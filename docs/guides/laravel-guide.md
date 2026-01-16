---
title: "Laravel Guide"
description: "Complete Laravel setup with MySQL, Redis, and Laravel Scheduler"
weight: 11
---

# Laravel Guide

Get Laravel running with MySQL, Redis, and scheduler support.

## Quick Start

### 1. Create docker-compose.yml

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm
    ports:
      - "8000:80"
    volumes:
      - ./:/var/www/html
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

### 2. Update .env

```bash
DB_HOST=mysql          # Service name, NOT localhost
REDIS_HOST=redis       # Service name, NOT localhost
REDIS_CLIENT=phpredis  # Pre-installed, faster than predis
```

### 3. Start

```bash
docker compose up -d
docker compose exec app php artisan key:generate
docker compose exec app php artisan migrate
```

Visit **http://localhost:8000**

---

## Environment Configuration

Key settings for `.env`:

```bash
# Database
DB_CONNECTION=mysql
DB_HOST=mysql
DB_DATABASE=laravel
DB_USERNAME=laravel
DB_PASSWORD=secret

# Cache & Queue (use Redis)
CACHE_STORE=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis
REDIS_CLIENT=phpredis
REDIS_HOST=redis
```

See [Environment Variables Reference](../reference/environment-variables.md) for all options.

---

## Laravel Features

Enable with environment variables:

| Variable | Purpose |
|----------|---------|
| `LARAVEL_SCHEDULER=true` | Enable `schedule:run` cron |
| `LARAVEL_QUEUE=true` | Enable queue worker |
| `LARAVEL_HORIZON=true` | Enable Horizon dashboard |
| `LARAVEL_REVERB=true` | Enable WebSocket server |

### Queue Workers

```yaml
environment:
  - LARAVEL_QUEUE=true
  - CBOX_PM_PROCESS_QUEUE_DEFAULT_SCALE=3  # 3 workers
```

### Scheduler

Already enabled above. Verify:

```bash
docker compose exec app php artisan schedule:list
```

---

## Development Setup

Use dev image with Xdebug:

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm-dev
    environment:
      - XDEBUG_MODE=debug,develop,coverage
      - XDEBUG_CONFIG=client_host=host.docker.internal
      - PHP_IDE_CONFIG=serverName=docker
```

See [Development Workflow](development-workflow.md) for Xdebug setup.

---

## Production Checklist

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm  # No -dev
    volumes:
      - ./:/var/www/html:ro  # Read-only
      - ./storage:/var/www/html/storage
      - ./bootstrap/cache:/var/www/html/bootstrap/cache
    restart: unless-stopped
```

```bash
# Before deploy
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan migrate --force
```

See [Production Deployment](production-deployment.md) for full guide.

---

## Common Mistakes

### ❌ Using localhost

```bash
# Wrong
DB_HOST=localhost

# Correct - use Docker service name
DB_HOST=mysql
```

### ❌ Connection refused

MySQL not ready. Use healthcheck or wait:

```bash
# Wait for MySQL to respond, then run migrations
docker compose exec mysql sh -c 'until mysqladmin ping -h localhost --silent; do sleep 1; done'
docker compose exec app php artisan migrate --force
```

### ❌ Permission errors

Cbox auto-fixes permissions. Manual fix:

```bash
docker compose exec app chown -R www-data:www-data storage
```

### ❌ Wrong Redis client

```bash
# Use phpredis (pre-installed, faster)
REDIS_CLIENT=phpredis
```

---

## Verification Commands

```bash
# Test database
docker compose exec app php artisan tinker --execute="DB::connection()->getPdo()"

# Test Redis
docker compose exec app php artisan tinker --execute="Redis::set('test','ok'); echo Redis::get('test');"

# Test cache
docker compose exec app php artisan cache:clear

# Run tests
docker compose exec app php artisan test
```

---

## Next Steps

| Topic | Guide |
|-------|-------|
| Xdebug & hot-reload | [Development Workflow](development-workflow.md) |
| Production deploy | [Production Deployment](production-deployment.md) |
| Add extensions | [Extending Images](../advanced/extending-images.md) |
| Performance tuning | [Performance Tuning](../advanced/performance-tuning.md) |
| All env vars | [Environment Variables](../reference/environment-variables.md) |
