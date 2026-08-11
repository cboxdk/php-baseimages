#!/bin/sh
set -e

# ============================================================================
# Cbox PHP-FPM Entrypoint
# ============================================================================
# shellcheck shell=sh

# Source shared library
LIB_PATH="${CBOX_LIB_PATH:-/usr/local/lib/cbox/entrypoint-lib.sh}"
if [ -f "$LIB_PATH" ]; then
    # shellcheck source=/dev/null
    . "$LIB_PATH"
else
    # Fallback: minimal logging if library not found
    log_info()  { echo "[INFO] $1"; }
    log_warn()  { echo "[WARN] $1"; }
    log_error() { echo "[ERROR] $1" >&2; }
    is_rootless() {
        [ "${CBOX_ROOTLESS:-false}" = "true" ]
    }
fi

# Worker sizing, which the pool file expands from the environment.
#
# THE IMAGE DID NOT START WITHOUT THIS. `fpm-pool.conf` is shared with
# php-fpm-nginx, whose entrypoint exports these five variables; this one never
# did, so `pm.max_children = ${PHP_FPM_MAX_CHILDREN}` expanded to nothing and
# php-fpm refused to boot with "pm.max_children must be a positive value" —
# `docker run ghcr.io/cboxdk/php-baseimages/php-fpm:8.4` exited on start, every
# tag, for anybody not setting the variables themselves.
#
# Defaults only. Anything already in the environment wins, including the sizing
# cbox-init derives from the container's memory limit.
resolve_fpm_sizing() {
    export PHP_FPM_MAX_CHILDREN="${PHP_FPM_MAX_CHILDREN:-10}"
    export PHP_FPM_START_SERVERS="${PHP_FPM_START_SERVERS:-2}"
    export PHP_FPM_MIN_SPARE="${PHP_FPM_MIN_SPARE:-1}"
    export PHP_FPM_MAX_SPARE="${PHP_FPM_MAX_SPARE:-6}"
    export PHP_FPM_MAX_REQUESTS="${PHP_FPM_MAX_REQUESTS:-500}"
}

# Write the pool settings that come from the environment.
#
# ONLY open_basedir today, and it has to be here rather than in the static pool:
# PHP-FPM takes the FIRST definition of a `php_admin_value`, so a directive set
# in `zz-custom.conf` can never be overridden by anything. The static pool no
# longer sets it, this writes the single definition, and `PHP_OPEN_BASEDIR` —
# which the image always sets — is therefore an override that works.
#
# The php-fpm-nginx image has its own, larger version of this; this one exists
# because php-fpm is run directly too, and without it that image would have no
# open_basedir at all.
write_env_overrides() {
    # Empty is a value: no definition is written, so the tier runs without any
    # open_basedir. That is how the dev image turns it off, and the only way to
    # turn it off — there is no second directive to fight with.
    [ -n "${PHP_OPEN_BASEDIR:-}" ] || return 0

    local fpm="/usr/local/etc/php-fpm.d/zz-env-overrides.conf"

    printf '%s\n' \
        "; Auto-generated from environment variables" \
        "[www]" \
        "php_admin_value[open_basedir] = ${PHP_OPEN_BASEDIR}" \
        > "$fpm" 2>/dev/null \
        || log_warn "Could not write $fpm (read-only rootfs? mount an emptyDir at /usr/local/etc/php-fpm.d)"
}

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
    # Skip permission setup in rootless mode
    if is_rootless; then
        log_info "Rootless mode - skipping permission setup"
        return 0
    fi

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

# Setup signal handlers (use POSIX signal names without SIG prefix for dash compatibility)
trap graceful_shutdown TERM INT QUIT

# ============================================================================
# Lifecycle Warning (deprecation/preview notices)
# ============================================================================
LIFECYCLE_CHECK="${CBOX_LIB_PATH:-/usr/local/lib/cbox}/lifecycle-check.sh"
if [ -f "$LIFECYCLE_CHECK" ]; then
    # shellcheck source=/dev/null
    . "$LIFECYCLE_CHECK"
    cbox_lifecycle_check
fi

# Display environment information
log_info "Starting PHP-FPM..."
log_info "PHP Version: $(php -r 'echo PHP_VERSION;')"
log_info "OPcache JIT: $(php -r 'echo ini_get("opcache.jit");')"

if [ -n "$XDEBUG_MODE" ]; then
    log_warn "Xdebug is enabled in mode: $XDEBUG_MODE"
    log_warn "This should NOT be used in production!"
fi

# Check Cbox Init
if command -v cbox-init >/dev/null 2>&1; then
    log_info "Cbox Init $(cbox-init --version 2>/dev/null | head -n1)"
fi

# Run startup checks. The environment's pool settings go in BEFORE validation:
# php-fpm -t reads what is on disk, so writing them after would validate a
# configuration the process is not going to run.
resolve_fpm_sizing
write_env_overrides
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
