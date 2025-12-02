---
title: "Symfony Guide"
description: "Symfony setup with PostgreSQL, Redis, and production deployment"
weight: 12
---

# Symfony Guide

Get Symfony running with PostgreSQL, Redis, and optimized caching.

## Quick Start

### 1. Create docker-compose.yml

```yaml
services:
  app:
    image: ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.3-alpine
    ports:
      - "8000:80"
    volumes:
      - .:/var/www/html
    depends_on:
      - postgres
      - redis

  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: symfony
      POSTGRES_USER: symfony
      POSTGRES_PASSWORD: secret
    volumes:
      - postgres-data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine

volumes:
  postgres-data:
```

### 2. Update .env

```bash
DATABASE_URL="postgresql://symfony:secret@postgres:5432/symfony?serverVersion=16"
REDIS_URL=redis://redis:6379
```

### 3. Start

```bash
docker compose up -d
docker compose exec app php bin/console doctrine:migrations:migrate
```

Visit **http://localhost:8000**

---

## Configuration

### Database (.env)

```bash
# PostgreSQL
DATABASE_URL="postgresql://symfony:secret@postgres:5432/symfony?serverVersion=16"

# Or MySQL
DATABASE_URL="mysql://symfony:secret@mysql:3306/symfony?serverVersion=8.0"
```

### Cache & Session (config/packages/framework.yaml)

```yaml
framework:
    cache:
        app: cache.adapter.redis
        default_redis_provider: '%env(REDIS_URL)%'
    session:
        handler_id: '%env(REDIS_URL)%'
```

See [Environment Variables](../reference/environment-variables) for all options.

---

## Development Setup

Use dev image with Xdebug:

```yaml
services:
  app:
    image: ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.3-alpine-dev
    environment:
      - APP_ENV=dev
      - XDEBUG_MODE=debug,develop,coverage
      - XDEBUG_CONFIG=client_host=host.docker.internal
```

See [Development Workflow](development-workflow) for Xdebug setup.

---

## Production Checklist

```yaml
services:
  app:
    image: ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.3-alpine
    volumes:
      - .:/var/www/html:ro
      - ./var:/var/www/html/var
    environment:
      - APP_ENV=prod
    restart: unless-stopped
```

```bash
# Before deploy
APP_ENV=prod composer install --no-dev --optimize-autoloader
php bin/console cache:clear --env=prod
php bin/console cache:warmup --env=prod
php bin/console doctrine:migrations:migrate --no-interaction
```

See [Production Deployment](production-deployment) for full guide.

---

## Common Mistakes

### ❌ Using localhost

```bash
# Wrong
DATABASE_URL="postgresql://symfony:secret@localhost:5432/symfony"

# Correct - use Docker service name
DATABASE_URL="postgresql://symfony:secret@postgres:5432/symfony"
```

### ❌ Missing var directory permissions

```bash
docker compose exec app chown -R www-data:www-data var
```

### ❌ APP_ENV not set

Always set `APP_ENV=prod` in production.

---

## Verification

```bash
# Test database
docker compose exec app php bin/console doctrine:query:sql "SELECT 1"

# Test cache
docker compose exec app php bin/console cache:clear

# Run tests
docker compose exec app php bin/phpunit
```

---

## Next Steps

| Topic | Guide |
|-------|-------|
| Development workflow | [Development Workflow](development-workflow) |
| Production deploy | [Production Deployment](production-deployment) |
| Add extensions | [Extending Images](../advanced/extending-images) |
| All env vars | [Environment Variables](../reference/environment-variables) |
