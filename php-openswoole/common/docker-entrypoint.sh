#!/bin/bash
set -e

# ============================================================================
# Cbox OpenSwoole Image - Docker Entrypoint
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Signal handling for graceful shutdown
cleanup() {
    log_info "Received shutdown signal, stopping OpenSwoole server..."
    if [ -n "$OPENSWOOLE_PID" ] && kill -0 "$OPENSWOOLE_PID" 2>/dev/null; then
        kill -TERM "$OPENSWOOLE_PID" 2>/dev/null
        wait "$OPENSWOOLE_PID" 2>/dev/null
    fi
    exit 0
}

# Use POSIX signal names (without SIG prefix) for dash compatibility on Debian
trap cleanup TERM INT QUIT

# Display environment information
echo "╔═══════════════════════════════════════════════════════════════════════════╗"
echo "║  Cbox OpenSwoole Image                                                  ║"
echo "╚═══════════════════════════════════════════════════════════════════════════╝"
log_info "PHP Version: $(php -r 'echo PHP_VERSION;')"
log_info "OpenSwoole Version: $(php -r 'echo OpenSwoole\Util::getVersion();' 2>/dev/null || echo 'unknown')"

# Check Cbox Init
if command -v cbox-init >/dev/null 2>&1; then
    log_info "Cbox Init $(cbox-init --version 2>/dev/null | head -n1)"
fi

# Working directory
WORKDIR="${WORKDIR:-/var/www/html}"
cd "$WORKDIR" 2>/dev/null || cd /var/www/html

# Setup Laravel if detected
if [ -f "$WORKDIR/artisan" ]; then
    log_info "Laravel application detected"

    # Fix permissions
    for dir in storage bootstrap/cache; do
        if [ -d "$WORKDIR/$dir" ]; then
            chown -R www-data:www-data "$WORKDIR/$dir" 2>/dev/null || true
            chmod -R 775 "$WORKDIR/$dir" 2>/dev/null || true
        fi
    done

    # Run migrations if enabled
    if [ "${LARAVEL_MIGRATE_ENABLED:-false}" = "true" ]; then
        log_info "Running Laravel migrations..."
        php artisan migrate --force --no-interaction 2>&1 || log_warn "Migration failed"
    fi

    # Optimize caches if enabled
    if [ "${LARAVEL_OPTIMIZE_ENABLED:-false}" = "true" ]; then
        log_info "Optimizing Laravel caches..."
        php artisan config:cache 2>&1 || true
        php artisan route:cache 2>&1 || true
        php artisan view:cache 2>&1 || true
    fi
fi

# Execute user-provided init scripts
if [ -d /docker-entrypoint-init.d ]; then
    for script in /docker-entrypoint-init.d/*.sh; do
        if [ -x "$script" ]; then
            log_info "Running init script: $script"
            "$script" || log_warn "Init script $script failed"
        fi
    done
fi

# Default OpenSwoole command (Laravel Octane)
if [ "$1" = "openswoole" ] || [ -z "$1" ]; then
    if [ -f "$WORKDIR/artisan" ] && php artisan list 2>/dev/null | grep -q "octane:start"; then
        log_info "Starting Laravel Octane with OpenSwoole..."

        # Octane configuration
        OCTANE_PORT="${OCTANE_PORT:-8000}"
        OCTANE_WORKERS="${OCTANE_WORKERS:-auto}"
        OCTANE_TASK_WORKERS="${OCTANE_TASK_WORKERS:-auto}"
        OCTANE_MAX_REQUESTS="${OCTANE_MAX_REQUESTS:-500}"

        exec php artisan octane:start \
            --server=swoole \
            --host=0.0.0.0 \
            --port="$OCTANE_PORT" \
            --workers="$OCTANE_WORKERS" \
            --task-workers="$OCTANE_TASK_WORKERS" \
            --max-requests="$OCTANE_MAX_REQUESTS"
    else
        log_error "Laravel Octane not found. Please install: composer require laravel/octane"
        log_info "Or provide a custom command to run your OpenSwoole application"
        exit 1
    fi
else
    log_info "Executing custom command: $*"
    exec "$@"
fi
