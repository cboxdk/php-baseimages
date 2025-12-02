#!/bin/bash
set -e

# ============================================================================
# PHPeek FrankenPHP Image - Docker Entrypoint
# ============================================================================
# FrankenPHP is a modern PHP application server built on Caddy
# Supports HTTP/3, automatic HTTPS, and worker mode for performance
# ============================================================================
# shellcheck shell=bash

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

# Signal handling for graceful shutdown
FRANKENPHP_PID=""

cleanup() {
    log_info "Received shutdown signal, stopping FrankenPHP..."
    if [ -n "$FRANKENPHP_PID" ] && kill -0 "$FRANKENPHP_PID" 2>/dev/null; then
        kill -TERM "$FRANKENPHP_PID" 2>/dev/null
        wait "$FRANKENPHP_PID" 2>/dev/null
    fi
    exit 0
}

# Use POSIX signal names (without SIG prefix) for dash compatibility on Debian
trap cleanup TERM INT QUIT

# Display environment information
print_banner "PHPeek FrankenPHP Image" 2>/dev/null || {
    echo "╔═══════════════════════════════════════════════════════════════════════════╗"
    echo "║  PHPeek FrankenPHP Image                                                  ║"
    echo "╚═══════════════════════════════════════════════════════════════════════════╝"
}

log_info "PHP Version: $(php -r 'echo PHP_VERSION;')"
log_info "FrankenPHP: $(frankenphp version 2>/dev/null | head -n1 || echo 'available')"

# Check PHPeek PM
if command -v phpeek-pm >/dev/null 2>&1; then
    log_info "PHPeek PM $(phpeek-pm --version 2>/dev/null | head -n1)"
fi

# Working directory
WORKDIR="${WORKDIR:-/var/www/html}"
cd "$WORKDIR" 2>/dev/null || cd /var/www/html

# Setup Laravel if detected (use shared function if available)
if [ -f "$WORKDIR/artisan" ]; then
    log_info "Laravel application detected"

    # Fix permissions (use shared function if available)
    if command -v fix_laravel_permissions >/dev/null 2>&1; then
        fix_laravel_permissions "$WORKDIR"
    else
        for dir in storage bootstrap/cache; do
            if [ -d "$WORKDIR/$dir" ]; then
                chown -R www-data:www-data "$WORKDIR/$dir" 2>/dev/null || true
                chmod -R 775 "$WORKDIR/$dir" 2>/dev/null || true
            fi
        done
    fi

    # Run migrations if enabled (use shared function if available)
    if command -v laravel_run_migrations >/dev/null 2>&1; then
        laravel_run_migrations "$WORKDIR"
    elif [ "${LARAVEL_MIGRATE_ENABLED:-false}" = "true" ]; then
        log_info "Running Laravel migrations..."
        php artisan migrate --force --no-interaction 2>&1 || log_warn "Migration failed"
    fi

    # Optimize caches if enabled (use shared function if available)
    if command -v laravel_optimize >/dev/null 2>&1; then
        laravel_optimize "$WORKDIR"
    elif [ "${LARAVEL_OPTIMIZE_ENABLED:-false}" = "true" ]; then
        log_info "Optimizing Laravel caches..."
        php artisan config:cache 2>&1 || true
        php artisan route:cache 2>&1 || true
        php artisan view:cache 2>&1 || true
    fi
fi

# Execute user-provided init scripts (use shared function if available)
if command -v run_init_scripts >/dev/null 2>&1; then
    run_init_scripts /docker-entrypoint-init.d
elif [ -d /docker-entrypoint-init.d ]; then
    for script in /docker-entrypoint-init.d/*.sh; do
        if [ -x "$script" ]; then
            log_info "Running init script: $script"
            "$script" || log_warn "Init script $script failed"
        fi
    done
fi

# Default FrankenPHP command
if [ "$1" = "frankenphp" ] || [ -z "$1" ]; then
    # FrankenPHP configuration
    FRANKENPHP_PORT="${FRANKENPHP_PORT:-80}"
    FRANKENPHP_HTTPS_PORT="${FRANKENPHP_HTTPS_PORT:-443}"
    SERVER_NAME="${SERVER_NAME:-:${FRANKENPHP_PORT}}"

    # Check for Laravel Octane
    if [ -f "$WORKDIR/artisan" ] && php artisan list 2>/dev/null | grep -q "octane:start"; then
        log_info "Starting Laravel Octane with FrankenPHP..."

        OCTANE_WORKERS="${OCTANE_WORKERS:-auto}"
        OCTANE_MAX_REQUESTS="${OCTANE_MAX_REQUESTS:-500}"

        exec php artisan octane:start \
            --server=frankenphp \
            --host=0.0.0.0 \
            --port="$FRANKENPHP_PORT" \
            --workers="$OCTANE_WORKERS" \
            --max-requests="$OCTANE_MAX_REQUESTS"
    else
        # Standalone FrankenPHP server
        log_info "Starting FrankenPHP server..."
        log_info "Server: ${SERVER_NAME}"
        log_info "Document root: ${WORKDIR}/public"

        # Generate Caddyfile if not exists
        if [ ! -f /etc/caddy/Caddyfile ]; then
            cat > /etc/caddy/Caddyfile <<EOF
{
    frankenphp
    order php_server before file_server
}

${SERVER_NAME} {
    root * ${WORKDIR}/public
    encode zstd gzip

    # Health check endpoint
    respond /health 200

    php_server
}
EOF
        fi

        exec frankenphp run --config /etc/caddy/Caddyfile
    fi
else
    log_info "Executing custom command: $*"
    exec "$@"
fi
