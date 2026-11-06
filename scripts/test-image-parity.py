#!/usr/bin/env python3
"""Compare an existing v1 image with its local replacement; never pull or publish."""
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

PHP = 'echo json_encode(["version"=>PHP_VERSION,"zts"=>PHP_ZTS,"sapi"=>PHP_SAPI,"uid"=>posix_geteuid(),"extensions"=>get_loaded_extensions(),"ini"=>ini_get_all(null,false)],JSON_THROW_ON_ERROR);'
CONFIG = ['User', 'WorkingDir', 'Entrypoint', 'Cmd', 'ExposedPorts', 'Healthcheck', 'StopSignal', 'Volumes']
# Engine patch metadata legitimately changes on a security update. Lifecycle
# notices are reported separately; they are CI build arguments, not PHP config.
METADATA_ENV = {'PHP_VERSION', 'PHP_SHA256', 'PHP_URL', 'PHP_ASC_URL', 'GPG_KEYS',
                'CBOX_LIFECYCLE', 'CBOX_PHP_VERSION', 'CBOX_PHP_EOL', 'CBOX_REMOVAL_DATE', 'CBOX_PREVIEW_STATUS'}


def runtime_diff(old, new):
    differences = {}
    for field in ['zts', 'sapi', 'uid']:
        if old[field] != new[field]: differences[field] = [old[field], new[field]]
    if old['version'].rsplit('.', 1)[0] != new['version'].rsplit('.', 1)[0]:
        differences['php_series'] = [old['version'], new['version']]
    missing = sorted(set(old['extensions']) - set(new['extensions']))
    if missing: differences['missing_extensions'] = missing
    ini = {key: [value, new['ini'].get(key)] for key, value in old['ini'].items() if new['ini'].get(key) != value}
    if ini: differences['ini'] = ini
    return differences


def capture(docker, image, with_http):
    inspected = json.loads(subprocess.check_output(docker + ['image', 'inspect', image], text=True))[0]
    result = {'image': image, 'id': inspected['Id'], 'digests': inspected.get('RepoDigests', []),
              'config': inspected['Config']}
    result['cli'] = json.loads(subprocess.check_output(docker + ['run', '--rm', '--entrypoint', 'php', image, '-r', PHP], text=True))
    if with_http:
        env = dict(value.split('=', 1) for value in inspected['Config'].get('Env', []))
        port = env.get('NGINX_HTTP_PORT', '8080' if env.get('CBOX_ROOTLESS') == 'true' else '80')
        container = subprocess.check_output(docker + ['run', '-d', '--memory', '512m', '--cpus', '1',
                                                     '-e', 'PHP_FPM_MAX_CHILDREN=10', '-p', '127.0.0.1::' + port, image], text=True).strip()
        try:
            with tempfile.TemporaryDirectory() as tmp:
                fixture = Path(tmp) / '__cbox_parity.php'
                fixture.write_text('<?php ' + PHP)
                fixture.chmod(0o644)
                subprocess.run(docker + ['cp', str(fixture), container + ':/var/www/html/public/__cbox_parity.php'], check=True)
            address = subprocess.check_output(docker + ['port', container, port + '/tcp'], text=True).strip()
            url = 'http://' + address + '/__cbox_parity.php'
            for attempt in range(30):
                try:
                    with urllib.request.urlopen(url, timeout=3) as response:
                        result['fpm'] = json.load(response)
                    break
                except (urllib.error.URLError, TimeoutError, ConnectionError, http.client.HTTPException):
                    if attempt == 29: raise
                    time.sleep(1)
        except Exception:
            subprocess.run(docker + ['logs', container], check=False)
            raise
        finally:
            subprocess.run(docker + ['rm', '-f', container], stdout=subprocess.DEVNULL, check=True)
    return result


def compare(old, new):
    differences = {'cli': runtime_diff(old['cli'], new['cli'])}
    if 'fpm' in old: differences['fpm'] = runtime_diff(old['fpm'], new['fpm'])
    differences['container'] = {key: [old['config'].get(key), new['config'].get(key)] for key in CONFIG
                                if old['config'].get(key) != new['config'].get(key)}
    envs = [dict(item.split('=', 1) for item in image['config'].get('Env', [])) for image in (old, new)]
    env_diff = {key: [envs[0].get(key), envs[1].get(key)] for key in envs[0].keys() | envs[1].keys()
                if envs[0].get(key) != envs[1].get(key)}
    differences['environment'] = {key: value for key, value in env_diff.items() if key not in METADATA_ENV}
    return differences, {key: value for key, value in env_diff.items() if key in METADATA_ENV}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('old')
    parser.add_argument('new')
    parser.add_argument('--http', action='store_true', help='Also test effective FPM config via a real HTTP request')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    docker = ['docker', '--context', os.environ.get('DOCKER_CONTEXT', 'orbstack')]
    old, new = [capture(docker, image, args.http) for image in (args.old, args.new)]
    differences, metadata = compare(old, new)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps({'old': old, 'new': new, 'differences': differences, 'metadata_changes': metadata}, indent=2) + '\n')
    print(json.dumps(differences, indent=2))
    raise SystemExit(int(any(differences.values())))


if __name__ == '__main__':
    main()
