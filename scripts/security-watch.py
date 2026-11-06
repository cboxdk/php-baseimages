#!/usr/bin/env python3
"""Re-scan digest-keyed Trivy inventories; dispatch remediation only with --dispatch."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]


def read_command(command):
    return json.loads(subprocess.check_output(command, text=True))


def plan(repository):
    versions = json.loads((ROOT / 'versions.json').read_text())
    channel = versions['release']['channel']
    images = [(series, f'{family}:{series}-trixie-dev-v{channel}')
              for series in versions['php']['supported'] for family in ('php-cli', 'php-fpm-nginx')]
    images.append(('nginx', f'nginx:trixie-v{channel}'))
    targets = []
    for series, image in images:
        ref = f'ghcr.io/{repository}/{image}'
        index = read_command(['docker', 'buildx', 'imagetools', 'inspect', ref, '--raw'])
        for arch in ['amd64', 'arm64']:
            manifests = [m for m in index.get('manifests', [])
                         if m.get('platform', {}).get('architecture') == arch and m.get('platform', {}).get('os') == 'linux']
            if len(manifests) != 1 or not re.fullmatch(r'sha256:[a-f0-9]{64}', manifests[0]['digest']):
                raise ValueError(f'No unique {arch} manifest for {ref}')
            digest = manifests[0]['digest']
            targets.append(dict(series=series, family=image.split(':', 1)[0], platform='linux/' + arch, digest=digest,
                                reference=ref.rsplit(':', 1)[0] + '@' + digest))
    return targets


def findings(report):
    return [dict(id=v['VulnerabilityID'], package=v['PkgName'], installed=v['InstalledVersion'],
                 fixed=v['FixedVersion'], severity=v['Severity'], type=r.get('Type', ''),
                 os=r.get('Class') == 'os-pkgs')
            for r in report.get('Results', []) for v in r.get('Vulnerabilities', [])
            if v.get('Severity') in ('HIGH', 'CRITICAL') and v.get('FixedVersion')]


def remediation(results):
    os_series = sorted({r['series'] for r in results if any(v['os'] for v in r['findings'])})
    tooling = any(not v['os'] for r in results for v in r['findings'])
    return os_series, tooling


def dispatch(results):
    os_series, tooling = remediation(results)
    identity = sorted({(r['series'], v['id'], v['package'], v['installed'], v['fixed']) for r in results for v in r['findings']})
    token = 'cve-' + hashlib.sha256(json.dumps(identity).encode()).hexdigest()[:20]
    tasks = []
    php = [s for s in os_series if s != 'nginx']
    if php:
        tasks.append(('build-php-base.yml', ['-f', 'php_version=' + (php[0] if len(php) == 1 else 'all'), '-f', 'os_revision=' + token, '-f', 'tier=all', '-f', 'os_variant=trixie']))
    if 'nginx' in os_series:
        tasks.append(('build-nginx.yml', ['-f', 'security_trigger=' + token]))
    if tooling:
        # APT cannot fix source-built PHP, extensions, npm or embedded Go.
        # Propose updated pins; never merge or publish an unreviewed tool bump.
        tasks.append(('check-updates.yml', ['-f', 'security_trigger=' + token]))
    for workflow, inputs in tasks:
        runs = read_command(['gh', 'run', 'list', '--workflow', workflow, '--branch', 'main', '--limit', '50',
                             '--json', 'status,displayTitle,createdAt'])
        if any(r['status'] != 'completed' for r in runs):
            print(f'{workflow}: already active; no duplicate dispatch')
            continue
        recent = [r for r in runs if token in r['displayTitle']]
        if recent and time.time() - max(datetime.datetime.fromisoformat(r['createdAt'].replace('Z', '+00:00')).timestamp() for r in recent) < 21600:
            print(f'{workflow}: unchanged finding already attempted; six-hour backoff')
            continue
        subprocess.run(['gh', 'workflow', 'run', workflow, '--ref', 'main', *inputs], check=True)


def scan(targets, cache, output, trivy='trivy', image_source='remote', do_dispatch=False):
    cache.mkdir(parents=True, exist_ok=True)
    output.mkdir(parents=True, exist_ok=True)
    subprocess.run([trivy, 'image', '--download-db-only'], check=True)
    results = []
    retained = set()
    for target in targets:
        digest = target['digest']
        if not re.fullmatch(r'sha256:[a-f0-9]{64}', digest):
            raise ValueError('Invalid immutable image digest')
        sbom = cache / (digest.replace(':', '-') + '.cdx.json')
        retained.add(sbom.name)
        if not sbom.exists():
            temporary = sbom.with_suffix('.tmp')
            subprocess.run([trivy, 'image', '--image-src', image_source, '--platform', target['platform'],
                            '--format', 'cyclonedx', '--output', str(temporary), target['reference']], check=True)
            # Never persist partial inventories from a failed scanner.
            inventory = json.loads(temporary.read_text())
            if inventory.get('bomFormat') != 'CycloneDX' or not inventory.get('components'):
                raise ValueError('Empty or invalid inventory')
            temporary.replace(sbom)
        report_path = output / (digest.replace(':', '-') + '.json')
        subprocess.run([trivy, 'sbom', '--skip-db-update', '--scanners', 'vuln', '--severity', 'HIGH,CRITICAL',
                        '--ignore-unfixed', '--ignorefile', str(ROOT / '.trivyignore'), '--format', 'json',
                        '--output', str(report_path), str(sbom)], check=True)
        report = json.loads(report_path.read_text())
        # Missing package detection is not evidence of a clean image.
        if not any(r.get('Class') == 'os-pkgs' and r.get('Type') == 'debian' for r in report.get('Results', [])):
            raise ValueError('Scanner did not analyze the Debian package inventory')
        results.append({**target, 'findings': findings(report)})
    for stale in cache.glob('*.cdx.json'):
        if stale.name not in retained:
            stale.unlink()
    (output / 'summary.json').write_text(json.dumps(results, indent=2) + '\n')
    summary = ['# Published-image security watch', '', '| Family | Series | Platform | Fixable HIGH/CRITICAL |', '| --- | --- | --- | --- |']
    for result in results:
        summary.append(f"| {result.get('family', 'image')} | {result['series']} | {result['platform']} | {len(result['findings'])} |")
        for item in result['findings']:
            print(f"{result['series']} {result['platform']}: {item['id']} {item['package']} {item['installed']} -> {item['fixed']}")
    summary += ['', 'OS findings request an APT build; non-OS findings request dependency-update review.',
                'No changes: inventories are reused, scanned with the current vulnerability database, and no build is dispatched.']
    text = '\n'.join(summary) + '\n'
    (output / 'summary.md').write_text(text)
    if os.environ.get('GITHUB_STEP_SUMMARY'):
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as stream:
            stream.write(text)
    if do_dispatch:
        dispatch(results)
    return any(r['findings'] for r in results)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    prepare = sub.add_parser('plan')
    prepare.add_argument('--repository', default='cboxdk/php-baseimages')
    prepare.add_argument('--output', type=Path, required=True)
    audit = sub.add_parser('scan')
    audit.add_argument('--plan', type=Path, required=True)
    audit.add_argument('--cache', type=Path, required=True)
    audit.add_argument('--output', type=Path, required=True)
    audit.add_argument('--trivy', default='trivy')
    audit.add_argument('--image-source', choices=['remote', 'docker'], default='remote')
    audit.add_argument('--dispatch', action='store_true')
    args = parser.parse_args()
    if args.command == 'plan':
        targets = plan(args.repository)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(targets, indent=2) + '\n')
        print('key=' + hashlib.sha256(json.dumps(targets, sort_keys=True).encode()).hexdigest())
    else:
        raise SystemExit(int(scan(json.loads(args.plan.read_text()), args.cache, args.output, args.trivy, args.image_source, args.dispatch)))


if __name__ == '__main__':
    main()
