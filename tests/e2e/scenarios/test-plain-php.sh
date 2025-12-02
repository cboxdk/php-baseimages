#!/bin/bash
# E2E Test: Plain PHP Application
# Tests basic PHP functionality without any framework

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-utils.sh"

E2E_ROOT="$(get_e2e_root)"
FIXTURE_DIR="$E2E_ROOT/fixtures/plain-php"
PROJECT_NAME="e2e-plain-php"
CONTAINER_NAME="e2e-plain-php"
BASE_URL="http://localhost:8090"

# Simple cleanup function - called explicitly, not via trap
# Always returns 0 regardless of docker compose result
do_cleanup() {
    cleanup_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME"
    return 0
}

log_section "Plain PHP E2E Test"

# Start the stack
cleanup_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME"
start_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME"

# Wait for healthy
wait_for_healthy "$CONTAINER_NAME" 60

log_section "HTTP Endpoint Tests"

# Test main endpoint
assert_http_code "$BASE_URL/" 200 "Main endpoint returns 200"
assert_http_contains "$BASE_URL/" '"status": "ok"' "Response contains status ok"
assert_http_contains "$BASE_URL/" '"php_version"' "Response contains PHP version"

# Test health endpoint
assert_http_code "$BASE_URL/health.php" 200 "Health endpoint returns 200"
# Health endpoint uses compact JSON (no spaces)
assert_http_contains "$BASE_URL/health.php" '"status":"healthy"' "Health check reports healthy"

log_section "PHP Extension Tests"

# Verify critical extensions are loaded (JSON has spaces: "key": value)
assert_http_contains "$BASE_URL/" '"redis": true' "Redis extension loaded"
assert_http_contains "$BASE_URL/" '"pdo_mysql": true' "PDO MySQL extension loaded"
assert_http_contains "$BASE_URL/" '"gd": true' "GD extension loaded"
assert_http_contains "$BASE_URL/" '"intl": true' "Intl extension loaded"
assert_http_contains "$BASE_URL/" '"zip": true' "Zip extension loaded"
assert_http_contains "$BASE_URL/" '"bcmath": true' "BCMath extension loaded"

log_section "Process Tests"

# Verify processes are running
assert_process_running "$CONTAINER_NAME" "php-fpm" "PHP-FPM master process running"
assert_process_running "$CONTAINER_NAME" "nginx" "Nginx master process running"

log_section "Filesystem Tests"

# Verify file permissions
assert_http_contains "$BASE_URL/" '"write_test": true' "Filesystem write test passes"
assert_http_contains "$BASE_URL/" '"temp_dir_writable": true' "Temp directory is writable"

log_section "Container Health Tests"

# Check PHP-FPM is responding on port 9000
assert_exec_succeeds "$CONTAINER_NAME" "netstat -tlnp | grep ':9000'" "PHP-FPM listening on port 9000"

# Check Nginx is responding on port 80
assert_exec_succeeds "$CONTAINER_NAME" "netstat -tlnp | grep ':80'" "Nginx listening on port 80"

# Verify OPcache is working via FPM (CLI has opcache.enable_cli=Off by default)
assert_http_contains "$BASE_URL/" '"opcache": true' "OPcache is enabled (via FPM)"

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
