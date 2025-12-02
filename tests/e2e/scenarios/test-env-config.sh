#!/bin/bash
# E2E Test: Environment Variable Configuration
# Tests that env vars are passed correctly to PHP and handles missing vars gracefully

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-utils.sh"

E2E_ROOT="$(get_e2e_root)"
FIXTURE_DIR="$E2E_ROOT/fixtures/env-config"
PROJECT_NAME="e2e-env-config"

# Simple cleanup function - called explicitly, not via trap
# Always returns 0 regardless of docker compose result
do_cleanup() {
    cleanup_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME"
    return 0
}

log_section "Environment Variable Configuration E2E Test"

# Clean up any existing containers
cleanup_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME"

# ═══════════════════════════════════════════════════════════════════════════
# TEST 1: Full Environment Variables
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 1: Full Environment Variables"

log_info "Starting container with full environment..."
docker compose -f "$FIXTURE_DIR/docker-compose.yml" -p "$PROJECT_NAME" up -d app-full-env 2>&1 || true

# Wait for container to be healthy
CONTAINER_NAME="e2e-env-full"
wait_for_healthy "$CONTAINER_NAME" 60

# Test the endpoint
log_info "Testing environment variable passthrough..."
RESPONSE=$(curl -s "http://localhost:8096/" 2>/dev/null || echo '{"status":"error"}')

# Check overall status
if echo "$RESPONSE" | grep -q '"status": "ok"'; then
    log_success "Full env config: All environment variables passed correctly"
else
    log_fail "Full env config: Some environment variables failed"
    echo "$RESPONSE" | head -100
fi

# Specific tests
assert_http_contains "http://localhost:8096/" '"APP_NAME"' "APP_NAME is accessible"
assert_http_contains "http://localhost:8096/" '"APP_ENV"' "APP_ENV is accessible"
assert_http_contains "http://localhost:8096/" '"DB_HOST"' "DB_HOST is accessible"
assert_http_contains "http://localhost:8096/" '"CUSTOM_OVERRIDE"' "CUSTOM_OVERRIDE is accessible"

# Stop this container
docker compose -f "$FIXTURE_DIR/docker-compose.yml" -p "$PROJECT_NAME" stop app-full-env 2>&1 || true

# ═══════════════════════════════════════════════════════════════════════════
# TEST 2: Minimal Environment Variables
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 2: Minimal Environment Variables"

log_info "Starting container with minimal environment..."
docker compose -f "$FIXTURE_DIR/docker-compose.yml" -p "$PROJECT_NAME" up -d app-minimal-env 2>&1 || true

CONTAINER_NAME="e2e-env-minimal"
wait_for_healthy "$CONTAINER_NAME" 60

# If container is healthy, it means FPM didn't crash on missing env vars
log_success "Minimal env: Container started successfully with missing env vars"

# Test the endpoint still works
assert_http_code "http://localhost:8097/" 200 "Minimal env: HTTP endpoint responds"

docker compose -f "$FIXTURE_DIR/docker-compose.yml" -p "$PROJECT_NAME" stop app-minimal-env 2>&1 || true

# ═══════════════════════════════════════════════════════════════════════════
# TEST 3: No Environment Variables
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 3: No Environment Variables"

log_info "Starting container with NO environment variables..."
docker compose -f "$FIXTURE_DIR/docker-compose.yml" -p "$PROJECT_NAME" up -d app-no-env 2>&1 || true

CONTAINER_NAME="e2e-env-none"

# This is the critical test - will FPM crash on NULL env vars?
if wait_for_healthy "$CONTAINER_NAME" 60; then
    log_success "No env: Container started successfully with zero env vars"
else
    log_fail "No env: Container failed to start (FPM likely crashed on NULL env vars)"

    # Show logs for debugging
    echo "=== Container Logs ==="
    docker logs "$CONTAINER_NAME" 2>&1 | tail -50
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 4: PHP Configuration Verification
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 4: PHP Configuration Verification"

# Ensure full-env container is running (it may have been stopped)
docker compose -f "$FIXTURE_DIR/docker-compose.yml" -p "$PROJECT_NAME" start app-full-env 2>&1 || true
wait_for_healthy "e2e-env-full" 60
wait_for_http "http://localhost:8096/" 200 30

# Check PHP config values directly
log_info "Verifying PHP configuration values..."

# Memory limit
MEMORY_LIMIT=$(docker exec e2e-env-full php -r "echo ini_get('memory_limit');")
if [ "$MEMORY_LIMIT" = "256M" ]; then
    log_success "PHP memory_limit is correctly set to 256M"
else
    log_warn "PHP memory_limit is $MEMORY_LIMIT (expected 256M)"
fi

# OPcache
OPCACHE=$(docker exec e2e-env-full php -r "echo ini_get('opcache.enable');")
if [ "$OPCACHE" = "1" ]; then
    log_success "OPcache is enabled"
else
    log_warn "OPcache status: $OPCACHE"
fi

# Security: expose_php
EXPOSE_PHP=$(docker exec e2e-env-full php -r "echo ini_get('expose_php');")
if [ -z "$EXPOSE_PHP" ] || [ "$EXPOSE_PHP" = "0" ] || [ "$EXPOSE_PHP" = "" ]; then
    log_success "expose_php is disabled (security)"
else
    log_warn "expose_php is enabled: $EXPOSE_PHP"
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 5: Environment Variable Override Test
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 5: Environment Variable Override"

# Ensure HTTP endpoint is available before testing
wait_for_http "http://localhost:8096/" 200 10

# Test that we can override default values
RESPONSE=$(curl -s "http://localhost:8096/")
if echo "$RESPONSE" | grep -q '"value": "overridden_value"'; then
    log_success "Custom environment variable override works"
else
    log_fail "Custom environment variable override failed"
    echo "  Response (first 500 chars): ${RESPONSE:0:500}"
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 6: Clear Environment Test
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 6: Clear Environment (Security)"

# Check if PATH is cleared (it should be if clear_env=yes works)
PATH_IN_PHP=$(curl -s "http://localhost:8096/" | grep -o '"PATH"[^}]*"exists"[^}]*' || echo "")
if echo "$PATH_IN_PHP" | grep -q '"exists": false'; then
    log_success "clear_env=yes is working (PATH not leaked to PHP)"
else
    log_info "PATH may be available in PHP (check clear_env setting)"
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
