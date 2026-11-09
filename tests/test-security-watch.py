#!/usr/bin/env python3
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('watch', Path(__file__).resolve().parents[1] / 'scripts/security-watch.py')
watch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(watch)


class SecurityWatchTests(unittest.TestCase):
    def finding(self, kind='os-pkgs', fixed='2', severity='HIGH'):
        return {'Results': [{'Class': kind, 'Type': 'debian' if kind == 'os-pkgs' else 'gobinary', 'Vulnerabilities': [
            dict(VulnerabilityID='CVE-test', PkgName='example', InstalledVersion='1', FixedVersion=fixed, Severity=severity)]}]}

    def test_actionable_findings_are_split_by_remediation(self):
        rows = [dict(series='8.5', findings=watch.findings(self.finding())),
                dict(series='nginx', findings=watch.findings(self.finding())),
                dict(series='8.2', findings=watch.findings(self.finding('lang-pkgs')))]
        self.assertEqual(watch.remediation(rows), (['8.5', 'nginx'], True))
        self.assertFalse(watch.findings(self.finding(fixed='')))
        self.assertFalse(watch.findings(self.finding(severity='MEDIUM')))

    def test_dispatch_batches_php_and_never_forces_toolchain_rebuild_for_os(self):
        rows = [dict(series=s, findings=watch.findings(self.finding())) for s in ['8.2','8.5']]
        with patch.object(watch, 'read_command', return_value=[]), patch.object(watch.subprocess, 'run') as run:
            watch.dispatch(rows)
        self.assertEqual(run.call_count, 1)
        self.assertIn('php_version=all', run.call_args.args[0])
        self.assertNotIn('force_full=true', run.call_args.args[0])

    def test_same_finding_backs_off_but_new_finding_dispatches(self):
        rows=[dict(series='8.5', findings=watch.findings(self.finding()))]
        with patch.object(watch,'read_command',return_value=[]), patch.object(watch.subprocess,'run') as run:
            watch.dispatch(rows)
            token=next(arg.split('=',1)[1] for arg in run.call_args.args[0] if arg.startswith('os_revision='))
        recent=[dict(status='completed', displayTitle='Build PHP base (8.5) OS:'+token, createdAt='2026-11-06T00:00:00Z')]
        now=watch.datetime.datetime.fromisoformat('2026-11-06T01:00:00+00:00').timestamp()
        with patch.object(watch,'read_command',return_value=recent), patch.object(watch.time,'time',return_value=now), patch.object(watch.subprocess,'run') as run:
            watch.dispatch(rows)
            run.assert_not_called()
            rows[0]['findings'][0]['id']='CVE-new'
            watch.dispatch(rows)
            run.assert_called_once()

    def test_active_work_prevents_duplicate_mitigation(self):
        rows = [dict(series='8.5', findings=watch.findings(self.finding()))]
        with patch.object(watch, 'read_command', return_value=[{'status':'in_progress'}]), patch.object(watch.subprocess, 'run') as run:
            watch.dispatch(rows)
        run.assert_not_called()

    def test_inventory_reused_but_vulnerabilities_are_rescanned(self):
        target = dict(series='8.5', platform='linux/arm64', digest='sha256:'+'a'*64, reference='local:test')
        calls = []
        report = {'Results':[{'Class':'os-pkgs', 'Type':'debian', 'Vulnerabilities':[]}]}
        def fake_run(command, **kwargs):
            calls.append(command)
            if '--output' in command:
                data = {'bomFormat':'CycloneDX', 'components':[{'name':'libc6'}]} if command[1]=='image' else report
                Path(command[command.index('--output')+1]).write_text(json.dumps(data))
        with tempfile.TemporaryDirectory() as tmp, patch.object(watch.subprocess, 'run', side_effect=fake_run), patch.object(watch, 'dispatch') as dispatch:
            root=Path(tmp)
            self.assertFalse(watch.scan([target], root/'cache', root/'results'))
            report.update(self.finding())
            self.assertTrue(watch.scan([target], root/'cache', root/'results'))
            dispatch.assert_not_called()  # report-only is the default, including local tests
        self.assertEqual(sum(c[1]=='image' and '--output' in c for c in calls), 1)
        self.assertEqual(sum(c[1]=='sbom' for c in calls), 2)

    def test_empty_scan_is_a_failure_not_a_clean_bill_of_health(self):
        target = dict(series='8.5', platform='linux/arm64', digest='sha256:'+'b'*64, reference='local:test')
        def fake_run(command, **kwargs):
            if '--output' in command:
                Path(command[command.index('--output')+1]).write_text('{}')
        with tempfile.TemporaryDirectory() as tmp, patch.object(watch.subprocess, 'run', side_effect=fake_run):
            root=Path(tmp)
            with self.assertRaises(ValueError): watch.scan([target],root/'cache',root/'out')

    def test_plan_covers_cli_fpm_nginx_and_both_architectures(self):
        manifest={'manifests':[{'platform':{'os':'linux','architecture':arch},'digest':'sha256:'+letter*64}
                               for arch,letter in [('amd64','a'),('arm64','b')]]}
        with patch.object(watch,'read_command',return_value=manifest):
            targets=watch.plan('cboxdk/php-baseimages')
        lines = watch.channels(json.loads((watch.ROOT/'versions.json').read_text()))
        self.assertEqual(len(targets), sum(4*len(c['php'])+2 for c in lines))
        self.assertEqual({t['channel'] for t in targets}, {c['channel'] for c in lines})
        self.assertEqual({t['family'] for t in targets},{'php-cli','php-fpm-nginx','nginx'})
        self.assertEqual({t['platform'] for t in targets},{'linux/amd64','linux/arm64'})
        self.assertTrue(all('@sha256:' in t['reference'] for t in targets))

    def kev_report(self, cve='CVE-kev', fixed='', severity='LOW', kind='os-pkgs', package='nginx'):
        return {'Results': [{'Class': kind, 'Type': 'debian', 'Vulnerabilities': [
            dict(VulnerabilityID=cve, PkgName=package, InstalledVersion='1', FixedVersion=fixed, Severity=severity)]}]}

    def test_kev_is_actionable_at_any_severity_and_without_a_fix(self):
        rows = watch.findings(self.kev_report(), kev={'CVE-kev'})
        self.assertEqual([(r['id'], r['kev']) for r in rows], [('CVE-kev', True)])
        self.assertFalse(watch.findings(self.kev_report(), kev={'CVE-other'}))

    def test_baseline_is_read_from_each_channels_branch(self):
        watch._BASELINES.clear()
        def fake(cmd, **kw):
            return '# note\nCVE-v1-only\n'
        with patch.object(watch.subprocess, 'run'), patch.object(watch.subprocess, 'check_output', side_effect=fake) as show:
            self.assertEqual(watch.ignored_ids('release/v1'), {'CVE-v1-only'})
            watch.ignored_ids('release/v1')
        self.assertEqual(show.call_count, 1)
        self.assertNotIn('CVE-v1-only', watch.ignored_ids('main'))
        watch._BASELINES.clear()

    def test_unreadable_branch_baseline_is_stricter_not_looser(self):
        watch._BASELINES.clear()
        with patch.object(watch.subprocess, 'run', side_effect=watch.subprocess.CalledProcessError(1, 'git')):
            self.assertEqual(watch.ignored_ids('release/v9'), set())
        watch._BASELINES.clear()

    def test_trivyignore_cannot_silence_a_kev(self):
        report = self.kev_report(fixed='2', severity='HIGH')
        self.assertFalse(watch.findings(report, kev=set(), ignored={'CVE-kev'}))
        self.assertTrue(watch.findings(report, kev={'CVE-kev'}, ignored={'CVE-kev'}))

    def test_pre_promotion_gate_blocks_only_fixable_kev(self):
        self.assertTrue(watch.kev_gate(self.kev_report(fixed='2'), {'CVE-kev'}))
        self.assertFalse(watch.kev_gate(self.kev_report(fixed=''), {'CVE-kev'}))
        self.assertFalse(watch.kev_gate(self.kev_report(fixed='2'), {'CVE-other'}))

    def test_exception_covers_only_unfixed_kev_for_its_package_channel_and_family(self):
        exc = [dict(id='CVE-kev', package='nginx', channel='1', family='php-fpm-nginx', reason='r', expires='2999-01-01')]
        target = dict(channel='1', family='php-fpm-nginx')
        unfixed = watch.findings(self.kev_report(), kev={'CVE-kev'})[0]
        fixed = watch.findings(self.kev_report(fixed='2'), kev={'CVE-kev'})[0]
        self.assertTrue(watch.accepted_kev(unfixed, target, exc))
        self.assertFalse(watch.accepted_kev(fixed, target, exc))
        self.assertFalse(watch.accepted_kev(unfixed, dict(channel='2', family='php-fpm-nginx'), exc))
        self.assertFalse(watch.accepted_kev(unfixed, dict(channel='1', family='nginx'), exc))

    def test_exceptions_expire_and_must_be_justified(self):
        entries = watch.load_kev_exceptions(today='2000-01-01')
        self.assertTrue(entries)
        self.assertTrue(all(e['reason'] and e['expires'] for e in entries))
        self.assertFalse(watch.load_kev_exceptions(today='2999-01-01'))

    def test_truncated_kev_catalog_is_an_error(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'kev.json'
            path.write_text(json.dumps({'vulnerabilities': [{'cveID': 'CVE-1'}]}))
            with self.assertRaises(ValueError): watch.load_kev(path)

    def test_unfixed_findings_never_request_a_rebuild(self):
        rows = [dict(series='8.5', findings=watch.findings(self.kev_report(), kev={'CVE-kev'}))]
        self.assertEqual(watch.remediation(rows), ([], False))

    def test_maintenance_branch_findings_rebuild_that_branch(self):
        fixable = watch.findings(self.kev_report(fixed='2'), kev={'CVE-kev'})
        rows = [dict(series='8.5', branch='release/v1', channel='1', findings=fixable),
                dict(series='nginx', branch='release/v1', channel='1', findings=fixable)]
        self.assertEqual(watch.remediation(rows), ([], False))
        with patch.object(watch, 'read_command', return_value=[]), patch.object(watch.subprocess, 'run') as run:
            watch.dispatch(rows)
        commands = [c.args[0] for c in run.call_args_list]
        self.assertEqual(sorted(c[3] for c in commands), ['build-nginx.yml', 'build-php-base.yml'])
        self.assertTrue(all(c[c.index('--ref') + 1] == 'release/v1' for c in commands))

    def test_channels_include_maintained_majors_until_their_end_date(self):
        versions = json.loads((watch.ROOT / 'versions.json').read_text())
        self.assertEqual([c['channel'] for c in watch.channels(versions, today='2026-11-09')], ['2', '1'])
        self.assertEqual([c['channel'] for c in watch.channels(versions, today='2999-01-01')], ['2'])

    def test_plan_requires_both_unique_platforms(self):
        manifest={'manifests':[{'platform':{'os':'linux','architecture':'amd64'},'digest':'sha256:'+'a'*64}]}
        with patch.object(watch,'read_command',return_value=manifest):
            with self.assertRaises(ValueError): watch.plan('cboxdk/php-baseimages')


if __name__ == '__main__':
    unittest.main()
