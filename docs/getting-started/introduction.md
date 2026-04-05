---
title: "Introduction"
description: "Why Cbox? Features, comparisons with ServerSideUp, Bitnami, and official PHP images"
weight: 1
---

# Introduction to Cbox PHP Base Images

Cbox PHP Base Images are production-ready PHP Docker containers designed for modern PHP applications. Built with a "batteries included" philosophy while maintaining clean, optimized images.

## Why Cbox?

### The Problem

Setting up PHP containers for production requires decisions:

1. **Official PHP images are minimal** - You need to install 20+ extensions yourself
2. **Extension management is time-consuming** - Compiling extensions for each version
3. **Process management choices** - Different approaches (S6 Overlay, supervisord, bash)
4. **Configuration varies** - Each solution has different conventions
5. **Security updates need attention** - Keeping base images current

### The Cbox Solution

Cbox provides production-ready containers with:

- **Four Image Tiers** - Slim (~120 MiB), Standard (~250 MiB), Chromium (~700 MiB), Dev (~750 MiB)
- **25+ PHP extensions pre-installed** - Everything Laravel, Symfony, WordPress need
- **Cbox Init built-in** - Lightweight Go-based process manager (no S6 Overlay)
- **50+ environment variables** - Runtime configuration without rebuilding
- **Weekly security rebuilds** - Automatic CVE patching
- **Framework auto-detection** - Laravel, Symfony, WordPress optimizations

See [Cbox Init Integration](../cbox-init-integration.md) for advanced configuration.

## Four Image Tiers

Cbox images come in four tiers -- Slim (~120 MiB), Standard (~250 MiB), Chromium (~700 MiB), and Dev (~750 MiB) -- to match your exact needs. See [Choosing Your Image](choosing-your-image) for the full size matrix and decision guide.

## Cbox vs Alternatives

### vs ServerSideUp/docker-php

| Feature | Cbox | ServerSideUp |
|---------|--------|--------------|
| Process Manager | Cbox Init (Go binary) | S6 Overlay |
| Image Tiers | 4 (Slim/Standard/Chromium/Dev) | 2 (Base/Full) |
| Framework Support | Laravel/Symfony/WordPress | Laravel-focused |
| PHP Versions | 8.2, 8.3, 8.4, 8.5 | 8.1, 8.2, 8.3, 8.4, 8.5 |
| Community | Newer project | Established, active |

**When to choose Cbox**: You need Symfony/WordPress support, built-in Prometheus metrics, or prefer a single-binary process manager.

**When to choose ServerSideUp**: You want established community support, proven S6 Overlay patterns, or Laravel-focused optimizations.

Both are production-ready. See [Cbox vs ServerSideUp](../guides/cbox-vs-serversideup.md) for detailed comparison.

### vs Official PHP Images

| Feature | Cbox | Official PHP |
|---------|--------|--------------|
| Extensions | 25+ included | ~10 basic |
| Production Ready | Yes | No (minimal) |
| Nginx Integration | Built-in | Separate setup |
| Framework Support | Auto-detection | None |
| Image Size | 120-750 MiB | 120 MiB+ (with extensions) |

**When to choose Cbox**: Production applications, rapid development, team standardization.

**When to choose Official**: Maximum control, learning Docker, custom requirements.

### vs Bitnami

| Feature | Cbox | Bitnami |
|---------|--------|---------|
| Image Size | 120-750 MiB | 400-600 MiB |
| Customization | Easy | Complex |
| Configuration | Environment vars | Config files |
| Updates | Weekly | Bitnami schedule |

**When to choose Cbox**: Smaller images, simpler customization.

**When to choose Bitnami**: VMware ecosystem, Helm charts.

## Core Innovations

### Cbox Process Manager

Cbox uses a lightweight Go-based process manager:

```bash
# What happens at container start:
1. Detect framework (Laravel/Symfony/WordPress)
2. Fix directory permissions automatically
3. Cbox Init starts as PID 1
4. Cbox Init orchestrates PHP-FPM, Nginx, and optional workers
5. Health checks monitor all processes with auto-restart
6. Graceful shutdown on SIGTERM
```

**Benefits**:
- Easy to debug (structured JSON logs, standard process inspection)
- Single Go binary for process management
- Built-in health checks and Prometheus metrics
- Automatic process restart on failure
- Custom scripts via `/docker-entrypoint-init.d/`

See [Cbox Init Integration](../cbox-init-integration.md) for configuration options.

### Framework Auto-Detection

Cbox automatically detects and configures:

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
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm
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

For the full image size matrix, tier contents, rootless variants, and single-service vs multi-service comparison, see [Choosing Your Image](choosing-your-image).

## Getting Started

Ready to try Cbox?

1. **[5-Minute Quickstart](quickstart.md)** - Get running immediately
2. **[Laravel Guide](../guides/laravel-guide.md)** - Complete Laravel setup
3. **[Choosing Your Image](choosing-your-image)** - Which tier to use

## Requirements

- Docker 20.10+ (BuildKit recommended)
- Docker Compose 2.0+ (optional)
- 512MB RAM minimum (1GB+ recommended)

## Support

- **Documentation**: You're reading it!
- **Issues**: [GitHub Issues](https://github.com/cboxdk/php-baseimages/issues)
- **Discussions**: [GitHub Discussions](https://github.com/cboxdk/php-baseimages/discussions)
