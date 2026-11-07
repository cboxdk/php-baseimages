#!/usr/bin/env python3
"""Validate and pin reachable Cbox parents before a full downstream build."""
import argparse
import importlib.util
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('image_patch', ROOT / 'scripts/image-patch.py')
patch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(patch)


def reachable_parents(text, target):
    stages = {}
    current = None
    for line in text.splitlines():
        match = re.match(r'FROM (\S+) AS (\S+)', line)
        if match:
            parent, current = match.groups()
            stages[current] = {'parent': parent, 'dependencies': [parent]}
        elif current:
            stages[current]['dependencies'].extend(re.findall(r'--from=([\w-]+)', line))
    if target not in stages:
        raise ValueError('Unknown build target')
    visited, parents = set(), {}
    def visit(stage):
        if stage in visited or stage not in stages:
            return
        visited.add(stage)
        value = stages[stage]
        if value['parent'].startswith('ghcr.io/cboxdk/php-baseimages/'):
            parents[stage] = value['parent']
        for dependency in value['dependencies']:
            visit(dependency)
    visit(target)
    return parents


def pin(text, target, series, platform, repository):
    versions = json.loads((ROOT / 'versions.json').read_text())
    php_version = json.loads((ROOT / f'php-source/php{series.replace(".", "")}-trixie.lock.json').read_text())['version']
    for stage, reference in reachable_parents(text, target).items():
        parent_type = reference.split('/')[3].split(':')[0]
        variant = stage.removeprefix('base-')
        rootless = variant.endswith('-rootless')
        tier = variant.removesuffix('-rootless')
        parent_target = ('' if tier == 'standard' else tier + '-') + ('rootless' if rootless else 'root')
        suffix = ('' if tier == 'standard' else tier) + ('-rootless' if rootless else '')
        suffix = suffix.lstrip('-')
        expected = patch.fingerprint(parent_type, series, parent_target, tier, suffix, platform)
        resolved = reference.replace('cboxdk/php-baseimages', repository).replace('${PHP_VERSION}', series).replace('${BASE_CHANNEL}', '-v' + versions['release']['channel'])
        digest, config, _ = patch.remote_config(resolved, platform.split('/')[1])
        labels = config.get('config', {}).get('Labels') or {}
        if (config.get('architecture') != platform.split('/')[1] or config.get('os') != 'linux'
                or labels.get(patch.PREFIX + 'debian-suite') != 'trixie'
                or labels.get(patch.PREFIX + 'php-version') != php_version
                or labels.get(patch.PREFIX + 'fingerprint') != expected):
            raise ValueError(f'{resolved} does not match this source commit; retry its base chain first')
        text = text.replace(f'FROM {reference} AS {stage}', f'FROM {digest} AS {stage}')
    return text


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dockerfile', type=Path, required=True)
    parser.add_argument('--target', required=True)
    parser.add_argument('--series', required=True)
    parser.add_argument('--platform', required=True)
    parser.add_argument('--repository', default='cboxdk/php-baseimages')
    args = parser.parse_args()
    args.dockerfile.write_text(pin(args.dockerfile.read_text(), args.target, args.series, args.platform, args.repository))


if __name__ == '__main__':
    main()
