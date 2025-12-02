#!/bin/bash
# E2E Test: Database Connectivity
# Tests MySQL, PostgreSQL, and SQLite connections

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-utils.sh"

E2E_ROOT="$(get_e2e_root)"
FIXTURE_DIR="$E2E_ROOT/fixtures/database"
PROJECT_NAME="e2e-database"

# Cleanup on exit
trap 'ec=$?; cleanup_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME"; exit $ec' EXIT

log_section "Database Connectivity E2E Test"

# Clean up any existing containers
cleanup_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME"

# Start containers
log_info "Starting database test containers (MySQL, PostgreSQL, App)..."
docker compose -f "$FIXTURE_DIR/docker-compose.yml" -p "$PROJECT_NAME" up -d 2>&1 || true

# Wait for databases to be healthy
log_info "Waiting for MySQL to be ready..."
MYSQL_CONTAINER="e2e-database-mysql"
wait_for_healthy "$MYSQL_CONTAINER" 60

log_info "Waiting for PostgreSQL to be ready..."
POSTGRES_CONTAINER="e2e-database-postgres"
wait_for_healthy "$POSTGRES_CONTAINER" 60

log_info "Waiting for PHP app to be ready..."
APP_CONTAINER="e2e-database-app"
wait_for_healthy "$APP_CONTAINER" 60

# ═══════════════════════════════════════════════════════════════════════════
# TEST 1: PHP Database Extensions
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 1: PHP Database Extensions"

assert_exec_contains "$APP_CONTAINER" "php -m | grep -i pdo" "PDO" "PDO extension is loaded"
assert_exec_contains "$APP_CONTAINER" "php -m | grep -i pdo_mysql" "pdo_mysql" "PDO MySQL driver is loaded"
assert_exec_contains "$APP_CONTAINER" "php -m | grep -i pdo_pgsql" "pdo_pgsql" "PDO PostgreSQL driver is loaded"
assert_exec_contains "$APP_CONTAINER" "php -m | grep -i pdo_sqlite" "pdo_sqlite" "PDO SQLite driver is loaded"
assert_exec_contains "$APP_CONTAINER" "php -m | grep -i mysqli" "mysqli" "MySQLi extension is loaded"
assert_exec_contains "$APP_CONTAINER" "php -m | grep -i pgsql" "pgsql" "Native PostgreSQL extension is loaded"

# ═══════════════════════════════════════════════════════════════════════════
# TEST 2: MySQL Connection Tests
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 2: MySQL Connection"

RESPONSE=$(curl -s "http://localhost:8100/" 2>/dev/null || echo '{"error":"failed"}')

# Test MySQL PDO
if echo "$RESPONSE" | grep -q '"mysql_pdo"' && echo "$RESPONSE" | grep -A5 '"mysql_pdo"' | grep -q '"success": true'; then
    log_success "MySQL: PDO connection works"

    # Check write test
    if echo "$RESPONSE" | grep -A10 '"mysql_pdo"' | grep -q '"write_test": "passed"'; then
        log_success "MySQL: PDO write operations work"
    else
        log_fail "MySQL: PDO write operations failed"
    fi
else
    log_fail "MySQL: PDO connection failed"
    echo "$RESPONSE" | grep -A10 '"mysql_pdo"' | head -15
fi

# Test MySQLi
if echo "$RESPONSE" | grep -q '"mysql_mysqli"' && echo "$RESPONSE" | grep -A5 '"mysql_mysqli"' | grep -q '"success": true'; then
    log_success "MySQL: mysqli connection works"
else
    log_fail "MySQL: mysqli connection failed"
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 3: PostgreSQL Connection Tests
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 3: PostgreSQL Connection"

# Test PostgreSQL PDO
if echo "$RESPONSE" | grep -q '"postgres_pdo"' && echo "$RESPONSE" | grep -A5 '"postgres_pdo"' | grep -q '"success": true'; then
    log_success "PostgreSQL: PDO connection works"

    # Check write test
    if echo "$RESPONSE" | grep -A10 '"postgres_pdo"' | grep -q '"write_test": "passed"'; then
        log_success "PostgreSQL: PDO write operations work"
    else
        log_fail "PostgreSQL: PDO write operations failed"
    fi
else
    log_fail "PostgreSQL: PDO connection failed"
    echo "$RESPONSE" | grep -A10 '"postgres_pdo"' | head -15
fi

# Test PostgreSQL native
if echo "$RESPONSE" | grep -q '"postgres_native"' && echo "$RESPONSE" | grep -A5 '"postgres_native"' | grep -q '"success": true'; then
    log_success "PostgreSQL: Native driver connection works"
else
    log_fail "PostgreSQL: Native driver connection failed"
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 4: SQLite Connection Tests
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 4: SQLite Connection"

if echo "$RESPONSE" | grep -q '"sqlite"' && echo "$RESPONSE" | grep -A5 '"sqlite"' | grep -q '"success": true'; then
    log_success "SQLite: Connection and operations work"

    # Check write test
    if echo "$RESPONSE" | grep -A10 '"sqlite"' | grep -q '"write_test": "passed"'; then
        log_success "SQLite: Write operations work"
    else
        log_fail "SQLite: Write operations failed"
    fi
else
    log_fail "SQLite: Connection failed"
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 5: Connection Pooling and Performance
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 5: Connection Performance"

# Test multiple rapid connections
log_info "Testing connection stability (10 rapid requests)..."
SUCCESS_COUNT=0
for i in {1..10}; do
    if curl -s "http://localhost:8100/" | grep -q '"status": "ok"' 2>/dev/null; then
        ((SUCCESS_COUNT++))
    fi
done

if [ "$SUCCESS_COUNT" -eq 10 ]; then
    log_success "Connection stability: 10/10 requests succeeded"
elif [ "$SUCCESS_COUNT" -ge 8 ]; then
    log_warn "Connection stability: $SUCCESS_COUNT/10 requests succeeded"
else
    log_fail "Connection stability: Only $SUCCESS_COUNT/10 requests succeeded"
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 6: Database Version Information
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 6: Database Versions"

# Extract and display versions
MYSQL_VERSION=$(echo "$RESPONSE" | grep -A10 '"mysql_pdo"' | grep '"version"' | head -1 | sed 's/.*"version": "\([^"]*\)".*/\1/')
POSTGRES_VERSION=$(echo "$RESPONSE" | grep -A10 '"postgres_pdo"' | grep '"version"' | head -1 | sed 's/.*"version": "\([^"]*\)".*/\1/' | head -c 30)
SQLITE_VERSION=$(echo "$RESPONSE" | grep -A10 '"sqlite"' | grep '"version"' | head -1 | sed 's/.*"version": "\([^"]*\)".*/\1/')

if [ -n "$MYSQL_VERSION" ]; then
    log_info "MySQL version: $MYSQL_VERSION"
fi
if [ -n "$POSTGRES_VERSION" ]; then
    log_info "PostgreSQL version: ${POSTGRES_VERSION}..."
fi
if [ -n "$SQLITE_VERSION" ]; then
    log_info "SQLite version: $SQLITE_VERSION"
fi

print_summary

exit 0
