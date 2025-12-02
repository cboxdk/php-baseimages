#!/bin/bash
# E2E Test Utilities for PHPeek Base Images
# Shared functions for all E2E test scenarios

set -euo pipefail

# Check for jq (optional but recommended for JSON parsing)
if command -v jq &> /dev/null; then
    JQ_AVAILABLE=true
else
    JQ_AVAILABLE=false
fi

# JSON helper - parse JSON value (uses jq if available, falls back to grep)
json_get() {
    local json="$1"
    local key="$2"

    if [ "$JQ_AVAILABLE" = true ]; then
        echo "$json" | jq -r ".$key // empty" 2>/dev/null || echo ""
    else
        # Fallback to grep-based parsing (less reliable but works)
        echo "$json" | grep -o "\"$key\"[[:space:]]*:[[:space:]]*[^,}]*" | sed 's/.*:[[:space:]]*//;s/"//g;s/[[:space:]]*$//' | head -1
    fi
}

# JSON helper - check if key exists and equals value
json_check() {
    local json="$1"
    local key="$2"
    local expected="$3"

    if [ "$JQ_AVAILABLE" = true ]; then
        local actual
        actual=$(echo "$json" | jq -r ".$key // empty" 2>/dev/null)
        [ "$actual" = "$expected" ]
    else
        echo "$json" | grep -q "\"$key\"[[:space:]]*:[[:space:]]*$expected"
    fi
}

# JSON helper - check if nested key path has success: true
json_success() {
    local json="$1"
    local key="$2"

    if [ "$JQ_AVAILABLE" = true ]; then
        echo "$json" | jq -e ".$key.success == true" &>/dev/null
    else
        echo "$json" | grep -A5 "\"$key\"" | grep -q '"success"[[:space:]]*:[[:space:]]*true'
    fi
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Wait for container to be healthy
wait_for_healthy() {
    local container=$1
    local timeout=${2:-60}
    local elapsed=0

    log_info "Waiting for $container to be healthy (timeout: ${timeout}s)..."

    while [ $elapsed -lt $timeout ]; do
        local health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "not_found")

        if [ "$health" = "healthy" ]; then
            log_info "$container is healthy after ${elapsed}s"
            return 0
        elif [ "$health" = "not_found" ]; then
            log_info "Container $container not found, waiting..."
        fi

        sleep 2
        ((elapsed+=2))
    done

    log_fail "$container failed to become healthy within ${timeout}s"
    docker logs "$container" 2>&1 | tail -50
    return 1
}

# Wait for HTTP endpoint
wait_for_http() {
    local url=$1
    local expected_code=${2:-200}
    local timeout=${3:-30}
    local elapsed=0

    log_info "Waiting for $url (expected: $expected_code, timeout: ${timeout}s)..."

    while [ $elapsed -lt $timeout ]; do
        local code=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")

        if [ "$code" = "$expected_code" ]; then
            log_info "$url returned $code after ${elapsed}s"
            return 0
        fi

        sleep 1
        ((elapsed++))
    done

    log_fail "$url did not return $expected_code within ${timeout}s (got: $code)"
    return 1
}

# Assert HTTP response contains string
assert_http_contains() {
    local url=$1
    local expected=$2
    local description=${3:-"HTTP response contains '$expected'"}

    local response=$(curl -s "$url" 2>/dev/null)

    if echo "$response" | grep -qF "$expected"; then
        log_success "$description"
    else
        log_fail "$description"
        echo "  Response: ${response:0:200}..."
    fi
    # Always return 0 to not break set -e, failures tracked in TESTS_FAILED
    return 0
}

# Assert HTTP response code
assert_http_code() {
    local url=$1
    local expected=$2
    local description=${3:-"HTTP $url returns $expected"}

    local code=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)

    if [ "$code" = "$expected" ]; then
        log_success "$description"
    else
        log_fail "$description (got: $code)"
    fi
    return 0
}

# Assert command output contains string
assert_exec_contains() {
    local container=$1
    local cmd=$2
    local expected=$3
    local description=${4:-"Command '$cmd' contains '$expected'"}

    local output=$(docker exec "$container" sh -c "$cmd" 2>&1)

    if echo "$output" | grep -qF "$expected"; then
        log_success "$description"
    else
        log_fail "$description"
        echo "  Output: ${output:0:200}..."
    fi
    return 0
}

# Assert command succeeds
assert_exec_succeeds() {
    local container=$1
    local cmd=$2
    local description=${3:-"Command '$cmd' succeeds"}

    if docker exec "$container" sh -c "$cmd" >/dev/null 2>&1; then
        log_success "$description"
    else
        log_fail "$description"
    fi
    return 0
}

# Assert process is running
assert_process_running() {
    local container=$1
    local process=$2
    local description=${3:-"Process '$process' is running"}

    if docker exec "$container" pgrep -f "$process" >/dev/null 2>&1; then
        log_success "$description"
    else
        log_fail "$description"
    fi
    return 0
}

# Assert file exists in container
assert_file_exists() {
    local container=$1
    local path=$2
    local description=${3:-"File '$path' exists"}

    if docker exec "$container" test -f "$path"; then
        log_success "$description"
    else
        log_fail "$description"
    fi
    return 0
}

# Assert directory exists in container
assert_dir_exists() {
    local container=$1
    local path=$2
    local description=${3:-"Directory '$path' exists"}

    if docker exec "$container" test -d "$path"; then
        log_success "$description"
    else
        log_fail "$description"
    fi
    return 0
}

# Cleanup function for docker compose
# Note: This function is designed to be safe in EXIT traps with set -euo pipefail
# It disables all strict modes and runs cleanup in a subshell to prevent any errors
# from affecting the trap exit code
cleanup_compose() {
    local compose_file="${1:-}"
    local project="${2:-e2e-test}"

    # Run in a subshell with all strict modes disabled to ensure cleanup completes
    # even if docker compose fails for any reason
    (
        set +euo pipefail 2>/dev/null || true
        echo -e "${BLUE:-}[INFO]${NC:-} Cleaning up $project..."
        docker compose -f "$compose_file" -p "$project" down -v --remove-orphans 2>/dev/null
    ) || true
}

# Start docker compose stack
start_compose() {
    local compose_file=$1
    local project=${2:-"e2e-test"}

    log_info "Starting $project..."
    docker compose -f "$compose_file" -p "$project" up -d --build
}

# Print test summary
print_summary() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  TEST SUMMARY${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${GREEN}Passed:${NC}  $TESTS_PASSED"
    echo -e "  ${RED}Failed:${NC}  $TESTS_FAILED"
    echo -e "  ${YELLOW}Skipped:${NC} $TESTS_SKIPPED"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if [ $TESTS_FAILED -gt 0 ]; then
        return 1
    fi
    return 0
}

# Get script directory
get_script_dir() {
    echo "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
}

# Get E2E root directory
get_e2e_root() {
    echo "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
}

# Get project root directory
get_project_root() {
    echo "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
}
