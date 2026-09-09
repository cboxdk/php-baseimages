#!/usr/bin/env bash
# Contract test: every env var the documentation promises must actually be
# consumed somewhere in the images (entrypoints, config files, init yamls).
#
# Why: both major competitors shipped YEARS of documented-but-dead env vars
# (webdevops/Dockerfile#351: XDEBUG_* documented, never wired; serversideup
# #594: documented default != shipped default). Docs drift is silent until a
# user burns an afternoon on it; this makes it a CI failure instead.
#
# Direction checked: documented -> consumed. (The reverse - consumed but
# undocumented - is a docs-completeness question, not a broken promise.)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

DOCS="docs/reference/environment-variables.md"
ALLOWLIST="tests/env-contract-allowlist.txt"

# Env-shaped tokens in backticks: UPPER_SNAKE with at least one underscore.
vars=$(grep -ohE '`[A-Z][A-Z0-9]*(_[A-Z0-9]+)+`' "$DOCS" README.md 2>/dev/null | tr -d '`' | sort -u)

CONSUME_PATHS=(php-fpm/common php-cli/common php-fpm-nginx/common nginx/common common/lib php-base/common php-fpm/Dockerfile php-cli/Dockerfile php-fpm-nginx/Dockerfile nginx/Dockerfile php-base/Dockerfile)

fail=0
for v in $vars; do
    case "$v" in
        # Consumed by the cbox-init binary itself (config-from-env), not by shell
        CBOX_INIT_*|CBOX_FPM_TUNE*|CBOX_FPM_EXPORTER*) continue ;;
    esac
    if [ -f "$ALLOWLIST" ] && grep -qx "$v" "$ALLOWLIST"; then
        continue
    fi
    if ! grep -rq -- "$v" "${CONSUME_PATHS[@]}" 2>/dev/null; then
        echo "DOCUMENTED BUT DEAD: $v is promised in the docs but consumed nowhere in the images"
        fail=1
    fi
done

if [ "$fail" = "1" ]; then
    echo ""
    echo "Fix: wire the variable into the relevant entrypoint/config, remove it"
    echo "from the docs, or add it to $ALLOWLIST with a comment-worthy reason"
    echo "(external consumers like PHP itself or framework code belong there)."
    exit 1
fi
echo "env contract OK: every documented variable is consumed."
