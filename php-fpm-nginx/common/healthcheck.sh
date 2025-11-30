#!/bin/sh
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  PHPeek Base Image - Health Check                                         ║
# ║  Queries PHPeek PM health endpoint for comprehensive status               ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
METRICS_PORT="${PHPEEK_PM_METRICS_PORT:-9090}"
NGINX_PORT="${NGINX_HTTP_PORT:-80}"
PHP_FPM_PORT="9000"

FAILURES=0

check_failed() {
    FAILURES=$((FAILURES + 1))
    echo "${RED}✗${NC} $1"
}

check_passed() {
    echo "${GREEN}✓${NC} $1"
}

check_warning() {
    echo "${YELLOW}!${NC} $1"
}

# ─────────────────────────────────────────────────────────────────────────────
# Primary: PHPeek PM Health Endpoint (if metrics enabled)
# ─────────────────────────────────────────────────────────────────────────────
if [ "${PHPEEK_PM_METRICS_ENABLED:-true}" = "true" ]; then
    # Try PHPeek PM metrics endpoint first (most comprehensive)
    if wget -q -O /dev/null --timeout=3 "http://127.0.0.1:${METRICS_PORT}/health" 2>/dev/null; then
        check_passed "PHPeek PM healthy (metrics endpoint)"
    elif curl -sf --max-time 3 "http://127.0.0.1:${METRICS_PORT}/health" >/dev/null 2>&1; then
        check_passed "PHPeek PM healthy (metrics endpoint)"
    else
        check_warning "PHPeek PM metrics endpoint not responding (checking processes directly)"

        # Fallback: Check processes directly
        if pgrep -x phpeek-pm >/dev/null 2>&1; then
            check_passed "PHPeek PM process running"
        else
            check_failed "PHPeek PM not running"
        fi
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# PHP-FPM Check
# ─────────────────────────────────────────────────────────────────────────────
if nc -z 127.0.0.1 ${PHP_FPM_PORT} 2>/dev/null; then
    check_passed "PHP-FPM listening on :${PHP_FPM_PORT}"
else
    check_failed "PHP-FPM not listening on :${PHP_FPM_PORT}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Nginx Check (HTTP health endpoint)
# ─────────────────────────────────────────────────────────────────────────────
if wget -q -O /dev/null --timeout=3 "http://127.0.0.1:${NGINX_PORT}/health" 2>/dev/null; then
    check_passed "Nginx healthy on :${NGINX_PORT}"
elif curl -sf --max-time 3 "http://127.0.0.1:${NGINX_PORT}/health" >/dev/null 2>&1; then
    check_passed "Nginx healthy on :${NGINX_PORT}"
elif nc -z 127.0.0.1 ${NGINX_PORT} 2>/dev/null; then
    check_passed "Nginx listening on :${NGINX_PORT}"
else
    check_failed "Nginx not responding on :${NGINX_PORT}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Optional: Laravel Horizon Check
# ─────────────────────────────────────────────────────────────────────────────
if [ "${PHPEEK_PM_PROCESS_HORIZON_ENABLED:-false}" = "true" ] || [ "${LARAVEL_HORIZON:-false}" = "true" ]; then
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
if [ "${PHPEEK_PM_PROCESS_REVERB_ENABLED:-false}" = "true" ] || [ "${LARAVEL_REVERB:-false}" = "true" ]; then
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
    echo "${RED}UNHEALTHY${NC} ($FAILURES failures)"
    exit 1
else
    echo "${GREEN}HEALTHY${NC}"
    exit 0
fi
