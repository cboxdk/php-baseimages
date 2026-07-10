#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the entrypoint library directly (not the full entrypoint which runs lifecycle checks)
ENTRYPOINT_LIB="$TEST_DIR/../../../common/lib/entrypoint-lib.sh"
if [ -f "$ENTRYPOINT_LIB" ]; then
    # shellcheck source=/dev/null
    . "$ENTRYPOINT_LIB"
else
    echo "ERROR: entrypoint-lib.sh not found at $ENTRYPOINT_LIB"
    exit 1
fi

# Test result functions
pass() {
    echo -e "${GREEN}✓${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    echo -e "  ${RED}Expected:${NC} $2"
    echo -e "  ${RED}Got:${NC} $3"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

# Test Laravel detection
test_laravel_detection() {
    info "Testing Laravel framework detection..."

    # Create temporary Laravel structure. Detection requires `artisan` PLUS
    # corroborating evidence (laravel/framework in composer.json or
    # bootstrap/app.php) so a stray file named `artisan` doesn't trigger
    # Laravel codepaths — see detect_framework in entrypoint-lib.sh.
    TEMP_DIR=$(mktemp -d)
    mkdir -p "$TEMP_DIR/var/www/html"
    touch "$TEMP_DIR/var/www/html/artisan"
    echo '{"require": {"laravel/framework": "^11.0"}}' > "$TEMP_DIR/var/www/html/composer.json"

    # Run detection using the sourced function
    RESULT=$(detect_framework "$TEMP_DIR/var/www/html" 2>/dev/null || echo "error")

    # Cleanup
    rm -rf "$TEMP_DIR"

    if [ "$RESULT" = "laravel" ]; then
        pass "Laravel detection with artisan + composer.json"
    else
        fail "Laravel detection with artisan + composer.json" "laravel" "$RESULT"
    fi
}

# Regression: a lone `artisan` file (e.g. Statamic, or a coincidental name)
# must NOT be detected as Laravel — it should fall through to generic.
test_stray_artisan_is_generic() {
    info "Testing that a stray artisan file is not misdetected as Laravel..."

    TEMP_DIR=$(mktemp -d)
    mkdir -p "$TEMP_DIR/var/www/html"
    touch "$TEMP_DIR/var/www/html/artisan"

    RESULT=$(detect_framework "$TEMP_DIR/var/www/html" 2>/dev/null || echo "error")

    rm -rf "$TEMP_DIR"

    if [ "$RESULT" = "generic" ]; then
        pass "Stray artisan file falls through to generic"
    else
        fail "Stray artisan file falls through to generic" "generic" "$RESULT"
    fi
}

# Test Symfony detection
test_symfony_detection() {
    info "Testing Symfony framework detection..."

    # Create temporary Symfony structure
    TEMP_DIR=$(mktemp -d)
    mkdir -p "$TEMP_DIR/var/www/html/bin"
    mkdir -p "$TEMP_DIR/var/www/html/var/cache"
    touch "$TEMP_DIR/var/www/html/bin/console"
    # Create symfony.lock file
    touch "$TEMP_DIR/var/www/html/symfony.lock"

    # Run detection using the sourced function
    RESULT=$(detect_framework "$TEMP_DIR/var/www/html" 2>/dev/null || echo "error")

    # Cleanup
    rm -rf "$TEMP_DIR"

    if [ "$RESULT" = "symfony" ]; then
        pass "Symfony detection with bin/console and symfony.lock"
    else
        fail "Symfony detection with bin/console and symfony.lock" "symfony" "$RESULT"
    fi
}

# Test WordPress detection
test_wordpress_detection() {
    info "Testing WordPress framework detection..."

    # Create temporary WordPress structure
    TEMP_DIR=$(mktemp -d)
    mkdir -p "$TEMP_DIR/var/www/html"
    touch "$TEMP_DIR/var/www/html/wp-config.php"

    # Run detection using the sourced function
    RESULT=$(detect_framework "$TEMP_DIR/var/www/html" 2>/dev/null || echo "error")

    # Cleanup
    rm -rf "$TEMP_DIR"

    if [ "$RESULT" = "wordpress" ]; then
        pass "WordPress detection with wp-config.php"
    else
        fail "WordPress detection with wp-config.php" "wordpress" "$RESULT"
    fi
}

# Test generic detection
test_generic_detection() {
    info "Testing generic PHP detection..."

    # Create temporary empty structure
    TEMP_DIR=$(mktemp -d)
    mkdir -p "$TEMP_DIR/var/www/html"
    touch "$TEMP_DIR/var/www/html/index.php"

    # Run detection using the sourced function
    RESULT=$(detect_framework "$TEMP_DIR/var/www/html" 2>/dev/null || echo "error")

    # Cleanup
    rm -rf "$TEMP_DIR"

    if [ "$RESULT" = "generic" ]; then
        pass "Generic PHP detection with no framework markers"
    else
        fail "Generic PHP detection with no framework markers" "generic" "$RESULT"
    fi
}

# Test priority (Laravel should win over generic)
test_detection_priority() {
    info "Testing detection priority (Laravel with generic files)..."

    # Create temporary structure with both Laravel and generic files
    TEMP_DIR=$(mktemp -d)
    mkdir -p "$TEMP_DIR/var/www/html/bootstrap"
    touch "$TEMP_DIR/var/www/html/artisan"
    touch "$TEMP_DIR/var/www/html/bootstrap/app.php"
    touch "$TEMP_DIR/var/www/html/index.php"

    # Run detection using the sourced function
    RESULT=$(detect_framework "$TEMP_DIR/var/www/html" 2>/dev/null || echo "error")

    # Cleanup
    rm -rf "$TEMP_DIR"

    if [ "$RESULT" = "laravel" ]; then
        pass "Laravel takes priority over generic files"
    else
        fail "Laravel takes priority over generic files" "laravel" "$RESULT"
    fi
}

# Main test execution
main() {
    echo "=========================================="
    echo "Framework Detection Integration Tests"
    echo "=========================================="
    echo ""

    test_laravel_detection
    test_stray_artisan_is_generic
    test_symfony_detection
    test_wordpress_detection
    test_generic_detection
    test_detection_priority

    echo ""
    echo "=========================================="
    echo "Test Results"
    echo "=========================================="
    echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
    echo -e "${RED}Failed:${NC} $TESTS_FAILED"
    echo -e "Total: $((TESTS_PASSED + TESTS_FAILED))"

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        exit 1
    fi
}

main "$@"
