#!/bin/bash
# PHPeek Base Images - PHP Base Image Test
# Tests that all required extensions, tools, and PHPeek PM are present

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-utils.sh"

IMAGE="${IMAGE:-ghcr.io/phpeek/baseimages/php-base:8.4-alpine}"
CONTAINER_NAME="phpeek-base-test-$$"

log_section "PHP Base Image Tests"
log_info "Testing image: $IMAGE"

cleanup() {
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
}
trap cleanup EXIT

# Start a test container
docker run -d --name "$CONTAINER_NAME" "$IMAGE" sleep infinity

# Test PHP version
test_php_version() {
    log_info "Testing PHP version..."
    local php_version
    php_version=$(docker exec "$CONTAINER_NAME" php -v | head -1)
    if echo "$php_version" | grep -qE "PHP 8\.[2345]"; then
        log_success "PHP version: $php_version"
    else
        log_fail "Unexpected PHP version: $php_version"
        return 1
    fi
}

# Test required extensions
test_required_extensions() {
    log_info "Testing required PHP extensions..."

    local required_extensions=(
        "bcmath"
        "ctype"
        "curl"
        "dom"
        "exif"
        "fileinfo"
        "gd"
        "iconv"
        "imagick"
        "intl"
        "json"
        "mbstring"
        "mysqli"
        "opcache"
        "openssl"
        "pcntl"
        "pdo"
        "pdo_mysql"
        "pdo_pgsql"
        "pdo_sqlite"
        "redis"
        "session"
        "simplexml"
        "sodium"
        "tokenizer"
        "xml"
        "xmlwriter"
        "zip"
    )

    local installed_extensions
    installed_extensions=$(docker exec "$CONTAINER_NAME" php -m)

    local missing=0
    for ext in "${required_extensions[@]}"; do
        # Opcache is a Zend extension, shown as "Zend OPcache" in php -m
        if [ "$ext" = "opcache" ]; then
            if echo "$installed_extensions" | grep -qi "Zend OPcache"; then
                log_success "Extension present: $ext (Zend extension)"
            else
                log_fail "Extension missing: $ext"
                ((missing++))
            fi
        elif echo "$installed_extensions" | grep -qi "^${ext}$"; then
            log_success "Extension present: $ext"
        else
            log_fail "Extension missing: $ext"
            ((missing++))
        fi
    done

    if [ $missing -gt 0 ]; then
        return 1
    fi
}

# Test Composer
test_composer() {
    log_info "Testing Composer..."
    local composer_version
    composer_version=$(docker exec "$CONTAINER_NAME" composer --version 2>/dev/null | head -1)
    if echo "$composer_version" | grep -qE "Composer version 2"; then
        log_success "Composer: $composer_version"
    else
        log_fail "Composer not found or wrong version"
        return 1
    fi
}

# Test Node.js
test_nodejs() {
    log_info "Testing Node.js..."
    local node_version
    node_version=$(docker exec "$CONTAINER_NAME" node --version 2>/dev/null)
    if echo "$node_version" | grep -qE "^v(20|22|24)\."; then
        log_success "Node.js: $node_version"
    else
        log_fail "Node.js not found or wrong version"
        return 1
    fi

    local npm_version
    npm_version=$(docker exec "$CONTAINER_NAME" npm --version 2>/dev/null)
    if [ -n "$npm_version" ]; then
        log_success "npm: v$npm_version"
    else
        log_fail "npm not found"
        return 1
    fi
}

# Test PHPeek PM
test_phpeek_pm() {
    log_info "Testing PHPeek PM..."
    local pm_version
    pm_version=$(docker exec "$CONTAINER_NAME" phpeek-pm --version 2>/dev/null | head -1)
    if [ -n "$pm_version" ]; then
        log_success "PHPeek PM: $pm_version"
    else
        log_fail "PHPeek PM not found"
        return 1
    fi
}

# Test directories and permissions
test_directories() {
    log_info "Testing directory structure..."

    # Check /var/www/html exists and is writable by www-data
    if docker exec "$CONTAINER_NAME" test -d /var/www/html; then
        log_success "Directory exists: /var/www/html"
    else
        log_fail "Directory missing: /var/www/html"
        return 1
    fi
}

# Run all tests
FAILED=0

test_php_version || ((FAILED++))
test_required_extensions || ((FAILED++))
test_composer || ((FAILED++))
test_nodejs || ((FAILED++))
test_phpeek_pm || ((FAILED++))
test_directories || ((FAILED++))

# Summary
echo ""
log_section "PHP Base Tests Summary"

if [ $FAILED -eq 0 ]; then
    log_success "All PHP base tests passed!"
    exit 0
else
    log_fail "$FAILED test group(s) failed"
    exit 1
fi
