---
title: "WordPress Guide"
description: "WordPress setup with MySQL and production optimization"
weight: 13
---

# WordPress Guide

Get WordPress running with MySQL and optimized performance.

## Quick Start

### 1. Create docker-compose.yml

```yaml
services:
  wordpress:
    image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine
    ports:
      - "8000:80"
    volumes:
      - .:/var/www/html
    depends_on:
      - mysql

  mysql:
    image: mysql:8
    environment:
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wordpress
      MYSQL_PASSWORD: secret
      MYSQL_ROOT_PASSWORD: root_secret
    volumes:
      - mysql-data:/var/lib/mysql

volumes:
  mysql-data:
```

### 2. Download WordPress

```bash
curl -O https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz --strip-components=1
rm latest.tar.gz
```

### 3. Start

```bash
docker compose up -d
```

Visit **http://localhost:8000** and complete the installation wizard.

**wp-config.php values:**
```php
define('DB_NAME', 'wordpress');
define('DB_USER', 'wordpress');
define('DB_PASSWORD', 'secret');
define('DB_HOST', 'mysql');  // Service name, NOT localhost
```

---

## Redis Object Cache

Add Redis for faster caching:

```yaml
services:
  wordpress:
    image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine
    depends_on:
      - mysql
      - redis

  redis:
    image: redis:7-alpine
```

**wp-config.php:**
```php
define('WP_REDIS_HOST', 'redis');
define('WP_REDIS_PORT', 6379);
```

Install [Redis Object Cache](https://wordpress.org/plugins/redis-cache/) plugin.

---

## Development Setup

Use dev image with Xdebug:

```yaml
services:
  wordpress:
    image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine-dev
    environment:
      - XDEBUG_MODE=debug,develop
      - XDEBUG_CONFIG=client_host=host.docker.internal
```

**wp-config.php for development:**
```php
define('WP_DEBUG', true);
define('WP_DEBUG_LOG', true);
define('WP_DEBUG_DISPLAY', false);
define('SCRIPT_DEBUG', true);
```

---

## Production Checklist

```yaml
services:
  wordpress:
    image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine
    volumes:
      - .:/var/www/html:ro
      - ./wp-content/uploads:/var/www/html/wp-content/uploads
    restart: unless-stopped
```

**wp-config.php for production:**
```php
define('WP_DEBUG', false);
define('DISALLOW_FILE_EDIT', true);
define('WP_AUTO_UPDATE_CORE', 'minor');
```

See [Production Deployment](production-deployment) for full guide.

---

## Common Mistakes

### ❌ Using localhost

```php
// Wrong
define('DB_HOST', 'localhost');

// Correct - use Docker service name
define('DB_HOST', 'mysql');
```

### ❌ Upload permission errors

```bash
docker compose exec wordpress chown -R www-data:www-data wp-content/uploads
```

### ❌ Memory limit errors

```yaml
environment:
  - PHP_MEMORY_LIMIT=256M
```

---

## WP-CLI

Run WP-CLI commands:

```bash
docker compose exec wordpress wp --allow-root plugin list
docker compose exec wordpress wp --allow-root theme list
docker compose exec wordpress wp --allow-root cache flush
```

---

## Next Steps

| Topic | Guide |
|-------|-------|
| Production deploy | [Production Deployment](production-deployment) |
| Performance tuning | [Performance Tuning](../advanced/performance-tuning) |
| Add extensions | [Extending Images](../advanced/extending-images) |
| All env vars | [Environment Variables](../reference/environment-variables) |
