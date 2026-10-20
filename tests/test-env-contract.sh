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

# ─────────────────────────────────────────────────────────────────────────────
# Second direction: PER-IMAGE consumption.
#
# The check above passes when a variable is consumed ANYWHERE, which is a real
# blind spot: PUID/PGID were documented as a property of "these images" while
# only php-fpm-nginx honoured them. php-fpm, php-cli and nginx accepted them and
# silently remapped nothing (#44) - every file they wrote into a bind mount came
# out as uid 33. The 1.9.0 changelog recorded the same shape for
# PHP_OPCACHE_PRELOAD ("the test passes when a variable is consumed anywhere, so
# it could not catch a per-image gap").
#
# So: variables the docs present as universal must be consumed by EVERY image's
# entrypoint - directly, or through a shared-library function it calls.
# ─────────────────────────────────────────────────────────────────────────────
UNIVERSAL_VARS="PUID PGID APP_USER APP_GROUP"
IMAGE_ENTRYPOINTS="php-fpm/common/docker-entrypoint.sh
php-cli/common/docker-entrypoint.sh
php-fpm-nginx/common/docker-entrypoint.sh
nginx/common/docker-entrypoint.sh"
# Shared-library functions that consume these on an entrypoint's behalf. An
# entrypoint that calls one counts as consuming whatever the function reads.
CONSUMER_FNS="setup_user_permissions"
LIB="common/lib/entrypoint-lib.sh"

per_image_fail=0
for v in $UNIVERSAL_VARS; do
    for ep in $IMAGE_ENTRYPOINTS; do
        [ -f "$ep" ] || { echo "MISSING ENTRYPOINT: $ep"; per_image_fail=1; continue; }
        # Comments are stripped first: a comment that merely MENTIONS the
        # variable is not consumption, and leaving one behind while deleting the
        # code is exactly how a gap would hide from this check.
        code=$(sed 's/#.*//' "$ep")
        if printf '%s' "$code" | grep -q -- "$v"; then
            continue
        fi
        # Indirect: the entrypoint calls a function that reads the variable.
        indirect=0
        for fn in $CONSUMER_FNS; do
            if printf '%s' "$code" | grep -q -- "$fn" && grep -q -- "$v" "$LIB"; then
                indirect=1
                break
            fi
        done
        [ "$indirect" = "1" ] && continue
        echo "PER-IMAGE GAP: $v is documented for every image but $ep neither"
        echo "               reads it nor calls a shared function that does"
        per_image_fail=1
    done
done

if [ "$per_image_fail" = "1" ]; then
    echo ""
    echo "Fix: call the shared consumer from that entrypoint (for PUID/PGID that"
    echo "is setup_user_permissions in $LIB), or narrow the docs so the promise"
    echo "names the images that actually keep it."
    exit 1
fi
echo "env contract OK: universal variables are consumed by every image."
