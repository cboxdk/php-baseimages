#!/usr/bin/env python3
"""Retry incomplete chains; a successful base alone is not a publication."""
import datetime
import hashlib
import json
import os
import subprocess
import time


def timestamp(run):
    return datetime.datetime.fromisoformat(run['createdAt'].replace('Z', '+00:00')).timestamp()


def matching(runs, title, sha=None):
    return sorted((r for r in runs if (r['displayTitle'] == title or r['displayTitle'].startswith(title + ' '))
                   and (sha is None or r['displayTitle'].endswith('source:' + sha))), key=timestamp, reverse=True)


def should_dispatch(series, runs, children, sha, revision, now):
    preview = series == '8.6'
    candidates = matching(runs, 'Build PHP 8.6 preview' if preview else f'Build PHP base ({series})')
    if not preview:
        candidates += matching(runs, 'Build PHP base (all)')
        candidates.sort(key=timestamp, reverse=True)
    if not candidates:
        return True
    latest = candidates[0]
    if latest['status'] != 'completed':
        return False
    if latest['conclusion'] != 'success':
        # Three failures against identical inputs should not consume a cold
        # source build every hour indefinitely. New source/OS inputs retry now.
        failures = candidates[:3]
        repeated = len(failures) == 3 and all(
            r['status'] == 'completed' and r['conclusion'] != 'success'
            and (preview or r['displayTitle'].endswith(' OS:' + revision)) for r in failures)
        return not repeated or now - timestamp(latest) >= 21600
    age = now - timestamp(latest)
    if preview:
        return age >= 604800
    # A base completion dispatches children asynchronously. Allow propagation,
    # but never let a failed child hide behind a successful base publication.
    incomplete = False
    for variant, child_runs in children.items():
        child = matching(child_runs, f'Build PHP {variant} ({series})', sha)
        child += matching(child_runs, f'Build PHP {variant} (all)', sha)
        child = sorted((r for r in child if timestamp(r) >= timestamp(latest)), key=timestamp, reverse=True)
        if not child:
            incomplete |= age >= 3600
            continue
        if child[0]['status'] != 'completed':
            return False
        incomplete |= child[0]['conclusion'] != 'success'
    if incomplete:
        # Retry child failures, but stop an unchanged broken chain consuming
        # the entire matrix every hour. The next source/security change wins.
        recent = candidates[:3]
        repeated = len(recent) == 3 and all(r['displayTitle'].endswith(' OS:' + revision) for r in recent)
        return not repeated or age >= 21600
    previous_revision = latest['displayTitle'].rsplit(' OS:', 1)[-1]
    # Security fixes bypass the ordinary six-hour budget limit. Stable/main
    # package churn still uses the slower cadence; no package change is a no-op.
    security_changed = '.' in revision and revision.rsplit('.', 1)[-1] != previous_revision.rsplit('.', 1)[-1]
    return security_changed or (age >= 21600 and not (age < 2592000 and previous_revision == revision))


def should_dispatch_nginx(runs, revision, now):
    candidates = matching(runs, 'Build Nginx')
    if not candidates:
        return True
    latest = candidates[0]
    if latest['status'] != 'completed':
        return False
    age = now - timestamp(latest)
    previous = latest['displayTitle'].rsplit(' OS:', 1)[-1]
    if latest['conclusion'] != 'success':
        same_failures = len(candidates) >= 3 and all(r['conclusion'] != 'success' and r['displayTitle'].endswith(' OS:' + revision) for r in candidates[:3])
        return not same_failures or age >= 21600
    if previous == revision:
        return age >= 2592000
    return previous.rsplit('.', 1)[-1] != revision.rsplit('.', 1)[-1] or age >= 21600


def nginx_revision(os_revision):
    # The official Nginx binary also changes independently of Debian indexes.
    # Inspect only registry metadata; no filesystem layers or QEMU work.
    from pathlib import Path
    dockerfile = (Path(__file__).resolve().parents[1] / 'nginx/Dockerfile').read_text()
    parent = next(line.split()[1] for line in dockerfile.splitlines() if line.startswith('FROM '))
    index = subprocess.check_output(['docker', 'buildx', 'imagetools', 'inspect', parent, '--raw'])
    json.loads(index)  # Never convert a registry error into a stable revision.
    urgent = hashlib.sha256(os_revision.rsplit('.', 1)[-1].encode() + index).hexdigest()
    return os_revision.split('.', 1)[0] + '.' + urgent


def main():
    sha = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
    revision = os.environ['PATCH_OS_REVISION']
    now = int(os.environ.get('PATCH_NOW', time.time()))
    def runs(workflow, source=False):
        command = ['gh', 'run', 'list', '--workflow', workflow, '--branch', 'main', '--limit', '100',
                   '--json', 'status,conclusion,displayTitle,createdAt']
        if source:
            command += ['--commit', sha]
        return json.loads(subprocess.check_output(command, text=True))
    base = runs('build-php-base.yml', True)
    children = {v: runs(f'build-php-{v}.yml') for v in ('cli', 'fpm', 'fpm-nginx')}
    preview = runs('build-php86-beta.yml', True)
    from pathlib import Path
    supported = json.loads((Path(__file__).resolve().parents[1] / 'versions.json').read_text())['php']['supported']
    needed = [series for series in supported if should_dispatch(series, base, children, sha, revision, now)]
    # GitHub concurrency keeps only one pending run per group. Dispatching four
    # individual PHP versions here silently replaces pending security updates.
    if needed:
        series = needed[0] if len(needed) == 1 else 'all'
        subprocess.run(['gh', 'workflow', 'run', 'build-php-base.yml', '--ref', 'main',
                        '-f', f'php_version={series}', '-f', f'os_revision={revision}',
                        '-f', 'os_variant=trixie', '-f', 'tier=all'], check=True)
    else:
        print('Stable PHP: active or complete chains; no dispatch.')
    if should_dispatch('8.6', preview, children, sha, revision, now):
        subprocess.run(['gh', 'workflow', 'run', 'build-php86-beta.yml', '--ref', 'main'], check=True)
    nginx = runs('build-nginx.yml')
    nginx_os = os.environ.get('PATCH_NGINX_REVISION') or nginx_revision(revision)
    if should_dispatch_nginx(nginx, nginx_os, now):
        subprocess.run(['gh', 'workflow', 'run', 'build-nginx.yml', '--ref', 'main', '-f', 'os_revision=' + nginx_os], check=True)


if __name__ == '__main__':
    main()
