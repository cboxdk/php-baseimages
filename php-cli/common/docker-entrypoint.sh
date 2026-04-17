#!/bin/sh
set -e

# ============================================================================
# Cbox PHP CLI Entrypoint
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
    validate_boolean() {
        case "$1" in
            true|false|TRUE|FALSE|1|0|yes|no|YES|NO|"") return 0 ;;
            *) log_warn "Invalid boolean value: $1 (using 'false')"; return 1 ;;
        esac
    }
    is_true() {
        case "$1" in
            true|TRUE|1|yes|YES) return 0 ;;
            *) return 1 ;;
        esac
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
# Environment Variable Alias Mapping
# Maps user-friendly LARAVEL_* env vars to CBOX_INIT_PROCESS_*_ENABLED
# ============================================================================
map_env_aliases() {
    [ -n "$LARAVEL_HORIZON" ] && validate_boolean "$LARAVEL_HORIZON" && export CBOX_INIT_PROCESS_HORIZON_ENABLED="$LARAVEL_HORIZON"
    [ -n "$LARAVEL_REVERB" ] && validate_boolean "$LARAVEL_REVERB" && export CBOX_INIT_PROCESS_REVERB_ENABLED="$LARAVEL_REVERB"
    [ -n "$LARAVEL_SCHEDULER" ] && validate_boolean "$LARAVEL_SCHEDULER" && export CBOX_INIT_PROCESS_SCHEDULER_ENABLED="$LARAVEL_SCHEDULER"
    [ -n "$LARAVEL_QUEUE" ] && validate_boolean "$LARAVEL_QUEUE" && export CBOX_INIT_PROCESS_QUEUE_DEFAULT_ENABLED="$LARAVEL_QUEUE"
    [ -n "$LARAVEL_QUEUE_HIGH" ] && validate_boolean "$LARAVEL_QUEUE_HIGH" && export CBOX_INIT_PROCESS_QUEUE_HIGH_ENABLED="$LARAVEL_QUEUE_HIGH"
    [ -n "$CBOX_QUEUE_AUTOSCALER" ] && validate_boolean "$CBOX_QUEUE_AUTOSCALER" && export CBOX_INIT_PROCESS_AUTOSCALER_ENABLED="$CBOX_QUEUE_AUTOSCALER"
    # Backward compatibility
    [ -n "$LARAVEL_SCHEDULER_ENABLED" ] && export CBOX_INIT_PROCESS_SCHEDULER_ENABLED="$LARAVEL_SCHEDULER_ENABLED"
    [ -n "$LARAVEL_AUTO_OPTIMIZE" ] && export LARAVEL_OPTIMIZE_ENABLED="$LARAVEL_AUTO_OPTIMIZE"
    [ -n "$LARAVEL_AUTO_MIGRATE" ] && export LARAVEL_MIGRATE_ENABLED="$LARAVEL_AUTO_MIGRATE"
    return 0
}

# ============================================================================
# Cbox Init Environment Variable Overrides
# The Go binary reads global config from YAML only (no env binding for
# api_enabled, api_port, etc.). This function copies the template config
# to /tmp and patches it with sed so that env vars like
# CBOX_INIT_API_ENABLED actually take effect.
# ============================================================================
apply_cbox_init_env_overrides() {
    src="${CBOX_INIT_CONFIG:-/etc/cbox-init/cbox-init.yaml}"
    dst="/tmp/cbox-init.yaml"

    [ ! -f "$src" ] && return 0

    cp "$src" "$dst"

    # Management API overrides
    [ -n "$CBOX_INIT_API_ENABLED" ] && sed -i "s/^\(\s*\)api_enabled:.*/\1api_enabled: ${CBOX_INIT_API_ENABLED}/" "$dst"
    [ -n "$CBOX_INIT_API_PORT" ] && sed -i "s/^\(\s*\)api_port:.*/\1api_port: ${CBOX_INIT_API_PORT}/" "$dst"
    if [ -n "$CBOX_INIT_API_AUTH" ]; then
        escaped_auth=$(printf '%s\n' "$CBOX_INIT_API_AUTH" | sed 's/[&/\]/\\&/g')
        sed -i "s/^\(\s*\)api_auth:.*/\1api_auth: \"${escaped_auth}\"/" "$dst"
    fi

    # Metrics overrides
    [ -n "$CBOX_INIT_METRICS_ENABLED" ] && sed -i "s/^\(\s*\)metrics_enabled:.*/\1metrics_enabled: ${CBOX_INIT_METRICS_ENABLED}/" "$dst"
    [ -n "$CBOX_INIT_METRICS_PORT" ] && sed -i "s/^\(\s*\)metrics_port:.*/\1metrics_port: ${CBOX_INIT_METRICS_PORT}/" "$dst"

    # Logging overrides
    [ -n "$CBOX_INIT_LOG_LEVEL" ] && sed -i "s/^\(\s*\)log_level:.*/\1log_level: ${CBOX_INIT_LOG_LEVEL}/" "$dst"
    [ -n "$CBOX_INIT_LOG_FORMAT" ] && sed -i "s/^\(\s*\)log_format:.*/\1log_format: ${CBOX_INIT_LOG_FORMAT}/" "$dst"

    # Shutdown timeout override
    [ -n "$CBOX_INIT_SHUTDOWN_TIMEOUT" ] && sed -i "s/^\(\s*\)shutdown_timeout:.*/\1shutdown_timeout: ${CBOX_INIT_SHUTDOWN_TIMEOUT}/" "$dst"

    export CBOX_INIT_CONFIG="$dst"
    return 0
}

# ============================================================================
# Check if any cbox-init process is enabled
# Returns 0 (true) if at least one CBOX_INIT_PROCESS_*_ENABLED is "true"
# ============================================================================
has_cbox_init_processes() {
    is_true "${CBOX_INIT_PROCESS_HORIZON_ENABLED:-false}" && return 0
    is_true "${CBOX_INIT_PROCESS_REVERB_ENABLED:-false}" && return 0
    is_true "${CBOX_INIT_PROCESS_SCHEDULER_ENABLED:-false}" && return 0
    is_true "${CBOX_INIT_PROCESS_QUEUE_DEFAULT_ENABLED:-false}" && return 0
    is_true "${CBOX_INIT_PROCESS_QUEUE_HIGH_ENABLED:-false}" && return 0
    is_true "${CBOX_INIT_PROCESS_AUTOSCALER_ENABLED:-false}" && return 0
    return 1
}

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

# Check Cbox Init
if command -v cbox-init >/dev/null 2>&1; then
    log_info "Cbox Init $(cbox-init --version 2>/dev/null | head -n1)"
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

# ============================================================================
# Command Execution
# ============================================================================

# Map environment aliases before deciding execution path
map_env_aliases

if [ "$1" = "cbox-init" ]; then
    # Explicit cbox-init command: start the process manager
    shift
    CBOX_INIT_CONFIG="${CBOX_INIT_CONFIG:-/etc/cbox-init/cbox-init.yaml}"
    apply_cbox_init_env_overrides
    log_info "Starting Cbox Init process manager"
    log_info "Config: $CBOX_INIT_CONFIG"
    exec /usr/local/bin/cbox-init serve --config "$CBOX_INIT_CONFIG" "$@"
elif [ -z "$1" ] && has_cbox_init_processes; then
    # No command given but cbox-init processes are enabled: auto-start cbox-init
    CBOX_INIT_CONFIG="${CBOX_INIT_CONFIG:-/etc/cbox-init/cbox-init.yaml}"
    apply_cbox_init_env_overrides
    log_info "Cbox Init processes enabled, starting process manager"
    log_info "Config: $CBOX_INIT_CONFIG"
    exec /usr/local/bin/cbox-init serve --config "$CBOX_INIT_CONFIG"
elif [ -z "$1" ]; then
    # No command, no cbox-init processes: interactive shell (existing behavior)
    log_info "No command specified, starting interactive shell"
    exec /bin/sh
else
    # Custom command passed: run it directly (existing behavior)
    log_info "Executing: $*"
    exec "$@"
fi
