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

# Validate nginx configuration
validate_config() {
    log_info "Validating nginx configuration..."
    if ! nginx -t 2>&1; then
        log_error "Nginx configuration validation failed!"
        exit 1
    fi
    log_info "Nginx configuration is valid"
}

# Setup proper permissions
setup_permissions() {
    log_info "Setting up permissions..."

    # Ensure nginx cache directories exist with proper permissions
    mkdir -p /var/cache/nginx/client_temp \
             /var/cache/nginx/proxy_temp \
             /var/cache/nginx/fastcgi_temp \
             /var/cache/nginx/uwsgi_temp \
             /var/cache/nginx/scgi_temp

    chown -R www-data:www-data /var/cache/nginx 2>/dev/null || \
    chown -R nginx:nginx /var/cache/nginx 2>/dev/null || true

    # Ensure document root exists
    if [ -d /var/www/html ]; then
        chown -R www-data:www-data /var/www/html 2>/dev/null || \
        chown -R nginx:nginx /var/www/html 2>/dev/null || true
    fi
}

# Test upstream connectivity
test_upstream() {
    log_info "Testing PHP-FPM upstream connectivity..."

    # Extract fastcgi_pass from config
    upstream=$(grep -r "fastcgi_pass" /etc/nginx/ 2>/dev/null | grep -v "#" | head -n1 | awk '{print $2}' | tr -d ';')

    if [ -n "$upstream" ]; then
        host=$(echo "$upstream" | cut -d: -f1)
        port=$(echo "$upstream" | cut -d: -f2)

        if [ "$port" != "$upstream" ]; then
            # Test TCP connection
            if nc -z "$host" "$port" 2>/dev/null; then
                log_info "PHP-FPM upstream is reachable at $upstream"
            else
                log_warn "PHP-FPM upstream not reachable at $upstream (it may not be started yet)"
            fi
        fi
    fi
}

# Handle graceful shutdown
graceful_shutdown() {
    log_info "Received shutdown signal, gracefully stopping nginx..."

    # Send QUIT signal for graceful shutdown
    nginx -s quit 2>/dev/null || true

    # Wait for nginx to finish (max 30 seconds)
    timeout=30
    while [ $timeout -gt 0 ] && pgrep -x nginx >/dev/null 2>&1; do
        sleep 1
        timeout=$((timeout - 1))
    done

    if [ $timeout -eq 0 ]; then
        log_warn "Graceful shutdown timeout, forcing shutdown"
        nginx -s stop 2>/dev/null || true
    else
        log_info "Nginx stopped gracefully"
    fi

    exit 0
}

# Setup signal handlers (use POSIX signal names without SIG prefix for dash compatibility)
trap graceful_shutdown TERM INT QUIT

# Handle reload signal
reload_config() {
    log_info "Received reload signal, reloading nginx configuration..."

    if validate_config; then
        nginx -s reload
        log_info "Nginx configuration reloaded successfully"
    else
        log_error "Configuration validation failed, not reloading"
    fi
}

trap reload_config HUP

# Display environment information
log_info "Starting nginx..."
log_info "Nginx version: $(nginx -v 2>&1 | cut -d: -f2)"

# Run startup checks
validate_config
setup_permissions
test_upstream

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

# Execute command or start nginx
if [ "$1" = "nginx" ] || [ -z "$1" ]; then
    log_info "Starting nginx in foreground mode"
    exec nginx -g "daemon off;"
else
    log_info "Executing custom command: $*"
    exec "$@"
fi
