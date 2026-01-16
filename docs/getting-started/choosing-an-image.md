---
title: "Choosing an Image"
description: "Decision matrix to help you select the right Cbox image for your use case"
weight: 2
---

# Choosing an Image

Quick reference to select the right Cbox image for your needs.

## Quick Decision Tree

```
What are you building?
│
├─ Web application (PHP + Nginx)
│   └─ Use: php-fpm-nginx
│
├─ CLI tool / Worker / Scheduler
│   └─ Use: php-cli
│
├─ Microservices (separate containers)
│   ├─ PHP processing → php-fpm
│   └─ Web serving → nginx
│
└─ Need maximum control?
    └─ Use single-process images
```

## Image Types

| Image | Best For | Services |
|-------|----------|----------|
| `php-fpm-nginx` | Most web apps | PHP-FPM + Nginx in one container |
| `php-fpm` | Microservices, Kubernetes | PHP-FPM only |
| `php-cli` | Workers, schedulers, commands | PHP CLI only |
| `nginx` | Static files, reverse proxy | Nginx only |

## OS Base

Cbox Base Images use **Debian 12 (Bookworm)** for maximum compatibility and stability.

| Feature | Debian 12 (Bookworm) |
|---------|----------------------|
| Base size | ~120MB |
| C library | glibc |
| Package manager | apt-get |
| Security updates | Weekly |
| Binary compatibility | Excellent |
| Debug tools | Full |
| Cron daemon | cron |

### Why Debian 12?

- ✅ Maximum binary compatibility with pre-compiled extensions
- ✅ glibc support for all PHP extensions
- ✅ Familiar apt package management
- ✅ Full debugging tools available
- ✅ Stable, long-term support base
- ✅ Weekly security updates

## PHP Version Selection

| Version | Status | Recommendation |
|---------|--------|----------------|
| **8.4** | Current | New projects, modern features |
| **8.3** | Stable | Production recommended |
| **8.2** | LTS | Conservative production |

### Feature Highlights

**PHP 8.4**:
- Property hooks
- Asymmetric visibility
- new without parentheses

**PHP 8.3**:
- Typed class constants
- json_validate()
- #[\Override] attribute

**PHP 8.2**:
- Readonly classes
- Disjunctive Normal Form types
- null/false standalone types

## Decision Matrix

### By Use Case

| Use Case | Recommended Image |
|----------|-------------------|
| Laravel/Symfony web app | `php-fpm-nginx:8.3-bookworm` |
| WordPress | `php-fpm-nginx:8.3-bookworm` |
| REST API | `php-fpm-nginx:8.3-bookworm` |
| Queue worker | `php-cli:8.3-bookworm` |
| Cron scheduler | `php-cli:8.3-bookworm` |
| Artisan commands | `php-cli:8.3-bookworm` |
| Kubernetes | `php-fpm:8.3-bookworm` + `nginx:bookworm` |
| Laravel Octane | `php-fpm-nginx:8.3-bookworm` |
| Laravel Horizon | `php-cli:8.3-bookworm` |

### By Environment

| Environment | Version | Tier |
|-------------|---------|------|
| Development | Latest (8.4) | Standard |
| Staging | Same as prod | Same as prod |
| Production | Stable (8.3) | Standard or Slim |
| CI/CD | Same as prod | Same as prod |

### By Team Experience

| Team Profile | Recommendation |
|--------------|----------------|
| All teams | Debian 12 (Bookworm) - single OS choice |
| Tier selection | Standard for most apps, Slim for APIs |
| Familiar tools | apt package management, glibc compatibility |

## Complete Image Reference

```
# Multi-service (PHP-FPM + Nginx)
ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm
ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm-slim
ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm-full
ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm
ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.2-bookworm

# Single-process images (legacy)
ghcr.io/cboxdk/baseimages/php-fpm:8.3-bookworm
ghcr.io/cboxdk/baseimages/php-cli:8.3-bookworm
ghcr.io/cboxdk/baseimages/nginx:bookworm
```

## Migration Guide

### From Official PHP Images

```yaml
# Before (official)
image: php:8.3-fpm

# After (Cbox)
image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm
```

### From ServersideUp

```yaml
# Before (ServersideUp)
image: serversideup/php:8.3-fpm-nginx

# After (Cbox) - nearly identical API
image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm
```

### From Custom Dockerfiles

If you're building custom PHP images, you can likely:
1. Use Cbox as base
2. Add only your custom extensions
3. Benefit from weekly security updates

```dockerfile
FROM ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm

# Add custom extension (Debian uses apt-get)
RUN apt-get update && apt-get install -y php8.3-custom-extension && rm -rf /var/lib/apt/lists/*

# Add custom config
COPY custom.ini /usr/local/etc/php/conf.d/
```

## FAQ

**Q: Which image for Laravel?**
A: `php-fpm-nginx:8.3-bookworm` for web, `php-cli:8.3-bookworm` for workers

**Q: Which tier for production?**
A: Standard for most apps, Slim for APIs, Full for PDF/browser automation

**Q: Should I use latest PHP version?**
A: Use 8.3 for production stability, 8.4 for new projects

**Q: Multi-service vs single container?**
A: Single (`php-fpm-nginx`) for simplicity, multi for Kubernetes/scaling
