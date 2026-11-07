#!/usr/bin/env python3
"""Local production matrix, including all tiers/users, without registry writes."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import shlex
import subprocess

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('source', ROOT / 'scripts/php-source.py')
source = importlib.util.module_from_spec(spec)
spec.loader.exec_module(source)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--series', default='8.5', choices=['8.2', '8.3', '8.4', '8.5'])
    parser.add_argument('--platform', default='linux/arm64', choices=['linux/arm64', 'linux/amd64'])
    parser.add_argument('--tiers', nargs='+', default=['slim', 'standard', 'chromium', 'dev'])
    parser.add_argument('--image-types', nargs='+', choices=['php-base', 'php-cli', 'php-fpm', 'php-fpm-nginx'], default=['php-base', 'php-cli', 'php-fpm', 'php-fpm-nginx'])
    args = parser.parse_args()
    os.chdir(ROOT)
    docker = ['docker', '--context', os.environ.get('DOCKER_CONTEXT', 'orbstack')]
    directory = ROOT / '.build/v2' / args.series / args.platform.split('/')[1]
    directory.mkdir(parents=True, exist_ok=True)
    versions = json.loads((ROOT / 'versions.json').read_text())
    build_args = ['--build-arg', 'PHP_VERSION=' + args.series]
    lifecycle = json.loads(subprocess.check_output(['bash', 'scripts/get-build-state.sh', args.series, 'trixie'], text=True))
    lifecycle_args = {'CBOX_LIFECYCLE': lifecycle['lifecycle'], 'CBOX_PHP_VERSION': args.series,
                       'CBOX_PHP_EOL': lifecycle['php_eol'], 'CBOX_REMOVAL_DATE': lifecycle['removal_date'],
                       'CBOX_PREVIEW_STATUS': lifecycle.get('preview_status', '')}
    for key, value in lifecycle_args.items():
        build_args += ['--build-arg', key + '=' + value]
    for group in ['extensions', 'tools']:
        for key, value in versions[group].items():
            if isinstance(value, str) and not key.endswith('sha256'):
                build_args += ['--build-arg', f'{key.upper()}_VERSION={value}']
    build_args += ['--build-arg', 'NODE_VERSION=' + versions['node']['version']]
    lock = source.read_lock(source.lock_path(args.series))
    def tag(image, target):
        return f'cbox-v2:{args.series}-{args.platform.split("/")[1]}-{image}-{target}'
    for image in args.image_types:
        text = source.render(image, lock)
        def local_parent(match):
            parent, tier, rootless = match.groups()
            target = (tier + '-' if tier else '') + ('rootless' if rootless else 'root')
            return f'FROM {tag(parent, target)} AS base-{tier or "standard"}' + ('-rootless' if rootless else '')
        text = re.sub(r'FROM ghcr.io/cboxdk/php-baseimages/(php-base|php-fpm):\$\{PHP_VERSION\}-trixie(?:-(slim|chromium|dev))?(-rootless)?\$\{BASE_CHANNEL\} AS base-[\w-]+', local_parent, text)
        path = directory / (image + '.Dockerfile')
        path.write_text(text)
        for tier in args.tiers:
            for user in ['root', 'rootless']:
                target = ('' if tier == 'standard' else tier + '-') + user
                reference = tag(image, target)
                subprocess.run(docker + ['build', '--platform', args.platform, '--target', target, '-f', str(path), '-t', reference, *build_args, '.'], check=True)
                command = 'test "$(php -r \'echo PHP_VERSION;\')" = ' + lock['version'] + '; php -m; composer --version; test "$(id -u)" = ' + ('0' if user == 'root' else '33')
                for key, value in lifecycle_args.items():
                    command += '; test "$' + key + '" = ' + shlex.quote(value)
                required = ['Zend OPcache', 'redis', 'apcu', 'msgpack', 'pdo_mysql', 'pdo_pgsql', 'mysqli',
                            'pgsql', 'zip', 'intl', 'bcmath', 'gd', 'exif', 'pcntl', 'sockets', 'bz2', 'gmp', 'mbstring']
                if tier != 'slim':
                    required += ['imagick', 'mongodb', 'soap', 'ldap', 'xsl']
                if tier == 'dev':
                    required += ['xdebug', 'pcov', 'spx']
                check = 'foreach (' + json.dumps(required) + ' as $ext) { if (!extension_loaded($ext)) { fwrite(STDERR, "Missing extension: ".$ext); exit(1); } }'
                command += '; php -r ' + shlex.quote(check)
                if tier != 'slim':
                    command += "; php -r " + shlex.quote('if (!extension_loaded("imagick")) exit(1); foreach (["png","jpeg","webp","avif","heic"] as $format) { $im=new Imagick(); $im->newImage(8,8,"white"); $im->setImageFormat($format); $decoded=new Imagick(); $decoded->readImageBlob($im->getImageBlob()); if ($decoded->getImageWidth() !== 8) exit(1); }')
                    command += '; test -s /etc/ImageMagick-7/policy.xml'
                    command += '; test \"$(npm --version)\" = ' + versions['tools']['npm']
                    command += '; test \"$(node --version)\" = v' + versions['node']['version']
                command += '; test "$(. /etc/os-release; echo "$VERSION_CODENAME")" = trixie'
                subprocess.run(docker + ['run', '--rm', '--platform', args.platform, '--entrypoint', 'sh', reference, '-ec', command], check=True)
                if image == 'php-fpm-nginx':
                    subprocess.run(['bash', 'scripts/test-runtime-image.sh', reference, lock['version'], tier, image], env={**os.environ, 'DOCKER_CONTEXT': os.environ.get('DOCKER_CONTEXT', 'orbstack')}, check=True)
                if image == 'php-fpm':
                    fixture = directory / 'source-smoke.php'
                    fixture.write_text('<?php echo PHP_VERSION, ":", bcadd("1", "2");')
                    container = subprocess.check_output(docker + ['run', '-d', '--platform', args.platform, '-p', '127.0.0.1::9000', reference], text=True).strip()
                    try:
                        subprocess.run(docker + ['cp', str(fixture), container + ':/var/www/html/source-smoke.php'], check=True)
                        port = subprocess.check_output(docker + ['port', container, '9000/tcp'], text=True).strip().rsplit(':', 1)[1]
                        subprocess.run(['python3', 'tests/php-source-fastcgi.py', port, lock['version']], check=True)
                    except Exception:
                        subprocess.run(docker + ['logs', container], check=False)
                        raise
                    finally:
                        subprocess.run(docker + ['rm', '-f', container], check=True)
                print('PASS:', reference, flush=True)


if __name__ == '__main__':
    main()
