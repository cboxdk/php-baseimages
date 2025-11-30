#!/bin/bash
# PHPeek Base Images - Extension Unit Tests
# Tests PHP extensions are properly installed and functional in baseimages
#
# Usage:
#   ./test-extensions.sh [IMAGE] [PROFILE]
#   ./test-extensions.sh                                    # Uses default image
#   ./test-extensions.sh baseimages-php-fpm-alpine          # Test local build (auto-detect profile)
#   ./test-extensions.sh baseimages-php-fpm-nginx-alpine    # Multi-service image
#   ./test-extensions.sh baseimages-php-fpm-alpine fpm      # Explicit profile
#
# Profiles:
#   fpm       - php-fpm single-process image (has vips, no igbinary/msgpack)
#   fpm-nginx - php-fpm-nginx multi-service image (has igbinary/msgpack, no vips)
#   cli       - php-cli image

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Default image (can be overridden)
IMAGE="${1:-baseimages-php-fpm-alpine}"

# Auto-detect profile from image name or use provided
detect_profile() {
    local img="$1"
    local explicit_profile="${2:-}"

    if [ -n "$explicit_profile" ]; then
        echo "$explicit_profile"
    elif echo "$img" | grep -qi "fpm-nginx"; then
        echo "fpm-nginx"
    elif echo "$img" | grep -qi "cli"; then
        echo "cli"
    else
        echo "fpm"
    fi
}

PROFILE=$(detect_profile "$IMAGE" "${2:-}")

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
}

log_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Run PHP code in container and check result
# Uses --entrypoint to bypass container entrypoint for direct PHP access
run_php() {
    local code="$1"
    docker run --rm --entrypoint php "$IMAGE" -r "$code" 2>/dev/null
}

# Check if extension is loaded
test_extension_loaded() {
    local ext="$1"
    local desc="${2:-$ext extension loaded}"
    TESTS_RUN=$((TESTS_RUN + 1))

    if run_php "echo extension_loaded('$ext') ? 'yes' : 'no';" | grep -q "yes"; then
        log_pass "$desc"
        return 0
    else
        log_fail "$desc"
        return 1
    fi
}

# Test extension with custom PHP code
test_extension_functional() {
    local desc="$1"
    local code="$2"
    local expected="${3:-}"
    TESTS_RUN=$((TESTS_RUN + 1))

    local result
    result=$(run_php "$code" 2>&1) || true

    if [ -n "$expected" ]; then
        if echo "$result" | grep -q "$expected"; then
            log_pass "$desc"
            return 0
        else
            log_fail "$desc (expected: $expected, got: $result)"
            return 1
        fi
    else
        # Just check it doesn't error
        if [ -n "$result" ] && ! echo "$result" | grep -qi "error\|fatal\|exception"; then
            log_pass "$desc"
            return 0
        else
            log_fail "$desc (output: $result)"
            return 1
        fi
    fi
}

# ============================================================================
# TESTS START HERE
# ============================================================================

log_section "Testing Image: $IMAGE"
echo -e "  Profile: ${YELLOW}$PROFILE${NC}"

# Verify image exists
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo -e "${RED}Image not found: $IMAGE${NC}"
    echo "Build it first with: docker compose build php-fpm-alpine"
    exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
# Core Extensions (must be present in all images)
# ─────────────────────────────────────────────────────────────────────────────
log_section "Core PHP Extensions"

# OPcache has internal name "Zend OPcache"
test_extension_functional "OPcache extension loaded" \
    "echo extension_loaded('Zend OPcache') ? 'yes' : 'no';" \
    "yes"
test_extension_loaded "pdo_mysql" "PDO MySQL extension loaded"
test_extension_loaded "pdo_pgsql" "PDO PostgreSQL extension loaded"
test_extension_loaded "redis" "Redis extension loaded"
test_extension_loaded "intl" "Intl extension loaded"
test_extension_loaded "zip" "Zip extension loaded"
test_extension_loaded "bcmath" "BCMath extension loaded"
test_extension_loaded "pcntl" "PCNTL extension loaded"
test_extension_loaded "sockets" "Sockets extension loaded"

# ─────────────────────────────────────────────────────────────────────────────
# Image Processing Extensions
# ─────────────────────────────────────────────────────────────────────────────
log_section "Image Processing Extensions"

test_extension_loaded "gd" "GD extension loaded"
test_extension_loaded "imagick" "ImageMagick extension loaded"
test_extension_loaded "exif" "EXIF extension loaded"

# Vips only in php-fpm images (not fpm-nginx)
if [ "$PROFILE" = "fpm" ]; then
    test_extension_loaded "vips" "Vips extension loaded"
else
    log_skip "Vips extension (not in $PROFILE profile)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# GD Format Support Tests
# ─────────────────────────────────────────────────────────────────────────────
log_section "GD Format Support"

test_extension_functional "GD can create images" \
    "echo imagecreatetruecolor(100, 100) ? 'ok' : 'fail';" \
    "ok"

# Core formats
test_extension_functional "GD supports JPEG" \
    "\$info = gd_info(); echo \$info['JPEG Support'] ? 'yes' : 'no';" \
    "yes"

test_extension_functional "GD supports PNG" \
    "\$info = gd_info(); echo \$info['PNG Support'] ? 'yes' : 'no';" \
    "yes"

test_extension_functional "GD supports GIF (read)" \
    "\$info = gd_info(); echo \$info['GIF Read Support'] ? 'yes' : 'no';" \
    "yes"

test_extension_functional "GD supports GIF (create)" \
    "\$info = gd_info(); echo \$info['GIF Create Support'] ? 'yes' : 'no';" \
    "yes"

# Modern formats
test_extension_functional "GD supports WebP" \
    "\$info = gd_info(); echo \$info['WebP Support'] ? 'yes' : 'no';" \
    "yes"

test_extension_functional "GD supports AVIF" \
    "\$info = gd_info(); echo \$info['AVIF Support'] ? 'yes' : 'no';" \
    "yes"

test_extension_functional "GD supports BMP" \
    "\$info = gd_info(); echo \$info['BMP Support'] ? 'yes' : 'no';" \
    "yes"

# ─────────────────────────────────────────────────────────────────────────────
# ImageMagick Format Support Tests
# ─────────────────────────────────────────────────────────────────────────────
log_section "ImageMagick Format Support"

test_extension_functional "ImageMagick can create images" \
    "\$im = new Imagick(); \$im->newImage(100, 100, 'white'); echo \$im->getImageWidth();" \
    "100"

# Core formats
test_extension_functional "ImageMagick supports JPEG" \
    "echo in_array('JPEG', Imagick::queryFormats()) ? 'yes' : 'no';" \
    "yes"

test_extension_functional "ImageMagick supports PNG" \
    "echo in_array('PNG', Imagick::queryFormats()) ? 'yes' : 'no';" \
    "yes"

test_extension_functional "ImageMagick supports GIF" \
    "echo in_array('GIF', Imagick::queryFormats()) ? 'yes' : 'no';" \
    "yes"

# Modern formats
test_extension_functional "ImageMagick supports WebP" \
    "echo in_array('WEBP', Imagick::queryFormats()) ? 'yes' : 'no';" \
    "yes"

test_extension_functional "ImageMagick supports TIFF" \
    "echo in_array('TIFF', Imagick::queryFormats()) ? 'yes' : 'no';" \
    "yes"

test_extension_functional "ImageMagick supports BMP" \
    "echo in_array('BMP', Imagick::queryFormats()) ? 'yes' : 'no';" \
    "yes"

# Vector/special formats
test_extension_functional "ImageMagick supports SVG" \
    "echo in_array('SVG', Imagick::queryFormats()) ? 'yes' : 'no';" \
    "yes"

test_extension_functional "ImageMagick supports ICO" \
    "echo in_array('ICO', Imagick::queryFormats()) ? 'yes' : 'no';" \
    "yes"

# ─────────────────────────────────────────────────────────────────────────────
# Vips Format Support Tests (only in fpm profile)
# ─────────────────────────────────────────────────────────────────────────────
if [ "$PROFILE" = "fpm" ]; then
    log_section "Vips Format Support"

    test_extension_functional "Vips library version" \
        "echo 'vips ' . vips_version();" \
        "vips"

    test_extension_functional "Vips can create images" \
        "\$img = vips_image_new_from_array([[0,0,0],[0,0,0]]); echo is_resource(\$img) ? 'ok' : 'fail';" \
        "ok"

    # Test vips format support via shell (vips -l)
    # JPEG support
    test_extension_functional "Vips supports JPEG" \
        "exec('vips -l 2>/dev/null | grep -q jpegload && echo yes || echo no', \$out); echo \$out[0];" \
        "yes"

    # PNG support
    test_extension_functional "Vips supports PNG" \
        "exec('vips -l 2>/dev/null | grep -q pngload && echo yes || echo no', \$out); echo \$out[0];" \
        "yes"

    # WebP support
    test_extension_functional "Vips supports WebP" \
        "exec('vips -l 2>/dev/null | grep -q webpload && echo yes || echo no', \$out); echo \$out[0];" \
        "yes"

    # GIF support
    test_extension_functional "Vips supports GIF" \
        "exec('vips -l 2>/dev/null | grep -q gifload && echo yes || echo no', \$out); echo \$out[0];" \
        "yes"

    # TIFF support
    test_extension_functional "Vips supports TIFF" \
        "exec('vips -l 2>/dev/null | grep -q tiffload && echo yes || echo no', \$out); echo \$out[0];" \
        "yes"

    # SVG support
    test_extension_functional "Vips supports SVG" \
        "exec('vips -l 2>/dev/null | grep -q svgload && echo yes || echo no', \$out); echo \$out[0];" \
        "yes"

    # JPEG2000 support
    test_extension_functional "Vips supports JPEG2000" \
        "exec('vips -l 2>/dev/null | grep -q jp2kload && echo yes || echo no', \$out); echo \$out[0];" \
        "yes"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Serialization Extensions
# ─────────────────────────────────────────────────────────────────────────────
log_section "Serialization Extensions"

# Igbinary and msgpack only in fpm-nginx profile
if [ "$PROFILE" = "fpm-nginx" ]; then
    test_extension_loaded "igbinary" "Igbinary extension loaded"
    test_extension_loaded "msgpack" "Msgpack extension loaded"

    test_extension_functional "Igbinary serialize/unserialize" \
        "\$data = ['test' => 123]; echo igbinary_unserialize(igbinary_serialize(\$data))['test'];" \
        "123"

    test_extension_functional "Msgpack pack/unpack" \
        "\$data = ['test' => 456]; echo msgpack_unpack(msgpack_pack(\$data))['test'];" \
        "456"
else
    log_skip "Igbinary extension (not in $PROFILE profile)"
    log_skip "Msgpack extension (not in $PROFILE profile)"
fi

test_extension_loaded "apcu" "APCu extension loaded"

# ─────────────────────────────────────────────────────────────────────────────
# Database Extensions
# ─────────────────────────────────────────────────────────────────────────────
log_section "Database Extensions"

test_extension_loaded "mysqli" "MySQLi extension loaded"
test_extension_loaded "pgsql" "PostgreSQL extension loaded"
test_extension_loaded "mongodb" "MongoDB extension loaded"

test_extension_functional "PDO drivers include mysql" \
    "echo in_array('mysql', PDO::getAvailableDrivers()) ? 'yes' : 'no';" \
    "yes"

test_extension_functional "PDO drivers include pgsql" \
    "echo in_array('pgsql', PDO::getAvailableDrivers()) ? 'yes' : 'no';" \
    "yes"

# ─────────────────────────────────────────────────────────────────────────────
# Communication Extensions
# ─────────────────────────────────────────────────────────────────────────────
log_section "Communication Extensions"

test_extension_loaded "soap" "SOAP extension loaded"
test_extension_loaded "ldap" "LDAP extension loaded"
test_extension_loaded "imap" "IMAP extension loaded"

# ─────────────────────────────────────────────────────────────────────────────
# Utility Extensions
# ─────────────────────────────────────────────────────────────────────────────
log_section "Utility Extensions"

test_extension_loaded "xsl" "XSL extension loaded"
test_extension_loaded "bz2" "Bzip2 extension loaded"
test_extension_loaded "gmp" "GMP extension loaded"
test_extension_loaded "calendar" "Calendar extension loaded"
test_extension_loaded "gettext" "Gettext extension loaded"

# ─────────────────────────────────────────────────────────────────────────────
# IPC Extensions (for queue workers)
# ─────────────────────────────────────────────────────────────────────────────
log_section "IPC Extensions"

test_extension_loaded "shmop" "Shared Memory extension loaded"
test_extension_loaded "sysvmsg" "System V Messages extension loaded"
test_extension_loaded "sysvsem" "System V Semaphores extension loaded"
test_extension_loaded "sysvshm" "System V Shared Memory extension loaded"

# ─────────────────────────────────────────────────────────────────────────────
# Redis Functionality Tests
# ─────────────────────────────────────────────────────────────────────────────
log_section "Redis Extension Tests"

test_extension_functional "Redis class exists" \
    "echo class_exists('Redis') ? 'yes' : 'no';" \
    "yes"

# Igbinary/msgpack serializers only if those extensions are installed
if [ "$PROFILE" = "fpm-nginx" ]; then
    test_extension_functional "Redis supports igbinary serializer" \
        "echo defined('Redis::SERIALIZER_IGBINARY') ? 'yes' : 'no';" \
        "yes"

    test_extension_functional "Redis supports msgpack serializer" \
        "echo defined('Redis::SERIALIZER_MSGPACK') ? 'yes' : 'no';" \
        "yes"
fi

test_extension_functional "Redis supports LZ4 compression" \
    "echo defined('Redis::COMPRESSION_LZ4') ? 'yes' : 'no';" \
    "yes"

test_extension_functional "Redis supports ZSTD compression" \
    "echo defined('Redis::COMPRESSION_ZSTD') ? 'yes' : 'no';" \
    "yes"

# ─────────────────────────────────────────────────────────────────────────────
# System Tools Tests
# ─────────────────────────────────────────────────────────────────────────────
log_section "System Tools"

# Test exiftool is available
test_extension_functional "Exiftool installed" \
    "exec('which exiftool 2>/dev/null && echo yes || echo no', \$out); echo \$out[count(\$out)-1];" \
    "yes"

test_extension_functional "Exiftool version" \
    "exec('exiftool -ver 2>/dev/null', \$out); echo !empty(\$out[0]) && preg_match('/^\d+\.\d+/', \$out[0]) ? 'ok' : 'fail';" \
    "ok"

# Test Composer is available
test_extension_functional "Composer installed" \
    "exec('which composer 2>/dev/null && echo yes || echo no', \$out); echo \$out[count(\$out)-1];" \
    "yes"

# ─────────────────────────────────────────────────────────────────────────────
# PHP Configuration Tests
# ─────────────────────────────────────────────────────────────────────────────
log_section "PHP Configuration"

test_extension_functional "Memory limit is reasonable" \
    "echo (int)ini_get('memory_limit') >= 128 ? 'ok' : ini_get('memory_limit');" \
    "ok"

test_extension_functional "OPcache enabled in CLI (or not)" \
    "echo function_exists('opcache_get_status') ? 'available' : 'missing';" \
    "available"

test_extension_functional "Max execution time configurable" \
    "echo ini_get('max_execution_time') !== false ? 'ok' : 'fail';" \
    "ok"

# ============================================================================
# SUMMARY
# ============================================================================
log_section "Test Summary"

echo ""
echo "  Image:   $IMAGE"
echo "  Profile: $PROFILE"
echo "  Tests:   $TESTS_RUN"
echo -e "  ${GREEN}Passed:${NC}  $TESTS_PASSED"
echo -e "  ${RED}Failed:${NC}  $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
