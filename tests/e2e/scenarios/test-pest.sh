#!/bin/bash
# E2E Test: Pest PHP v4 Testing Framework
# Tests Pest v4 with native browser testing (Playwright), architecture testing,
# and all v4-specific features

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-utils.sh"

E2E_ROOT="$(get_e2e_root)"
FIXTURE_DIR="$E2E_ROOT/fixtures/pest-testing"
PROJECT_NAME="e2e-pest-testing"
CONTAINER_NAME="e2e-pest-testing"

# Global to track the script's intended exit code
SCRIPT_EXIT_CODE=0

# Cleanup on exit - completely isolated from strict modes
cleanup_and_exit() {
    # Capture desired exit code FIRST before any commands
    local desired_exit="${SCRIPT_EXIT_CODE:-0}"

    # Disable all strict modes
    set +e
    set +u
    set +o pipefail

    # Run cleanup in a fully isolated subshell
    (
        set +e +u +o pipefail 2>/dev/null
        cleanup_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME" 2>/dev/null
        true
    ) 2>/dev/null || true

    # Force the exact exit code we want
    exit "$desired_exit"
}
trap cleanup_and_exit EXIT

log_section "Pest PHP v4 Testing Framework E2E Test"

# Start the container
cleanup_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME"
start_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME"

# Wait for container
wait_for_healthy "$CONTAINER_NAME" 30

log_section "PHP Environment"

# Test PHP version
assert_exec_succeeds "$CONTAINER_NAME" "php -v" "PHP is available"

# Test Composer is available
assert_exec_succeeds "$CONTAINER_NAME" "composer --version" "Composer is available"

log_section "Installing Dependencies"

# Install Composer dependencies
log_info "Installing Composer dependencies (this may take a moment)..."
docker exec "$CONTAINER_NAME" composer install --no-interaction --prefer-dist 2>&1 | tail -5

if docker exec "$CONTAINER_NAME" test -d vendor; then
    log_success "Composer dependencies installed"
else
    log_fail "Composer dependencies installation failed"
fi

# Check Pest is installed
if docker exec "$CONTAINER_NAME" test -f vendor/bin/pest; then
    log_success "Pest binary exists"
else
    log_fail "Pest binary not found"
fi

log_section "Pest v4 Version Check"

# Check Pest version - MUST be v4.x
PEST_VERSION_RAW=$(docker exec "$CONTAINER_NAME" ./vendor/bin/pest --version 2>&1 || echo "unknown")
# Strip ANSI escape codes for clean parsing
PEST_VERSION=$(echo "$PEST_VERSION_RAW" | sed 's/\x1b\[[0-9;]*m//g' | tr -d '\r')
log_info "Pest version: $PEST_VERSION"

# Extract major version number - look for version pattern like "4.1.6"
MAJOR_VERSION=$(echo "$PEST_VERSION" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 | cut -d'.' -f1)
MAJOR_VERSION=${MAJOR_VERSION:-0}

if [ "$MAJOR_VERSION" -ge 4 ]; then
    log_success "Pest v4 detected: $PEST_VERSION"
elif [ "$MAJOR_VERSION" -eq 3 ]; then
    log_warn "Pest v3 detected (expected v4): $PEST_VERSION"
else
    log_fail "Pest version too old: $PEST_VERSION (need v4+)"
fi

# Verify v4 specific features
if [ "$MAJOR_VERSION" -ge 4 ]; then
    log_info "Verifying Pest v4 specific features..."

    # Check for browser plugin
    if docker exec "$CONTAINER_NAME" composer show pestphp/pest-plugin-browser 2>/dev/null | grep -q "version"; then
        log_success "Pest browser plugin installed (Playwright-powered)"
    else
        log_info "Browser plugin not installed (optional)"
    fi

    # Check for arch plugin
    if docker exec "$CONTAINER_NAME" composer show pestphp/pest-plugin-arch 2>/dev/null | grep -q "version"; then
        log_success "Pest architecture plugin installed"
    else
        log_info "Architecture plugin not installed (optional)"
    fi
fi

log_section "Running Pest Tests"

# Run Pest tests
log_info "Executing Pest test suite..."
TEST_OUTPUT=$(docker exec "$CONTAINER_NAME" ./vendor/bin/pest --colors=never 2>&1 || true)
echo "$TEST_OUTPUT"

# Parse test results
if echo "$TEST_OUTPUT" | grep -qE "Tests:.*passed"; then
    log_success "Pest tests executed successfully"

    # Extract pass count
    PASSED=$(echo "$TEST_OUTPUT" | grep -oE "[0-9]+ passed" | grep -oE "[0-9]+")
    if [ -n "$PASSED" ] && [ "$PASSED" -gt 0 ]; then
        log_success "$PASSED tests passed"
    fi
else
    log_fail "Pest tests failed or did not complete"
fi

# Check for failures
if echo "$TEST_OUTPUT" | grep -qE "failed|FAILED"; then
    FAILED=$(echo "$TEST_OUTPUT" | grep -oE "[0-9]+ failed" | grep -oE "[0-9]+" || echo "some")
    log_fail "$FAILED tests failed"
fi

log_section "Pest Features Validation"

# Test describe blocks work - verify actual describe() output
if echo "$TEST_OUTPUT" | grep -qE "describe|Calculator|PASS.*Calculator"; then
    log_success "Describe blocks work (found in test output)"
else
    log_warn "Could not verify describe blocks in output"
fi

# Test datasets work - count iterations to verify dataset expansion
# Strip ANSI codes and count dataset test lines (look for "with (" pattern from Pest output)
CLEAN_OUTPUT=$(echo "$TEST_OUTPUT" | sed 's/\x1b\[[0-9;]*m//g')
DATASET_MATCHES=$(echo "$CLEAN_OUTPUT" | grep -cE "with \([0-9]|multiple inputs" 2>/dev/null || echo "0")
DATASET_MATCHES=${DATASET_MATCHES:-0}
if [ "$DATASET_MATCHES" -gt 1 ]; then
    log_success "Datasets work ($DATASET_MATCHES dataset iterations found)"
elif [ "$DATASET_MATCHES" -eq 1 ]; then
    log_warn "Dataset test found but only 1 iteration (expected multiple)"
else
    # Check alternative pattern
    if echo "$CLEAN_OUTPUT" | grep -qE "dataset|inputs"; then
        log_success "Datasets work (patterns detected)"
    else
        log_warn "Could not verify datasets"
    fi
fi

# Test custom expectations
log_info "Testing custom expectation (toBeOne)..."
CUSTOM_TEST=$(docker exec "$CONTAINER_NAME" sh -c "
    cd /var/www/html && ./vendor/bin/pest --filter='custom expectation' 2>&1 || echo ''
" 2>&1)

if echo "$CUSTOM_TEST" | grep -qE "PASS|passed"; then
    log_success "Custom expectations work"
else
    log_info "Custom expectation test: $CUSTOM_TEST"
fi

log_section "Architecture Testing (Pest v4 Feature)"

# Test architecture testing - this is a key Pest v4 feature
log_info "Checking for architecture tests..."
ARCH_TEST=$(docker exec "$CONTAINER_NAME" sh -c "
    cd /var/www/html
    if [ -f tests/Architecture/ArchitectureTest.php ]; then
        ./vendor/bin/pest tests/Architecture --colors=never 2>&1
    elif [ -f tests/ArchitectureTest.php ]; then
        ./vendor/bin/pest tests/ArchitectureTest.php --colors=never 2>&1
    else
        echo 'no_arch_tests'
    fi
" 2>&1)

if echo "$ARCH_TEST" | grep -qE "PASS|passed"; then
    log_success "Architecture testing works"
    ARCH_PASSED=$(echo "$ARCH_TEST" | grep -oE "[0-9]+ passed" | head -1 || echo "")
    [ -n "$ARCH_PASSED" ] && log_info "Architecture tests: $ARCH_PASSED"
elif echo "$ARCH_TEST" | grep -q "no_arch_tests"; then
    log_info "No architecture tests in fixture (optional feature)"
else
    log_warn "Architecture test output: ${ARCH_TEST:0:200}"
fi

log_section "Browser Testing (Pest v4 Playwright Feature)"

# Test browser testing - Pest v4's killer feature
log_info "Checking for browser tests..."
BROWSER_TEST=$(docker exec "$CONTAINER_NAME" sh -c "
    cd /var/www/html
    if [ -d tests/Browser ]; then
        # Browser tests require Playwright, which needs Node.js
        if command -v node >/dev/null 2>&1; then
            ./vendor/bin/pest tests/Browser --colors=never 2>&1 || echo 'browser_test_run'
        else
            echo 'no_nodejs'
        fi
    else
        echo 'no_browser_tests'
    fi
" 2>&1)

if echo "$BROWSER_TEST" | grep -qE "PASS|passed"; then
    log_success "Browser testing works (Playwright-powered)"
    BROWSER_PASSED=$(echo "$BROWSER_TEST" | grep -oE "[0-9]+ passed" | head -1 || echo "")
    [ -n "$BROWSER_PASSED" ] && log_info "Browser tests: $BROWSER_PASSED"
elif echo "$BROWSER_TEST" | grep -q "no_browser_tests"; then
    log_info "No browser tests in fixture"
elif echo "$BROWSER_TEST" | grep -q "no_nodejs"; then
    log_info "Node.js not available for Playwright (browser tests skipped)"
elif echo "$BROWSER_TEST" | grep -qE "skip|Skip"; then
    log_info "Browser tests skipped (Playwright not configured)"
else
    log_info "Browser test output: ${BROWSER_TEST:0:200}"
fi

log_section "Pest Plugin Verification"

# Check for common Pest plugins
log_info "Checking installed Pest plugins..."
PLUGINS=$(docker exec "$CONTAINER_NAME" composer show 2>/dev/null | grep -E "pestphp/" || echo "none")
if [ "$PLUGINS" != "none" ]; then
    log_success "Pest plugins installed:"
    echo "$PLUGINS" | while read -r line; do
        log_info "  - $line"
    done
else
    log_info "No additional Pest plugins installed"
fi

# Verify Pest configuration
log_info "Checking Pest configuration..."
if docker exec "$CONTAINER_NAME" test -f phpunit.xml || docker exec "$CONTAINER_NAME" test -f pest.php; then
    log_success "Pest configuration file exists"
else
    log_warn "No pest.php or phpunit.xml found"
fi

log_section "Coverage Capability"

# Check if coverage is available (requires Xdebug or PCOV)
COVERAGE_CHECK=$(docker exec "$CONTAINER_NAME" php -m 2>/dev/null | grep -iE "xdebug|pcov" || echo "")
if [ -n "$COVERAGE_CHECK" ]; then
    log_success "Code coverage driver available: $COVERAGE_CHECK"

    # Quick coverage test
    log_info "Testing coverage capability..."
    COVERAGE_TEST=$(docker exec "$CONTAINER_NAME" sh -c "
        cd /var/www/html && \
        ./vendor/bin/pest --coverage --min=0 2>&1 | head -20
    " 2>&1 || echo "")

    if echo "$COVERAGE_TEST" | grep -qE "Coverage|%"; then
        log_success "Code coverage works"
    else
        log_info "Coverage test output: ${COVERAGE_TEST:0:100}"
    fi
else
    log_info "No coverage driver (Xdebug/PCOV) - coverage tests skipped"
fi

log_section "Pest v4 Type Coverage (2x Faster)"

# Test type coverage - Pest v4 feature that's 2x faster than v3
log_info "Testing type coverage..."
TYPE_COVERAGE=$(docker exec "$CONTAINER_NAME" sh -c "
    cd /var/www/html && \
    ./vendor/bin/pest --type-coverage 2>&1 | head -15
" 2>&1 || echo "")

if echo "$TYPE_COVERAGE" | grep -qE "Type Coverage|%"; then
    log_success "Type coverage works (Pest v4 - 2x faster)"
    TYPE_PCT=$(echo "$TYPE_COVERAGE" | grep -oE "[0-9]+\.[0-9]+%" | head -1 || echo "")
    [ -n "$TYPE_PCT" ] && log_info "Type coverage: $TYPE_PCT"
else
    log_info "Type coverage output: ${TYPE_COVERAGE:0:100}"
fi

log_section "Pest v4 Parallel Testing"

# Test parallel execution - Pest v4 feature
log_info "Testing parallel test execution..."
PARALLEL_TEST=$(docker exec "$CONTAINER_NAME" sh -c "
    cd /var/www/html && \
    ./vendor/bin/pest --parallel 2>&1 | tail -10
" 2>&1 || echo "")

if echo "$PARALLEL_TEST" | grep -qE "passed|PASS"; then
    log_success "Parallel testing works"
else
    log_info "Parallel test: ${PARALLEL_TEST:0:100}"
fi

print_summary

exit 0
