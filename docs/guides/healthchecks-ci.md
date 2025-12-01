---
title: "Health Checks & CI Templates"
description: "Add PHPeek-ready Docker health checks and GitHub Actions workflows to keep deployments and pull requests stable"
weight: 55
---

# Health Checks & CI Templates

Ready-to-copy snippets for wiring health checks into Docker Compose and running PHPeek stacks inside GitHub Actions.

## Docker Compose Health Checks

Use health checks so dependent services (PHP, MySQL, Redis) only start once everything is ready.

```yaml
# examples/healthchecks/docker-compose.yml
version: '3.8'

services:
  app:
    image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine
    environment:
      - APP_ENV=local
      - DB_HOST=mysql
      - REDIS_HOST=redis
      - LARAVEL_SCHEDULER=true
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "php-fpm-healthcheck"]
      interval: 10s
      timeout: 3s
      retries: 5
      start_period: 30s

  mysql:
    image: mysql:8.3
    environment:
      MYSQL_DATABASE: app
      MYSQL_USER: app
      MYSQL_PASSWORD: secret
      MYSQL_ROOT_PASSWORD: root_secret
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 5s
      timeout: 3s
      retries: 10
      start_period: 20s

  redis:
    image: redis:7-alpine
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 10

volumes:
  mysql-data:
```

**Why it matters**

- `php-fpm-healthcheck` ships with PHPeek and fails if PHP-FPM/Nginx are down.
- MySQL/Redis health checks allow `docker compose up -d --wait` to block until services are ready.
- `depends_on.condition: service_healthy` ensures Laravel boot doesn't run migrations before MySQL is up.

**Usage**

1. Copy the file to `docker-compose.healthcheck.yml` (or merge sections into your main compose file).
2. Start services with `docker compose -f docker-compose.yml -f docker-compose.healthcheck.yml up -d --wait`.
3. Verify status via `docker compose ps --format 'table {{.Name}}\t{{.Health}}'`.

## GitHub Actions Template

The workflow below runs Composer install and `php artisan test` using your existing PHPeek Compose stack.

```yaml
# examples/github-actions/laravel-ci.yml
name: Laravel CI (PHPeek)

on:
  push:
    branches: ["main", "develop"]
  pull_request:
    branches: ["main"]

jobs:
  test:
    runs-on: ubuntu-latest
    env:
      APP_ENV: testing
      APP_KEY: base64:dummyappkeyhere=
    steps:
      - uses: actions/checkout@v4

      - name: Copy CI environment file
        run: |
          if [ -f .env.ci ]; then cp .env.ci .env; else cp .env.example .env; fi

      - name: Pull images
        run: docker compose pull

      - name: Start dependencies with health checks
        run: docker compose up -d --wait mysql redis

      - name: Install Composer dependencies
        run: docker compose run --rm app composer install --prefer-dist --no-progress --no-interaction

      - name: Run Laravel tests
        run: docker compose run --rm app php artisan test --parallel

      - name: Tear down
        if: always()
        run: docker compose down -v
```

**Key points**

- Health checks let `docker compose up -d --wait mysql redis` block until DB/cache are ready before tests.
- Composer + tests run inside the same `app` service image you ship to production, keeping parity high.
- `.env.ci` override pattern ensures secrets stay in GitHub and not in `docker-compose.yml`.

## Recommended Workflow

1. Merge health-check snippets into your compose file (or keep a separate override file under `docker-compose.healthcheck.yml`).
2. Commit `.github/workflows/laravel-ci.yml` based on the template above.
3. Run `docker compose up -d --wait` locally once to ensure health checks succeed before enabling CI.
4. Extend the workflow with additional commands (Pest, Dusk, static analysis) as needed.

Need more automation? Combine this with the [Production Deployment](production-deployment) checklist to promote healthy builds straight into staging.
