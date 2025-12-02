#!/bin/bash
# E2E Test: Rootless Container Mode
# Tests containers running as non-root user with PHPEEK_ROOTLESS=true

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-utils.sh"

E2E_ROOT="$(get_e2e_root)"
FIXTURE_DIR="$E2E_ROOT/fixtures/rootless"
PROJECT_NAME="e2e-rootless"
CONTAINER_NAME="e2e-rootless-app"
BASE_URL="http://localhost:8095"

# Cleanup on exit - capture exit code, run cleanup, restore exit code
cleanup_and_exit() {
    local exit_code=$?
    set +euo pipefail 2>/dev/null || true
    cleanup_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME" 2>/dev/null || true
    exit $exit_code
}
trap cleanup_and_exit EXIT

log_section "Rootless Container E2E Test"

# Start the stack
cleanup_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME"
start_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME"

# Wait for healthy
wait_for_healthy "$CONTAINER_NAME" 60

# ═══════════════════════════════════════════════════════════════════════════════
# ROOTLESS IDENTITY TESTS
# ═══════════════════════════════════════════════════════════════════════════════
log_section "Rootless Identity Tests"

# Verify container runs as www-data (not root)
USER_ID=$(docker exec "$CONTAINER_NAME" id -u)
if [ "$USER_ID" = "82" ] || [ "$USER_ID" = "33" ]; then
    log_success "Container runs as non-root (UID: $USER_ID)"
else
    log_fail "Container should run as www-data (UID 82/33), got UID: $USER_ID"
fi

# Verify user name is www-data
USER_NAME=$(docker exec "$CONTAINER_NAME" id -un)
if [ "$USER_NAME" = "www-data" ]; then
    log_success "Container runs as www-data user"
else
    log_fail "Container should run as www-data, got: $USER_NAME"
fi

# Verify PHPEEK_ROOTLESS environment variable
ROOTLESS_ENV=$(docker exec "$CONTAINER_NAME" printenv PHPEEK_ROOTLESS 2>/dev/null || echo "unset")
if [ "$ROOTLESS_ENV" = "true" ]; then
    log_success "PHPEEK_ROOTLESS=true is set"
else
    log_fail "PHPEEK_ROOTLESS should be 'true', got: $ROOTLESS_ENV"
fi

# Verify no processes run as root
ROOT_PROCS=$(docker exec "$CONTAINER_NAME" ps aux 2>/dev/null | grep -E "^root\s" | grep -v "ps aux" || true)
if [ -z "$ROOT_PROCS" ]; then
    log_success "No processes running as root"
else
    log_fail "Found processes running as root"
    echo "  Root processes: $ROOT_PROCS"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# PORT CONFIGURATION TESTS
# ═══════════════════════════════════════════════════════════════════════════════
log_section "Rootless Port Configuration"

# Verify Nginx listens on 8080 (unprivileged port)
assert_exec_succeeds "$CONTAINER_NAME" "netstat -tlnp 2>/dev/null | grep ':8080' || ss -tlnp | grep ':8080'" "Nginx listening on port 8080 (unprivileged)"

# Verify NOT listening on port 80 (requires root)
if docker exec "$CONTAINER_NAME" sh -c "netstat -tlnp 2>/dev/null | grep ':80[^0-9]' || ss -tlnp | grep ':80[^0-9]'" 2>/dev/null; then
    log_fail "Should NOT be listening on privileged port 80"
else
    log_success "Not listening on privileged port 80 (correct for rootless)"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# HTTP ENDPOINT TESTS
# ═══════════════════════════════════════════════════════════════════════════════
log_section "HTTP Endpoint Tests"

# Test main endpoint
assert_http_code "$BASE_URL/" 200 "Main endpoint returns 200"
assert_http_contains "$BASE_URL/" '"status": "ok"' "Response contains status ok"
assert_http_contains "$BASE_URL/" '"php_version"' "Response contains PHP version"

# Test health endpoint
assert_http_code "$BASE_URL/health.php" 200 "Health endpoint returns 200"
assert_http_contains "$BASE_URL/health.php" '"status":"healthy"' "Health check reports healthy"

# ═══════════════════════════════════════════════════════════════════════════════
# PHP EXTENSION TESTS
# ═══════════════════════════════════════════════════════════════════════════════
log_section "PHP Extension Tests"

# Verify critical extensions are loaded
assert_http_contains "$BASE_URL/" '"redis": true' "Redis extension loaded"
assert_http_contains "$BASE_URL/" '"pdo_mysql": true' "PDO MySQL extension loaded"
assert_http_contains "$BASE_URL/" '"gd": true' "GD extension loaded"
assert_http_contains "$BASE_URL/" '"intl": true' "Intl extension loaded"
assert_http_contains "$BASE_URL/" '"opcache": true' "OPcache is enabled"

# ═══════════════════════════════════════════════════════════════════════════════
# PROCESS TESTS
# ═══════════════════════════════════════════════════════════════════════════════
log_section "Process Tests"

# Verify processes are running
assert_process_running "$CONTAINER_NAME" "php-fpm" "PHP-FPM process running"
assert_process_running "$CONTAINER_NAME" "nginx" "Nginx process running"

# ═══════════════════════════════════════════════════════════════════════════════
# FILESYSTEM PERMISSION TESTS
# ═══════════════════════════════════════════════════════════════════════════════
log_section "Filesystem Permission Tests"

# Verify /var/www/html is accessible
assert_exec_succeeds "$CONTAINER_NAME" "ls -la /var/www/html" "Can list /var/www/html"

# Verify temp directory is writable
assert_http_contains "$BASE_URL/" '"temp_dir_writable": true' "Temp directory is writable"

# Verify /tmp is writable as www-data
assert_exec_succeeds "$CONTAINER_NAME" "touch /tmp/rootless-test && rm /tmp/rootless-test" "Can write to /tmp"

# ═══════════════════════════════════════════════════════════════════════════════
# SECURITY TESTS
# ═══════════════════════════════════════════════════════════════════════════════
log_section "Rootless Security Tests"

# Verify cannot write to /etc (read-only system directories)
if docker exec "$CONTAINER_NAME" touch /etc/rootless-test 2>/dev/null; then
    docker exec "$CONTAINER_NAME" rm /etc/rootless-test 2>/dev/null || true
    log_fail "Should NOT be able to write to /etc"
else
    log_success "Cannot write to /etc (correct for rootless)"
fi

# Verify cannot bind to privileged ports (simulated)
# Note: actual test would require netcat or similar, skip if not available
if docker exec "$CONTAINER_NAME" which nc >/dev/null 2>&1; then
    if docker exec "$CONTAINER_NAME" sh -c "nc -l -p 80 &" 2>/dev/null; then
        log_fail "Should NOT be able to bind to port 80"
        docker exec "$CONTAINER_NAME" pkill nc 2>/dev/null || true
    else
        log_success "Cannot bind to privileged port 80"
    fi
else
    log_skip "netcat not available for privileged port test"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# PUID/PGID IGNORED TEST
# ═══════════════════════════════════════════════════════════════════════════════
log_section "PUID/PGID Handling"

# PUID/PGID should be ignored in rootless mode
# The entrypoint should skip user mapping entirely
# We verify by checking the user is still www-data despite any PUID/PGID env vars
FINAL_USER=$(docker exec "$CONTAINER_NAME" whoami)
if [ "$FINAL_USER" = "www-data" ]; then
    log_success "PUID/PGID correctly ignored (still www-data)"
else
    log_fail "User should be www-data, got: $FINAL_USER"
fi

print_summary

exit 0
