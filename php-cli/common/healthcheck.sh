#!/bin/sh
set -e

# Health check script for PHP CLI
# Returns 0 if healthy, 1 if unhealthy

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

FAILURES=0

check_failed() {
    FAILURES=$((FAILURES + 1))
    echo "${RED}✗${NC} $1"
}

check_passed() {
    echo "${GREEN}✓${NC} $1"
}

# Check 1: PHP CLI is executable
if ! php -v >/dev/null 2>&1; then
    check_failed "PHP CLI not working"
    exit 1
else
    check_passed "PHP CLI is working"
fi

# Check 2: Can execute simple PHP code
if ! php -r "exit(0);" 2>/dev/null; then
    check_failed "Cannot execute PHP code"
else
    check_passed "Can execute PHP code"
fi

# Check 3: OPcache is loaded
if php -m 2>/dev/null | grep -q "^Zend OPcache$"; then
    check_passed "OPcache extension loaded"
else
    check_failed "OPcache extension not loaded"
fi

# Check 4: Composer is available
if command -v composer >/dev/null 2>&1; then
    if composer --version --no-ansi >/dev/null 2>&1; then
        check_passed "Composer is available"
    else
        check_failed "Composer not working properly"
    fi
else
    check_failed "Composer not found"
fi

# Check 5: Critical extensions
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
