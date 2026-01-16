#!/bin/bash
#
# Cbox Base Images - Complete E2E Test Suite
# Runs all test scenarios and provides a summary
#
# Usage:
#   ./run-all-tests.sh                    # Run all tests
#   ./run-all-tests.sh --quick            # Run quick tests only
#   ./run-all-tests.sh --specific test    # Run specific test
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCENARIOS_DIR="$SCRIPT_DIR/scenarios"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test results
declare -A TEST_RESULTS
declare -A TEST_COUNTS
TOTAL_PASSED=0
TOTAL_FAILED=0
TOTAL_SKIPPED=0

# Test categories
QUICK_TESTS=(
    "test-plain-php.sh"
    "test-health-checks.sh"
    "test-env-config.sh"
)

FRAMEWORK_TESTS=(
    "test-laravel.sh"
    "test-wordpress.sh"
)

COMPREHENSIVE_TESTS=(
    "test-image-formats.sh"
    "test-database.sh"
    "test-security.sh"
    "test-browsershot.sh"
    "test-pest.sh"
    "test-dusk-capabilities.sh"
)

print_header() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BLUE}Cbox Base Images - E2E Test Suite${NC}                                         ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  $1${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

run_test() {
    local test_file="$1"
    local test_name="${test_file%.sh}"
    test_name="${test_name#test-}"

    echo -e "  ${BLUE}▶${NC} Running: ${CYAN}$test_name${NC}"

    local start_time=$(date +%s)
    local output
    local exit_code=0

    if output=$("$SCENARIOS_DIR/$test_file" 2>&1); then
        exit_code=0
    else
        exit_code=$?
    fi

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Extract test counts from output
    local passed=$(echo "$output" | grep -oE "PASSED: [0-9]+" | grep -oE "[0-9]+" | tail -1 || echo "0")
    local failed=$(echo "$output" | grep -oE "FAILED: [0-9]+" | grep -oE "[0-9]+" | tail -1 || echo "0")

    if [ "$exit_code" -eq 0 ]; then
        TEST_RESULTS["$test_name"]="PASSED"
        TEST_COUNTS["$test_name"]="$passed passed"
        TOTAL_PASSED=$((TOTAL_PASSED + ${passed:-0}))
        echo -e "    ${GREEN}✓${NC} Completed in ${duration}s (${passed:-0} tests passed)"
    else
        TEST_RESULTS["$test_name"]="FAILED"
        TEST_COUNTS["$test_name"]="$passed passed, $failed failed"
        TOTAL_PASSED=$((TOTAL_PASSED + ${passed:-0}))
        TOTAL_FAILED=$((TOTAL_FAILED + ${failed:-0}))
        echo -e "    ${RED}✗${NC} Failed in ${duration}s (${failed:-0} tests failed)"
        echo "$output" | tail -20
    fi
}

run_test_category() {
    local category_name="$1"
    shift
    local tests=("$@")

    print_section "$category_name"

    for test_file in "${tests[@]}"; do
        if [ -f "$SCENARIOS_DIR/$test_file" ]; then
            run_test "$test_file"
        else
            echo -e "  ${YELLOW}⚠${NC} Skipping: $test_file (not found)"
            TOTAL_SKIPPED=$((TOTAL_SKIPPED + 1))
        fi
    done
}

print_summary() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BLUE}Test Summary${NC}                                                                 ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local all_passed=true

    for test_name in "${!TEST_RESULTS[@]}"; do
        local result="${TEST_RESULTS[$test_name]}"
        local counts="${TEST_COUNTS[$test_name]}"

        if [ "$result" == "PASSED" ]; then
            printf "  ${GREEN}✓${NC} %-30s ${GREEN}%s${NC} (%s)\n" "$test_name" "$result" "$counts"
        else
            printf "  ${RED}✗${NC} %-30s ${RED}%s${NC} (%s)\n" "$test_name" "$result" "$counts"
            all_passed=false
        fi
    done

    echo ""
    echo -e "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "  ${GREEN}Total Passed:${NC}  $TOTAL_PASSED"
    echo -e "  ${RED}Total Failed:${NC}  $TOTAL_FAILED"
    if [ "$TOTAL_SKIPPED" -gt 0 ]; then
        echo -e "  ${YELLOW}Skipped:${NC}       $TOTAL_SKIPPED"
    fi
    echo ""

    if [ "$all_passed" = true ] && [ "$TOTAL_FAILED" -eq 0 ]; then
        echo -e "  ${GREEN}╔═══════════════════════════════════════════╗${NC}"
        echo -e "  ${GREEN}║     ALL TESTS PASSED SUCCESSFULLY! 🎉     ║${NC}"
        echo -e "  ${GREEN}╚═══════════════════════════════════════════╝${NC}"
        return 0
    else
        echo -e "  ${RED}╔═══════════════════════════════════════════╗${NC}"
        echo -e "  ${RED}║     SOME TESTS FAILED - CHECK OUTPUT      ║${NC}"
        echo -e "  ${RED}╚═══════════════════════════════════════════╝${NC}"
        return 1
    fi
}

# Parse arguments
MODE="all"
SPECIFIC_TEST=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --quick)
            MODE="quick"
            shift
            ;;
        --comprehensive)
            MODE="comprehensive"
            shift
            ;;
        --frameworks)
            MODE="frameworks"
            shift
            ;;
        --specific)
            MODE="specific"
            SPECIFIC_TEST="$2"
            shift 2
            ;;
        --help)
            echo "Cbox E2E Test Runner"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --quick           Run quick tests only (basic functionality)"
            echo "  --frameworks      Run framework integration tests"
            echo "  --comprehensive   Run comprehensive tests (image formats, database, security)"
            echo "  --specific NAME   Run a specific test (without .sh extension)"
            echo "  --help            Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                      # Run all tests"
            echo "  $0 --quick              # Run quick tests"
            echo "  $0 --specific database  # Run database tests only"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Main execution
print_header

case $MODE in
    quick)
        run_test_category "Quick Tests" "${QUICK_TESTS[@]}"
        ;;
    frameworks)
        run_test_category "Framework Integration Tests" "${FRAMEWORK_TESTS[@]}"
        ;;
    comprehensive)
        run_test_category "Comprehensive Tests" "${COMPREHENSIVE_TESTS[@]}"
        ;;
    specific)
        if [ -f "$SCENARIOS_DIR/test-${SPECIFIC_TEST}.sh" ]; then
            run_test "test-${SPECIFIC_TEST}.sh"
        elif [ -f "$SCENARIOS_DIR/${SPECIFIC_TEST}.sh" ]; then
            run_test "${SPECIFIC_TEST}.sh"
        else
            echo -e "${RED}Error: Test not found: $SPECIFIC_TEST${NC}"
            exit 1
        fi
        ;;
    all)
        run_test_category "Quick Tests" "${QUICK_TESTS[@]}"
        run_test_category "Framework Integration Tests" "${FRAMEWORK_TESTS[@]}"
        run_test_category "Comprehensive Tests" "${COMPREHENSIVE_TESTS[@]}"
        ;;
esac

print_summary
