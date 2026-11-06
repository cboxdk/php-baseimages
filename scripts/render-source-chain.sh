#!/usr/bin/env bash
# Generate a local chain from one source lock; no registry writes or dispatches.
set -euo pipefail
cd "$(dirname "$0")/.."
series="${1:-8.5}"
output="${2:-.build/source-ci}"
for image in php-base php-cli php-fpm php-fpm-nginx; do
    python3 scripts/php-source.py --series "$series" render "$image" --output "$output/$image.Dockerfile"
done
