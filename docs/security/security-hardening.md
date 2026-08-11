---
title: "Security Hardening Guide"
description: "Comprehensive security best practices for Cbox containers including CVE management, secrets handling, and production hardening"
weight: 1
---

# Security Hardening Guide

Security hardening guide for Cbox containers in production environments.

## Built-in Security Features

Cbox PHP Base Images come with security features enabled by default:

### Nginx Security (Default Configuration)

| Feature | Status | Description |
|---------|--------|-------------|
| Server version hidden | Enabled | `server_tokens off` - Nginx version not exposed |
| X-Frame-Options | Enabled | `SAMEORIGIN` - Prevents clickjacking |
| X-Content-Type-Options | Enabled | `nosniff` - Prevents MIME sniffing |
| Referrer-Policy | Enabled | `strict-origin-when-cross-origin` |
| Permissions-Policy | Enabled | Restricts browser features (camera, microphone, etc.) |
| X-XSS-Protection | Removed | [Deprecated and can be exploited](https://github.com/serversideup/docker-php/issues/31) |
| Content-Security-Policy | Opt-in | Disabled by default - too application-specific |
| Health endpoint restricted | Enabled | `/health` only accessible from localhost |
| Sensitive files blocked | Enabled | `.env`, `.git`, `composer.json`, `artisan`, `vendor/`, etc. return 404 |
| Hidden files blocked | Enabled | All `/.` paths return 404 |
| Upload directory protection | Enabled | PHP execution blocked in upload directories |

### SSL/TLS Security (When Enabled)

| Feature | Default | Description |
|---------|---------|-------------|
| Key strength | RSA 4096 | Strong key generation for self-signed certificates |
| Protocols | TLSv1.2, TLSv1.3 | Modern protocols only |
| Cipher suite | Mozilla Modern | ECDHE-based ciphers with forward secrecy |
| HSTS | Enabled | 1 year max-age with includeSubDomains |
| Session tickets | Disabled | Enhanced security for session resumption |

For custom TLS configuration, use the [Mozilla SSL Configuration Generator](https://ssl-config.mozilla.org/) to generate nginx TLS directives appropriate for your environment.

### Entrypoint Security

| Feature | Status | Description |
|---------|--------|-------------|
| Input validation | Enabled | Boolean values and paths validated |
| Path traversal protection | Enabled | `..` sequences blocked in file paths |
| Template injection prevention | Enabled | `envsubst` used instead of `eval` |
| Signal handling | Enabled | Graceful shutdown on SIGTERM/SIGINT/SIGQUIT |

## Security Checklist

### Before Production

- [ ] Disable PHP error display
- [ ] Restrict dangerous PHP functions
- [ ] Enable HTTPS/TLS
- [ ] Security headers configured
- [ ] Secrets stored securely (not in git)
- [ ] Container runs as non-root
- [ ] File permissions correct
- [ ] Rate limiting enabled
- [ ] CVE scanning enabled

## PHP Security Configuration

### Disable Error Display

```yaml
services:
  app:
    environment:
      - PHP_DISPLAY_ERRORS=Off
      - PHP_DISPLAY_STARTUP_ERRORS=Off
      - PHP_LOG_ERRORS=On
      - PHP_ERROR_LOG=/proc/self/fd/2
```

### Restrict Dangerous Functions

Create `docker/php/security.ini`:

```ini
[Security]
disable_functions = exec,passthru,shell_exec,system,proc_open,popen,curl_exec,curl_multi_exec,parse_ini_file,show_source,phpinfo
expose_php = Off
allow_url_fopen = Off
allow_url_include = Off
; open_basedir is NOT set here. The FPM pool sets it as a `php_admin_value`,
; which overrides php.ini — so a value in this file is silently ignored in web
; requests. Use `PHP_OPEN_BASEDIR` instead, and keep the read-only kernel
; statistics in it or `cboxdk/laravel-telemetry` collects nothing:
; see docs/reference/environment-variables.md.

; Session security
session.cookie_httponly = 1
session.cookie_secure = 1
session.cookie_samesite = "Strict"
session.use_strict_mode = 1
session.use_only_cookies = 1
```

Mount in docker-compose.yml:

```yaml
services:
  app:
    volumes:
      - ./docker/php/security.ini:/usr/local/etc/php/conf.d/zz-security.ini:ro
```

For a complete reference on PHP security settings, see the [PHP Security documentation](https://www.php.net/manual/en/security.php).

### Content Security Policy

CSP is **disabled by default** because it is too application-specific. Enable it via environment variable:

```yaml
services:
  app:
    environment:
      # Example for Laravel with Livewire and Google Fonts
      - NGINX_HEADER_CSP=default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data: https:; connect-src 'self' wss:; frame-ancestors 'self'
```

For strict CSP or per-route CSP via Laravel middleware, configure at the application level. See the [MDN CSP documentation](https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP) for guidance on crafting policies.

## Nginx Rate Limiting

```nginx
# Define rate limit zones
limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;
limit_req_zone $binary_remote_addr zone=api:10m rate=100r/s;

server {
    limit_req zone=general burst=20 nodelay;

    location /login {
        limit_req zone=login burst=2 nodelay;
    }

    location /api/ {
        limit_req zone=api burst=50;
    }
}
```

## Secrets Management

### Environment Variables (Basic)

Never commit secrets to git. Add to `.gitignore`:

```
.env
.env.*
!.env.example
*.key
*.pem
```

### Docker Secrets (Docker Swarm)

```yaml
services:
  app:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm
    secrets:
      - app_key
      - db_password
    environment:
      - APP_KEY_FILE=/run/secrets/app_key
      - DB_PASSWORD_FILE=/run/secrets/db_password

secrets:
  app_key:
    external: true
  db_password:
    external: true
```

Read secrets in your application:

```php
// Laravel - config/database.php
'password' => file_exists(env('DB_PASSWORD_FILE'))
    ? trim(file_get_contents(env('DB_PASSWORD_FILE')))
    : env('DB_PASSWORD'),
```

For Kubernetes secrets and Vault integration, see the [Kubernetes Secrets documentation](https://kubernetes.io/docs/concepts/configuration/secret/) and your vault provider's docs.

## Container Security

### Run as Non-Root User

Every image tier ships in two variants:

| Variant | Tag suffix | Runs as | Web port | Use when |
|---------|-----------|---------|----------|----------|
| Root | *(none)* — e.g. `8.4-bookworm`, `latest` | `root` (PID 1, nginx master), workers drop to `www-data` | 80 / 443 | You need to bind privileged ports or remap PUID/PGID |
| Rootless | `-rootless` — e.g. `8.4-bookworm-rootless` | `www-data` throughout | 8080 | **Recommended** — no root anywhere |

> ⚠️ The **default/`latest` tags run their init process and nginx master as
> root** (workers still drop to `www-data`). If you don't need to bind port 80
> or remap ownership, prefer the `-rootless` variant, or drop capabilities and
> add `no-new-privileges` (below) to a root image.

```bash
# Rootless variant — nothing runs as root
docker run -p 8080:8080 ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-rootless
docker exec <container> whoami          # -> www-data
```

For a root image, verify the reduced privileges you've applied:

```bash
docker exec <container> ps -o user,comm   # workers should show www-data
```

### Read-Only Root Filesystem

```yaml
services:
  app:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm
    read_only: true
    tmpfs:
      - /tmp
      - /var/run
      - /var/cache/nginx
    volumes:
      - ./:/var/www/html:ro
      - app-storage:/var/www/html/storage
```

### Drop Unnecessary Capabilities & Block Privilege Escalation

```yaml
services:
  app:
    security_opt:
      - no-new-privileges:true   # process can never gain more privileges
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE  # Only if binding to port <1024 (root image on :80)
      - CHOWN             # Only if using PUID/PGID remap
      - SETGID            # Only if dropping from root to www-data
      - SETUID            # Only if dropping from root to www-data
```

The **rootless** variant needs none of these — it binds :8080 and never
switches user, so you can run it with `cap_drop: [ALL]` and no `cap_add`:

```yaml
services:
  app:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-rootless
    ports:
      - "8080:8080"
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
```

### Network Isolation

```yaml
services:
  app:
    networks:
      - frontend
      - backend

  mysql:
    networks:
      - backend  # Not exposed to frontend

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true  # No external access
```

### Pin Images by Digest

Rolling tags (`8.4-bookworm`) get weekly security rebuilds — great for staying
patched, but the tag moves. For reproducible, tamper-evident deployments, pin
the digest and update it deliberately:

```yaml
services:
  app:
    # Resolve once: docker buildx imagetools inspect ghcr.io/.../php-fpm-nginx:8.4-bookworm
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm@sha256:<digest>
```

Verify the image signature before trusting a digest (images are cosign-signed
with keyless OIDC — see [SECURITY.md](https://github.com/cboxdk/php-baseimages/blob/main/SECURITY.md)):

```bash
cosign verify \
  --certificate-identity-regexp 'https://github.com/cboxdk/php-baseimages/.github/workflows/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm
```

### Protect the cbox-init Management API

The multi-service image bundles the cbox-init process manager, which can expose
a REST management API and Prometheus metrics. Both are **disabled by default**.
If you enable them:

```yaml
services:
  app:
    environment:
      - CBOX_INIT_API_ENABLED=true
      - CBOX_INIT_API_AUTH=${CBOX_INIT_API_TOKEN}   # always set a token
    # Never publish the API/metrics ports to untrusted networks. Prefer a
    # local-only bind (api_host: 127.0.0.1) and scrape metrics via a sidecar.
```

Never expose the management API on `0.0.0.0` without a bearer token — it can
start/stop/scale processes. See the cbox-init docs for `api_host`/`metrics_host`
and ACL/TLS options.

## CVE Management

### Weekly Security Updates

Cbox images are automatically rebuilt weekly (Mondays 03:00 UTC) with the latest upstream base image patches, PHP security updates, and OS security updates.

```bash
# Pull latest image and restart
docker pull ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm
docker-compose build --pull
docker-compose up -d
```

### Scanning with Trivy

[Trivy](https://trivy.dev/) detects vulnerabilities in OS packages, application dependencies, and container configuration.

```bash
# Scan Cbox image
trivy image ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm

# Only HIGH and CRITICAL
trivy image --severity HIGH,CRITICAL ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm

# Fail CI on critical vulnerabilities
trivy image --exit-code 1 --severity CRITICAL ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm
```

Cbox CI workflows already include Trivy scanning. For setting up Trivy in your own CI pipeline, see the [Trivy GitHub Action](https://github.com/aquasecurity/trivy-action) documentation.

### Ignoring False Positives

Create a `.trivyignore` file for accepted risks:

```
# False positive in dev dependency
CVE-2024-12345

# Accepted risk - tracked in JIRA-123
CVE-2024-67890
```

### PHP Dependency Scanning

```bash
# Using Symfony CLI
symfony security:check

# Or Enlightn Security Checker
docker-compose exec app composer require --dev enlightn/security-checker
docker-compose exec app php vendor/bin/security-checker security:check
```

### Severity Response Guide

| Severity | Action |
|----------|--------|
| CRITICAL | Immediate action - update base image or patch |
| HIGH | Schedule update within 1 week |
| MEDIUM | Address in next regular update cycle |
| LOW | Monitor, address when convenient |

## Security Best Practices Checklist

### Container Security
- [ ] Run as non-root user (default in Cbox)
- [ ] Read-only root filesystem where possible
- [ ] Drop unnecessary capabilities
- [ ] Regular security scanning
- [ ] Minimal base image (use slim tier when possible)
- [ ] No secrets in image layers

### Network Security
- [ ] HTTPS/TLS enabled
- [ ] Network isolation configured
- [ ] Rate limiting enabled

For detailed TLS configuration, use the [Mozilla SSL Configuration Generator](https://ssl-config.mozilla.org/). For monitoring and alerting setup, see your observability platform's documentation.

## Related Documentation

- [Production Deployment](../guides/production-deployment) - Production setup
- [Environment Variables](../reference/environment-variables) - Configuration options
- [Performance Tuning](../advanced/performance-tuning) - Performance optimization

---

**Questions?** Check [common issues](../troubleshooting/common-issues) or ask in [GitHub Discussions](https://github.com/cboxdk/php-baseimages/discussions).
