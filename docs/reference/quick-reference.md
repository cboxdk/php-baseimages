---
title: "Quick Reference"
description: "Copy-paste ready snippets for PHPeek base images"
weight: 1
---

# Quick Reference

Copy-paste ready snippets. No configuration needed.

## Minimal Setup

```yaml
# docker-compose.yml
services:
  app:
    image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine
    ports:
      - "8000:80"
    volumes:
      - .:/var/www/html
```

```bash
docker compose up
# Open http://localhost:8000
```

## Laravel

```yaml
services:
  app:
    image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine
    ports:
      - "8000:80"
    volumes:
      - .:/var/www/html
    environment:
      - LARAVEL_SCHEDULER=true
    depends_on:
      - mysql
      - redis

  mysql:
    image: mysql:8
    environment:
      MYSQL_ROOT_PASSWORD: secret
      MYSQL_DATABASE: laravel
      MYSQL_USER: laravel
      MYSQL_PASSWORD: secret
    volumes:
      - mysql-data:/var/lib/mysql

  redis:
    image: redis:7-alpine

volumes:
  mysql-data:
```

**.env essentials:**
```bash
DB_HOST=mysql
REDIS_HOST=redis
REDIS_CLIENT=phpredis
```

## Symfony

```yaml
services:
  app:
    image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine
    ports:
      - "8000:80"
    volumes:
      - .:/var/www/html
    environment:
      - APP_ENV=dev
    depends_on:
      - postgres

  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: symfony
      POSTGRES_USER: symfony
      POSTGRES_PASSWORD: secret
    volumes:
      - postgres-data:/var/lib/postgresql/data

volumes:
  postgres-data:
```

## WordPress

```yaml
services:
  wordpress:
    image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine
    ports:
      - "8000:80"
    volumes:
      - ./wordpress:/var/www/html
    depends_on:
      - mysql

  mysql:
    image: mysql:8
    environment:
      MYSQL_ROOT_PASSWORD: secret
      MYSQL_DATABASE: wordpress
    volumes:
      - mysql-data:/var/lib/mysql

volumes:
  mysql-data:
```

---

## Common Environment Variables

### PHP Settings

```yaml
environment:
  - PHP_MEMORY_LIMIT=512M
  - PHP_MAX_EXECUTION_TIME=300
  - PHP_UPLOAD_MAX_FILESIZE=100M
  - PHP_POST_MAX_SIZE=100M
```

### Laravel Features

```yaml
environment:
  - LARAVEL_SCHEDULER=true      # Enable cron
  - LARAVEL_QUEUE=true          # Enable queue worker
  - LARAVEL_HORIZON=true        # Enable Horizon
  - LARAVEL_REVERB=true         # Enable WebSockets
```

### Development (Xdebug)

```yaml
environment:
  - XDEBUG_MODE=debug,develop,coverage
  - XDEBUG_CONFIG=client_host=host.docker.internal
  - PHP_IDE_CONFIG=serverName=docker
```

### Production

```yaml
environment:
  - PHP_OPCACHE_VALIDATE_TIMESTAMPS=0
  - PHP_OPCACHE_MAX_ACCELERATED_FILES=20000
```

---

## Quick Commands

```bash
# Start
docker compose up -d

# Logs
docker compose logs -f

# Shell
docker compose exec app sh

# PHP version
docker compose exec app php -v

# Extensions
docker compose exec app php -m

# Health check
curl localhost:8000/health

# Stop
docker compose down
```

## Laravel Commands

```bash
docker compose exec app php artisan key:generate
docker compose exec app php artisan migrate
docker compose exec app php artisan cache:clear
docker compose exec app php artisan config:cache
docker compose exec app php artisan test
```

---

## Available Images

```
# Alpine (smallest, ~80MB)
ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-alpine
ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine
ghcr.io/phpeek/baseimages/php-fpm-nginx:8.2-alpine

# Debian (glibc, ~150MB)
ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-debian

# Ubuntu (~160MB)
ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-ubuntu

# Development (with Xdebug)
ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine-dev
```

---

## Included Extensions

All images include 40+ extensions:

```
bcmath, calendar, ctype, curl, dom, exif, fileinfo, gd, gettext,
iconv, imagick, intl, mbstring, mongodb, mysqli, opcache, pcntl,
pdo_mysql, pdo_pgsql, pgsql, redis, simplexml, soap, sockets,
sodium, tokenizer, xml, xmlreader, xmlwriter, xsl, zip
```

Verify: `docker compose exec app php -m`

---

## Add Custom Extension

```dockerfile
FROM ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine

RUN apk add --no-cache $PHPIZE_DEPS \
    && pecl install swoole \
    && docker-php-ext-enable swoole \
    && apk del $PHPIZE_DEPS
```

See [Extending Images](../advanced/extending-images) for more.
