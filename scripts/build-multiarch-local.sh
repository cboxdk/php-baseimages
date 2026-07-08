#!/usr/bin/env bash
# Build the base-image chain (php-base -> php-fpm -> php-fpm-nginx) as a real
# multi-arch manifest WITHOUT QEMU emulation, by using two NATIVE builder nodes:
#
#   linux/arm64  -> this machine (Apple Silicon Mac / any arm64 host, local docker)
#   linux/amd64  -> the Hetzner runner over an SSH docker context
#
# Why this exists: php-base compiles ~8 C extensions from source (redis, imagick,
# vips, mongodb, ...). Under emulated arm64-on-x86 that compile blows past the CI
# 60-min job timeout. Building each arch on native hardware is ~10x faster (the
# full multi-arch php-base builds in ~7 min instead of timing out). Use this until
# a native arm64 CI runner exists (Hetzner CAX), after which CI can do it directly.
#
# Prereqs (one-time): SSH access to the amd64 host as root; local docker + buildx.
# Usage: scripts/build-multiarch-local.sh [PHP_VERSION] [AMD64_SSH_HOST]
set -euo pipefail

PHP_VERSION="${1:-8.5}"
AMD64_HOST="${2:-root@77.42.30.235}"
OS_VARIANT=bookworm
REG=ghcr.io/cboxdk/php-baseimages
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# --- 1. multi-node builder: arm64 (local) + amd64 (remote over SSH) ------------
if ! docker buildx inspect cbox-multi >/dev/null 2>&1; then
  echo "==> Creating multi-node builder cbox-multi"
  docker context inspect hetzner >/dev/null 2>&1 || \
    docker context create hetzner --docker "host=ssh://${AMD64_HOST}"
  docker buildx create --name cbox-multi --driver docker-container --platform linux/arm64 default
  docker buildx create --append --name cbox-multi --driver docker-container --platform linux/amd64 hetzner
fi
docker buildx inspect cbox-multi --bootstrap >/dev/null

# --- 2. version args from versions.json ---------------------------------------
V() { jq -r "$1" versions.json; }
INIT_V=$(V '.tools.cbox_init')
echo "==> cbox-init v${INIT_V}, PHP ${PHP_VERSION}"
bash scripts/download-cbox-init.sh

COMMON=(--builder cbox-multi --platform linux/amd64,linux/arm64
        --provenance=false --sbom=false --build-arg "PHP_VERSION=${PHP_VERSION}" --push)
TAG="${PHP_VERSION}-${OS_VARIANT}"

# --- 3. php-base (standard tier — carries the extensions + baked cbox-init) ----
echo "==> Building php-base:${TAG} (multi-arch native)"
docker buildx build "${COMMON[@]}" --target standard-base -f php-base/Dockerfile \
  --build-arg "REDIS_VERSION=$(V .extensions.redis)" \
  --build-arg "IMAGICK_VERSION=$(V .extensions.imagick)" \
  --build-arg "APCU_VERSION=$(V .extensions.apcu)" \
  --build-arg "MONGODB_VERSION=$(V .extensions.mongodb)" \
  --build-arg "MSGPACK_VERSION=$(V .extensions.msgpack)" \
  --build-arg "VIPS_VERSION=$(V .extensions.vips)" \
  --build-arg "NODE_VERSION=$(V .node.version)" \
  --build-arg "CBOX_INIT_VERSION=${INIT_V}" \
  --build-arg "XDEBUG_VERSION=$(V '.extensions.xdebug // "3.5.0"')" \
  --build-arg "PCOV_VERSION=$(V '.extensions.pcov // "1.0.12"')" \
  -t "${REG}/php-base:${TAG}" .

# --- 4. php-fpm + php-fpm-nginx (light layers; init inherited from php-base) ---
echo "==> Building php-fpm:${TAG}"
docker buildx build "${COMMON[@]}" --target root -f php-fpm/Dockerfile \
  -t "${REG}/php-fpm:${TAG}" .
echo "==> Building php-fpm-nginx:${TAG}"
docker buildx build "${COMMON[@]}" --target root -f php-fpm-nginx/Dockerfile \
  -t "${REG}/php-fpm-nginx:${TAG}" .

echo "==> Done. Multi-arch ${REG}/php-fpm-nginx:${TAG} pushed (amd64+arm64, cbox-init ${INIT_V})."
