#!/bin/bash
# E2E Test: Symfony Framework Detection and Integration
# Tests Symfony-specific entrypoint behavior, permissions, and caching

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-utils.sh"

E2E_ROOT="$(get_e2e_root)"
FIXTURE_DIR="$E2E_ROOT/fixtures/symfony"
PROJECT_NAME="e2e-symfony"
CONTAINER_NAME="e2e-symfony-app"
BASE_URL="http://localhost:8095"

# Simple cleanup function - called explicitly, not via trap
# Always returns 0 regardless of docker compose result
do_cleanup() {
    cleanup_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME"
    return 0
}

log_section "Symfony Framework E2E Test"

# Clean up any existing containers
cleanup_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME" 2>/dev/null || true

# Start container
log_info "Starting Symfony test container..."
docker compose -f "$FIXTURE_DIR/docker-compose.yml" -p "$PROJECT_NAME" up -d 2>&1 || {
    log_fail "Failed to start docker compose"
    exit 1
}

wait_for_healthy "$CONTAINER_NAME" 60

# ═══════════════════════════════════════════════════════════════════════════
# TEST 1: Symfony Framework Detection
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 1: Symfony Framework Detection"

# Check if entrypoint detected Symfony
LOGS=$(docker logs "$CONTAINER_NAME" 2>&1)
if echo "$LOGS" | grep -qi "symfony"; then
    log_success "Entrypoint detected Symfony framework"
else
    log_warn "Symfony detection message not found in logs"
fi

# Verify bin/console exists
assert_file_exists "$CONTAINER_NAME" "/var/www/html/bin/console" "Symfony bin/console exists"

# ═══════════════════════════════════════════════════════════════════════════
# TEST 2: Symfony Directory Permissions
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 2: Symfony Directory Permissions"

# Check var/ directory permissions
assert_dir_exists "$CONTAINER_NAME" "/var/www/html/var" "Symfony var/ directory exists"
assert_dir_exists "$CONTAINER_NAME" "/var/www/html/var/cache" "Symfony var/cache/ directory exists"
assert_dir_exists "$CONTAINER_NAME" "/var/www/html/var/log" "Symfony var/log/ directory exists"

# Check writable by www-data
if docker exec "$CONTAINER_NAME" sh -c "su -s /bin/sh www-data -c 'touch /var/www/html/var/cache/test_file && rm /var/www/html/var/cache/test_file'" 2>/dev/null; then
    log_success "var/cache/ is writable by www-data"
else
    log_fail "var/cache/ is NOT writable by www-data"
fi

if docker exec "$CONTAINER_NAME" sh -c "su -s /bin/sh www-data -c 'touch /var/www/html/var/log/test_file && rm /var/www/html/var/log/test_file'" 2>/dev/null; then
    log_success "var/log/ is writable by www-data"
else
    log_fail "var/log/ is NOT writable by www-data"
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 3: Symfony Console Commands
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 3: Symfony Console Commands"

# Test bin/console list
if docker exec "$CONTAINER_NAME" php /var/www/html/bin/console list --no-ansi 2>&1 | grep -q "Available commands"; then
    log_success "Symfony console 'list' command works"
else
    log_fail "Symfony console 'list' command failed"
fi

# Test cache:clear
if docker exec "$CONTAINER_NAME" php /var/www/html/bin/console cache:clear --no-warmup --env=prod 2>&1 | grep -qi "cache"; then
    log_success "Symfony cache:clear works"
else
    log_warn "Symfony cache:clear may have issues"
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 4: HTTP Response
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 4: HTTP Response"

# Test health endpoint
assert_http_code "$BASE_URL/health" 200 "Health endpoint returns 200"

# Test main endpoint
assert_http_code "$BASE_URL/" 200 "Main endpoint returns 200"
assert_http_contains "$BASE_URL/" "Symfony" "Response contains Symfony identifier"

# ═══════════════════════════════════════════════════════════════════════════
# TEST 5: Symfony Environment
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 5: Symfony Environment"

# Check APP_ENV
APP_ENV=$(docker exec "$CONTAINER_NAME" sh -c 'echo $APP_ENV' 2>/dev/null || echo "")
if [ -n "$APP_ENV" ]; then
    log_success "APP_ENV is set: $APP_ENV"
else
    log_info "APP_ENV not set (will use default)"
fi

# Check for debug mode indicator
if docker exec "$CONTAINER_NAME" php /var/www/html/bin/console about 2>&1 | grep -qi "Environment"; then
    log_success "Symfony 'about' command provides environment info"
else
    log_info "Symfony 'about' command not available (minimal install)"
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 6: PHP Extensions for Symfony
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 6: PHP Extensions for Symfony"

# Essential extensions for Symfony
SYMFONY_EXTENSIONS="intl mbstring xml ctype iconv"

for ext in $SYMFONY_EXTENSIONS; do
    if docker exec "$CONTAINER_NAME" php -m 2>/dev/null | grep -qi "^${ext}$"; then
        log_success "PHP extension: $ext"
    else
        log_warn "PHP extension missing: $ext"
    fi
done

# Check OPcache (recommended for Symfony)
if docker exec "$CONTAINER_NAME" php -m 2>/dev/null | grep -q "Zend OPcache"; then
    log_success "OPcache is enabled (recommended for Symfony)"
else
    log_warn "OPcache not enabled"
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 7: Symfony Doctrine Support (if available)
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 7: Database Extensions"

# Check PDO and drivers
if docker exec "$CONTAINER_NAME" php -r "exit(class_exists('PDO') ? 0 : 1);" 2>/dev/null; then
    log_success "PDO is available"
else
    log_fail "PDO is NOT available"
fi

# Check specific drivers
for driver in pdo_mysql pdo_pgsql pdo_sqlite; do
    if docker exec "$CONTAINER_NAME" php -m 2>/dev/null | grep -qi "$driver"; then
        log_success "PDO driver: $driver"
    else
        log_info "PDO driver not installed: $driver"
    fi
done

# ═══════════════════════════════════════════════════════════════════════════
# TEST 8: Composer
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 8: Composer Availability"

assert_exec_succeeds "$CONTAINER_NAME" "which composer" "Composer is installed"
assert_exec_succeeds "$CONTAINER_NAME" "composer --version --no-ansi" "Composer works"

# ═══════════════════════════════════════════════════════════════════════════
# TEST 9: PHPeek PM Integration
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 9: PHPeek PM Integration"

if command -v phpeek-pm >/dev/null 2>&1 || docker exec "$CONTAINER_NAME" which phpeek-pm >/dev/null 2>&1; then
    assert_exec_succeeds "$CONTAINER_NAME" "phpeek-pm --version" "PHPeek PM available"
else
    log_info "PHPeek PM not installed in this image"
fi

# Store test results before any cleanup that might affect shell state
FINAL_PASSED=$TESTS_PASSED
FINAL_FAILED=$TESTS_FAILED

# Print summary (doesn't affect exit code when used with ||)
print_summary || true

# Disable strict mode for cleanup - this is critical for proper exit codes
set +euo pipefail

# Always cleanup, ignoring any errors
do_cleanup

# Exit based on test results
if [ "$FINAL_FAILED" -gt 0 ]; then
    exit 1
fi
exit 0
