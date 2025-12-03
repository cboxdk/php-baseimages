---
title: "Introduction"
description: "Why PHPeek? Features, comparisons with ServerSideUp, Bitnami, and official PHP images"
weight: 1
---

# Introduction to PHPeek Base Images

PHPeek Base Images are production-ready PHP Docker containers designed for modern PHP applications. Built with a "batteries included" philosophy while maintaining clean, minimal images.

## Why PHPeek?

### The Problem

Setting up PHP containers for production is surprisingly complex:

1. **Official PHP images are minimal** - You need to install 20+ extensions yourself
2. **Existing solutions are bloated** - 500MB+ images with unnecessary tools
3. **Process management is fragile** - S6 Overlay adds complexity
4. **Configuration is scattered** - Different approaches for each service
5. **Security updates are manual** - You're responsible for rebuilding

### The PHPeek Solution

PHPeek provides production-ready containers with:

- **40+ PHP extensions pre-installed** - Everything Laravel, Symfony, WordPress need
- **Minimal images** - Alpine variant as small as 50MB
- **Vanilla bash entrypoint** - Simple, debuggable process management (no S6 Overlay)
- **50+ environment variables** - Runtime configuration without rebuilding
- **Weekly security rebuilds** - Automatic CVE patching
- **Framework auto-detection** - Laravel, Symfony, WordPress optimizations

> **PHPeek PM**: A Go-based process manager for advanced multi-process orchestration. See [PHPeek PM Integration](../phpeek-pm-integration) for details.

## PHPeek vs Alternatives

### vs ServerSideUp/docker-php

| Feature | PHPeek | ServerSideUp |
|---------|--------|--------------|
| Process Manager | Vanilla bash (simple) | S6 Overlay (complex) |
| Framework Support | Laravel/Symfony/WordPress | Laravel only |
| Runtime Config | 50+ variables | ~30 variables |
| PHP Versions | 8.2, 8.3, 8.4 | 8.1, 8.2, 8.3 |
| Minimal Edition | Yes (50MB) | No |
| Security Rebuilds | Weekly automated | Manual |

**When to choose PHPeek**: You need Symfony/WordPress support, latest PHP, or prefer simple debuggable entrypoints.

**When to choose ServerSideUp**: You need established community support or S6 Overlay features.

### vs Official PHP Images

| Feature | PHPeek | Official PHP |
|---------|--------|--------------|
| Extensions | 40+ included | ~10 basic |
| Production Ready | Yes | No (minimal) |
| Nginx Integration | Built-in | Separate setup |
| Framework Support | Auto-detection | None |
| Image Size | 50-130MB | 120MB+ (with extensions) |

**When to choose PHPeek**: Production applications, rapid development, team standardization.

**When to choose Official**: Maximum control, learning Docker, custom requirements.

### vs Bitnami

| Feature | PHPeek | Bitnami |
|---------|--------|---------|
| Image Size | 50-130MB | 400-600MB |
| Customization | Easy | Complex |
| Configuration | Environment vars | Config files |
| Updates | Weekly | Bitnami schedule |

**When to choose PHPeek**: Smaller images, simpler customization.

**When to choose Bitnami**: VMware ecosystem, Helm charts.

## Core Innovations

### Vanilla Bash Entrypoint

PHPeek uses a simple, debuggable bash entrypoint instead of complex init systems:

```bash
# What happens at container start:
1. Detect framework (Laravel/Symfony/WordPress)
2. Fix directory permissions automatically
3. Start PHP-FPM (daemonized)
4. Start Nginx (foreground, keeps container alive)
5. Handle graceful shutdown on SIGTERM
```

**Benefits**:
- Easy to debug (`docker exec` into container, read `/usr/local/bin/docker-entrypoint.sh`)
- No S6 Overlay complexity or learning curve
- Works with any debugging/profiling tools
- Custom scripts via `/docker-entrypoint-init.d/`

> **PHPeek PM**: Go-based process manager available for advanced orchestration. Enable with `PHPEEK_PROCESS_MANAGER=phpeek-pm`.

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
    image: ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine
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
php-fpm/           # PHP-FPM only (for microservices)
php-cli/           # CLI scripts, queue workers
nginx/             # Nginx only (reverse proxy)
php-fpm-nginx/     # All-in-one (recommended for most)
```

### OS Variants

| Variant | Size | Use Case |
|---------|------|----------|
| Alpine | ~50MB | Production, smallest footprint |
| Debian | ~120MB | glibc compatibility, native extensions |

### Editions

| Edition | Includes | Use Case |
|---------|----------|----------|
| Standard | 40+ extensions | Production |
| Dev | + Xdebug, SPX | Development |
| Minimal | Core extensions only | Microservices |

## Getting Started

Ready to try PHPeek?

1. **[5-Minute Quickstart](quickstart)** - Get running immediately
2. **[Laravel Guide](../guides/laravel-guide)** - Complete Laravel setup
3. **[Choosing a Variant](choosing-variant)** - Alpine vs Debian

## Requirements

- Docker 20.10+ (BuildKit recommended)
- Docker Compose 2.0+ (optional)
- 512MB RAM minimum (1GB+ recommended)

## Support

- **Documentation**: You're reading it!
- **Issues**: [GitHub Issues](https://github.com/gophpeek/baseimages/issues)
- **Discussions**: [GitHub Discussions](https://github.com/gophpeek/baseimages/discussions)
