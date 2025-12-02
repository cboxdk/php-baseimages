#!/bin/bash
# E2E Test: Drupal stack (PostgreSQL + Redis)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-utils.sh"

E2E_ROOT="$(get_e2e_root)"
FIXTURE_DIR="$E2E_ROOT/fixtures/drupal"
PROJECT_NAME="e2e-drupal"
CONTAINER_NAME="e2e-drupal-app"
BASE_URL="http://localhost:8097"

# Simple cleanup function - called explicitly, not via trap
# Always returns 0 regardless of docker compose result
do_cleanup() {
    cleanup_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME"
    return 0
}

log_section "Drupal E2E Test"

cleanup_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME" 2>/dev/null || true
start_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME"

wait_for_healthy "$CONTAINER_NAME" 120

log_section "Framework Detection"
assert_http_code "$BASE_URL/" 200 "/ endpoint"
assert_http_contains "$BASE_URL/" '"cms":"drupal"' "Drupal detection"

log_section "Health"
assert_http_code "$BASE_URL/health" 200 "Health endpoint"
assert_http_contains "$BASE_URL/health" '"database":{"ok":true' "Database healthy"
assert_http_contains "$BASE_URL/health" '"redis":{"ok":true' "Redis healthy"

log_section "Connectivity"
assert_http_code "$BASE_URL/db" 200 "PostgreSQL endpoint"
assert_http_code "$BASE_URL/redis" 200 "Redis endpoint"

log_section "Cron"
assert_http_code "$BASE_URL/cron" 200 "Cron endpoint"
assert_http_contains "$BASE_URL/cron" '"scheduler_env":"true"' "Scheduler env set"

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
