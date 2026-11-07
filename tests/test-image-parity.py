#!/usr/bin/env python3
import copy
import importlib.util
from pathlib import Path
import unittest
spec=importlib.util.spec_from_file_location('parity',Path(__file__).resolve().parents[1]/'scripts/test-image-parity.py')
parity=importlib.util.module_from_spec(spec);spec.loader.exec_module(parity)

class ParityTests(unittest.TestCase):
    def setUp(self):
        self.old=dict(version='8.5.11',zts=False,sapi='fpm-fcgi',uid=33,extensions=['redis','PDO'],ini={'memory_limit':'256M'})

    def test_patch_update_preserves_contract_but_ini_or_extension_loss_fails(self):
        new=copy.deepcopy(self.old);new['version']='8.5.12'
        self.assertEqual(parity.runtime_diff(self.old,new),{})
        new['ini']['memory_limit']='128M';new['extensions'].remove('redis')
        differences=parity.runtime_diff(self.old,new)
        self.assertIn('ini',differences);self.assertEqual(differences['missing_extensions'],['redis'])

    def test_metadata_does_not_hide_runtime_env_or_user_changes(self):
        old=dict(cli=self.old,config={'User':'33','Env':['CBOX_PHP_EOL=old','PHP_OPEN_BASEDIR=']})
        new=copy.deepcopy(old);new['config']['Env']=['CBOX_PHP_EOL=new','PHP_OPEN_BASEDIR=/var/www']
        new['config']['User']='0'
        diff,metadata=parity.compare(old,new)
        self.assertIn('PHP_OPEN_BASEDIR',diff['environment'])
        self.assertIn('User',diff['container'])
        self.assertIn('CBOX_PHP_EOL',metadata)

if __name__=='__main__':unittest.main()
