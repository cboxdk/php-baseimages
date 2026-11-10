#!/usr/bin/env bash
# Contract test: php-base's extension ARG defaults must match versions.json.
#
# Why: CI passes every version as a --build-arg from versions.json, so the
# defaults in the Dockerfile are only ever used by a LOCAL build. That makes
# drift invisible - and it drifted. When this test was written, four of eight
# were stale:
#
#     APCU_VERSION      5.1.27  (versions.json: 5.1.28)
#     MONGODB_VERSION   2.1.4   (versions.json: 2.5.2)
#     MSGPACK_VERSION   3.0.0   (versions.json: 3.0.1)
#     XDEBUG_VERSION    3.5.0   (versions.json: 3.5.3)
#
# So anyone building locally - to reproduce a bug, to test a change - got a
# different extension set than production, silently. The pecl era hid it
# further, because pecl happily served those older versions. PIE does not:
# Packagist carries only what a maintainer tagged, and msgpack 3.0.0 does not
# exist there at all, so the stale default turned into a hard build failure.
#
# Direction checked: Dockerfile default -> versions.json. An ARG with no
# default is fine (CI must supply it); an ARG whose default disagrees is not.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

DOCKERFILE="php-base/Dockerfile"
fail=0

# ARG name -> versions.json key under .extensions
while IFS='=' read -r arg key; do
    want=$(jq -r --arg k "$key" '.extensions[$k] // empty' versions.json)
    got=$(grep -oE "^ARG ${arg}=\S+" "$DOCKERFILE" | head -1 | cut -d= -f2 || true)

    if [ -z "$want" ]; then
        # The extension is gone from versions.json; the ARG must go too.
        if [ -n "$got" ]; then
            echo "STALE ARG: $DOCKERFILE still defaults $arg=$got but .extensions.$key no longer exists"
            fail=1
        fi
        continue
    fi

    [ -z "$got" ] && continue  # no default at all: CI supplies it, fine

    if [ "$got" != "$want" ]; then
        echo "ARG DRIFT: $DOCKERFILE has $arg=$got, versions.json says $want"
        fail=1
    fi
done <<'MAP'
REDIS_VERSION=redis
IMAGICK_VERSION=imagick
APCU_VERSION=apcu
MONGODB_VERSION=mongodb
MSGPACK_VERSION=msgpack
OPENTELEMETRY_VERSION=opentelemetry
XDEBUG_VERSION=xdebug
PCOV_VERSION=pcov
VIPS_VERSION=vips
MAP

if [ "$fail" = "1" ]; then
    echo ""
    echo "Fix: update the ARG default in $DOCKERFILE to match versions.json,"
    echo "which is the single source of truth. CI overrides these, so a stale"
    echo "default only ever misleads someone building locally."
    exit 1
fi
echo "ARG defaults OK: php-base matches versions.json"
