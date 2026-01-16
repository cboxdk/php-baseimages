#!/usr/bin/env bash
# ============================================================================
# Cbox Base Images - Build State Generator
# ============================================================================
# Determines lifecycle state for each image variant based on EOL dates
# Used by CI to set appropriate labels, tags, and warnings
#
# Usage:
#   ./scripts/get-build-state.sh <php_version> <os_variant>
#   ./scripts/get-build-state.sh 8.2 alpine
#   ./scripts/get-build-state.sh 8.5 alpine --preview
#
# Output (JSON):
#   {
#     "lifecycle": "stable|deprecated|eol|preview",
#     "php_eol": "2025-12-08",
#     "days_to_eol": 6,
#     "removal_date": "2026-06-08",
#     "days_to_removal": 188,
#     "labels": { ... },
#     "warning_message": "...",
#     "tags_suffix": ""
#   }
# ============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
VERSIONS_FILE="$REPO_ROOT/versions.json"

# Arguments
PHP_VERSION="${1:-}"
OS_VARIANT="${2:-}"
IS_PREVIEW=false

for arg in "$@"; do
    [[ "$arg" == "--preview" ]] && IS_PREVIEW=true
done

if [[ -z "$PHP_VERSION" || -z "$OS_VARIANT" ]]; then
    echo "Usage: $0 <php_version> <os_variant> [--preview]" >&2
    exit 1
fi

# Load versions
VERSIONS=$(cat "$VERSIONS_FILE")

# Date helpers
TODAY=$(date +%Y-%m-%d)
TODAY_SEC=$(date -d "$TODAY" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$TODAY" +%s)

days_until() {
    local target_date="$1"
    local target_sec
    target_sec=$(date -d "$target_date" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$target_date" +%s)
    echo $(( (target_sec - TODAY_SEC) / 86400 ))
}

add_months() {
    local base_date="$1"
    local months="$2"
    if date --version >/dev/null 2>&1; then
        date -d "$base_date + $months months" +%Y-%m-%d
    else
        date -j -v+"${months}m" -f "%Y-%m-%d" "$base_date" +%Y-%m-%d
    fi
}

# Get policy settings
WARNING_DAYS=$(echo "$VERSIONS" | jq -r '.deprecation_policy.warning_before_removal_days // 90')
PHP_REMOVAL_MONTHS=$(echo "$VERSIONS" | jq -r '.deprecation_policy.php_removal_after_eol_months // 6')
OS_REMOVAL_MONTHS=$(echo "$VERSIONS" | jq -r '.deprecation_policy.os_removal_after_eol_months // 3')

# Check if preview version
PREVIEW_STATUS=$(echo "$VERSIONS" | jq -r ".php.preview[\"$PHP_VERSION\"].status // empty")
if [[ -n "$PREVIEW_STATUS" ]] || [[ "$IS_PREVIEW" == true ]]; then
    # Preview/Beta version
    PREVIEW_NOTE=$(echo "$VERSIONS" | jq -r ".php.preview[\"$PHP_VERSION\"].note // \"Preview release\"")

    cat <<EOF
{
  "lifecycle": "preview",
  "status": "${PREVIEW_STATUS:-beta}",
  "php_version": "$PHP_VERSION",
  "os_variant": "$OS_VARIANT",
  "note": "$PREVIEW_NOTE",
  "labels": {
    "org.opencontainers.image.version": "${PHP_VERSION}-${OS_VARIANT}-${PREVIEW_STATUS:-beta}",
    "io.cbox.lifecycle": "preview",
    "io.cbox.preview.status": "${PREVIEW_STATUS:-beta}",
    "io.cbox.preview.warning": "This is a preview release. Not recommended for production use."
  },
  "warning_message": "⚠️  WARNING: This is a ${PREVIEW_STATUS:-beta} preview of PHP $PHP_VERSION. Not recommended for production.",
  "tags_suffix": "-${PREVIEW_STATUS:-beta}",
  "show_startup_warning": true
}
EOF
    exit 0
fi

# Get EOL dates
PHP_EOL=$(echo "$VERSIONS" | jq -r ".php.eol[\"$PHP_VERSION\"] // empty")

if [[ -z "$PHP_EOL" ]]; then
    echo "Error: Unknown PHP version $PHP_VERSION" >&2
    exit 1
fi

# Calculate dates
DAYS_TO_PHP_EOL=$(days_until "$PHP_EOL")
PHP_REMOVAL_DATE=$(add_months "$PHP_EOL" "$PHP_REMOVAL_MONTHS")
DAYS_TO_REMOVAL=$(days_until "$PHP_REMOVAL_DATE")

# Determine lifecycle state
LIFECYCLE="stable"
WARNING_MESSAGE=""
SHOW_WARNING=false
TAGS_SUFFIX=""

if [[ $DAYS_TO_REMOVAL -lt 0 ]]; then
    # Past removal date
    LIFECYCLE="removed"
    WARNING_MESSAGE="🚨 CRITICAL: PHP $PHP_VERSION support ended. This image should be removed. Please upgrade immediately."
    SHOW_WARNING=true
elif [[ $DAYS_TO_PHP_EOL -lt 0 ]]; then
    # Past EOL, in grace period
    LIFECYCLE="eol"
    WARNING_MESSAGE="🚨 WARNING: PHP $PHP_VERSION reached End-of-Life on $PHP_EOL. This image will be removed on $PHP_REMOVAL_DATE ($DAYS_TO_REMOVAL days). Please upgrade to a supported PHP version."
    SHOW_WARNING=true
    TAGS_SUFFIX="-eol"
elif [[ $DAYS_TO_PHP_EOL -lt $WARNING_DAYS ]]; then
    # Within warning period
    LIFECYCLE="deprecated"
    WARNING_MESSAGE="⚠️  DEPRECATION WARNING: PHP $PHP_VERSION reaches End-of-Life on $PHP_EOL ($DAYS_TO_PHP_EOL days). Please plan your upgrade to PHP 8.3 or 8.4."
    SHOW_WARNING=true
    TAGS_SUFFIX="-deprecated"
fi

# Build labels
cat <<EOF
{
  "lifecycle": "$LIFECYCLE",
  "php_version": "$PHP_VERSION",
  "os_variant": "$OS_VARIANT",
  "php_eol": "$PHP_EOL",
  "days_to_eol": $DAYS_TO_PHP_EOL,
  "removal_date": "$PHP_REMOVAL_DATE",
  "days_to_removal": $DAYS_TO_REMOVAL,
  "labels": {
    "org.opencontainers.image.version": "${PHP_VERSION}-${OS_VARIANT}",
    "io.cbox.lifecycle": "$LIFECYCLE",
    "io.cbox.php.version": "$PHP_VERSION",
    "io.cbox.php.eol": "$PHP_EOL",
    "io.cbox.os.variant": "$OS_VARIANT"$(if [[ "$LIFECYCLE" != "stable" ]]; then echo ",
    \"io.cbox.deprecated\": \"true\",
    \"io.cbox.deprecated.message\": \"$WARNING_MESSAGE\",
    \"io.cbox.removal.date\": \"$PHP_REMOVAL_DATE\""; fi)
  },
  "warning_message": $(echo "$WARNING_MESSAGE" | jq -R .),
  "tags_suffix": "$TAGS_SUFFIX",
  "show_startup_warning": $SHOW_WARNING
}
EOF
