---
title: "Frequently Asked Questions"
description: "Common questions and answers about PHPeek Base Images, troubleshooting, and best practices"
weight: 10
---

# Frequently Asked Questions

## General Questions

### What is PHPeek Base Images?

PHPeek Base Images is a collection of production-ready Docker images for PHP applications. We provide:

- **40+ PHP extensions** pre-installed and optimized
- **Three tiers**: Slim (APIs), Standard (most apps), Full (Browsershot/Dusk)
- **PHP versions**: 8.2, 8.3, 8.4, 8.5
- **Architecture types**: Single-process (PHP-FPM, PHP-CLI, Nginx) and Multi-service (PHP-FPM + Nginx)
- **Development variants** with Xdebug pre-configured
- **Framework auto-detection** for Laravel, Symfony, and WordPress

### How is PHPeek different from other PHP Docker images?

| Feature | PHPeek | php:official | serversideup |
|---------|--------|--------------|--------------|
| Extensions pre-installed | 40+ | ~10 | 30+ |
| Multi-service containers | Yes | No | Yes (S6) |
| Process manager | PHPeek PM (Go) | None | S6 Overlay |
| Framework detection | Yes | No | Yes |
| Development variants | Yes | No | Yes |
| Weekly security rebuilds | Yes | Varies | Yes |

**Key differentiator**: PHPeek uses PHPeek PM, a lightweight Go-based process manager instead of S6 Overlay, resulting in simpler debugging, smaller image sizes, and built-in Prometheus metrics.

### Which image should I use?

**For most Laravel/Symfony projects**: `php-fpm-nginx:8.4-bookworm`
- Smallest image size (~120MB)
- Both PHP-FPM and Nginx in one container
- Auto-configures for your framework

**For Kubernetes/microservices**: Separate `php-fpm` + `nginx` images
- Better horizontal scaling
- Independent resource limits

**For development**: `php-fpm-nginx:8.4-bookworm-dev`
- Includes Xdebug pre-configured
- Development PHP settings (errors visible)

## Installation & Setup

### How do I get started quickly?

```bash
# Pull the latest image
docker pull ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-bookworm

# Run with your Laravel project
docker run -d \
  -p 8080:80 \
  -v $(pwd):/var/www/html \
  ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-bookworm
```

### How do I use the development image with Xdebug?

```yaml
# docker-compose.yml
services:
  app:
    image: ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-bookworm-dev
    ports:
      - "8080:80"
      - "9003:9003"  # Xdebug port
    volumes:
      - .:/var/www/html
    environment:
      XDEBUG_MODE: debug,develop,coverage
      XDEBUG_CONFIG: client_host=host.docker.internal client_port=9003
      PHP_IDE_CONFIG: serverName=docker
```

### What PHP extensions are included?

**Core extensions** (always available):
- opcache, pdo_mysql, pdo_pgsql, mysqli, pgsql
- redis, imagick, apcu, mongodb
- zip, intl, bcmath, gd, exif
- pcntl, sockets, soap, xsl, ldap, imap

**Run `php -m` to see all enabled extensions in your container.**

See [Available Extensions](../reference/available-extensions.md) for the complete list.

## Configuration

### How do I customize PHP settings?

**Option 1**: Environment variables (runtime)
```yaml
environment:
  PHP_MEMORY_LIMIT: 512M
  PHP_UPLOAD_MAX_FILESIZE: 100M
  PHP_POST_MAX_SIZE: 100M
  PHP_MAX_EXECUTION_TIME: 300
```

**Option 2**: Custom php.ini (build time)
```dockerfile
FROM ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-bookworm
COPY custom.ini /usr/local/etc/php/conf.d/99-custom.ini
```

### How do I customize Nginx?

**Replace the default config**:
```dockerfile
FROM ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-bookworm
COPY nginx.conf /etc/nginx/conf.d/default.conf
```

**Or use environment variables** (template-based):
```yaml
environment:
  NGINX_WEBROOT: /var/www/html/public
  NGINX_CLIENT_MAX_BODY_SIZE: 100M
  NGINX_FASTCGI_READ_TIMEOUT: 300s
```

### How do I enable the Laravel scheduler?

```yaml
environment:
  LARAVEL_SCHEDULER: "true"
```

This automatically sets up cron to run `php artisan schedule:run` every minute. Older configs that still export `LARAVEL_SCHEDULER_ENABLED` continue to work, but `LARAVEL_SCHEDULER` is the canonical flag going forward.

## Performance

### What performance optimizations are included?

1. **OPcache** - Fully configured for production
   - `opcache.memory_consumption=256`
   - `opcache.max_accelerated_files=50000`
   - `opcache.jit_buffer_size=128M` (PHP 8.x)

2. **Realpath Cache** - 20-30% performance improvement
   - `realpath_cache_size=4096K`
   - `realpath_cache_ttl=600`

3. **Nginx Optimizations**
   - `open_file_cache` enabled
   - Gzip compression configured
   - Static asset caching

4. **PHP-FPM** - Production-tuned pool settings

### How do I monitor performance?

PHPeek PM provides built-in metrics:

```bash
# Check process status
docker exec myapp phpeek-pm status

# View metrics (Prometheus format)
curl http://localhost:9100/metrics
```

### Why is my container slow on first request?

First requests trigger:
1. OPcache warming
2. Framework bootstrapping
3. File caching

**Solution**: Enable warm-up in production:
```yaml
environment:
  LARAVEL_AUTO_OPTIMIZE: "true"  # Runs optimize on startup
```

## Security

### What security features are included?

1. **HTTP Security Headers**
   - X-Frame-Options: SAMEORIGIN
   - X-Content-Type-Options: nosniff
   - Cross-Origin-Opener-Policy: same-origin
   - Cross-Origin-Embedder-Policy: require-corp
   - Permissions-Policy (camera, microphone, etc. disabled)

2. **Nginx Protections**
   - Hidden files blocked (`.env`, `.git`)
   - Sensitive directories blocked (`vendor`, `node_modules`)
   - PHP execution blocked in upload directories
   - Version headers hidden

3. **PHP Security**
   - `expose_php = Off`
   - Dangerous functions disabled
   - `open_basedir` ready

4. **ImageMagick Policy**
   - XXE prevention
   - Ghostscript exploits blocked
   - SSRF protection

### How do I add Content-Security-Policy?

CSP is intentionally not set by default (too application-specific). Add it in your Dockerfile or custom nginx config:

```nginx
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'" always;
```

### Is the /health endpoint secure?

Yes! The `/health` endpoint is restricted to localhost only:
```nginx
location /health {
    allow 127.0.0.1;
    allow ::1;
    deny all;
}
```

Kubernetes/Docker health checks work because they run inside the container.

## Troubleshooting

### Container starts but site shows 502 Bad Gateway

**Cause**: PHP-FPM isn't running or Nginx can't connect.

**Fix**:
```bash
# Check if PHP-FPM is running
docker exec myapp ps aux | grep php-fpm

# Check PHP-FPM logs
docker exec myapp cat /var/log/php-fpm.log

# Verify socket/port
docker exec myapp netstat -tlnp | grep 9000
```

### Permission denied errors on Laravel

**Cause**: `storage/` and `bootstrap/cache/` aren't writable.

**Fix**: PHPeek auto-fixes this, but if it persists:
```bash
docker exec myapp chown -R www-data:www-data /var/www/html/storage
docker exec myapp chmod -R 775 /var/www/html/storage
```

### Xdebug not connecting to IDE

**Checklist**:
1. Port 9003 is exposed: `-p 9003:9003`
2. `XDEBUG_MODE=debug` is set
3. `client_host=host.docker.internal` (Docker Desktop) or your host IP
4. IDE is listening on port 9003
5. Path mappings are correct in IDE

### OPcache changes not reflecting

**Development**: Set `OPCACHE_VALIDATE_TIMESTAMPS=1`

**Production**: Restart container after deployment:
```bash
docker restart myapp
# Or inside container:
kill -USR2 1  # Graceful reload
```

### Container won't start - "exec format error"

**Cause**: Wrong architecture (ARM vs AMD64).

**Fix**: Specify platform:
```bash
docker pull --platform linux/amd64 ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-bookworm
```

## Updates & Maintenance

### How often are images updated?

- **Weekly security rebuilds** every Monday at 03:00 UTC
- **PHP version updates** within 48 hours of release
- **Extension updates** as needed

### How do I update my images?

```bash
# Pull latest
docker pull ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-bookworm

# Rebuild your image
docker-compose build --pull

# Restart containers
docker-compose up -d
```

### How do I pin to a specific version?

Use SHA-based tags for reproducibility:
```yaml
image: ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-bookworm@sha256:abc123...
```

Rolling tags (`8.4-bookworm`) get weekly security updates automatically.

## Migration

### Migrating from serversideup images?

**Key differences**:
1. No S6 Overlay - services managed by bash entrypoint
2. Different environment variable names (check docs)
3. Config paths may differ

**Migration steps**:
1. Update `image:` in docker-compose.yml
2. Review environment variables
3. Test locally before production

### Migrating from official PHP images?

PHPeek includes everything from official images plus:
- 40+ extensions pre-installed
- Nginx bundled (multi-service)
- Framework auto-detection
- Production optimizations

**Simply change your `FROM` line**:
```dockerfile
# Before
FROM php:8.4-fpm-bookworm

# After
FROM ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-bookworm
```

## Getting Help

### Where can I report issues?

GitHub Issues: [github.com/gophpeek/baseimages/issues](https://github.com/gophpeek/baseimages/issues)

### How do I contribute?

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

See [Contributing Guide](../contributing.md) for details.
