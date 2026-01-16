#!/bin/sh
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  Cbox Base Images - Shared Entrypoint Library                           ║
# ║  Common functions used across all entrypoint and healthcheck scripts      ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
# shellcheck shell=sh

# Prevent double-sourcing
[ -n "$_CBOX_LIB_LOADED" ] && return 0
_CBOX_LIB_LOADED=1

###########################################
# Logging Functions
###########################################
# Colors (only if terminal supports it)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

log_info()  { printf '%b[INFO]%b %s\n' "$GREEN" "$NC" "$1"; }
log_warn()  { printf '%b[WARN]%b %s\n' "$YELLOW" "$NC" "$1"; }
log_error() { printf '%b[ERROR]%b %s\n' "$RED" "$NC" "$1" >&2; }
log_debug() { [ "${DEBUG:-false}" = "true" ] && printf '%b[DEBUG]%b %s\n' "$BLUE" "$NC" "$1"; }

# Healthcheck-style output
check_passed()  { printf '%b✓%b %s\n' "$GREEN" "$NC" "$1"; }
check_failed()  { printf '%b✗%b %s\n' "$RED" "$NC" "$1"; }
check_warning() { printf '%b!%b %s\n' "$YELLOW" "$NC" "$1"; }

###########################################
# Input Validation (Security)
###########################################
validate_path() {
    local path="$1"
    local allowed_prefix="$2"

    # Ensure path doesn't contain path traversal
    case "$path" in
        *..*) log_error "Path traversal detected: $path"; return 1 ;;
    esac

    # Ensure path starts with allowed prefix
    case "$path" in
        "${allowed_prefix}"*) printf '%s' "$path"; return 0 ;;
        *) log_error "Invalid path (must start with $allowed_prefix): $path"; return 1 ;;
    esac
}

validate_boolean() {
    case "$1" in
        true|false|TRUE|FALSE|1|0|yes|no|YES|NO|"") return 0 ;;
        *) log_warn "Invalid boolean value: $1 (using 'false')"; return 1 ;;
    esac
}

validate_numeric() {
    case "$1" in
        ''|*[!0-9]*) log_error "Value must be numeric: $1"; return 1 ;;
        *) return 0 ;;
    esac
}

is_true() {
    case "$1" in
        true|TRUE|1|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

is_rootless() {
    [ "${CBOX_ROOTLESS:-false}" = "true" ]
}

###########################################
# PHP Detection
###########################################
detect_php_version() {
    if command -v php >/dev/null 2>&1; then
        php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;"
    else
        echo "8.3"  # Fallback
    fi
}

###########################################
# Framework Detection
###########################################
detect_framework() {
    local workdir="${1:-/var/www/html}"

    if [ -f "$workdir/artisan" ]; then
        echo "laravel"
    elif [ -f "$workdir/bin/console" ] && [ -f "$workdir/symfony.lock" ]; then
        echo "symfony"
    elif [ -f "$workdir/wp-config.php" ] || [ -f "$workdir/wp-config-sample.php" ]; then
        echo "wordpress"
    else
        echo "generic"
    fi
}

###########################################
# Directory & Permission Setup
###########################################
ensure_dir() {
    local dir="$1"
    local owner="${2:-www-data}"
    local perms="${3:-755}"

    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" 2>/dev/null || return 1
    fi
    chown "$owner:$owner" "$dir" 2>/dev/null || true
    chmod "$perms" "$dir" 2>/dev/null || true
}

fix_laravel_permissions() {
    local workdir="${1:-/var/www/html}"
    local owner="${2:-www-data}"

    [ ! -f "$workdir/artisan" ] && return 0

    log_info "Fixing Laravel directory permissions..."
    for dir in storage bootstrap/cache; do
        if [ -d "$workdir/$dir" ]; then
            chown -R "$owner:$owner" "$workdir/$dir" 2>/dev/null || true
            chmod -R 775 "$workdir/$dir" 2>/dev/null || true
        fi
    done
}

fix_symfony_permissions() {
    local workdir="${1:-/var/www/html}"
    local owner="${2:-www-data}"

    [ ! -f "$workdir/bin/console" ] && return 0

    log_info "Fixing Symfony directory permissions..."
    for dir in var/cache var/log; do
        if [ -d "$workdir/$dir" ]; then
            chown -R "$owner:$owner" "$workdir/$dir" 2>/dev/null || true
            chmod -R 775 "$workdir/$dir" 2>/dev/null || true
        fi
    done
}

###########################################
# Init Scripts Execution
###########################################
run_init_scripts() {
    local init_dir="${1:-/docker-entrypoint-init.d}"

    [ ! -d "$init_dir" ] && return 0

    for script in "$init_dir"/*.sh; do
        [ ! -f "$script" ] && continue
        if [ -x "$script" ]; then
            log_info "Running init script: $(basename "$script")"
            "$script" || log_warn "Init script $(basename "$script") failed"
        fi
    done
}

###########################################
# Service Checks
###########################################
wait_for_port() {
    local host="$1"
    local port="$2"
    local timeout="${3:-30}"
    local count=0

    log_info "Waiting for $host:$port..."
    while [ $count -lt "$timeout" ]; do
        if nc -z "$host" "$port" 2>/dev/null; then
            log_info "$host:$port is available"
            return 0
        fi
        sleep 1
        count=$((count + 1))
    done

    log_error "Timeout waiting for $host:$port"
    return 1
}

check_port() {
    nc -z 127.0.0.1 "$1" 2>/dev/null
}

check_http() {
    local url="$1"
    local timeout="${2:-3}"

    if command -v wget >/dev/null 2>&1; then
        wget -q -O /dev/null --timeout="$timeout" "$url" 2>/dev/null
    elif command -v curl >/dev/null 2>&1; then
        curl -sf --max-time "$timeout" "$url" >/dev/null 2>&1
    else
        return 1
    fi
}

###########################################
# Signal Handling Templates
###########################################
# Usage: setup_signal_handlers <cleanup_function>
setup_signal_handlers() {
    local cleanup_fn="${1:-_default_cleanup}"
    # Use POSIX signal names (without SIG prefix) for dash compatibility on Debian
    trap "$cleanup_fn" TERM INT QUIT
}

_default_cleanup() {
    log_info "Received shutdown signal, exiting..."
    exit 0
}

###########################################
# Cbox PM Validation
###########################################
validate_cbox_pm() {
    local config="${CBOX_PM_CONFIG:-/etc/cbox-pm/cbox-pm.yaml}"

    if ! command -v cbox-pm >/dev/null 2>&1; then
        log_error "Cbox PM binary not found"
        return 1
    fi

    if [ ! -f "$config" ]; then
        log_warn "Cbox PM config not found at $config, generating default..."
        if ! cbox-pm scaffold --output "$config" 2>/dev/null; then
            log_error "Could not generate Cbox PM config"
            return 1
        fi
    fi

    if ! cbox-pm check-config --config "$config" >/dev/null 2>&1; then
        log_error "Cbox PM config validation failed"
        return 1
    fi

    log_info "Cbox PM validated successfully"
    return 0
}

###########################################
# PUID/PGID User Mapping
###########################################
setup_user_permissions() {
    local target_uid="${PUID:-}"
    local target_gid="${PGID:-}"
    local app_user="${APP_USER:-www-data}"
    local app_group="${APP_GROUP:-www-data}"

    # Skip if no PUID/PGID specified
    [ -z "$target_uid" ] && [ -z "$target_gid" ] && return 0

    # Only root can change ownership
    if [ "$(id -u)" != "0" ]; then
        log_warn "PUID/PGID specified but not running as root - skipping"
        return 0
    fi

    # Validate numeric
    [ -n "$target_uid" ] && ! validate_numeric "$target_uid" && return 1
    [ -n "$target_gid" ] && ! validate_numeric "$target_gid" && return 1

    log_info "Setting up PUID=${target_uid:-unchanged} PGID=${target_gid:-unchanged}"

    # Modify group
    if [ -n "$target_gid" ]; then
        if ! getent group "$target_gid" >/dev/null 2>&1; then
            groupmod -g "$target_gid" "$app_group" 2>/dev/null || \
            addgroup -g "$target_gid" "$app_group" 2>/dev/null || \
            groupadd -g "$target_gid" "$app_group" 2>/dev/null || true
        fi
    fi

    # Modify user
    if [ -n "$target_uid" ]; then
        if ! getent passwd "$target_uid" >/dev/null 2>&1; then
            usermod -u "$target_uid" "$app_user" 2>/dev/null || \
            adduser -u "$target_uid" -D -S -G "$app_group" "$app_user" 2>/dev/null || \
            useradd -u "$target_uid" -g "$app_group" "$app_user" 2>/dev/null || true
        fi
    fi

    log_info "User permissions configured"
}

###########################################
# Laravel Helpers
###########################################
laravel_decrypt_env() {
    local workdir="${1:-/var/www/html}"
    local key="${LARAVEL_ENV_ENCRYPTION_KEY:-}"
    local key_file="${LARAVEL_ENV_ENCRYPTION_KEY_FILE:-}"

    [ ! -f "$workdir/.env.encrypted" ] && return 0
    [ -f "$workdir/.env" ] && ! is_true "${LARAVEL_ENV_FORCE_DECRYPT:-false}" && return 0

    # Get key from file if specified
    if [ -z "$key" ] && [ -n "$key_file" ] && [ -f "$key_file" ]; then
        key=$(cat "$key_file" | tr -d '\n')
    fi

    [ -z "$key" ] && { log_warn ".env.encrypted found but no decryption key"; return 0; }
    [ ! -f "$workdir/artisan" ] && { log_warn "artisan not found, cannot decrypt"; return 0; }

    log_info "Decrypting .env.encrypted..."
    if php "$workdir/artisan" env:decrypt --key="$key" --force 2>&1; then
        chmod 600 "$workdir/.env" 2>/dev/null || true
        log_info "Successfully decrypted .env"
    else
        log_error "Failed to decrypt .env.encrypted"
        return 1
    fi
}

laravel_run_migrations() {
    local workdir="${1:-/var/www/html}"

    [ ! -f "$workdir/artisan" ] && return 0
    ! is_true "${LARAVEL_MIGRATE_ENABLED:-false}" && return 0

    log_info "Running Laravel migrations..."
    if [ "${APP_ENV:-production}" = "production" ]; then
        php "$workdir/artisan" migrate --force --no-interaction 2>&1 || \
            log_warn "Migration failed, continuing..."
    else
        php "$workdir/artisan" migrate --no-interaction 2>&1 || \
            log_warn "Migration failed, continuing..."
    fi
}

laravel_optimize() {
    local workdir="${1:-/var/www/html}"

    [ ! -f "$workdir/artisan" ] && return 0
    ! is_true "${LARAVEL_OPTIMIZE_ENABLED:-false}" && return 0

    log_info "Optimizing Laravel caches..."
    php "$workdir/artisan" config:cache 2>&1 || true
    php "$workdir/artisan" route:cache 2>&1 || true
    php "$workdir/artisan" view:cache 2>&1 || true
}

###########################################
# Environment Variable Mapping
###########################################
# Map Laravel-style env vars to Cbox PM format
map_laravel_env_vars() {
    [ -n "$LARAVEL_HORIZON" ] && export CBOX_PM_PROCESS_HORIZON_ENABLED="$LARAVEL_HORIZON"
    [ -n "$LARAVEL_REVERB" ] && export CBOX_PM_PROCESS_REVERB_ENABLED="$LARAVEL_REVERB"
    [ -n "$LARAVEL_SCHEDULER" ] && export CBOX_PM_PROCESS_SCHEDULER_ENABLED="$LARAVEL_SCHEDULER"
    [ -n "$LARAVEL_QUEUE" ] && export CBOX_PM_PROCESS_QUEUE_DEFAULT_ENABLED="$LARAVEL_QUEUE"
    [ -n "$LARAVEL_QUEUE_HIGH" ] && export CBOX_PM_PROCESS_QUEUE_HIGH_ENABLED="$LARAVEL_QUEUE_HIGH"

    # Backward compatibility
    [ -n "$LARAVEL_SCHEDULER_ENABLED" ] && export CBOX_PM_PROCESS_SCHEDULER_ENABLED="$LARAVEL_SCHEDULER_ENABLED"
    [ -n "$LARAVEL_AUTO_MIGRATE" ] && export LARAVEL_MIGRATE_ENABLED="$LARAVEL_AUTO_MIGRATE"
    return 0
}

###########################################
# Banner
###########################################
print_banner() {
    local title="${1:-Cbox Base Image}"
    printf '%s\n' "╔═══════════════════════════════════════════════════════════════════════════╗"
    printf '║  %-73s ║\n' "$title"
    printf '%s\n' "╚═══════════════════════════════════════════════════════════════════════════╝"
}
