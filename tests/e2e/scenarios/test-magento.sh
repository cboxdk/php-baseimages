#!/bin/bash
# E2E Test: Magento stack (MySQL + Redis + OpenSearch)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-utils.sh"

E2E_ROOT="$(get_e2e_root)"
FIXTURE_DIR="$E2E_ROOT/fixtures/magento"
PROJECT_NAME="e2e-magento"
CONTAINER_NAME="e2e-magento-app"
BASE_URL="http://localhost:8096"

trap 'cleanup_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME"' EXIT

log_section "Magento E2E Test"

cleanup_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME" 2>/dev/null || true
start_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME"

wait_for_healthy "$CONTAINER_NAME" 180

log_section "Framework Detection"
assert_http_code "$BASE_URL/" 200 "Base endpoint"
assert_http_contains "$BASE_URL/" '"platform":"magento"' "Identified as Magento"

log_section "Health"
assert_http_code "$BASE_URL/health" 200 "Health endpoint"
assert_http_contains "$BASE_URL/health" '"mysql":{"ok":true' "MySQL OK"
assert_http_contains "$BASE_URL/health" '"redis":{"ok":true' "Redis OK"
assert_http_contains "$BASE_URL/health" '"opensearch":{"ok":true' "OpenSearch OK"

log_section "Connectivity"
assert_http_code "$BASE_URL/db" 200 "DB endpoint"
assert_http_code "$BASE_URL/redis" 200 "Redis endpoint"
assert_http_code "$BASE_URL/search" 200 "Search endpoint"

log_section "Scheduler"
assert_http_code "$BASE_URL/cron" 200 "Cron endpoint"
assert_http_contains "$BASE_URL/cron" '"env":"true"' "Scheduler env"

print_summary
