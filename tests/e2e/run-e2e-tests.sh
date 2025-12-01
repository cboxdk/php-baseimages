#!/bin/bash
# PHPeek Base Images - E2E Test Runner
# Runs all E2E test scenarios across specified image variants

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/test-utils.sh"

# Default configuration
DEFAULT_IMAGE="ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine"
SCENARIOS_DIR="$SCRIPT_DIR/scenarios"
PARALLEL=${PARALLEL:-false}
VERBOSE=${VERBOSE:-false}

# Parse arguments
IMAGE="${1:-$DEFAULT_IMAGE}"
SCENARIO="${2:-all}"

usage() {
    echo "Usage: $0 [IMAGE] [SCENARIO]"
    echo ""
    echo "Arguments:"
    echo "  IMAGE     Docker image to test (default: $DEFAULT_IMAGE)"
    echo "  SCENARIO  Scenario to run: all, plain-php, laravel, symfony, wordpress, magento, drupal, typo3, statamic, health-checks"
    echo ""
    echo "Environment variables:"
    echo "  PARALLEL=true   Run scenarios in parallel (experimental)"
    echo "  VERBOSE=true    Show detailed output"
    echo ""
    echo "Examples:"
    echo "  $0                                              # Test default image, all scenarios"
    echo "  $0 ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-alpine"
    echo "  $0 ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-debian laravel"
    echo "  $0 local-test-image:latest plain-php"
    exit 1
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
fi

# Export image for docker-compose files
export IMAGE="$IMAGE"

log_section "PHPeek E2E Test Suite"
echo ""
echo "  Image:    $IMAGE"
echo "  Scenario: $SCENARIO"
echo "  Parallel: $PARALLEL"
echo ""

# Verify image exists or can be pulled
log_info "Verifying image availability..."
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    log_info "Image not found locally, attempting to pull..."
    if ! docker pull "$IMAGE" 2>/dev/null; then
        log_fail "Cannot find or pull image: $IMAGE"
        exit 1
    fi
fi
log_success "Image available: $IMAGE"

# Get available scenarios
get_scenarios() {
    local scenario_filter="$1"
    local scenarios=()

    if [ "$scenario_filter" = "all" ]; then
        for file in "$SCENARIOS_DIR"/test-*.sh; do
            if [ -f "$file" ]; then
                scenarios+=("$file")
            fi
        done
    else
        local file="$SCENARIOS_DIR/test-${scenario_filter}.sh"
        if [ -f "$file" ]; then
            scenarios+=("$file")
        else
            log_fail "Scenario not found: $scenario_filter"
            echo "Available scenarios:"
            for f in "$SCENARIOS_DIR"/test-*.sh; do
                basename "$f" .sh | sed 's/test-/  - /'
            done
            exit 1
        fi
    fi

    echo "${scenarios[@]}"
}

# Run a single scenario
run_scenario() {
    local scenario_file="$1"
    local scenario_name=$(basename "$scenario_file" .sh | sed 's/test-//')
    local log_file="/tmp/e2e-${scenario_name}-$$.log"

    log_info "Running scenario: $scenario_name"

    if [ "$VERBOSE" = "true" ]; then
        if bash "$scenario_file"; then
            return 0
        else
            return 1
        fi
    else
        if bash "$scenario_file" > "$log_file" 2>&1; then
            # Extract summary from log
            grep -E "^\[PASS\]|\[FAIL\]" "$log_file" | tail -20
            rm -f "$log_file"
            return 0
        else
            echo "  Scenario failed. Log output:"
            cat "$log_file"
            rm -f "$log_file"
            return 1
        fi
    fi
}

# Main execution
SCENARIOS=($(get_scenarios "$SCENARIO"))
TOTAL_SCENARIOS=${#SCENARIOS[@]}
PASSED_SCENARIOS=0
FAILED_SCENARIOS=0

log_info "Found $TOTAL_SCENARIOS scenario(s) to run"

for scenario in "${SCENARIOS[@]}"; do
    echo ""
    if run_scenario "$scenario"; then
        ((PASSED_SCENARIOS++))
    else
        ((FAILED_SCENARIOS++))
    fi
done

# Final summary
echo ""
log_section "E2E Test Suite Summary"
echo ""
echo "  Image tested:  $IMAGE"
echo "  Scenarios run: $TOTAL_SCENARIOS"
echo -e "  ${GREEN}Passed:${NC}        $PASSED_SCENARIOS"
echo -e "  ${RED}Failed:${NC}        $FAILED_SCENARIOS"
echo ""

if [ $FAILED_SCENARIOS -gt 0 ]; then
    echo -e "${RED}E2E tests failed!${NC}"
    exit 1
else
    echo -e "${GREEN}All E2E tests passed!${NC}"
    exit 0
fi
