#!/usr/bin/env bash
# Early warning for the "Debian suite dropped in a patch release" event.
#
# Upstream supports exactly two Debian suites and removes the older one in an
# UNANNOUNCED patch release when a new one is added - bullseye disappeared
# between 8.4.11 and 8.4.12 while still in LTS (docker-library/php#1596/#1619),
# after which pinned-suite users silently stopped receiving PHP patches.
#
# Signal: versions.json's latest_patch is maintained weekly from upstream
# releases. If php:<latest_patch>-fpm-bookworm does NOT exist while the same
# patch DOES exist on another suite, bookworm has been dropped (or is lagging)
# - time to plan the suite migration, not to discover it when builds freeze.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSIONS_FILE="${REPO_ROOT}/versions.json"
NEXT_SUITE="${NEXT_SUITE:-trixie}"

fail=0
for ver in $(jq -r '.php.supported[]' "$VERSIONS_FILE"); do
    patch=$(jq -r --arg v "$ver" '.php.latest_patch[$v] // empty' "$VERSIONS_FILE")
    [ -z "$patch" ] && continue
    if docker buildx imagetools inspect "docker.io/library/php:${patch}-fpm-bookworm" >/dev/null 2>&1; then
        echo "OK: php:${patch}-fpm-bookworm exists"
        continue
    fi
    if docker buildx imagetools inspect "docker.io/library/php:${patch}-fpm-${NEXT_SUITE}" >/dev/null 2>&1; then
        echo "::error::php:${patch}-fpm-bookworm is MISSING while php:${patch}-fpm-${NEXT_SUITE} exists - bookworm looks dropped or lagging upstream. Plan the suite migration NOW (and benchmark first: bullseye->bookworm carried a 30-40% CPU regression, docker-library/php#1431)."
        fail=1
    else
        echo "note: php:${patch}-fpm-bookworm not published yet (no suite has ${patch}) - normal release lag, not a suite drop"
    fi
done
exit "$fail"
