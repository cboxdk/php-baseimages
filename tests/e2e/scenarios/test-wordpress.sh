#!/bin/bash
# E2E Test: WordPress Application
# Tests WordPress with MySQL

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-utils.sh"

E2E_ROOT="$(get_e2e_root)"
FIXTURE_DIR="$E2E_ROOT/fixtures/wordpress"
PROJECT_NAME="e2e-wordpress"
CONTAINER_NAME="e2e-wordpress-app"
BASE_URL="http://localhost:8092"

# Simple cleanup function - called explicitly, not via trap
# Always returns 0 regardless of docker compose result
do_cleanup() {
    cleanup_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME"
    return 0
}

log_section "WordPress E2E Test"

# Start the stack
cleanup_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME"
start_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME"

# Wait for MySQL to be ready first
log_info "Waiting for MySQL to be ready..."
sleep 10

# Wait for app to be healthy
wait_for_healthy "$CONTAINER_NAME" 60

log_section "Framework Detection Tests"

# Test main endpoint (compact JSON format - no spaces)
assert_http_code "$BASE_URL/" 200 "Main endpoint returns 200"
assert_http_contains "$BASE_URL/" '"cms":"wordpress"' "CMS detected as WordPress"
assert_http_contains "$BASE_URL/" '"wp_config_exists":true' "wp-config.php exists"

log_section "Health Check Tests"

# Test health endpoint (compact JSON format - no spaces)
assert_http_code "$BASE_URL/health.php" 200 "Health endpoint returns 200"
assert_http_contains "$BASE_URL/health.php" '"status":"healthy"' "Health check reports healthy"
assert_http_contains "$BASE_URL/health.php" '"mysql":true' "MySQL connection successful"
assert_http_contains "$BASE_URL/health.php" '"wp_config":true' "wp-config.php detected"

log_section "WordPress Structure Tests"

# Test wp-admin simulation
assert_http_code "$BASE_URL/wp-admin/" 200 "wp-admin accessible"
assert_http_contains "$BASE_URL/wp-admin/" '"area":"admin"' "Admin area response correct"

# Test URL rewriting
assert_http_code "$BASE_URL/sample-page/" 200 "URL rewriting works"
assert_http_contains "$BASE_URL/sample-page/" '"rewrite":"active"' "Rewrite rules active"

log_section "File Structure Tests"

# Verify WordPress file structure (files are in /var/www/html/public via volume mount)
assert_file_exists "$CONTAINER_NAME" "/var/www/html/public/wp-config.php" "wp-config.php exists"
assert_file_exists "$CONTAINER_NAME" "/var/www/html/public/index.php" "index.php exists"

log_section "Process Tests"

# Verify processes
assert_process_running "$CONTAINER_NAME" "php-fpm" "PHP-FPM running"
assert_process_running "$CONTAINER_NAME" "nginx" "Nginx running"

log_section "PHP Configuration Tests"

# Check memory limit (WordPress needs more)
assert_exec_contains "$CONTAINER_NAME" "php -r 'echo ini_get(\"memory_limit\");'" "256M" "Memory limit is 256M"

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
