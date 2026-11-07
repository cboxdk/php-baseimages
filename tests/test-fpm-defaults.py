#!/usr/bin/env python3
import json
from pathlib import Path
import subprocess
import unittest
ROOT = Path(__file__).resolve().parents[1]


class FpmDefaultsTests(unittest.TestCase):
    def resolve(self, assignments):
        result = subprocess.run(['sh', '-c', '. "$1"; eval "$2"; resolve_fpm_dynamic_defaults || exit; printf "%s,%s,%s" "$PHP_FPM_START_SERVERS" "$PHP_FPM_MIN_SPARE" "$PHP_FPM_MAX_SPARE"', 'test', str(ROOT/'common/lib/entrypoint-lib.sh'), assignments], text=True, capture_output=True)
        return result

    def test_small_manual_pools_have_valid_defaults(self):
        self.assertEqual(self.resolve('PHP_FPM_MAX_CHILDREN=1').stdout, '1,1,1')
        self.assertEqual(self.resolve('PHP_FPM_MAX_CHILDREN=4').stdout, '2,1,4')
        self.assertEqual(self.resolve('PHP_FPM_MAX_CHILDREN=10').stdout, '2,1,6')

    def test_explicit_settings_are_preserved(self):
        result=self.resolve('PHP_FPM_MAX_CHILDREN=10; PHP_FPM_START_SERVERS=3; PHP_FPM_MIN_SPARE=2; PHP_FPM_MAX_SPARE=5')
        self.assertEqual(result.stdout,'3,2,5')

    def test_bad_maximum_fails_before_arithmetic(self):
        for value in ['0','-1','junk','1+2']:
            self.assertNotEqual(self.resolve('PHP_FPM_MAX_CHILDREN='+value).returncode,0)

    def test_lifecycle_dates_match_existing_linux_contract(self):
        result=json.loads(subprocess.check_output(['bash',str(ROOT/'scripts/get-build-state.sh'),'8.2','trixie'],text=True))
        self.assertEqual(result['removal_date'],'2027-07-01')


if __name__ == '__main__': unittest.main()
