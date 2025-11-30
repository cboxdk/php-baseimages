#!/bin/sh
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo "${RED}[ERROR]${NC} $1"
}

# Validate PHP-FPM configuration
validate_config() {
    log_info "Validating PHP-FPM configuration..."
    if ! php-fpm -t 2>&1; then
        log_error "PHP-FPM configuration validation failed!"
        exit 1
    fi
    log_info "PHP-FPM configuration is valid"
}

# Check if required extensions are loaded
check_extensions() {
    log_info "Checking required PHP extensions..."

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

    # Ensure PHP session directory exists and is writable
    mkdir -p /var/lib/php/sessions
    chown -R www-data:www-data /var/lib/php/sessions
    chmod 1733 /var/lib/php/sessions
}

# Handle graceful shutdown
graceful_shutdown() {
    log_info "Received shutdown signal, gracefully stopping PHP-FPM..."

    # Send QUIT signal to PHP-FPM for graceful shutdown
    kill -QUIT "$(cat /var/run/php-fpm.pid)" 2>/dev/null || true

    # Wait for PHP-FPM to finish processing requests (max 30 seconds)
    timeout=30
    while [ $timeout -gt 0 ] && kill -0 "$(cat /var/run/php-fpm.pid)" 2>/dev/null; do
        sleep 1
        timeout=$((timeout - 1))
    done

    if [ $timeout -eq 0 ]; then
        log_warn "Graceful shutdown timeout, forcing shutdown"
        kill -TERM "$(cat /var/run/php-fpm.pid)" 2>/dev/null || true
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

# Run startup checks
validate_config
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

# Execute command or start PHP-FPM
if [ "$1" = "php-fpm" ] || [ -z "$1" ]; then
    log_info "Starting PHP-FPM in foreground mode"
    exec php-fpm -F -R
else
    log_info "Executing custom command: $*"
    exec "$@"
fi
