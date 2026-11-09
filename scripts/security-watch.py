#!/usr/bin/env python3
"""Re-scan digest-keyed Trivy inventories; dispatch remediation only with --dispatch.

Two rules decide what is actionable:
- a fixable HIGH/CRITICAL finding, and
- any CVE in CISA's Known Exploited Vulnerabilities catalog, whatever its
  severity and whether or not a fix exists. Severity is a guess about impact;
  KEV is evidence of exploitation. An unfixed KEV cannot be rebuilt away, so it
  fails the watch until it is fixed or carries a reviewed, expiring exception
  in security/kev-exceptions.json.
"""
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
KEV_URLS = ('https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json',
            'https://raw.githubusercontent.com/cisagov/kev-data/develop/known_exploited_vulnerabilities.json')


def load_kev(path):
    catalog = json.loads(Path(path).read_text())
    ids = {v['cveID'] for v in catalog.get('vulnerabilities', [])}
    # A truncated or empty download must not read as "nothing is exploited".
    if len(ids) < 1000:
        raise ValueError(f'KEV catalog looks truncated ({len(ids)} entries)')
    return ids


def load_kev_exceptions(today=None):
    path = ROOT / 'security/kev-exceptions.json'
    if not path.exists():
        return []
    today = today or datetime.date.today().isoformat()
    entries = json.loads(path.read_text())['exceptions']
    for entry in entries:
        for key in ('id', 'package', 'channel', 'reason', 'expires'):
            if not entry.get(key):
                raise ValueError(f'KEV exception without {key}: {entry}')
    return [e for e in entries if e['expires'] >= today]


def ignored_ids():
    path = ROOT / '.trivyignore'
    if not path.exists():
        return set()
    return {line.split()[0] for line in path.read_text().splitlines() if line.strip() and not line.startswith('#')}


def read_command(command):
    return json.loads(subprocess.check_output(command, text=True))


def channels(versions, today=None):
    """The current channel plus every previous major still inside its maintenance window."""
    today = today or datetime.date.today().isoformat()
    release = versions['release']
    current = dict(channel=release['channel'], branch='main', os=versions['os']['debian']['default'],
                   php=versions['php']['supported'])
    maintained = [dict(channel=major, **info) for major, info in release.get('maintenance', {}).items()
                  if major in release['supported_majors'] and info['until'] >= today]
    return [current, *maintained]


def plan(repository):
    versions = json.loads((ROOT / 'versions.json').read_text())
    images = []
    for line in channels(versions):
        tag = f"-v{line['channel']}"
        images += [(line, series, f"{family}:{series}-{line['os']}-dev{tag}")
                   for series in line['php'] for family in ('php-cli', 'php-fpm-nginx')]
        images.append((line, 'nginx', f"nginx:{line['os']}{tag}"))
    targets = []
    for line, series, image in images:
        ref = f'ghcr.io/{repository}/{image}'
        index = read_command(['docker', 'buildx', 'imagetools', 'inspect', ref, '--raw'])
        for arch in ['amd64', 'arm64']:
            manifests = [m for m in index.get('manifests', [])
                         if m.get('platform', {}).get('architecture') == arch and m.get('platform', {}).get('os') == 'linux']
            if len(manifests) != 1 or not re.fullmatch(r'sha256:[a-f0-9]{64}', manifests[0]['digest']):
                raise ValueError(f'No unique {arch} manifest for {ref}')
            digest = manifests[0]['digest']
            targets.append(dict(series=series, family=image.split(':', 1)[0], platform='linux/' + arch, digest=digest,
                                reference=ref.rsplit(':', 1)[0] + '@' + digest,
                                channel=line['channel'], branch=line['branch']))
    return targets


def findings(report, kev=frozenset(), ignored=frozenset()):
    """Actionable findings: fixable HIGH/CRITICAL, plus every KEV entry.

    .trivyignore only silences ordinary findings; a KEV entry needs an explicit
    exception (see accepted_kev) because "known exploited" outranks a triage note.
    """
    rows = []
    for r in report.get('Results', []):
        for v in r.get('Vulnerabilities', []):
            exploited = v['VulnerabilityID'] in kev
            fixable_high = v.get('Severity') in ('HIGH', 'CRITICAL') and v.get('FixedVersion')
            if exploited or (fixable_high and v['VulnerabilityID'] not in ignored):
                rows.append(dict(id=v['VulnerabilityID'], package=v['PkgName'], installed=v['InstalledVersion'],
                                 fixed=v.get('FixedVersion', ''), severity=v['Severity'], type=r.get('Type', ''),
                                 os=r.get('Class') == 'os-pkgs', kev=exploited))
    return rows


def accepted_kev(finding, target, exceptions):
    return finding['kev'] and not finding['fixed'] and any(
        e['id'] == finding['id'] and e['package'] == finding['package'] and e['channel'] == target.get('channel')
        and e.get('family', target.get('family')) == target.get('family') for e in exceptions)


def kev_gate(report, kev):
    """Pre-promotion: block any KEV entry that a rebuild could have fixed."""
    return [f for f in findings(report, kev) if f['kev'] and f['fixed']]


def remediation(results):
    # Only fixable findings can be rebuilt away; an unfixed KEV is reported, not retried.
    results = [r for r in results if r.get('branch', 'main') == 'main']
    os_series = sorted({r['series'] for r in results if any(v['os'] and v['fixed'] for v in r['findings'])})
    tooling = any(not v['os'] and v['fixed'] for r in results for v in r['findings'])
    return os_series, tooling


def maintenance_tasks(results):
    """Maintenance branches build their full chain from build-php-base/build-nginx on that branch."""
    tasks = []
    for branch in sorted({r['branch'] for r in results if r.get('branch', 'main') != 'main'}):
        rows = [r for r in results if r.get('branch') == branch and any(v['os'] and v['fixed'] for v in r['findings'])]
        if any(r['series'] != 'nginx' for r in rows):
            tasks.append(('build-php-base.yml', branch, []))
        if any(r['series'] == 'nginx' for r in rows):
            tasks.append(('build-nginx.yml', branch, []))
    return tasks


def dispatch(results):
    os_series, tooling = remediation(results)
    identity = sorted({(r.get('channel', ''), r['series'], v['id'], v['package'], v['installed'], v['fixed'])
                       for r in results for v in r['findings']})
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
    tasks = [(workflow, 'main', inputs) for workflow, inputs in tasks] + maintenance_tasks(results)
    for workflow, branch, inputs in tasks:
        runs = read_command(['gh', 'run', 'list', '--workflow', workflow, '--branch', branch, '--limit', '50',
                             '--json', 'status,displayTitle,createdAt'])
        if any(r['status'] != 'completed' for r in runs):
            print(f'{workflow}@{branch}: already active; no duplicate dispatch')
            continue
        # Maintenance branches predate the token in run titles: back off on any recent run there.
        recent = [r for r in runs if token in r['displayTitle'] or branch != 'main']
        if recent and time.time() - max(datetime.datetime.fromisoformat(r['createdAt'].replace('Z', '+00:00')).timestamp() for r in recent) < 21600:
            print(f'{workflow}@{branch}: recently attempted; six-hour backoff')
            continue
        subprocess.run(['gh', 'workflow', 'run', workflow, '--ref', branch, *inputs], check=True)


def scan(targets, cache, output, trivy='trivy', image_source='remote', do_dispatch=False, kev=frozenset(), exceptions=()):
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
        # Every severity, fixed or not: KEV membership, not Trivy's severity, decides
        # whether a LOW or unfixed finding matters. findings() applies the filter.
        subprocess.run([trivy, 'sbom', '--skip-db-update', '--scanners', 'vuln', '--format', 'json',
                        '--output', str(report_path), str(sbom)], check=True)
        report = json.loads(report_path.read_text())
        # Missing package detection is not evidence of a clean image.
        if not any(r.get('Class') == 'os-pkgs' and r.get('Type') == 'debian' for r in report.get('Results', [])):
            raise ValueError('Scanner did not analyze the Debian package inventory')
        rows = findings(report, kev, ignored_ids())
        accepted = [f for f in rows if accepted_kev(f, target, exceptions)]
        results.append({**target, 'findings': [f for f in rows if f not in accepted], 'accepted_kev': accepted})
    for stale in cache.glob('*.cdx.json'):
        if stale.name not in retained:
            stale.unlink()
    (output / 'summary.json').write_text(json.dumps(results, indent=2) + '\n')
    summary = ['# Published-image security watch', '',
               '| Channel | Family | Series | Platform | Fixable HIGH/CRITICAL | KEV | KEV accepted |',
               '| --- | --- | --- | --- | --- | --- | --- |']
    for result in results:
        kev_rows = [f for f in result['findings'] if f['kev']]
        summary.append(f"| v{result.get('channel', '?')} | {result.get('family', 'image')} | {result['series']} | {result['platform']} | "
                       f"{sum(1 for f in result['findings'] if not f['kev'])} | {len(kev_rows)} | {len(result.get('accepted_kev', []))} |")
        for item in result['findings']:
            label = 'KEV ' if item['kev'] else ''
            print(f"v{result.get('channel', '?')} {result['series']} {result['platform']}: {label}{item['id']} {item['package']} "
                  f"{item['installed']} -> {item['fixed'] or 'no fix'}")
    summary += ['', 'OS findings request an APT build (on the maintenance branch for previous majors); non-OS findings request dependency-update review.',
                'Any CISA KEV entry fails the watch regardless of severity; an unfixed one needs a reviewed exception in security/kev-exceptions.json.']
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
    audit.add_argument('--kev', type=Path, required=True, help='CISA KEV catalog JSON')
    gate = sub.add_parser('kev-gate', help='Fail when a Trivy JSON report contains a fixable KEV entry')
    gate.add_argument('--report', type=Path, required=True)
    gate.add_argument('--kev', type=Path, required=True)
    args = parser.parse_args()
    if args.command == 'plan':
        targets = plan(args.repository)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(targets, indent=2) + '\n')
        print('key=' + hashlib.sha256(json.dumps(targets, sort_keys=True).encode()).hexdigest())
    elif args.command == 'kev-gate':
        blocked = kev_gate(json.loads(args.report.read_text()), load_kev(args.kev))
        for f in blocked:
            print(f"KEV {f['id']} {f['package']} {f['installed']} -> {f['fixed']} ({f['severity']})")
        print(f'{len(blocked)} fixable known-exploited vulnerabilities')
        raise SystemExit(int(bool(blocked)))
    else:
        raise SystemExit(int(scan(json.loads(args.plan.read_text()), args.cache, args.output, args.trivy, args.image_source,
                                  args.dispatch, load_kev(args.kev), load_kev_exceptions())))


if __name__ == '__main__':
    main()
