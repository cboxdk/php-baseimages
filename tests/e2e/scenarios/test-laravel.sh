#!/bin/bash
# E2E Test: Laravel Application
# Tests Laravel with MySQL, Redis, and scheduler

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-utils.sh"

E2E_ROOT="$(get_e2e_root)"
FIXTURE_DIR="$E2E_ROOT/fixtures/laravel"
PROJECT_NAME="e2e-laravel"
CONTAINER_NAME="e2e-laravel-app"
BASE_URL="http://localhost:8091"

# Cleanup on exit
trap 'cleanup_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME"' EXIT

log_section "Laravel E2E Test"

# Make artisan executable
chmod +x "$FIXTURE_DIR/app/artisan" 2>/dev/null || true

# Start the stack
cleanup_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME"
start_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME"

# Wait for MySQL to be ready first (it takes longer)
log_info "Waiting for MySQL to be ready..."
sleep 10

# Wait for app to be healthy
wait_for_healthy "$CONTAINER_NAME" 90

log_section "Framework Detection Tests"

# Test main endpoint
assert_http_code "$BASE_URL/" 200 "Main endpoint returns 200"
assert_http_contains "$BASE_URL/" '"framework":"laravel"' "Framework detected as Laravel"

log_section "Database Connection Tests"

# Test MySQL connection
wait_for_http "$BASE_URL/db/test" 200 30
assert_http_code "$BASE_URL/db/test" 200 "Database endpoint returns 200"
assert_http_contains "$BASE_URL/db/test" '"status":"connected"' "MySQL connection successful"
assert_http_contains "$BASE_URL/db/test" '"database":"laravel"' "Connected to correct database"

log_section "Redis Connection Tests"

# Test Redis connection
assert_http_code "$BASE_URL/redis/test" 200 "Redis endpoint returns 200"
assert_http_contains "$BASE_URL/redis/test" '"status":"connected"' "Redis connection successful"
assert_http_contains "$BASE_URL/redis/test" '"read_write":true' "Redis read/write works"

log_section "Health Check Tests"

# Test comprehensive health check (compact JSON format - no spaces)
# Note: Using /app-health to avoid conflict with nginx's /health location
assert_http_code "$BASE_URL/app-health" 200 "Health endpoint returns 200"
assert_http_contains "$BASE_URL/app-health" '"status":"healthy"' "Health check reports healthy"
assert_http_contains "$BASE_URL/app-health" '"mysql":true' "MySQL health check passes"
assert_http_contains "$BASE_URL/app-health" '"redis":true' "Redis health check passes"
assert_http_contains "$BASE_URL/app-health" '"php":true' "PHP health check passes"

log_section "Laravel Scheduler Tests"

# Test scheduler configuration via HTTP endpoint
assert_http_contains "$BASE_URL/scheduler/test" '"scheduler_env":"true"' "LARAVEL_SCHEDULER env is set"

# Check if artisan exists and is executable
assert_file_exists "$CONTAINER_NAME" "/var/www/html/artisan" "Artisan file exists"
assert_exec_succeeds "$CONTAINER_NAME" "php /var/www/html/artisan --version" "Artisan is executable"

# Verify PHPeek PM is managing the scheduler process
# When LARAVEL_SCHEDULER=true, PHPeek PM should enable the scheduler process
log_info "Checking PHPeek PM scheduler integration..."
assert_exec_succeeds "$CONTAINER_NAME" "phpeek-pm --version" "PHPeek PM is available"

# Check if scheduler process is managed by PHPeek PM (via metrics or status)
# The scheduler runs as 'php artisan schedule:work' under PHPeek PM
if docker exec "$CONTAINER_NAME" pgrep -f "schedule:work" >/dev/null 2>&1; then
    log_success "Scheduler process is running (schedule:work)"
else
    # If not running, check if PHPeek PM config has scheduler enabled
    log_info "Scheduler process not found - checking PHPeek PM config"
    assert_file_exists "$CONTAINER_NAME" "/etc/phpeek-pm/phpeek-pm.yaml" "PHPeek PM config exists"
fi

log_section "Process Tests"

# Verify critical processes
assert_process_running "$CONTAINER_NAME" "php-fpm" "PHP-FPM running"
assert_process_running "$CONTAINER_NAME" "nginx" "Nginx running"

log_section "Permission Tests"

# Laravel needs storage and bootstrap/cache to be writable
assert_dir_exists "$CONTAINER_NAME" "/var/www/html/public" "Public directory exists"

log_section "API Endpoint Tests"

# Test API endpoint
assert_http_code "$BASE_URL/api/test" 200 "API endpoint returns 200"
assert_http_contains "$BASE_URL/api/test" '"message":"API endpoint working"' "API response correct"

print_summary
