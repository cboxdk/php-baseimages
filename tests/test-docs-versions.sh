#!/usr/bin/env bash
# Contract test: the pinned-versions table in the extensions reference must
# match versions.json. It drifted silently (the weekly updater bumps
# versions.json but no human remembers the docs table) - mongodb sat at 2.1.4
# in the docs while 2.5.2 shipped. Same disease as documented-but-dead envs.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

DOC="docs/reference/available-extensions.md"
fail=0
for ext in $(jq -r '.extensions | keys[]' versions.json); do
    want=$(jq -r --arg e "$ext" '.extensions[$e]' versions.json)
    got=$(grep -E "^\| ${ext} \| [v0-9]" "$DOC" 2>/dev/null | tail -1 | awk -F'|' '{gsub(/ /,"",$3); print $3}' || true)
    [ -z "$got" ] && continue  # extension not in the pinned table
    # Normalize: a leading 'v' (git-tag pins like spx) and trailing
    # annotations like "(fromGitHub)" are presentation, not version.
    got="${got%%(*}"; got="${got#v}"; want="${want#v}"
    if [ "$got" != "$want" ]; then
        echo "DOCS DRIFT: $DOC says $ext = $got, versions.json says $want"
        fail=1
    fi
done
[ "$fail" = "0" ] && echo "docs version table matches versions.json" || exit 1
