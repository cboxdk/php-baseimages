#!/usr/bin/env python3
"""Exercise constrained FPM-Nginx containers with automatic and one-worker pools."""
import argparse
import http.client
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import urllib.error
import urllib.request

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('images',nargs='+')
args=parser.parse_args()
docker=['docker','--context',os.environ.get('DOCKER_CONTEXT','orbstack')]
for image in args.images:
    config=json.loads(subprocess.check_output(docker+['image','inspect',image],text=True))[0]['Config']
    env=dict(item.split('=',1) for item in config.get('Env',[]))
    port=env.get('NGINX_HTTP_PORT','8080' if env.get('CBOX_ROOTLESS')=='true' else '80')
    for mode,extra in [('autotune',[]),('one-worker',['-e','PHP_FPM_MAX_CHILDREN=1'])]:
        container=subprocess.check_output(docker+['run','-d','--memory','512m','--cpus','1',*extra,'-p','127.0.0.1::'+port,image],text=True).strip()
        try:
            with tempfile.TemporaryDirectory() as tmp:
                fixture=Path(tmp)/'sizing.php';fixture.write_text('<?php echo "FPM:".bcadd("1","2");');fixture.chmod(0o644)
                subprocess.run(docker+['cp',str(fixture),container+':/var/www/html/public/sizing.php'],check=True)
            address=subprocess.check_output(docker+['port',container,port+'/tcp'],text=True).strip()
            for attempt in range(40):
                try:
                    with urllib.request.urlopen('http://'+address+'/sizing.php',timeout=3) as response:
                        assert response.read()==b'FPM:3'
                    break
                except (urllib.error.URLError,TimeoutError,ConnectionError,http.client.HTTPException):
                    if attempt==39: raise
                    time.sleep(1)
            if mode=='autotune':
                logs=subprocess.check_output(docker+['logs',container],stderr=subprocess.STDOUT,text=True)
                assert 'auto-tuning calculated' in logs, logs
            print('PASS:',image,mode,'512 MiB / 1 CPU, real PHP request',flush=True)
        except Exception:
            subprocess.run(docker+['logs',container],check=False)
            raise
        finally: subprocess.run(docker+['rm','-f',container],stdout=subprocess.DEVNULL,check=True)
