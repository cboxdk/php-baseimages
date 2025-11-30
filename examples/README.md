---
title: "Example Applications"
description: "Production-ready Docker Compose setups for common PHP application patterns"
weight: 1
---

# Example Applications

Copy-paste ready Docker Compose configurations for common use cases.

## Quick Reference

| Example | Use Case | Services |
|---------|----------|----------|
| [Laravel Basic](laravel-basic/) | Simple web app | PHP, Nginx, MySQL |
| [Laravel Horizon](laravel-horizon/) | Queue processing | PHP, Horizon, Scheduler, MySQL, Redis |
| [Laravel Octane](laravel-octane/) | High performance | Swoole, MySQL, Redis |
| [Symfony Basic](symfony-basic/) | Symfony app | PHP, Messenger, PostgreSQL |
| [WordPress](wordpress/) | CMS setup | PHP, MySQL |
| [API Only](api-only/) | REST/GraphQL API | PHP, PostgreSQL, Redis |
| [Development](development/) | Local dev | Xdebug, Vite HMR, MailHog |
| [Production](production/) | Deploy ready | Resource limits, health checks |
| [Multi-Tenant](multi-tenant/) | SaaS | Central DB + Tenant DBs |
| [Static Assets](static-assets/) | Pre-built frontend | PHP only, no Node runtime |

## How to Use

1. Copy the example folder to your project
2. Adjust `docker-compose.yml` for your needs
3. Run `docker compose up -d`

```bash
# Example: Start Laravel basic setup
cp -r examples/laravel-basic/* ./
docker compose up -d
```

## Choosing an Example

### By Framework

- **Laravel**: `laravel-basic`, `laravel-horizon`, `laravel-octane`
- **Symfony**: `symfony-basic`
- **WordPress**: `wordpress`
- **Custom/API**: `api-only`

### By Environment

- **Development**: `development` (Xdebug, hot reload, exposed ports)
- **Production**: `production` (optimized, resource limits)
- **Testing**: Use any with `APP_ENV=testing`

### By Architecture

- **Monolith**: `laravel-basic`, `symfony-basic`
- **Queue-heavy**: `laravel-horizon`
- **High-performance**: `laravel-octane`
- **Multi-tenant SaaS**: `multi-tenant`

## Customization

All examples use PHPeek images. Swap versions as needed:

```yaml
# Use different PHP version
image: phpeek/php-fpm-nginx:8.4-alpine

# Use different OS variant
image: phpeek/php-fpm-nginx:8.3-debian
image: phpeek/php-fpm-nginx:8.3-ubuntu
```

## Common Patterns

### Adding Redis Cache

```yaml
services:
  redis:
    image: redis:7-alpine
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
```

### Adding Queue Worker

```yaml
services:
  worker:
    image: phpeek/php-fpm-nginx:8.3-alpine
    command: php artisan queue:work
```

### Adding Scheduler

```yaml
services:
  scheduler:
    image: phpeek/php-fpm-nginx:8.3-alpine
    command: >
      sh -c "while true; do php artisan schedule:run; sleep 60; done"
```

## Need Help?

- Check the README in each example folder
- See [documentation](../docs/) for detailed guides
- Open an issue on GitHub
