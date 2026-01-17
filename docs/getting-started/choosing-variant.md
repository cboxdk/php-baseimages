---
title: "Choosing a Variant"
description: "Slim vs Standard vs Full - which image tier to use for your PHP application"
weight: 4
---

# Choosing a Variant

Cbox offers three image tiers and rootless variants. This guide helps you choose the right combination.

## Quick Decision Guide

```
What do you need?
│
├─ PDF generation, browser testing (Browsershot/Dusk)?
│  └─ Full Tier (~700MB)
│
├─ Image processing (ImageMagick, vips), Node.js?
│  └─ Standard Tier (~250MB) ✅ DEFAULT
│
└─ Minimal footprint, APIs, microservices?
   └─ Slim Tier (~120MB)
```

## Quick Decision Matrix

| Use Case | Recommended Tag |
|----------|-----------------|
| Most Laravel/PHP apps | `8.4-bookworm` (Standard) |
| REST/GraphQL APIs | `8.4-bookworm-slim` |
| Browsershot/PDF | `8.4-bookworm-full` |
| Laravel Dusk tests | `8.4-bookworm-full` |
| Kubernetes (security) | `8.4-bookworm-rootless` |

## Image Tiers

### Standard Tier (Default)

```bash
ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm
```

**Size**: ~250MB

**Includes**:
- All Slim tier extensions
- ImageMagick (complex image operations)
- vips (high-performance image processing)
- Node.js 22 + npm
- GD with AVIF support
- exiftool, ghostscript, librsvg

**Best for**:
- Most Laravel applications
- Symfony applications
- WordPress sites
- Applications with image processing
- Apps using npm/Node.js build tools

**Example**:
```yaml
services:
  app:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm
    environment:
      LARAVEL_SCHEDULER: "true"
```

### Slim Tier

```bash
ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-slim
```

**Size**: ~120MB (smallest)

**Includes**:
- 25+ core PHP extensions
- opcache, pdo_mysql, pdo_pgsql, redis, mongodb
- grpc, intl, bcmath, gd (WebP), zip
- Composer 2, Cbox Init

**Best for**:
- REST APIs
- GraphQL APIs
- Microservices
- Maximum security (minimal attack surface)
- CI/CD pipelines (fast builds)

**Example**:
```yaml
services:
  api:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-slim
    environment:
      PHP_MEMORY_LIMIT: "256M"
```

### Full Tier

```bash
ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-full
```

**Size**: ~700MB

**Includes**:
- Everything in Standard tier
- Chromium (headless browser)
- Puppeteer environment pre-configured
- NSS, HarfBuzz, fonts

**Environment variables (auto-set)**:
```
PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
```

**Best for**:
- Browsershot (PDF generation)
- Laravel Dusk (browser testing)
- Puppeteer/Playwright
- Screenshot services
- Web scraping

**Example**:
```yaml
services:
  app:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-full
    environment:
      PHP_MEMORY_LIMIT: "1G"  # Chromium needs more memory
```

## Rootless Variants

All tiers support rootless execution (runs as `www-data` user):

| Tag | Tier | Description |
|-----|------|-------------|
| `8.4-bookworm-rootless` | Standard | Default + rootless |
| `8.4-bookworm-slim-rootless` | Slim | Slim + rootless |
| `8.4-bookworm-full-rootless` | Full | Full + rootless |

**When to use rootless**:
- Kubernetes with security policies
- OpenShift
- Security-sensitive environments
- Compliance requirements (CIS benchmarks)

**Example**:
```yaml
# Kubernetes deployment
spec:
  containers:
    - image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-rootless
      securityContext:
        runAsNonRoot: true
```

## Size Comparison

| Tier | Debian 12 (Bookworm) |
|------|----------------------|
| Slim | ~120MB |
| Standard | ~250MB |
| Full | ~700MB |

## Extension Comparison

| Extension | Slim | Standard | Full |
|-----------|------|----------|------|
| opcache | ✅ | ✅ | ✅ |
| pdo_mysql, pdo_pgsql | ✅ | ✅ | ✅ |
| redis, mongodb | ✅ | ✅ | ✅ |
| grpc | ✅ | ✅ | ✅ |
| gd (WebP) | ✅ | ✅ | ✅ |
| gd (AVIF) | ❌ | ✅ | ✅ |
| imagick | ❌ | ✅ | ✅ |
| vips | ❌ | ✅ | ✅ |
| **Node.js 22** | ❌ | ✅ | ✅ |
| **Chromium** | ❌ | ❌ | ✅ |

## Decision Flowchart

```
Start
  │
  v
Need Browsershot, Dusk, or PDF generation?
  │
  ├── Yes → Full Tier (`-full`)
  │
  └── No → Continue
        │
        v
    Need ImageMagick, vips, or Node.js?
        │
        ├── Yes → Standard Tier (default, no suffix)
        │
        └── No → Slim Tier (`-slim`)
              │
              v
          Need rootless for Kubernetes/security?
              │
              ├── Yes → Add `-rootless` suffix
              │
              └── No → Done
```

## Common Scenarios

### Scenario 1: New Laravel Project

```yaml
# Development (standard tier is fine)
services:
  app:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm

# Production (same, standard handles most needs)
services:
  app:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm
```

### Scenario 2: Laravel with Browsershot

```yaml
# Full tier required for Chromium
services:
  app:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-full
    environment:
      PHP_MEMORY_LIMIT: "1G"
```

### Scenario 3: REST API Microservice

```yaml
# Slim tier for minimal footprint
services:
  api:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-slim
```

### Scenario 4: Kubernetes Production

```yaml
# Rootless for security compliance
spec:
  containers:
    - image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-rootless
      securityContext:
        runAsNonRoot: true
        readOnlyRootFilesystem: true
```

### Scenario 5: Laravel Dusk Testing

```yaml
# Full tier for Chromium
services:
  dusk:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-full
    environment:
      DUSK_DRIVER_URL: ""  # Use local Chromium
```

## Migration Between Tiers

### Upgrading to a Larger Tier

```yaml
# From Slim to Standard
- image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-slim
+ image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm

# From Standard to Full
- image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm
+ image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-full
```

### Downgrading to a Smaller Tier

**Before downgrading, verify**:
1. Check `composer.json` for extension requirements
2. Search code for `extension_loaded()` calls
3. Test all features in staging
4. Monitor error logs for missing extensions

```yaml
# From Standard to Slim (if no ImageMagick/Node needed)
- image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm
+ image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-slim
```

## Recommendations Summary

| Situation | Recommendation |
|-----------|----------------|
| Starting new Laravel/PHP project | `8.4-bookworm` (Standard) |
| Building REST/GraphQL API | `8.4-bookworm-slim` |
| Need PDF generation | `8.4-bookworm-full` |
| Running Laravel Dusk | `8.4-bookworm-full` |
| Kubernetes production | `8.4-bookworm-rootless` |
| Maximum security | `8.4-bookworm-slim-rootless` |
| CI/CD pipelines | `8.4-bookworm-slim` (fast) |

## Next Steps

- **[5-Minute Quickstart](quickstart.md)** - Get running immediately
- **[Laravel Guide](../guides/laravel-guide.md)** - Complete Laravel setup
- **[Image Tiers Comparison](../reference/editions-comparison.md)** - Detailed tier comparison
