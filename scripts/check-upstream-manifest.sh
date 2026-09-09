#!/usr/bin/env bash
# Preflight for the weekly build chain: verify the upstream php images we are
# about to build FROM actually exist with BOTH architectures.
#
# Why: upstream rollouts fill arch manifests in gradually - pulls have returned
# the wrong arch mid-rollout (docker-library/php#1645), stable tags have lagged
# releases by days (#1672), and whole arches have been missing when a JIT asm
# bug broke one platform (#1683). Building on a half-rolled-out upstream would
# publish a half-arch or mismatched release; failing fast here leaves last
# week's good tags in place instead.
#
# Usage: check-upstream-manifest.sh <php-version> [variant...]
#   e.g. check-upstream-manifest.sh 8.5 cli fpm
set -euo pipefail

PHP_VERSION="${1:?usage: $0 <php-version> [variant...]}"
shift
VARIANTS=("${@:-cli fpm}")
[ $# -eq 0 ] && VARIANTS=(cli fpm)

REQUIRED_ARCHS=(amd64 arm64)
fail=0

for variant in "${VARIANTS[@]}"; do
    ref="php:${PHP_VERSION}-${variant}-bookworm"
    echo "Checking ${ref}..."
    if ! manifest=$(docker buildx imagetools inspect "docker.io/library/${ref}" --raw 2>&1); then
        echo "::error::Upstream ${ref} does not exist or is not pullable: ${manifest}"
        fail=1
        continue
    fi
    for arch in "${REQUIRED_ARCHS[@]}"; do
        if ! printf '%s' "$manifest" | grep -q "\"architecture\"[[:space:]]*:[[:space:]]*\"${arch}\""; then
            echo "::error::Upstream ${ref} is missing linux/${arch} - upstream rollout incomplete or arch build broken. Aborting before we publish a half-arch release."
            fail=1
        else
            echo "  linux/${arch}: OK"
        fi
    done
done

if [ "$fail" = "1" ]; then
    echo ""
    echo "Upstream preflight FAILED. Last week's published tags remain in place."
    echo "Escalation: check https://github.com/docker-library/php/issues for the rollout status."
    exit 1
fi
echo "Upstream manifests complete for PHP ${PHP_VERSION} (${VARIANTS[*]})."
