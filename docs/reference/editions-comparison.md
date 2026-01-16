---
title: "Image Tiers: Slim / Standard / Full"
description: "Complete comparison of Slim, Standard, and Full image tiers with extensions, sizes, and use cases"
weight: 30
---

# Image Tiers Comparison

Cbox Base Images come in three tiers optimized for different use cases.

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

## Tier Overview

| Tier | Size | Best For | Tag Suffix |
|------|------|----------|------------|
| **Slim** | ~120MB | APIs, microservices, minimal footprint | `-slim` |
| **Standard** | ~250MB | Most Laravel/PHP apps (DEFAULT) | (none) |
| **Full** | ~700MB | Browsershot, Dusk, PDF generation | `-full` |

## Tag Format

```
{image-type}:{php-version}-{os}[-tier][-rootless]

Examples:
php-fpm-nginx:8.4-bookworm              # Standard (default)
php-fpm-nginx:8.4-bookworm-slim         # Slim
php-fpm-nginx:8.4-bookworm-full         # Full
php-fpm-nginx:8.4-bookworm-rootless     # Standard + rootless
php-fpm-nginx:8.4-bookworm-slim-rootless  # Slim + rootless
php-fpm-nginx:8.4-bookworm-full-rootless  # Full + rootless
```

## Extensions by Tier

### Slim Tier (All Core Extensions)

**PHP Extensions:**
| Extension | Purpose |
|-----------|---------|
| `opcache` | Bytecode caching |
| `pdo_mysql`, `mysqli` | MySQL/MariaDB |
| `pdo_pgsql`, `pgsql` | PostgreSQL |
| `redis` | Redis cache/sessions |
| `apcu` | In-memory cache |
| `mongodb` | MongoDB NoSQL |
| `igbinary` | Fast serialization |
| `msgpack` | MessagePack serialization |
| `grpc` | gRPC protocol support |
| `zip` | ZIP archives |
| `intl` | Internationalization |
| `bcmath` | Precision math |
| `gd` | Images (WebP, JPEG, PNG) |
| `exif` | Image metadata |
| `pcntl` | Process control |
| `sockets` | Low-level networking |
| `soap` | SOAP web services |
| `xsl` | XSLT transformations |
| `ldap` | LDAP/Active Directory |
| `bz2` | bzip2 compression |
| `calendar` | Date calculations |
| `gettext` | GNU translations |
| `shmop`, `sysvmsg`, `sysvsem`, `sysvshm` | IPC |
| `gmp` | Arbitrary precision math |

**Tools:**
- Composer 2
- Cbox PM (process manager)
- curl, wget, git, unzip

### Standard Tier (Slim + Image Processing + Node.js)

Everything in Slim, plus:

| Component | Description |
|-----------|-------------|
| `imagick` | ImageMagick for complex image operations, PDF support |
| `vips` | libvips for high-performance image processing (4-10x faster) |
| `gd` (AVIF) | AVIF image format support |
| **Node.js 22** | JavaScript runtime |
| **npm** | Node package manager |
| `exiftool` | Advanced image metadata |
| `ghostscript` | PDF/PostScript support |
| `librsvg` | SVG rendering |
| `icu-data-full` | Complete ICU locale data |

### Full Tier (Standard + Browser Automation)

Everything in Standard, plus:

| Component | Description |
|-----------|-------------|
| **Chromium** | Headless browser |
| `nss` | Network Security Services |
| `harfbuzz` | Text shaping |
| `ttf-freefont` | Free fonts |

**Environment Variables (auto-set):**
```
PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
```

## Size Comparison

| Tier | Size | Use Case |
|------|------|----------|
| **Slim** | ~120MB | APIs, microservices |
| **Standard** | ~250MB | Most apps |
| **Full** | ~700MB | Browser automation |

## Performance Characteristics

### Startup Time

| Tier | Cold Start | Reason |
|------|------------|--------|
| Slim | ~800ms | Fewer extensions |
| Standard | ~1000ms | ImageMagick, Node.js |
| Full | ~1200ms | Chromium loaded |

### Memory Footprint

| Tier | Base RAM | Per PHP Worker |
|------|----------|----------------|
| Slim | ~15MB | ~30MB |
| Standard | ~25MB | ~45MB |
| Full | ~35MB | ~55MB |

## Use Case Matrix

| Scenario | Recommended | Why |
|----------|-------------|-----|
| REST API | Slim | Minimal footprint |
| GraphQL API | Slim | Core extensions sufficient |
| Laravel app | Standard | ImageMagick, Node for assets |
| Symfony app | Standard | Balanced feature set |
| WordPress | Standard | Image processing needed |
| PDF generation | Full | Requires Chromium |
| Browsershot | Full | Requires Chromium |
| Laravel Dusk | Full | Requires Chromium |
| Puppeteer | Full | Requires Chromium |
| Microservice | Slim | Smallest footprint |

## Migration Between Tiers

### Upgrading to a Larger Tier

```yaml
# From Slim to Standard
- image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm-slim
+ image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm

# From Standard to Full
- image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm
+ image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm-full
```

### Downgrading to a Smaller Tier

**Validation checklist:**
1. Check `composer.json` for extension requirements
2. Search code for `extension_loaded()` calls
3. Test all features in staging
4. Monitor error logs for missing extensions

```yaml
# From Standard to Slim (if no ImageMagick/Node needed)
- image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm
+ image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm-slim
```

## Rootless Variants

All tiers support rootless execution (runs as `www-data` user):

| Tag | Description |
|-----|-------------|
| `8.4-bookworm-rootless` | Standard + rootless |
| `8.4-bookworm-slim-rootless` | Slim + rootless |
| `8.4-bookworm-full-rootless` | Full + rootless |

**When to use rootless:**
- Kubernetes with security policies
- OpenShift
- Security-sensitive environments
- Compliance requirements (CIS benchmarks)

## Configuration

All tiers share the same configuration options:

```yaml
environment:
  # PHP Settings
  PHP_MEMORY_LIMIT: "512M"
  PHP_MAX_EXECUTION_TIME: "60"

  # OPcache (enabled by default)
  PHP_OPCACHE_ENABLE: "1"
  PHP_OPCACHE_JIT: "tracing"
```

## Examples

### Slim Tier (API)

```yaml
services:
  api:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm-slim
    ports:
      - "8000:80"
    environment:
      PHP_MEMORY_LIMIT: "256M"
```

### Standard Tier (Laravel)

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm
    ports:
      - "8000:80"
    environment:
      LARAVEL_SCHEDULER: "true"
```

### Full Tier (Browsershot)

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm-full
    ports:
      - "8000:80"
    environment:
      # Chromium is pre-configured
      PHP_MEMORY_LIMIT: "1G"
```

## See Also

- [Available Images](available-images.md) - Complete tag matrix
- [Tagging Strategy](tagging-strategy.md) - Tag format details
- [Rootless Containers](../advanced/rootless-containers.md) - Security guide
