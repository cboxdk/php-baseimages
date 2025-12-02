---
title: "Image Tagging Strategy"
description: "Comprehensive guide to PHPeek image tagging, versioning, and deprecation policies"
weight: 40
---

# Image Tagging Strategy

PHPeek Base Images follow a clear, predictable tagging strategy with OS version support for current + 1 version back.

## Tag Format

```
{image-type}:{php-version}-{os-variant}[-{edition}]
```

## Supported OS Versions

### Alpine Linux
- **Current**: Alpine 3.20+ (auto-updated with upstream)
- **Support**: Latest stable only
- **Tag format**: `8.3-alpine`, `8.3-alpine-minimal`

### Debian
- **Current**: Bookworm (Debian 12) - PHP 8.2, 8.3, 8.4
- **Previous**: Bullseye (Debian 11) - PHP 8.2, 8.3 only
- **Tag format**: `8.3-bookworm`, `8.3-bookworm-minimal`

## Edition Suffixes

- **Full Edition** (default): No suffix - `8.3-alpine`
- **Minimal Edition**: `-minimal` suffix - `8.3-alpine-minimal`

## Complete Tag Examples

### PHP-FPM Images

**Alpine (Full Edition)**:
```
ghcr.io/phpeek/baseimages/php-fpm:8.3-alpine
ghcr.io/phpeek/baseimages/php-fpm:8.4-alpine
```

**Alpine (Minimal Edition)**:
```
ghcr.io/phpeek/baseimages/php-fpm:8.3-alpine-minimal
ghcr.io/phpeek/baseimages/php-fpm:8.4-alpine-minimal
```

**Debian Bookworm (Full Edition)**:
```
ghcr.io/phpeek/baseimages/php-fpm:8.2-bookworm
ghcr.io/phpeek/baseimages/php-fpm:8.3-bookworm
ghcr.io/phpeek/baseimages/php-fpm:8.4-bookworm
```

**Debian Bookworm (Minimal Edition)**:
```
ghcr.io/phpeek/baseimages/php-fpm:8.3-bookworm-minimal
ghcr.io/phpeek/baseimages/php-fpm:8.4-bookworm-minimal
```

**Debian Bullseye (Full Edition - Legacy Support)**:
```
ghcr.io/phpeek/baseimages/php-fpm:8.2-bullseye
ghcr.io/phpeek/baseimages/php-fpm:8.3-bullseye
```

### PHP-FPM-Nginx Images

**Alpine**:
```
ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine
ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine-minimal
```

**Debian Bookworm**:
```
ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-bookworm
ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-bookworm-minimal
```

## Version Matrix

| PHP Version | Alpine | Debian Bookworm | Debian Bullseye |
|-------------|--------|-----------------|-----------------|
| 8.2         | ✅     | ✅              | ✅              |
| 8.3         | ✅     | ✅              | ✅              |
| 8.4         | ✅     | ✅              | ❌              |

**Note**: PHP 8.4 Bullseye variant not available (newer PHP requires newer OS)

## Alias Tags

**Latest stable**:
- `latest` → `8.3-alpine`
- `8.3` → `8.3-alpine`

**Minimal latest**:
- `minimal` → `8.3-alpine-minimal`
- `8.3-minimal` → `8.3-alpine-minimal`

**OS-specific latest**:
- `debian` → `8.3-bookworm`

## Deprecation Policy

PHPeek follows a predictable deprecation schedule based on upstream EOL dates.

### Timeline

| Component | Removal After EOL | Warning Period |
|-----------|-------------------|----------------|
| PHP       | 6 months          | 90 days        |
| Debian    | 3 months          | 90 days        |
| Alpine    | 3 months          | 90 days        |
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

### Production (Full Edition, Latest Stable)
```yaml
services:
  app:
    image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine
```

### Production (Minimal Edition, Laravel)
```yaml
services:
  app:
    image: ghcr.io/phpeek/baseimages/php-fpm:8.3-bookworm-minimal
```

### Legacy Application (Older OS)
```yaml
services:
  app:
    image: ghcr.io/phpeek/baseimages/php-fpm:8.2-bullseye
```

## See Also

- [Available Images](available-images.md) - Complete list of all images
- [Choosing a Variant](../getting-started/choosing-variant.md) - Which OS to choose
- [Minimal vs Full Editions](editions-comparison.md) - Edition feature comparison
