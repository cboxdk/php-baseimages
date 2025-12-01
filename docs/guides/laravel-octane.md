---
title: "Laravel Octane"
description: "High-performance Laravel with Swoole, RoadRunner, or FrankenPHP using PHPeek PM"
weight: 15
---

# Laravel Octane

Run Laravel Octane with PHPeek PM for high-performance applications. PHPeek PM supports all three Octane servers: **Swoole**, **RoadRunner**, and **FrankenPHP**.

## Quick Start

```yaml
services:
  app:
    image: ghcr.io/phpeek/baseimages/php-swoole:8.3-alpine
    environment:
      LARAVEL_OCTANE: "true"
      OCTANE_SERVER: swoole
```

That's it. PHPeek PM handles everything else.

## Server Comparison

| Feature | Swoole | RoadRunner | FrankenPHP |
|---------|--------|------------|------------|
| **Language** | PHP Extension (C) | Go Binary | Go Binary (Caddy) |
| **HTTP/2** | ✅ | ✅ | ✅ |
| **HTTP/3** | ❌ | ✅ | ✅ |
| **Auto HTTPS** | ❌ | ❌ | ✅ (Caddy) |
| **gRPC** | ❌ | ✅ | ❌ |
| **Task Workers** | ✅ | ❌ | ❌ |
| **Coroutines** | ✅ | ❌ | ❌ |
| **Memory** | Lower | Medium | Medium |
| **Setup** | Extension required | Binary download | Binary download |
| **PHPeek Image** | `php-swoole` | `php-fpm-nginx` | `php-frankenphp` |

## Configuration Reference

### Core Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `LARAVEL_OCTANE` | Enable Octane server | `false` |
| `OCTANE_SERVER` | Server type: `swoole`, `roadrunner`, `frankenphp` | `swoole` |
| `OCTANE_HOST` | Listen address | `0.0.0.0` |
| `OCTANE_PORT` | Listen port | `8000` |
| `OCTANE_WORKERS` | Worker count (`auto` = CPU cores) | `auto` |
| `OCTANE_MAX_REQUESTS` | Requests before worker restart | `500` |
| `OCTANE_WATCH` | Enable file watching (dev only) | `false` |

### Swoole-Specific

| Variable | Description | Default |
|----------|-------------|---------|
| `OCTANE_TASK_WORKERS` | Task worker count | `auto` |

### RoadRunner-Specific

| Variable | Description | Default |
|----------|-------------|---------|
| `OCTANE_RPC_HOST` | RPC host for internal communication | `127.0.0.1` |
| `OCTANE_RPC_PORT` | RPC port | `6001` |

### FrankenPHP-Specific

| Variable | Description | Default |
|----------|-------------|---------|
| `OCTANE_HTTPS_PORT` | HTTPS port (Caddy auto-TLS) | `443` |
| `OCTANE_CADDYFILE` | Custom Caddyfile path | (none) |

## Example Configurations

### Swoole (Best Performance)

```yaml
# examples/octane-swoole/docker-compose.yml
services:
  app:
    image: ghcr.io/phpeek/baseimages/php-swoole:8.3-alpine
    ports:
      - "8080:8000"
    environment:
      LARAVEL_OCTANE: "true"
      OCTANE_SERVER: swoole
      OCTANE_HOST: 0.0.0.0
      OCTANE_PORT: 8000
      OCTANE_WORKERS: auto
      OCTANE_TASK_WORKERS: auto
      OCTANE_MAX_REQUESTS: 500

      # Also enable queue and scheduler
      LARAVEL_QUEUE: "true"
      LARAVEL_SCHEDULER: "true"
```

**When to use Swoole:**
- Maximum performance requirements
- Need coroutines for async operations
- Task workers for background processing
- Lower memory footprint

### RoadRunner (Most Flexible)

```yaml
# examples/octane-roadrunner/docker-compose.yml
services:
  app:
    image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine
    ports:
      - "8080:8000"
    environment:
      LARAVEL_OCTANE: "true"
      OCTANE_SERVER: roadrunner
      OCTANE_HOST: 0.0.0.0
      OCTANE_PORT: 8000
      OCTANE_WORKERS: auto
      OCTANE_RPC_HOST: 127.0.0.1
      OCTANE_RPC_PORT: 6001

      LARAVEL_QUEUE: "true"
      LARAVEL_SCHEDULER: "true"
```

**When to use RoadRunner:**
- Need gRPC support
- HTTP/3 requirements
- No PHP extension dependencies
- Built-in load balancing needs

### FrankenPHP (Easiest HTTPS)

```yaml
# examples/octane-frankenphp/docker-compose.yml
services:
  app:
    image: ghcr.io/phpeek/baseimages/php-frankenphp:8.3-alpine
    ports:
      - "8080:8000"
      - "8443:443"
    environment:
      LARAVEL_OCTANE: "true"
      OCTANE_SERVER: frankenphp
      OCTANE_HOST: 0.0.0.0
      OCTANE_PORT: 8000
      OCTANE_HTTPS_PORT: 443
      OCTANE_WORKERS: auto

      LARAVEL_QUEUE: "true"
      LARAVEL_SCHEDULER: "true"
```

**When to use FrankenPHP:**
- Automatic HTTPS with Let's Encrypt
- HTTP/2 and HTTP/3 native support
- Early Hints (103) for performance
- Simpler TLS configuration

## Laravel Setup

### 1. Install Octane

```bash
composer require laravel/octane
```

### 2. Install Server

```bash
# For Swoole (extension must be in image)
php artisan octane:install --server=swoole

# For RoadRunner (downloads binary)
php artisan octane:install --server=roadrunner

# For FrankenPHP (downloads binary)
php artisan octane:install --server=frankenphp
```

### 3. Configure Environment

PHPeek PM reads these from your container environment:

```bash
# .env is NOT needed - use docker-compose environment instead
# PHPeek PM passes all env vars to Octane
```

## Production Considerations

### Worker Count

```yaml
environment:
  # Auto-scale to CPU cores (recommended)
  OCTANE_WORKERS: auto

  # Or set explicitly for predictable resource usage
  OCTANE_WORKERS: "4"
```

### Request Limits

```yaml
environment:
  # Restart workers after N requests to prevent memory leaks
  OCTANE_MAX_REQUESTS: 500
```

### Combined with Horizon

For production queues, use Horizon instead of basic queue workers:

```yaml
environment:
  LARAVEL_OCTANE: "true"
  OCTANE_SERVER: swoole
  LARAVEL_HORIZON: "true"      # Use Horizon, NOT LARAVEL_QUEUE
  LARAVEL_SCHEDULER: "true"
```

### Health Checks

PHPeek PM includes built-in health checks for Octane. No configuration needed.

```yaml
# ✅ Correct - use built-in health check
services:
  app:
    image: ghcr.io/phpeek/baseimages/php-swoole:8.3-alpine
    # No healthcheck override needed

# ❌ Wrong - don't override
services:
  app:
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/"]
```

## Troubleshooting

### Octane Not Starting

```bash
# Check PHPeek PM status
docker exec <container> phpeek-pm status

# Check Octane logs
docker exec <container> phpeek-pm logs octane
```

### Memory Issues

```yaml
environment:
  # Lower max requests to restart workers more frequently
  OCTANE_MAX_REQUESTS: 250
```

### Extension Not Found (Swoole)

Ensure you're using the correct image:

```yaml
# ✅ Correct for Swoole
image: ghcr.io/phpeek/baseimages/php-swoole:8.3-alpine

# ❌ Wrong - doesn't have Swoole extension
image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine
```

## See Also

- [Examples: octane-swoole/](../../examples/octane-swoole/)
- [Examples: octane-roadrunner/](../../examples/octane-roadrunner/)
- [Examples: octane-frankenphp/](../../examples/octane-frankenphp/)
- [Queue Workers Guide](queue-workers.md)
- [PHPeek PM Integration](../phpeek-pm-integration.md)
