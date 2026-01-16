---
title: "FrankenPHP Guide"
description: "Modern PHP application server with automatic HTTPS, HTTP/3, and worker mode"
weight: 17
---

# FrankenPHP Guide

FrankenPHP is a modern PHP application server built on Caddy. It provides automatic HTTPS, HTTP/3 support, and high-performance worker mode for Laravel Octane.

## Quick Start

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/frankenphp:8.4-bookworm
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./:/var/www/html
```

```bash
docker-compose up -d
```

## What is FrankenPHP?

FrankenPHP is a PHP application server created by Kévin Dunglas (creator of API Platform). Key features:

- **Built on Caddy** - Production-ready web server with automatic HTTPS
- **Automatic HTTPS** - Let's Encrypt certificates with zero configuration
- **HTTP/2 and HTTP/3** - Modern protocols out of the box
- **Early Hints (103)** - Faster page loads with preloading
- **Worker Mode** - Keep PHP in memory like Swoole/RoadRunner
- **No PHP-FPM** - Direct PHP execution for better performance

## Cbox FrankenPHP Images

| Image | PHP | FrankenPHP | Architecture |
|-------|-----|------------|--------------|
| `frankenphp:8.4-bookworm` | 8.4 | Latest | amd64, arm64 |
| `frankenphp:8.3-bookworm` | 8.3 | Latest | amd64, arm64 |
| `frankenphp:8.2-bookworm` | 8.2 | Latest | amd64, arm64 |

All images include:
- FrankenPHP binary with Caddy integration
- All standard Cbox extensions (Redis, MongoDB, etc.)
- Composer, Node.js, Cbox PM
- Automatic Caddyfile generation

## Laravel Octane Setup

### 1. Install Octane

```bash
composer require laravel/octane
php artisan octane:install --server=frankenphp
```

### 2. Configure Docker Compose

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/frankenphp:8.4-bookworm
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"  # HTTP/3 (QUIC)
    volumes:
      - ./:/var/www/html
      - caddy_data:/data
      - caddy_config:/config
    environment:
      SERVER_NAME: "localhost"  # Or your domain
      FRANKENPHP_PORT: "80"
      FRANKENPHP_HTTPS_PORT: "443"

      # Laravel features
      LARAVEL_SCHEDULER: "true"
      LARAVEL_QUEUE: "true"

volumes:
  caddy_data:
  caddy_config:
```

### 3. Start

```bash
docker-compose up -d
```

The entrypoint automatically detects Laravel Octane and starts it with FrankenPHP.

## Environment Variables

### FrankenPHP Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `SERVER_NAME` | Server name/domain | `:80` |
| `FRANKENPHP_PORT` | HTTP port | `80` |
| `FRANKENPHP_HTTPS_PORT` | HTTPS port | `443` |

### Octane Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `OCTANE_WORKERS` | Worker processes (`auto` = CPU cores) | `auto` |
| `OCTANE_MAX_REQUESTS` | Requests before worker restart | `500` |

### Laravel Features

| Variable | Description | Default |
|----------|-------------|---------|
| `LARAVEL_SCHEDULER` | Enable cron for `schedule:run` | `false` |
| `LARAVEL_QUEUE` | Enable queue worker | `false` |
| `LARAVEL_HORIZON` | Enable Horizon (instead of basic queue) | `false` |
| `LARAVEL_MIGRATE_ENABLED` | Auto-run migrations on startup | `false` |
| `LARAVEL_OPTIMIZE_ENABLED` | Auto-cache config/routes | `false` |

## Automatic HTTPS

### Local Development (Self-Signed)

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/frankenphp:8.4-bookworm
    ports:
      - "443:443"
    environment:
      SERVER_NAME: "localhost"
    volumes:
      - caddy_data:/data  # Stores certificates
```

Access: `https://localhost` (accept self-signed certificate)

### Production (Let's Encrypt)

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/frankenphp:8.4-bookworm
    ports:
      - "80:80"
      - "443:443"
    environment:
      SERVER_NAME: "example.com"
    volumes:
      - caddy_data:/data  # Persists Let's Encrypt certificates
      - caddy_config:/config
```

Let's Encrypt certificates are automatically obtained and renewed.

## Custom Caddyfile

For advanced configuration, mount a custom Caddyfile:

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/frankenphp:8.4-bookworm
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ./:/var/www/html
```

Example Caddyfile:

```caddyfile
{
    frankenphp
    order php_server before file_server
}

example.com {
    root * /var/www/html/public
    encode zstd gzip

    # Health check
    respond /health 200

    # Static files
    @static {
        file
        path *.css *.js *.ico *.gif *.jpg *.jpeg *.png *.svg *.woff *.woff2
    }
    handle @static {
        file_server
    }

    # PHP
    php_server
}
```

## Production Configuration

### Recommended Settings

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/frankenphp:8.4-bookworm
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    volumes:
      - ./:/var/www/html:ro
      - caddy_data:/data
      - caddy_config:/config
    environment:
      SERVER_NAME: "example.com"
      OCTANE_WORKERS: "auto"
      OCTANE_MAX_REQUESTS: "1000"
      LARAVEL_OPTIMIZE_ENABLED: "true"
      LARAVEL_HORIZON: "true"
      LARAVEL_SCHEDULER: "true"
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 1G

volumes:
  caddy_data:
  caddy_config:
```

### HTTP/3 (QUIC)

HTTP/3 is enabled by default. Ensure UDP port 443 is exposed:

```yaml
ports:
  - "443:443"
  - "443:443/udp"  # Required for HTTP/3
```

## FrankenPHP vs Other Servers

| Feature | FrankenPHP | Swoole | RoadRunner |
|---------|------------|--------|------------|
| **Auto HTTPS** | Yes (Caddy) | No | No |
| **HTTP/3** | Yes | No | Yes |
| **HTTP/2** | Yes | Yes | Yes |
| **Early Hints** | Yes | No | No |
| **Coroutines** | No | Yes | No |
| **Task Workers** | No | Yes | No |
| **gRPC** | No | No | Yes |
| **Memory** | Medium | Lowest | Medium |

**Choose FrankenPHP when:**
- You want automatic HTTPS without reverse proxy setup
- HTTP/3 support is important
- Simplicity is preferred over raw performance
- You're using Caddy ecosystem features

## Standalone PHP Applications

For non-Laravel applications:

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/frankenphp:8.4-bookworm
    volumes:
      - ./:/var/www/html
    environment:
      SERVER_NAME: ":80"
```

FrankenPHP will serve `public/index.php` automatically.

## Health Checks

Built-in health check endpoint at `/health`:

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/frankenphp:8.4-bookworm
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 5s
      retries: 3
```

## Troubleshooting

### FrankenPHP Version

```bash
docker run --rm ghcr.io/cboxdk/baseimages/frankenphp:8.4-bookworm frankenphp version
```

### Certificate Issues

```bash
# Check Caddy logs
docker-compose logs app | grep -i "tls\|cert"

# Verify certificate
openssl s_client -connect localhost:443 -servername localhost
```

### Octane Not Starting

```bash
# Check if Octane is detected
docker-compose logs app | grep -i "octane"

# Verify Octane installation
docker-compose exec app php artisan octane:status
```

### Permission Errors

```yaml
volumes:
  - caddy_data:/data    # Must be writable for certificates
  - caddy_config:/config
```

### Port Conflicts

If port 80/443 is in use:

```yaml
environment:
  SERVER_NAME: ":8080"
ports:
  - "8080:8080"
```

## See Also

- [Laravel Octane Guide](./laravel-octane.md) - Complete Octane setup
- [Swoole Guide](./swoole-guide.md) - Maximum performance with coroutines
- [Queue Workers Guide](./queue-workers.md) - Background job processing
- [Available Images](../reference/available-images.md) - All image variants
