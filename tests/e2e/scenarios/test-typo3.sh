#!/bin/bash
# E2E Test: TYPO3 stack (MySQL + Redis)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-utils.sh"

E2E_ROOT="$(get_e2e_root)"
FIXTURE_DIR="$E2E_ROOT/fixtures/typo3"
PROJECT_NAME="e2e-typo3"
CONTAINER_NAME="e2e-typo3-app"
BASE_URL="http://localhost:8098"

trap 'cleanup_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME"' EXIT

log_section "TYPO3 E2E Test"

cleanup_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME" 2>/dev/null || true
start_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME"

wait_for_healthy "$CONTAINER_NAME" 120

log_section "Framework Detection"
assert_http_code "$BASE_URL/" 200
assert_http_contains "$BASE_URL/" '"cms":"typo3"'

log_section "Health"
assert_http_code "$BASE_URL/health" 200
assert_http_contains "$BASE_URL/health" '"database":{"ok":true'
assert_http_contains "$BASE_URL/health" '"redis":{"ok":true'

log_section "Connectivity"
assert_http_code "$BASE_URL/db" 200
assert_http_code "$BASE_URL/redis" 200

log_section "Scheduler"
assert_http_code "$BASE_URL/scheduler" 200
assert_http_contains "$BASE_URL/scheduler" '"env":"true"'

print_summary
