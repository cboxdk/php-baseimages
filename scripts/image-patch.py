#!/usr/bin/env python3
"""Select a digest-pinned OS-only update when all non-OS build inputs match."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time
import sys
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
PREFIX = 'io.cbox.build.'
MAX_DEPTH = 16
MAX_AGE = 30 * 86400


def lifecycle_state(series):
    state = json.loads(subprocess.check_output(['bash', str(ROOT / 'scripts/get-build-state.sh'), series, 'trixie'], cwd=ROOT))
    return {key: state.get(key) for key in ('lifecycle', 'php_eol', 'removal_date', 'status')}


def fingerprint(image_type, series, target, tier, suffix, platform, build_args=''):
    directories = {'common', 'php-base', image_type}
    if image_type == 'php-fpm-nginx':
        directories.update({'php-fpm', 'nginx'})
    paths = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'], cwd=ROOT).decode().split('\0')
    selected = []
    for name in set(paths):
        if not name or not (ROOT / name).is_file():
            continue
        parts = Path(name).parts
        include = parts[0] in directories
        if parts[0] == 'php-source':
            include = (name == f'php-source/php{series.replace(".", "")}-trixie.lock.json'
                       or name.startswith(f'php-source/upstream/{series}/')
                       or (len(parts) == 3 and parts[1] == 'upstream'))
        include |= name in {'scripts/php-source.py', 'scripts/pin-source-parents.py', 'scripts/test-runtime-image.sh', 'scripts/image-patch.py', 'scripts/get-build-state.sh', '.github/workflows/_build-image.yml', '.dockerignore', '.trivyignore'}
        if name.endswith('.md') or name == 'php-base/Dockerfile.php86-beta':
            include = False
        if include:
            selected.append(name)
    versions = json.loads((ROOT / 'versions.json').read_text())
    # latest_patch is an advisory inventory, not a compiler input. The per-series
    # source lock is included above; another PHP series must not invalidate us.
    versions.pop('_meta', None)
    versions.get('release', {}).pop('_policy', None)
    php = versions.pop('php')
    versions['php_channels'] = {key: php.get(key) for key in ('supported', 'default', 'newest')}
    versions['php'] = {key: value.get(series) for key, value in php.items() if isinstance(value, dict) and key != 'latest_patch'}
    lifecycle = lifecycle_state(series)
    identity = [image_type, series, target, tier, suffix, platform, build_args, versions, lifecycle]
    digest = hashlib.sha256(json.dumps(identity, sort_keys=True).encode())
    for name in sorted(selected):
        digest.update(name.encode() + b'\0' + (ROOT / name).read_bytes() + b'\0')
    return digest.hexdigest()


def decide(config, expected, php_version, architecture, now):
    labels = config.get('config', {}).get('Labels') or {}
    if config.get('architecture') != architecture or config.get('os') != 'linux':
        return False, 'platform differs'
    if labels.get(PREFIX + 'debian-suite') != 'trixie':
        return False, 'Debian suite changed or is unrecorded'
    if labels.get(PREFIX + 'fingerprint') != expected:
        return False, 'build inputs changed or image predates input labels'
    if labels.get(PREFIX + 'php-version') != php_version:
        return False, 'PHP source lock changed'
    try:
        depth = int(labels[PREFIX + 'patch-depth'])
        full_at = int(labels[PREFIX + 'full-built-at'])
    except (ValueError, KeyError, TypeError):
        return False, 'missing or invalid patch history'
    if not 0 <= depth < MAX_DEPTH:
        return False, 'patch-layer limit reached'
    if not 0 <= now - full_at < MAX_AGE:
        return False, 'full build is due'
    user = config.get('config', {}).get('User') or 'root'
    if not re.fullmatch(r'[a-zA-Z0-9_.-]+(?::[a-zA-Z0-9_.-]+)?', user):
        return False, 'unsupported image user'
    return True, 'same PHP, extensions, configuration and build inputs'


def patch_dockerfile(reference, user, target):
    # The CI caller supplies a validated immutable manifest digest. Local tests
    # may explicitly pass a local tag, but prepare() never emits a mutable FROM.
    if not re.fullmatch(r'[a-zA-Z0-9_./:@-]+', reference):
        raise ValueError('Invalid image reference')
    if not re.fullmatch(r'[a-zA-Z0-9_.-]+(?::[a-zA-Z0-9_.-]+)?', user):
        raise ValueError('Invalid user')
    if not re.fullmatch(r'[a-zA-Z0-9_-]+', target):
        raise ValueError('Invalid target')
    return f'''FROM {reference} AS {target}
USER root
ARG CACHE_REFRESH
# Keep the filesystem and application toolchain; upgrade only installed Debian
# packages. Failure is fatal. Restore the original user, including rootless.
RUN test -n "$CACHE_REFRESH" && apt-get -o APT::Update::Error-Mode=any update && DEBIAN_FRONTEND=noninteractive apt-get \
    -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold upgrade --with-new-pkgs -y \\
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*.deb
USER {user}
'''


def remote_config(reference, architecture):
    def inspect(*args):
        return json.loads(subprocess.check_output(['docker', 'buildx', 'imagetools', 'inspect', reference, *args], stderr=subprocess.PIPE, text=True))
    index = inspect('--raw')
    candidates = [m['digest'] for m in index.get('manifests', [])
                  if m.get('platform', {}).get('os') == 'linux'
                  and m.get('platform', {}).get('architecture') == architecture]
    if len(candidates) != 1 or not re.fullmatch(r'sha256:[0-9a-f]{64}', candidates[0]):
        raise ValueError('Published multi-arch manifest has no unique target platform')
    repository = reference.rsplit(':', 1)[0]
    extra = [m['digest'] for m in index.get('manifests', [])
             if m.get('annotations', {}).get('vnd.docker.reference.digest') == candidates[0]
             and m.get('annotations', {}).get('vnd.docker.reference.type') == 'attestation-manifest']
    if not all(re.fullmatch(r'sha256:[0-9a-f]{64}', digest) for digest in extra):
        raise ValueError('Invalid attestation digest')
    reference = repository + '@' + candidates[0]
    # Config-only registry reads; do not download image layers merely to decide.
    config = inspect('--format', '{{json .Image}}')
    if not isinstance(config, dict):
        raise ValueError('Missing platform image configuration')
    return reference, config, extra


def probe_updates(reference, platform):
    """True: patch; False: reuse; None: packages held back, rebuild fully."""
    # Reuse a byte-identical publication when Debian has nothing to install.
    # Never accept partial/stale apt indexes as evidence that no fixes exist.
    command = '''set -eu
export LC_ALL=C
apt-get -o APT::Update::Error-Mode=any update -qq
plan=$(apt-get -s --with-new-pkgs upgrade)
if printf '%s\n' "$plan" | grep -Eq '[1-9][0-9]* not upgraded[.]'; then
    echo CBOX_OS_UPDATES=full
elif printf '%s\n' "$plan" | grep -q '^Inst '; then
    echo CBOX_OS_UPDATES=1
else
    echo CBOX_OS_UPDATES=0
fi'''
    result = subprocess.check_output(['docker', 'run', '--rm', '--platform', platform,
                                      '--user', '0', '--entrypoint', 'sh', reference, '-c', command], text=True)
    marker = result.strip().splitlines()[-1]
    if marker not in ('CBOX_OS_UPDATES=0', 'CBOX_OS_UPDATES=1', 'CBOX_OS_UPDATES=full'):
        raise ValueError('APT probe returned no trustworthy result')
    return None if marker.endswith('full') else marker.endswith('1')


def repository_revision():
    # Cheap scheduler signal: package-index hashes, not InRelease timestamps or
    # signatures (which rotate without package changes). APT still verifies the
    # signed indexes itself before any package is installed.
    revisions = []
    security = []
    for suite, base in [('trixie', 'https://deb.debian.org/debian'),
                        ('trixie-updates', 'https://deb.debian.org/debian'),
                        ('trixie-security', 'https://security.debian.org/debian-security')]:
        with urllib.request.urlopen(f'{base}/dists/{suite}/InRelease', timeout=30) as response:
            release = response.read().decode()
        hashes = re.findall(r'^ ([0-9a-f]{64}) +[0-9]+ +(main/binary-(?:amd64|arm64)/Packages\.xz)$', release, re.M)
        if len(hashes) != 2:
            raise ValueError(f'Missing Debian package-index hashes for {suite}')
        revisions.extend(suite + ':' + name + ':' + digest for digest, name in hashes)
        if suite == 'trixie-security':
            security = sorted(name + ':' + digest for digest, name in hashes)
    # Calendar transitions must not wait for a Debian package change. Exclude
    # daily countdowns: only effective lifecycle/expiry state changes matter.
    versions = json.loads((ROOT / 'versions.json').read_text())
    revisions.append(json.dumps({series: lifecycle_state(series) for series in versions['php']['supported']}, sort_keys=True))
    combined = hashlib.sha256('\n'.join(sorted(revisions)).encode()).hexdigest()
    urgent = hashlib.sha256('\n'.join(security).encode()).hexdigest()
    return combined + '.' + urgent


def main():
    if sys.argv[1:] == ['os-revision']:
        print(repository_revision())
        return
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--image-type', required=True, choices=['php-base', 'php-fpm', 'php-cli', 'php-fpm-nginx'])
    parser.add_argument('--series', required=True)
    parser.add_argument('--target', required=True)
    parser.add_argument('--tier', required=True)
    parser.add_argument('--suffix', default='')
    parser.add_argument('--platform', required=True, choices=['linux/amd64', 'linux/arm64'])
    parser.add_argument('--repository', default='cboxdk/php-baseimages')
    parser.add_argument('--build-args', default='')
    parser.add_argument('--force-full', action='store_true')
    parser.add_argument('--output', type=Path, default=ROOT / '.build/os-patch.Dockerfile')
    args = parser.parse_args()
    now = int(time.time())
    expected = fingerprint(args.image_type, args.series, args.target, args.tier, args.suffix, args.platform, args.build_args)
    result = {'mode': 'full', 'reason': 'no eligible previous publication', 'fingerprint': expected,
              'depth': 0, 'full_built_at': now, 'php_version': '', 'dockerfile': '', 'digest': '', 'extra_digests': ''}
    lock = ROOT / f'php-source/php{args.series.replace(".", "")}-trixie.lock.json'
    if lock.exists():
        result['php_version'] = json.loads(lock.read_text())['version']
    if result['php_version'] and args.series != '8.6' and not args.force_full:
        versions = json.loads((ROOT / 'versions.json').read_text())
        channel = versions['release']['channel']
        suffix = '-' + args.suffix if args.suffix else ''
        reference = f'ghcr.io/{args.repository}/{args.image_type}:{args.series}-trixie{suffix}-v{channel}'
        try:
            reference, config, extra = remote_config(reference, args.platform.split('/')[1])
            patch, reason = decide(config, expected, result['php_version'], args.platform.split('/')[1], now)
            result['reason'] = reason
            if patch:
                labels = config['config']['Labels']
                args.output.parent.mkdir(parents=True, exist_ok=True)
                args.output.write_text(patch_dockerfile(reference, config['config'].get('User') or 'root', args.target))
                result.update(mode='patch', depth=int(labels[PREFIX + 'patch-depth']) + 1,
                              full_built_at=int(labels[PREFIX + 'full-built-at']), dockerfile=str(args.output))
        except (subprocess.CalledProcessError, ValueError, KeyError, TypeError) as error:
            result['reason'] = f'previous publication unavailable or invalid ({type(error).__name__}); full build'
    if result['mode'] == 'patch':
        updates = probe_updates(reference, args.platform)
        if updates is None:
            result.update(mode='full', reason='APT kept packages back; rebuild from source',
                          depth=0, full_built_at=now, dockerfile='')
        elif not updates:
            result.update(mode='reuse', reason='no Debian packages to upgrade; reuse verified bytes',
                          depth=result['depth'] - 1, dockerfile='', digest=reference.split('@')[1],
                          extra_digests=' '.join(extra))
    for key, value in result.items():
        print(f'{key}={value}')


if __name__ == '__main__':
    main()
