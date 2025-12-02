#!/bin/bash
# E2E Test: Security Baseline
# Tests Nginx security headers, file blocking, and security configuration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-utils.sh"

E2E_ROOT="$(get_e2e_root)"
FIXTURE_DIR="$E2E_ROOT/fixtures/security"
PROJECT_NAME="e2e-security"

# Cleanup on exit - simple pattern that preserves original exit code
trap 'set +e; cleanup_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME" || true' EXIT

log_section "Security Baseline E2E Test"

# Clean up and start
cleanup_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME"

log_info "Starting security test container..."
docker compose -f "$FIXTURE_DIR/docker-compose.yml" -p "$PROJECT_NAME" up -d 2>&1 || true

CONTAINER_NAME="e2e-security"
wait_for_healthy "$CONTAINER_NAME" 60
wait_for_http "http://localhost:8101/" 200 30

# ═══════════════════════════════════════════════════════════════════════════
# TEST 1: Security Headers
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 1: Security Headers"

# Get headers
HEADERS=$(curl -sI "http://localhost:8101/" 2>/dev/null)

# X-Frame-Options
if echo "$HEADERS" | grep -qi "X-Frame-Options"; then
    log_success "X-Frame-Options header is set"
else
    log_fail "X-Frame-Options header is missing"
fi

# X-Content-Type-Options
if echo "$HEADERS" | grep -qi "X-Content-Type-Options.*nosniff"; then
    log_success "X-Content-Type-Options: nosniff is set"
else
    log_fail "X-Content-Type-Options header is missing or incorrect"
fi

# X-XSS-Protection
if echo "$HEADERS" | grep -qi "X-XSS-Protection"; then
    log_success "X-XSS-Protection header is set"
else
    log_warn "X-XSS-Protection header is missing (deprecated but still useful)"
fi

# Referrer-Policy
if echo "$HEADERS" | grep -qi "Referrer-Policy"; then
    log_success "Referrer-Policy header is set"
else
    log_warn "Referrer-Policy header is missing"
fi

# Content-Security-Policy (may not be set by default)
if echo "$HEADERS" | grep -qi "Content-Security-Policy"; then
    log_success "Content-Security-Policy header is set"
else
    log_info "Content-Security-Policy not set (user should configure)"
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 2: Server Token Hiding
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 2: Server Information Hiding"

# Check Server header doesn't expose version
if echo "$HEADERS" | grep -qi "Server:.*nginx/"; then
    log_fail "Server header exposes nginx version"
else
    log_success "Server header does not expose nginx version"
fi

# Check X-Powered-By is hidden
if echo "$HEADERS" | grep -qi "X-Powered-By"; then
    log_fail "X-Powered-By header is exposed (PHP version leak)"
else
    log_success "X-Powered-By header is hidden"
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 3: Sensitive File Blocking
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 3: Sensitive File Blocking"

# Test .env file blocking
CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8101/.env" 2>/dev/null)
if [ "$CODE" = "403" ] || [ "$CODE" = "404" ]; then
    log_success ".env file is blocked (HTTP $CODE)"
else
    log_fail ".env file is accessible! (HTTP $CODE)"
fi

# Test .git directory blocking
CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8101/.git/config" 2>/dev/null)
if [ "$CODE" = "403" ] || [ "$CODE" = "404" ]; then
    log_success ".git directory is blocked (HTTP $CODE)"
else
    log_fail ".git directory is accessible! (HTTP $CODE)"
fi

# Test .htaccess blocking
CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8101/.htaccess" 2>/dev/null)
if [ "$CODE" = "403" ] || [ "$CODE" = "404" ]; then
    log_success ".htaccess file is blocked (HTTP $CODE)"
else
    log_fail ".htaccess file is accessible! (HTTP $CODE)"
fi

# Test composer.json blocking
CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8101/composer.json" 2>/dev/null)
if [ "$CODE" = "403" ] || [ "$CODE" = "404" ]; then
    log_success "composer.json is blocked (HTTP $CODE)"
else
    log_fail "composer.json is accessible! (HTTP $CODE)"
fi

# Test composer.lock blocking
CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8101/composer.lock" 2>/dev/null)
if [ "$CODE" = "403" ] || [ "$CODE" = "404" ]; then
    log_success "composer.lock is blocked (HTTP $CODE)"
else
    log_fail "composer.lock is accessible! (HTTP $CODE)"
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 4: Directory Blocking
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 4: Directory Blocking"

# Test vendor directory
CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8101/vendor/" 2>/dev/null)
if [ "$CODE" = "403" ] || [ "$CODE" = "404" ]; then
    log_success "vendor/ directory is blocked (HTTP $CODE)"
else
    log_fail "vendor/ directory is accessible! (HTTP $CODE)"
fi

# Test node_modules directory
CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8101/node_modules/" 2>/dev/null)
if [ "$CODE" = "403" ] || [ "$CODE" = "404" ]; then
    log_success "node_modules/ directory is blocked (HTTP $CODE)"
else
    log_fail "node_modules/ directory is accessible! (HTTP $CODE)"
fi

# Test storage/logs directory (Laravel)
CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8101/storage/logs/" 2>/dev/null)
if [ "$CODE" = "403" ] || [ "$CODE" = "404" ]; then
    log_success "storage/logs/ directory is blocked (HTTP $CODE)"
else
    log_fail "storage/logs/ directory is accessible! (HTTP $CODE)"
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 5: PHP Configuration Security
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 5: PHP Configuration Security"

# Check expose_php is disabled
EXPOSE_PHP=$(docker exec "$CONTAINER_NAME" php -r "echo ini_get('expose_php');" 2>&1)
if [ -z "$EXPOSE_PHP" ] || [ "$EXPOSE_PHP" = "0" ] || [ "$EXPOSE_PHP" = "" ] || [ "$EXPOSE_PHP" = "Off" ]; then
    log_success "expose_php is disabled"
else
    log_fail "expose_php is enabled: $EXPOSE_PHP"
fi

# Check display_errors is disabled (production)
DISPLAY_ERRORS=$(docker exec "$CONTAINER_NAME" php -r "echo ini_get('display_errors');" 2>&1)
if [ "$DISPLAY_ERRORS" = "0" ] || [ "$DISPLAY_ERRORS" = "" ] || [ "$DISPLAY_ERRORS" = "Off" ]; then
    log_success "display_errors is disabled (production safe)"
else
    log_warn "display_errors is enabled: $DISPLAY_ERRORS (ok for dev)"
fi

# Check open_basedir is set
OPEN_BASEDIR=$(docker exec "$CONTAINER_NAME" php -r "echo ini_get('open_basedir');" 2>&1)
if [ -n "$OPEN_BASEDIR" ] && [ "$OPEN_BASEDIR" != "" ]; then
    log_success "open_basedir is set: $OPEN_BASEDIR"
else
    log_warn "open_basedir is not set"
fi

# Check disable_functions
DISABLED=$(docker exec "$CONTAINER_NAME" php -r "echo ini_get('disable_functions');" 2>&1)
if [ -n "$DISABLED" ] && echo "$DISABLED" | grep -q "pcntl_"; then
    log_success "Dangerous functions are disabled"
else
    log_warn "disable_functions may not be configured"
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 6: Health Endpoint Security
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 6: Health Endpoint Security"

# Health endpoint should be localhost-only (test from outside)
# This test checks if /health is accessible from host (should be blocked or return limited info)
CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8101/health" 2>/dev/null)
if [ "$CODE" = "403" ]; then
    log_success "/health endpoint is restricted to localhost (HTTP 403)"
elif [ "$CODE" = "200" ]; then
    log_warn "/health endpoint is accessible from outside (consider restricting)"
else
    log_info "/health endpoint returns HTTP $CODE"
fi

# FPM status should be restricted
CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8101/fpm-status" 2>/dev/null)
if [ "$CODE" = "403" ] || [ "$CODE" = "404" ]; then
    log_success "/fpm-status is restricted (HTTP $CODE)"
else
    log_fail "/fpm-status is accessible from outside! (HTTP $CODE)"
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 7: Upload Directory PHP Execution Block
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 7: Upload Security"

# Test PHP execution in uploads directory is blocked
CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8101/uploads/test.php" 2>/dev/null)
if [ "$CODE" = "403" ] || [ "$CODE" = "404" ]; then
    log_success "PHP execution in uploads/ is blocked (HTTP $CODE)"
else
    log_warn "uploads/ PHP execution check returned HTTP $CODE"
fi

# Test SQL/backup file blocking
CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8101/database.sql" 2>/dev/null)
if [ "$CODE" = "403" ] || [ "$CODE" = "404" ]; then
    log_success ".sql files are blocked (HTTP $CODE)"
else
    log_fail ".sql files are accessible! (HTTP $CODE)"
fi

print_summary

exit 0
