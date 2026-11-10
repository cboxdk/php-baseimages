#!/bin/bash
# Cbox Base Images - PHP Base Image Test
# Tests that all required extensions, tools, and Cbox Init are present

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-utils.sh"

IMAGE="${IMAGE:-ghcr.io/cboxdk/php-baseimages/php-base:8.4-alpine}"
CONTAINER_NAME="cbox-base-test-$$"

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
    php_version=$(docker exec "$CONTAINER_NAME" php -v | head -1) || true
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
    installed_extensions=$(docker exec "$CONTAINER_NAME" php -m) || true

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
    composer_version=$(docker exec "$CONTAINER_NAME" composer --version 2>/dev/null | head -1) || true
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
    node_version=$(docker exec "$CONTAINER_NAME" node --version 2>/dev/null) || true
    if echo "$node_version" | grep -qE "^v(20|22|24)\."; then
        log_success "Node.js: $node_version"
    else
        log_fail "Node.js not found or wrong version"
        return 1
    fi

    local npm_version
    npm_version=$(docker exec "$CONTAINER_NAME" npm --version 2>/dev/null) || true
    if [ -n "$npm_version" ]; then
        log_success "npm: v$npm_version"
    else
        log_fail "npm not found"
        return 1
    fi
}

# Test Cbox Init
test_cbox_init() {
    log_info "Testing Cbox Init..."
    local pm_version
    pm_version=$(docker exec "$CONTAINER_NAME" cbox-init --version 2>/dev/null | head -1) || true
    if [ -n "$pm_version" ]; then
        log_success "Cbox Init: $pm_version"
    else
        log_fail "Cbox Init not found"
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

# Test telemetry-native ships but stays unloaded
#
# The point of the extension being opt-in is that a default container does NOT
# have it in php -m. Assert both halves, and drive the ON half through the real
# entrypoint function rather than a hand-written PHP_INI_SCAN_DIR - a .so that
# ships but never actually reaches PHP is exactly the failure this guards.
test_telemetry_native() {
    log_info "Testing telemetry-native gate..."

    local php_minor
    php_minor=$(docker exec "$CONTAINER_NAME" php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null) || true
    if [ "$php_minor" = "8.2" ]; then
        log_info "telemetry-native: skipped, the extension needs PHP 8.3+ (image is $php_minor)"
        return 0
    fi

    if docker exec "$CONTAINER_NAME" php -m | grep -q '^cbox_telemetry$'; then
        log_fail "telemetry-native is loaded by default - it must stay opt-in"
        return 1
    fi
    log_success "telemetry-native: not loaded by default"

    # PHP_TELEMETRY_NATIVE=true, through the shipped entrypoint library
    local backend
    backend=$(docker exec -e PHP_TELEMETRY_NATIVE=true "$CONTAINER_NAME" sh -c \
        '. /usr/local/lib/cbox/entrypoint-lib.sh; setup_telemetry_native >/dev/null 2>&1; php -r "echo extension_loaded(\"cbox_telemetry\") ? cbox_telemetry_status()[\"timer_backend\"] : \"not-loaded\";"' 2>/dev/null) || true
    if [ "$backend" != "posix-thread-cputime" ]; then
        log_fail "telemetry-native: PHP_TELEMETRY_NATIVE=true gave timer backend '$backend', expected posix-thread-cputime"
        return 1
    fi
    log_success "telemetry-native: PHP_TELEMETRY_NATIVE=true loads it ($backend)"

    # Automatic units are a separate switch: on for FPM, wrong for workers
    local auto_off auto_on
    auto_off=$(docker exec -e PHP_TELEMETRY_NATIVE=true "$CONTAINER_NAME" sh -c \
        '. /usr/local/lib/cbox/entrypoint-lib.sh; setup_telemetry_native >/dev/null 2>&1; php -r "echo cbox_telemetry_status()[\"auto\"] ? 1 : 0;"' 2>/dev/null) || true
    auto_on=$(docker exec -e PHP_TELEMETRY_NATIVE=true -e PHP_TELEMETRY_NATIVE_AUTO=true "$CONTAINER_NAME" sh -c \
        '. /usr/local/lib/cbox/entrypoint-lib.sh; setup_telemetry_native >/dev/null 2>&1; php -r "echo cbox_telemetry_status()[\"auto\"] ? 1 : 0;"' 2>/dev/null) || true
    if [ "$auto_off" != "0" ] || [ "$auto_on" != "1" ]; then
        log_fail "telemetry-native: auto gate wrong (without PHP_TELEMETRY_NATIVE_AUTO='$auto_off', with='$auto_on')"
        return 1
    fi
    log_success "telemetry-native: automatic units gated separately"
}

# Test runtime tools that every tier must carry
#
# git is the one that went missing: the dev tier purged it while cleaning up
# its build deps, so the tier meant for CI and local work was the only one
# without it. tests/test-runtime-deps.sh catches that statically; this checks
# the artifact that actually shipped.
test_runtime_tools() {
    log_info "Testing runtime tools present in every tier..."

    local failed=0
    for tool in git ssh unzip curl; do
        if docker exec "$CONTAINER_NAME" sh -c "command -v $tool" >/dev/null 2>&1; then
            log_success "runtime tool present: $tool"
        else
            log_fail "runtime tool MISSING: $tool (every tier must ship it)"
            failed=1
        fi
    done

    # safe.directory is baked in slim-base purely so git works on a
    # bind-mounted app owned by another UID - useless if git is not there
    if docker exec "$CONTAINER_NAME" git config --system --get-all safe.directory 2>/dev/null | grep -q '\*'; then
        log_success "git safe.directory = * is in effect"
    else
        log_fail "git safe.directory = * missing (bind-mounted repos will be refused)"
        failed=1
    fi

    return $failed
}

# Run all tests
FAILED=0

test_php_version || ((FAILED++))
test_required_extensions || ((FAILED++))
test_composer || ((FAILED++))
test_nodejs || ((FAILED++))
test_cbox_init || ((FAILED++))
test_directories || ((FAILED++))
test_telemetry_native || ((FAILED++))
test_runtime_tools || ((FAILED++))

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
