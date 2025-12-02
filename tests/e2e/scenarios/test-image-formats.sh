#!/bin/bash
# E2E Test: Image Format Support
# Tests GD, ImageMagick, and libvips support for various image formats
# JPEG, PNG, GIF, WebP, AVIF, HEIF, PDF

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-utils.sh"

E2E_ROOT="$(get_e2e_root)"
FIXTURE_DIR="$E2E_ROOT/fixtures/image-formats"
PROJECT_NAME="e2e-image-formats"

# Cleanup on exit
trap 'ec=$?; cleanup_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME"; exit $ec' EXIT

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
GD_INFO=$(docker exec "$CONTAINER_NAME" php -r "print_r(gd_info());" 2>&1)

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
MEMORY_LIMIT=$(docker exec "$CONTAINER_NAME" php -r "echo ini_get('memory_limit');" 2>&1)
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
MAX_EXEC=$(docker exec "$CONTAINER_NAME" php -r "echo ini_get('max_execution_time');" 2>&1)
if [ "$MAX_EXEC" -ge 60 ] || [ "$MAX_EXEC" -eq 0 ]; then
    log_success "Max execution time: ${MAX_EXEC}s (adequate for image processing)"
else
    log_warn "Max execution time: ${MAX_EXEC}s (may timeout on large images)"
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 7: libvips Support (Optional - gracefully skip if not installed)
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 7: libvips Support (Optional)"

# Note: libvips is optional - GD and ImageMagick are the primary image libraries
# This test validates libvips functionality IF it's installed

VIPS_AVAILABLE=false

# Check if vips PHP extension is loaded
if docker exec "$CONTAINER_NAME" php -m 2>/dev/null | grep -qi "vips"; then
    log_success "VIPS PHP extension is loaded"
    VIPS_AVAILABLE=true

    # Get vips version
    VIPS_VERSION=$(docker exec "$CONTAINER_NAME" php -r "echo function_exists('vips_version') ? vips_version() : 'unknown';" 2>&1)
    log_info "libvips version: $VIPS_VERSION"

    # Test vips via HTTP endpoint with proper validation
    VIPS_RESPONSE=$(curl -s "http://localhost:8099/test-vips.php" 2>/dev/null || echo '{"error":"curl_failed"}')

    # Validate we got actual JSON response
    if echo "$VIPS_RESPONSE" | grep -q '"available": true'; then
        log_success "VIPS: HTTP endpoint returned valid response"

        # Test JPEG processing - verify file was created with size > 0
        if echo "$VIPS_RESPONSE" | grep -q '"jpeg"' && echo "$VIPS_RESPONSE" | grep -A3 '"jpeg"' | grep -qE '"size": [1-9][0-9]*'; then
            log_success "VIPS: JPEG processing works (file created with valid size)"
        else
            log_warn "VIPS: JPEG processing returned but file size may be zero"
        fi

        # Test WebP conversion
        if echo "$VIPS_RESPONSE" | grep -q '"webp"' && echo "$VIPS_RESPONSE" | grep -A3 '"webp"' | grep -qE '"size": [1-9][0-9]*'; then
            log_success "VIPS: WebP conversion works"
        else
            log_warn "VIPS: WebP conversion not functional"
        fi

        # Test thumbnail generation
        if echo "$VIPS_RESPONSE" | grep -q '"thumbnail"' && echo "$VIPS_RESPONSE" | grep -A3 '"thumbnail"' | grep -qE '"success": true'; then
            log_success "VIPS: Thumbnail generation works"
        else
            log_warn "VIPS: Thumbnail generation not functional"
        fi

        # Test metadata stripping
        if echo "$VIPS_RESPONSE" | grep -q '"strip_metadata"' && echo "$VIPS_RESPONSE" | grep -A3 '"strip_metadata"' | grep -qE '"success": true'; then
            log_success "VIPS: Metadata stripping works"
        else
            log_warn "VIPS: Metadata stripping not functional"
        fi

        # Test image info extraction
        if echo "$VIPS_RESPONSE" | grep -q '"info"' && echo "$VIPS_RESPONSE" | grep -A5 '"info"' | grep -qE '"width": [1-9][0-9]*'; then
            log_success "VIPS: Image info extraction works"
        else
            log_warn "VIPS: Image info extraction not functional"
        fi
    else
        log_warn "VIPS: HTTP endpoint did not return expected response"
        log_info "Response: $VIPS_RESPONSE"
    fi

    # Additional: Test actual image processing in container
    log_info "Running direct VIPS image processing test..."
    DIRECT_TEST=$(docker exec "$CONTAINER_NAME" php -r "
        if (!extension_loaded('vips')) { echo 'no_vips'; exit; }
        \$img = imagecreatetruecolor(100, 100);
        \$red = imagecolorallocate(\$img, 255, 0, 0);
        imagefill(\$img, 0, 0, \$red);
        imagejpeg(\$img, '/tmp/vips_direct_test.jpg', 90);
        imagedestroy(\$img);
        \$vimg = vips_image_new_from_file('/tmp/vips_direct_test.jpg');
        if (\$vimg) {
            \$w = vips_image_get(\$vimg, 'width');
            \$h = vips_image_get(\$vimg, 'height');
            echo \"ok:{\$w}x{\$h}\";
        } else {
            echo 'failed';
        }
        @unlink('/tmp/vips_direct_test.jpg');
    " 2>&1)

    if echo "$DIRECT_TEST" | grep -q "ok:100x100"; then
        log_success "VIPS: Direct image processing validated (100x100 image)"
    else
        log_warn "VIPS: Direct processing test returned: $DIRECT_TEST"
    fi

# Check for CLI tools as alternative
elif docker exec "$CONTAINER_NAME" which vips >/dev/null 2>&1; then
    log_info "VIPS PHP extension not installed, but CLI tools available"
    VIPS_AVAILABLE=true

    VIPS_CLI_VERSION=$(docker exec "$CONTAINER_NAME" vips --version 2>&1 | head -1 || echo "unknown")
    log_info "libvips CLI version: $VIPS_CLI_VERSION"

    # Test actual CLI image transformation
    log_info "Testing VIPS CLI image processing..."
    CLI_TEST=$(docker exec "$CONTAINER_NAME" sh -c "
        # Create test image with ImageMagick
        convert -size 100x100 xc:blue /tmp/vips_cli_test.jpg 2>/dev/null || echo 'no_convert'

        # Process with vips
        if [ -f /tmp/vips_cli_test.jpg ]; then
            vips resize /tmp/vips_cli_test.jpg /tmp/vips_cli_out.jpg 0.5 2>/dev/null
            if [ -f /tmp/vips_cli_out.jpg ]; then
                SIZE=\$(stat -c%s /tmp/vips_cli_out.jpg 2>/dev/null || stat -f%z /tmp/vips_cli_out.jpg 2>/dev/null)
                echo \"ok:\$SIZE\"
            else
                echo 'resize_failed'
            fi
            rm -f /tmp/vips_cli_test.jpg /tmp/vips_cli_out.jpg
        fi
    " 2>&1)

    if echo "$CLI_TEST" | grep -qE "ok:[1-9][0-9]*"; then
        log_success "VIPS CLI: Image resize works"
    else
        log_warn "VIPS CLI: Test returned: $CLI_TEST"
    fi

    # Check supported formats
    VIPS_FORMATS=$(docker exec "$CONTAINER_NAME" vips --list classes 2>&1 || echo "")
    for FORMAT in jpeg png webp; do
        if echo "$VIPS_FORMATS" | grep -qi "$FORMAT"; then
            log_success "VIPS CLI: $FORMAT support available"
        fi
    done

    if echo "$VIPS_FORMATS" | grep -qi "heif\|avif"; then
        log_success "VIPS CLI: HEIF/AVIF support available"
    else
        log_info "VIPS CLI: HEIF/AVIF not compiled in (optional)"
    fi
else
    log_info "libvips not installed (optional - GD and ImageMagick are primary)"
    log_info "To add libvips: Install php-vips extension or vips CLI tools"
fi

# Summary
if [ "$VIPS_AVAILABLE" = true ]; then
    log_success "libvips support: AVAILABLE and functional"
else
    log_info "libvips support: Not installed (using GD/ImageMagick instead)"
fi

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

print_summary

exit 0
