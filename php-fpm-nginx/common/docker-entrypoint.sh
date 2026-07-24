#!/bin/bash
set -e

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  Cbox Base Image - Docker Entrypoint                                    ║
# ║  Powered by Cbox Init (Process Manager)                                   ║
# ║  https://github.com/cboxdk/init                                      ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
# shellcheck shell=bash

###########################################
# Lifecycle Warning (deprecation/preview)
###########################################
LIFECYCLE_CHECK="/usr/local/lib/cbox/lifecycle-check.sh"
if [ -f "$LIFECYCLE_CHECK" ]; then
    # shellcheck source=/dev/null
    . "$LIFECYCLE_CHECK"
    cbox_lifecycle_check
fi

# Source shared library
LIB_PATH="${CBOX_LIB_PATH:-/usr/local/lib/cbox/entrypoint-lib.sh}"
if [ -f "$LIB_PATH" ]; then
    # shellcheck source=/dev/null
    . "$LIB_PATH"
else
    # Fallback: minimal functions if library not found
    log_info()  { echo "[INFO] $1"; }
    log_warn()  { echo "[WARN] $1"; }
    log_error() { echo "[ERROR] $1" >&2; }
    validate_boolean() {
        case "$1" in
            true|false|TRUE|FALSE|1|0|yes|no|YES|NO|"") return 0 ;;
            *) echo "WARNING: Invalid boolean value: $1" >&2; return 1 ;;
        esac
    }
    validate_numeric() {
        case "$1" in
            ''|*[!0-9]*) echo "ERROR: Value must be numeric: $1" >&2; return 1 ;;
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
fi

###########################################
# Signal Handling for Graceful Shutdown/Reload
###########################################
CBOX_INIT_PID=""
PHP_FPM_PID=""
NGINX_PID=""

cleanup() {
    log_info "Received shutdown signal, cleaning up..."
    # Forward signal to Cbox Init (it handles child processes)
    if [ -n "$CBOX_INIT_PID" ] && kill -0 "$CBOX_INIT_PID" 2>/dev/null; then
        kill -TERM "$CBOX_INIT_PID" 2>/dev/null
        wait "$CBOX_INIT_PID" 2>/dev/null
    fi
    # Fallback mode cleanup
    if [ -n "$PHP_FPM_PID" ] && kill -0 "$PHP_FPM_PID" 2>/dev/null; then
        kill -QUIT "$PHP_FPM_PID" 2>/dev/null
    fi
    if [ -n "$NGINX_PID" ] && kill -0 "$NGINX_PID" 2>/dev/null; then
        kill -QUIT "$NGINX_PID" 2>/dev/null
    fi
    exit 0
}

graceful_reload() {
    log_info "Received SIGHUP, reloading services..."
    if [ -n "$PHP_FPM_PID" ] && kill -0 "$PHP_FPM_PID" 2>/dev/null; then
        log_info "Reloading PHP-FPM..."
        kill -USR2 "$PHP_FPM_PID" 2>/dev/null
    fi
    if [ -n "$NGINX_PID" ] && kill -0 "$NGINX_PID" 2>/dev/null; then
        log_info "Reloading Nginx..."
        kill -HUP "$NGINX_PID" 2>/dev/null
    fi
    if [ -n "$CBOX_INIT_PID" ] && kill -0 "$CBOX_INIT_PID" 2>/dev/null; then
        log_info "Forwarding reload to Cbox Init..."
        kill -HUP "$CBOX_INIT_PID" 2>/dev/null
    fi
}

# Use POSIX signal names (without SIG prefix) for dash compatibility on Debian
trap cleanup TERM INT QUIT
trap graceful_reload HUP

###########################################
# Nginx-specific Validation
###########################################
sanitize_nginx_value() {
    echo "$1" | sed 's/[;{}$`\\]//g'
}

###########################################
# PUID/PGID Runtime User Mapping
# NOTE: This is an extended version of setup_user_permissions() from
# entrypoint-lib.sh. It adds rootless-mode awareness, current UID/GID
# checks before modifying, and ownership updates for the workdir and
# common framework directories (storage, bootstrap/cache, var/).
# Not using the lib version because the logic is a complete superset.
###########################################
setup_user_permissions_extended() {
    # Skip PUID/PGID mapping in rootless mode
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

    [ -n "$target_uid" ] && ! validate_numeric "$target_uid" && return 1
    [ -n "$target_gid" ] && ! validate_numeric "$target_gid" && return 1

    log_info "Setting up PUID=${target_uid:-unchanged} PGID=${target_gid:-unchanged}"

    # Modify group if PGID specified
    if [ -n "$target_gid" ]; then
        local current_gid
        current_gid=$(id -g "$app_user" 2>/dev/null || echo "")
        if [ "$current_gid" != "$target_gid" ]; then
            if getent group "$target_gid" >/dev/null 2>&1; then
                local existing_group
                existing_group=$(getent group "$target_gid" | cut -d: -f1)
                log_info "GID $target_gid already exists as group '$existing_group'"
            else
                groupmod -g "$target_gid" "$app_group" 2>/dev/null || \
                    addgroup -g "$target_gid" "$app_group" 2>/dev/null || \
                    groupadd -g "$target_gid" "$app_group" 2>/dev/null || true
            fi
        fi
    fi

    # Modify user if PUID specified
    if [ -n "$target_uid" ]; then
        local current_uid
        current_uid=$(id -u "$app_user" 2>/dev/null || echo "")
        if [ "$current_uid" != "$target_uid" ]; then
            if getent passwd "$target_uid" >/dev/null 2>&1; then
                local existing_user
                existing_user=$(getent passwd "$target_uid" | cut -d: -f1)
                log_info "UID $target_uid already exists as user '$existing_user'"
            else
                usermod -u "$target_uid" "$app_user" 2>/dev/null || \
                    adduser -u "$target_uid" -D -S -G "$app_group" "$app_user" 2>/dev/null || \
                    useradd -u "$target_uid" -g "$app_group" "$app_user" 2>/dev/null || true
            fi
        fi
    fi

    # Update ownership only when it isn't already correct. `chown -R` over a
    # large mounted volume (Statamic content, uploaded assets) on every start
    # is O(files) and slows rollouts / trips startupProbes — so skip when the
    # workdir is already owned by the target user.
    local workdir="${WORKDIR:-/var/www/html}"
    if [ -d "$workdir" ]; then
        local numeric_uid
        numeric_uid=$(id -u "$app_user" 2>/dev/null || echo "")
        if [ -n "$numeric_uid" ] && [ "$(stat -c %u "$workdir" 2>/dev/null)" = "$numeric_uid" ]; then
            log_info "Ownership of $workdir already correct - skipping recursive chown"
        else
            log_info "Updating ownership of $workdir"
            chown -R "$app_user:$app_group" "$workdir" 2>/dev/null || true
        fi
    fi

    log_info "User permissions configured successfully"
}

# Laravel .env decryption: uses laravel_decrypt_env() from entrypoint-lib.sh

###########################################
# Environment Variable Aliases (DX)
# NOTE: Extended version of map_laravel_env_vars() from entrypoint-lib.sh.
# This version adds validate_boolean() checks before each export to catch
# invalid user input early. The lib version trusts input without validation.
###########################################
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

# PHP Version Auto-Detection (uses detect_php_version from entrypoint-lib.sh,
# falls back to inline detection if lib was not loaded)
if command -v detect_php_version >/dev/null 2>&1; then
    PHP_VERSION=$(detect_php_version)
elif command -v php >/dev/null 2>&1; then
    PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
else
    PHP_VERSION="8.3"
fi

###########################################
# Runtime Configuration Generation
###########################################
generate_php_config() {
    local template="$1"
    local output="$2"
    [ -f "$template" ] && envsubst < "$template" > "$output" 2>/dev/null || true
}

apply_php_env_overrides() {
    local ini="/usr/local/etc/php/conf.d/zz-env-overrides.ini"
    local fpm="/usr/local/etc/php-fpm.d/zz-env-overrides.conf"
    local content=""

    # PHP ini overrides (zz- prefix ensures it loads last and wins)
    content="; Auto-generated from environment variables"
    [ -n "$PHP_MEMORY_LIMIT" ] && content="${content}\nmemory_limit = $PHP_MEMORY_LIMIT"
    [ -n "$PHP_MAX_EXECUTION_TIME" ] && content="${content}\nmax_execution_time = $PHP_MAX_EXECUTION_TIME"
    [ -n "$PHP_MAX_INPUT_TIME" ] && content="${content}\nmax_input_time = $PHP_MAX_INPUT_TIME"
    [ -n "$PHP_POST_MAX_SIZE" ] && content="${content}\npost_max_size = $PHP_POST_MAX_SIZE"
    [ -n "$PHP_UPLOAD_MAX_FILESIZE" ] && content="${content}\nupload_max_filesize = $PHP_UPLOAD_MAX_FILESIZE"
    [ -n "$PHP_MAX_FILE_UPLOADS" ] && content="${content}\nmax_file_uploads = $PHP_MAX_FILE_UPLOADS"
    [ -n "$PHP_MAX_INPUT_VARS" ] && content="${content}\nmax_input_vars = $PHP_MAX_INPUT_VARS"
    [ -n "$PHP_DATE_TIMEZONE" ] && content="${content}\ndate.timezone = $PHP_DATE_TIMEZONE"
    [ -n "$PHP_DISPLAY_ERRORS" ] && content="${content}\ndisplay_errors = $PHP_DISPLAY_ERRORS"
    [ -n "$PHP_DISPLAY_STARTUP_ERRORS" ] && content="${content}\ndisplay_startup_errors = $PHP_DISPLAY_STARTUP_ERRORS"
    [ -n "$PHP_ERROR_REPORTING" ] && content="${content}\nerror_reporting = $PHP_ERROR_REPORTING"
    [ -n "$PHP_LOG_ERRORS" ] && content="${content}\nlog_errors = $PHP_LOG_ERRORS"
    [ -n "$PHP_ERROR_LOG" ] && content="${content}\nerror_log = $PHP_ERROR_LOG"
    [ -n "$PHP_SESSION_COOKIE_SECURE" ] && content="${content}\nsession.cookie_secure = $PHP_SESSION_COOKIE_SECURE"
    [ -n "$PHP_REALPATH_CACHE_TTL" ] && content="${content}\nrealpath_cache_ttl = $PHP_REALPATH_CACHE_TTL"
    [ -n "$PHP_OPEN_BASEDIR" ] && content="${content}\nopen_basedir = $PHP_OPEN_BASEDIR"
    [ -n "$PHP_OPCACHE_ENABLE" ] && content="${content}\nopcache.enable = $PHP_OPCACHE_ENABLE"
    [ -n "$PHP_OPCACHE_MEMORY_CONSUMPTION" ] && content="${content}\nopcache.memory_consumption = $PHP_OPCACHE_MEMORY_CONSUMPTION"
    [ -n "$PHP_OPCACHE_INTERNED_STRINGS_BUFFER" ] && content="${content}\nopcache.interned_strings_buffer = $PHP_OPCACHE_INTERNED_STRINGS_BUFFER"
    [ -n "$PHP_OPCACHE_MAX_ACCELERATED_FILES" ] && content="${content}\nopcache.max_accelerated_files = $PHP_OPCACHE_MAX_ACCELERATED_FILES"
    [ -n "$PHP_OPCACHE_REVALIDATE_FREQ" ] && content="${content}\nopcache.revalidate_freq = $PHP_OPCACHE_REVALIDATE_FREQ"
    [ -n "$PHP_OPCACHE_VALIDATE_TIMESTAMPS" ] && content="${content}\nopcache.validate_timestamps = $PHP_OPCACHE_VALIDATE_TIMESTAMPS"
    if [ -n "$PHP_OPCACHE_JIT" ]; then
        content="${content}\nopcache.jit = $PHP_OPCACHE_JIT"
        # Turning JIT off must ALSO zero the buffer. opcache.jit=off/disable alone
        # still allocates the RWX JIT arena at module init, which (a) wastes the
        # configured buffer and (b) leaves the process un-checkpointable — CRIU
        # cannot parasite-inject through JIT'd executable memory, so scale-to-zero
        # suspend/resume silently fails. Set jit=off to make a service snapshotable.
        case "$PHP_OPCACHE_JIT" in
            off | disable | 0) content="${content}\nopcache.jit_buffer_size = 0" ;;
        esac
    fi
    [ -n "$PHP_OPCACHE_JIT_BUFFER_SIZE" ] && content="${content}\nopcache.jit_buffer_size = $PHP_OPCACHE_JIT_BUFFER_SIZE"
    printf '%b\n' "$content" > "$ini" 2>/dev/null || log_warn "Could not write $ini (read-only rootfs? mount an emptyDir at /usr/local/etc/php/conf.d)"

    # PHP-FPM pool overrides
    content="; Auto-generated from environment variables\n[www]"
    [ -n "$PHP_FPM_PM" ] && content="${content}\npm = $PHP_FPM_PM"
    [ -n "$PHP_FPM_PM_MAX_CHILDREN" ] && content="${content}\npm.max_children = $PHP_FPM_PM_MAX_CHILDREN"
    [ -n "$PHP_FPM_PM_START_SERVERS" ] && content="${content}\npm.start_servers = $PHP_FPM_PM_START_SERVERS"
    [ -n "$PHP_FPM_PM_MIN_SPARE_SERVERS" ] && content="${content}\npm.min_spare_servers = $PHP_FPM_PM_MIN_SPARE_SERVERS"
    [ -n "$PHP_FPM_PM_MAX_SPARE_SERVERS" ] && content="${content}\npm.max_spare_servers = $PHP_FPM_PM_MAX_SPARE_SERVERS"
    [ -n "$PHP_FPM_PM_MAX_REQUESTS" ] && content="${content}\npm.max_requests = $PHP_FPM_PM_MAX_REQUESTS"
    [ -n "$PHP_FPM_REQUEST_TERMINATE_TIMEOUT" ] && content="${content}\nrequest_terminate_timeout = $PHP_FPM_REQUEST_TERMINATE_TIMEOUT"
    # FPM pool overrides for PHP values (php_admin_value wins over php.ini)
    [ -n "$PHP_MEMORY_LIMIT" ] && content="${content}\nphp_admin_value[memory_limit] = $PHP_MEMORY_LIMIT"
    [ -n "$PHP_MAX_EXECUTION_TIME" ] && content="${content}\nphp_admin_value[max_execution_time] = $PHP_MAX_EXECUTION_TIME"
    [ -n "$PHP_MAX_INPUT_TIME" ] && content="${content}\nphp_admin_value[max_input_time] = $PHP_MAX_INPUT_TIME"
    [ -n "$PHP_UPLOAD_MAX_FILESIZE" ] && content="${content}\nphp_admin_value[upload_max_filesize] = $PHP_UPLOAD_MAX_FILESIZE"
    [ -n "$PHP_POST_MAX_SIZE" ] && content="${content}\nphp_admin_value[post_max_size] = $PHP_POST_MAX_SIZE"
    [ -n "$PHP_OPEN_BASEDIR" ] && content="${content}\nphp_admin_value[open_basedir] = $PHP_OPEN_BASEDIR"
    printf '%b\n' "$content" > "$fpm" 2>/dev/null || log_warn "Could not write $fpm (read-only rootfs? mount an emptyDir at /usr/local/etc/php-fpm.d)"
}

generate_runtime_configs() {
    # PHP environment variable overrides
    apply_php_env_overrides

    # PHP custom templates (user-provided). These images are source-built
    # (php:*-fpm), so config lives under /usr/local/etc/php — the Debian-style
    # /etc/php/${PHP_VERSION}/fpm path does not exist and was a silent no-op.
    generate_php_config "/usr/local/etc/php/conf.d/99-custom.ini.template" "/usr/local/etc/php/conf.d/99-custom.ini"

    # Nginx configuration
    if [ -f /etc/nginx/conf.d/default.conf.template ]; then
        # Set defaults (rootless uses unprivileged ports)
        if is_rootless; then
            : ${NGINX_HTTP_PORT:=8080}
            : ${NGINX_HTTPS_PORT:=8443}
        else
            : ${NGINX_HTTP_PORT:=80}
            : ${NGINX_HTTPS_PORT:=443}
        fi
        : ${NGINX_WEBROOT:=/var/www/html/public}
        : ${NGINX_INDEX:=index.php index.html}
        : ${NGINX_CLIENT_MAX_BODY_SIZE:=100M}
        : ${NGINX_CLIENT_BODY_TIMEOUT:=60s}
        : ${NGINX_CLIENT_HEADER_TIMEOUT:=60s}
        : ${NGINX_HEADER_X_FRAME_OPTIONS:=SAMEORIGIN}
        : ${NGINX_HEADER_X_CONTENT_TYPE_OPTIONS:=nosniff}
        # X-XSS-Protection removed - deprecated and can be exploited (see serversideup/docker-php#31)
        : ${NGINX_HEADER_X_XSS_PROTECTION:=}
        # CSP empty by default - too complex for one-size-fits-all (like ServerSideUp)
        # Users can set via NGINX_HEADER_CSP env var
        : ${NGINX_HEADER_CSP:=}
        : ${NGINX_HEADER_REFERRER_POLICY:=strict-origin-when-cross-origin}
        : ${NGINX_HEADER_COOP:=}
        : ${NGINX_HEADER_COEP:=}
        : ${NGINX_HEADER_CORP:=}
        : "${NGINX_HEADER_PERMISSIONS_POLICY:=accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=()}"
        : ${NGINX_SERVER_TOKENS:=off}

        if [ "${NGINX_ACCESS_LOG:-}" = "false" ] || [ "${NGINX_ACCESS_LOG:-}" = "FALSE" ]; then
            NGINX_ACCESS_LOG="off"
        fi
        : ${NGINX_ACCESS_LOG:=/var/log/nginx/access.log}
        : ${NGINX_ERROR_LOG:=/var/log/nginx/error.log}
        : ${NGINX_ERROR_LOG_LEVEL:=warn}
        : ${NGINX_TRY_FILES:=/index.php?\$query_string}
        : ${NGINX_FASTCGI_PASS:=127.0.0.1:9000}
        : ${NGINX_FASTCGI_BUFFERS:=8 8k}
        : ${NGINX_FASTCGI_BUFFER_SIZE:=8k}
        : ${NGINX_FASTCGI_BUSY_BUFFERS_SIZE:=16k}
        : ${NGINX_FASTCGI_CONNECT_TIMEOUT:=60s}
        : ${NGINX_FASTCGI_SEND_TIMEOUT:=60s}
        : ${NGINX_FASTCGI_READ_TIMEOUT:=60s}
        : ${NGINX_STATIC_EXPIRES:=1y}
        : ${NGINX_STATIC_CACHE_CONTROL:=public, immutable}
        : ${NGINX_STATIC_ACCESS_LOG:=off}
        : ${NGINX_GZIP:=on}
        : ${NGINX_GZIP_VARY:=on}
        : ${NGINX_GZIP_PROXIED:=any}
        : ${NGINX_GZIP_COMP_LEVEL:=6}
        : ${NGINX_GZIP_MIN_LENGTH:=1000}
        : ${NGINX_GZIP_TYPES:=text/plain text/css text/xml text/javascript application/json application/javascript application/xml application/xml+rss application/x-javascript image/svg+xml}
        : ${NGINX_OPEN_FILE_CACHE:=max=10000 inactive=20s}
        : ${NGINX_OPEN_FILE_CACHE_VALID:=30s}
        : ${NGINX_OPEN_FILE_CACHE_MIN_USES:=2}
        : ${NGINX_OPEN_FILE_CACHE_ERRORS:=on}
        : ${NGINX_TRUSTED_PROXIES:=}
        : ${NGINX_REAL_IP_HEADER:=X-Forwarded-For}
        : ${NGINX_REAL_IP_RECURSIVE:=on}
        : ${NGINX_PROXY_PROTOCOL:=off}
        # When fronted by an L4 proxy that speaks PROXY protocol (HAProxy TCP mode,
        # AWS NLB, Fastly): accept it on the listen sockets and take the real client
        # IP from the PROXY header. Otherwise nginx would 400 on the PROXY preamble.
        if [ "${NGINX_PROXY_PROTOCOL}" = "on" ] || [ "${NGINX_PROXY_PROTOCOL}" = "true" ]; then
            NGINX_LISTEN_EXTRA="proxy_protocol"
            NGINX_REAL_IP_HEADER="proxy_protocol"
        else
            NGINX_LISTEN_EXTRA=""
        fi
        : ${MTLS_ENABLED:=false}
        : ${MTLS_CLIENT_CA_FILE:=/etc/ssl/certs/client-ca.crt}
        : ${MTLS_VERIFY_CLIENT:=optional}
        : ${MTLS_VERIFY_DEPTH:=2}

        export NGINX_HTTP_PORT NGINX_HTTPS_PORT NGINX_WEBROOT NGINX_INDEX
        export NGINX_CLIENT_MAX_BODY_SIZE NGINX_CLIENT_BODY_TIMEOUT NGINX_CLIENT_HEADER_TIMEOUT
        export NGINX_HEADER_X_FRAME_OPTIONS NGINX_HEADER_X_CONTENT_TYPE_OPTIONS NGINX_HEADER_X_XSS_PROTECTION NGINX_HEADER_CSP
        export NGINX_HEADER_REFERRER_POLICY NGINX_HEADER_COOP NGINX_HEADER_COEP NGINX_HEADER_CORP NGINX_HEADER_PERMISSIONS_POLICY
        export NGINX_SERVER_TOKENS NGINX_ACCESS_LOG NGINX_ERROR_LOG NGINX_ERROR_LOG_LEVEL NGINX_TRY_FILES
        export NGINX_FASTCGI_PASS NGINX_FASTCGI_BUFFERS NGINX_FASTCGI_BUFFER_SIZE NGINX_FASTCGI_BUSY_BUFFERS_SIZE
        export NGINX_FASTCGI_CONNECT_TIMEOUT NGINX_FASTCGI_SEND_TIMEOUT NGINX_FASTCGI_READ_TIMEOUT
        export NGINX_STATIC_EXPIRES NGINX_STATIC_CACHE_CONTROL NGINX_STATIC_ACCESS_LOG
        export NGINX_GZIP NGINX_GZIP_VARY NGINX_GZIP_PROXIED NGINX_GZIP_COMP_LEVEL NGINX_GZIP_MIN_LENGTH NGINX_GZIP_TYPES
        export NGINX_OPEN_FILE_CACHE NGINX_OPEN_FILE_CACHE_VALID NGINX_OPEN_FILE_CACHE_MIN_USES NGINX_OPEN_FILE_CACHE_ERRORS
        export NGINX_TRUSTED_PROXIES NGINX_REAL_IP_HEADER NGINX_REAL_IP_RECURSIVE
        export NGINX_PROXY_PROTOCOL NGINX_LISTEN_EXTRA
        export MTLS_ENABLED MTLS_CLIENT_CA_FILE MTLS_VERIFY_CLIENT MTLS_VERIFY_DEPTH

        # Trusted proxy configuration
        if [ -n "${NGINX_TRUSTED_PROXIES}" ]; then
            log_info "Configuring trusted proxies for real IP detection"
            NGINX_REAL_IP_CONFIG=""
            for proxy in ${NGINX_TRUSTED_PROXIES}; do
                # Proxies are IPs/CIDRs; strip characters that could break out
                # of the directive and inject arbitrary nginx config.
                proxy=$(sanitize_nginx_value "$proxy")
                [ -z "$proxy" ] && continue
                NGINX_REAL_IP_CONFIG="${NGINX_REAL_IP_CONFIG}set_real_ip_from ${proxy};\n"
            done
            NGINX_REAL_IP_CONFIG="${NGINX_REAL_IP_CONFIG}real_ip_header ${NGINX_REAL_IP_HEADER};\nreal_ip_recursive ${NGINX_REAL_IP_RECURSIVE};"
            # Convert \n to actual newlines (same as security headers below).
            # Without this the literal "\n" ends up in the config and nginx
            # aborts with: unknown directive "<newline>set_real_ip_from".
            NGINX_REAL_IP_CONFIG=$(printf '%b' "$NGINX_REAL_IP_CONFIG")
            export NGINX_REAL_IP_CONFIG
        else
            export NGINX_REAL_IP_CONFIG="# No trusted proxies configured"
        fi

        # mTLS configuration
        if [ "${MTLS_ENABLED}" = "true" ]; then
            if [ -f "${MTLS_CLIENT_CA_FILE}" ]; then
                log_info "Configuring mTLS client certificate authentication"
                export NGINX_MTLS_CONFIG="ssl_client_certificate ${MTLS_CLIENT_CA_FILE};\n    ssl_verify_client ${MTLS_VERIFY_CLIENT};\n    ssl_verify_depth ${MTLS_VERIFY_DEPTH};"
            else
                log_warn "mTLS enabled but client CA file not found: ${MTLS_CLIENT_CA_FILE}"
                export NGINX_MTLS_CONFIG="# mTLS enabled but CA file missing"
            fi
        else
            export NGINX_MTLS_CONFIG="# mTLS disabled"
        fi

        # Generate security headers (only non-empty values)
        NGINX_SECURITY_HEADERS=""
        [ -n "${NGINX_HEADER_X_FRAME_OPTIONS}" ] && NGINX_SECURITY_HEADERS="${NGINX_SECURITY_HEADERS}    add_header X-Frame-Options \"${NGINX_HEADER_X_FRAME_OPTIONS}\" always;\n"
        [ -n "${NGINX_HEADER_X_CONTENT_TYPE_OPTIONS}" ] && NGINX_SECURITY_HEADERS="${NGINX_SECURITY_HEADERS}    add_header X-Content-Type-Options \"${NGINX_HEADER_X_CONTENT_TYPE_OPTIONS}\" always;\n"
        [ -n "${NGINX_HEADER_X_XSS_PROTECTION}" ] && NGINX_SECURITY_HEADERS="${NGINX_SECURITY_HEADERS}    add_header X-XSS-Protection \"${NGINX_HEADER_X_XSS_PROTECTION}\" always;\n"
        [ -n "${NGINX_HEADER_CSP}" ] && NGINX_SECURITY_HEADERS="${NGINX_SECURITY_HEADERS}    add_header Content-Security-Policy \"${NGINX_HEADER_CSP}\" always;\n"
        [ -n "${NGINX_HEADER_REFERRER_POLICY}" ] && NGINX_SECURITY_HEADERS="${NGINX_SECURITY_HEADERS}    add_header Referrer-Policy \"${NGINX_HEADER_REFERRER_POLICY}\" always;\n"
        [ -n "${NGINX_HEADER_COOP}" ] && NGINX_SECURITY_HEADERS="${NGINX_SECURITY_HEADERS}    add_header Cross-Origin-Opener-Policy \"${NGINX_HEADER_COOP}\" always;\n"
        [ -n "${NGINX_HEADER_COEP}" ] && NGINX_SECURITY_HEADERS="${NGINX_SECURITY_HEADERS}    add_header Cross-Origin-Embedder-Policy \"${NGINX_HEADER_COEP}\" always;\n"
        [ -n "${NGINX_HEADER_CORP}" ] && NGINX_SECURITY_HEADERS="${NGINX_SECURITY_HEADERS}    add_header Cross-Origin-Resource-Policy \"${NGINX_HEADER_CORP}\" always;\n"
        [ -n "${NGINX_HEADER_PERMISSIONS_POLICY}" ] && NGINX_SECURITY_HEADERS="${NGINX_SECURITY_HEADERS}    add_header Permissions-Policy \"${NGINX_HEADER_PERMISSIONS_POLICY}\" always;\n"
        # Convert \n to actual newlines
        NGINX_SECURITY_HEADERS=$(printf '%b' "$NGINX_SECURITY_HEADERS")
        export NGINX_SECURITY_HEADERS

        envsubst '${NGINX_HTTP_PORT} ${NGINX_HTTPS_PORT} ${NGINX_WEBROOT} ${NGINX_INDEX} ${NGINX_CLIENT_MAX_BODY_SIZE} ${NGINX_CLIENT_BODY_TIMEOUT} ${NGINX_CLIENT_HEADER_TIMEOUT} ${NGINX_SERVER_TOKENS} ${NGINX_ACCESS_LOG} ${NGINX_ERROR_LOG} ${NGINX_ERROR_LOG_LEVEL} ${NGINX_TRY_FILES} ${NGINX_FASTCGI_PASS} ${NGINX_FASTCGI_BUFFERS} ${NGINX_FASTCGI_BUFFER_SIZE} ${NGINX_FASTCGI_BUSY_BUFFERS_SIZE} ${NGINX_FASTCGI_CONNECT_TIMEOUT} ${NGINX_FASTCGI_SEND_TIMEOUT} ${NGINX_FASTCGI_READ_TIMEOUT} ${NGINX_STATIC_EXPIRES} ${NGINX_STATIC_CACHE_CONTROL} ${NGINX_STATIC_ACCESS_LOG} ${NGINX_GZIP} ${NGINX_GZIP_VARY} ${NGINX_GZIP_PROXIED} ${NGINX_GZIP_COMP_LEVEL} ${NGINX_GZIP_MIN_LENGTH} ${NGINX_GZIP_TYPES} ${NGINX_OPEN_FILE_CACHE} ${NGINX_OPEN_FILE_CACHE_VALID} ${NGINX_OPEN_FILE_CACHE_MIN_USES} ${NGINX_OPEN_FILE_CACHE_ERRORS} ${NGINX_REAL_IP_CONFIG} ${NGINX_MTLS_CONFIG} ${NGINX_SECURITY_HEADERS} ${NGINX_LISTEN_EXTRA}' \
            < /etc/nginx/conf.d/default.conf.template \
            > /etc/nginx/conf.d/default.conf || {
            log_error "Failed to generate Nginx config"
            exit 1
        }
    fi

    # SSL configuration
    [ -n "${SSL_MODE}" ] && [ "${SSL_MODE}" != "off" ] && generate_ssl_config

    # Fail closed: validate the generated nginx config so a bad env-supplied
    # value surfaces here with a clear message instead of crash-looping nginx
    # under cbox-init. `nginx -t` only checks syntax, not upstream liveness, so
    # it is safe to run before php-fpm is up.
    if command -v nginx >/dev/null 2>&1; then
        if ! nginx -t 2>/tmp/nginx-test.err; then
            log_error "Generated Nginx configuration is invalid:"
            cat /tmp/nginx-test.err >&2 || true
            exit 1
        fi
    fi
    return 0
}

###########################################
# SSL Configuration
###########################################
generate_ssl_config() {
    SSL_CERTIFICATE_FILE="${SSL_CERTIFICATE_FILE:-/etc/ssl/certs/cbox-selfsigned.crt}"
    SSL_PRIVATE_KEY_FILE="${SSL_PRIVATE_KEY_FILE:-/etc/ssl/private/cbox-selfsigned.key}"

    # Generate self-signed certificate if not present
    if [ ! -f "$SSL_CERTIFICATE_FILE" ] || [ ! -f "$SSL_PRIVATE_KEY_FILE" ]; then
        mkdir -p "$(dirname "$SSL_CERTIFICATE_FILE")" "$(dirname "$SSL_PRIVATE_KEY_FILE")"
        openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
            -keyout "$SSL_PRIVATE_KEY_FILE" \
            -out "$SSL_CERTIFICATE_FILE" \
            -subj "/CN=localhost" \
            -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" 2>/dev/null || \
        openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
            -keyout "$SSL_PRIVATE_KEY_FILE" \
            -out "$SSL_CERTIFICATE_FILE" \
            -subj "/CN=localhost" 2>/dev/null
        chmod 600 "$SSL_PRIVATE_KEY_FILE"
    fi

    : ${SSL_PROTOCOLS:=TLSv1.2 TLSv1.3}
    : ${SSL_CIPHERS:=ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384}
    # Cipher strings never legitimately contain shell/nginx metacharacters;
    # strip them so a supplied value can't inject directives.
    SSL_CIPHERS=$(sanitize_nginx_value "$SSL_CIPHERS")

    local ssl_mtls_config=""
    [ "${MTLS_ENABLED}" = "true" ] && [ -f "${MTLS_CLIENT_CA_FILE}" ] && \
        ssl_mtls_config="ssl_client_certificate ${MTLS_CLIENT_CA_FILE};
    ssl_verify_client ${MTLS_VERIFY_CLIENT};
    ssl_verify_depth ${MTLS_VERIFY_DEPTH};"

    cat >> /etc/nginx/conf.d/default.conf <<EOF

server {
    listen ${NGINX_HTTPS_PORT:-443} ssl ${NGINX_LISTEN_EXTRA};
    http2 on;
    server_name _;
    root ${NGINX_WEBROOT:-/var/www/html/public};
    index ${NGINX_INDEX:-index.php index.html};

    ssl_certificate ${SSL_CERTIFICATE_FILE};
    ssl_certificate_key ${SSL_PRIVATE_KEY_FILE};
    ssl_protocols ${SSL_PROTOCOLS};
    ssl_ciphers ${SSL_CIPHERS};
    ssl_prefer_server_ciphers off;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;

    ${ssl_mtls_config}

    client_max_body_size ${NGINX_CLIENT_MAX_BODY_SIZE:-100M};

    add_header Strict-Transport-Security "${SSL_HSTS_HEADER:-max-age=31536000; includeSubDomains}" always;
${NGINX_SECURITY_HEADERS}

    location / { try_files \$uri \$uri/ ${NGINX_TRY_FILES:-/index.php?\$query_string}; }

    location ~ \.php\$ {
        try_files \$uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass ${NGINX_FASTCGI_PASS:-127.0.0.1:9000};
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_param HTTP_X_FORWARDED_FOR \$proxy_add_x_forwarded_for;
        fastcgi_param HTTP_X_FORWARDED_PROTO \$forwarded_proto;
        fastcgi_param HTTP_X_FORWARDED_PORT \$forwarded_port;
        fastcgi_param HTTPS \$forwarded_https;
        fastcgi_param HTTP_X_FORWARDED_HOST \$host;
        fastcgi_param HTTP_X_REAL_IP \$remote_addr;
        fastcgi_param SSL_CLIENT_VERIFY \$ssl_client_verify;
        fastcgi_param SSL_CLIENT_S_DN \$ssl_client_s_dn;
        fastcgi_param SSL_CLIENT_I_DN \$ssl_client_i_dn;
        fastcgi_param SSL_CLIENT_SERIAL \$ssl_client_serial;
        fastcgi_param SSL_CLIENT_FINGERPRINT \$ssl_client_fingerprint;
    }

    # Internal nginx liveness (localhost only) for cbox-init's process check.
    # The app owns /health and /up; k8s should probe cbox-init's /tmp/cbox-ready.
    location = /healthz {
        allow 127.0.0.1;
        allow ::1;
        deny all;
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    location ~ /\.(env|git|svn|htpasswd) { deny all; return 404; }
    location ~ /(composer\.(json|lock)|package(-lock)?\.json|yarn\.lock|Dockerfile)$ { deny all; return 404; }
}
EOF

    # Redirect plaintext -> https, but ONLY for genuinely plaintext requests.
    # Behind a TLS-terminating proxy (Traefik/Cloudflare) the forwarded proto is
    # already https, so gating on $forwarded_proto avoids an infinite redirect loop.
    [ "$SSL_MODE" = "full" ] && cat > /etc/nginx/conf.d/http-redirect.conf <<EOF
server {
    listen ${NGINX_HTTP_PORT:-80};
    server_name _;
    # Redirect only genuine plaintext requests. If the forwarded proto is already
    # https, TLS was terminated upstream (SSL_MODE=full is misconfigured behind a
    # proxy) — return 404 instead of looping back to https.
    if (\$forwarded_proto = "http") { return 301 https://\$host\$request_uri; }
    return 404;
}
EOF
    return 0
}

###########################################
# Cbox Init Environment Variable Overrides
# The Go binary reads global config from YAML only (no env binding for
# api_enabled, api_port, etc.). This function copies the template config
# to /tmp and patches it with sed so that env vars like
# CBOX_INIT_API_ENABLED actually take effect.
###########################################
apply_cbox_init_env_overrides() {
    local src="${CBOX_INIT_CONFIG:-/etc/cbox-init/cbox-init.yaml}"
    local dst="/tmp/cbox-init.yaml"

    [ ! -f "$src" ] && return 0

    # The rendered config holds the management-API bearer token, so it must not
    # be world-readable. Create it 0600 (umask for the copy, chmod to be sure)
    # so other UIDs in the container — e.g. a compromised php-fpm worker — can't
    # read the token from /tmp.
    (umask 077 && cp "$src" "$dst")
    chmod 600 "$dst" 2>/dev/null || true

    # Escape a value for safe use on the RHS of a sed s### replacement.
    _sed_escape() { printf '%s' "$1" | sed 's/[&/\]/\\&/g'; }

    # Management API overrides
    [ -n "$CBOX_INIT_API_ENABLED" ] && sed -i "s/^\(\s*\)api_enabled:.*/\1api_enabled: $(_sed_escape "${CBOX_INIT_API_ENABLED}")/" "$dst"
    [ -n "$CBOX_INIT_API_PORT" ] && sed -i "s/^\(\s*\)api_port:.*/\1api_port: $(_sed_escape "${CBOX_INIT_API_PORT}")/" "$dst"
    [ -n "$CBOX_INIT_API_AUTH" ] && sed -i "s/^\(\s*\)api_auth:.*/\1api_auth: \"$(_sed_escape "${CBOX_INIT_API_AUTH}")\"/" "$dst"

    # Metrics overrides
    [ -n "$CBOX_INIT_METRICS_ENABLED" ] && sed -i "s/^\(\s*\)metrics_enabled:.*/\1metrics_enabled: $(_sed_escape "${CBOX_INIT_METRICS_ENABLED}")/" "$dst"
    [ -n "$CBOX_INIT_METRICS_PORT" ] && sed -i "s/^\(\s*\)metrics_port:.*/\1metrics_port: $(_sed_escape "${CBOX_INIT_METRICS_PORT}")/" "$dst"

    # Logging overrides
    [ -n "$CBOX_INIT_LOG_LEVEL" ] && sed -i "s/^\(\s*\)log_level:.*/\1log_level: $(_sed_escape "${CBOX_INIT_LOG_LEVEL}")/" "$dst"
    [ -n "$CBOX_INIT_LOG_FORMAT" ] && sed -i "s/^\(\s*\)log_format:.*/\1log_format: $(_sed_escape "${CBOX_INIT_LOG_FORMAT}")/" "$dst"

    # Shutdown timeout override
    [ -n "$CBOX_INIT_SHUTDOWN_TIMEOUT" ] && sed -i "s/^\(\s*\)shutdown_timeout:.*/\1shutdown_timeout: $(_sed_escape "${CBOX_INIT_SHUTDOWN_TIMEOUT}")/" "$dst"

    # Keep the nginx health-check port in sync with NGINX_HTTP_PORT, otherwise
    # cbox-init probes the hard-coded :80 and restart-loops nginx when the port
    # is overridden.
    if [ -n "${NGINX_HTTP_PORT}" ] && [ "${NGINX_HTTP_PORT}" != "80" ]; then
        sed -i "s#http://127.0.0.1:80/health#http://127.0.0.1:$(_sed_escape "${NGINX_HTTP_PORT}")/health#" "$dst"
    fi

    # Re-assert 0600 in case an in-place edit reset the mode (defence in depth;
    # GNU sed -i preserves it, but don't rely on that for a secret-bearing file).
    chmod 600 "$dst" 2>/dev/null || true

    export CBOX_INIT_CONFIG="$dst"
}

###########################################
# Cbox Init Validation
# NOTE: Similar to validate_cbox_init() from entrypoint-lib.sh but uses
# exit 1 instead of return 1 on failure. During container startup, a missing
# or broken cbox-init is fatal and must abort the entrypoint immediately.
###########################################
validate_cbox_init_local() {
    local config="${CBOX_INIT_CONFIG:-/etc/cbox-init/cbox-init.yaml}"

    if ! command -v cbox-init >/dev/null 2>&1; then
        log_error "Cbox Init binary not found"
        exit 1
    fi

    if [ ! -f "$config" ]; then
        log_warn "Cbox Init config not found, generating default..."
        if ! cbox-init scaffold --output "$config" 2>/dev/null; then
            log_error "Could not generate Cbox Init config"
            exit 1
        fi
    fi

    if ! cbox-init check-config --config "$config" >/dev/null 2>&1; then
        log_error "Cbox Init config validation failed"
        exit 1
    fi

    log_info "Cbox Init validated successfully"
}

###########################################
# Preflight Checks
###########################################
preflight_checks() {
    local warnings=0
    local workdir="${WORKDIR:-/var/www/html}"

    if [ -f "$workdir/artisan" ]; then
        log_info "Laravel application detected"

        # Check enabled services
        if is_true "${CBOX_INIT_PROCESS_HORIZON_ENABLED:-false}"; then
            [ -f "$workdir/composer.lock" ] && ! grep -q '"laravel/horizon"' "$workdir/composer.lock" 2>/dev/null && {
                log_warn "LARAVEL_HORIZON=true but laravel/horizon not found"
                warnings=$((warnings + 1))
            }
        fi

        if is_true "${CBOX_INIT_PROCESS_REVERB_ENABLED:-false}"; then
            [ -f "$workdir/composer.lock" ] && ! grep -q '"laravel/reverb"' "$workdir/composer.lock" 2>/dev/null && {
                log_warn "LARAVEL_REVERB=true but laravel/reverb not found"
                warnings=$((warnings + 1))
            }
        fi

        # Scaffold the Laravel storage tree first: a freshly-provisioned (empty)
        # volume mounted over storage/ otherwise lacks framework/{cache,sessions,
        # views} and logs/, and the app fatals ("directory does not exist").
        for d in framework/cache framework/sessions framework/views app/public logs; do
            mkdir -p "$workdir/storage/$d" 2>/dev/null || true
        done
        mkdir -p "$workdir/bootstrap/cache" 2>/dev/null || true

        # Auto-fix permissions if running as root (skip in rootless mode)
        if [ "$(id -u)" = "0" ] && ! is_rootless; then
            log_info "Auto-fixing Laravel directory permissions..."
            for dir in storage bootstrap/cache; do
                [ -d "$workdir/$dir" ] && {
                    chown -R www-data:www-data "$workdir/$dir" 2>/dev/null || true
                    chmod -R 775 "$workdir/$dir" 2>/dev/null || true
                }
            done
        fi
    fi

    validate_cbox_init_local

    [ $warnings -gt 0 ] && log_info "Preflight completed with $warnings warnings"
    return 0
}

###########################################
# Main Execution
###########################################
print_banner "Cbox Base Image" 2>/dev/null || {
    echo "╔═══════════════════════════════════════════════════════════════════════════╗"
    echo "║  Cbox Base Image                                                        ║"
    echo "╚═══════════════════════════════════════════════════════════════════════════╝"
}
log_info "PHP Version: $PHP_VERSION"

# Map environment variable aliases
map_env_aliases

# Setup PUID/PGID user permissions
setup_user_permissions_extended

# Decrypt Laravel .env.encrypted (uses lib function if available)
if command -v laravel_decrypt_env >/dev/null 2>&1; then
    laravel_decrypt_env "${WORKDIR:-/var/www/html}"
fi

# Run preflight checks
preflight_checks

# Generate runtime configs
generate_runtime_configs

# Set working directory
WORKDIR="${WORKDIR:-/var/www/html}"
cd "$WORKDIR" 2>/dev/null || cd /var/www/html

# Execute user-provided init scripts
if command -v run_init_scripts >/dev/null 2>&1; then
    run_init_scripts /docker-entrypoint-init.d
elif [ -d /docker-entrypoint-init.d ]; then
    for script in /docker-entrypoint-init.d/*.sh; do
        [ -x "$script" ] && {
            log_info "Running init script: $script"
            "$script" || log_warn "Init script $script failed"
        }
    done
fi

# Run migrations if enabled
# NOTE: Not using laravel_run_migrations() from entrypoint-lib.sh because this
# version supports LARAVEL_MIGRATE_ALLOW_FAILURE and can abort the container on
# failure, which the lib version does not (it always warns and continues).
if is_true "${LARAVEL_MIGRATE_ENABLED:-false}"; then
    [ -f "$WORKDIR/artisan" ] && {
        log_info "Running Laravel migrations..."
        migration_failed=0
        # --isolated takes an atomic cache lock so that when several replicas boot
        # together (rolling update) only ONE runs migrations; the others no-op
        # instead of racing on the schema and crash-looping.
        if [ "${APP_ENV:-production}" = "production" ]; then
            php artisan migrate --force --no-interaction --isolated 2>&1 || migration_failed=1
        else
            php artisan migrate --no-interaction --isolated 2>&1 || migration_failed=1
        fi
        if [ "$migration_failed" = "1" ]; then
            if is_true "${LARAVEL_MIGRATE_ALLOW_FAILURE:-false}"; then
                log_warn "Migration failed - continuing anyway (LARAVEL_MIGRATE_ALLOW_FAILURE=true)"
            else
                log_error "Migration failed - aborting container startup. Set LARAVEL_MIGRATE_ALLOW_FAILURE=true to continue on failure."
                exit 1
            fi
        fi
    }
fi

# Optimize Laravel caches (uses lib function if available)
if command -v laravel_optimize >/dev/null 2>&1; then
    laravel_optimize "$WORKDIR"
elif is_true "${LARAVEL_OPTIMIZE_ENABLED:-false}"; then
    [ -f "$WORKDIR/artisan" ] && {
        log_info "Optimizing Laravel caches..."
        php artisan config:cache 2>&1 || true
        php artisan route:cache 2>&1 || true
        php artisan view:cache 2>&1 || true
    }
fi

# If a custom command was passed (not cbox-init, not empty, not a flag),
# run it directly after setup instead of starting the process manager.
# This supports: docker run myimage php artisan migrate
#                docker run myimage bash
if [ $# -gt 0 ] && [ "$1" != "cbox-init" ] && [ "${1#-}" = "$1" ]; then
    log_info "Running custom command: $*"
    exec "$@"
fi

# --- PHP-FPM worker autotuning ----------------------------------------------
# cbox-init sizes php-fpm workers from the container's memory/CPU limits when a
# profile is set, exporting PHP_FPM_* which fpm-pool.conf expands. Autotune is on
# by default (profile: medium); an explicit PHP_FPM_MAX_CHILDREN pins the count
# and turns autotune off unless a profile is also given. The fallbacks below make
# the pool resolve even with autotune disabled (cbox-init overrides them when it
# runs, so the tuned values win).
if [ -n "${PHP_FPM_MAX_CHILDREN:-}" ]; then
    export PHP_FPM_AUTOTUNE_PROFILE="${PHP_FPM_AUTOTUNE_PROFILE:-}"   # manual sizing wins
else
    export PHP_FPM_AUTOTUNE_PROFILE="${PHP_FPM_AUTOTUNE_PROFILE-medium}"
fi
export PHP_FPM_MAX_CHILDREN="${PHP_FPM_MAX_CHILDREN:-10}"
export PHP_FPM_START_SERVERS="${PHP_FPM_START_SERVERS:-2}"
export PHP_FPM_MIN_SPARE="${PHP_FPM_MIN_SPARE:-1}"
export PHP_FPM_MAX_SPARE="${PHP_FPM_MAX_SPARE:-6}"
export PHP_FPM_MAX_REQUESTS="${PHP_FPM_MAX_REQUESTS:-500}"
[ -n "$PHP_FPM_AUTOTUNE_PROFILE" ] && log_info "PHP-FPM autotune: profile=$PHP_FPM_AUTOTUNE_PROFILE (memory-derived worker sizing)"

# --- Live config reload ------------------------------------------------------
# Watch mode reloads changed processes when the config file changes, and
# `cbox-init reload-config` / `scale` / `restart` apply changes over the Unix
# socket — daemons reload without a container restart. Disable with CBOX_INIT_WATCH=false.
CBOX_INIT_SERVE_ARGS=""
if is_true "${CBOX_INIT_WATCH:-true}"; then
    CBOX_INIT_SERVE_ARGS="--watch"
    log_info "Live config reload enabled (watch mode)"
fi

# Start Cbox Init
CBOX_INIT_CONFIG="${CBOX_INIT_CONFIG:-/etc/cbox-init/cbox-init.yaml}"
apply_cbox_init_env_overrides
log_info "Starting Cbox Init process manager"
log_info "Config: $CBOX_INIT_CONFIG"

exec /usr/local/bin/cbox-init serve --config "$CBOX_INIT_CONFIG" $CBOX_INIT_SERVE_ARGS "$@"
