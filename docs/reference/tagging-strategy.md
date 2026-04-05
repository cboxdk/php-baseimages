---
title: "Image Tagging Strategy"
description: "Comprehensive guide to Cbox image tagging, versioning, and deprecation policies"
weight: 40
---

# Image Tagging Strategy

Cbox PHP Base Images follow a clear, predictable tagging strategy with four image tiers and rootless variants.

## Tag Format

```
{image-type}:{php-version}-{os}[-tier][-rootless]
```

## Image Tiers

| Tier | Tag Suffix | Size | Use Case |
|------|------------|------|----------|
| **Slim** | `-slim` | ~120 MiB | APIs, microservices, minimal footprint |
| **Standard** | (none) | ~250 MiB | Most Laravel/PHP apps (DEFAULT) |
| **Chromium** | `-chromium` | ~700 MiB | Browsershot, Dusk, PDF generation |
| **Dev** | `-dev` | ~750 MiB | Chromium + Xdebug, PCOV, SPX |

## Complete Tag Examples

### Standard Tier (Default)

Most applications should use standard tier:

```
ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.5-bookworm
ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm
ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.3-bookworm
ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.2-bookworm
```

### Slim Tier

For APIs and microservices with minimal footprint:

```
ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.5-bookworm-slim
ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-slim
ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.3-bookworm-slim
ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.2-bookworm-slim
```

### Chromium Tier

For Browsershot, Dusk, Puppeteer, and PDF generation:

```
ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.5-bookworm-chromium
ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-chromium
ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.3-bookworm-chromium
ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.2-bookworm-chromium
```

### Rootless Variants

All tiers support rootless execution (runs as `www-data` user):

```
# Standard + rootless
ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-rootless

# Slim + rootless
ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-slim-rootless

# Chromium + rootless
ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-chromium-rootless
```

## Version Matrix

| PHP Version | Debian 12 (Slim) | Debian 12 (Standard) | Debian 12 (Chromium) | Debian 12 (Dev) |
|-------------|------------------|----------------------|----------------------|-----------------|
| 8.5         | ✅               | ✅                   | ✅                   | ✅              |
| 8.4         | ✅               | ✅                   | ✅                   | ✅              |
| 8.3         | ✅               | ✅                   | ✅                   | ✅              |
| 8.2         | ✅               | ✅                   | ✅                   | ✅              |

All variants also available with `-rootless` suffix.

## Alias Tags

**Latest stable**:
- `latest` → `8.5-bookworm`
- `8.5` → `8.5-bookworm`

**Tier aliases**:
- `slim` → `8.5-bookworm-slim`
- `chromium` → `8.5-bookworm-chromium`

## Deprecation Policy

Cbox follows a predictable deprecation schedule based on upstream EOL dates.

### Timeline

| Component | Removal After EOL | Warning Period |
|-----------|-------------------|----------------|
| PHP       | 6 months          | 90 days        |
| Debian    | 3 months          | 90 days        |
| Node.js   | 6 months          | 90 days        |

### Current EOL Dates

Check `versions.json` for current EOL dates, or run:

```bash
./scripts/check-eol.sh
```

### Deprecation Process

1. **Warning Phase** (90 days before removal):
   - Deprecation notice added to image labels
   - Warning in CI workflow output
   - Documentation updated with migration guide

2. **EOL Phase** (upstream EOL reached):
   - Images still built but marked deprecated
   - No new features, security patches only
   - Migration reminder in container startup

3. **Removal Phase** (after grace period):
   - Images removed from registry
   - Dockerfiles archived to `archive/` branch
   - Final migration guide published

### Checking Deprecation Status

```bash
# Check all EOL dates
./scripts/check-eol.sh

# Only show warnings
./scripts/check-eol.sh --warnings

# JSON output for CI
./scripts/check-eol.sh --json
```

### Migration Guides

When a version is deprecated, migration guides are published at:
- `docs/troubleshooting/migration-guide.md`
- GitHub release notes

## Examples by Use Case

### Production (Standard Tier, Recommended)
```yaml
services:
  app:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm
```

### API/Microservice (Slim Tier)
```yaml
services:
  api:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-slim
```

### PDF Generation (Chromium Tier)
```yaml
services:
  pdf:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-chromium
```

### Kubernetes (Rootless)
```yaml
services:
  app:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-rootless
```

## See Also

- [Available Images](available-images.md) - Complete list of all images
- [Choosing Your Image](../getting-started/choosing-your-image) - Tiers, sizes, and when to use each
