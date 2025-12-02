#!/usr/bin/env bash
# ============================================================================
# PHPeek Base Images - EOL & Deprecation Check Script
# ============================================================================
# Checks all components for upcoming EOL dates and generates warnings/actions
#
# Usage:
#   ./scripts/check-eol.sh              # Show all EOL status
#   ./scripts/check-eol.sh --warnings   # Only show items needing attention
#   ./scripts/check-eol.sh --json       # Output as JSON for CI
#
# Exit codes:
#   0 - No immediate action needed
#   1 - Items deprecated or EOL within warning period
#   2 - Items past EOL and should be removed
# ============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
VERSIONS_FILE="$REPO_ROOT/versions.json"

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Parse arguments
WARNINGS_ONLY=false
JSON_OUTPUT=false
for arg in "$@"; do
    case $arg in
        --warnings) WARNINGS_ONLY=true ;;
        --json) JSON_OUTPUT=true ;;
        --help|-h)
            echo "Usage: $0 [--warnings] [--json]"
            exit 0
            ;;
    esac
done

# Load versions.json
VERSIONS=$(cat "$VERSIONS_FILE")

# Get policy settings
WARNING_DAYS=$(echo "$VERSIONS" | jq -r '.deprecation_policy.warning_before_removal_days // 90')
PHP_REMOVAL_MONTHS=$(echo "$VERSIONS" | jq -r '.deprecation_policy.php_removal_after_eol_months // 6')
OS_REMOVAL_MONTHS=$(echo "$VERSIONS" | jq -r '.deprecation_policy.os_removal_after_eol_months // 3')
NODE_REMOVAL_MONTHS=$(echo "$VERSIONS" | jq -r '.deprecation_policy.node_removal_after_eol_months // 6')

# Today's date
TODAY=$(date +%Y-%m-%d)
TODAY_SEC=$(date -d "$TODAY" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$TODAY" +%s)

# Results tracking
declare -a CRITICAL=()
declare -a WARNINGS=()
declare -a UPCOMING=()
declare -a OK=()

# ============================================================================
# Helper functions
# ============================================================================

days_until() {
    local eol_date="$1"
    local eol_sec
    eol_sec=$(date -d "$eol_date" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$eol_date" +%s)
    echo $(( (eol_sec - TODAY_SEC) / 86400 ))
}

add_months_to_date() {
    local base_date="$1"
    local months="$2"
    # Cross-platform date math
    if date --version >/dev/null 2>&1; then
        # GNU date (Linux)
        date -d "$base_date + $months months" +%Y-%m-%d
    else
        # BSD date (macOS)
        date -j -v+"${months}m" -f "%Y-%m-%d" "$base_date" +%Y-%m-%d
    fi
}

check_eol() {
    local component="$1"
    local version="$2"
    local eol_date="$3"
    local removal_months="$4"

    local days_left=$(days_until "$eol_date")
    local removal_date=$(add_months_to_date "$eol_date" "$removal_months")
    local days_to_removal=$(days_until "$removal_date")

    if [[ $days_to_removal -lt 0 ]]; then
        # Past removal date - CRITICAL
        CRITICAL+=("$component $version: PAST REMOVAL DATE (EOL: $eol_date, should remove: $removal_date)")
        return 2
    elif [[ $days_left -lt 0 ]]; then
        # Past EOL but within grace period
        WARNINGS+=("$component $version: EOL PASSED (EOL: $eol_date, removal in ${days_to_removal} days: $removal_date)")
        return 1
    elif [[ $days_left -lt $WARNING_DAYS ]]; then
        # Within warning period
        WARNINGS+=("$component $version: EOL in ${days_left} days ($eol_date), removal: $removal_date")
        return 1
    elif [[ $days_left -lt 365 ]]; then
        # EOL within a year
        UPCOMING+=("$component $version: EOL in ${days_left} days ($eol_date)")
        return 0
    else
        OK+=("$component $version: EOL $eol_date (${days_left} days)")
        return 0
    fi
}

# ============================================================================
# Check all components
# ============================================================================

if [[ "$JSON_OUTPUT" != true ]]; then
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  PHPeek Base Images - EOL & Deprecation Report${NC}"
    echo -e "${BLUE}  Date: $TODAY${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
fi

# --- PHP Versions ---
if [[ "$JSON_OUTPUT" != true ]]; then
    echo -e "${CYAN}PHP Versions${NC}"
fi

for version in $(echo "$VERSIONS" | jq -r '.php.supported[]'); do
    eol=$(echo "$VERSIONS" | jq -r ".php.eol[\"$version\"]")
    check_eol "PHP" "$version" "$eol" "$PHP_REMOVAL_MONTHS" || true
done

# --- Node.js ---
if [[ "$JSON_OUTPUT" != true ]]; then
    echo -e "\n${CYAN}Node.js${NC}"
fi

node_version=$(echo "$VERSIONS" | jq -r '.node.version')
node_eol=$(echo "$VERSIONS" | jq -r '.node.eol')
if [[ "$node_eol" != "null" && -n "$node_eol" ]]; then
    check_eol "Node.js" "$node_version" "$node_eol" "$NODE_REMOVAL_MONTHS" || true
fi

# --- Alpine ---
if [[ "$JSON_OUTPUT" != true ]]; then
    echo -e "\n${CYAN}Alpine Linux${NC}"
fi

for version in $(echo "$VERSIONS" | jq -r '.os.alpine.supported[]' 2>/dev/null); do
    eol=$(echo "$VERSIONS" | jq -r ".os.alpine.eol[\"$version\"]" 2>/dev/null)
    if [[ "$eol" != "null" && -n "$eol" ]]; then
        check_eol "Alpine" "$version" "$eol" "$OS_REMOVAL_MONTHS" || true
    fi
done

# --- Debian ---
if [[ "$JSON_OUTPUT" != true ]]; then
    echo -e "\n${CYAN}Debian${NC}"
fi

for codename in $(echo "$VERSIONS" | jq -r '.os.debian.supported[]' 2>/dev/null); do
    eol=$(echo "$VERSIONS" | jq -r ".os.debian.eol[\"$codename\"]" 2>/dev/null)
    if [[ "$eol" != "null" && -n "$eol" ]]; then
        check_eol "Debian" "$codename" "$eol" "$OS_REMOVAL_MONTHS" || true
    fi
done

# ============================================================================
# Output results
# ============================================================================

EXIT_CODE=0

if [[ "$JSON_OUTPUT" == true ]]; then
    # JSON output for CI
    cat <<EOF
{
  "date": "$TODAY",
  "critical": $(printf '%s\n' "${CRITICAL[@]}" | jq -R . | jq -s .),
  "warnings": $(printf '%s\n' "${WARNINGS[@]}" | jq -R . | jq -s .),
  "upcoming": $(printf '%s\n' "${UPCOMING[@]}" | jq -R . | jq -s .),
  "ok": $(printf '%s\n' "${OK[@]}" | jq -R . | jq -s .),
  "exit_code": $([[ ${#CRITICAL[@]} -gt 0 ]] && echo 2 || ([[ ${#WARNINGS[@]} -gt 0 ]] && echo 1 || echo 0))
}
EOF
else
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Critical items
    if [[ ${#CRITICAL[@]} -gt 0 ]]; then
        echo -e "${RED}🚨 CRITICAL - Immediate Action Required:${NC}"
        for item in "${CRITICAL[@]}"; do
            echo -e "   ${RED}✗${NC} $item"
        done
        echo ""
        EXIT_CODE=2
    fi

    # Warnings
    if [[ ${#WARNINGS[@]} -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  WARNINGS - Action Needed Soon:${NC}"
        for item in "${WARNINGS[@]}"; do
            echo -e "   ${YELLOW}!${NC} $item"
        done
        echo ""
        [[ $EXIT_CODE -lt 1 ]] && EXIT_CODE=1
    fi

    # Upcoming (only if not --warnings)
    if [[ "$WARNINGS_ONLY" != true && ${#UPCOMING[@]} -gt 0 ]]; then
        echo -e "${CYAN}📅 Upcoming EOL (within 1 year):${NC}"
        for item in "${UPCOMING[@]}"; do
            echo -e "   ${CYAN}○${NC} $item"
        done
        echo ""
    fi

    # OK items (only if not --warnings)
    if [[ "$WARNINGS_ONLY" != true && ${#OK[@]} -gt 0 ]]; then
        echo -e "${GREEN}✅ OK:${NC}"
        for item in "${OK[@]}"; do
            echo -e "   ${GREEN}✓${NC} $item"
        done
        echo ""
    fi

    # Summary
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "Summary: ${RED}${#CRITICAL[@]} critical${NC}, ${YELLOW}${#WARNINGS[@]} warnings${NC}, ${CYAN}${#UPCOMING[@]} upcoming${NC}, ${GREEN}${#OK[@]} ok${NC}"

    # Deprecation policy reminder
    echo ""
    echo -e "${BLUE}Deprecation Policy:${NC}"
    echo "  • PHP: Removed $PHP_REMOVAL_MONTHS months after EOL"
    echo "  • OS:  Removed $OS_REMOVAL_MONTHS months after EOL"
    echo "  • Node: Removed $NODE_REMOVAL_MONTHS months after EOL"
    echo "  • Warning period: $WARNING_DAYS days before removal"
fi

exit $EXIT_CODE
