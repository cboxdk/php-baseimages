#!/bin/bash
# E2E Test: Image Format Support
# Tests GD and ImageMagick support for various image formats
# JPEG, PNG, GIF, WebP, AVIF, HEIF, PDF

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-utils.sh"

E2E_ROOT="$(get_e2e_root)"
FIXTURE_DIR="$E2E_ROOT/fixtures/image-formats"
PROJECT_NAME="e2e-image-formats"

# Simple cleanup function - called explicitly, not via trap
# Always returns 0 regardless of docker compose result
do_cleanup() {
    cleanup_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME"
    return 0
}

log_section "Image Format Support E2E Test"

# Clean up any existing containers
cleanup_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME"

# Start container
log_info "Starting image processing test container..."
docker compose -f "$FIXTURE_DIR/docker-compose.yml" -p "$PROJECT_NAME" up -d 2>&1 || true

CONTAINER_NAME="e2e-image-formats"
wait_for_healthy "$CONTAINER_NAME" 60

# ═══════════════════════════════════════════════════════════════════════════
# TEST 1: GD Library Support
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 1: GD Library Support"

# Check GD is loaded
assert_exec_contains "$CONTAINER_NAME" "php -m | grep -i gd" "gd" "GD extension is loaded"

# Check GD info for format support
GD_INFO=$(docker exec "$CONTAINER_NAME" php -r "print_r(gd_info());" 2>&1) || true

# JPEG Support
if echo "$GD_INFO" | grep -q '\[JPEG Support\] => 1'; then
    log_success "GD: JPEG support enabled"
else
    log_fail "GD: JPEG support missing"
fi

# PNG Support
if echo "$GD_INFO" | grep -q '\[PNG Support\] => 1'; then
    log_success "GD: PNG support enabled"
else
    log_fail "GD: PNG support missing"
fi

# GIF Support
if echo "$GD_INFO" | grep -q '\[GIF Read Support\] => 1'; then
    log_success "GD: GIF support enabled"
else
    log_fail "GD: GIF support missing"
fi

# WebP Support
if echo "$GD_INFO" | grep -q '\[WebP Support\] => 1'; then
    log_success "GD: WebP support enabled"
else
    log_fail "GD: WebP support missing"
fi

# AVIF Support (PHP 8.1+)
if echo "$GD_INFO" | grep -q '\[AVIF Support\] => 1'; then
    log_success "GD: AVIF support enabled"
else
    log_warn "GD: AVIF support not available (may require PHP 8.1+ with libavif)"
fi

# FreeType Support (for text rendering)
if echo "$GD_INFO" | grep -q '\[FreeType Support\] => 1'; then
    log_success "GD: FreeType (text) support enabled"
else
    log_fail "GD: FreeType support missing"
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 2: ImageMagick Support
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 2: ImageMagick Support"

# Check Imagick extension
assert_exec_contains "$CONTAINER_NAME" "php -m | grep -i imagick" "imagick" "Imagick extension is loaded"

# Get ImageMagick formats
IMAGICK_FORMATS=$(docker exec "$CONTAINER_NAME" php -r "echo implode(',', Imagick::queryFormats());" 2>&1 || echo "")

# Check supported formats
for FORMAT in JPEG PNG GIF WEBP; do
    if echo "$IMAGICK_FORMATS" | grep -qi "$FORMAT"; then
        log_success "ImageMagick: $FORMAT support enabled"
    else
        log_fail "ImageMagick: $FORMAT support missing"
    fi
done

# AVIF support (newer ImageMagick)
if echo "$IMAGICK_FORMATS" | grep -qi "AVIF"; then
    log_success "ImageMagick: AVIF support enabled"
else
    log_warn "ImageMagick: AVIF support not available (requires ImageMagick 7.0.25+)"
fi

# HEIC/HEIF support
if echo "$IMAGICK_FORMATS" | grep -qi "HEIC\|HEIF"; then
    log_success "ImageMagick: HEIC/HEIF support enabled"
else
    log_warn "ImageMagick: HEIC/HEIF support not available (requires libheif)"
fi

# PDF support (requires Ghostscript)
if echo "$IMAGICK_FORMATS" | grep -qi "PDF"; then
    log_success "ImageMagick: PDF support enabled"
else
    log_warn "ImageMagick: PDF support not available (requires Ghostscript)"
fi

# SVG support
if echo "$IMAGICK_FORMATS" | grep -qi "SVG"; then
    log_success "ImageMagick: SVG support enabled"
else
    log_warn "ImageMagick: SVG support not available"
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 3: Actual Image Creation Tests
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 3: Actual Image Creation"

# Test creating actual images with GD
log_info "Testing GD image creation..."

# Create test images via HTTP endpoint
RESPONSE=$(curl -s "http://localhost:8099/test-gd.php" 2>/dev/null || echo '{"error":"failed"}')

if echo "$RESPONSE" | grep -q '"jpeg"' && echo "$RESPONSE" | grep -q '"success": true'; then
    log_success "GD: Created JPEG image successfully"
else
    log_fail "GD: Failed to create JPEG image"
fi

if echo "$RESPONSE" | grep -q '"png"' && echo "$RESPONSE" | grep -A2 '"png"' | grep -q '"success": true'; then
    log_success "GD: Created PNG image successfully"
else
    log_fail "GD: Failed to create PNG image"
fi

if echo "$RESPONSE" | grep -q '"gif"' && echo "$RESPONSE" | grep -A2 '"gif"' | grep -q '"success": true'; then
    log_success "GD: Created GIF image successfully"
else
    log_fail "GD: Failed to create GIF image"
fi

if echo "$RESPONSE" | grep -q '"webp"' && echo "$RESPONSE" | grep -A2 '"webp"' | grep -q '"success": true'; then
    log_success "GD: Created WebP image successfully"
else
    log_fail "GD: Failed to create WebP image"
fi

if echo "$RESPONSE" | grep -q '"avif"' && echo "$RESPONSE" | grep -A2 '"avif"' | grep -q '"success": true'; then
    log_success "GD: Created AVIF image successfully"
else
    log_warn "GD: AVIF creation not supported"
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 4: ImageMagick Image Operations
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 4: ImageMagick Image Operations"

RESPONSE=$(curl -s "http://localhost:8099/test-imagick.php" 2>/dev/null || echo '{"error":"failed"}')

if echo "$RESPONSE" | grep -q '"resize"' && echo "$RESPONSE" | grep -A2 '"resize"' | grep -q '"success": true'; then
    log_success "ImageMagick: Resize operation works"
else
    log_fail "ImageMagick: Resize operation failed"
fi

if echo "$RESPONSE" | grep -q '"convert_webp"' && echo "$RESPONSE" | grep -A2 '"convert_webp"' | grep -q '"success": true'; then
    log_success "ImageMagick: Convert to WebP works"
else
    log_fail "ImageMagick: Convert to WebP failed"
fi

if echo "$RESPONSE" | grep -q '"thumbnail"' && echo "$RESPONSE" | grep -A2 '"thumbnail"' | grep -q '"success": true'; then
    log_success "ImageMagick: Thumbnail generation works"
else
    log_fail "ImageMagick: Thumbnail generation failed"
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 5: Image Quality and Metadata
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 5: EXIF and Metadata Support"

# Check EXIF extension
assert_exec_contains "$CONTAINER_NAME" "php -m | grep -i exif" "exif" "EXIF extension is loaded"

RESPONSE=$(curl -s "http://localhost:8099/test-exif.php" 2>/dev/null || echo '{"error":"failed"}')

if echo "$RESPONSE" | grep -q '"exif_read"' && echo "$RESPONSE" | grep -A2 '"exif_read"' | grep -q '"success": true'; then
    log_success "EXIF: Can read image metadata"
elif echo "$RESPONSE" | grep -q '"imagetype"' && echo "$RESPONSE" | grep -A3 '"imagetype"' | grep -q '"success": true'; then
    log_success "EXIF: Image type detection works"
else
    log_warn "EXIF: Metadata reading not fully tested"
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 6: Memory and Resource Limits
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 6: Image Processing Resources"

# Check memory limit is adequate for image processing
MEMORY_LIMIT=$(docker exec "$CONTAINER_NAME" php -r "echo ini_get('memory_limit');" 2>&1) || true
log_info "PHP memory_limit: $MEMORY_LIMIT"

# Parse memory limit to MB
if [[ "$MEMORY_LIMIT" == "-1" ]]; then
    log_success "Memory limit: Unlimited (good for large images)"
elif [[ "$MEMORY_LIMIT" =~ ^([0-9]+)M$ ]]; then
    MB="${BASH_REMATCH[1]}"
    if [ "$MB" -ge 256 ]; then
        log_success "Memory limit: ${MB}M (adequate for image processing)"
    else
        log_warn "Memory limit: ${MB}M (may be insufficient for large images)"
    fi
else
    log_info "Memory limit: $MEMORY_LIMIT"
fi

# Check max execution time
MAX_EXEC=$(docker exec "$CONTAINER_NAME" php -r "echo ini_get('max_execution_time');" 2>&1) || true
if [ "$MAX_EXEC" -ge 60 ] || [ "$MAX_EXEC" -eq 0 ]; then
    log_success "Max execution time: ${MAX_EXEC}s (adequate for image processing)"
else
    log_warn "Max execution time: ${MAX_EXEC}s (may timeout on large images)"
fi

# ═══════════════════════════════════════════════════════════════════════════
# Test 7 was libvips. The extension is gone (#23): it had no PIE package under
# any name, was PECL-only, and its upstream repo has been untouched since
# 2024-10 - so it could not survive the retirement of pecl. GD and ImageMagick
# are the image's image-processing stack, which is what this scenario already
# called them when the libvips section was marked optional.
# ═══════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════
# TEST 8: CLI Image Tools
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 8: CLI Image Tools"

# Check if convert command is available
if docker exec "$CONTAINER_NAME" which convert >/dev/null 2>&1; then
    log_success "ImageMagick CLI (convert) is available"

    # Check version
    VERSION=$(docker exec "$CONTAINER_NAME" convert --version 2>&1 | head -1 || echo "unknown")
    log_info "ImageMagick version: $VERSION"
else
    log_warn "ImageMagick CLI not installed (only PHP extension)"
fi

# Check for other useful tools
for TOOL in identify mogrify; do
    if docker exec "$CONTAINER_NAME" which "$TOOL" >/dev/null 2>&1; then
        log_success "ImageMagick tool '$TOOL' is available"
    else
        log_info "ImageMagick tool '$TOOL' not installed"
    fi
done

# Store test results before any cleanup that might affect shell state
FINAL_PASSED=$TESTS_PASSED
FINAL_FAILED=$TESTS_FAILED

# Determine exit code BEFORE cleanup
if [ "$FINAL_FAILED" -gt 0 ]; then
    TEST_EXIT_CODE=1
else
    TEST_EXIT_CODE=0
fi

# Print summary (ignore any errors from print function)
print_summary 2>/dev/null || true

# Run cleanup in a subshell to completely isolate it from main script exit code
# The subshell will run with its own environment and cannot affect our exit code
(
    set +euo pipefail
    do_cleanup 2>/dev/null
) || true

# Use explicit exit with the pre-determined code
exit "$TEST_EXIT_CODE"
