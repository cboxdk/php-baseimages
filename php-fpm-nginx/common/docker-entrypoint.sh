#!/bin/bash
set -e

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  PHPeek Base Image - Docker Entrypoint                                    ║
# ║  Powered by PHPeek PM (Process Manager)                                   ║
# ║  https://github.com/gophpeek/phpeek-pm                                      ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
# shellcheck shell=bash

###########################################
# Lifecycle Warning (deprecation/preview)
###########################################
LIFECYCLE_CHECK="/usr/local/lib/phpeek/lifecycle-check.sh"
if [ -f "$LIFECYCLE_CHECK" ]; then
    # shellcheck source=/dev/null
    . "$LIFECYCLE_CHECK"
    phpeek_lifecycle_check
fi

# Source shared library
LIB_PATH="${PHPEEK_LIB_PATH:-/usr/local/lib/phpeek/entrypoint-lib.sh}"
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
        [ "${PHPEEK_ROOTLESS:-false}" = "true" ]
    }
fi

###########################################
# Signal Handling for Graceful Shutdown/Reload
###########################################
PHPEEK_PM_PID=""
PHP_FPM_PID=""
NGINX_PID=""

cleanup() {
    log_info "Received shutdown signal, cleaning up..."
    # Forward signal to PHPeek PM (it handles child processes)
    if [ -n "$PHPEEK_PM_PID" ] && kill -0 "$PHPEEK_PM_PID" 2>/dev/null; then
        kill -TERM "$PHPEEK_PM_PID" 2>/dev/null
        wait "$PHPEEK_PM_PID" 2>/dev/null
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
    if [ -n "$PHPEEK_PM_PID" ] && kill -0 "$PHPEEK_PM_PID" 2>/dev/null; then
        log_info "Forwarding reload to PHPeek PM..."
        kill -HUP "$PHPEEK_PM_PID" 2>/dev/null
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

    # Update ownership of common directories
    local workdir="${WORKDIR:-/var/www/html}"
    if [ -d "$workdir" ]; then
        log_info "Updating ownership of $workdir"
        chown -R "$app_user:$app_group" "$workdir" 2>/dev/null || true
    fi

    for dir in storage bootstrap/cache var/cache var/log; do
        if [ -d "$workdir/$dir" ]; then
            chown -R "$app_user:$app_group" "$workdir/$dir" 2>/dev/null || true
        fi
    done

    log_info "User permissions configured successfully"
}

###########################################
# Laravel .env Decryption Support
###########################################
decrypt_laravel_env() {
    local workdir="${WORKDIR:-/var/www/html}"
    local encrypted_file="$workdir/.env.encrypted"
    local env_file="$workdir/.env"
    local key=""

    [ ! -f "$encrypted_file" ] && return 0

    if [ -f "$env_file" ] && ! is_true "${LARAVEL_ENV_FORCE_DECRYPT:-false}"; then
        log_info ".env exists, skipping decryption (set LARAVEL_ENV_FORCE_DECRYPT=true to override)"
        return 0
    fi

    if [ -n "${LARAVEL_ENV_ENCRYPTION_KEY:-}" ]; then
        key="$LARAVEL_ENV_ENCRYPTION_KEY"
    elif [ -n "${LARAVEL_ENV_ENCRYPTION_KEY_FILE:-}" ] && [ -f "${LARAVEL_ENV_ENCRYPTION_KEY_FILE}" ]; then
        key=$(cat "${LARAVEL_ENV_ENCRYPTION_KEY_FILE}" | tr -d '\n')
    else
        log_warn ".env.encrypted found but no decryption key provided"
        return 0
    fi

    [ ! -f "$workdir/artisan" ] && { log_warn ".env.encrypted found but artisan not available"; return 0; }

    log_info "Decrypting .env.encrypted..."
    if php "$workdir/artisan" env:decrypt --key="$key" --force 2>&1; then
        log_info "Successfully decrypted .env"
        chmod 600 "$env_file" 2>/dev/null || true
    else
        log_error "Failed to decrypt .env.encrypted"
        return 1
    fi
}

###########################################
# Environment Variable Aliases (DX)
###########################################
map_env_aliases() {
    [ -n "$LARAVEL_HORIZON" ] && validate_boolean "$LARAVEL_HORIZON" && export PHPEEK_PM_PROCESS_HORIZON_ENABLED="$LARAVEL_HORIZON"
    [ -n "$LARAVEL_REVERB" ] && validate_boolean "$LARAVEL_REVERB" && export PHPEEK_PM_PROCESS_REVERB_ENABLED="$LARAVEL_REVERB"
    [ -n "$LARAVEL_SCHEDULER" ] && validate_boolean "$LARAVEL_SCHEDULER" && export PHPEEK_PM_PROCESS_SCHEDULER_ENABLED="$LARAVEL_SCHEDULER"
    [ -n "$LARAVEL_QUEUE" ] && validate_boolean "$LARAVEL_QUEUE" && export PHPEEK_PM_PROCESS_QUEUE_DEFAULT_ENABLED="$LARAVEL_QUEUE"
    [ -n "$LARAVEL_QUEUE_HIGH" ] && validate_boolean "$LARAVEL_QUEUE_HIGH" && export PHPEEK_PM_PROCESS_QUEUE_HIGH_ENABLED="$LARAVEL_QUEUE_HIGH"
    # Backward compatibility
    [ -n "$LARAVEL_SCHEDULER_ENABLED" ] && export PHPEEK_PM_PROCESS_SCHEDULER_ENABLED="$LARAVEL_SCHEDULER_ENABLED"
    [ -n "$LARAVEL_AUTO_MIGRATE" ] && export LARAVEL_MIGRATE_ENABLED="$LARAVEL_AUTO_MIGRATE"
    return 0
}

###########################################
# PHP Version Auto-Detection
###########################################
detect_php_version_local() {
    if command -v php >/dev/null 2>&1; then
        php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;"
    else
        echo "8.3"
    fi
}

PHP_VERSION=$(detect_php_version_local)

###########################################
# Runtime Configuration Generation
###########################################
generate_php_config() {
    local template="$1"
    local output="$2"
    [ -f "$template" ] && envsubst < "$template" > "$output" 2>/dev/null || true
}

generate_runtime_configs() {
    # PHP configuration
    generate_php_config "/usr/local/etc/php/conf.d/99-custom.ini.template" "/usr/local/etc/php/conf.d/99-custom.ini"
    generate_php_config "/etc/php/${PHP_VERSION}/fpm/conf.d/99-custom.ini.template" "/etc/php/${PHP_VERSION}/fpm/conf.d/99-custom.ini"

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
        export MTLS_ENABLED MTLS_CLIENT_CA_FILE MTLS_VERIFY_CLIENT MTLS_VERIFY_DEPTH

        # Trusted proxy configuration
        if [ -n "${NGINX_TRUSTED_PROXIES}" ]; then
            log_info "Configuring trusted proxies for real IP detection"
            NGINX_REAL_IP_CONFIG=""
            for proxy in ${NGINX_TRUSTED_PROXIES}; do
                NGINX_REAL_IP_CONFIG="${NGINX_REAL_IP_CONFIG}set_real_ip_from ${proxy};\n"
            done
            NGINX_REAL_IP_CONFIG="${NGINX_REAL_IP_CONFIG}real_ip_header ${NGINX_REAL_IP_HEADER};\nreal_ip_recursive ${NGINX_REAL_IP_RECURSIVE};"
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

        envsubst '${NGINX_HTTP_PORT} ${NGINX_HTTPS_PORT} ${NGINX_WEBROOT} ${NGINX_INDEX} ${NGINX_CLIENT_MAX_BODY_SIZE} ${NGINX_CLIENT_BODY_TIMEOUT} ${NGINX_CLIENT_HEADER_TIMEOUT} ${NGINX_SERVER_TOKENS} ${NGINX_ACCESS_LOG} ${NGINX_ERROR_LOG} ${NGINX_ERROR_LOG_LEVEL} ${NGINX_TRY_FILES} ${NGINX_FASTCGI_PASS} ${NGINX_FASTCGI_BUFFERS} ${NGINX_FASTCGI_BUFFER_SIZE} ${NGINX_FASTCGI_BUSY_BUFFERS_SIZE} ${NGINX_FASTCGI_CONNECT_TIMEOUT} ${NGINX_FASTCGI_SEND_TIMEOUT} ${NGINX_FASTCGI_READ_TIMEOUT} ${NGINX_STATIC_EXPIRES} ${NGINX_STATIC_CACHE_CONTROL} ${NGINX_STATIC_ACCESS_LOG} ${NGINX_GZIP} ${NGINX_GZIP_VARY} ${NGINX_GZIP_PROXIED} ${NGINX_GZIP_COMP_LEVEL} ${NGINX_GZIP_MIN_LENGTH} ${NGINX_GZIP_TYPES} ${NGINX_OPEN_FILE_CACHE} ${NGINX_OPEN_FILE_CACHE_VALID} ${NGINX_OPEN_FILE_CACHE_MIN_USES} ${NGINX_OPEN_FILE_CACHE_ERRORS} ${NGINX_REAL_IP_CONFIG} ${NGINX_MTLS_CONFIG} ${NGINX_SECURITY_HEADERS}' \
            < /etc/nginx/conf.d/default.conf.template \
            > /etc/nginx/conf.d/default.conf || {
            log_error "Failed to generate Nginx config"
            exit 1
        }
    fi

    # SSL configuration
    [ -n "${SSL_MODE}" ] && [ "${SSL_MODE}" != "off" ] && generate_ssl_config
    return 0
}

###########################################
# SSL Configuration
###########################################
generate_ssl_config() {
    SSL_CERTIFICATE_FILE="${SSL_CERTIFICATE_FILE:-/etc/ssl/certs/phpeek-selfsigned.crt}"
    SSL_PRIVATE_KEY_FILE="${SSL_PRIVATE_KEY_FILE:-/etc/ssl/private/phpeek-selfsigned.key}"

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

    local ssl_mtls_config=""
    [ "${MTLS_ENABLED}" = "true" ] && [ -f "${MTLS_CLIENT_CA_FILE}" ] && \
        ssl_mtls_config="ssl_client_certificate ${MTLS_CLIENT_CA_FILE};
    ssl_verify_client ${MTLS_VERIFY_CLIENT};
    ssl_verify_depth ${MTLS_VERIFY_DEPTH};"

    cat >> /etc/nginx/conf.d/default.conf <<EOF

server {
    listen ${NGINX_HTTPS_PORT:-443} ssl http2;
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
        fastcgi_param HTTP_X_FORWARDED_PROTO \$scheme;
        fastcgi_param HTTP_X_FORWARDED_HOST \$host;
        fastcgi_param HTTP_X_REAL_IP \$remote_addr;
        fastcgi_param SSL_CLIENT_VERIFY \$ssl_client_verify;
        fastcgi_param SSL_CLIENT_S_DN \$ssl_client_s_dn;
        fastcgi_param SSL_CLIENT_I_DN \$ssl_client_i_dn;
        fastcgi_param SSL_CLIENT_SERIAL \$ssl_client_serial;
        fastcgi_param SSL_CLIENT_FINGERPRINT \$ssl_client_fingerprint;
    }

    location /health {
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

    [ "$SSL_MODE" = "full" ] && cat > /etc/nginx/conf.d/http-redirect.conf <<EOF
server { listen ${NGINX_HTTP_PORT:-80}; server_name _; return 301 https://\$host\$request_uri; }
EOF
    return 0
}

###########################################
# PHPeek PM Validation
###########################################
validate_phpeek_pm_local() {
    local config="${PHPEEK_PM_CONFIG:-/etc/phpeek-pm/phpeek-pm.yaml}"

    if ! command -v phpeek-pm >/dev/null 2>&1; then
        log_error "PHPeek PM binary not found"
        exit 1
    fi

    if [ ! -f "$config" ]; then
        log_warn "PHPeek PM config not found, generating default..."
        if ! phpeek-pm scaffold --output "$config" 2>/dev/null; then
            log_error "Could not generate PHPeek PM config"
            exit 1
        fi
    fi

    if ! phpeek-pm check-config --config "$config" >/dev/null 2>&1; then
        log_error "PHPeek PM config validation failed"
        exit 1
    fi

    log_info "PHPeek PM validated successfully"
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
        if is_true "${PHPEEK_PM_PROCESS_HORIZON_ENABLED:-false}"; then
            [ -f "$workdir/composer.lock" ] && ! grep -q '"laravel/horizon"' "$workdir/composer.lock" 2>/dev/null && {
                log_warn "LARAVEL_HORIZON=true but laravel/horizon not found"
                warnings=$((warnings + 1))
            }
        fi

        if is_true "${PHPEEK_PM_PROCESS_REVERB_ENABLED:-false}"; then
            [ -f "$workdir/composer.lock" ] && ! grep -q '"laravel/reverb"' "$workdir/composer.lock" 2>/dev/null && {
                log_warn "LARAVEL_REVERB=true but laravel/reverb not found"
                warnings=$((warnings + 1))
            }
        fi

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

    validate_phpeek_pm_local

    [ $warnings -gt 0 ] && log_info "Preflight completed with $warnings warnings"
    return 0
}

###########################################
# Main Execution
###########################################
print_banner "PHPeek Base Image" 2>/dev/null || {
    echo "╔═══════════════════════════════════════════════════════════════════════════╗"
    echo "║  PHPeek Base Image                                                        ║"
    echo "╚═══════════════════════════════════════════════════════════════════════════╝"
}
log_info "PHP Version: $PHP_VERSION"

# Map environment variable aliases
map_env_aliases

# Setup PUID/PGID user permissions
setup_user_permissions_extended

# Decrypt Laravel .env.encrypted
decrypt_laravel_env

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
if is_true "${LARAVEL_MIGRATE_ENABLED:-false}"; then
    [ -f "$WORKDIR/artisan" ] && {
        log_info "Running Laravel migrations..."
        if [ "${APP_ENV:-production}" = "production" ]; then
            php artisan migrate --force --no-interaction 2>&1 || log_warn "Migration failed"
        else
            php artisan migrate --no-interaction 2>&1 || log_warn "Migration failed"
        fi
    }
fi

# Optimize Laravel caches
if is_true "${LARAVEL_OPTIMIZE_ENABLED:-false}"; then
    [ -f "$WORKDIR/artisan" ] && {
        log_info "Optimizing Laravel caches..."
        php artisan config:cache 2>&1 || true
        php artisan route:cache 2>&1 || true
        php artisan view:cache 2>&1 || true
    }
fi

# Start PHPeek PM
PHPEEK_PM_CONFIG="${PHPEEK_PM_CONFIG:-/etc/phpeek-pm/phpeek-pm.yaml}"
log_info "Starting PHPeek PM process manager"
log_info "Config: $PHPEEK_PM_CONFIG"

exec /usr/local/bin/phpeek-pm serve --config "$PHPEEK_PM_CONFIG" "$@"
