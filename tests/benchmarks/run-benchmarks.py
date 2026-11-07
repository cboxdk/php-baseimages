#!/usr/bin/env python3
"""Measure a local PHP/FPM/Nginx image; missing images or failed requests fail CI."""
import http.client
import json
import os
from pathlib import Path
import statistics
import subprocess
import tempfile
import time
import urllib.error
import urllib.request


def docker(*args):
    return subprocess.check_output(['docker', *args], text=True).strip()


def main():
    image = os.environ.get('BENCHMARK_IMAGE', 'cbox-trixie')
    metadata = json.loads(docker('image', 'inspect', image))[0]  # Never silently pull.
    env = dict(entry.split('=', 1) for entry in metadata['Config'].get('Env', []))
    port = env.get('NGINX_HTTP_PORT', '8080' if env.get('CBOX_ROOTLESS') == 'true' else '80')
    result = {'image': image, 'image_id': metadata['Id'], 'image_bytes': metadata['Size'],
              'startup_seconds': [], 'http_seconds': [], 'php_cpu_seconds': [],
              'limitations': 'Shared CI runner; serial HTTP and CLI CPU smoke measurements, not production capacity or a cross-OS comparison.'}
    program = '$t=hrtime(true);$n=0;for($i=0;$i<500000;$i++){$n+=strlen(hash("sha256",(string)$i));}echo json_encode(["seconds"=>(hrtime(true)-$t)/1e9,"checksum"=>$n,"php"=>PHP_VERSION]);'
    for _ in range(3):
        cpu = json.loads(docker('run', '--rm', '--pull=never', '--entrypoint', 'php', image,
                                '-d', 'opcache.enable_cli=0', '-r', program))
        if cpu['checksum'] != 32000000:
            raise RuntimeError('Incorrect PHP benchmark result')
        result['php'] = cpu['php']
        result['php_cpu_seconds'].append(cpu['seconds'])
    with tempfile.TemporaryDirectory() as tmp:
        fixture = Path(tmp) / 'benchmark.php'
        fixture.write_text('<?php header("Content-Type: application/json"); echo json_encode(["benchmark"=>"ok"]);')
        for run in range(3):
            container = docker('create', '--pull=never', '--memory', '512m', '--cpus', '1',
                               '-p', f'127.0.0.1::{port}', image)
            try:
                docker('cp', str(fixture), container + ':/var/www/html/public/benchmark.php')
                started = time.monotonic()
                docker('start', container)
                mapped = docker('port', container, port + '/tcp').splitlines()[0]
                url = 'http://' + mapped + '/benchmark.php'
                def request():
                    with urllib.request.urlopen(url, timeout=3) as response:
                        if json.load(response) != {'benchmark': 'ok'}:
                            raise RuntimeError('HTTP benchmark did not execute the PHP fixture')
                deadline = started + 60
                while True:
                    try:
                        request()
                        break
                    except (urllib.error.URLError, ConnectionError, http.client.HTTPException):
                        if time.monotonic() >= deadline:
                            raise RuntimeError('PHP failed to become ready within 60 seconds')
                        time.sleep(0.1)
                result['startup_seconds'].append(time.monotonic() - started)
                if run == 0:
                    for _ in range(50):
                        tick = time.monotonic()
                        request()
                        result['http_seconds'].append(time.monotonic() - tick)
            finally:
                docker('rm', '-f', container)
    for key in ('startup_seconds', 'http_seconds', 'php_cpu_seconds'):
        result[key + '_median'] = statistics.median(result[key])
    output = Path(os.environ.get('BENCHMARK_RESULTS_DIR', 'tests/benchmarks/results'))
    output.mkdir(parents=True, exist_ok=True)
    (output / 'benchmark.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
