#!/bin/sh
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo "${RED}[ERROR]${NC} $1"
}

# Check if required extensions are loaded
check_extensions() {
    log_info "Checking PHP extensions..."

    required_extensions="pdo_mysql pdo_pgsql redis"
    missing_extensions=""

    for ext in $required_extensions; do
        if ! php -m | grep -q "^${ext}$"; then
            missing_extensions="${missing_extensions} ${ext}"
        fi
    done

    if [ -n "$missing_extensions" ]; then
        log_warn "Missing recommended extensions:${missing_extensions}"
    else
        log_info "All required extensions are loaded"
    fi
}

# Setup proper permissions
setup_permissions() {
    log_info "Setting up permissions..."

    # Ensure www-data can write to necessary directories
    if [ -d /var/www/html ]; then
        chown -R www-data:www-data /var/www/html 2>/dev/null || true
    fi
}

# Handle signals for graceful shutdown
graceful_shutdown() {
    log_info "Received shutdown signal, exiting..."
    exit 0
}

trap graceful_shutdown SIGTERM SIGINT SIGQUIT

# Display environment information
log_info "PHP CLI Environment"
log_info "PHP Version: $(php -r 'echo PHP_VERSION;')"
log_info "OPcache JIT: $(php -r 'echo ini_get("opcache.jit");')"
log_info "Memory Limit: $(php -r 'echo ini_get("memory_limit");')"

if [ -n "$XDEBUG_MODE" ]; then
    log_warn "Xdebug is enabled in mode: $XDEBUG_MODE"
fi

# Run startup checks
check_extensions
setup_permissions

# Allow custom initialization scripts
if [ -d /docker-entrypoint-init.d ]; then
    log_info "Running initialization scripts..."
    for script in /docker-entrypoint-init.d/*; do
        if [ -f "$script" ] && [ -x "$script" ]; then
            log_info "Executing: $(basename "$script")"
            "$script"
        fi
    done
fi

# Check if composer is available
if command -v composer >/dev/null 2>&1; then
    log_info "Composer $(composer --version --no-ansi 2>/dev/null | head -n1)"
fi

# Execute command
if [ -z "$1" ]; then
    log_info "No command specified, starting interactive shell"
    exec /bin/sh
else
    log_info "Executing: $*"
    exec "$@"
fi
