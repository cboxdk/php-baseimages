#!/usr/bin/env bash
# Download Cbox Init binaries for local Docker builds
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
VERSIONS_FILE="$REPO_ROOT/versions.json"
DEST_DIR="$REPO_ROOT/cbox-init/binaries"

VERSION=$(jq -r '.tools.cbox_init' "$VERSIONS_FILE")
BASE_URL="https://github.com/cboxdk/init/releases/download/v${VERSION}"

echo "Downloading Cbox Init v${VERSION}..."

mkdir -p "$DEST_DIR"

for ARCH in amd64 arm64; do
    URL="${BASE_URL}/cbox-init-linux-${ARCH}"
    DEST="$DEST_DIR/cbox-init-linux-${ARCH}"

    if [ -f "$DEST" ]; then
        echo "  ${ARCH}: already exists, skipping (delete to re-download)"
        continue
    fi

    echo "  ${ARCH}: downloading from ${URL}..."
    curl -fsSL -o "$DEST" "$URL"
    chmod +x "$DEST"
done

echo "Verifying SHA256 checksums..."
CHECKSUMS_FILE="$DEST_DIR/checksums.txt"
if [ ! -f "$CHECKSUMS_FILE" ]; then
    curl -fsSL -o "$CHECKSUMS_FILE" "${BASE_URL}/checksums.txt"
fi
cd "$DEST_DIR"
grep -E "cbox-init-linux-(amd64|arm64)$" checksums.txt | sha256sum -c -
cd - > /dev/null

echo "Done. Binaries in: $DEST_DIR"
