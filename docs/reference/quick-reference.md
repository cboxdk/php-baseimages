---
title: "Quick Reference"
description: "Copy-paste ready snippets for Cbox PHP Base Images"
weight: 6
---

# Quick Reference

Copy-paste ready snippets. No configuration needed.

## Minimal Setup

```yaml
# docker-compose.yml
services:
  app:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.3-bookworm
    ports:
      - "8000:80"
    volumes:
      - .:/var/www/html
```

```bash
docker compose up
# Open http://localhost:8000
```

## Framework Guides

For full docker-compose setups with databases and caching, see the framework guides:

- [Laravel Guide](../guides/laravel-guide) -- MySQL, Redis, Scheduler, Horizon
- [Symfony Guide](../guides/symfony-guide) -- PostgreSQL, Redis, Doctrine
- [WordPress Guide](../guides/wordpress-guide) -- MySQL, Redis Object Cache

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

For the full image size matrix, tier descriptions, and rootless variants, see [Choosing Your Image](../getting-started/choosing-your-image).

```text
# Standard tier (DEFAULT)
ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm

# Slim tier (APIs, microservices)
ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-slim

# Chromium tier (Browsershot, Dusk)
ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-chromium

# Development (with Xdebug)
ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-dev
```

See [Available Extensions](./available-extensions) for the full extension list by tier.
