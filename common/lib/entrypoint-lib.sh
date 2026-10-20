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
# Cbox Telemetry Native extension (opt-in)
###########################################
# cboxdk/telemetry-native is the native half of cboxdk/laravel-telemetry: a
# statistical CPU profiler, native timing for connects and cURL, bounded
# runtime counters and a signal-safe crash recorder. The image ships the .so
# but leaves it unloaded - it is pre-1.0, and it installs fatal-signal
# handlers, which is not something an image should arm on an application's
# behalf. Its ini therefore lives in conf.d-telemetry, outside the default
# scan dir; same read-only-safe mechanism as setup_opentelemetry above.
#
# PHP_TELEMETRY_NATIVE_AUTO opens a unit of work at RINIT, so a profile
# covers framework boot instead of starting wherever middleware runs. Right
# for FPM. WRONG for queue workers and Octane, where RINIT fires once per
# PROCESS - an automatic unit there would span hours and mean nothing, and
# the consumer should call begin()/finish() per job instead. That is why it
# is a separate switch rather than something PHP_TELEMETRY_NATIVE implies.
setup_telemetry_native() {
    if is_true "${PHP_TELEMETRY_NATIVE:-false}"; then
        if [ -f /usr/local/etc/php/conf.d-telemetry/cbox-telemetry.ini ]; then
            export PHP_INI_SCAN_DIR="${PHP_INI_SCAN_DIR:-}:/usr/local/etc/php/conf.d-telemetry"
            log_info "telemetry-native extension enabled (PHP_TELEMETRY_NATIVE=true)"
            if is_true "${PHP_TELEMETRY_NATIVE_AUTO:-false}"; then
                export PHP_INI_SCAN_DIR="${PHP_INI_SCAN_DIR}:/usr/local/etc/php/conf.d-telemetry-auto"
                log_info "telemetry-native automatic units enabled (cbox_telemetry.auto=1)"
            fi
        else
            log_warn "PHP_TELEMETRY_NATIVE=true but the extension is not in this image (it needs PHP 8.3+)"
        fi
    elif is_true "${PHP_TELEMETRY_NATIVE_AUTO:-false}"; then
        log_warn "PHP_TELEMETRY_NATIVE_AUTO=true does nothing without PHP_TELEMETRY_NATIVE=true"
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
#
# Remaps the app user to the uid/gid the host uses, which is the whole point of
# PUID/PGID: files the container writes into a bind mount come out owned by
# somebody who can edit them afterwards.
#
# THIS is the one implementation. php-fpm-nginx used to carry a private copy
# and the other three images carried nothing, so `PUID=1000` was accepted and
# silently ignored on php-fpm, php-cli and nginx while the docs promised it
# everywhere (#44). One function, called by every entrypoint.
#
# Optional arguments are directories to chown after the remap - pass the ones
# the image owns. Without PUID/PGID nothing is remapped and nothing is chowned,
# so a caller that wants its usual unconditional chown keeps doing it itself.
#
# APP_USER/APP_GROUP name the user to remap; the standalone nginx image runs
# its workers as `nginx`, not `www-data`, and defaults them accordingly.
###########################################
setup_user_permissions() {
    # Rootless images already run AS the app user: nothing to remap, and no
    # privilege to remap it with.
    if is_rootless; then
        log_info "Rootless mode - skipping PUID/PGID user mapping"
        return 0
    fi

    local target_uid="${PUID:-}"
    local target_gid="${PGID:-}"
    local app_user="${APP_USER:-www-data}"
    local app_group="${APP_GROUP:-www-data}"

    [ -z "$target_uid" ] && [ -z "$target_gid" ] && return 0

    if [ "$(id -u)" != "0" ]; then
        log_warn "PUID/PGID specified but not running as root - skipping user mapping"
        return 0
    fi

    # A typo here is a deploy-time mistake, and every image fails the boot on it
    # rather than guessing a uid. Name the variable - "Value must be numeric" on
    # its own sent people reading the wrong part of their compose file.
    if [ -n "$target_uid" ] && ! validate_numeric "$target_uid" >/dev/null 2>&1; then
        log_error "PUID must be a number (got '$target_uid')"
        return 1
    fi
    if [ -n "$target_gid" ] && ! validate_numeric "$target_gid" >/dev/null 2>&1; then
        log_error "PGID must be a number (got '$target_gid')"
        return 1
    fi

    log_info "Setting up PUID=${target_uid:-unchanged} PGID=${target_gid:-unchanged} for ${app_user}:${app_group}"

    # Group first: a usermod that moves the user into a group needs it to exist.
    if [ -n "$target_gid" ]; then
        local current_gid
        current_gid=$(id -g "$app_user" 2>/dev/null || echo "")
        if [ "$current_gid" != "$target_gid" ]; then
            if getent group "$target_gid" >/dev/null 2>&1; then
                # Taken by something else. Say so instead of leaving the
                # operator to wonder why the mapping did not happen.
                log_info "GID $target_gid already exists as group '$(getent group "$target_gid" | cut -d: -f1)'"
            else
                groupmod -g "$target_gid" "$app_group" 2>/dev/null || \
                    addgroup -g "$target_gid" "$app_group" 2>/dev/null || \
                    groupadd -g "$target_gid" "$app_group" 2>/dev/null || true
            fi
        fi
    fi

    if [ -n "$target_uid" ]; then
        local current_uid
        current_uid=$(id -u "$app_user" 2>/dev/null || echo "")
        if [ "$current_uid" != "$target_uid" ]; then
            if getent passwd "$target_uid" >/dev/null 2>&1; then
                log_info "UID $target_uid already exists as user '$(getent passwd "$target_uid" | cut -d: -f1)'"
            else
                usermod -u "$target_uid" "$app_user" 2>/dev/null || \
                    adduser -u "$target_uid" -D -S -G "$app_group" "$app_user" 2>/dev/null || \
                    useradd -u "$target_uid" -g "$app_group" "$app_user" 2>/dev/null || true
            fi
        fi
    fi

    # Ownership of the paths the caller named. `chown -R` over a large mounted
    # volume (Statamic content, uploaded assets) on every start is O(files) and
    # slows rollouts / trips startupProbes - so skip a path that is already
    # owned by the target user.
    local numeric_uid
    numeric_uid=$(id -u "$app_user" 2>/dev/null || echo "")
    local dir
    for dir in "$@"; do
        [ -d "$dir" ] || continue
        if [ -n "$numeric_uid" ] && [ "$(stat -c %u "$dir" 2>/dev/null)" = "$numeric_uid" ]; then
            log_info "Ownership of $dir already correct - skipping recursive chown"
            continue
        fi
        log_info "Updating ownership of $dir"
        chown -R "$app_user:$app_group" "$dir" 2>/dev/null || true
    done

    log_info "User permissions configured: ${app_user} is uid $(id -u "$app_user" 2>/dev/null || echo '?')"
}

###########################################
# App Process Identity (cbox-init app processes)
#
# The app processes in cbox-init.yaml - queue workers, scheduler, Horizon,
# Reverb, the queue autoscaler - carry two placeholders that cbox-init expands
# when it loads the config:
#
#   working_dir: ${WORKDIR:-/var/www/html}
#   user: ${CBOX_APP_USER:-}
#
# This resolves both, once, before cbox-init is exec'd.
#
# WORKDIR was hardcoded to /var/www/html in the config, so a symlink-release
# layout (WORKDIR=/app/current) crash-looped every worker with "Could not open
# input file: artisan" while php-fpm and the entrypoint used the real path.
#
# CBOX_APP_USER makes the workers match the php-fpm pool user instead of
# staying root: a job that writes a cache file, a compiled view, a log line or
# a git object left it root-owned, and the php-fpm workers could not write
# there afterwards.
#
# It is deliberately EMPTY whenever this container cannot drop privileges -
# the rootless images, `--user 1000:1000`, OpenShift's arbitrary uid. cbox-init
# fails a process closed when it cannot setuid to the configured user, so
# asking for www-data from a container that is already an unprivileged user
# would turn "the workers run as the wrong user" into "the workers do not run".
# Nothing is lost there: the container's own user IS the app user.
#
# An explicit CBOX_APP_USER is always honored, as is a per-process
# CBOX_INIT_PROCESS_<NAME>_USER / _WORKING_DIR override.
###########################################
setup_app_process_identity() {
    WORKDIR="${WORKDIR:-/var/www/html}"
    export WORKDIR

    # Explicitly set (even to empty) = the operator decided; don't second-guess.
    if [ -n "${CBOX_APP_USER+x}" ]; then
        export CBOX_APP_USER
        return 0
    fi

    if [ "$(id -u)" = "0" ] && ! is_rootless; then
        export CBOX_APP_USER="${APP_USER:-www-data}"
        log_info "App processes (workers, scheduler, Horizon, Reverb) run as ${CBOX_APP_USER} in ${WORKDIR}"
    else
        export CBOX_APP_USER=""
        log_info "App processes run as this container's own user (uid $(id -u)) in ${WORKDIR}"
    fi
    return 0
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
