---
title: "TYPO3 Guide"
description: "TYPO3 CMS with Cbox, MySQL, Redis, and scheduler"
weight: 32
---

# TYPO3 Guide

Deploy TYPO3 v12 with Cbox base images.

## Quick Start

```yaml
# docker-compose.typo3.yml
version: '3.8'

services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm
    ports:
      - "8082:80"
    volumes:
      - ./:/var/www/html
    environment:
      - APP_ENV=local
      - DB_HOST=mysql
      - DB_DATABASE=typo3
      - DB_USERNAME=typo3
      - DB_PASSWORD=secret
      - REDIS_HOST=redis
      - LARAVEL_SCHEDULER=true
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_healthy

  mysql:
    image: mysql:8.0
    environment:
      MYSQL_DATABASE: typo3
      MYSQL_USER: typo3
      MYSQL_PASSWORD: secret
      MYSQL_ROOT_PASSWORD: root_secret
    volumes:
      - mysql-data:/var/lib/mysql
    command: --default-authentication-plugin=mysql_native_password
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 5s
      timeout: 3s
      retries: 10

  redis:
    image: redis:7-alpine

volumes:
  mysql-data:
```

## Install TYPO3

```bash
composer create-project typo3/cms-base-distribution:^12 .
docker compose -f docker-compose.typo3.yml up -d --wait
docker compose exec app composer install
```

Visit `http://localhost:8082` to complete the Install Tool.

## File Storage

Map persistent folders:

```yaml
services:
  app:
    volumes:
      - ./:/var/www/html
      - ./public/fileadmin:/var/www/html/public/fileadmin
      - ./public/typo3conf:/var/www/html/public/typo3conf
      - ./var:/var/www/html/var
```

## Caching with Redis

Install extension:

```bash
docker compose exec app composer req friendsoftypo3/redis:^2
```

Add to `config/system/settings.php`:

```php
$GLOBALS['TYPO3_CONF_VARS']['SYS']['caching']['cacheConfigurations']['cache_pages']['backend'] = \
    \TYPO3\CMS\Core\Cache\Backend\RedisBackend::class;
$GLOBALS['TYPO3_CONF_VARS']['SYS']['caching']['cacheConfigurations']['cache_pages']['options'] = [
    'hostname' => 'redis',
    'port' => 6379,
];
```

Clear caches:

```bash
docker compose exec app vendor/bin/typo3 cache:flush
```

## Scheduler Tasks

TYPO3 scheduler requires cron. Cbox’s scheduler runs `vendor/bin/typo3 scheduler:run` every minute when `LARAVEL_SCHEDULER=true` and `CBOX_PM_PROCESS_SCHEDULER_COMMAND` default is used.

Manual run:

```bash
docker compose exec app vendor/bin/typo3 scheduler:run
```

## Development Tips

- Switch to `php-fpm-nginx:8.3-bookworm-dev` for Xdebug.
- Use `composer req typo3/cms-introduction --dev` to seed sample content.
- Enable error display in `config/system/settings.php` for local environments.

## Production Checklist

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm
    environment:
      - APP_ENV=production
      - PHP_DISPLAY_ERRORS=Off
      - PHP_OPCACHE_VALIDATE_TIMESTAMPS=0
      - LARAVEL_SCHEDULER=true
    volumes:
      - ./:/var/www/html:ro
      - ./public/fileadmin:/var/www/html/public/fileadmin
      - ./public/typo3conf:/var/www/html/public/typo3conf
      - ./var:/var/www/html/var
```

```bash
vendor/bin/typo3 cache:flush
vendor/bin/typo3 upgrade:run
vendor/bin/typo3 extension:setupactive
```

## Troubleshooting

- **Install tool locked**: remove `public/typo3conf/ENABLE_INSTALL_TOOL` to access installer.
- **Scheduler not executing**: ensure `LARAVEL_SCHEDULER=true` and check `docker compose logs -f app | grep scheduler`.
- **File permission errors**: run `docker compose exec app chown -R www-data:www-data public/fileadmin public/typo3conf var`.
