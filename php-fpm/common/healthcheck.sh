#!/bin/sh
set -e

# Health check script for PHP-FPM
# Returns 0 if healthy, 1 if unhealthy

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FAILURES=0
MAX_FAILURES=3

check_failed() {
    FAILURES=$((FAILURES + 1))
    echo "${RED}✗${NC} $1"
}

check_passed() {
    echo "${GREEN}✓${NC} $1"
}

# Check 1: PHP-FPM process is running
if ! pgrep -x php-fpm >/dev/null 2>&1; then
    check_failed "PHP-FPM process not running"
else
    check_passed "PHP-FPM process is running"
fi

# Check 2: PHP-FPM is listening on port 9000
if ! nc -z localhost 9000 2>/dev/null; then
    check_failed "PHP-FPM not listening on port 9000"
else
    check_passed "PHP-FPM listening on port 9000"
fi

# Check 3: PHP-FPM status page (if enabled)
if command -v cgi-fcgi >/dev/null 2>&1; then
    if SCRIPT_NAME=/ping SCRIPT_FILENAME=/ping REQUEST_METHOD=GET cgi-fcgi -bind -connect 127.0.0.1:9000 2>/dev/null | grep -q "pong"; then
        check_passed "PHP-FPM ping/pong working"
    else
        check_failed "PHP-FPM ping/pong failed"
    fi
fi

# Check 4: OPcache status (should be enabled)
if php -r "exit(function_exists('opcache_get_status') ? 0 : 1);" 2>/dev/null; then
    check_passed "OPcache extension loaded"
else
    check_failed "OPcache extension not loaded"
fi

# Check 5: Critical extensions loaded
required_extensions="json mbstring"
for ext in $required_extensions; do
    if php -m 2>/dev/null | grep -q "^${ext}$"; then
        check_passed "Extension loaded: $ext"
    else
        check_failed "Extension missing: $ext"
    fi
done

# Check PDO separately (uses different naming)
if php -r "exit(class_exists('PDO') ? 0 : 1);" 2>/dev/null; then
    check_passed "Extension loaded: PDO"
else
    check_failed "Extension missing: PDO"
fi

# Check 6: Memory usage (warn if > 80%)
if command -v free >/dev/null 2>&1; then
    memory_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100}')
    if [ "$memory_usage" -lt 80 ]; then
        check_passed "Memory usage: ${memory_usage}%"
    else
        echo "${YELLOW}⚠${NC} High memory usage: ${memory_usage}%"
    fi
fi

# Final verdict
if [ $FAILURES -ge $MAX_FAILURES ]; then
    echo ""
    echo "${RED}Health check FAILED${NC} ($FAILURES failures)"
    exit 1
else
    echo ""
    echo "${GREEN}Health check PASSED${NC}"
    exit 0
fi
