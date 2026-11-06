#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('dispatch', Path(__file__).resolve().parents[1] / 'scripts/dispatch-php-source-builds.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class DispatchTests(unittest.TestCase):
    def setUp(self):
        self.base = [{'displayTitle': 'Build PHP base (8.5) OS:unchanged', 'createdAt': '2026-11-05T00:00:00Z', 'status': 'completed', 'conclusion': 'success'}]
        self.now = module.timestamp(self.base[0]) + 86400
        self.children = {v: [{'displayTitle': f'Build PHP {v} (8.5) source:abc', 'createdAt': '2026-11-05T01:00:00Z', 'status': 'completed', 'conclusion': 'success'}] for v in ('cli', 'fpm', 'fpm-nginx')}

    def dispatch(self):
        return module.should_dispatch('8.5', self.base, self.children, 'abc', 'unchanged', self.now)

    def test_complete_chain_deduplicates_unchanged_os(self):
        self.assertFalse(self.dispatch())
        self.now += 30 * 86400
        self.assertTrue(self.dispatch())

    def test_failed_missing_or_wrong_source_child_retries_chain(self):
        for variant in self.children:
            child = self.children[variant][0]
            child['conclusion'] = 'failure'
            self.assertTrue(self.dispatch())
            child['conclusion'] = 'success'
        self.children['cli'][0]['displayTitle'] = 'Build PHP cli (8.5) source:old'
        self.assertTrue(self.dispatch())
        self.children['cli'] = []
        self.assertTrue(self.dispatch())

    def test_running_child_does_not_queue_duplicate(self):
        self.children['fpm'][0]['status'] = 'in_progress'
        self.assertFalse(self.dispatch())

    def test_active_sibling_wins_over_earlier_failed_child(self):
        self.children['cli'][0]['conclusion'] = 'failure'
        self.children['fpm'][0]['status'] = 'in_progress'
        self.assertFalse(self.dispatch())

    def test_security_revision_bypasses_six_hour_wait(self):
        self.now = module.timestamp(self.base[0]) + 7200
        self.base[0]['displayTitle'] = 'Build PHP base (8.5) OS:old.security1'
        self.assertFalse(module.should_dispatch('8.5',self.base,self.children,'abc','new.security1',self.now))
        self.assertTrue(module.should_dispatch('8.5',self.base,self.children,'abc','new.security2',self.now))

    def test_repeated_child_failures_back_off_but_new_packages_retry(self):
        self.base *= 3
        self.children['cli'][0]['conclusion'] = 'failure'
        self.now = module.timestamp(self.base[0]) + 7200
        self.assertFalse(self.dispatch())
        self.assertTrue(module.should_dispatch('8.5',self.base,self.children,'abc','new',self.now))

    def test_nginx_parent_or_security_changes_dispatch_immediately(self):
        runs=[{**self.base[0], 'displayTitle':'Build Nginx security:normal OS:normal.urgent1'}]
        now=module.timestamp(runs[0])+1800
        self.assertFalse(module.should_dispatch_nginx(runs,'normal.urgent1',now))
        self.assertFalse(module.should_dispatch_nginx(runs,'changed.urgent1',now))
        self.assertTrue(module.should_dispatch_nginx(runs,'normal.urgent2',now))
        runs[0]['status']='in_progress'
        self.assertFalse(module.should_dispatch_nginx(runs,'normal.urgent2',now))

    def test_latest_failure_overrides_older_success(self):
        self.base.insert(0, {**self.base[0], 'createdAt': '2026-11-05T02:00:00Z', 'conclusion': 'failure'})
        self.assertTrue(self.dispatch())

    def test_three_failures_back_off_until_inputs_change(self):
        self.base = [{**self.base[0], 'conclusion': 'failure'} for _ in range(3)]
        self.now = module.timestamp(self.base[0]) + 1800
        self.assertFalse(self.dispatch())
        self.assertTrue(module.should_dispatch('8.5', self.base, self.children, 'abc', 'new-packages', self.now))
        self.now += 21600
        self.assertTrue(self.dispatch())


if __name__ == '__main__':
    unittest.main()
