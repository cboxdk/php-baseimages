#!/usr/bin/env python3
"""Locked PHP source builds on Trixie, including the separate 8.6 preview lane."""
import argparse
import json
from pathlib import Path
import re
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
SERIES = ('8.2', '8.3', '8.4', '8.5', '8.6')
LOCK = ROOT / 'php-source/php85-trixie.lock.json'


def lock_path(series):
    if series not in SERIES:
        raise ValueError(f'No source lane for PHP {series}')
    return ROOT / f'php-source/php{series.replace(".", "")}-trixie.lock.json'


def version_key(version, series, channel):
    pattern = re.escape(series) + (r'\.(\d+)' if channel == 'stable' else r'\.0(alpha|beta|RC)(\d+)')
    match = re.fullmatch(pattern, version)
    if not match:
        raise ValueError(f'Expected a {channel} PHP {series} release: {version!r}')
    return (int(match[1]),) if channel == 'stable' else ({'alpha': 0, 'beta': 1, 'RC': 2}[match[1]], int(match[2]))


def validate_lock(lock):
    series, channel = lock['series'], lock['channel']
    if series not in SERIES or channel != ('preview' if series == '8.6' else 'stable'):
        raise ValueError('Unsupported source lane/channel')
    version_key(lock['version'], series, channel)
    for key, length in [('sha256', 64), ('docker_library_commit', 40)]:
        if not re.fullmatch('[0-9a-f]{%d}' % length, lock[key]):
            raise ValueError(f'Invalid {key}')
    suffix = re.escape(f'php-{lock["version"]}.tar.xz')
    prefix = r'https://www\.php\.net/distributions/' if channel == 'stable' else r'https://downloads\.php\.net/(?:~[a-zA-Z0-9_-]+/)?'
    if not re.fullmatch(prefix + suffix, lock['url']):
        raise ValueError('Source URL must be the matching official PHP archive')
    return lock


def read_lock(path=LOCK):
    return validate_lock(json.loads(Path(path).read_text()))


def patch_candidate(lock, release):
    version = release['version']
    new = version_key(version, lock['series'], lock['channel'])
    if new <= version_key(lock['version'], lock['series'], lock['channel']):
        return None
    if lock['channel'] == 'preview':
        archive = release['files']['xz']
        url, sha256 = archive['path'], archive['sha256']
    else:
        archive = next(s for s in release['source'] if s['filename'] == f'php-{version}.tar.xz')
        url, sha256 = f'https://www.php.net/distributions/php-{version}.tar.xz', archive['sha256']
    return validate_lock({**lock, 'version': version, 'url': url, 'sha256': sha256})


def preview_release(document, lock):
    # php.net currently returns a map with nested `release` objects; its newer
    # `releases` map/array is also supported. Disabled entries are not candidates.
    if 'releases' in document:
        entries = document['releases']
        if isinstance(entries, dict):
            entries = entries.values()
    else:
        entries = [v.get('release', {}) for v in document.values() if isinstance(v, dict) and v.get('active', True)]
    candidates = []
    for release in entries:
        if release.get('enabled') is False:
            continue
        try:
            key = version_key(release.get('version', ''), lock['series'], 'preview')
        except ValueError:
            continue
        candidates.append((key, release))
    return max(candidates, key=lambda item: item[0])[1] if candidates else None


def fetch_release(lock):
    url = ('https://www.php.net/pre-release-builds.php?format=json' if lock['channel'] == 'preview'
           else 'https://www.php.net/releases/index.php?json&version=' + lock['series'])
    with urllib.request.urlopen(url, timeout=30) as response:
        return json.load(response)


def runtime_dockerfile(variant, lock):
    text = (ROOT / f'php-source/upstream/{lock["series"]}/{variant}.Dockerfile').read_text()
    if text.count('FROM debian:trixie-slim') != 1:
        raise ValueError('Source recipe must have exactly one Debian Trixie base')
    text = re.sub(r'^ENV PHP_VERSION[ =].*$', f"ENV PHP_VERSION={lock['version']}", text, flags=re.M)
    text = re.sub(r'^ENV PHP_URL=.*$', f'ENV PHP_URL="{lock["url"]}" PHP_ASC_URL="{lock["url"]}.asc"', text, flags=re.M)
    text = re.sub(r'^ENV PHP_SHA256=.*$', f'ENV PHP_SHA256="{lock["sha256"]}"', text, flags=re.M)
    text = text.replace('FROM debian:trixie-slim', 'FROM debian:trixie-slim AS php-source-runtime\n'
                        'ARG CACHE_REFRESH=local\n'
                        'RUN echo "$CACHE_REFRESH" >/dev/null && apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*')
    # Retain upstream SHA256 + GPG verification; PECL availability must not block a build.
    text = text.replace('pecl update-channels;', ':;')
    text = text.replace("PHP_BUILD_PROVIDER='https://github.com/docker-library/php'", "PHP_BUILD_PROVIDER='https://github.com/cboxdk/php-baseimages'")
    text = re.sub(r'^COPY (.+) /usr/local/bin/$',
                  lambda m: 'COPY ' + ' '.join('php-source/upstream/' + s for s in m[1].split()) + ' /usr/local/bin/',
                  text, flags=re.M)
    return text


def render(image, lock):
    if image in ('cli', 'fpm'):
        return runtime_dockerfile(image, lock)
    preview = image in ('php86-base', 'php86-fpm')
    if (lock['channel'] == 'preview') != preview:
        raise ValueError('8.6 must use the separate preview image lane')
    original = (ROOT / ('php-base/Dockerfile.php86-beta' if preview else image + '/Dockerfile')).read_text()
    original = re.sub(r'^ARG PHP_VERSION=.*$', f'ARG PHP_VERSION={lock["series"]}', original, count=1, flags=re.M)
    if image not in ('php-base', 'php-fpm', 'php86-base', 'php86-fpm'):
        return re.sub(r'^(FROM ghcr.io/cboxdk/php-baseimages/.*)$',
                      lambda m: m[0] + '\nRUN test "$(php -r \'echo PHP_VERSION;\')" = "' + lock['version'] + '"',
                      original, flags=re.M)
    variant = 'fpm' if image == 'php-fpm' else 'cli'
    first_from = original.index('\nFROM ')
    globals_, body = original[:first_from], original[first_from:]
    body = body.replace(f'FROM php:${{PHP_VERSION}}-{variant}-trixie ', 'FROM php-source-runtime ')
    if image == 'php-fpm':
        body = re.sub(r'^(FROM .* AS base-(?:slim|standard|chromium|dev))$',
                      lambda m: m[0] + '\nRUN test "$(php -r \'echo PHP_VERSION;\')" = "' + lock['version'] + '"', body, flags=re.M)
    runtime = runtime_dockerfile(variant, lock)
    if image == 'php86-fpm':
        # Keep the preview's extensions and runtime libraries; add the matching
        # FPM binary/config. Both runtimes use their version-specific official
        # recipes (8.6 is ZTS), and the same archive, flags and extension ABI.
        runtime += '\n' + runtime_dockerfile('fpm', lock).replace('AS php-source-runtime', 'AS php-source-fpm')
        for tier in ('slim', 'standard', 'chromium', 'dev'):
            body += f'''\nFROM beta-{tier} AS beta-fpm-{tier}
COPY --from=php-source-fpm /usr/local/sbin/php-fpm /usr/local/sbin/php-fpm
COPY --from=php-source-fpm /usr/local/etc/php-fpm.conf /usr/local/etc/php-fpm.conf
COPY --from=php-source-fpm /usr/local/etc/php-fpm.d/ /usr/local/etc/php-fpm.d/
COPY --from=php-source-fpm /usr/local/etc/php/conf.d/docker-fpm.ini /usr/local/etc/php/conf.d/docker-fpm.ini
RUN php-fpm -t
WORKDIR /var/www/html
EXPOSE 9000
STOPSIGNAL SIGQUIT
CMD ["php-fpm"]
'''
    return globals_ + '\n' + runtime + '\n' + body


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--series', choices=SERIES, default='8.5')
    parser.add_argument('--lock', type=Path)
    sub = parser.add_subparsers(dest='command', required=True)
    sub.add_parser('version')
    sub.add_parser('supported')
    check = sub.add_parser('check')
    check.add_argument('--release-json', type=Path)
    check.add_argument('--apply', action='store_true')
    build = sub.add_parser('render')
    build.add_argument('image', choices=['cli', 'fpm', 'php-base', 'php-fpm', 'php-cli', 'php-fpm-nginx', 'php86-base', 'php86-fpm'])
    build.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    path = args.lock or lock_path(args.series)
    lock = read_lock(path)
    if args.command == 'supported':
        print(' '.join(SERIES))
    elif args.command == 'version':
        print(lock['version'])
    elif args.command == 'render':
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(render(args.image, lock))
    else:
        release = json.loads(args.release_json.read_text()) if args.release_json else fetch_release(lock)
        if lock['channel'] == 'preview':
            release = preview_release(release, lock)
        candidate = patch_candidate(lock, release) if release else None
        if candidate and args.apply:
            path.write_text(json.dumps(candidate, indent=2) + '\n')
        print('changed=' + str(candidate is not None).lower())
        print('version=' + (candidate or lock)['version'])


if __name__ == '__main__':
    main()
