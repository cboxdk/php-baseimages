---
title: "Choosing an Image"
description: "Decision matrix to help you select the right PHPeek image for your use case"
weight: 2
---

# Choosing an Image

Quick reference to select the right PHPeek image for your needs.

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

## OS Variant Selection

| Variant | Size | Use When |
|---------|------|----------|
| **Alpine** | ~50MB | Default choice, production, most cases |
| **Debian** | ~120MB | Need glibc, specific libraries, debugging |

### Detailed Comparison

| Feature | Alpine | Debian |
|---------|--------|--------|
| Base size | ~5MB | ~120MB |
| C library | musl | glibc |
| Package manager | apk | apt |
| Security updates | Fast | Fast |
| Binary compatibility | Limited | Excellent |
| Debug tools | Minimal | Full |
| Cron daemon | dcron | cron |

### When to Choose Each

**Alpine** (recommended default):
- ✅ Smallest image size
- ✅ Fastest builds and pulls
- ✅ Minimal attack surface
- ✅ Most PHP applications work perfectly
- ⚠️ Some native extensions may need recompilation
- ⚠️ Limited binary compatibility (musl vs glibc)

**Debian**:
- ✅ Maximum binary compatibility
- ✅ Pre-compiled PHP extensions available
- ✅ Familiar apt package management
- ✅ Better for debugging with full tools
- ⚠️ Larger image size

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
| Laravel/Symfony web app | `php-fpm-nginx:8.3-alpine` |
| WordPress | `php-fpm-nginx:8.3-alpine` |
| REST API | `php-fpm-nginx:8.3-alpine` |
| Queue worker | `php-cli:8.3-alpine` |
| Cron scheduler | `php-cli:8.3-alpine` |
| Artisan commands | `php-cli:8.3-alpine` |
| Kubernetes | `php-fpm:8.3-alpine` + `nginx:alpine` |
| Laravel Octane | `php-fpm-nginx:8.3-alpine` |
| Laravel Horizon | `php-cli:8.3-alpine` |

### By Environment

| Environment | Version | Variant |
|-------------|---------|---------|
| Development | Latest (8.4) | alpine or debian |
| Staging | Same as prod | Same as prod |
| Production | Stable (8.3) | alpine |
| CI/CD | Same as prod | Same as prod |

### By Team Experience

| Team Profile | Recommendation |
|--------------|----------------|
| DevOps experienced | Alpine (smallest, fastest) |
| Traditional PHP dev | Debian (familiar apt) |
| Mixed/new team | Debian (best docs, most compatible) |

## Complete Image Reference

```
ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine
ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-debian
ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.3-alpine
ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.3-debian
ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.2-alpine
ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.2-debian

ghcr.io/gophpeek/baseimages/php-fpm:8.3-alpine
ghcr.io/gophpeek/baseimages/php-fpm:8.3-debian

ghcr.io/gophpeek/baseimages/php-cli:8.3-alpine
ghcr.io/gophpeek/baseimages/php-cli:8.3-debian

ghcr.io/gophpeek/baseimages/nginx:alpine
ghcr.io/gophpeek/baseimages/nginx:debian
```

## Migration Guide

### From Official PHP Images

```yaml
# Before (official)
image: php:8.3-fpm-alpine

# After (PHPeek)
image: phpeek/php-fpm-nginx:8.3-alpine
```

### From ServersideUp

```yaml
# Before (ServersideUp)
image: serversideup/php:8.3-fpm-nginx-alpine

# After (PHPeek) - nearly identical API
image: phpeek/php-fpm-nginx:8.3-alpine
```

### From Custom Dockerfiles

If you're building custom PHP images, you can likely:
1. Use PHPeek as base
2. Add only your custom extensions
3. Benefit from weekly security updates

```dockerfile
FROM phpeek/php-fpm-nginx:8.3-alpine

# Add custom extension
RUN apk add --no-cache php83-custom-extension

# Add custom config
COPY custom.ini /usr/local/etc/php/conf.d/
```

## FAQ

**Q: Which image for Laravel?**
A: `php-fpm-nginx:8.3-alpine` for web, `php-cli:8.3-alpine` for workers

**Q: Alpine or Debian for production?**
A: Alpine unless you have specific glibc requirements

**Q: Should I use latest PHP version?**
A: Use 8.3 for production stability, 8.4 for new projects

**Q: Multi-service vs single container?**
A: Single (`php-fpm-nginx`) for simplicity, multi for Kubernetes/scaling
