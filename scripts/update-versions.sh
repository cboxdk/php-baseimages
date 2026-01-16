#!/usr/bin/env bash
# ============================================================================
# Cbox Base Images - Version Update Script
# ============================================================================
# Fetches latest versions from official sources and updates versions.json
#
# Usage:
#   ./scripts/update-versions.sh           # Check all, show diff
#   ./scripts/update-versions.sh --apply   # Apply changes to versions.json
#   ./scripts/update-versions.sh --ci      # CI mode: apply + exit 1 if changes
#
# Requirements: curl, jq
# ============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
VERSIONS_FILE="$REPO_ROOT/versions.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
APPLY=false
CI_MODE=false
for arg in "$@"; do
    case $arg in
        --apply) APPLY=true ;;
        --ci) CI_MODE=true; APPLY=true ;;
        --help|-h)
            echo "Usage: $0 [--apply] [--ci]"
            echo "  --apply  Apply changes to versions.json"
            echo "  --ci     CI mode: apply changes and exit 1 if updates found"
            exit 0
            ;;
    esac
done

# Track updates
UPDATE_COUNT=0
UPDATE_LIST=""

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_update() { echo -e "${YELLOW}[UPDATE]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ============================================================================
# Fetch functions for each source
# ============================================================================

fetch_github_latest() {
    local repo="$1"
    curl -fsSL "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null | jq -r '.tag_name // empty' | sed 's/^v//'
}

fetch_pecl_latest() {
    local package="$1"
    # Get stable version (not RC/alpha/beta)
    local version
    version=$(curl -fsSL "https://pecl.php.net/rest/r/${package,,}/latest.txt" 2>/dev/null | tr -d '[:space:]')

    # Skip if it's a pre-release (RC, alpha, beta)
    if [[ "$version" =~ (RC|alpha|beta|dev) ]]; then
        # Try to get stable from allreleases instead (cross-platform sed)
        version=$(curl -fsSL "https://pecl.php.net/rest/r/${package,,}/allreleases.xml" 2>/dev/null \
            | sed -n 's/.*<v>\([0-9]*\.[0-9]*\.[0-9]*\)<\/v>.*/\1/p' | head -1)
    fi
    echo "$version"
}

fetch_php_latest_patch() {
    local minor_version="$1"
    curl -fsSL "https://www.php.net/releases/index.php?json&version=$minor_version" 2>/dev/null | jq -r '.version // empty'
}

fetch_node_lts() {
    curl -fsSL "https://nodejs.org/dist/index.json" 2>/dev/null | jq -r '[.[] | select(.lts != false)] | .[0].version' | sed 's/^v//' | cut -d. -f1
}

# ============================================================================
# Main update logic
# ============================================================================

log_info "Checking for version updates..."
echo ""

# Load current versions
CURRENT=$(cat "$VERSIONS_FILE")
UPDATED="$CURRENT"

# --- PHP Extensions (PECL) ---
log_info "Checking PECL extensions..."

for ext in redis imagick apcu mongodb igbinary msgpack xdebug pcov uuid excimer vips; do
    current=$(echo "$CURRENT" | jq -r ".extensions.$ext")
    latest=$(fetch_pecl_latest "$ext")

    if [[ -z "$latest" || ! "$latest" =~ ^[0-9] ]]; then
        log_error "Failed to fetch $ext, keeping $current"
        continue
    fi

    if [[ "$current" != "$latest" ]]; then
        UPDATE_COUNT=$((UPDATE_COUNT + 1))
        UPDATE_LIST="${UPDATE_LIST}  - extensions.$ext: $current -> $latest\n"
        log_update "extensions.$ext: $current -> $latest"
        UPDATED=$(echo "$UPDATED" | jq ".extensions.$ext = \"$latest\"")
    else
        log_success "extensions.$ext: $current (up to date)"
    fi
done

# Swoole (GitHub - not standard PECL)
current=$(echo "$CURRENT" | jq -r ".extensions.swoole")
latest=$(fetch_github_latest "swoole/swoole-src")
if [[ -n "$latest" && "$latest" =~ ^[0-9] ]]; then
    if [[ "$current" != "$latest" ]]; then
        UPDATE_COUNT=$((UPDATE_COUNT + 1))
        UPDATE_LIST="${UPDATE_LIST}  - extensions.swoole: $current -> $latest\n"
        log_update "extensions.swoole: $current -> $latest"
        UPDATED=$(echo "$UPDATED" | jq ".extensions.swoole = \"$latest\"")
    else
        log_success "extensions.swoole: $current (up to date)"
    fi
else
    log_error "Failed to fetch swoole, keeping $current"
fi

# OpenSwoole (GitHub)
current=$(echo "$CURRENT" | jq -r ".extensions.openswoole")
latest=$(fetch_github_latest "openswoole/swoole-src")
if [[ -n "$latest" && "$latest" =~ ^[0-9] ]]; then
    if [[ "$current" != "$latest" ]]; then
        UPDATE_COUNT=$((UPDATE_COUNT + 1))
        UPDATE_LIST="${UPDATE_LIST}  - extensions.openswoole: $current -> $latest\n"
        log_update "extensions.openswoole: $current -> $latest"
        UPDATED=$(echo "$UPDATED" | jq ".extensions.openswoole = \"$latest\"")
    else
        log_success "extensions.openswoole: $current (up to date)"
    fi
else
    log_error "Failed to fetch openswoole, keeping $current"
fi

echo ""

# --- Tools ---
log_info "Checking tools..."

# FrankenPHP
current=$(echo "$CURRENT" | jq -r ".tools.frankenphp")
latest=$(fetch_github_latest "dunglas/frankenphp")
if [[ -n "$latest" && "$latest" =~ ^[0-9] ]]; then
    if [[ "$current" != "$latest" ]]; then
        UPDATE_COUNT=$((UPDATE_COUNT + 1))
        UPDATE_LIST="${UPDATE_LIST}  - tools.frankenphp: $current -> $latest\n"
        log_update "tools.frankenphp: $current -> $latest"
        UPDATED=$(echo "$UPDATED" | jq ".tools.frankenphp = \"$latest\"")
    else
        log_success "tools.frankenphp: $current (up to date)"
    fi
else
    log_error "Failed to fetch frankenphp, keeping $current"
fi

# Cbox Init
current=$(echo "$CURRENT" | jq -r ".tools.cbox_init")
latest=$(fetch_github_latest "gophpeek/phpeek-pm")
if [[ -n "$latest" && "$latest" =~ ^[0-9] ]]; then
    if [[ "$current" != "$latest" ]]; then
        UPDATE_COUNT=$((UPDATE_COUNT + 1))
        UPDATE_LIST="${UPDATE_LIST}  - tools.cbox_init: $current -> $latest\n"
        log_update "tools.cbox_init: $current -> $latest"
        UPDATED=$(echo "$UPDATED" | jq ".tools.cbox_init = \"$latest\"")
    else
        log_success "tools.cbox_init: $current (up to date)"
    fi
else
    log_error "Failed to fetch cbox_init, keeping $current"
fi

echo ""

# --- PHP Versions ---
log_info "Checking PHP patch versions..."

for version in 8.2 8.3 8.4; do
    current=$(echo "$CURRENT" | jq -r ".php.latest_patch[\"$version\"]")
    latest=$(fetch_php_latest_patch "$version")

    if [[ -z "$latest" || ! "$latest" =~ ^[0-9] ]]; then
        log_error "Failed to fetch PHP $version, keeping $current"
        continue
    fi

    if [[ "$current" != "$latest" ]]; then
        UPDATE_COUNT=$((UPDATE_COUNT + 1))
        UPDATE_LIST="${UPDATE_LIST}  - php.latest_patch.$version: $current -> $latest\n"
        log_update "php.latest_patch.$version: $current -> $latest"
        UPDATED=$(echo "$UPDATED" | jq ".php.latest_patch[\"$version\"] = \"$latest\"")
    else
        log_success "php.latest_patch.$version: $current (up to date)"
    fi
done

echo ""

# --- Node.js ---
log_info "Checking Node.js LTS..."

current=$(echo "$CURRENT" | jq -r ".node.version")
latest=$(fetch_node_lts)
if [[ -n "$latest" && "$latest" =~ ^[0-9]+$ ]]; then
    if [[ "$current" != "$latest" ]]; then
        UPDATE_COUNT=$((UPDATE_COUNT + 1))
        UPDATE_LIST="${UPDATE_LIST}  - node.version: $current -> $latest\n"
        log_update "node.version: $current -> $latest"
        UPDATED=$(echo "$UPDATED" | jq ".node.version = \"$latest\"")
    else
        log_success "node.version: $current (up to date)"
    fi
else
    log_error "Failed to fetch Node.js, keeping $current"
fi

echo ""

# ============================================================================
# Summary and apply
# ============================================================================

if [[ $UPDATE_COUNT -eq 0 ]]; then
    log_success "All versions are up to date!"
    exit 0
fi

echo "========================================"
log_info "Found $UPDATE_COUNT update(s):"
echo -e "$UPDATE_LIST"
echo "========================================"

if [[ "$APPLY" == true ]]; then
    # Update last_updated timestamp
    TODAY=$(date +%Y-%m-%d)
    UPDATED=$(echo "$UPDATED" | jq "._meta.last_updated = \"$TODAY\"")

    # Write updated versions
    echo "$UPDATED" | jq '.' > "$VERSIONS_FILE"
    log_success "Updated $VERSIONS_FILE"

    if [[ "$CI_MODE" == true ]]; then
        log_info "CI mode: Exiting with code 1 to signal updates available"
        exit 1
    fi
else
    echo ""
    log_info "Run with --apply to update versions.json"
    echo ""
    log_info "Diff preview:"
    diff <(echo "$CURRENT" | jq '.') <(echo "$UPDATED" | jq '.') || true
fi
