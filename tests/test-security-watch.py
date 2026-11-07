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
        self.assertEqual(len(targets),4*len(json.loads((watch.ROOT/'versions.json').read_text())['php']['supported'])+2)
        self.assertEqual({t['family'] for t in targets},{'php-cli','php-fpm-nginx','nginx'})
        self.assertEqual({t['platform'] for t in targets},{'linux/amd64','linux/arm64'})
        self.assertTrue(all('@sha256:' in t['reference'] for t in targets))

    def test_plan_requires_both_unique_platforms(self):
        manifest={'manifests':[{'platform':{'os':'linux','architecture':'amd64'},'digest':'sha256:'+'a'*64}]}
        with patch.object(watch,'read_command',return_value=manifest):
            with self.assertRaises(ValueError): watch.plan('cboxdk/php-baseimages')


if __name__ == '__main__':
    unittest.main()
