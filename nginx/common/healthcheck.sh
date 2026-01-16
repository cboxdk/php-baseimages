#!/bin/sh
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  Cbox Nginx Health Check                                                ║
# ║  Validates Nginx process, ports, configuration, and upstream connectivity ║
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
NGINX_PORT="${NGINX_HTTP_PORT:-80}"
FAILURES=0

# Override check_failed to track failures
_check_failed() {
    FAILURES=$((FAILURES + 1))
    check_failed "$1"
}

# ─────────────────────────────────────────────────────────────────────────────
# Check 1: Nginx Process
# ─────────────────────────────────────────────────────────────────────────────
if ps aux | grep -v grep | grep -q "nginx: master"; then
    check_passed "Nginx master process running"
else
    _check_failed "Nginx master process not running"
    exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
# Check 2: Nginx Port Listening
# ─────────────────────────────────────────────────────────────────────────────
if command -v check_port >/dev/null 2>&1; then
    if check_port ${NGINX_PORT}; then
        check_passed "Nginx listening on :${NGINX_PORT}"
    else
        _check_failed "Nginx not listening on :${NGINX_PORT}"
    fi
elif nc -z 127.0.0.1 ${NGINX_PORT} 2>/dev/null; then
    check_passed "Nginx listening on :${NGINX_PORT}"
else
    _check_failed "Nginx not listening on :${NGINX_PORT}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Check 3: Health Endpoint
# ─────────────────────────────────────────────────────────────────────────────
if command -v check_http >/dev/null 2>&1; then
    if check_http "http://127.0.0.1:${NGINX_PORT}/health" 3; then
        check_passed "Health endpoint responding"
    else
        check_warning "Health endpoint not responding (may not be configured)"
    fi
elif curl -sf --max-time 3 "http://127.0.0.1:${NGINX_PORT}/health" >/dev/null 2>&1; then
    check_passed "Health endpoint responding"
elif wget -q -O /dev/null --timeout=3 "http://127.0.0.1:${NGINX_PORT}/health" 2>/dev/null; then
    check_passed "Health endpoint responding"
else
    check_warning "Health endpoint not responding (may not be configured)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Check 4: Configuration Valid
# ─────────────────────────────────────────────────────────────────────────────
if nginx -t 2>&1 | grep -q "successful"; then
    check_passed "Nginx configuration valid"
else
    _check_failed "Nginx configuration has errors"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Check 5: PHP-FPM Upstream Connectivity
# ─────────────────────────────────────────────────────────────────────────────
upstream=$(grep -r "fastcgi_pass" /etc/nginx/ 2>/dev/null | grep -v "#" | head -n1 | awk '{print $2}' | tr -d ';')
if [ -n "$upstream" ]; then
    host=$(echo "$upstream" | cut -d: -f1)
    port=$(echo "$upstream" | cut -d: -f2)

    if [ "$port" != "$upstream" ]; then
        if nc -z "$host" "$port" 2>/dev/null; then
            check_passed "PHP-FPM upstream reachable at ${upstream}"
        else
            _check_failed "PHP-FPM upstream not reachable at ${upstream}"
        fi
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Check 6: Worker Processes
# ─────────────────────────────────────────────────────────────────────────────
worker_count=$(ps aux | grep "nginx: worker" | grep -v grep | wc -l)
if [ "$worker_count" -gt 0 ]; then
    check_passed "Nginx workers: ${worker_count}"
else
    check_warning "No nginx worker processes found"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Check 7: Error Log
# ─────────────────────────────────────────────────────────────────────────────
if [ -f /var/log/nginx/error.log ]; then
    recent_errors=$(tail -n 50 /var/log/nginx/error.log 2>/dev/null | grep -c "\[emerg\]\|\[alert\]\|\[crit\]" || echo 0)
    if [ "$recent_errors" -gt 0 ]; then
        check_warning "Found ${recent_errors} critical errors in recent log"
    else
        check_passed "No critical errors in recent log"
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
