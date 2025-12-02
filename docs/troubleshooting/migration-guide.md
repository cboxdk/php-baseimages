---
title: "Migration Guide"
description: "Migrate to PHPeek base images from ServerSideUp, Bitnami, or custom images with step-by-step instructions"
weight: 43
---

# Migration Guide

Complete guide for migrating to PHPeek from other PHP Docker solutions.

## Quick Migration Matrix

| From | Main Differences | Migration Complexity |
|------|-----------------|---------------------|
| ServerSideUp | Architecture similar, different env vars | ⚡ Easy |
| Bitnami | Different user, paths, and structure | 🔧 Moderate |
| Official PHP | Need to add Nginx, different config | 🔨 Complex |
| Custom | Varies by implementation | 🎯 Variable |

## From ServerSideUp Images

### Key Differences

| Aspect | ServerSideUp | PHPeek |
|--------|-------------|--------|
| Process Manager | S6 Overlay | Vanilla bash |
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

# After (PHPeek)
services:
  app:
    image: ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.3-alpine
```

**2. Update environment variables:**

```yaml
# Most variables work the same, but check:

# ServerSideUp
AUTORUN_ENABLED=true
AUTORUN_LARAVEL_STORAGE_LINK=true

# PHPeek
LARAVEL_AUTO_OPTIMIZE=true
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

### ServerSideUp → PHPeek Env Mapping

| ServerSideUp | PHPeek | Notes |
|--------------|--------|-------|
| `PHP_MEMORY_LIMIT` | `PHP_MEMORY_LIMIT` | Same |
| `PHP_OPCACHE_ENABLE` | `PHP_OPCACHE_ENABLE` | Same |
| `AUTORUN_ENABLED` | N/A | Always enabled |
| `AUTORUN_LARAVEL_STORAGE_LINK` | N/A | Automatic |

## From Bitnami Images

### Key Differences

| Aspect | Bitnami | PHPeek |
|--------|---------|--------|
| User | `1001` | www-data (82/33) |
| Install Path | `/opt/bitnami` | `/var/www/html` |
| Config Location | `/opt/bitnami/php/etc` | `/usr/local/etc/php` |
| Process Manager | Custom scripts | Vanilla bash |

### Migration Steps

**1. Update image and paths:**

```yaml
# Before (Bitnami)
services:
  app:
    image: bitnami/php-fpm:8.3
    volumes:
      - ./:/app

# After (PHPeek)
services:
  app:
    image: ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.3-alpine
    volumes:
      - ./:/var/www/html
```

**2. Update user permissions:**

```bash
# Bitnami uses UID 1001
# PHPeek uses www-data (82 on Alpine, 33 on Debian)

# Update file ownership
chown -R 82:82 .  # Alpine
# OR
chown -R 33:33 .  # Debian
```

**3. Update configuration paths:**

```yaml
# Before (Bitnami)
volumes:
  - ./php.ini:/opt/bitnami/php/etc/php.ini

# After (PHPeek)
volumes:
  - ./php.ini:/usr/local/etc/php/conf.d/zz-custom.ini
```

**4. Update database host:**

```env
# Before (Bitnami often uses specific service names)
DB_HOST=mariadb

# After (PHPeek - use your service name)
DB_HOST=mysql
```

## From Official PHP Images

### Key Differences

| Aspect | Official PHP | PHPeek |
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
    image: nginx:alpine
    volumes:
      - ./:/var/www/html
      - ./nginx.conf:/etc/nginx/conf.d/default.conf

# After (PHPeek - combined)
services:
  app:
    image: ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.3-alpine
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
# Just use: ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.3-alpine
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

**Option 1: Use PHPeek Directly (if possible)**

Check if PHPeek includes everything you need:

```bash
# Check included extensions
docker run --rm ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.3-alpine php -m
```

**Option 2: Extend PHPeek Image**

For additional requirements:

```dockerfile
FROM ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.3-alpine

# Add your custom extensions
RUN apk add --no-cache ffmpeg

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
  - LARAVEL_AUTO_OPTIMIZE=true
  - LARAVEL_QUEUE_ENABLED=true
```

### Symfony

```yaml
# Add Symfony-specific settings
environment:
  - SYMFONY_AUTO_WARMUP=true
  - APP_ENV=prod
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
2. **Search issues:** [GitHub Issues](https://github.com/phpeek/baseimages/issues)
3. **Ask community:** [GitHub Discussions](https://github.com/phpeek/baseimages/discussions)

## Related Documentation

- [Extending Images](../advanced/extending-images) - Customization guide
- [Laravel Guide](../guides/laravel-guide) - Laravel-specific setup
- [Environment Variables](../reference/environment-variables) - Configuration options
- [Common Issues](common-issues) - Troubleshooting

---

**Migration questions?** Ask in [GitHub Discussions](https://github.com/phpeek/baseimages/discussions).
