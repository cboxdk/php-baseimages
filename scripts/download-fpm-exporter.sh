#!/usr/bin/env bash
# Download Cbox FPM Exporter binaries for local Docker builds
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
VERSIONS_FILE="${VERSIONS_FILE:-$REPO_ROOT/versions.json}"
DEST_DIR="$REPO_ROOT/fpm-exporter/binaries"

VERSION=$(jq -r '.tools.fpm_exporter' "$VERSIONS_FILE")
BASE_URL="https://github.com/cboxdk/fpm-exporter/releases/download/v${VERSION}"

echo "Downloading Cbox FPM Exporter v${VERSION}..."
mkdir -p "$DEST_DIR"

# Version-stamp the cache so a bump in versions.json invalidates old binaries
# (the cbox-init script shipped stale binaries for weeks before this pattern).
STAMP_FILE="$DEST_DIR/.version"
if [ "$(cat "$STAMP_FILE" 2>/dev/null)" != "$VERSION" ]; then
    rm -f "$DEST_DIR"/fpm-exporter-linux-*
fi
printf '%s\n' "$VERSION" > "$STAMP_FILE"

for ARCH in amd64 arm64; do
    DEST="$DEST_DIR/fpm-exporter-linux-${ARCH}"
    if [ ! -f "$DEST" ]; then
        echo "  ${ARCH}: downloading..."
        curl -fsSL -o "$DEST" "${BASE_URL}/fpm-exporter-linux-${ARCH}"
        chmod +x "$DEST"
    fi
done

# Upstream publishes no checksums.txt (yet) - verify against the sha256 pins
# recorded in versions.json instead, which is stronger anyway: the hashes are
# reviewed in git alongside the version bump.
echo "Verifying SHA256 against versions.json pins..."
for ARCH in amd64 arm64; do
    WANT=$(jq -r ".tools.fpm_exporter_sha256[\"linux-${ARCH}\"]" "$VERSIONS_FILE")
    GOT=$(shasum -a 256 "$DEST_DIR/fpm-exporter-linux-${ARCH}" 2>/dev/null | awk '{print $1}' || sha256sum "$DEST_DIR/fpm-exporter-linux-${ARCH}" | awk '{print $1}')
    if [ "$WANT" != "$GOT" ]; then
        echo "CHECKSUM MISMATCH for ${ARCH}: want $WANT got $GOT" >&2
        exit 1
    fi
    echo "  ${ARCH}: OK"
done

echo "Done. Binaries in: $DEST_DIR"
