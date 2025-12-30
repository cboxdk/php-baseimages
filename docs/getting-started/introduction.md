---
title: "Introduction"
description: "Why PHPeek? Features, comparisons with ServerSideUp, Bitnami, and official PHP images"
weight: 1
---

# Introduction to PHPeek Base Images

PHPeek Base Images are production-ready PHP Docker containers designed for modern PHP applications. Built with a "batteries included" philosophy while maintaining clean, optimized images.

## Why PHPeek?

### The Problem

Setting up PHP containers for production requires decisions:

1. **Official PHP images are minimal** - You need to install 20+ extensions yourself
2. **Extension management is time-consuming** - Compiling extensions for each version
3. **Process management choices** - Different approaches (S6 Overlay, supervisord, bash)
4. **Configuration varies** - Each solution has different conventions
5. **Security updates need attention** - Keeping base images current

### The PHPeek Solution

PHPeek provides production-ready containers with:

- **Three Image Tiers** - Slim (~120MB), Standard (~250MB), Full (~700MB)
- **25+ PHP extensions pre-installed** - Everything Laravel, Symfony, WordPress need
- **PHPeek PM built-in** - Lightweight Go-based process manager (no S6 Overlay)
- **50+ environment variables** - Runtime configuration without rebuilding
- **Weekly security rebuilds** - Automatic CVE patching
- **Framework auto-detection** - Laravel, Symfony, WordPress optimizations

See [PHPeek PM Integration](../phpeek-pm-integration.md) for advanced configuration.

## Three Image Tiers

PHPeek images come in three tiers to match your exact needs:

| Tier | Size | Use Case |
|------|------|----------|
| **Slim** | ~120MB | APIs, microservices, minimal footprint |
| **Standard** | ~250MB | Most Laravel/PHP apps (DEFAULT) |
| **Full** | ~700MB | Browsershot, Dusk, PDF generation |

**Quick decision**:
- Need PDF generation or browser testing? → **Full**
- Building a standard Laravel/PHP app? → **Standard** (default)
- Building APIs or microservices? → **Slim**

## PHPeek vs Alternatives

### vs ServerSideUp/docker-php

| Feature | PHPeek | ServerSideUp |
|---------|--------|--------------|
| Process Manager | PHPeek PM (Go binary) | S6 Overlay |
| Image Tiers | 3 (Slim/Standard/Full) | 2 (Base/Full) |
| Framework Support | Laravel/Symfony/WordPress | Laravel-focused |
| PHP Versions | 8.2, 8.3, 8.4, 8.5 | 8.1, 8.2, 8.3, 8.4 |
| Community | Newer project | Established, active |

**When to choose PHPeek**: You need PHP 8.5, Symfony/WordPress support, or built-in Prometheus metrics.

**When to choose ServerSideUp**: You want established community support, proven S6 Overlay patterns, or Laravel-focused optimizations.

Both are production-ready. See [PHPeek vs ServerSideUp](../guides/phpeek-vs-serversideup.md) for detailed comparison.

### vs Official PHP Images

| Feature | PHPeek | Official PHP |
|---------|--------|--------------|
| Extensions | 25+ included | ~10 basic |
| Production Ready | Yes | No (minimal) |
| Nginx Integration | Built-in | Separate setup |
| Framework Support | Auto-detection | None |
| Image Size | 120-700MB | 120MB+ (with extensions) |

**When to choose PHPeek**: Production applications, rapid development, team standardization.

**When to choose Official**: Maximum control, learning Docker, custom requirements.

### vs Bitnami

| Feature | PHPeek | Bitnami |
|---------|--------|---------|
| Image Size | 120-700MB | 400-600MB |
| Customization | Easy | Complex |
| Configuration | Environment vars | Config files |
| Updates | Weekly | Bitnami schedule |

**When to choose PHPeek**: Smaller images, simpler customization.

**When to choose Bitnami**: VMware ecosystem, Helm charts.

## Core Innovations

### PHPeek Process Manager

PHPeek uses a lightweight Go-based process manager:

```bash
# What happens at container start:
1. Detect framework (Laravel/Symfony/WordPress)
2. Fix directory permissions automatically
3. PHPeek PM starts as PID 1
4. PHPeek PM orchestrates PHP-FPM, Nginx, and optional workers
5. Health checks monitor all processes with auto-restart
6. Graceful shutdown on SIGTERM
```

**Benefits**:
- Easy to debug (structured JSON logs, standard process inspection)
- Single Go binary for process management
- Built-in health checks and Prometheus metrics
- Automatic process restart on failure
- Custom scripts via `/docker-entrypoint-init.d/`

See [PHPeek PM Integration](../phpeek-pm-integration.md) for configuration options.

### Framework Auto-Detection

PHPeek automatically detects and configures:

```bash
# Laravel detected (artisan file exists)
INFO: Laravel application detected
INFO: Auto-fixing Laravel directory permissions...
INFO: Enabling Laravel scheduler...

# Symfony detected (bin/console exists)
INFO: Symfony application detected
INFO: Setting up var/ directory permissions...

# WordPress detected (wp-config.php exists)
INFO: WordPress application detected
INFO: Configuring wp-content permissions...
```

### Runtime Configuration

Configure everything via environment variables:

```yaml
services:
  app:
    image: ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-bookworm
    environment:
      # PHP
      PHP_MEMORY_LIMIT: 512M
      PHP_MAX_EXECUTION_TIME: 120

      # Laravel
      LARAVEL_SCHEDULER: true
      LARAVEL_QUEUE: true

      # Nginx
      NGINX_CLIENT_MAX_BODY_SIZE: 100M
```

No Dockerfile changes needed!

## Architecture Overview

### Image Types

```
php-fpm-nginx/     # All-in-one (recommended for most)
```

### Image Tiers

| Tier | Tag | Includes |
|------|-----|----------|
| **Slim** | `-slim` | Core extensions (25+) |
| **Standard** | (none) | + ImageMagick, vips, Node.js |
| **Full** | `-full` | + Chromium for browser automation |

### Rootless Variants

All tiers support rootless execution:

| Tag | Description |
|-----|-------------|
| `8.4-bookworm-rootless` | Standard + rootless |
| `8.4-bookworm-slim-rootless` | Slim + rootless |
| `8.4-bookworm-full-rootless` | Full + rootless |

## Getting Started

Ready to try PHPeek?

1. **[5-Minute Quickstart](quickstart.md)** - Get running immediately
2. **[Laravel Guide](../guides/laravel-guide.md)** - Complete Laravel setup
3. **[Choosing a Variant](choosing-variant.md)** - Which tier to use

## Requirements

- Docker 20.10+ (BuildKit recommended)
- Docker Compose 2.0+ (optional)
- 512MB RAM minimum (1GB+ recommended)

## Support

- **Documentation**: You're reading it!
- **Issues**: [GitHub Issues](https://github.com/gophpeek/baseimages/issues)
- **Discussions**: [GitHub Discussions](https://github.com/gophpeek/baseimages/discussions)
