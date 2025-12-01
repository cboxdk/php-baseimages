#!/bin/sh
set -e

# ============================================================================
# PHPeek PHP-FPM Entrypoint
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
fi

# Validate PHP-FPM configuration
validate_fpm_config() {
    log_info "Validating PHP-FPM configuration..."
    if ! php-fpm -t 2>&1; then
        log_error "PHP-FPM configuration validation failed!"
        exit 1
    fi
    log_info "PHP-FPM configuration is valid"
}

# Setup proper permissions
setup_fpm_permissions() {
    log_info "Setting up permissions..."

    # Ensure www-data can write to necessary directories
    if [ -d /var/www/html ]; then
        chown -R www-data:www-data /var/www/html 2>/dev/null || true
    fi

    # Ensure PHP session directory exists and is writable
    mkdir -p /var/lib/php/sessions
    chown -R www-data:www-data /var/lib/php/sessions
    chmod 1733 /var/lib/php/sessions
}

# Handle graceful shutdown
graceful_shutdown() {
    log_info "Received shutdown signal, gracefully stopping PHP-FPM..."

    # Send QUIT signal to PHP-FPM for graceful shutdown
    kill -QUIT "$(cat /var/run/php-fpm.pid 2>/dev/null)" 2>/dev/null || true

    # Wait for PHP-FPM to finish processing requests (max 30 seconds)
    timeout=30
    while [ $timeout -gt 0 ] && [ -f /var/run/php-fpm.pid ] && kill -0 "$(cat /var/run/php-fpm.pid 2>/dev/null)" 2>/dev/null; do
        sleep 1
        timeout=$((timeout - 1))
    done

    if [ $timeout -eq 0 ]; then
        log_warn "Graceful shutdown timeout, forcing shutdown"
        kill -TERM "$(cat /var/run/php-fpm.pid 2>/dev/null)" 2>/dev/null || true
    else
        log_info "PHP-FPM stopped gracefully"
    fi

    exit 0
}

# Setup signal handlers
trap graceful_shutdown SIGTERM SIGINT SIGQUIT

# Display environment information
log_info "Starting PHP-FPM..."
log_info "PHP Version: $(php -r 'echo PHP_VERSION;')"
log_info "OPcache JIT: $(php -r 'echo ini_get("opcache.jit");')"

if [ -n "$XDEBUG_MODE" ]; then
    log_warn "Xdebug is enabled in mode: $XDEBUG_MODE"
    log_warn "This should NOT be used in production!"
fi

# Check PHPeek PM
if command -v phpeek-pm >/dev/null 2>&1; then
    log_info "PHPeek PM $(phpeek-pm --version 2>/dev/null | head -n1)"
fi

# Run startup checks
validate_fpm_config
setup_fpm_permissions

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

# Execute command or start PHP-FPM
if [ "$1" = "php-fpm" ] || [ -z "$1" ]; then
    log_info "Starting PHP-FPM in foreground mode"
    exec php-fpm -F -R
else
    log_info "Executing custom command: $*"
    exec "$@"
fi
