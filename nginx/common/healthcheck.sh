#!/bin/sh
set -e

# Health check script for Nginx
# Returns 0 if healthy, 1 if unhealthy

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FAILURES=0

check_failed() {
    FAILURES=$((FAILURES + 1))
    echo "${RED}✗${NC} $1"
}

check_passed() {
    echo "${GREEN}✓${NC} $1"
}

check_warning() {
    echo "${YELLOW}⚠${NC} $1"
}

# Check 1: Nginx process is running
if ! ps aux | grep -v grep | grep -q "nginx: master"; then
    check_failed "Nginx process not running"
    exit 1
else
    check_passed "Nginx process is running"
fi

# Check 2: Nginx is listening on port 80
if ! nc -z localhost 80 2>/dev/null; then
    check_failed "Nginx not listening on port 80"
else
    check_passed "Nginx listening on port 80"
fi

# Check 3: Health endpoint responds
if command -v curl >/dev/null 2>&1; then
    if curl -sf http://localhost/health >/dev/null 2>&1; then
        check_passed "Health endpoint responding"
    else
        check_warning "Health endpoint not responding (may not be configured)"
    fi
elif command -v wget >/dev/null 2>&1; then
    if wget -q -O /dev/null http://localhost/health 2>/dev/null; then
        check_passed "Health endpoint responding"
    else
        check_warning "Health endpoint not responding (may not be configured)"
    fi
fi

# Check 4: Configuration is valid
if nginx -t 2>&1 | grep -q "successful"; then
    check_passed "Nginx configuration is valid"
else
    check_failed "Nginx configuration has errors"
fi

# Check 5: PHP-FPM upstream connectivity
upstream=$(grep -r "fastcgi_pass" /etc/nginx/ 2>/dev/null | grep -v "#" | head -n1 | awk '{print $2}' | tr -d ';')
if [ -n "$upstream" ]; then
    host=$(echo "$upstream" | cut -d: -f1)
    port=$(echo "$upstream" | cut -d: -f2)

    if [ "$port" != "$upstream" ]; then
        if nc -z "$host" "$port" 2>/dev/null; then
            check_passed "PHP-FPM upstream reachable at $upstream"
        else
            check_failed "PHP-FPM upstream not reachable at $upstream"
        fi
    fi
fi

# Check 6: Worker processes
worker_count=$(ps aux | grep "nginx: worker" | grep -v grep | wc -l)
if [ "$worker_count" -gt 0 ]; then
    check_passed "Nginx worker processes: $worker_count"
else
    check_warning "No nginx worker processes found"
fi

# Check 7: Error log for recent critical errors
if [ -f /var/log/nginx/error.log ]; then
    recent_errors=$(tail -n 50 /var/log/nginx/error.log 2>/dev/null | grep -c "\[emerg\]\|\[alert\]\|\[crit\]" || echo 0)
    if [ "$recent_errors" -gt 0 ]; then
        check_warning "Found $recent_errors recent critical errors in log"
    else
        check_passed "No recent critical errors in log"
    fi
fi

# Final verdict
if [ $FAILURES -gt 0 ]; then
    echo ""
    echo "${RED}Health check FAILED${NC} ($FAILURES failures)"
    exit 1
else
    echo ""
    echo "${GREEN}Health check PASSED${NC}"
    exit 0
fi
