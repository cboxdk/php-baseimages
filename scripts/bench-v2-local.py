#!/usr/bin/env python3
"""Local CPU smoke comparison; not a production throughput/CI-cost benchmark."""
import argparse
import json
import os
from pathlib import Path
import statistics
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--bookworm', default='cbox-php-source:8.5.12-base-slim')
parser.add_argument('--trixie', default='cbox-v2:8.5-arm64-php-base-slim-root')
parser.add_argument('--output', type=Path, default=Path('.build/v2/benchmark.json'))
args = parser.parse_args()
docker = ['docker', '--context', os.environ.get('DOCKER_CONTEXT', 'orbstack')]
program = '''$start=hrtime(true); $sum=0; for($i=0;$i<500000;$i++){ $sum+=strlen(hash("sha256",(string)$i)); } echo json_encode(["seconds"=>(hrtime(true)-$start)/1e9,"checksum"=>$sum,"php"=>PHP_VERSION,"zts"=>PHP_ZTS]);'''
results = {}
# Alternate suites to reduce time-order bias under shared-host contention.
for _ in range(5):
    for suite, image in [('bookworm', args.bookworm), ('trixie', args.trixie)]:
        result = json.loads(subprocess.check_output(docker + ['run', '--rm', '--entrypoint', 'php', image, '-d', 'opcache.enable_cli=0', '-r', program], text=True))
        results.setdefault(suite, {'image': image, 'runs': []})['runs'].append(result)
for data in results.values():
    data['median_seconds'] = statistics.median(r['seconds'] for r in data['runs'])
assert {r['php'] for d in results.values() for r in d['runs']} == {'8.5.12'}
assert {r['checksum'] for d in results.values() for r in d['runs']} == {32000000}
results['trixie_over_bookworm'] = results['trixie']['median_seconds'] / results['bookworm']['median_seconds']
results['limitations'] = 'ARM64 shared OrbStack host; CLI hashing only, no Laravel/HTTP or CI-cost inference.'
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(results, indent=2) + '\n')
print(json.dumps(results, indent=2))
