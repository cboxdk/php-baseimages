#!/bin/sh
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  Cbox Base Image - Health Check                                         ║
# ║  Queries Cbox Init health endpoint for comprehensive status               ║
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
METRICS_PORT="${CBOX_INIT_METRICS_PORT:-9090}"
# Default to 8080 for rootless containers, 80 for root
if [ "${CBOX_ROOTLESS:-false}" = "true" ]; then
    NGINX_PORT="${NGINX_HTTP_PORT:-8080}"
else
    NGINX_PORT="${NGINX_HTTP_PORT:-80}"
fi
PHP_FPM_PORT="9000"

FAILURES=0

# Override check_failed to track failures
_check_failed() {
    FAILURES=$((FAILURES + 1))
    check_failed "$1"
}

# ─────────────────────────────────────────────────────────────────────────────
# Primary: Cbox Init Health Endpoint (if metrics enabled)
# ─────────────────────────────────────────────────────────────────────────────
if [ "${CBOX_INIT_METRICS_ENABLED:-true}" = "true" ]; then
    if wget -q -O /dev/null --timeout=3 "http://127.0.0.1:${METRICS_PORT}/health" 2>/dev/null; then
        check_passed "Cbox Init healthy (metrics endpoint)"
    elif curl -sf --max-time 3 "http://127.0.0.1:${METRICS_PORT}/health" >/dev/null 2>&1; then
        check_passed "Cbox Init healthy (metrics endpoint)"
    else
        check_warning "Cbox Init metrics endpoint not responding (checking processes directly)"

        # Fallback: Check processes directly
        if pgrep -x cbox-init >/dev/null 2>&1; then
            check_passed "Cbox Init process running"
        else
            _check_failed "Cbox Init not running"
        fi
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# PHP-FPM Check
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
# Nginx Check (HTTP health endpoint)
# ─────────────────────────────────────────────────────────────────────────────
if command -v check_http >/dev/null 2>&1; then
    if check_http "http://127.0.0.1:${NGINX_PORT}/health" 3; then
        check_passed "Nginx healthy on :${NGINX_PORT}"
    elif nc -z 127.0.0.1 ${NGINX_PORT} 2>/dev/null; then
        check_passed "Nginx listening on :${NGINX_PORT}"
    else
        _check_failed "Nginx not responding on :${NGINX_PORT}"
    fi
elif wget -q -O /dev/null --timeout=3 "http://127.0.0.1:${NGINX_PORT}/health" 2>/dev/null; then
    check_passed "Nginx healthy on :${NGINX_PORT}"
elif curl -sf --max-time 3 "http://127.0.0.1:${NGINX_PORT}/health" >/dev/null 2>&1; then
    check_passed "Nginx healthy on :${NGINX_PORT}"
elif nc -z 127.0.0.1 ${NGINX_PORT} 2>/dev/null; then
    check_passed "Nginx listening on :${NGINX_PORT}"
else
    _check_failed "Nginx not responding on :${NGINX_PORT}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Optional: Laravel Horizon Check
# ─────────────────────────────────────────────────────────────────────────────
if [ "${CBOX_INIT_PROCESS_HORIZON_ENABLED:-false}" = "true" ] || [ "${LARAVEL_HORIZON:-false}" = "true" ]; then
    if php /var/www/html/artisan horizon:status 2>/dev/null | grep -q "running"; then
        check_passed "Laravel Horizon running"
    else
        check_warning "Laravel Horizon enabled but not running"
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Optional: Laravel Reverb Check
# ─────────────────────────────────────────────────────────────────────────────
REVERB_PORT="${REVERB_PORT:-8080}"
if [ "${CBOX_INIT_PROCESS_REVERB_ENABLED:-false}" = "true" ] || [ "${LARAVEL_REVERB:-false}" = "true" ]; then
    if nc -z 127.0.0.1 ${REVERB_PORT} 2>/dev/null; then
        check_passed "Laravel Reverb listening on :${REVERB_PORT}"
    else
        check_warning "Laravel Reverb enabled but not listening on :${REVERB_PORT}"
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Final Verdict
# ─────────────────────────────────────────────────────────────────────────────
echo ""
if [ $FAILURES -gt 0 ]; then
    printf '%bUNHEALTHY%b (%d failures)\n' "$RED" "$NC" "$FAILURES"
    exit 1
else
    printf '%bHEALTHY%b\n' "$GREEN" "$NC"
    exit 0
fi
