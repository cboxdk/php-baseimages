---
title: "Swoole Guide"
description: "High-performance PHP with Swoole extension for Laravel Octane and async applications"
weight: 16
---

# Swoole Guide

Run high-performance PHP applications with the Swoole extension. Perfect for Laravel Octane, Hyperf, and custom async applications.

## Quick Start

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-swoole:8.4-bookworm
    ports:
      - "8000:8000"
    volumes:
      - ./:/var/www/html
```

```bash
docker-compose up -d
```

## What is Swoole?

Swoole is a high-performance coroutine-based PHP extension written in C. It provides:

- **Event-driven architecture** - Non-blocking I/O for maximum throughput
- **Coroutines** - Write async code that looks synchronous
- **Task workers** - Offload heavy operations to background workers
- **Built-in servers** - HTTP, WebSocket, TCP, UDP servers
- **Connection pooling** - Efficient database and Redis connections

## Cbox Swoole Images

| Image | PHP | Swoole | Architecture |
|-------|-----|--------|--------------|
| `php-swoole:8.4-bookworm` | 8.4 | Latest | amd64, arm64 |
| `php-swoole:8.3-bookworm` | 8.3 | Latest | amd64, arm64 |
| `php-swoole:8.2-bookworm` | 8.2 | Latest | amd64, arm64 |

All images include:
- Swoole extension with OpenSSL, cURL, c-ares support
- All standard Cbox extensions (Redis, MongoDB, etc.)
- Composer, Node.js, Cbox PM
- `swoole.use_shortname = Off` for Laravel compatibility

## Laravel Octane Setup

### 1. Install Octane

```bash
composer require laravel/octane
php artisan octane:install --server=swoole
```

### 2. Configure Docker Compose

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-swoole:8.4-bookworm
    ports:
      - "8000:8000"
    volumes:
      - ./:/var/www/html
    environment:
      # Octane will auto-start when detected
      OCTANE_PORT: "8000"
      OCTANE_WORKERS: "auto"
      OCTANE_TASK_WORKERS: "auto"
      OCTANE_MAX_REQUESTS: "500"

      # Laravel features
      LARAVEL_SCHEDULER: "true"
      LARAVEL_QUEUE: "true"
```

### 3. Start

```bash
docker-compose up -d
```

The entrypoint automatically detects Laravel Octane and starts it with Swoole.

## Environment Variables

### Octane Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `OCTANE_PORT` | HTTP listen port | `8000` |
| `OCTANE_WORKERS` | Worker processes (`auto` = CPU cores) | `auto` |
| `OCTANE_TASK_WORKERS` | Task worker processes | `auto` |
| `OCTANE_MAX_REQUESTS` | Requests before worker restart | `500` |

### Laravel Features

| Variable | Description | Default |
|----------|-------------|---------|
| `LARAVEL_SCHEDULER` | Enable cron for `schedule:run` | `false` |
| `LARAVEL_QUEUE` | Enable queue worker | `false` |
| `LARAVEL_HORIZON` | Enable Horizon (instead of basic queue) | `false` |
| `LARAVEL_MIGRATE_ENABLED` | Auto-run migrations on startup | `false` |
| `LARAVEL_OPTIMIZE_ENABLED` | Auto-cache config/routes | `false` |

## Production Configuration

### Recommended Settings

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-swoole:8.4-bookworm
    ports:
      - "8000:8000"
    volumes:
      - ./:/var/www/html:ro  # Read-only for security
    environment:
      # Performance
      OCTANE_WORKERS: "auto"
      OCTANE_TASK_WORKERS: "4"
      OCTANE_MAX_REQUESTS: "1000"

      # Caching
      LARAVEL_OPTIMIZE_ENABLED: "true"

      # Background processing
      LARAVEL_HORIZON: "true"
      LARAVEL_SCHEDULER: "true"
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 1G
```

### Worker Scaling

```yaml
# CPU-bound workloads (calculations, image processing)
OCTANE_WORKERS: "4"        # Match CPU cores
OCTANE_TASK_WORKERS: "8"   # 2x workers for offloading

# I/O-bound workloads (database, API calls)
OCTANE_WORKERS: "16"       # Higher count for concurrent I/O
OCTANE_TASK_WORKERS: "4"   # Fewer task workers needed
```

### Memory Management

Swoole workers persist in memory. Prevent memory leaks:

```yaml
environment:
  # Restart workers after N requests
  OCTANE_MAX_REQUESTS: "500"

  # PHP memory limit per worker
  PHP_MEMORY_LIMIT: "256M"
```

## Swoole vs Other Servers

| Feature | Swoole | RoadRunner | FrankenPHP |
|---------|--------|------------|------------|
| **Performance** | Fastest | Fast | Fast |
| **Coroutines** | Native | No | No |
| **Task Workers** | Yes | No | No |
| **HTTP/3** | No | Yes | Yes |
| **Auto HTTPS** | No | No | Yes (Caddy) |
| **gRPC** | No | Yes | No |
| **Memory** | Lowest | Medium | Medium |

**Choose Swoole when:**
- Maximum performance is critical
- You need coroutines for async operations
- Task workers for background processing are required
- Memory efficiency matters

## Custom Swoole Applications

For non-Laravel Swoole apps, pass a custom command:

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-swoole:8.4-bookworm
    command: php /var/www/html/server.php
```

Or use the entrypoint for setup, then custom command:

```dockerfile
FROM ghcr.io/cboxdk/baseimages/php-swoole:8.4-bookworm

COPY . /var/www/html

CMD ["php", "server.php"]
```

## Health Checks

The image includes a built-in health check. For custom endpoints:

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-swoole:8.4-bookworm
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 5s
      retries: 3
```

## Troubleshooting

### Swoole Not Found

```bash
# Verify Swoole is loaded
docker run --rm ghcr.io/cboxdk/baseimages/php-swoole:8.4-bookworm php -m | grep swoole
```

### Octane Not Starting

```bash
# Check logs
docker-compose logs app

# Verify Octane is installed
docker-compose exec app php artisan octane:status
```

### Memory Issues

```yaml
# Lower max requests for faster recycling
environment:
  OCTANE_MAX_REQUESTS: "250"
```

### Coroutine Deadlocks

Avoid blocking operations in coroutines:

```php
// Wrong - blocks coroutine
sleep(5);

// Correct - yields to other coroutines
Swoole\Coroutine::sleep(5);
```

## See Also

- [Laravel Octane Guide](./laravel-octane.md) - Complete Octane setup
- [FrankenPHP Guide](./frankenphp-guide.md) - Alternative with auto HTTPS
- [Queue Workers Guide](./queue-workers.md) - Background job processing
- [Available Images](../reference/available-images.md) - All image variants
