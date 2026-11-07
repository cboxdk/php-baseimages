#!/usr/bin/env python3
"""No registry writes: verify reuse eligibility, trust boundaries and patch generation."""
import copy
import contextlib
import importlib.util
import json
import io
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('image_patch', ROOT / 'scripts/image-patch.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class PatchTests(unittest.TestCase):
    def setUp(self):
        self.now = 1793966400
        self.config = {'architecture': 'arm64', 'os': 'linux', 'config': {'User': '33:33', 'Labels': {
            module.PREFIX + 'debian-suite': 'trixie', module.PREFIX + 'fingerprint': 'abc', module.PREFIX + 'php-version': '8.5.12',
            module.PREFIX + 'patch-depth': '2', module.PREFIX + 'full-built-at': str(self.now - 86400)}}}

    def eligible(self, config):
        return module.decide(config, 'abc', '8.5.12', 'arm64', self.now)[0]

    def test_matching_inputs_allow_rootless_patch(self):
        self.assertTrue(self.eligible(self.config))
        recipe = module.patch_dockerfile('ghcr.io/cbox/test@sha256:' + 'a' * 64, '33:33', 'slim-rootless')
        self.assertIn('USER root', recipe)
        self.assertTrue(recipe.endswith('USER 33:33\n'))
        self.assertIn('APT::Update::Error-Mode=any', recipe)
        self.assertIn('upgrade --with-new-pkgs', recipe)
        self.assertIn('--force-confold', recipe)
        self.assertNotIn('make', recipe)

    def test_changed_inputs_php_or_platform_force_full(self):
        for field, value in [('fingerprint', 'different'), ('php-version', '8.5.11'), ('debian-suite', 'bookworm')]:
            config = copy.deepcopy(self.config)
            config['config']['Labels'][module.PREFIX + field] = value
            self.assertFalse(self.eligible(config))
        config = copy.deepcopy(self.config)
        config['architecture'] = 'amd64'
        self.assertFalse(self.eligible(config))
        config['config']['Labels'] = {}
        self.assertFalse(self.eligible(config))

    def test_patch_history_is_bounded_and_malformed_labels_fail_closed(self):
        for field, value in [('patch-depth', str(module.MAX_DEPTH)), ('patch-depth', '-1'),
                             ('patch-depth', 'oops'), ('full-built-at', str(self.now - module.MAX_AGE)),
                             ('full-built-at', str(self.now + 1))]:
            config = copy.deepcopy(self.config)
            config['config']['Labels'][module.PREFIX + field] = value
            self.assertFalse(self.eligible(config))

    def test_dockerfile_injection_is_rejected(self):
        for reference, user, target in [('image\nRUN false', 'root', 'test'), ('image', 'root\nRUN false', 'test'),
                                        ('image', 'root', 'test\nRUN false')]:
            with self.assertRaises(ValueError):
                module.patch_dockerfile(reference, user, target)

    def test_input_fingerprint_is_stable_and_covers_variant_and_caller_args(self):
        args = ['php-fpm', '8.5', 'slim-root', 'slim', 'slim', 'linux/arm64']
        expected = module.fingerprint(*args)
        self.assertEqual(expected, module.fingerprint(*args))
        self.assertNotEqual(expected, module.fingerprint(*args, 'CUSTOM=changed'))
        args[2] = 'slim-rootless'
        self.assertNotEqual(expected, module.fingerprint(*args))

    def test_remote_selection_keeps_platform_attestations_without_pulling_layers(self):
        image, attestation = 'sha256:' + 'a' * 64, 'sha256:' + 'b' * 64
        index = {'manifests': [
            {'digest': image, 'platform': {'architecture': 'arm64', 'os': 'linux'}},
            {'digest': 'sha256:' + 'c' * 64, 'platform': {'architecture': 'amd64', 'os': 'linux'}},
            {'digest': attestation, 'annotations': {'vnd.docker.reference.digest': image, 'vnd.docker.reference.type': 'attestation-manifest'}}]}
        with patch.object(module.subprocess, 'check_output', side_effect=[json.dumps(index), json.dumps(self.config)]) as call:
            reference, config, extra = module.remote_config('ghcr.io/cbox/test:8.5-slim-v1', 'arm64')
        self.assertEqual(reference, 'ghcr.io/cbox/test@' + image)
        self.assertEqual(extra, [attestation])
        self.assertEqual(config, self.config)
        self.assertIn(reference, call.call_args_list[1].args[0])
        self.assertNotIn('pull', call.call_args_list[0].args[0])

    def test_planner_emits_patch_or_reuse_with_immutable_digest_and_attestations(self):
        reference = 'ghcr.io/cbox/test@sha256:' + 'a' * 64
        extra = 'sha256:' + 'b' * 64
        for series, updates, mode in [(s, u, m) for s in ('8.2', '8.3', '8.4', '8.5')
                                      for u, m in [(True, 'patch'), (False, 'reuse'), (None, 'full')]]:
            config = copy.deepcopy(self.config)
            lock = json.loads((ROOT / f'php-source/php{series.replace(".", "")}-trixie.lock.json').read_text())
            config['config']['Labels'][module.PREFIX + 'php-version'] = lock['version']
            with tempfile.TemporaryDirectory() as tmp:
                output = io.StringIO()
                args = ['image-patch.py', '--image-type', 'php-fpm', '--series', series, '--target', 'slim-rootless',
                        '--tier', 'slim', '--platform', 'linux/arm64', '--output', tmp + '/Dockerfile']
                with patch.object(sys, 'argv', args), patch.object(module, 'fingerprint', return_value='abc'), \
                     patch.object(module.time, 'time', return_value=self.now), \
                     patch.object(module, 'remote_config', return_value=(reference, config, [extra])), \
                     patch.object(module, 'probe_updates', return_value=updates), contextlib.redirect_stdout(output):
                    module.main()
                result = dict(line.split('=', 1) for line in output.getvalue().splitlines())
                self.assertEqual(result['mode'], mode)
                self.assertEqual(result['depth'], '0' if updates is None else ('3' if updates else '2'))
                if updates:
                    self.assertIn(reference, Path(result['dockerfile']).read_text())
                elif updates is not None:
                    self.assertEqual(result['digest'], reference.split('@')[1])
                    self.assertEqual(result['extra_digests'], extra)
                    self.assertEqual(result['dockerfile'], '')

    def test_package_revision_ignores_signature_dates_but_detects_package_changes(self):
        def release(digest, stamp):
            return io.BytesIO((f'Date: {stamp}\n {digest} 100 main/binary-amd64/Packages.xz\n'
                               + f' {"b" * 64} 101 main/binary-arm64/Packages.xz\n').encode())
        with patch.object(module.urllib.request, 'urlopen', side_effect=[release('a' * 64, 'today') for _ in range(3)]):
            first = module.repository_revision()
        with patch.object(module.urllib.request, 'urlopen', side_effect=[release('a' * 64, 'tomorrow') for _ in range(3)]):
            self.assertEqual(first, module.repository_revision())
        with patch.object(module.urllib.request, 'urlopen', side_effect=[release('c' * 64, 'today') for _ in range(3)]):
            self.assertNotEqual(first, module.repository_revision())
        with patch.object(module.urllib.request, 'urlopen', return_value=io.BytesIO(b'broken metadata')):
            with self.assertRaises(ValueError):
                module.repository_revision()

    def test_lifecycle_transition_changes_scheduler_signal(self):
        release = ('SHA256:\n ' + 'a' * 64 + ' 12 main/binary-amd64/Packages.xz\n '
                   + 'b' * 64 + ' 12 main/binary-arm64/Packages.xz\n').encode()
        with patch.object(module.urllib.request, 'urlopen', side_effect=lambda *a, **k: io.BytesIO(release)):
            with patch.object(module, 'lifecycle_state', return_value={'lifecycle': 'stable'}):
                stable = module.repository_revision()
            with patch.object(module, 'lifecycle_state', return_value={'lifecycle': 'deprecated'}):
                self.assertNotEqual(stable, module.repository_revision())

    def test_apt_summary_does_not_hide_held_back_packages(self):
        plans = [
            ("0 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.", False),
            ("Inst hello [1.0] (2.0 Debian:13/stable [arm64])\n1 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.", True),
            ("0 upgraded, 0 newly installed, 0 to remove and 2 not upgraded.", None),
            ("Inst hello [1.0] (2.0 Debian:13/stable [arm64])\n1 upgraded, 0 newly installed, 0 to remove and 1 not upgraded.", None),
        ]
        with tempfile.TemporaryDirectory() as tmp:
            apt = Path(tmp) / 'apt-get'
            apt.write_text('#!/bin/sh\ncase " $* " in *" upgrade "*) printf "%s\\n" "$CBOX_TEST_APT_PLAN";; esac\n')
            apt.chmod(0o755)
            for plan, expected in plans:
                env = {**os.environ, 'PATH': tmp + os.pathsep + os.environ['PATH'], 'CBOX_TEST_APT_PLAN': plan}
                def run_probe(args, **kwargs):
                    return subprocess.run(['sh', '-c', args[-1]], env=env, text=True, capture_output=True, check=True).stdout
                with patch.object(module.subprocess, 'check_output', side_effect=run_probe):
                    self.assertIs(module.probe_updates('local:test', 'linux/arm64'), expected)

    def test_apt_probe_reuses_only_on_explicit_success(self):
        for output, expected in [('CBOX_OS_UPDATES=0\n', False), ('CBOX_OS_UPDATES=1\n', True), ('CBOX_OS_UPDATES=full\n', None)]:
            with patch.object(module.subprocess, 'check_output', return_value=output):
                self.assertEqual(module.probe_updates('local:test', 'linux/arm64'), expected)
        with patch.object(module.subprocess, 'check_output', side_effect=subprocess.CalledProcessError(100, 'apt')):
            with self.assertRaises(subprocess.CalledProcessError):
                module.probe_updates('local:test', 'linux/arm64')
        with patch.object(module.subprocess, 'check_output', return_value='unrecognized output'):
            with self.assertRaises(ValueError):
                module.probe_updates('local:test', 'linux/arm64')


if __name__ == '__main__':
    unittest.main()
