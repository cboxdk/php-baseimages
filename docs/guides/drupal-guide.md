---
title: "Drupal Guide"
description: "Deploy Drupal with PHPeek using PostgreSQL/MySQL, Redis, and cron"
weight: 31
---

# Drupal Guide

Spin up Drupal 10 with PHPeek images, PostgreSQL (or MySQL), Redis cache, and cron.

## Quick Start

```yaml
# docker-compose.drupal.yml
version: '3.8'

services:
  app:
    image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine
    ports:
      - "8081:80"
    volumes:
      - ./:/var/www/html
    environment:
      - APP_ENV=local
      - DRUPAL_SETTINGS=/var/www/html/web/sites/default/settings.php
      - DB_HOST=postgres
      - DB_DATABASE=drupal
      - DB_USERNAME=drupal
      - DB_PASSWORD=secret
      - CACHE_BACKEND=redis
      - REDIS_HOST=redis
      - LARAVEL_SCHEDULER=true   # Runs cron every minute
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy

  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: drupal
      POSTGRES_USER: drupal
      POSTGRES_PASSWORD: secret
    volumes:
      - pg-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -d drupal -U drupal"]
      interval: 5s
      timeout: 3s
      retries: 10

  redis:
    image: redis:7-alpine

volumes:
  pg-data:
```

## Install Drupal

```bash
composer create-project drupal/recommended-project:^10 drupal
mv drupal/* .
rm -rf drupal

docker compose -f docker-compose.drupal.yml up -d --wait
docker compose exec app composer install
docker compose exec app cp web/sites/example.settings.local.php web/sites/default/settings.php
docker compose exec app chown -R www-data:www-data web/sites/default
```

Visit `http://localhost:8081` to finish the installer.

## Redis Cache & Sessions

Install module:

```bash
docker compose exec app composer require drupal/redis && \
  docker compose exec app drush en redis -y
```

Add to `web/sites/default/services.yml`:

```yaml
parameters:
  redis.connection:
    interface: Predis\Client
    host: redis
    port: 6379

services:
  cache.backend.redis:
    class: Drupal\redis\Cache\PhpRedis
    arguments: ['@redis.factory']
```

Update `settings.php`:

```php
$settings['cache']['default'] = 'cache.backend.redis';
$settings['container_yamls'][] = DRUPAL_ROOT . '/sites/default/services.yml';
$settings['redis.connection']['interface'] = 'PhpRedis';
$settings['redis.connection']['host'] = 'redis';
$settings['redis.connection']['port'] = 6379;
$settings['cache_prefix'] = 'drupal_';
```

## Cron & Queue

Drupal's internal cron can run via PHPeek’s scheduler:

```bash
docker compose exec app drush cron
```

For queues:

```yaml
environment:
  - DRUPAL_QUEUE_RUNNER=true
```

## Development Setup

- Switch to `ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine-dev` for Xdebug.
- Mount `web/sites` read/write for config export/import.
- Use `drush uli` to generate one-time login links.

## Production Checklist

```yaml
services:
  app:
    image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine
    volumes:
      - ./:/var/www/html:ro
      - ./web/sites/default/files:/var/www/html/web/sites/default/files
    environment:
      - APP_ENV=production
      - PHP_DISPLAY_ERRORS=Off
      - PHP_OPCACHE_VALIDATE_TIMESTAMPS=0
      - LARAVEL_SCHEDULER=true
```

```bash
drush cache:rebuild
drush config:export --destination=../config-sync
drush updatedb -y
drush cr
```

## Troubleshooting

- **Install stuck at composer autoload**: ensure `/vendor` writable; fix perms via `docker compose exec app chown -R www-data:www-data vendor`.
- **Cron not running**: confirm `LARAVEL_SCHEDULER=true` and watch logs `docker compose logs -f app | grep cron`.
- **File uploads failing**: share host folder via bind mount and set `chmod -R 775 web/sites/default/files`.
