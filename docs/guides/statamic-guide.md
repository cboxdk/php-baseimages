---
title: "Statamic Guide"
description: "Deploy Statamic (Laravel) on Cbox with Redis, queues, and image handling"
weight: 33
---

# Statamic Guide

Statamic runs on Laravel, so Cbox’s Laravel defaults apply. This guide highlights Statamic-specific steps.

## Quick Start

```yaml
# docker-compose.statamic.yml
version: '3.8'

services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm
    ports:
      - "8083:80"
    volumes:
      - ./:/var/www/html
    environment:
      - APP_ENV=local
      - APP_URL=http://localhost:8083
      - DB_HOST=mysql
      - DB_DATABASE=statamic
      - DB_USERNAME=statamic
      - DB_PASSWORD=secret
      - CACHE_DRIVER=redis
      - SESSION_DRIVER=redis
      - REDIS_HOST=redis
      - LARAVEL_SCHEDULER=true
      - LARAVEL_QUEUE=true
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_healthy

  mysql:
    image: mysql:8.0
    environment:
      MYSQL_DATABASE: statamic
      MYSQL_USER: statamic
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

## Install Statamic

```bash
composer create-project statamic/statamic statamic-app
mv statamic-app/* .
rm -rf statamic-app

docker compose -f docker-compose.statamic.yml up -d --wait
docker compose exec app php artisan key:generate
docker compose exec app php please make:user
```

Set `STATAMIC_LICENSE_KEY` in `.env` if you have a Pro license.

## Asset Storage

Expose `storage` and `public/assets` for uploads:

```yaml
services:
  app:
    volumes:
      - ./:/var/www/html
      - ./storage:/var/www/html/storage
      - ./public/assets:/var/www/html/public/assets
```

Run `php artisan storage:link` once inside the container.

## Image Manipulation

Statamic uses Glide (Intervention Image). Cbox images already include GD + Imagick. Ensure the cache directory is writable:

```bash
docker compose exec app chown -R www-data:www-data storage public/assets
```

## Queues & Scheduler

`LARAVEL_QUEUE=true` spins up Statamic queues (for email, static caching). Adjust worker scale:

```yaml
environment:
  - CBOX_INIT_PROCESS_QUEUE_DEFAULT_SCALE=2
```

Scheduler handles `php artisan schedule:run` for static cache warming, sitemaps, etc.

## Development Tips

- Use the `-dev` image for Xdebug, Vite, and Tailwind builds.
- Run `npm install && npm run dev` via `docker compose exec app npm install` (install Node in Dockerfile if needed).
- Use `php please multisite` commands for multi-site setups.

## Production Checklist

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm
    environment:
      - APP_ENV=production
      - APP_URL=https://example.com
      - APP_DEBUG=false
      - CACHE_DRIVER=redis
      - SESSION_DRIVER=redis
      - LARAVEL_SCHEDULER=true
      - LARAVEL_QUEUE=true
    volumes:
      - ./:/var/www/html:ro
      - ./storage:/var/www/html/storage
      - ./public/assets:/var/www/html/public/assets
```

```bash
php artisan config:cache
php artisan route:cache
php artisan view:cache
php please cache:clear
```

## Troubleshooting

- **“No suitable cipher”**: ensure `APP_KEY` is set (`php artisan key:generate`).
- **Assets not loading**: confirm `public/assets` mount and run `php artisan storage:link`.
- **Glide 500 errors**: check Imagick availability `docker compose exec app php -m | grep imagick` and set `ASSET_URL` if using CDN.
