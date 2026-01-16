#!/bin/sh
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  Cbox PHP-FPM Health Check                                              ║
# ║  Validates PHP-FPM process, port, extensions, and Cbox Init               ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
# shellcheck shell=sh

set -e

# Source shared library
LIB_PATH="${CBOX_LIB_PATH:-/usr/local/lib/cbox/entrypoint-lib.sh}"
if [ -f "$LIB_PATH" ]; then
    # shellcheck source=/dev/null
    . "$LIB_PATH"
else
    # Fallback: minimal check functions if library not found
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
    check_passed()  { printf '%b✓%b %s\n' "$GREEN" "$NC" "$1"; }
    check_failed()  { printf '%b✗%b %s\n' "$RED" "$NC" "$1"; }
    check_warning() { printf '%b!%b %s\n' "$YELLOW" "$NC" "$1"; }
fi

# Configuration
PHP_FPM_PORT="${PHP_FPM_PORT:-9000}"
MAX_FAILURES="${HEALTHCHECK_MAX_FAILURES:-3}"

FAILURES=0

# Override check_failed to track failures
_check_failed() {
    FAILURES=$((FAILURES + 1))
    check_failed "$1"
}

# ─────────────────────────────────────────────────────────────────────────────
# Check 1: PHP-FPM Process
# ─────────────────────────────────────────────────────────────────────────────
if pgrep -x php-fpm >/dev/null 2>&1; then
    check_passed "PHP-FPM process running"
else
    _check_failed "PHP-FPM process not running"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Check 2: PHP-FPM Port Listening
# ─────────────────────────────────────────────────────────────────────────────
if command -v check_port >/dev/null 2>&1; then
    if check_port ${PHP_FPM_PORT}; then
        check_passed "PHP-FPM listening on :${PHP_FPM_PORT}"
    else
        _check_failed "PHP-FPM not listening on :${PHP_FPM_PORT}"
    fi
elif nc -z 127.0.0.1 ${PHP_FPM_PORT} 2>/dev/null; then
    check_passed "PHP-FPM listening on :${PHP_FPM_PORT}"
else
    _check_failed "PHP-FPM not listening on :${PHP_FPM_PORT}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Check 3: PHP-FPM Ping/Pong (if cgi-fcgi available)
# ─────────────────────────────────────────────────────────────────────────────
if command -v cgi-fcgi >/dev/null 2>&1; then
    if SCRIPT_NAME=/ping SCRIPT_FILENAME=/ping REQUEST_METHOD=GET \
       cgi-fcgi -bind -connect 127.0.0.1:${PHP_FPM_PORT} 2>/dev/null | grep -q "pong"; then
        check_passed "PHP-FPM ping/pong working"
    else
        check_warning "PHP-FPM ping/pong not responding (may need pm.status_path configured)"
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Check 4: OPcache Extension
# ─────────────────────────────────────────────────────────────────────────────
if php -r "exit(function_exists('opcache_get_status') ? 0 : 1);" 2>/dev/null; then
    check_passed "OPcache extension loaded"
else
    check_warning "OPcache not loaded (recommended for production)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Check 5: Cbox Init
# ─────────────────────────────────────────────────────────────────────────────
if command -v cbox-init >/dev/null 2>&1; then
    if cbox-init --version >/dev/null 2>&1; then
        check_passed "Cbox Init available"
    else
        check_warning "Cbox Init installed but not responding"
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Check 6: Critical PHP Extensions
# ─────────────────────────────────────────────────────────────────────────────
required_extensions="json mbstring"
for ext in $required_extensions; do
    if php -m 2>/dev/null | grep -qi "^${ext}$"; then
        check_passed "Extension: ${ext}"
    else
        _check_failed "Extension missing: ${ext}"
    fi
done

# Check PDO separately (class-based check)
if php -r "exit(class_exists('PDO') ? 0 : 1);" 2>/dev/null; then
    check_passed "Extension: PDO"
else
    _check_failed "Extension missing: PDO"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Final Verdict
# ─────────────────────────────────────────────────────────────────────────────
echo ""
if [ $FAILURES -ge $MAX_FAILURES ]; then
    printf '%bUNHEALTHY%b (%d failures, max: %d)\n' "$RED" "$NC" "$FAILURES" "$MAX_FAILURES"
    exit 1
else
    if [ $FAILURES -gt 0 ]; then
        printf '%bHEALTHY%b (with %d warning(s))\n' "$YELLOW" "$NC" "$FAILURES"
    else
        printf '%bHEALTHY%b\n' "$GREEN" "$NC"
    fi
    exit 0
fi
