---
title: "Example Applications"
description: "Production-ready Docker Compose setups for common PHP application patterns"
weight: 1
---

# Example Applications

Copy-paste ready Docker Compose configurations for common use cases.

**All processes managed by Cbox PM** - NO command overrides!

## Quick Reference

| Example | Use Case | Services |
|---------|----------|----------|
| [PHP Basic](php-basic/) | Plain PHP without framework | PHP-FPM, Nginx |
| [Laravel Basic](laravel-basic/) | Simple Laravel app | PHP-FPM, Nginx, MySQL |
| [Laravel Horizon](laravel-horizon/) | Queue dashboard | Horizon, Scheduler, MySQL, Redis |
| [Laravel Production](laravel-production/) | Deploy ready | Resource limits, Horizon |
| [Octane Swoole](octane-swoole/) | High performance | Swoole, MySQL, Redis |
| [Octane RoadRunner](octane-roadrunner/) | HTTP/3, gRPC | RoadRunner, MySQL, Redis |
| [Octane FrankenPHP](octane-frankenphp/) | Auto HTTPS | FrankenPHP, MySQL, Redis |
| [Reverb WebSockets](reverb-websockets/) | Real-time features | Reverb, Queue, MySQL, Redis |
| [Symfony Basic](symfony-basic/) | Symfony app | Messenger, PostgreSQL |
| [WordPress](wordpress/) | CMS setup | PHP, MySQL |
| [API Only](api-only/) | REST/GraphQL API | PHP, PostgreSQL, Redis |
| [Development](development/) | Local dev | Xdebug, Vite HMR, MailHog |
| [Multi-Tenant](multi-tenant/) | SaaS | Central DB + Tenant DBs |
| [Microservices](microservices/) | Distributed services | Gateway + Service containers |
| [Static Assets](static-assets/) | Pre-built frontend | PHP only, no Node runtime |

## CI & Health Check Templates

| Template | Description |
|----------|-------------|
| [Health Checks](healthchecks/) | Docker Compose override with built-in health checks for app/MySQL/Redis |
| [GitHub Actions](github-actions/laravel-ci.yml) | Workflow file that pulls Cbox images, waits for health checks, and runs `php artisan test` |

## How to Use

1. Copy the example folder to your project
2. Adjust `docker-compose.yml` for your needs
3. Run `docker compose up -d`

```bash
# Example: Start Laravel basic setup
cp -r examples/laravel-basic/* ./
docker compose up -d
```

## Cbox PM Process Management

All examples use environment variables to control processes - **NEVER override `command:`** for PHP containers!

```yaml
# Correct - Use environment variables
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm
    environment:
      LARAVEL_QUEUE: "true"       # Enables queue workers
      LARAVEL_SCHEDULER: "true"   # Enables scheduler
      LARAVEL_HORIZON: "true"     # Enables Horizon (replaces QUEUE)
      LARAVEL_REVERB: "true"      # Enables Reverb WebSocket server
      LARAVEL_OCTANE: "true"      # Enables Octane server

# WRONG - Don't override command
services:
  worker:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm
    command: php artisan queue:work  # DON'T DO THIS!
```

## Webroot Configuration

Cbox images default to `/var/www/html/public` for frameworks like Laravel/Symfony.

For apps without `public/` folder (WordPress, plain PHP), set `WEBROOT`:

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm
    environment:
      WEBROOT: /var/www/html  # Serve from root, not public/
```

| App Type | WEBROOT Setting |
|----------|-----------------|
| Laravel, Symfony | Default (`/var/www/html/public`) |
| WordPress, plain PHP | `WEBROOT: /var/www/html` |

## Octane Server Options

Cbox PM supports all three Laravel Octane servers:

| Server | Image | Environment Variable |
|--------|-------|---------------------|
| Swoole | `php-swoole:8.3-bookworm` | `OCTANE_SERVER: swoole` |
| RoadRunner | `php-fpm-nginx:8.3-bookworm` | `OCTANE_SERVER: roadrunner` |
| FrankenPHP | `php-frankenphp:8.3-bookworm` | `OCTANE_SERVER: frankenphp` |

See [Octane documentation](../docs/guides/laravel-octane.md) for full configuration reference.

## Choosing an Example

### By Framework

- **Laravel**: `laravel-basic`, `laravel-horizon`, `laravel-production`, `octane-*`, `reverb-websockets`
- **Symfony**: `symfony-basic`
- **WordPress**: `wordpress`
- **Plain PHP**: `php-basic`, `api-only`

### By Environment

- **Development**: `development` (Xdebug, hot reload, exposed ports)
- **Production**: `laravel-production` (optimized, resource limits)
- **Testing**: Use any with `APP_ENV=testing`

### By Architecture

- **Monolith**: `laravel-basic`, `symfony-basic`
- **Queue-heavy**: `laravel-horizon`
- **High-performance**: `octane-swoole`, `octane-roadrunner`, `octane-frankenphp`
- **Real-time**: `reverb-websockets`
- **Multi-tenant SaaS**: `multi-tenant`
- **Microservices**: `microservices`

## Volume Strategies

### Development (bind mount)
```yaml
volumes:
  - ./:/var/www/html  # Your code synced to container
```

### Production (named volumes)
```yaml
volumes:
  - app_storage:/var/www/html/storage
  - app_cache:/var/www/html/bootstrap/cache

volumes:
  app_storage:
  app_cache:
```

### Mixed (common pattern)
```yaml
volumes:
  - ./:/var/www/html                    # Code (bind mount)
  - mysql_data:/var/lib/mysql           # Database (named volume)
```

## Common Patterns

### Enable Queue Workers

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm
    environment:
      LARAVEL_QUEUE: "true"
      REDIS_HOST: redis
      QUEUE_CONNECTION: redis
```

### Enable Horizon (Production Queues)

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm
    environment:
      LARAVEL_HORIZON: "true"     # Use instead of LARAVEL_QUEUE
      REDIS_HOST: redis
```

### Enable Scheduler

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm
    environment:
      LARAVEL_SCHEDULER: "true"
```

### Enable Octane

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-swoole:8.3-bookworm
    environment:
      LARAVEL_OCTANE: "true"
      OCTANE_SERVER: swoole
      OCTANE_PORT: 8000
```

### Enable Reverb WebSockets

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm
    ports:
      - "8080:80"
      - "8085:8085"
    environment:
      LARAVEL_REVERB: "true"
      REVERB_HOST: 0.0.0.0
      REVERB_PORT: 8085
```

## Customization

All examples use Cbox images. Swap versions as needed:

```yaml
# Use different PHP version
image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm

# Use different tier
image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm-slim
image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm-full
```

## Need Help?

- Check the README in each example folder
- See [documentation](../docs/) for detailed guides
- See [Laravel Octane Guide](../docs/guides/laravel-octane.md) for Octane configuration
- Open an issue on GitHub
