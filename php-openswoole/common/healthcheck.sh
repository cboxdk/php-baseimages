#!/bin/sh
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  Cbox OpenSwoole Health Check                                           ║
# ║  Validates OpenSwoole extension, HTTP server, and Cbox PM               ║
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
OCTANE_PORT="${OCTANE_PORT:-8000}"
FAILURES=0

# Override check_failed to track failures
_check_failed() {
    FAILURES=$((FAILURES + 1))
    check_failed "$1"
}

# ─────────────────────────────────────────────────────────────────────────────
# Check 1: OpenSwoole Extension
# ─────────────────────────────────────────────────────────────────────────────
if php -m 2>/dev/null | grep -qi "^openswoole$"; then
    check_passed "OpenSwoole extension loaded"
else
    _check_failed "OpenSwoole extension not loaded"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Check 2: HTTP Server Listening
# ─────────────────────────────────────────────────────────────────────────────
if command -v check_port >/dev/null 2>&1; then
    if check_port ${OCTANE_PORT}; then
        check_passed "OpenSwoole HTTP server listening on :${OCTANE_PORT}"
    else
        _check_failed "OpenSwoole HTTP server not listening on :${OCTANE_PORT}"
    fi
elif nc -z 127.0.0.1 ${OCTANE_PORT} 2>/dev/null; then
    check_passed "OpenSwoole HTTP server listening on :${OCTANE_PORT}"
else
    _check_failed "OpenSwoole HTTP server not listening on :${OCTANE_PORT}"
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
# Check 4: Cbox PM
# ─────────────────────────────────────────────────────────────────────────────
if command -v cbox-init >/dev/null 2>&1; then
    if cbox-init --version >/dev/null 2>&1; then
        check_passed "Cbox PM available"
    else
        check_warning "Cbox PM installed but not responding"
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
