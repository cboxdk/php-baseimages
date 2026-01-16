#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0

# Test result functions
pass() {
    echo -e "${GREEN}✓${NC} $1"
    # Note: Using $((x + 1)) instead of ((x++)) to avoid errexit on first increment
    # ((x++)) returns 1 when x=0, which triggers set -e
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    echo -e "  ${RED}Details:${NC} $2"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

# Cleanup function
cleanup() {
    info "Cleaning up test containers and volumes..."
    docker-compose -f tests/integration/framework-detection/docker-compose.test.yml down -v 2>/dev/null || true
}

# Trap cleanup on exit
trap cleanup EXIT

# Test Laravel container
test_laravel_container() {
    info "Testing Laravel detection in Bookworm container..."

    # Create test Laravel structure
    mkdir -p tests/integration/framework-detection/fixtures/laravel
    touch tests/integration/framework-detection/fixtures/laravel/artisan
    echo "<?php echo 'Laravel Test';" > tests/integration/framework-detection/fixtures/laravel/index.php

    # Run container with timeout to prevent hangs
    # Note: Source the library directly (not entrypoint) to avoid starting services
    # Use '.' instead of 'source' for POSIX compatibility (dash on Debian)
    timeout 30 docker run --rm \
        -v "$(pwd)/tests/integration/framework-detection/fixtures/laravel:/var/www/html" \
        --entrypoint /bin/sh \
        ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm \
        -c ". /usr/local/lib/cbox/entrypoint-lib.sh && detect_framework" > /tmp/laravel-test.log 2>&1 || true

    # Debug: show full log content
    echo "DEBUG: Laravel test log content:"
    cat /tmp/laravel-test.log 2>/dev/null || echo "(empty or missing)"

    RESULT=$(cat /tmp/laravel-test.log | grep -o "laravel\|symfony\|wordpress\|generic" || echo "error")

    # Cleanup - use sudo because container may create files owned by root
    sudo rm -rf tests/integration/framework-detection/fixtures/laravel || rm -rf tests/integration/framework-detection/fixtures/laravel 2>/dev/null || true
    rm -f /tmp/laravel-test.log

    if [ "$RESULT" = "laravel" ]; then
        pass "Laravel detected in Bookworm container"
    else
        fail "Laravel detection in Bookworm container" "Got: $RESULT"
    fi
}

# Test Symfony container
test_symfony_container() {
    info "Testing Symfony detection in Bookworm container..."

    # Create test Symfony structure
    # Note: detect_framework requires both bin/console AND symfony.lock
    mkdir -p tests/integration/framework-detection/fixtures/symfony/bin
    mkdir -p tests/integration/framework-detection/fixtures/symfony/var/cache
    touch tests/integration/framework-detection/fixtures/symfony/bin/console
    touch tests/integration/framework-detection/fixtures/symfony/symfony.lock
    echo "<?php echo 'Symfony Test';" > tests/integration/framework-detection/fixtures/symfony/index.php

    # Run container with timeout to prevent hangs
    # Note: Source the library directly (not entrypoint) to avoid starting services
    # Use '.' instead of 'source' for POSIX compatibility (dash on Debian)
    timeout 30 docker run --rm \
        -v "$(pwd)/tests/integration/framework-detection/fixtures/symfony:/var/www/html" \
        --entrypoint /bin/sh \
        ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm \
        -c ". /usr/local/lib/cbox/entrypoint-lib.sh && detect_framework" > /tmp/symfony-test.log 2>&1 || true

    # Debug: show full log content
    echo "DEBUG: Symfony test log content:"
    cat /tmp/symfony-test.log 2>/dev/null || echo "(empty or missing)"

    RESULT=$(cat /tmp/symfony-test.log | grep -o "laravel\|symfony\|wordpress\|generic" || echo "error")

    # Cleanup - use sudo because container may create files owned by root
    sudo rm -rf tests/integration/framework-detection/fixtures/symfony || rm -rf tests/integration/framework-detection/fixtures/symfony 2>/dev/null || true
    rm -f /tmp/symfony-test.log

    if [ "$RESULT" = "symfony" ]; then
        pass "Symfony detected in Bookworm container"
    else
        fail "Symfony detection in Bookworm container" "Got: $RESULT"
    fi
}

# Test WordPress container
test_wordpress_container() {
    info "Testing WordPress detection in Bookworm container..."

    # Create test WordPress structure
    mkdir -p tests/integration/framework-detection/fixtures/wordpress
    touch tests/integration/framework-detection/fixtures/wordpress/wp-config.php
    echo "<?php echo 'WordPress Test';" > tests/integration/framework-detection/fixtures/wordpress/index.php

    # Run container with timeout to prevent hangs
    # Note: Source the library directly (not entrypoint) to avoid starting services
    # Use '.' instead of 'source' for POSIX compatibility (dash on Debian)
    timeout 30 docker run --rm \
        -v "$(pwd)/tests/integration/framework-detection/fixtures/wordpress:/var/www/html" \
        --entrypoint /bin/sh \
        ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm \
        -c ". /usr/local/lib/cbox/entrypoint-lib.sh && detect_framework" > /tmp/wordpress-test.log 2>&1 || true

    # Debug: show full log content
    echo "DEBUG: WordPress test log content:"
    cat /tmp/wordpress-test.log 2>/dev/null || echo "(empty or missing)"

    RESULT=$(cat /tmp/wordpress-test.log | grep -o "laravel\|symfony\|wordpress\|generic" || echo "error")

    # Cleanup - use sudo because container may create files owned by root
    sudo rm -rf tests/integration/framework-detection/fixtures/wordpress || rm -rf tests/integration/framework-detection/fixtures/wordpress 2>/dev/null || true
    rm -f /tmp/wordpress-test.log

    if [ "$RESULT" = "wordpress" ]; then
        pass "WordPress detected in Bookworm container"
    else
        fail "WordPress detection in Bookworm container" "Got: $RESULT"
    fi
}

# Test generic container
test_generic_container() {
    info "Testing generic PHP detection in Bookworm container..."

    # Create test generic structure
    mkdir -p tests/integration/framework-detection/fixtures/generic
    echo "<?php phpinfo();" > tests/integration/framework-detection/fixtures/generic/index.php

    # Run container with timeout to prevent hangs
    # Note: Source the library directly (not entrypoint) to avoid starting services
    # Use '.' instead of 'source' for POSIX compatibility (dash on Debian)
    timeout 30 docker run --rm \
        -v "$(pwd)/tests/integration/framework-detection/fixtures/generic:/var/www/html" \
        --entrypoint /bin/sh \
        ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm \
        -c ". /usr/local/lib/cbox/entrypoint-lib.sh && detect_framework" > /tmp/generic-test.log 2>&1 || true

    # Debug: show full log content
    echo "DEBUG: Generic test log content:"
    cat /tmp/generic-test.log 2>/dev/null || echo "(empty or missing)"

    RESULT=$(cat /tmp/generic-test.log | grep -o "laravel\|symfony\|wordpress\|generic" || echo "error")

    # Cleanup - use sudo because container may create files owned by root
    sudo rm -rf tests/integration/framework-detection/fixtures/generic || rm -rf tests/integration/framework-detection/fixtures/generic 2>/dev/null || true
    rm -f /tmp/generic-test.log

    if [ "$RESULT" = "generic" ]; then
        pass "Generic PHP detected in Bookworm container"
    else
        fail "Generic PHP detection in Bookworm container" "Got: $RESULT"
    fi
}

# Main test execution
main() {
    echo "=========================================="
    echo "Docker Framework Detection Tests"
    echo "=========================================="
    echo ""

    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker not found. Skipping Docker tests.${NC}"
        exit 0
    fi

    # Create fixtures directory
    mkdir -p tests/integration/framework-detection/fixtures

    test_laravel_container
    test_symfony_container
    test_wordpress_container
    test_generic_container

    echo ""
    echo "=========================================="
    echo "Test Results"
    echo "=========================================="
    echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
    echo -e "${RED}Failed:${NC} $TESTS_FAILED"
    echo -e "Total: $((TESTS_PASSED + TESTS_FAILED))"

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All Docker tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some Docker tests failed!${NC}"
        exit 1
    fi
}

main "$@"
