---
title: "Image Tagging Strategy"
description: "Comprehensive guide to Cbox image tagging, versioning, and deprecation policies"
weight: 40
---

# Image Tagging Strategy

Cbox Base Images follow a clear, predictable tagging strategy with three image tiers and rootless variants.

## Tag Format

```
{image-type}:{php-version}-{os}[-tier][-rootless]
```

## Image Tiers

| Tier | Tag Suffix | Size | Use Case |
|------|------------|------|----------|
| **Slim** | `-slim` | ~120MB | APIs, microservices, minimal footprint |
| **Standard** | (none) | ~250MB | Most Laravel/PHP apps (DEFAULT) |
| **Full** | `-full` | ~700MB | Browsershot, Dusk, PDF generation |

## Complete Tag Examples

### Standard Tier (Default)

Most applications should use standard tier:

```
ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm
ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm
ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.2-bookworm
```

### Slim Tier

For APIs and microservices with minimal footprint:

```
ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm-slim
ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm-slim
ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.2-bookworm-slim
```

### Full Tier

For Browsershot, Dusk, Puppeteer, and PDF generation:

```
ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm-full
ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm-full
ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.2-bookworm-full
```

### Rootless Variants

All tiers support rootless execution (runs as `www-data` user):

```
# Standard + rootless
ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm-rootless

# Slim + rootless
ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm-slim-rootless

# Full + rootless
ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm-full-rootless
```

## Version Matrix

| PHP Version | Debian 12 (Slim) | Debian 12 (Standard) | Debian 12 (Full) |
|-------------|------------------|----------------------|------------------|
| 8.4         | ✅               | ✅                   | ✅               |
| 8.3         | ✅               | ✅                   | ✅               |
| 8.2         | ✅               | ✅                   | ✅               |

All variants also available with `-rootless` suffix.

## Alias Tags

**Latest stable**:
- `latest` → `8.4-bookworm`
- `8.4` → `8.4-bookworm`

**Tier aliases**:
- `slim` → `8.4-bookworm-slim`
- `full` → `8.4-bookworm-full`

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
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm
```

### API/Microservice (Slim Tier)
```yaml
services:
  api:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm-slim
```

### PDF Generation (Full Tier)
```yaml
services:
  pdf:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm-full
```

### Kubernetes (Rootless)
```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm-rootless
```

## See Also

- [Available Images](available-images.md) - Complete list of all images
- [Choosing a Variant](../getting-started/choosing-variant.md) - Which tier to choose
- [Image Tiers Comparison](editions-comparison.md) - Tier feature comparison
