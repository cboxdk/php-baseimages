#!/usr/bin/env bash
# Contract test: every relative link and heading anchor inside /docs resolves.
#
# Why: cbox.dk serves /docs, and a link that 404s there is invisible from the
# repository - nothing renders it in CI and nothing clicks it. Two were already
# dead when this test was written: a `./changelog` pointing at the docs copy
# that CLAUDE.md deliberately does not keep, and a `#php-ini` anchor for a
# heading called "PHP.ini Customization".
#
# Anchors follow GitHub's slug rules, which is what the links in this repo
# already assume: lowercase, drop punctuation (an emoji leaves the space it
# came with, hence anchors like `#-management-api`), keep `_` and `-`, spaces
# to dashes.
#
# External links (http/https/mailto) are NOT checked - that needs the network
# and turns an offline lint job into a flaky one.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

python3 - <<'PY'
import pathlib, re, sys

def slug(heading):
    s = re.sub(r'[`*]', '', heading.strip().lower())
    s = re.sub(r'[^\w\s-]', '', s)      # punctuation and emoji out, _ and - stay
    # One dash per whitespace character, and no trimming: GitHub turns the
    # space a stripped leading emoji left behind into a leading dash, which is
    # where anchors like #-management-api come from.
    return re.sub(r'\s', '-', s)

docs = pathlib.Path('docs')
files = sorted(docs.rglob('*.md'))
anchors = {}
for f in files:
    anchors[f.resolve()] = {
        slug(m.group(2))
        for m in re.finditer(r'^(#{1,6})\s+(.+)$', f.read_text(), re.M)
    }

broken = []
for f in files:
    for m in re.finditer(r'\[[^\]]*\]\(([^)]+)\)', f.read_text()):
        target = m.group(1).strip()
        if target.startswith(('http://', 'https://', 'mailto:', '#!')):
            continue
        path, _, anchor = target.partition('#')
        if not path:
            if anchor and anchor not in anchors[f.resolve()]:
                broken.append(f"{f}: no heading for own anchor #{anchor}")
            continue
        base = f.parent / path
        hit = next((c for c in (
            base,
            base.with_suffix('.md'),
            pathlib.Path(f"{base}.md"),
            base / '_index.md',
        ) if c.exists()), None)
        if hit is None:
            broken.append(f"{f}: link target does not exist: {target}")
        elif anchor and hit.suffix == '.md' and anchor not in anchors.get(hit.resolve(), set()):
            broken.append(f"{f}: {path} has no heading for #{anchor}")

if broken:
    print("BROKEN DOCS LINKS:")
    for b in broken:
        print(f"  {b}")
    print("")
    print("Fix the link, add the heading, or use an absolute https:// URL for")
    print("anything outside /docs (the changelog lives at the repository root).")
    sys.exit(1)

print(f"docs links OK: every relative link and anchor in {len(files)} files resolves")
PY
