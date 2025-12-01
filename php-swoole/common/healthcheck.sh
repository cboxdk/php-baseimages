#!/bin/sh
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  PHPeek Swoole Health Check                                               ║
# ║  Validates Swoole extension, HTTP server, and PHPeek PM                   ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
# shellcheck shell=sh

set -e

# Source shared library
LIB_PATH="${PHPEEK_LIB_PATH:-/usr/local/lib/phpeek/entrypoint-lib.sh}"
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
OCTANE_PORT="${OCTANE_PORT:-8000}"
FAILURES=0

# Override check_failed to track failures
_check_failed() {
    FAILURES=$((FAILURES + 1))
    check_failed "$1"
}

# ─────────────────────────────────────────────────────────────────────────────
# Check 1: Swoole Extension
# ─────────────────────────────────────────────────────────────────────────────
if php -m 2>/dev/null | grep -qi "^swoole$"; then
    check_passed "Swoole extension loaded"
else
    _check_failed "Swoole extension not loaded"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Check 2: HTTP Server Listening
# ─────────────────────────────────────────────────────────────────────────────
if command -v check_port >/dev/null 2>&1; then
    if check_port ${OCTANE_PORT}; then
        check_passed "Swoole HTTP server listening on :${OCTANE_PORT}"
    else
        _check_failed "Swoole HTTP server not listening on :${OCTANE_PORT}"
    fi
elif nc -z 127.0.0.1 ${OCTANE_PORT} 2>/dev/null; then
    check_passed "Swoole HTTP server listening on :${OCTANE_PORT}"
else
    _check_failed "Swoole HTTP server not listening on :${OCTANE_PORT}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Check 3: HTTP Health Endpoint
# ─────────────────────────────────────────────────────────────────────────────
if command -v check_http >/dev/null 2>&1; then
    if check_http "http://127.0.0.1:${OCTANE_PORT}/health" 3; then
        check_passed "HTTP health endpoint responding"
    else
        check_warning "HTTP /health endpoint not responding (may not be configured)"
    fi
elif wget -q -O /dev/null --timeout=3 "http://127.0.0.1:${OCTANE_PORT}/health" 2>/dev/null; then
    check_passed "HTTP health endpoint responding"
elif curl -sf --max-time 3 "http://127.0.0.1:${OCTANE_PORT}/health" >/dev/null 2>&1; then
    check_passed "HTTP health endpoint responding"
else
    check_warning "HTTP /health endpoint not responding (may not be configured)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Check 4: PHPeek PM
# ─────────────────────────────────────────────────────────────────────────────
if command -v phpeek-pm >/dev/null 2>&1; then
    if phpeek-pm --version >/dev/null 2>&1; then
        check_passed "PHPeek PM available"
    else
        check_warning "PHPeek PM installed but not responding"
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
