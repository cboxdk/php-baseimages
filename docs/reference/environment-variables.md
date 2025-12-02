---
title: "Environment Variables Reference"
description: "Complete reference for all PHPeek environment variables"
weight: 1
---

# Environment Variables Reference

Complete reference for all environment variables supported by PHPeek base images powered by PHPeek PM.

## Quick Start Variables

These are the most commonly used variables. Just set what you need!

| Variable | Default | Description |
|----------|---------|-------------|
| `LARAVEL_SCHEDULER` | `false` | Enable Laravel scheduler |
| `LARAVEL_HORIZON` | `false` | Enable Laravel Horizon |
| `LARAVEL_REVERB` | `false` | Enable Laravel Reverb WebSockets |
| `LARAVEL_QUEUE` | `false` | Enable queue workers |
| `PHP_MEMORY_LIMIT` | `256M` | PHP memory limit |
| `PHP_MAX_EXECUTION_TIME` | `30` | Max script execution time |

---

## Laravel Shorthand Variables

These user-friendly variables are automatically mapped to PHPeek PM process controls by the entrypoint script.

### Process Control

| Variable | Maps To | Description |
|----------|---------|-------------|
| `LARAVEL_SCHEDULER` | `PHPEEK_PM_PROCESS_SCHEDULER_ENABLED` | Enable `php artisan schedule:work` |
| `LARAVEL_HORIZON` | `PHPEEK_PM_PROCESS_HORIZON_ENABLED` | Enable Laravel Horizon |
| `LARAVEL_REVERB` | `PHPEEK_PM_PROCESS_REVERB_ENABLED` | Enable Laravel Reverb |
| `LARAVEL_QUEUE` | `PHPEEK_PM_PROCESS_QUEUE_DEFAULT_ENABLED` | Enable default queue worker |
| `LARAVEL_QUEUE_HIGH` | `PHPEEK_PM_PROCESS_QUEUE_HIGH_ENABLED` | Enable high priority queue |

---

## PHP Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `PHP_MEMORY_LIMIT` | `256M` | Memory limit |
| `PHP_MAX_EXECUTION_TIME` | `30` | Max execution time |
| `PHP_MAX_INPUT_TIME` | `60` | Max input time |
| `PHP_POST_MAX_SIZE` | `100M` | Max POST size |
| `PHP_UPLOAD_MAX_FILESIZE` | `100M` | Max upload size |
| `PHP_MAX_FILE_UPLOADS` | `20` | Max simultaneous uploads |
| `PHP_MAX_INPUT_VARS` | `1000` | Max input variables |
| `PHP_DATE_TIMEZONE` | `UTC` | Default timezone |
| `PHP_DISPLAY_ERRORS` | `Off` | Display errors (use `On` for dev) |
| `PHP_ERROR_REPORTING` | `E_ALL & ~E_DEPRECATED & ~E_STRICT` | Error reporting level |
| `PHP_LOG_ERRORS` | `On` | Log errors |
| `PHP_ERROR_LOG` | `/dev/stderr` | Error log destination |

### OPcache

| Variable | Default | Description |
|----------|---------|-------------|
| `PHP_OPCACHE_ENABLE` | `1` | Enable OPcache |
| `PHP_OPCACHE_MEMORY_CONSUMPTION` | `256` | OPcache memory (MB) |
| `PHP_OPCACHE_INTERNED_STRINGS_BUFFER` | `16` | Interned strings buffer (MB) |
| `PHP_OPCACHE_MAX_ACCELERATED_FILES` | `20000` | Max cached files |
| `PHP_OPCACHE_REVALIDATE_FREQ` | `0` | Revalidation frequency |
| `PHP_OPCACHE_VALIDATE_TIMESTAMPS` | `0` | Validate timestamps (1 for dev) |
| `PHP_OPCACHE_JIT` | `tracing` | JIT mode: `tracing`, `function`, `off` |
| `PHP_OPCACHE_JIT_BUFFER_SIZE` | `128M` | JIT buffer size |

---

## Nginx Configuration

### Server Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `NGINX_HTTP_PORT` | `80` | HTTP port |
| `NGINX_HTTPS_PORT` | `443` | HTTPS port |
| `NGINX_WEBROOT` | `/var/www/html/public` | Document root |
| `NGINX_INDEX` | `index.php index.html` | Index files |
| `NGINX_SERVER_TOKENS` | `off` | Hide Nginx version |

### Client Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `NGINX_CLIENT_MAX_BODY_SIZE` | `100M` | Max request body |
| `NGINX_CLIENT_BODY_TIMEOUT` | `60s` | Body read timeout |
| `NGINX_CLIENT_HEADER_TIMEOUT` | `60s` | Header read timeout |

### Security Headers

**All security headers are fully configurable via environment variables.** Set to empty string to disable.

| Variable | Default | Description |
|----------|---------|-------------|
| `NGINX_HEADER_X_FRAME_OPTIONS` | `SAMEORIGIN` | Clickjacking protection |
| `NGINX_HEADER_X_CONTENT_TYPE_OPTIONS` | `nosniff` | MIME sniffing protection |
| `NGINX_HEADER_X_XSS_PROTECTION` | `1; mode=block` | XSS filter |
| `NGINX_HEADER_CSP` | *(see below)* | Content-Security-Policy |
| `NGINX_HEADER_REFERRER_POLICY` | `strict-origin-when-cross-origin` | Referrer information |
| `NGINX_HEADER_COOP` | *(disabled)* | Cross-Origin-Opener-Policy (opt-in) |
| `NGINX_HEADER_COEP` | *(disabled)* | Cross-Origin-Embedder-Policy (opt-in) |
| `NGINX_HEADER_CORP` | *(disabled)* | Cross-Origin-Resource-Policy (opt-in) |
| `NGINX_HEADER_PERMISSIONS_POLICY` | *(see below)* | Browser feature permissions |

**Default CSP:**
```
default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self'; frame-ancestors 'self'
```

**Default Permissions-Policy:**
```
accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=()
```

**Cross-Origin Isolation Headers (COOP/COEP/CORP):**

These headers are **disabled by default** because they break most applications that use:
- External APIs (payment gateways, analytics, social login)
- CDN resources (fonts, scripts, images)
- Third-party embeds (YouTube, maps, widgets)

**Enable for maximum security** (advanced use cases only):
```yaml
environment:
  - NGINX_HEADER_COOP=same-origin
  - NGINX_HEADER_COEP=require-corp
  - NGINX_HEADER_CORP=same-origin
```

**Disable a header** (set to empty):
```yaml
environment:
  - NGINX_HEADER_CSP=       # Disable Content-Security-Policy
```

See [Security Hardening](../advanced/security-hardening#content-security-policy) for customization examples.

### Gzip Compression

| Variable | Default | Description |
|----------|---------|-------------|
| `NGINX_GZIP` | `on` | Enable gzip (`on`/`off`) |
| `NGINX_GZIP_VARY` | `on` | Add Vary: Accept-Encoding |
| `NGINX_GZIP_PROXIED` | `any` | Compress proxied requests |
| `NGINX_GZIP_COMP_LEVEL` | `6` | Compression level (1-9) |
| `NGINX_GZIP_MIN_LENGTH` | `1000` | Min size to compress (bytes) |
| `NGINX_GZIP_TYPES` | *(see below)* | MIME types to compress |

**Default gzip types:**
```
text/plain text/css text/xml text/javascript application/json application/javascript application/xml application/xml+rss application/x-javascript image/svg+xml
```

**Disable gzip:**
```yaml
environment:
  - NGINX_GZIP=off
```

### Open File Cache

| Variable | Default | Description |
|----------|---------|-------------|
| `NGINX_OPEN_FILE_CACHE` | `max=10000 inactive=20s` | Cache config (`off` to disable) |
| `NGINX_OPEN_FILE_CACHE_VALID` | `30s` | Cache validation interval |
| `NGINX_OPEN_FILE_CACHE_MIN_USES` | `2` | Min uses before caching |
| `NGINX_OPEN_FILE_CACHE_ERRORS` | `on` | Cache file errors |

**Disable file cache:**
```yaml
environment:
  - NGINX_OPEN_FILE_CACHE=off
```

### FastCGI Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `NGINX_FASTCGI_PASS` | `127.0.0.1:9000` | PHP-FPM address |
| `NGINX_FASTCGI_BUFFERS` | `8 8k` | FastCGI buffers |
| `NGINX_FASTCGI_BUFFER_SIZE` | `8k` | Buffer size |
| `NGINX_FASTCGI_BUSY_BUFFERS_SIZE` | `16k` | Busy buffers size |
| `NGINX_FASTCGI_CONNECT_TIMEOUT` | `60s` | Connect timeout |
| `NGINX_FASTCGI_SEND_TIMEOUT` | `60s` | Send timeout |
| `NGINX_FASTCGI_READ_TIMEOUT` | `60s` | Read timeout |

### Logging

| Variable | Default | Description |
|----------|---------|-------------|
| `NGINX_ACCESS_LOG` | `/var/log/nginx/access.log` | Access log path (`off` or `false` to disable) |
| `NGINX_ERROR_LOG` | `/var/log/nginx/error.log` | Error log path |
| `NGINX_ERROR_LOG_LEVEL` | `warn` | Error log level |

**Disable access logging** (reduces disk I/O in high-traffic scenarios):
```yaml
environment:
  - NGINX_ACCESS_LOG=false
  # or
  - NGINX_ACCESS_LOG=off
```

### Static Files

| Variable | Default | Description |
|----------|---------|-------------|
| `NGINX_STATIC_EXPIRES` | `1y` | Static file cache duration |
| `NGINX_STATIC_CACHE_CONTROL` | `public, immutable` | Cache-Control header |
| `NGINX_STATIC_ACCESS_LOG` | `off` | Static file access logging |
| `NGINX_TRY_FILES` | `/index.php?$query_string` | try_files fallback |

---

## Reverse Proxy Configuration

Configure PHPeek to run behind Cloudflare, HAProxy, Traefik, Nginx, Fastly, Tailscale, or other reverse proxies.

| Variable | Default | Description |
|----------|---------|-------------|
| `NGINX_TRUSTED_PROXIES` | *(empty)* | Space-separated list of trusted proxy IPs/CIDRs |
| `NGINX_REAL_IP_HEADER` | `X-Forwarded-For` | Header containing real client IP |
| `NGINX_REAL_IP_RECURSIVE` | `on` | Recursive IP extraction from proxy chain |

### Common Proxy Configurations

```yaml
# Docker/Kubernetes internal networks
NGINX_TRUSTED_PROXIES: "10.0.0.0/8 172.16.0.0/12 192.168.0.0/16"

# Cloudflare
NGINX_TRUSTED_PROXIES: "173.245.48.0/20 103.21.244.0/22 ..."
NGINX_REAL_IP_HEADER: "CF-Connecting-IP"

# Tailscale
NGINX_TRUSTED_PROXIES: "100.64.0.0/10"

# Traefik/HAProxy (Docker network)
NGINX_TRUSTED_PROXIES: "172.16.0.0/12"
```

### Headers Forwarded to PHP

When proxies are configured, these headers are available in PHP:

| PHP Variable | Description |
|--------------|-------------|
| `$_SERVER['REMOTE_ADDR']` | Real client IP (after proxy extraction) |
| `$_SERVER['HTTP_X_FORWARDED_FOR']` | Full proxy chain |
| `$_SERVER['HTTP_X_FORWARDED_PROTO']` | Original protocol (http/https) |
| `$_SERVER['HTTP_X_FORWARDED_HOST']` | Original hostname |
| `$_SERVER['HTTP_X_REAL_IP']` | Real client IP |

See [Reverse Proxy & mTLS Guide](../advanced/reverse-proxy-mtls) for detailed setup.

---

## SSL Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `SSL_MODE` | `off` | SSL mode: `off`, `on`, `full` |
| `SSL_CERTIFICATE_FILE` | `/etc/ssl/certs/phpeek-selfsigned.crt` | Certificate path |
| `SSL_PRIVATE_KEY_FILE` | `/etc/ssl/private/phpeek-selfsigned.key` | Private key path |
| `SSL_PROTOCOLS` | `TLSv1.2 TLSv1.3` | SSL protocols |
| `SSL_CIPHERS` | `HIGH:!aNULL:!MD5` | SSL ciphers |
| `SSL_HSTS_HEADER` | `max-age=31536000; includeSubDomains` | HSTS header value |

### SSL Modes

- `off` - HTTP only
- `on` - HTTPS enabled (HTTP still available)
- `full` - HTTPS with HTTP to HTTPS redirect

---

## mTLS (Mutual TLS) Configuration

Enable client certificate authentication for zero-trust networks, service mesh, or API authentication.

| Variable | Default | Description |
|----------|---------|-------------|
| `MTLS_ENABLED` | `false` | Enable mTLS client verification |
| `MTLS_CLIENT_CA_FILE` | `/etc/ssl/certs/client-ca.crt` | CA certificate for client verification |
| `MTLS_VERIFY_CLIENT` | `optional` | `optional`, `on` (required), or `optional_no_ca` |
| `MTLS_VERIFY_DEPTH` | `2` | Maximum certificate chain depth |

### mTLS Client Info in PHP

When mTLS is enabled, client certificate details are available:

| PHP Variable | Description |
|--------------|-------------|
| `$_SERVER['SSL_CLIENT_VERIFY']` | `SUCCESS`, `FAILED`, or `NONE` |
| `$_SERVER['SSL_CLIENT_S_DN']` | Client subject DN (e.g., `/CN=service-name`) |
| `$_SERVER['SSL_CLIENT_I_DN']` | Client issuer DN |
| `$_SERVER['SSL_CLIENT_SERIAL']` | Certificate serial number |
| `$_SERVER['SSL_CLIENT_FINGERPRINT']` | Certificate fingerprint |

### Example mTLS Setup

```yaml
services:
  app:
    image: ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine
    environment:
      SSL_MODE: "on"
      MTLS_ENABLED: "true"
      MTLS_VERIFY_CLIENT: "optional"
    volumes:
      - ./certs/client-ca.crt:/etc/ssl/certs/client-ca.crt:ro
      - ./certs/server.crt:/etc/ssl/certs/phpeek-selfsigned.crt:ro
      - ./certs/server.key:/etc/ssl/private/phpeek-selfsigned.key:ro
```

See [Reverse Proxy & mTLS Guide](../advanced/reverse-proxy-mtls#mtls-mutual-tls-client-authentication) for complete setup.

---

## User/Group Mapping (PUID/PGID)

Match container user/group IDs to your host filesystem for seamless permissions.

| Variable | Default | Description |
|----------|---------|-------------|
| `PUID` | *(container default)* | User ID for application files |
| `PGID` | *(container default)* | Group ID for application files |
| `APP_USER` | `www-data` | Application user name |
| `APP_GROUP` | `www-data` | Application group name |

**Match host user permissions:**
```yaml
environment:
  - PUID=1000
  - PGID=1000
```

Useful for:
- NFS volumes with user mapping
- Host filesystem permissions on bind mounts
- Rootless container environments

---

## Laravel .env Decryption

Automatically decrypt `.env.encrypted` files at container startup.

| Variable | Default | Description |
|----------|---------|-------------|
| `LARAVEL_ENV_ENCRYPTION_KEY` | *(empty)* | Decryption key (e.g., `base64:xxx`) |
| `LARAVEL_ENV_ENCRYPTION_KEY_FILE` | *(empty)* | Path to file containing decryption key |
| `LARAVEL_ENV_FORCE_DECRYPT` | `false` | Overwrite existing `.env` file |

**Using environment variable:**
```yaml
environment:
  - LARAVEL_ENV_ENCRYPTION_KEY=base64:your-encryption-key-here
```

**Using Docker secrets:**
```yaml
environment:
  - LARAVEL_ENV_ENCRYPTION_KEY_FILE=/run/secrets/laravel_env_key
secrets:
  - laravel_env_key
```

---

## Other Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `WORKDIR` | `/var/www/html` | Working directory |
| `PHPEEK_PM_CONFIG` | `/etc/phpeek-pm/phpeek-pm.yaml` | PHPeek PM config path |

---

## Example Configurations

### Development

```yaml
environment:
  - PHP_DISPLAY_ERRORS=On
  - PHP_OPCACHE_VALIDATE_TIMESTAMPS=1
```

### Production Laravel

```yaml
environment:
  - LARAVEL_SCHEDULER=true
  - PHP_MEMORY_LIMIT=512M
```

### High-Traffic API

```yaml
environment:
  - PHP_MEMORY_LIMIT=1G
  - PHP_MAX_EXECUTION_TIME=120
  - NGINX_FASTCGI_READ_TIMEOUT=120s
  - LARAVEL_QUEUE=true
```

### Laravel with Horizon

```yaml
environment:
  - LARAVEL_HORIZON=true
  - LARAVEL_SCHEDULER=true
```

### Laravel with Reverb (WebSockets)

```yaml
environment:
  - LARAVEL_REVERB=true
ports:
  - "8000:80"
  - "8080:8080"
```
