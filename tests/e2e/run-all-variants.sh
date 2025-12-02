#!/bin/bash
# PHPeek Base Images - Multi-Variant E2E Test Runner
# Tests all image variants (Alpine, Debian, Ubuntu) across PHP versions

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/test-utils.sh"

# Configuration
REGISTRY="${REGISTRY:-ghcr.io/gophpeek/baseimages}"
PHP_VERSIONS="${PHP_VERSIONS:-8.3}"
OS_VARIANTS="${OS_VARIANTS:-alpine debian ubuntu}"
SCENARIO="${1:-plain-php}"  # Default to quick test

usage() {
    echo "Usage: $0 [SCENARIO]"
    echo ""
    echo "Arguments:"
    echo "  SCENARIO  Test scenario: plain-php, laravel, wordpress, health-checks, all"
    echo ""
    echo "Environment variables:"
    echo "  REGISTRY=ghcr.io/gophpeek/baseimages   Image registry"
    echo "  PHP_VERSIONS='8.2 8.3 8.4'           Space-separated PHP versions"
    echo "  OS_VARIANTS='alpine debian ubuntu'   Space-separated OS variants"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Quick test (plain-php) all variants"
    echo "  $0 all                                # Full test suite all variants"
    echo "  PHP_VERSIONS='8.3 8.4' $0 laravel    # Laravel tests on PHP 8.3 and 8.4"
    exit 1
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
fi

log_section "PHPeek Multi-Variant E2E Test Suite"
echo ""
echo "  Registry:     $REGISTRY"
echo "  PHP Versions: $PHP_VERSIONS"
echo "  OS Variants:  $OS_VARIANTS"
echo "  Scenario:     $SCENARIO"
echo ""

# Track results
declare -A RESULTS
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Run tests for each variant
for version in $PHP_VERSIONS; do
    for os in $OS_VARIANTS; do
        IMAGE="${REGISTRY}/php-fpm-nginx:${version}-${os}"
        VARIANT_KEY="${version}-${os}"

        log_section "Testing: $VARIANT_KEY"

        # Check if image exists
        if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
            log_info "Pulling image: $IMAGE"
            if ! docker pull "$IMAGE" 2>/dev/null; then
                log_skip "Image not available: $IMAGE"
                RESULTS[$VARIANT_KEY]="skipped"
                continue
            fi
        fi

        ((TOTAL_TESTS++))

        # Run the test
        if "$SCRIPT_DIR/run-e2e-tests.sh" "$IMAGE" "$SCENARIO"; then
            RESULTS[$VARIANT_KEY]="passed"
            ((PASSED_TESTS++))
            log_success "Variant $VARIANT_KEY: PASSED"
        else
            RESULTS[$VARIANT_KEY]="failed"
            ((FAILED_TESTS++))
            log_fail "Variant $VARIANT_KEY: FAILED"
        fi
    done
done

# Print summary table
echo ""
log_section "Multi-Variant Test Results"
echo ""
printf "  %-20s %-10s\n" "VARIANT" "RESULT"
printf "  %-20s %-10s\n" "-------" "------"

for key in "${!RESULTS[@]}"; do
    result="${RESULTS[$key]}"
    case $result in
        passed)
            printf "  %-20s ${GREEN}%-10s${NC}\n" "$key" "PASSED"
            ;;
        failed)
            printf "  %-20s ${RED}%-10s${NC}\n" "$key" "FAILED"
            ;;
        skipped)
            printf "  %-20s ${YELLOW}%-10s${NC}\n" "$key" "SKIPPED"
            ;;
    esac
done

echo ""
echo "  Total:   $TOTAL_TESTS"
echo -e "  ${GREEN}Passed:${NC}  $PASSED_TESTS"
echo -e "  ${RED}Failed:${NC}  $FAILED_TESTS"
echo ""

if [ $FAILED_TESTS -gt 0 ]; then
    echo -e "${RED}Some variants failed!${NC}"
    exit 1
else
    echo -e "${GREEN}All variants passed!${NC}"
    exit 0
fi
