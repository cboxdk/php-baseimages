#!/usr/bin/env bash
# Download the PIE phar for local Docker builds.
#
# PIE (PHP Installer for Extensions) replaces `pecl install`: the pecl binary
# is gone from php:8.6 images (--with-pear dropped, PECL formally deprecated -
# docker-library/php#1682), and the PECL network service itself has a stated
# shelf life. See issue #23.
#
# Delivered the same way as cbox-init and fpm-exporter - a pinned version with
# a verified sha256 - rather than bind-mounted from a floating registry tag as
# upstream's own examples do. Two reasons: a floating tag makes every build
# non-reproducible, and it makes every build depend on that registry being up.
# The second is not hypothetical - ghcr.io's blob CDN returned 502 for both
# `ghcr.io/php/pie:bin` and `:nightly-bin` for twenty minutes while this was
# being written.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
VERSIONS_FILE="$REPO_ROOT/versions.json"
DEST_DIR="$REPO_ROOT/pie/binaries"

VERSION=$(jq -r '.tools.pie' "$VERSIONS_FILE")
WANT=$(jq -r '.tools.pie_sha256' "$VERSIONS_FILE")
URL="https://github.com/php/pie/releases/download/${VERSION}/pie.phar"
DEST="$DEST_DIR/pie.phar"

echo "Downloading PIE ${VERSION}..."
mkdir -p "$DEST_DIR"

# A cached phar carries no version information, so a bump in versions.json
# would otherwise be silently ignored - the same trap download-cbox-init.sh
# documents. Stamp the version and wipe the cache on mismatch.
STAMP_FILE="$DEST_DIR/.version"
if [ "$(cat "$STAMP_FILE" 2>/dev/null)" != "$VERSION" ]; then
    rm -f "$DEST"
fi
printf '%s\n' "$VERSION" > "$STAMP_FILE"

if [ -f "$DEST" ]; then
    echo "  already present, skipping (delete to re-download)"
else
    curl -fsSL --retry 5 --retry-delay 5 --retry-all-errors -o "$DEST" "$URL"
fi

echo "Verifying SHA256 against the pin in versions.json..."
echo "${WANT}  ${DEST}" | sha256sum -c -

echo "Done. PIE in: $DEST"
