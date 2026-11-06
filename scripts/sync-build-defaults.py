#!/usr/bin/env python3
"""Keep local Dockerfile defaults identical to CI's versions.json inputs."""
import argparse
import json
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--check', action='store_true')
args = parser.parse_args()
versions = json.loads((root / 'versions.json').read_text())
values = {'NODE_VERSION': versions['node']['version']}
for group in ['tools', 'extensions']:
    values.update({key.upper() + '_VERSION': value for key, value in versions[group].items() if isinstance(value, str) and not key.endswith('sha256')})
changed = []
for path in [root / 'php-base/Dockerfile', root / 'php-base/Dockerfile.php86-beta']:
    old = path.read_text()
    new = re.sub(r'^ARG ([A-Z_]+_VERSION)=.*$', lambda m: f'ARG {m[1]}={values[m[1]]}' if m[1] in values else m[0], old, flags=re.M)
    if old != new:
        changed.append(str(path.relative_to(root)))
        if not args.check:
            path.write_text(new)
if changed:
    print('Build defaults ' + ('need syncing: ' if args.check else 'updated: ') + ', '.join(changed))
    if args.check:
        raise SystemExit(1)
