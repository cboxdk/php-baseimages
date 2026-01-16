#!/bin/sh
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  Cbox PHP CLI Health Check                                              ║
# ║  Validates PHP CLI, Composer, extensions, and Cbox PM                   ║
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

FAILURES=0

# Override check_failed to track failures
_check_failed() {
    FAILURES=$((FAILURES + 1))
    check_failed "$1"
}

# ─────────────────────────────────────────────────────────────────────────────
# Check 1: PHP CLI Executable
# ─────────────────────────────────────────────────────────────────────────────
if php -v >/dev/null 2>&1; then
    check_passed "PHP CLI working"
else
    _check_failed "PHP CLI not working"
    exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
# Check 2: PHP Code Execution
# ─────────────────────────────────────────────────────────────────────────────
if php -r "exit(0);" 2>/dev/null; then
    check_passed "PHP code execution working"
else
    _check_failed "Cannot execute PHP code"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Check 3: OPcache Extension
# ─────────────────────────────────────────────────────────────────────────────
if php -m 2>/dev/null | grep -q "^Zend OPcache$"; then
    check_passed "OPcache extension loaded"
else
    check_warning "OPcache not loaded (recommended for performance)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Check 4: Composer
# ─────────────────────────────────────────────────────────────────────────────
if command -v composer >/dev/null 2>&1; then
    if composer --version --no-ansi >/dev/null 2>&1; then
        check_passed "Composer available"
    else
        check_warning "Composer installed but not responding"
    fi
else
    check_warning "Composer not found"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Check 5: Cbox PM
# ─────────────────────────────────────────────────────────────────────────────
if command -v cbox-pm >/dev/null 2>&1; then
    if cbox-pm --version >/dev/null 2>&1; then
        check_passed "Cbox PM available"
    else
        check_warning "Cbox PM installed but not responding"
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
if [ $FAILURES -gt 0 ]; then
    printf '%bUNHEALTHY%b (%d failures)\n' "$RED" "$NC" "$FAILURES"
    exit 1
else
    printf '%bHEALTHY%b\n' "$GREEN" "$NC"
    exit 0
fi
