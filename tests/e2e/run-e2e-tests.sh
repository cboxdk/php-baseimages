#!/bin/bash
# Cbox Base Images - E2E Test Runner
# Runs all E2E test scenarios across specified image variants

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/test-utils.sh"

# Default configuration
DEFAULT_IMAGE="ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.5-bookworm-v1"
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
    echo "  $0 ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-alpine"
    echo "  $0 ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.3-debian laravel"
    echo "  $0 local-test-image:latest plain-php"
    exit 1
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
fi

# Export image for docker-compose files
export IMAGE="$IMAGE"

log_section "Cbox E2E Test Suite"
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

    # Tier-aware skip: a scenario declaring "# requires: chromium" is skipped
    # (not failed) when the image has no chromium - running the browsershot
    # suite against a slim/standard image only produces noise.
    if grep -q "^# requires: chromium" "$scenario_file" 2>/dev/null; then
        if ! docker run --rm --entrypoint sh "$IMAGE" -c 'command -v chromium >/dev/null' 2>/dev/null; then
            log_info "SKIP: $scenario_name requires chromium; image $IMAGE has none"
            return 2
        fi
    fi

    # The rootless scenario needs a rootless-variant image (USER www-data,
    # nginx on 8080). Run it against ROOTLESS_IMAGE when provided; otherwise
    # skip unless the main image itself is rootless.
    if grep -q "^# requires: rootless" "$scenario_file" 2>/dev/null; then
        if [ -n "${ROOTLESS_IMAGE:-}" ]; then
            log_info "Using ROOTLESS_IMAGE=$ROOTLESS_IMAGE for $scenario_name"
            if [ "$VERBOSE" = "true" ]; then
                IMAGE="$ROOTLESS_IMAGE" bash "$scenario_file" && return 0 || return 1
            else
                if IMAGE="$ROOTLESS_IMAGE" bash "$scenario_file" > "$log_file" 2>&1; then
                    grep -E "^\[PASS\]|\[FAIL\]" "$log_file" | tail -20
                    rm -f "$log_file"; return 0
                else
                    echo "  Scenario failed. Log output:"; cat "$log_file"; rm -f "$log_file"; return 1
                fi
            fi
        elif [ -z "$(docker image inspect -f '{{.Config.User}}' "$IMAGE" 2>/dev/null)" ]; then
            log_info "SKIP: $scenario_name requires a rootless image; set ROOTLESS_IMAGE or test a -rootless tag"
            return 2
        fi
    fi

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

SKIPPED_SCENARIOS=0
for scenario in "${SCENARIOS[@]}"; do
    echo ""
    rc=0
    run_scenario "$scenario" || rc=$?
    # Guaranteed teardown: scenarios only clean up on success (no traps), so a
    # failed one leaks its compose stack and its ports collide with the next
    # scenarios (8090/8095 are shared). Sweep the scenario's project either way.
    sn=$(basename "$scenario" .sh | sed 's/test-//')
    docker compose -p "e2e-${sn}" down -v --remove-orphans >/dev/null 2>&1 || true
    # Some scenarios use plain docker run with their own e2e-* names (e.g.
    # e2e-health-check, e2e-env-full); compose down does not know those. The
    # suite is sequential, so removing every leftover e2e-* container here is
    # safe and keeps the shared ports (8090-8096) free for the next scenario.
    leftovers=$(docker ps -aq --filter "name=^e2e-" 2>/dev/null || true)
    [ -n "$leftovers" ] && docker rm -f $leftovers >/dev/null 2>&1 || true
    if [ "$rc" -eq 0 ]; then
        ((PASSED_SCENARIOS++)) || true
    elif [ "$rc" -eq 2 ]; then
        ((SKIPPED_SCENARIOS++)) || true
    else
        ((FAILED_SCENARIOS++)) || true
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
