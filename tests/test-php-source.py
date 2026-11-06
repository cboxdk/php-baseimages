#!/usr/bin/env python3
"""Offline checks for per-series source locks and bounded build dispatch."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('php_source', ROOT / 'scripts/php-source.py')
source = importlib.util.module_from_spec(spec)
spec.loader.exec_module(source)


class SourceTests(unittest.TestCase):
    def setUp(self):
        self.lock = source.read_lock()
        self.version = '8.5.' + str(int(self.lock['version'].split('.')[-1]) + 1)
        self.release = {'version': self.version, 'source': [
            {'filename': f'php-{self.version}.tar.xz', 'sha256': 'a' * 64}]}

    def test_stable_patches_are_isolated_per_series(self):
        for series in ['8.2', '8.3', '8.4', '8.5']:
            lock = source.read_lock(source.lock_path(series))
            version = series + '.' + str(int(lock['version'].split('.')[-1]) + 1)
            release = {'version': version, 'source': [{'filename': f'php-{version}.tar.xz', 'sha256': 'a' * 64}]}
            candidate = source.patch_candidate(lock, release)
            self.assertEqual(candidate['version'], version)
            self.assertEqual(candidate['series'], series)
            self.assertEqual(candidate['url'], f'https://www.php.net/distributions/php-{version}.tar.xz')
            self.assertEqual(candidate['docker_library_commit'], lock['docker_library_commit'])
            self.assertIsNone(source.patch_candidate(lock, {'version': lock['version']}))
            self.assertIsNone(source.patch_candidate(lock, {'version': series + '.0'}))
            for invalid in ['8.7.0', series + '.99RC1']:
                with self.assertRaises(ValueError):
                    source.patch_candidate(lock, {'version': invalid})

    def test_bad_hash_missing_archive_and_injected_url_fail_closed(self):
        self.release['source'][0]['sha256'] = 'bad'
        with self.assertRaises(ValueError):
            source.patch_candidate(self.lock, self.release)
        self.release['source'] = []
        with self.assertRaises(StopIteration):
            source.patch_candidate(self.lock, self.release)
        lock = {**source.read_lock(source.lock_path('8.6')), 'version': '8.6.0RC1',
                'url': 'https://downloads.php.net/~user/php-8.6.0RC1.tar.xz'}
        for url in ['https://evil.example/php-8.6.0RC6.tar.xz', 'https://downloads.php.net/../bad',
                    'https://downloads.php.net/~user/php-8.6.0RC6.tar.xz"\nRUN false']:
            with self.assertRaises(ValueError):
                source.patch_candidate(lock, {'version': '8.6.0RC6', 'files': {'xz': {'path': url, 'sha256': 'a' * 64}}})

    def test_preview_orders_rc_numerically_without_promoting_to_ga(self):
        lock = {**source.read_lock(source.lock_path('8.6')), 'version': '8.6.0RC1',
                'url': 'https://downloads.php.net/~user/php-8.6.0RC1.tar.xz'}
        self.assertGreater(source.version_key('8.6.0RC10', '8.6', 'preview'), source.version_key('8.6.0RC9', '8.6', 'preview'))
        for invalid in ['8.6.0', '8.6.1RC1', '8.7.0RC1']:
            with self.assertRaises(ValueError):
                source.patch_candidate(lock, {'version': invalid})
        rc = {'version': '8.6.0RC10', 'files': {'xz': {'path': 'https://downloads.php.net/~user/php-8.6.0RC10.tar.xz', 'sha256': 'b' * 64}}}
        self.assertEqual(source.preview_release({'8.6.0': {'release': rc}}, lock), rc)
        self.assertEqual(source.preview_release({'releases': {'8.6.0': rc}}, lock), rc)
        self.assertEqual(source.preview_release({'releases': [rc, {'version': '8.7.0RC1'}]}, lock), rc)
        self.assertIsNone(source.preview_release({'8.6.0': {'release': {**rc, 'enabled': False}}}, lock))
        self.assertEqual(source.patch_candidate(lock, rc)['url'], rc['files']['xz']['path'])

    def test_check_is_read_only_unless_apply_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as tmp:
            lock, release = Path(tmp) / 'lock.json', Path(tmp) / 'release.json'
            lock.write_text(json.dumps(self.lock))
            release.write_text(json.dumps(self.release))
            command = ['python3', str(ROOT / 'scripts/php-source.py'), '--lock', str(lock), 'check', '--release-json', str(release)]
            self.assertIn('changed=true', subprocess.check_output(command, text=True))
            self.assertEqual(json.loads(lock.read_text()), self.lock)
            subprocess.check_call(command + ['--apply'], stdout=subprocess.DEVNULL)
            self.assertIn('changed=false', subprocess.check_output(command, text=True))

    def test_all_runtimes_use_their_own_recipes_and_one_verified_lock(self):
        for series in source.SERIES:
            lock = source.read_lock(source.lock_path(series))
            for variant in ['cli', 'fpm']:
                text = source.render(variant, lock)
                self.assertIn(f'ENV PHP_VERSION={lock["version"]}', text)
                self.assertIn(lock['sha256'], text)
                self.assertIn(lock['url'], text)
                self.assertIn('sha256sum -c -', text)
                self.assertIn('gpg --batch --verify', text)
                self.assertNotIn('pecl update-channels;', text)
                self.assertNotIn('FROM php:', text)
                self.assertEqual('--enable-zts' in text, series == '8.6')

    def test_wrong_suite_recipe_fails_before_building(self):
        with tempfile.TemporaryDirectory() as tmp:
            recipe = Path(tmp) / 'php-source/upstream/8.5/cli.Dockerfile'
            recipe.parent.mkdir(parents=True)
            recipe.write_text('FROM debian:bookworm-slim\n')
            with patch.object(source, 'ROOT', Path(tmp)), self.assertRaises(ValueError):
                source.runtime_dockerfile('cli', self.lock)

    def test_stable_and_preview_images_cannot_be_confused(self):
        for series in ('8.2', '8.3', '8.4', '8.5'):
            text = source.render('php-fpm', source.read_lock(source.lock_path(series)))
            self.assertIn('ARG PHP_VERSION=' + series + '\n', text)
        for image in ['php-base', 'php-fpm']:
            text = source.render(image, self.lock)
            self.assertLess(text.index('ARG PHP_VERSION='), text.index('FROM '))
            self.assertNotIn('FROM php:${PHP_VERSION}', text)
        for image in ['php-fpm', 'php-cli', 'php-fpm-nginx']:
            text = source.render(image, self.lock)
            self.assertEqual(text.count('RUN test "$(php -r'), text.count('FROM ghcr.io/cboxdk/php-baseimages/'))
        preview = source.read_lock(source.lock_path('8.6'))
        with self.assertRaises(ValueError):
            source.render('php-base', preview)
        text = source.render('php86-fpm', preview)
        self.assertNotIn('FROM php:', text)
        self.assertEqual(text.count('AS php-source-runtime'), 1)
        self.assertEqual(text.count('AS php-source-fpm'), 1)
        for tier in ['slim', 'standard', 'chromium', 'dev']:
            self.assertIn('AS beta-fpm-' + tier, text)

    def test_dispatch_distinguishes_series_retries_failures_and_refreshes_os(self):
        with tempfile.TemporaryDirectory() as tmp:
            gh, log = Path(tmp) / 'gh', Path(tmp) / 'dispatch.log'
            gh.write_text('#!/usr/bin/env python3\nimport os, sys\n'
                          'if sys.argv[1:3] == ["run", "list"]: print(os.environ["TEST_RUNS"])\n'
                          'else: open(os.environ["TEST_LOG"], "a").write(" ".join(sys.argv[1:]) + "\\n")\n')
            gh.chmod(0o755)
            now = 1793966400
            recent = '2026-11-06T11:30:00Z'
            for runs, count in [([], 3),
                ([{'status': 'in_progress', 'conclusion': '', 'displayTitle': 'Build PHP base (8.4)', 'createdAt': recent}], 3),
                ([{'status': 'completed', 'conclusion': 'success', 'displayTitle': 'Build PHP base (8.3) OS:same-revision', 'createdAt': '2026-11-05T00:00:00Z'}], 3),
                ([{'status': 'completed', 'conclusion': 'success', 'displayTitle': 'Build PHP base (8.3) OS:old-revision', 'createdAt': '2026-11-05T00:00:00Z'}], 3),
                ([{'status': 'in_progress', 'conclusion': '', 'displayTitle': 'Build PHP base (8.2)', 'createdAt': recent}], 3),
                ([{'status': 'completed', 'conclusion': 'success', 'displayTitle': 'Build PHP base (8.3)', 'createdAt': recent}], 3),
                ([{'status': 'completed', 'conclusion': 'failure', 'displayTitle': 'Build PHP base (8.3)', 'createdAt': recent}], 3),
                ([{'status': 'completed', 'conclusion': 'success', 'displayTitle': 'Build PHP base (8.3)', 'createdAt': '2026-11-05T00:00:00Z'}], 3)]:
                log.unlink(missing_ok=True)
                env = {**os.environ, 'PATH': tmp + os.pathsep + os.environ['PATH'], 'PATCH_NGINX_REVISION': 'same-nginx', 'PATCH_NOW': str(now), 'PATCH_OS_REVISION': 'same-revision',
                       'TEST_RUNS': json.dumps(runs), 'TEST_LOG': str(log)}
                subprocess.run(['bash', 'scripts/dispatch-php-source-builds.sh'], cwd=ROOT, env=env, check=True, capture_output=True)
                commands = log.read_text() if log.exists() else ''
                self.assertEqual(len(commands.splitlines()), count)
                if not runs:
                    self.assertIn('-f php_version=all ', commands)


if __name__ == '__main__':
    unittest.main()
