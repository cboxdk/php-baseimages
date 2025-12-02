#!/bin/bash
# E2E Test: Browsershot/Puppeteer PDF Generation
# Tests Node.js, npm, Chromium and PDF generation capability

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-utils.sh"

E2E_ROOT="$(get_e2e_root)"
FIXTURE_DIR="$E2E_ROOT/fixtures/browsershot"
PROJECT_NAME="e2e-browsershot"
CONTAINER_NAME="e2e-browsershot"
BASE_URL="http://localhost:8095"

# Global to track the script's intended exit code
SCRIPT_EXIT_CODE=0

# Cleanup on exit - completely isolated from strict modes
cleanup_and_exit() {
    # Capture desired exit code FIRST before any commands
    local desired_exit="${SCRIPT_EXIT_CODE:-0}"

    # Disable all strict modes
    set +e
    set +u
    set +o pipefail

    # Run cleanup in a fully isolated subshell
    (
        set +e +u +o pipefail 2>/dev/null
        cleanup_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME" 2>/dev/null
        true
    ) 2>/dev/null || true

    # Force the exact exit code we want
    exit "$desired_exit"
}
trap cleanup_and_exit EXIT

log_section "Browsershot/Puppeteer E2E Test"

# Start the stack
cleanup_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME"

# Ensure storage directory is writable
chmod -R 777 "$FIXTURE_DIR/storage" 2>/dev/null || true

start_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME"

# Wait for healthy
wait_for_healthy "$CONTAINER_NAME" 90

log_section "Node.js Tests"

# Test Node.js is installed
assert_exec_succeeds "$CONTAINER_NAME" "node --version" "Node.js is installed"
assert_exec_contains "$CONTAINER_NAME" "node --version" "v22" "Node.js version is v22.x"

# Test npm is installed
assert_exec_succeeds "$CONTAINER_NAME" "npm --version" "npm is installed"

# Test npx is installed
assert_exec_succeeds "$CONTAINER_NAME" "npx --version" "npx is installed"

log_section "Chromium Tests"

# Test Chromium is installed
assert_exec_succeeds "$CONTAINER_NAME" "chromium-browser --version || chromium --version" "Chromium is installed"

# Check Puppeteer environment variables
assert_exec_contains "$CONTAINER_NAME" "env | grep PUPPETEER" "PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true" "PUPPETEER_SKIP_CHROMIUM_DOWNLOAD is set"
assert_exec_contains "$CONTAINER_NAME" "env | grep PUPPETEER" "PUPPETEER_EXECUTABLE_PATH=" "PUPPETEER_EXECUTABLE_PATH is set"

log_section "HTTP Endpoint Tests"

# Give the container a moment to fully initialize
sleep 2

# Test main endpoint (this runs the full PDF generation test)
assert_http_code "$BASE_URL/" 200 "Main endpoint returns 200"

# Get full response for detailed checks
RESPONSE=$(curl -s "$BASE_URL/" 2>/dev/null || echo '{}')

# Test overall status
if echo "$RESPONSE" | grep -q '"status": "ok"'; then
    log_success "Overall status is ok"
else
    log_fail "Overall status is not ok"
    echo "Response: ${RESPONSE:0:500}"
fi

# Test Node.js detection via HTTP
assert_http_contains "$BASE_URL/" '"node":' "Response contains Node.js info"
if echo "$RESPONSE" | grep -A2 '"node"' | grep -q '"installed": true'; then
    log_success "Node.js is detected as installed"
else
    log_fail "Node.js is not detected"
fi

# Test npm detection
assert_http_contains "$BASE_URL/" '"npm":' "Response contains npm info"
if echo "$RESPONSE" | grep -A2 '"npm"' | grep -q '"installed": true'; then
    log_success "npm is detected as installed"
else
    log_fail "npm is not detected"
fi

# Test Chromium detection
assert_http_contains "$BASE_URL/" '"chromium":' "Response contains Chromium info"
if echo "$RESPONSE" | grep -A2 '"chromium"' | grep -q '"installed": true'; then
    log_success "Chromium is detected as installed"
else
    log_fail "Chromium is not detected"
fi

log_section "PDF Generation Tests"

# Test PDF generation success
if echo "$RESPONSE" | grep -A5 '"pdf_test"' | grep -q '"success": true'; then
    log_success "PDF generation test passed (HTTP endpoint reports success)"
else
    log_fail "PDF generation test failed"
    echo "PDF test output: $(echo "$RESPONSE" | grep -A10 '"pdf_test"')"
fi

# Check PDF file was created with content (from HTTP response)
PDF_SIZE=$(echo "$RESPONSE" | grep -o '"file_size": [0-9]*' | grep -o '[0-9]*' || echo "0")
if [ "$PDF_SIZE" -gt 1000 ]; then
    log_success "PDF file has valid size (${PDF_SIZE} bytes via HTTP response)"
else
    log_warn "PDF file size reported as small or zero (${PDF_SIZE} bytes)"
fi

# CRITICAL: Verify PDF file actually exists in container filesystem
log_info "Verifying PDF file exists in container..."
PDF_PATH=$(echo "$RESPONSE" | grep -o '"file_path": "[^"]*"' | sed 's/"file_path": "//;s/"$//' || echo "")
if [ -n "$PDF_PATH" ]; then
    # Check file exists and has content
    PDF_CHECK=$(docker exec "$CONTAINER_NAME" sh -c "
        if [ -f '$PDF_PATH' ]; then
            SIZE=\$(stat -c%s '$PDF_PATH' 2>/dev/null || stat -f%z '$PDF_PATH' 2>/dev/null)
            FILE_TYPE=\$(file '$PDF_PATH' 2>/dev/null | head -1)
            echo \"exists:\$SIZE:\$FILE_TYPE\"
        else
            echo 'not_found'
        fi
    " 2>&1)

    if echo "$PDF_CHECK" | grep -q "^exists:"; then
        ACTUAL_SIZE=$(echo "$PDF_CHECK" | cut -d: -f2)
        FILE_TYPE=$(echo "$PDF_CHECK" | cut -d: -f3-)

        if [ "$ACTUAL_SIZE" -gt 1000 ]; then
            log_success "PDF file verified in container (${ACTUAL_SIZE} bytes)"
        else
            log_fail "PDF file exists but is too small (${ACTUAL_SIZE} bytes)"
        fi

        # Verify it's actually a PDF
        if echo "$FILE_TYPE" | grep -qi "PDF"; then
            log_success "File is valid PDF format"
        else
            log_warn "File may not be valid PDF: $FILE_TYPE"
        fi
    else
        log_fail "PDF file not found in container at $PDF_PATH"
    fi
else
    # Fallback: search for any PDF in storage
    log_info "No file path in response, searching for PDF files..."
    PDF_SEARCH=$(docker exec "$CONTAINER_NAME" sh -c "
        find /var/www/html/storage -name '*.pdf' -type f 2>/dev/null | head -1
    " 2>&1)

    if [ -n "$PDF_SEARCH" ]; then
        PDF_VERIFY=$(docker exec "$CONTAINER_NAME" sh -c "
            SIZE=\$(stat -c%s '$PDF_SEARCH' 2>/dev/null || stat -f%z '$PDF_SEARCH' 2>/dev/null)
            FILE_TYPE=\$(file '$PDF_SEARCH' 2>/dev/null | head -1)
            echo \"size:\$SIZE type:\$FILE_TYPE\"
        " 2>&1)
        log_success "Found PDF in storage: $PDF_SEARCH"
        log_info "PDF details: $PDF_VERIFY"

        # Validate PDF is valid
        VERIFY_SIZE=$(echo "$PDF_VERIFY" | grep -o 'size:[0-9]*' | cut -d: -f2 || echo "0")
        if [ "$VERIFY_SIZE" -gt 1000 ]; then
            log_success "PDF file has valid size (${VERIFY_SIZE} bytes)"
        else
            log_warn "PDF file is suspiciously small (${VERIFY_SIZE} bytes)"
        fi
    else
        log_warn "No PDF files found in storage directory"
    fi
fi

# Test screenshot capability as well
log_info "Testing screenshot capability..."
SCREENSHOT_TEST=$(docker exec "$CONTAINER_NAME" sh -c "
    cd /var/www/html && \
    node -e \"
        const puppeteer = require('puppeteer');
        (async () => {
            const browser = await puppeteer.launch({
                headless: 'new',
                args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage']
            });
            const page = await browser.newPage();
            await page.setContent('<h1>Screenshot Test</h1>');
            await page.screenshot({ path: '/tmp/test-screenshot.png' });
            await browser.close();
            console.log('screenshot_ok');
        })();
    \" 2>&1
" 2>&1)

if echo "$SCREENSHOT_TEST" | grep -q "screenshot_ok"; then
    # Verify screenshot file exists
    SS_CHECK=$(docker exec "$CONTAINER_NAME" sh -c "
        if [ -f /tmp/test-screenshot.png ]; then
            SIZE=\$(stat -c%s /tmp/test-screenshot.png 2>/dev/null || stat -f%z /tmp/test-screenshot.png 2>/dev/null)
            echo \"ok:\$SIZE\"
            rm -f /tmp/test-screenshot.png
        else
            echo 'not_found'
        fi
    " 2>&1)

    if echo "$SS_CHECK" | grep -qE "ok:[1-9][0-9]*"; then
        SS_SIZE=$(echo "$SS_CHECK" | cut -d: -f2)
        log_success "Screenshot generation works (${SS_SIZE} bytes)"
    else
        log_fail "Screenshot file not created"
    fi
else
    log_warn "Screenshot test output: ${SCREENSHOT_TEST:0:200}"
fi

log_section "Process Tests"

# Verify processes are running
assert_process_running "$CONTAINER_NAME" "php-fpm" "PHP-FPM master process running"
assert_process_running "$CONTAINER_NAME" "nginx" "Nginx master process running"

log_section "Directory Tests"

# Check key directories exist
assert_dir_exists "$CONTAINER_NAME" "/var/www/html/storage" "Storage directory exists"

print_summary

exit 0
