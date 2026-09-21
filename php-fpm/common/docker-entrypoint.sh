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
    # Listen transport: "9000" (TCP, default) or a unix socket path with
    # PHP_FPM_LISTEN=unix. Same contract as the php-fpm-nginx image; here the
    # socket use case is a shared volume with a separate nginx container.
    # tcp stays the DEFAULT here, deliberately diverging from php-fpm-nginx's
    # unix default (v2): this image's whole purpose is FastCGI from OUTSIDE
    # the container (nginx sidecars, separate pods), where a unix socket
    # requires a shared volume nobody mounts by accident.
    if [ "${PHP_FPM_LISTEN:-tcp}" = "unix" ]; then
        sock="${PHP_FPM_SOCKET_PATH:-/run/php/php-fpm.sock}"
        mkdir -p "$(dirname "$sock")" 2>/dev/null || true
        [ "$(id -u)" = "0" ] && chown www-data:www-data "$(dirname "$sock")" 2>/dev/null || true
        export PHP_FPM_LISTEN_ADDR="${PHP_FPM_LISTEN_ADDR:-$sock}"
    else
        export PHP_FPM_LISTEN_ADDR="${PHP_FPM_LISTEN_ADDR:-9000}"
    fi
    export PHP_FPM_MAX_CHILDREN="${PHP_FPM_MAX_CHILDREN:-10}"
    export PHP_FPM_START_SERVERS="${PHP_FPM_START_SERVERS:-2}"
    export PHP_FPM_MIN_SPARE="${PHP_FPM_MIN_SPARE:-1}"
    # Exported (not only shell-defaulted) because the BAKED zz-pm-mode.conf
    # carries ${PHP_FPM_MAX_SPAWN_RATE} for FPM's own env expansion - the
    # read-only-rootfs path where the entrypoint cannot rewrite the drop-in.
    export PHP_FPM_MAX_SPAWN_RATE="${PHP_FPM_MAX_SPAWN_RATE:-32}"
    export PHP_FPM_MAX_SPARE="${PHP_FPM_MAX_SPARE:-6}"
    export PHP_FPM_MAX_REQUESTS="${PHP_FPM_MAX_REQUESTS:-500}"
    export PHP_FPM_LISTEN_BACKLOG="${PHP_FPM_LISTEN_BACKLOG:-511}"
    export PHP_FPM_REQUEST_TERMINATE_TIMEOUT="${PHP_FPM_REQUEST_TERMINATE_TIMEOUT:-60s}"
    export PHP_FPM_REQUEST_SLOWLOG_TIMEOUT="${PHP_FPM_REQUEST_SLOWLOG_TIMEOUT:-5s}"
    export PHP_FPM_MEMORY_LIMIT="${PHP_FPM_MEMORY_LIMIT:-256M}"
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
# WHAT A CONSUMER NEEDS ON TOP, without restating what it does not own.
#
# A platform that mounts something else into the container — a sibling package a
# developer is editing, an extra data directory — has to widen open_basedir to
# reach it, and the only way to do that used to be to set the WHOLE list. So a
# consumer copied this image's default into its own source, and the copy went
# stale the first time the default changed: the paths system-metrics reads were
# added here and the consumer kept overriding them away.
#
# `PHP_OPEN_BASEDIR_EXTRA` is appended instead. One owner for the default, one
# place for the addition.
if [ -n "${PHP_OPEN_BASEDIR_EXTRA:-}" ]; then
    PHP_OPEN_BASEDIR="${PHP_OPEN_BASEDIR:-}${PHP_OPEN_BASEDIR:+:}${PHP_OPEN_BASEDIR_EXTRA}"
    export PHP_OPEN_BASEDIR
fi

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

# opcache.preload - the only supported way to use the FFI this image ships.
#
# It goes in a php.ini drop-in, NOT in the pool conf above. preload is
# PHP_INI_SYSTEM and runs at MINIT, before the master ever reads a pool's
# php_admin_value, so a pool directive would be silently ignored - the worst
# possible failure for a setting whose whole job is to run once at startup.
#
# php-fpm-nginx has its own copy inside apply_php_env_overrides. This one
# exists because php-fpm is also run directly, and without it the variable
# would be documented but dead in exactly the images that a remote-FastCGI
# deployment uses.
write_opcache_preload() {
    [ -n "${PHP_OPCACHE_PRELOAD:-}" ] || return 0

    if [ ! -f "$PHP_OPCACHE_PRELOAD" ]; then
        log_error "PHP_OPCACHE_PRELOAD is set to '$PHP_OPCACHE_PRELOAD' but that file does not exist."
        log_error "Preload runs at startup - fix the path or unset the variable."
        exit 1
    fi

    local ini="/usr/local/etc/php/conf.d/zz-opcache-preload.ini"
    {
        printf '%s\n' "; Auto-generated from PHP_OPCACHE_PRELOAD"
        printf '%s\n' "opcache.preload = ${PHP_OPCACHE_PRELOAD}"
        # PHP refuses to preload as root without preload_user, and says so in
        # terms of the ini rather than of the container. Rootless images are
        # already non-root, where PHP ignores the setting.
        if ! is_rootless; then
            printf '%s\n' "opcache.preload_user = ${PHP_OPCACHE_PRELOAD_USER:-www-data}"
        elif [ -n "${PHP_OPCACHE_PRELOAD_USER:-}" ]; then
            printf '%s\n' "opcache.preload_user = ${PHP_OPCACHE_PRELOAD_USER}"
        fi
    } > "$ini" 2>/dev/null \
        || { log_warn "Could not write $ini (read-only rootfs? mount an emptyDir at /usr/local/etc/php/conf.d)"; return 0; }

    log_info "OPcache preload enabled: $PHP_OPCACHE_PRELOAD"
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
setup_opentelemetry
setup_telemetry_native
resolve_fpm_sizing
export PHP_FPM_PM="${PHP_FPM_PM:-dynamic}"
write_pm_mode_dropin || exit 1
write_env_overrides
write_opcache_preload
validate_fpm_config
# Assert the EFFECTIVE pool listen matches the exported address - tripwire
# against any conf file loading after zz-custom.conf (docker-library/php#1635)
if command -v verify_fpm_listen >/dev/null 2>&1; then
    verify_fpm_listen
fi
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
