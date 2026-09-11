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

    # Laravel: require an `artisan` file AND corroborating evidence (composer
    # dependency or the framework bootstrap) so a stray file named `artisan`
    # doesn't trigger migrate/optimize codepaths. (Statamic ships both.)
    if [ -f "$workdir/artisan" ] && { grep -q 'laravel/framework' "$workdir/composer.json" 2>/dev/null || [ -f "$workdir/bootstrap/app.php" ]; }; then
        echo "laravel"
    # Symfony: `bin/console` plus corroborating evidence. symfony.lock only
    # exists on Flex-managed apps, so also accept a composer dependency on
    # symfony/framework-bundle (mirrors the Laravel rule above).
    elif [ -f "$workdir/bin/console" ] && { [ -f "$workdir/symfony.lock" ] || grep -q 'symfony/framework-bundle' "$workdir/composer.json" 2>/dev/null; }; then
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
    # Create the cache/log dirs when missing - on a fresh bind mount var/ is
    # often root-owned, and Symfony cannot mkdir var/cache itself then.
    for dir in var/cache var/log; do
        mkdir -p "$workdir/$dir" 2>/dev/null || true
        if [ -d "$workdir/$dir" ]; then
            chown -R "$owner:$owner" "$workdir/$dir" 2>/dev/null || true
            chmod -R 775 "$workdir/$dir" 2>/dev/null || true
        fi
    done
}

###########################################
# PHP-FPM process-manager mode
# Writes the mode-specific pm directives as a drop-in, so the static pool
# file stays mode-neutral and php-fpm never warns about directives that
# belong to another mode. Called by both the php-fpm and php-fpm-nginx
# entrypoints after sizing envs are resolved.
###########################################
write_pm_mode_dropin() {
    local mode="${PHP_FPM_PM:-dynamic}"
    local dropin="/usr/local/etc/php-fpm.d/zz-pm-mode.conf"
    case "$mode" in
        dynamic)
            # The image BAKES a dynamic drop-in with env placeholders, so an
            # unwritable config dir (read-only rootfs) is fine for the default
            # mode: FPM expands the exported PHP_FPM_* itself.
            printf '%s\n' \
                "; Auto-generated: dynamic warm floor (PHP_FPM_PM=dynamic)" \
                "[www]" \
                "pm.start_servers = ${PHP_FPM_START_SERVERS:-2}" \
                "pm.min_spare_servers = ${PHP_FPM_MIN_SPARE:-1}" \
                "pm.max_spare_servers = ${PHP_FPM_MAX_SPARE:-6}" \
                "pm.max_spawn_rate = ${PHP_FPM_MAX_SPAWN_RATE:-32}" \
                > "$dropin" 2>/dev/null || log_info "Config dir not writable - the baked dynamic drop-in stands (env-expanded by FPM)"
            ;;
        ondemand)
            printf '%s\n' \
                "; Auto-generated: ondemand (PHP_FPM_PM=ondemand)" \
                "[www]" \
                "pm.process_idle_timeout = ${PHP_FPM_PROCESS_IDLE_TIMEOUT:-10s}" \
                "pm.max_spawn_rate = ${PHP_FPM_MAX_SPAWN_RATE:-32}" \
                > "$dropin" 2>/dev/null || {
                    log_error "PHP_FPM_PM=ondemand but $dropin is not writable - refusing to boot the WRONG process manager. Mount a writable emptyDir at /usr/local/etc/php-fpm.d."
                    return 1
                }
            ;;
        static)
            printf '%s\n' \
                "; Auto-generated: static pool (PHP_FPM_PM=static)" \
                "[www]" \
                > "$dropin" 2>/dev/null || {
                    log_error "PHP_FPM_PM=static but $dropin is not writable - refusing to boot the WRONG process manager. Mount a writable emptyDir at /usr/local/etc/php-fpm.d."
                    return 1
                }
            ;;
        *)
            log_error "PHP_FPM_PM must be dynamic, ondemand or static (got: $mode)"
            return 1
            ;;
    esac
    log_info "PHP-FPM process manager: $mode"
}

###########################################
# Init Scripts Execution
###########################################
# Runs /docker-entrypoint-init.d/*.sh in VERSION-SORT order (sort -V), so
# 2-a.sh runs before 10-b.sh - plain glob order would run 10 before 2, the
# classic prefix trap. Scripts are EXECUTED (not sourced): an `exit` inside a
# user script can never abort the container boot chain.
#   - a *.sh without +x is a warning, not a silent skip (top support trap)
#   - CBOX_INIT_SCRIPTS_STRICT=true makes a failing script abort the boot
#     (default: warn and continue)
run_init_scripts() {
    local init_dir="${1:-/docker-entrypoint-init.d}"

    [ ! -d "$init_dir" ] && return 0

    local script oldIFS="$IFS"
    IFS='
'
    for script in $(ls "$init_dir"/*.sh 2>/dev/null | sort -V); do
        IFS="$oldIFS"
        [ ! -f "$script" ] && continue
        if [ ! -x "$script" ]; then
            log_warn "Init script $(basename "$script") is not executable - SKIPPING. chmod +x it (or COPY --chmod=755) to run it."
            continue
        fi
        log_info "Running init script: $(basename "$script")"
        if ! "$script"; then
            if [ "${CBOX_INIT_SCRIPTS_STRICT:-false}" = "true" ]; then
                log_error "Init script $(basename "$script") failed - aborting startup (CBOX_INIT_SCRIPTS_STRICT=true)"
                exit 1
            fi
            log_warn "Init script $(basename "$script") failed - continuing (set CBOX_INIT_SCRIPTS_STRICT=true to abort on failure)"
        fi
    done
    IFS="$oldIFS"
}

###########################################
# PHP-FPM effective-config assertion
###########################################
# Upstream has moved pool directives between its conf.d files in PATCH
# releases (docker-library/php#1635), silently overriding user listen
# addresses across the ecosystem. We delete upstream's files at build time;
# this assert is the tripwire in case any future layer reintroduces one:
# the EFFECTIVE listen (php-fpm -tt, env expanded) must be exactly what the
# entrypoint exported. Fails loud at boot instead of mysterious 502s.
verify_fpm_listen() {
    local expected="${PHP_FPM_LISTEN_ADDR:-9000}"
    local effective
    effective=$(php-fpm -tt 2>&1 | grep -E '[[:space:]]listen = ' | sed 's/^.*listen = //' | tail -1)
    if [ -z "$effective" ]; then
        log_warn "Could not read effective listen from php-fpm -tt - skipping listen assertion"
        return 0
    fi
    if [ "$effective" != "$expected" ]; then
        log_error "PHP-FPM effective listen is '$effective' but the entrypoint configured '$expected'."
        log_error "A conf file loading after zz-custom.conf is overriding the pool (check /usr/local/etc/php-fpm.d/)."
        exit 1
    fi
    log_info "PHP-FPM listen verified: $effective"
}

###########################################
# OpenTelemetry extension (opt-in)
###########################################
# The otel extension enables the Zend observer API, which taxes every PHP
# function call even with no OTel SDK installed - measured 2026-09-11 on
# dedicated EPYC (Hetzner ccx33): -18.5% rps on a Laravel app, 0% on
# tight-loop code. Its ini therefore lives in conf.d-otel, outside the
# default scan dir. A leading colon in PHP_INI_SCAN_DIR appends to the
# compiled-in default, so this works without touching the filesystem
# (read-only containers included). Exported before PHP starts; cbox-init
# passes the environment through to its services.
setup_opentelemetry() {
    if is_true "${PHP_OPENTELEMETRY:-false}"; then
        if [ -f /usr/local/etc/php/conf.d-otel/docker-php-ext-opentelemetry.ini ]; then
            export PHP_INI_SCAN_DIR="${PHP_INI_SCAN_DIR:-}:/usr/local/etc/php/conf.d-otel"
            log_info "OpenTelemetry extension enabled (PHP_OPENTELEMETRY=true)"
        else
            log_warn "PHP_OPENTELEMETRY=true but the extension is not in this tier (slim has no otel)"
        fi
    fi
}

###########################################
# Container CPU limit (cgroup-aware)
###########################################
# `worker_processes auto` reads the HOST's core count, not the container's
# CPU quota - a 500m-CPU pod on a 64-core node gets 64 workers
# (serversideup/docker-php#199, closed unfixed). The whole premise of these
# images is sizing from the container's real limits; this reads them.
detect_cpu_limit() {
    local cpus="" quota period
    if [ -f /sys/fs/cgroup/cpu.max ]; then # cgroup v2
        read -r quota period < /sys/fs/cgroup/cpu.max
        if [ "$quota" != "max" ] && [ "${period:-0}" -gt 0 ] 2>/dev/null; then
            cpus=$(( (quota + period - 1) / period ))
        fi
    elif [ -f /sys/fs/cgroup/cpu/cpu.cfs_quota_us ]; then # cgroup v1
        quota=$(cat /sys/fs/cgroup/cpu/cpu.cfs_quota_us 2>/dev/null)
        period=$(cat /sys/fs/cgroup/cpu/cpu.cfs_period_us 2>/dev/null)
        if [ "${quota:-0}" -gt 0 ] 2>/dev/null && [ "${period:-0}" -gt 0 ] 2>/dev/null; then
            cpus=$(( (quota + period - 1) / period ))
        fi
    fi
    if [ -z "$cpus" ] || ! [ "$cpus" -ge 1 ] 2>/dev/null; then
        cpus=$(nproc 2>/dev/null || echo 1)
    fi
    echo "$cpus"
}

# Rewrite worker_processes in the nginx main config to the container's CPU
# limit. NGINX_WORKER_PROCESSES overrides (a number, or 'auto' to restore
# nginx's host-count behavior).
apply_nginx_worker_processes() {
    local conf="${1:-/etc/nginx/nginx.conf}"
    local wp="${NGINX_WORKER_PROCESSES:-}"
    [ -z "$wp" ] && wp=$(detect_cpu_limit)
    [ "$wp" = "auto" ] && return 0
    if [ -w "$conf" ] && grep -qE '^worker_processes ' "$conf"; then
        sed -i "s/^worker_processes .*/worker_processes ${wp};/" "$conf"
        log_info "nginx worker_processes = ${wp} (container CPU limit; override with NGINX_WORKER_PROCESSES, 'auto' = host core count)"
    else
        log_warn "Cannot set nginx worker_processes ($conf not writable): 'auto' will size from the HOST's cores, not the container limit"
    fi
}

###########################################
# Writable-path preflight
###########################################
# The single biggest support category across every PHP image project is
# "Permission denied" on a bind mount, diagnosed over days because nothing
# names the offending path. This names it, with owner and runtime UID, before
# the app produces a cryptic 500. Warns by default (a read-only mount can be
# intentional); CBOX_PREFLIGHT_STRICT=true aborts the boot instead.
preflight_writable() {
    local failed=0 path owner
    for path in "$@"; do
        [ -e "$path" ] || continue
        if [ ! -w "$path" ]; then
            owner=$(stat -c '%U(%u):%G(%g) mode %a' "$path" 2>/dev/null || echo "unknown")
            log_warn "NOT WRITABLE: $path is owned by $owner, but this container runs as uid $(id -u). Fix the bind mount's ownership on the host (chown $(id -u):$(id -g)), drop :ro if it was mounted read-only, or mount it elsewhere."
            failed=1
        fi
    done
    if [ "$failed" = "1" ] && [ "${CBOX_PREFLIGHT_STRICT:-false}" = "true" ]; then
        log_error "Aborting startup: unwritable paths above (CBOX_PREFLIGHT_STRICT=true)"
        exit 1
    fi
    return 0
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
# Cbox Init Validation
###########################################
validate_cbox_init() {
    local config="${CBOX_INIT_CONFIG:-/etc/cbox-init/cbox-init.yaml}"

    if ! command -v cbox-init >/dev/null 2>&1; then
        log_error "Cbox Init binary not found"
        return 1
    fi

    if [ ! -f "$config" ]; then
        log_warn "Cbox Init config not found at $config, generating default..."
        if ! cbox-init scaffold --output "$config" 2>/dev/null; then
            log_error "Could not generate Cbox Init config"
            return 1
        fi
    fi

    if ! cbox-init check-config --config "$config" >/dev/null 2>&1; then
        log_error "Cbox Init config validation failed"
        return 1
    fi

    log_info "Cbox Init validated successfully"
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
# Map Laravel-style env vars to Cbox Init format
map_laravel_env_vars() {
    [ -n "$LARAVEL_HORIZON" ] && export CBOX_INIT_PROCESS_HORIZON_ENABLED="$LARAVEL_HORIZON"
    [ -n "$LARAVEL_REVERB" ] && export CBOX_INIT_PROCESS_REVERB_ENABLED="$LARAVEL_REVERB"
    [ -n "$LARAVEL_SCHEDULER" ] && export CBOX_INIT_PROCESS_SCHEDULER_ENABLED="$LARAVEL_SCHEDULER"
    [ -n "$LARAVEL_QUEUE" ] && export CBOX_INIT_PROCESS_QUEUE_DEFAULT_ENABLED="$LARAVEL_QUEUE"
    [ -n "$LARAVEL_QUEUE_HIGH" ] && export CBOX_INIT_PROCESS_QUEUE_HIGH_ENABLED="$LARAVEL_QUEUE_HIGH"

    # Backward compatibility
    [ -n "$LARAVEL_SCHEDULER_ENABLED" ] && export CBOX_INIT_PROCESS_SCHEDULER_ENABLED="$LARAVEL_SCHEDULER_ENABLED"
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
