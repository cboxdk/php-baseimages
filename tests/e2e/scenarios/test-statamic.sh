#!/bin/bash
# E2E Test: Statamic stack (Laravel + MySQL + Redis)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-utils.sh"

E2E_ROOT="$(get_e2e_root)"
FIXTURE_DIR="$E2E_ROOT/fixtures/statamic"
PROJECT_NAME="e2e-statamic"
CONTAINER_NAME="e2e-statamic-app"
BASE_URL="http://localhost:8099"

# Simple cleanup function - called explicitly, not via trap
# Always returns 0 regardless of docker compose result
do_cleanup() {
    cleanup_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME"
    return 0
}

log_section "Statamic E2E Test"

cleanup_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME" 2>/dev/null || true
start_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME"

wait_for_healthy "$CONTAINER_NAME" 120

log_section "Framework Detection"
assert_http_code "$BASE_URL/" 200
assert_http_contains "$BASE_URL/" '"cms":"statamic"'

log_section "Health"
assert_http_code "$BASE_URL/health" 200
assert_http_contains "$BASE_URL/health" '"database":{"ok":true'
assert_http_contains "$BASE_URL/health" '"redis":{"ok":true'

log_section "Connectivity"
assert_http_code "$BASE_URL/db" 200
assert_http_code "$BASE_URL/redis" 200

log_section "Queue"
assert_http_code "$BASE_URL/queue" 200
assert_http_contains "$BASE_URL/queue" '"queue_env":"true"'

# Store test results before any cleanup that might affect shell state
FINAL_PASSED=$TESTS_PASSED
FINAL_FAILED=$TESTS_FAILED

# Determine exit code BEFORE cleanup
if [ "$FINAL_FAILED" -gt 0 ]; then
    TEST_EXIT_CODE=1
else
    TEST_EXIT_CODE=0
fi

# Print summary (ignore any errors from print function)
print_summary 2>/dev/null || true

# Run cleanup in a subshell to completely isolate it from main script exit code
# The subshell will run with its own environment and cannot affect our exit code
(
    set +euo pipefail
    do_cleanup 2>/dev/null
) || true

# Use explicit exit with the pre-determined code
exit "$TEST_EXIT_CODE"
