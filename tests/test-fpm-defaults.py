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

    LIMITS = 'PHP_FPM_MEMORY_LIMIT PHP_FPM_UPLOAD_MAX_FILESIZE PHP_FPM_POST_MAX_SIZE PHP_FPM_MAX_FILE_UPLOADS PHP_FPM_MAX_EXECUTION_TIME PHP_FPM_MAX_INPUT_TIME'

    def resolve_limits(self, assignments):
        # env -i: the result must not depend on what the machine running the tests exports
        script = '. "$1"; eval "$2"; resolve_fpm_php_limits || exit; for name in ' + self.LIMITS + '; do eval "printf \'%s,\' \\"\\$$name\\""; done'
        return subprocess.run(['env', '-i', 'sh', '-c', script, 'test', str(ROOT/'common/lib/entrypoint-lib.sh'), assignments], text=True, capture_output=True)

    def test_pool_limits_default_to_the_image_defaults(self):
        self.assertEqual(self.resolve_limits(':').stdout, '256M,100M,100M,20,60,60,')

    def test_general_php_variables_reach_the_pool(self):
        # The regression: these were documented, written to a second
        # php_admin_value, and ignored by PHP-FPM for every web request.
        result = self.resolve_limits('PHP_MEMORY_LIMIT=2048M; PHP_UPLOAD_MAX_FILESIZE=1024M; PHP_POST_MAX_SIZE=1024M; PHP_MAX_FILE_UPLOADS=50; PHP_MAX_EXECUTION_TIME=1800; PHP_MAX_INPUT_TIME=900')
        self.assertEqual(result.stdout, '2048M,1024M,1024M,50,1800,900,')

    def test_pool_only_variable_wins_over_the_general_one(self):
        result = self.resolve_limits('PHP_MEMORY_LIMIT=1G; PHP_FPM_MEMORY_LIMIT=512M; PHP_MAX_EXECUTION_TIME=1800; PHP_FPM_MAX_EXECUTION_TIME=30')
        self.assertEqual(result.stdout, '512M,100M,100M,20,30,60,')

    def test_pool_file_has_one_definition_per_limit_and_all_are_resolved(self):
        # A literal here is a second definition waiting to win over the
        # environment again; a ${VAR} nothing exports stops php-fpm booting.
        pool = (ROOT/'php-fpm/common/fpm-pool.conf').read_text()
        for directive, variable in [('memory_limit', 'PHP_FPM_MEMORY_LIMIT'), ('upload_max_filesize', 'PHP_FPM_UPLOAD_MAX_FILESIZE'), ('post_max_size', 'PHP_FPM_POST_MAX_SIZE'), ('max_file_uploads', 'PHP_FPM_MAX_FILE_UPLOADS'), ('max_execution_time', 'PHP_FPM_MAX_EXECUTION_TIME'), ('max_input_time', 'PHP_FPM_MAX_INPUT_TIME')]:
            lines = [line for line in pool.splitlines() if line.startswith('php_admin_value[' + directive + ']')]
            self.assertEqual(lines, ['php_admin_value[' + directive + '] = ${' + variable + '}'])
            self.assertIn(variable, self.LIMITS.split())
        for entrypoint in ['php-fpm/common/docker-entrypoint.sh', 'php-fpm-nginx/common/docker-entrypoint.sh']:
            text = (ROOT/entrypoint).read_text()
            self.assertIn('resolve_fpm_php_limits', text)
            for directive in ['memory_limit', 'upload_max_filesize', 'post_max_size', 'max_execution_time', 'max_input_time']:
                self.assertNotIn('php_admin_value[' + directive + ']', text)

    def test_lifecycle_dates_match_existing_linux_contract(self):
        result=json.loads(subprocess.check_output(['bash',str(ROOT/'scripts/get-build-state.sh'),'8.2','trixie'],text=True))
        self.assertEqual(result['removal_date'],'2027-07-01')


if __name__ == '__main__': unittest.main()
