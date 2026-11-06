---
title: "Migration Guide"
description: "Migrate to Cbox PHP Base Images from ServerSideUp, Bitnami, or custom images with step-by-step instructions"
weight: 5
---

# Migration Guide

Complete guide for migrating to Cbox from other PHP Docker solutions.

## V1 to V2 (unpublished candidate)

V2 changes the OS from Debian 12 Bookworm to Debian 13 Trixie. Rebuild the
application image from scratch; do not apt-dist-upgrade a v1 container.
The intended pin changes from `8.5-bookworm-v1` to `8.5-trixie-v2` once v2
has been published. PHP 8.2, 8.3, 8.4 and 8.5 have independent source locks;
CLI and FPM for a series use the same archive. PHP 8.6 remains a separate
preview with ZTS and no promise of stable extension support.

- Recompile custom PHP extensions and native libraries against Trixie. Do not
  copy extension `.so` files from v1: ICU, ImageMagick and other library ABIs
  changed. ImageMagick is now 7; validate image rendering in your application.
  AVIF and HEIC encoders are installed explicitly because Trixie makes them
  optional packages; local and native CI checks exercise image roundtrips.
- The PHP `vips` extension is removed. Use GD/ImageMagick or a separate libvips
  service if your workload needs it.
- Node remains on the 22 LTS line (22.23.4); npm moves from bundled npm 10
  to separately pinned npm 12.2.2 to remove its known vulnerable dependencies.
  Re-run your application's `npm ci` and build scripts before adopting v2.
- Match your application's Playwright version to `tools.playwright` in
  `versions.json`, or install that application's browser revision yourself.
  Composer and Playwright are pinned; apt-only patches do not update them.
- `SSL_MODE=full` now redirects HTTP to HTTPS while retaining loopback
  `/healthz`. Check ingress headers, application URLs and health probes.
- FPM dynamic-pool defaults now follow the final autotune environment. This
  fixes startup failure in small containers where autotuning chose fewer
  workers than the previous hard-coded spare-worker count. With manual
  `PHP_FPM_MAX_CHILDREN=1`, default start/spare counts now fit that pool.
  Explicit user-provided start/spare values are retained.
- Validate rootless permissions and your actual host kernel/container runtime.
  Local macOS/OrbStack tests do not certify old RHEL host seccomp/Landlock
  behavior. Keep the previous immutable application digest for rollback.

The first v2 build is full. Subsequent OS-only patches require matching source,
configuration, dependencies, architecture and Debian-suite labels. A new PHP
patch or other changed build input forces a full build; unchanged apt indexes
and completed build chains avoid scheduling needless work. See
[the source-build implementation](https://github.com/cboxdk/php-baseimages/blob/main/php-source/README.md) for local tests.

## Quick Migration Matrix

| From | Main Differences | Migration Complexity |
|------|-----------------|---------------------|
| ServerSideUp | Architecture similar, different env vars | ⚡ Easy |
| Bitnami | Different user, paths, and structure | 🔧 Moderate |
| Official PHP | Need to add Nginx, different config | 🔨 Complex |
| Custom | Varies by implementation | 🎯 Variable |

## From ServerSideUp Images

### Key Differences

| Aspect | ServerSideUp | Cbox |
|--------|-------------|--------|
| Process Manager | S6 Overlay | Cbox Init (Go) |
| User | www-data (fixed) | www-data/nginx (OS-dependent) |
| Env Prefix | `PHP_` | `PHP_`, `NGINX_` |
| Health Checks | Built-in | Built-in |

### Migration Steps

**1. Update image name:**

```yaml
# Before (ServerSideUp)
services:
  app:
    image: serversideup/php:8.3-fpm-nginx

# After (Cbox)
services:
  app:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.3-trixie-v2
```

**2. Update environment variables:**

```yaml
# Most variables work the same, but check:

# ServerSideUp
AUTORUN_ENABLED=true
AUTORUN_LARAVEL_STORAGE_LINK=true

# Cbox
LARAVEL_OPTIMIZE_ENABLED=true
# (storage link runs automatically)
```

**3. Update volume paths (if different):**

```yaml
# Paths are the same
volumes:
  - ./:/var/www/html
```

**4. Test and verify:**

```bash
docker-compose build
docker-compose up -d
docker-compose logs -f app
```

### ServerSideUp → Cbox Env Mapping

| ServerSideUp | Cbox | Notes |
|--------------|--------|-------|
| `PHP_MEMORY_LIMIT` | `PHP_MEMORY_LIMIT` | Same |
| `PHP_OPCACHE_ENABLE` | `PHP_OPCACHE_ENABLE` | Same |
| `AUTORUN_ENABLED` | N/A | Always enabled |
| `AUTORUN_LARAVEL_STORAGE_LINK` | N/A | Automatic |

## From Bitnami Images

### Key Differences

| Aspect | Bitnami | Cbox |
|--------|---------|--------|
| User | `1001` | www-data (82/33) |
| Install Path | `/opt/bitnami` | `/var/www/html` |
| Config Location | `/opt/bitnami/php/etc` | `/usr/local/etc/php` |
| Process Manager | Custom scripts | Cbox Init (Go) |

### Migration Steps

**1. Update image and paths:**

```yaml
# Before (Bitnami)
services:
  app:
    image: bitnami/php-fpm:8.3
    volumes:
      - ./:/app

# After (Cbox)
services:
  app:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.3-trixie-v2
    volumes:
      - ./:/var/www/html
```

**2. Update user permissions:**

```bash
# Bitnami uses UID 1001
# Cbox uses www-data (UID 33 on Debian)

# Update file ownership
chown -R 33:33 .  # www-data on Debian
```

**3. Update configuration paths:**

```yaml
# Before (Bitnami)
volumes:
  - ./php.ini:/opt/bitnami/php/etc/php.ini

# After (Cbox)
volumes:
  - ./php.ini:/usr/local/etc/php/conf.d/zz-custom.ini
```

**4. Update database host:**

```env
# Before (Bitnami often uses specific service names)
DB_HOST=mariadb

# After (Cbox - use your service name)
DB_HOST=mysql
```

## From Official PHP Images

### Key Differences

| Aspect | Official PHP | Cbox |
|--------|-------------|--------|
| Web Server | None (FPM only) | Nginx included |
| Extensions | Minimal | 40+ pre-installed |
| Configuration | Manual | Environment variables |
| Production Ready | Requires work | Ready to use |

### Migration Steps

**1. Simplify your docker-compose.yml:**

```yaml
# Before (Official PHP - separate services)
services:
  php:
    image: php:8.3-fpm
    volumes:
      - ./:/var/www/html

  nginx:
    image: nginx:trixie
    volumes:
      - ./:/var/www/html
      - ./nginx.conf:/etc/nginx/conf.d/default.conf

# After (Cbox - combined)
services:
  app:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.3-trixie-v2
    ports:
      - "8000:80"
    volumes:
      - ./:/var/www/html
```

**2. Remove custom Dockerfile (if only installing extensions):**

```dockerfile
# Before - Custom Dockerfile needed for extensions
FROM php:8.3-fpm
RUN docker-php-ext-install pdo_mysql redis opcache gd

# After - Extensions pre-installed, no Dockerfile needed!
# Just use: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.3-trixie-v2
```

**3. Update configuration method:**

```yaml
# Before - Mount custom php.ini
volumes:
  - ./php.ini:/usr/local/etc/php/php.ini

# After - Use environment variables (easier)
environment:
  - PHP_MEMORY_LIMIT=256M
  - PHP_OPCACHE_VALIDATE_TIMESTAMPS=0

# Or still mount if needed
volumes:
  - ./php.ini:/usr/local/etc/php/conf.d/zz-custom.ini
```

## From Custom Images

### Assessment Checklist

Evaluate your custom image:

- [ ] Which PHP extensions are installed?
- [ ] Custom PHP configuration?
- [ ] Custom Nginx configuration?
- [ ] System packages installed?
- [ ] Custom initialization scripts?
- [ ] Process management setup?

### Migration Strategy

**Option 1: Use Cbox Directly (if possible)**

Check if Cbox includes everything you need:

```bash
# Check included extensions
docker run --rm ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.3-trixie-v2 php -m
```

**Option 2: Extend Cbox Image**

For additional requirements:

```dockerfile
FROM ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.3-trixie-v2

# Add your custom extensions
RUN apt-get update && apt-get install -y ffmpeg

# Add custom configurations
COPY docker/php/custom.ini /usr/local/etc/php/conf.d/zz-custom.ini
COPY docker/nginx/custom.conf /etc/nginx/conf.d/custom.conf

# Add initialization scripts
COPY docker-entrypoint-init.d/ /docker-entrypoint-init.d/
```

## Framework-Specific Migrations

### Laravel

```yaml
# Add Laravel-specific settings
environment:
  - LARAVEL_SCHEDULER=true
  - LARAVEL_OPTIMIZE_ENABLED=true
  - LARAVEL_QUEUE=true
```

### Symfony

```yaml
# Add Symfony-specific settings
environment:
  - APP_ENV=prod
```

Symfony is auto-detected (via `bin/console` + `symfony.lock`) and `var/`
permissions are fixed automatically. For cache warmup on startup, drop an init
script into `/docker-entrypoint-init.d/` — it runs before the services start:

```bash
# docker-entrypoint-init.d/10-warmup.sh
#!/bin/sh
php bin/console cache:warmup --env=prod
```

### WordPress

```yaml
# WordPress configuration
environment:
  - WORDPRESS_DB_HOST=mysql
  - WORDPRESS_DB_NAME=wordpress
  - WORDPRESS_DB_USER=wordpress
  - WORDPRESS_DB_PASSWORD=${DB_PASSWORD}
```

## Post-Migration Checklist

After migrating:

- [ ] All services start successfully
- [ ] Application is accessible
- [ ] Database connections work
- [ ] File permissions correct
- [ ] Cache/sessions working
- [ ] Scheduled tasks running (if applicable)
- [ ] Queue workers running (if applicable)
- [ ] Static assets loading
- [ ] Logs accessible and clean
- [ ] Performance acceptable

## Common Migration Issues

### Issue: File Permission Errors

```bash
# Check current ownership
docker-compose exec app ls -la /var/www/html

# Fix permissions
docker-compose exec app chown -R www-data:www-data /var/www/html/storage
```

### Issue: Database Connection Failed

```yaml
# Update to use Docker service name
DB_HOST=mysql  # Not 'localhost'!
```

### Issue: Missing PHP Extension

```bash
# Check if extension exists
docker-compose exec app php -m | grep extension_name

# If missing, extend the image (see docs/advanced/extending-images.md)
```

## Migration Support

Need help with migration?

1. **Check examples:** See [guides section](../guides) for your framework
2. **Search issues:** [GitHub Issues](https://github.com/cboxdk/php-baseimages/issues)
3. **Ask community:** [GitHub Discussions](https://github.com/cboxdk/php-baseimages/discussions)

## Related Documentation

- [Extending Images](../advanced/extending-images) - Customization guide
- [Laravel Guide](../guides/laravel-guide) - Laravel-specific setup
- [Environment Variables](../reference/environment-variables) - Configuration options
- [Common Issues](../troubleshooting/common-issues) - Troubleshooting

---

**Migration questions?** Ask in [GitHub Discussions](https://github.com/cboxdk/php-baseimages/discussions).
