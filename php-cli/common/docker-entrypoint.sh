#!/bin/sh
set -e

# ============================================================================
# PHPeek PHP CLI Entrypoint
# ============================================================================
# shellcheck shell=sh

# Source shared library
LIB_PATH="${PHPEEK_LIB_PATH:-/usr/local/lib/phpeek/entrypoint-lib.sh}"
if [ -f "$LIB_PATH" ]; then
    # shellcheck source=/dev/null
    . "$LIB_PATH"
else
    # Fallback: minimal logging if library not found
    log_info()  { echo "[INFO] $1"; }
    log_warn()  { echo "[WARN] $1"; }
    log_error() { echo "[ERROR] $1" >&2; }
    is_rootless() {
        [ "${PHPEEK_ROOTLESS:-false}" = "true" ]
    }
fi

# Handle signals for graceful shutdown (use shared or fallback)
if ! command -v _default_cleanup >/dev/null 2>&1; then
    graceful_shutdown() {
        log_info "Received shutdown signal, exiting..."
        exit 0
    }
    # Use POSIX signal names (without SIG prefix) for dash compatibility on Debian
    trap graceful_shutdown TERM INT QUIT
else
    setup_signal_handlers
fi

# ============================================================================
# Lifecycle Warning (deprecation/preview notices)
# ============================================================================
LIFECYCLE_CHECK="${PHPEEK_LIB_PATH:-/usr/local/lib/phpeek}/lifecycle-check.sh"
if [ -f "$LIFECYCLE_CHECK" ]; then
    # shellcheck source=/dev/null
    . "$LIFECYCLE_CHECK"
    phpeek_lifecycle_check
fi

# Display environment information
log_info "PHP CLI Environment"
log_info "PHP Version: $(php -r 'echo PHP_VERSION;')"
log_info "OPcache JIT: $(php -r 'echo ini_get("opcache.jit");')"
log_info "Memory Limit: $(php -r 'echo ini_get("memory_limit");')"

if [ -n "$XDEBUG_MODE" ]; then
    log_warn "Xdebug is enabled in mode: $XDEBUG_MODE"
fi

# Check if composer is available
if command -v composer >/dev/null 2>&1; then
    log_info "Composer $(composer --version --no-ansi 2>/dev/null | head -n1)"
fi

# Check PHPeek PM
if command -v phpeek-pm >/dev/null 2>&1; then
    log_info "PHPeek PM $(phpeek-pm --version 2>/dev/null | head -n1)"
fi

# Setup proper permissions (skip in rootless mode)
if [ -d /var/www/html ] && ! is_rootless; then
    chown -R www-data:www-data /var/www/html 2>/dev/null || true
fi

# Run user-provided init scripts (using shared function if available)
if command -v run_init_scripts >/dev/null 2>&1; then
    run_init_scripts /docker-entrypoint-init.d
elif [ -d /docker-entrypoint-init.d ]; then
    log_info "Running initialization scripts..."
    for script in /docker-entrypoint-init.d/*; do
        if [ -f "$script" ] && [ -x "$script" ]; then
            log_info "Executing: $(basename "$script")"
            "$script"
        fi
    done
fi

# Execute command
if [ -z "$1" ]; then
    log_info "No command specified, starting interactive shell"
    exec /bin/sh
else
    log_info "Executing: $*"
    exec "$@"
fi
