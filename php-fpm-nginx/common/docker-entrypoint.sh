#!/bin/bash
set -e

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  PHPeek Base Image - Docker Entrypoint                                    ║
# ║  Powered by PHPeek PM (Process Manager)                                   ║
# ║  https://github.com/phpeek/phpeek-pm                                      ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

###########################################
# Signal Handling for Graceful Shutdown/Reload
###########################################
# Track child PIDs for signal forwarding
PHPEEK_PM_PID=""
PHP_FPM_PID=""
NGINX_PID=""

cleanup() {
    echo "Received shutdown signal, cleaning up..."
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
    echo "Received SIGHUP, reloading services..."
    # Reload PHP-FPM (graceful restart of workers)
    if [ -n "$PHP_FPM_PID" ] && kill -0 "$PHP_FPM_PID" 2>/dev/null; then
        echo "Reloading PHP-FPM..."
        kill -USR2 "$PHP_FPM_PID" 2>/dev/null
    fi
    # Reload Nginx configuration
    if [ -n "$NGINX_PID" ] && kill -0 "$NGINX_PID" 2>/dev/null; then
        echo "Reloading Nginx..."
        kill -HUP "$NGINX_PID" 2>/dev/null
    fi
    # If PHPeek PM is managing processes, let it handle reload
    if [ -n "$PHPEEK_PM_PID" ] && kill -0 "$PHPEEK_PM_PID" 2>/dev/null; then
        echo "Forwarding reload to PHPeek PM..."
        kill -HUP "$PHPEEK_PM_PID" 2>/dev/null
    fi
}

trap cleanup SIGTERM SIGINT SIGQUIT
trap graceful_reload SIGHUP

###########################################
# Input Validation Functions (Security)
###########################################
validate_path() {
    local path="$1"
    local allowed_prefix="$2"

    # Ensure path doesn't contain path traversal
    case "$path" in
        *..*)
            echo "ERROR: Path traversal detected in: $path" >&2
            return 1
            ;;
    esac

    # Ensure path starts with allowed prefix
    case "$path" in
        ${allowed_prefix}*)
            echo "$path"
            return 0
            ;;
        *)
            echo "ERROR: Invalid path (must start with $allowed_prefix): $path" >&2
            return 1
            ;;
    esac
}

validate_boolean() {
    local value="$1"
    case "$value" in
        true|false|TRUE|FALSE|1|0|yes|no|YES|NO|"")
            return 0
            ;;
        *)
            echo "WARNING: Invalid boolean value: $value (using 'false')" >&2
            return 1
            ;;
    esac
}

sanitize_nginx_value() {
    # Remove potentially dangerous characters from nginx config values
    echo "$1" | sed 's/[;{}$`\\]//g'
}

###########################################
# PUID/PGID Runtime User Mapping
###########################################
# Allows running containers with custom user/group IDs
# Useful for: NFS volumes, host filesystem permissions, rootless containers
# Usage: docker run -e PUID=1000 -e PGID=1000 ...

setup_user_permissions() {
    local target_uid="${PUID:-}"
    local target_gid="${PGID:-}"
    local app_user="${APP_USER:-www-data}"
    local app_group="${APP_GROUP:-www-data}"

    # Skip if no PUID/PGID specified
    if [ -z "$target_uid" ] && [ -z "$target_gid" ]; then
        return 0
    fi

    # Only root can change ownership
    if [ "$(id -u)" != "0" ]; then
        echo "WARNING: PUID/PGID specified but not running as root - skipping user mapping"
        return 0
    fi

    # Validate numeric values (SECURITY: prevent injection)
    if [ -n "$target_uid" ] && ! echo "$target_uid" | grep -qE '^[0-9]+$'; then
        echo "ERROR: PUID must be a numeric value, got: $target_uid" >&2
        return 1
    fi
    if [ -n "$target_gid" ] && ! echo "$target_gid" | grep -qE '^[0-9]+$'; then
        echo "ERROR: PGID must be a numeric value, got: $target_gid" >&2
        return 1
    fi

    echo "INFO: Setting up PUID=${target_uid:-unchanged} PGID=${target_gid:-unchanged}"

    # Modify group if PGID specified
    if [ -n "$target_gid" ]; then
        local current_gid=$(id -g "$app_user" 2>/dev/null || echo "")
        if [ "$current_gid" != "$target_gid" ]; then
            # Check if target GID already exists
            if getent group "$target_gid" >/dev/null 2>&1; then
                local existing_group=$(getent group "$target_gid" | cut -d: -f1)
                echo "INFO: GID $target_gid already exists as group '$existing_group'"
            else
                groupmod -g "$target_gid" "$app_group" 2>/dev/null || \
                    addgroup -g "$target_gid" "$app_group" 2>/dev/null || \
                    groupadd -g "$target_gid" "$app_group" 2>/dev/null || true
            fi
        fi
    fi

    # Modify user if PUID specified
    if [ -n "$target_uid" ]; then
        local current_uid=$(id -u "$app_user" 2>/dev/null || echo "")
        if [ "$current_uid" != "$target_uid" ]; then
            # Check if target UID already exists
            if getent passwd "$target_uid" >/dev/null 2>&1; then
                local existing_user=$(getent passwd "$target_uid" | cut -d: -f1)
                echo "INFO: UID $target_uid already exists as user '$existing_user'"
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
        echo "INFO: Updating ownership of $workdir"
        chown -R "$app_user:$app_group" "$workdir" 2>/dev/null || true
    fi

    # Update ownership of storage directories (Laravel/Symfony)
    for dir in storage bootstrap/cache var/cache var/log; do
        if [ -d "$workdir/$dir" ]; then
            chown -R "$app_user:$app_group" "$workdir/$dir" 2>/dev/null || true
        fi
    done

    echo "INFO: User permissions configured successfully"
}

###########################################
# Laravel .env Decryption Support
###########################################
# Automatically decrypt .env.encrypted files at runtime
# Usage: docker run -e LARAVEL_ENV_ENCRYPTION_KEY=base64:xxx ...
# or: LARAVEL_ENV_ENCRYPTION_KEY_FILE=/run/secrets/env_key

decrypt_laravel_env() {
    local workdir="${WORKDIR:-/var/www/html}"
    local encrypted_file="$workdir/.env.encrypted"
    local env_file="$workdir/.env"
    local key=""

    # Skip if no encrypted file exists
    if [ ! -f "$encrypted_file" ]; then
        return 0
    fi

    # Skip if .env already exists and not forced
    if [ -f "$env_file" ] && [ "${LARAVEL_ENV_FORCE_DECRYPT:-false}" != "true" ]; then
        echo "INFO: .env exists, skipping decryption (set LARAVEL_ENV_FORCE_DECRYPT=true to override)"
        return 0
    fi

    # Get decryption key from env var or secret file
    if [ -n "${LARAVEL_ENV_ENCRYPTION_KEY:-}" ]; then
        key="$LARAVEL_ENV_ENCRYPTION_KEY"
    elif [ -n "${LARAVEL_ENV_ENCRYPTION_KEY_FILE:-}" ] && [ -f "${LARAVEL_ENV_ENCRYPTION_KEY_FILE}" ]; then
        key=$(cat "${LARAVEL_ENV_ENCRYPTION_KEY_FILE}" | tr -d '\n')
    else
        echo "WARNING: .env.encrypted found but no decryption key provided"
        echo "         Set LARAVEL_ENV_ENCRYPTION_KEY or LARAVEL_ENV_ENCRYPTION_KEY_FILE"
        return 0
    fi

    # Check if artisan exists
    if [ ! -f "$workdir/artisan" ]; then
        echo "WARNING: .env.encrypted found but artisan not available - cannot decrypt"
        return 0
    fi

    echo "INFO: Decrypting .env.encrypted..."

    # Use Laravel's env:decrypt command
    if php "$workdir/artisan" env:decrypt --key="$key" --force 2>&1; then
        echo "INFO: Successfully decrypted .env"
        chmod 600 "$env_file" 2>/dev/null || true
    else
        echo "ERROR: Failed to decrypt .env.encrypted" >&2
        echo "       Check your LARAVEL_ENV_ENCRYPTION_KEY" >&2
        return 1
    fi
}

###########################################
# Environment Variable Aliases (DX)
###########################################
# Map friendly Laravel-style env vars to PHPeek PM format
# Users can use either format!

[ -n "$LARAVEL_HORIZON" ] && validate_boolean "$LARAVEL_HORIZON" && export PHPEEK_PM_PROCESS_HORIZON_ENABLED="$LARAVEL_HORIZON"
[ -n "$LARAVEL_REVERB" ] && validate_boolean "$LARAVEL_REVERB" && export PHPEEK_PM_PROCESS_REVERB_ENABLED="$LARAVEL_REVERB"
[ -n "$LARAVEL_SCHEDULER" ] && validate_boolean "$LARAVEL_SCHEDULER" && export PHPEEK_PM_PROCESS_SCHEDULER_ENABLED="$LARAVEL_SCHEDULER"
[ -n "$LARAVEL_QUEUE" ] && validate_boolean "$LARAVEL_QUEUE" && export PHPEEK_PM_PROCESS_QUEUE_DEFAULT_ENABLED="$LARAVEL_QUEUE"
[ -n "$LARAVEL_QUEUE_HIGH" ] && validate_boolean "$LARAVEL_QUEUE_HIGH" && export PHPEEK_PM_PROCESS_QUEUE_HIGH_ENABLED="$LARAVEL_QUEUE_HIGH"

# Backward compatibility
[ -n "$LARAVEL_SCHEDULER_ENABLED" ] && export PHPEEK_PM_PROCESS_SCHEDULER_ENABLED="$LARAVEL_SCHEDULER_ENABLED"
[ -n "$LARAVEL_AUTO_MIGRATE" ] && export LARAVEL_MIGRATE_ENABLED="$LARAVEL_AUTO_MIGRATE"

###########################################
# PHP Version Auto-Detection
###########################################
detect_php_version() {
    if command -v php >/dev/null 2>&1; then
        php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;"
    else
        echo "8.3"  # Fallback
    fi
}

PHP_VERSION=$(detect_php_version)

###########################################
# Runtime Configuration Generation
###########################################
generate_php_config() {
    local template="$1"
    local output="$2"

    if [ -f "$template" ]; then
        # Use envsubst instead of eval (SECURITY: prevents code injection)
        envsubst < "$template" > "$output" 2>/dev/null || {
            echo "WARNING: Failed to generate PHP config from $template" >&2
        }
    fi
}

generate_runtime_configs() {
    # Generate PHP configuration from template (Alpine path)
    generate_php_config \
        "/usr/local/etc/php/conf.d/99-custom.ini.template" \
        "/usr/local/etc/php/conf.d/99-custom.ini"

    # Generate PHP configuration (Debian/Ubuntu path - auto-detected version)
    generate_php_config \
        "/etc/php/${PHP_VERSION}/fpm/conf.d/99-custom.ini.template" \
        "/etc/php/${PHP_VERSION}/fpm/conf.d/99-custom.ini"

    # Generate Nginx configuration from template
    if [ -f /etc/nginx/conf.d/default.conf.template ]; then
        # Set defaults with sanitization
        : ${NGINX_HTTP_PORT:=80}
        : ${NGINX_HTTPS_PORT:=443}
        : ${NGINX_WEBROOT:=/var/www/html/public}
        : ${NGINX_INDEX:=index.php index.html}
        : ${NGINX_CLIENT_MAX_BODY_SIZE:=100M}
        : ${NGINX_CLIENT_BODY_TIMEOUT:=60s}
        : ${NGINX_CLIENT_HEADER_TIMEOUT:=60s}
        : ${NGINX_HEADER_X_FRAME_OPTIONS:=SAMEORIGIN}
        : ${NGINX_HEADER_X_CONTENT_TYPE_OPTIONS:=nosniff}
        : ${NGINX_HEADER_X_XSS_PROTECTION:=1; mode=block}
        : ${NGINX_HEADER_CSP:=default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self'; frame-ancestors 'self'}
        : ${NGINX_HEADER_REFERRER_POLICY:=strict-origin-when-cross-origin}
        # Cross-Origin Isolation headers (opt-in - these break most apps with external APIs/CDNs/analytics)
        # Enable for advanced security: NGINX_HEADER_COOP=same-origin NGINX_HEADER_COEP=require-corp NGINX_HEADER_CORP=same-origin
        : ${NGINX_HEADER_COOP:=}
        : ${NGINX_HEADER_COEP:=}
        : ${NGINX_HEADER_CORP:=}
        : ${NGINX_HEADER_PERMISSIONS_POLICY:=accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=()}
        : ${NGINX_SERVER_TOKENS:=off}
        # NGINX_ACCESS_LOG: Set to "off", "false", or "/dev/null" to disable access logging
        # This is useful for reducing disk I/O and log noise in high-traffic scenarios
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

        # Gzip compression (set NGINX_GZIP=off to disable)
        : ${NGINX_GZIP:=on}
        : ${NGINX_GZIP_VARY:=on}
        : ${NGINX_GZIP_PROXIED:=any}
        : ${NGINX_GZIP_COMP_LEVEL:=6}
        : ${NGINX_GZIP_MIN_LENGTH:=1000}
        : ${NGINX_GZIP_TYPES:=text/plain text/css text/xml text/javascript application/json application/javascript application/xml application/xml+rss application/x-javascript image/svg+xml}

        # Open file cache (set NGINX_OPEN_FILE_CACHE=off to disable)
        : ${NGINX_OPEN_FILE_CACHE:=max=10000 inactive=20s}
        : ${NGINX_OPEN_FILE_CACHE_VALID:=30s}
        : ${NGINX_OPEN_FILE_CACHE_MIN_USES:=2}
        : ${NGINX_OPEN_FILE_CACHE_ERRORS:=on}

        # Reverse proxy / tunnel support (Cloudflare, HAProxy, Traefik, Tailscale, etc.)
        # NGINX_TRUSTED_PROXIES: Space-separated list of trusted proxy IPs/CIDRs
        # Common values:
        #   - Cloudflare: "173.245.48.0/20 103.21.244.0/22 103.22.200.0/22 103.31.4.0/22 141.101.64.0/18 108.162.192.0/18 190.93.240.0/20 188.114.96.0/20 197.234.240.0/22 198.41.128.0/17 162.158.0.0/15 104.16.0.0/13 104.24.0.0/14 172.64.0.0/13 131.0.72.0/22"
        #   - Private networks: "10.0.0.0/8 172.16.0.0/12 192.168.0.0/16"
        #   - Docker networks: "172.16.0.0/12"
        #   - Tailscale: "100.64.0.0/10"
        : ${NGINX_TRUSTED_PROXIES:=}
        : ${NGINX_REAL_IP_HEADER:=X-Forwarded-For}
        : ${NGINX_REAL_IP_RECURSIVE:=on}

        # mTLS (Mutual TLS) - Client certificate authentication (optional)
        # Use for zero-trust networks, service mesh, or API authentication
        : ${MTLS_ENABLED:=false}
        : ${MTLS_CLIENT_CA_FILE:=/etc/ssl/certs/client-ca.crt}
        : ${MTLS_VERIFY_CLIENT:=optional}
        : ${MTLS_VERIFY_DEPTH:=2}

        export NGINX_HTTP_PORT NGINX_HTTPS_PORT NGINX_WEBROOT NGINX_INDEX
        export NGINX_CLIENT_MAX_BODY_SIZE NGINX_CLIENT_BODY_TIMEOUT NGINX_CLIENT_HEADER_TIMEOUT
        export NGINX_HEADER_X_FRAME_OPTIONS NGINX_HEADER_X_CONTENT_TYPE_OPTIONS NGINX_HEADER_X_XSS_PROTECTION NGINX_HEADER_CSP
        export NGINX_HEADER_REFERRER_POLICY NGINX_HEADER_COOP NGINX_HEADER_COEP NGINX_HEADER_CORP NGINX_HEADER_PERMISSIONS_POLICY
        export NGINX_SERVER_TOKENS
        export NGINX_ACCESS_LOG NGINX_ERROR_LOG NGINX_ERROR_LOG_LEVEL NGINX_TRY_FILES
        export NGINX_FASTCGI_PASS NGINX_FASTCGI_BUFFERS NGINX_FASTCGI_BUFFER_SIZE NGINX_FASTCGI_BUSY_BUFFERS_SIZE
        export NGINX_FASTCGI_CONNECT_TIMEOUT NGINX_FASTCGI_SEND_TIMEOUT NGINX_FASTCGI_READ_TIMEOUT
        export NGINX_STATIC_EXPIRES NGINX_STATIC_CACHE_CONTROL NGINX_STATIC_ACCESS_LOG
        export NGINX_GZIP NGINX_GZIP_VARY NGINX_GZIP_PROXIED NGINX_GZIP_COMP_LEVEL NGINX_GZIP_MIN_LENGTH NGINX_GZIP_TYPES
        export NGINX_OPEN_FILE_CACHE NGINX_OPEN_FILE_CACHE_VALID NGINX_OPEN_FILE_CACHE_MIN_USES NGINX_OPEN_FILE_CACHE_ERRORS
        export NGINX_TRUSTED_PROXIES NGINX_REAL_IP_HEADER NGINX_REAL_IP_RECURSIVE
        export MTLS_ENABLED MTLS_CLIENT_CA_FILE MTLS_VERIFY_CLIENT MTLS_VERIFY_DEPTH

        # Generate trusted proxy configuration if set
        if [ -n "${NGINX_TRUSTED_PROXIES}" ]; then
            echo "INFO: Configuring trusted proxies for real IP detection"
            NGINX_REAL_IP_CONFIG=""
            for proxy in ${NGINX_TRUSTED_PROXIES}; do
                NGINX_REAL_IP_CONFIG="${NGINX_REAL_IP_CONFIG}set_real_ip_from ${proxy};\n"
            done
            NGINX_REAL_IP_CONFIG="${NGINX_REAL_IP_CONFIG}real_ip_header ${NGINX_REAL_IP_HEADER};\nreal_ip_recursive ${NGINX_REAL_IP_RECURSIVE};"
            export NGINX_REAL_IP_CONFIG
        else
            export NGINX_REAL_IP_CONFIG="# No trusted proxies configured (set NGINX_TRUSTED_PROXIES to enable)"
        fi

        # Generate mTLS configuration if enabled
        if [ "${MTLS_ENABLED}" = "true" ]; then
            if [ -f "${MTLS_CLIENT_CA_FILE}" ]; then
                echo "INFO: Configuring mTLS client certificate authentication"
                export NGINX_MTLS_CONFIG="ssl_client_certificate ${MTLS_CLIENT_CA_FILE};\n    ssl_verify_client ${MTLS_VERIFY_CLIENT};\n    ssl_verify_depth ${MTLS_VERIFY_DEPTH};"
            else
                echo "WARNING: mTLS enabled but client CA file not found: ${MTLS_CLIENT_CA_FILE}"
                export NGINX_MTLS_CONFIG="# mTLS enabled but CA file missing: ${MTLS_CLIENT_CA_FILE}"
            fi
        else
            export NGINX_MTLS_CONFIG="# mTLS disabled (set MTLS_ENABLED=true to enable)"
        fi

        envsubst '${NGINX_HTTP_PORT} ${NGINX_HTTPS_PORT} ${NGINX_WEBROOT} ${NGINX_INDEX} ${NGINX_CLIENT_MAX_BODY_SIZE} ${NGINX_CLIENT_BODY_TIMEOUT} ${NGINX_CLIENT_HEADER_TIMEOUT} ${NGINX_HEADER_X_FRAME_OPTIONS} ${NGINX_HEADER_X_CONTENT_TYPE_OPTIONS} ${NGINX_HEADER_X_XSS_PROTECTION} ${NGINX_HEADER_CSP} ${NGINX_HEADER_REFERRER_POLICY} ${NGINX_HEADER_COOP} ${NGINX_HEADER_COEP} ${NGINX_HEADER_CORP} ${NGINX_HEADER_PERMISSIONS_POLICY} ${NGINX_SERVER_TOKENS} ${NGINX_ACCESS_LOG} ${NGINX_ERROR_LOG} ${NGINX_ERROR_LOG_LEVEL} ${NGINX_TRY_FILES} ${NGINX_FASTCGI_PASS} ${NGINX_FASTCGI_BUFFERS} ${NGINX_FASTCGI_BUFFER_SIZE} ${NGINX_FASTCGI_BUSY_BUFFERS_SIZE} ${NGINX_FASTCGI_CONNECT_TIMEOUT} ${NGINX_FASTCGI_SEND_TIMEOUT} ${NGINX_FASTCGI_READ_TIMEOUT} ${NGINX_STATIC_EXPIRES} ${NGINX_STATIC_CACHE_CONTROL} ${NGINX_STATIC_ACCESS_LOG} ${NGINX_GZIP} ${NGINX_GZIP_VARY} ${NGINX_GZIP_PROXIED} ${NGINX_GZIP_COMP_LEVEL} ${NGINX_GZIP_MIN_LENGTH} ${NGINX_GZIP_TYPES} ${NGINX_OPEN_FILE_CACHE} ${NGINX_OPEN_FILE_CACHE_VALID} ${NGINX_OPEN_FILE_CACHE_MIN_USES} ${NGINX_OPEN_FILE_CACHE_ERRORS} ${NGINX_REAL_IP_CONFIG} ${NGINX_MTLS_CONFIG}' \
            < /etc/nginx/conf.d/default.conf.template \
            > /etc/nginx/conf.d/default.conf || {
            echo "ERROR: Failed to generate Nginx config" >&2
            exit 1
        }
    fi

    # Handle SSL configuration if enabled
    if [ -n "${SSL_MODE}" ] && [ "${SSL_MODE}" != "off" ]; then
        generate_ssl_config
    fi
}

###########################################
# SSL Configuration (if enabled)
###########################################
generate_ssl_config() {
    # Validate SSL paths (SECURITY: prevent path traversal)
    SSL_CERTIFICATE_FILE=$(validate_path "${SSL_CERTIFICATE_FILE:-/etc/ssl/certs/phpeek-selfsigned.crt}" "/etc/ssl") || {
        echo "ERROR: Invalid SSL certificate path" >&2
        exit 1
    }
    SSL_PRIVATE_KEY_FILE=$(validate_path "${SSL_PRIVATE_KEY_FILE:-/etc/ssl/private/phpeek-selfsigned.key}" "/etc/ssl") || {
        echo "ERROR: Invalid SSL private key path" >&2
        exit 1
    }

    # Generate self-signed certificate if not present
    if [ ! -f "$SSL_CERTIFICATE_FILE" ] || [ ! -f "$SSL_PRIVATE_KEY_FILE" ]; then
        mkdir -p "$(dirname "$SSL_CERTIFICATE_FILE")" "$(dirname "$SSL_PRIVATE_KEY_FILE")"

        # Use RSA 4096 (stronger) with SAN for modern browsers
        openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
            -keyout "$SSL_PRIVATE_KEY_FILE" \
            -out "$SSL_CERTIFICATE_FILE" \
            -subj "/CN=localhost" \
            -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" 2>/dev/null || {
            # Fallback for older OpenSSL without -addext
            openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
                -keyout "$SSL_PRIVATE_KEY_FILE" \
                -out "$SSL_CERTIFICATE_FILE" \
                -subj "/CN=localhost" 2>/dev/null
        }

        chmod 600 "$SSL_PRIVATE_KEY_FILE"
    fi

    # Use modern cipher suite (Mozilla Modern)
    : ${SSL_PROTOCOLS:=TLSv1.2 TLSv1.3}
    : ${SSL_CIPHERS:=ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384}

    # Generate mTLS config for SSL block (reuse from earlier)
    local ssl_mtls_config=""
    if [ "${MTLS_ENABLED}" = "true" ] && [ -f "${MTLS_CLIENT_CA_FILE}" ]; then
        ssl_mtls_config="ssl_client_certificate ${MTLS_CLIENT_CA_FILE};
    ssl_verify_client ${MTLS_VERIFY_CLIENT};
    ssl_verify_depth ${MTLS_VERIFY_DEPTH};"
    fi

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

    # mTLS Client Certificate Authentication (optional)
    # Enable with: MTLS_ENABLED=true MTLS_CLIENT_CA_FILE=/path/to/ca.crt
    ${ssl_mtls_config}

    client_max_body_size ${NGINX_CLIENT_MAX_BODY_SIZE:-100M};

    # Security Headers
    add_header Strict-Transport-Security "${SSL_HSTS_HEADER:-max-age=31536000; includeSubDomains}" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Content-Security-Policy "${NGINX_HEADER_CSP}" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    location / { try_files \$uri \$uri/ ${NGINX_TRY_FILES:-/index.php?\$query_string}; }

    location ~ \.php\$ {
        try_files \$uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass ${NGINX_FASTCGI_PASS:-127.0.0.1:9000};
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;

        # Proxy headers for trusted proxy detection
        fastcgi_param HTTP_X_FORWARDED_FOR \$proxy_add_x_forwarded_for;
        fastcgi_param HTTP_X_FORWARDED_PROTO \$scheme;
        fastcgi_param HTTP_X_FORWARDED_HOST \$host;
        fastcgi_param HTTP_X_REAL_IP \$remote_addr;

        # mTLS client certificate info (pass to PHP)
        fastcgi_param SSL_CLIENT_VERIFY \$ssl_client_verify;
        fastcgi_param SSL_CLIENT_S_DN \$ssl_client_s_dn;
        fastcgi_param SSL_CLIENT_I_DN \$ssl_client_i_dn;
        fastcgi_param SSL_CLIENT_SERIAL \$ssl_client_serial;
        fastcgi_param SSL_CLIENT_FINGERPRINT \$ssl_client_fingerprint;
    }

    # Health check (localhost only)
    location /health {
        allow 127.0.0.1;
        allow ::1;
        deny all;
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # Block sensitive files
    location ~ /\.(env|git|svn|htpasswd) { deny all; return 404; }
    location ~ /(composer\.(json|lock)|package(-lock)?\.json|yarn\.lock|Dockerfile)$ { deny all; return 404; }
}
EOF

    # HTTPS redirect for full SSL mode
    if [ "$SSL_MODE" = "full" ]; then
        cat > /etc/nginx/conf.d/http-redirect.conf <<EOF
server { listen ${NGINX_HTTP_PORT:-80}; server_name _; return 301 https://\$host\$request_uri; }
EOF
    fi
}

###########################################
# PHPeek PM Validation (REQUIRED - No Fallback)
###########################################
validate_phpeek_pm() {
    local config="${PHPEEK_PM_CONFIG:-/etc/phpeek-pm/phpeek-pm.yaml}"

    # Check if PHPeek PM binary exists (REQUIRED)
    if ! command -v phpeek-pm >/dev/null 2>&1; then
        echo "ERROR: PHPeek PM binary not found at /usr/local/bin/phpeek-pm" >&2
        echo "       This is a critical error - PHPeek PM is required for this image." >&2
        echo "       The image may be corrupted. Please pull a fresh image." >&2
        exit 1
    fi

    # Check if config exists (REQUIRED)
    if [ ! -f "$config" ]; then
        echo "ERROR: PHPeek PM config not found at $config" >&2
        echo "       Attempting to generate default config..." >&2
        if phpeek-pm scaffold --output "$config" 2>/dev/null; then
            echo "INFO: Generated default PHPeek PM config"
        else
            echo "ERROR: Could not generate PHPeek PM config" >&2
            echo "       Please ensure /etc/phpeek-pm/ is writable" >&2
            exit 1
        fi
    fi

    # Validate config syntax (check-config exits 0 if valid with suggestions, non-zero if errors)
    if ! phpeek-pm check-config --config "$config" >/dev/null 2>&1; then
        echo "ERROR: PHPeek PM config validation failed" >&2
        echo "       Run: phpeek-pm check-config --config $config" >&2
        echo "       to see detailed validation errors." >&2
        exit 1
    fi

    echo "INFO: PHPeek PM validated successfully"
}

###########################################
# Preflight Checks
###########################################
preflight_checks() {
    local warnings=0
    local workdir="${WORKDIR:-/var/www/html}"

    # Check if Laravel is detected
    if [ -f "$workdir/artisan" ]; then
        echo "INFO: Laravel application detected"

        # Check if enabled services are installed
        if [ "${PHPEEK_PM_PROCESS_HORIZON_ENABLED:-false}" = "true" ]; then
            if [ -f "$workdir/composer.lock" ] && ! grep -q '"laravel/horizon"' "$workdir/composer.lock" 2>/dev/null; then
                echo "WARNING: LARAVEL_HORIZON=true but laravel/horizon not found in composer.lock"
                echo "         Install with: composer require laravel/horizon"
                warnings=$((warnings + 1))
            fi
        fi

        if [ "${PHPEEK_PM_PROCESS_REVERB_ENABLED:-false}" = "true" ]; then
            if [ -f "$workdir/composer.lock" ] && ! grep -q '"laravel/reverb"' "$workdir/composer.lock" 2>/dev/null; then
                echo "WARNING: LARAVEL_REVERB=true but laravel/reverb not found in composer.lock"
                echo "         Install with: composer require laravel/reverb"
                warnings=$((warnings + 1))
            fi
        fi

        # Check writable directories
        for dir in storage/logs storage/framework/cache storage/framework/sessions storage/framework/views bootstrap/cache; do
            if [ -d "$workdir/$dir" ] && [ ! -w "$workdir/$dir" ]; then
                echo "WARNING: Directory not writable: $dir"
                echo "         Run: chown -R www-data:www-data $dir"
                warnings=$((warnings + 1))
            fi
        done

        # Auto-fix permissions if running as root
        if [ "$(id -u)" = "0" ]; then
            echo "INFO: Auto-fixing Laravel directory permissions..."
            for dir in storage bootstrap/cache; do
                if [ -d "$workdir/$dir" ]; then
                    chown -R www-data:www-data "$workdir/$dir" 2>/dev/null || true
                    chmod -R 775 "$workdir/$dir" 2>/dev/null || true
                fi
            done
        fi
    fi

    # Validate PHPeek PM (REQUIRED - will exit if invalid)
    validate_phpeek_pm

    if [ $warnings -gt 0 ]; then
        echo "INFO: Preflight completed with $warnings warnings"
    fi
}

###########################################
# Main Execution
###########################################

echo "╔═══════════════════════════════════════════════════════════════════════════╗"
echo "║  PHPeek Base Image                                                        ║"
echo "╚═══════════════════════════════════════════════════════════════════════════╝"
echo "PHP Version: $PHP_VERSION"

# Setup PUID/PGID user permissions (if specified)
setup_user_permissions

# Decrypt Laravel .env.encrypted (if present)
decrypt_laravel_env

# Run preflight checks (also validates PHPeek PM)
preflight_checks

# Generate runtime configs (PHP, Nginx)
generate_runtime_configs

# Set working directory
WORKDIR="${WORKDIR:-/var/www/html}"
cd "$WORKDIR" 2>/dev/null || cd /var/www/html

# Execute user-provided init scripts (if any)
if [ -d /docker-entrypoint-init.d ]; then
    for script in /docker-entrypoint-init.d/*.sh; do
        if [ -x "$script" ]; then
            echo "INFO: Running init script: $script"
            "$script" || echo "WARNING: Init script $script failed"
        fi
    done
fi

# Run migrations if enabled (with safety checks)
if [ "${LARAVEL_MIGRATE_ENABLED:-false}" = "true" ]; then
    if [ -f "$WORKDIR/artisan" ]; then
        echo "INFO: Running Laravel migrations..."
        if [ "${APP_ENV:-production}" = "production" ]; then
            php artisan migrate --force --no-interaction 2>&1 || {
                echo "WARNING: Migration failed, continuing anyway..."
            }
        else
            php artisan migrate --no-interaction 2>&1 || {
                echo "WARNING: Migration failed, continuing anyway..."
            }
        fi
    fi
fi

# Optimize Laravel caches if enabled
if [ "${LARAVEL_OPTIMIZE_ENABLED:-false}" = "true" ]; then
    if [ -f "$WORKDIR/artisan" ]; then
        echo "INFO: Optimizing Laravel caches..."
        php artisan config:cache 2>&1 || true
        php artisan route:cache 2>&1 || true
        php artisan view:cache 2>&1 || true
    fi
fi

# PHPeek PM configuration path
PHPEEK_PM_CONFIG="${PHPEEK_PM_CONFIG:-/etc/phpeek-pm/phpeek-pm.yaml}"

# Start PHPeek PM (REQUIRED - no fallback)
echo "INFO: Starting PHPeek PM process manager"
echo "      Config: $PHPEEK_PM_CONFIG"

# Hand off to PHPeek PM as PID 1
# PHPeek PM handles: process lifecycle, health checks, graceful shutdown,
# DAG-based dependencies, auto-restart, metrics, and logging
exec /usr/local/bin/phpeek-pm serve --config "$PHPEEK_PM_CONFIG" "$@"
