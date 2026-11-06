#!/usr/bin/env python3
import importlib.util
import json
import unittest
from pathlib import Path
from unittest.mock import patch

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('parents', root / 'scripts/pin-source-parents.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ParentTests(unittest.TestCase):
    def test_reachable_targets_include_copied_browser_but_not_unused_tiers(self):
        text = (root / 'php-fpm/Dockerfile').read_text()
        self.assertEqual(set(module.reachable_parents(text, 'dev-rootless')), {'base-dev', 'base-chromium'})
        self.assertEqual(set(module.reachable_parents(text, 'slim-root')), {'base-slim'})
        text = (root / 'php-cli/Dockerfile').read_text()
        self.assertEqual(set(module.reachable_parents(text, 'rootless')), {'base-standard-rootless'})

    def test_source_mismatch_rejected_and_matching_parent_pinned_before_tag_can_move(self):
        text = (root / 'php-cli/Dockerfile').read_text()
        config = {'architecture': 'arm64', 'os': 'linux', 'config': {'Labels': {
            module.patch.PREFIX + 'fingerprint': 'expected', module.patch.PREFIX + 'debian-suite': 'trixie',
            module.patch.PREFIX + 'php-version': json.loads((root / 'php-source/php85-trixie.lock.json').read_text())['version']}}}
        digest = 'ghcr.io/cboxdk/php-baseimages/php-base@sha256:' + 'a' * 64
        with patch.object(module.patch, 'fingerprint', return_value='expected') as fingerprint, patch.object(module.patch, 'remote_config', return_value=(digest, config, [])) as remote:
            result = module.pin(text, 'rootless', '8.5', 'linux/arm64', 'cboxdk/php-baseimages')
            self.assertIn('FROM ' + digest + ' AS base-standard-rootless', result)
            remote.assert_called_once_with('ghcr.io/cboxdk/php-baseimages/php-base:8.5-trixie-rootless-v2', 'arm64')
            fingerprint.assert_called_once_with('php-base', '8.5', 'rootless', 'standard', 'rootless', 'linux/arm64')
            config['config']['Labels'][module.patch.PREFIX + 'fingerprint'] = 'other-source'
            with self.assertRaises(ValueError):
                module.pin(text, 'rootless', '8.5', 'linux/arm64', 'cboxdk/php-baseimages')


if __name__ == '__main__':
    unittest.main()
