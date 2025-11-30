#!/bin/bash
# PHPeek Base Images - Matrix Test Runner
# Builds and tests all PHP versions and OS variants
#
# Usage:
#   ./run-matrix-tests.sh              # Run all tests
#   ./run-matrix-tests.sh --build      # Build images before testing
#   ./run-matrix-tests.sh --fpm        # Test only php-fpm images
#   ./run-matrix-tests.sh --fpm-nginx  # Test only php-fpm-nginx images
#   ./run-matrix-tests.sh --quick      # Quick mode: skip slow tests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
PHP_VERSIONS=("8.2" "8.3" "8.4")
OS_VARIANTS=("alpine" "debian" "ubuntu")
IMAGE_TYPES=("fpm" "fpm-nginx")

# Options
BUILD_IMAGES=false
TEST_FPM=true
TEST_FPM_NGINX=true
QUICK_MODE=false
PARALLEL=false

# Counters
TOTAL_IMAGES=0
IMAGES_TESTED=0
IMAGES_PASSED=0
IMAGES_FAILED=0
IMAGES_SKIPPED=0

# Results tracking
declare -a PASSED_IMAGES
declare -a FAILED_IMAGES
declare -a SKIPPED_IMAGES

log_header() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  $1"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
}

log_section() {
    echo ""
    echo -e "${BLUE}┌──────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${NC}  $1"
    echo -e "${BLUE}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
}

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --build)
                BUILD_IMAGES=true
                shift
                ;;
            --fpm)
                TEST_FPM=true
                TEST_FPM_NGINX=false
                shift
                ;;
            --fpm-nginx)
                TEST_FPM=false
                TEST_FPM_NGINX=true
                shift
                ;;
            --quick)
                QUICK_MODE=true
                shift
                ;;
            --parallel)
                PARALLEL=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --build       Build images before testing"
                echo "  --fpm         Test only php-fpm images"
                echo "  --fpm-nginx   Test only php-fpm-nginx images"
                echo "  --quick       Quick mode: skip slow format tests"
                echo "  --parallel    Run tests in parallel (experimental)"
                echo "  --help        Show this help"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

# Get docker-compose service name for image
get_service_name() {
    local type="$1"
    local version="$2"
    local os="$3"

    # Map to docker-compose service names
    if [ "$type" = "fpm" ]; then
        echo "php-fpm-${os}"
    else
        echo "php-fpm-nginx-${os}"
    fi
}

# Get full image name
get_image_name() {
    local type="$1"
    local version="$2"
    local os="$3"

    if [ "$type" = "fpm" ]; then
        echo "baseimages-php-fpm-${os}"
    else
        echo "baseimages-php-fpm-nginx-${os}"
    fi
}

# Build image using docker compose
build_image() {
    local type="$1"
    local version="$2"
    local os="$3"
    local service=$(get_service_name "$type" "$version" "$os")

    log_info "Building $type $version $os..."

    cd "$PROJECT_ROOT"

    if [ "$type" = "fpm-nginx" ]; then
        docker compose --profile multi build "$service" 2>&1 | tail -5
    else
        docker compose build "$service" 2>&1 | tail -5
    fi
}

# Test a single image
test_image() {
    local type="$1"
    local version="$2"
    local os="$3"
    local image=$(get_image_name "$type" "$version" "$os")
    local profile

    if [ "$type" = "fpm" ]; then
        profile="fpm"
    else
        profile="fpm-nginx"
    fi

    TOTAL_IMAGES=$((TOTAL_IMAGES + 1))

    # Check if image exists
    if ! docker image inspect "$image" >/dev/null 2>&1; then
        if [ "$BUILD_IMAGES" = true ]; then
            build_image "$type" "$version" "$os" || {
                log_error "Failed to build $image"
                IMAGES_FAILED=$((IMAGES_FAILED + 1))
                FAILED_IMAGES+=("$image (build failed)")
                return 1
            }
        else
            log_warn "Image not found: $image (use --build to build)"
            IMAGES_SKIPPED=$((IMAGES_SKIPPED + 1))
            SKIPPED_IMAGES+=("$image")
            return 0
        fi
    fi

    IMAGES_TESTED=$((IMAGES_TESTED + 1))
    log_info "Testing $image (profile: $profile)..."

    # Run the extension tests
    if "$SCRIPT_DIR/test-extensions.sh" "$image" "$profile" > /tmp/test-output-$$.log 2>&1; then
        log_success "$image"
        IMAGES_PASSED=$((IMAGES_PASSED + 1))
        PASSED_IMAGES+=("$image")

        # Show summary line from test output
        grep -E "Tests:|Passed:|Failed:" /tmp/test-output-$$.log | tail -3 | head -1 || true
    else
        log_error "$image"
        IMAGES_FAILED=$((IMAGES_FAILED + 1))
        FAILED_IMAGES+=("$image")

        # Show failure details
        echo "  Last 10 lines of test output:"
        tail -10 /tmp/test-output-$$.log | sed 's/^/    /'
    fi

    rm -f /tmp/test-output-$$.log
}

# Main test matrix
run_matrix() {
    log_header "PHPeek Base Images - Matrix Test Runner"

    echo ""
    echo "Configuration:"
    echo "  PHP Versions: ${PHP_VERSIONS[*]}"
    echo "  OS Variants:  ${OS_VARIANTS[*]}"
    echo "  Build:        $BUILD_IMAGES"
    echo "  Test FPM:     $TEST_FPM"
    echo "  Test FPM-Nginx: $TEST_FPM_NGINX"

    # Test php-fpm images
    if [ "$TEST_FPM" = true ]; then
        log_section "Testing php-fpm images"

        for version in "${PHP_VERSIONS[@]}"; do
            for os in "${OS_VARIANTS[@]}"; do
                test_image "fpm" "$version" "$os" || true
            done
        done
    fi

    # Test php-fpm-nginx images
    if [ "$TEST_FPM_NGINX" = true ]; then
        log_section "Testing php-fpm-nginx images"

        for version in "${PHP_VERSIONS[@]}"; do
            for os in "${OS_VARIANTS[@]}"; do
                test_image "fpm-nginx" "$version" "$os" || true
            done
        done
    fi
}

# Print summary
print_summary() {
    log_header "Test Matrix Summary"

    echo ""
    echo "  Total Images:  $TOTAL_IMAGES"
    echo "  Tested:        $IMAGES_TESTED"
    echo -e "  ${GREEN}Passed:${NC}        $IMAGES_PASSED"
    echo -e "  ${RED}Failed:${NC}        $IMAGES_FAILED"
    echo -e "  ${YELLOW}Skipped:${NC}       $IMAGES_SKIPPED"

    if [ ${#PASSED_IMAGES[@]} -gt 0 ]; then
        echo ""
        echo -e "${GREEN}Passed images:${NC}"
        for img in "${PASSED_IMAGES[@]}"; do
            echo "  ✓ $img"
        done
    fi

    if [ ${#FAILED_IMAGES[@]} -gt 0 ]; then
        echo ""
        echo -e "${RED}Failed images:${NC}"
        for img in "${FAILED_IMAGES[@]}"; do
            echo "  ✗ $img"
        done
    fi

    if [ ${#SKIPPED_IMAGES[@]} -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}Skipped images:${NC}"
        for img in "${SKIPPED_IMAGES[@]}"; do
            echo "  - $img"
        done
    fi

    echo ""

    if [ $IMAGES_FAILED -gt 0 ]; then
        echo -e "${RED}Some tests failed!${NC}"
        return 1
    elif [ $IMAGES_TESTED -eq 0 ]; then
        echo -e "${YELLOW}No images were tested. Use --build to build images first.${NC}"
        return 0
    else
        echo -e "${GREEN}All tested images passed!${NC}"
        return 0
    fi
}

# Main
main() {
    parse_args "$@"

    # Initialize arrays
    PASSED_IMAGES=()
    FAILED_IMAGES=()
    SKIPPED_IMAGES=()

    run_matrix
    print_summary
}

main "$@"
