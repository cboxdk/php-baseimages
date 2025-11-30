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

### Ubuntu
- **Current**: Ubuntu 24.04 (Noble Numbat) - PHP 8.2, 8.3, 8.4
- **Previous**: Ubuntu 22.04 (Jammy Jellyfish) - PHP 8.2, 8.3 only
- **Tag format**: `8.3-ubuntu-24.04`, `8.3-ubuntu-24.04-minimal`

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

**Ubuntu 24.04 (Full Edition)**:
```
ghcr.io/phpeek/baseimages/php-fpm:8.3-ubuntu-24.04
ghcr.io/phpeek/baseimages/php-fpm:8.4-ubuntu-24.04
```

**Ubuntu 24.04 (Minimal Edition)**:
```
ghcr.io/phpeek/baseimages/php-fpm:8.3-ubuntu-24.04-minimal
ghcr.io/phpeek/baseimages/php-fpm:8.4-ubuntu-24.04-minimal
```

**Ubuntu 22.04 (Legacy Support)**:
```
ghcr.io/phpeek/baseimages/php-fpm:8.2-ubuntu-22.04
ghcr.io/phpeek/baseimages/php-fpm:8.3-ubuntu-22.04
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

**Ubuntu 24.04**:
```
ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-ubuntu-24.04
ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-ubuntu-24.04-minimal
```

## Version Matrix

| PHP Version | Alpine | Debian Bookworm | Debian Bullseye | Ubuntu 24.04 | Ubuntu 22.04 |
|-------------|--------|-----------------|-----------------|--------------|--------------|
| 8.2         | ✅     | ✅              | ✅              | ✅           | ✅           |
| 8.3         | ✅     | ✅              | ✅              | ✅           | ✅           |
| 8.4         | ✅     | ✅              | ❌              | ✅           | ❌           |

**Note**: PHP 8.4 Bullseye and Ubuntu 22.04 variants not available (newer PHP requires newer OS)

## Alias Tags

**Latest stable**:
- `latest` → `8.3-alpine`
- `8.3` → `8.3-alpine`

**Minimal latest**:
- `minimal` → `8.3-alpine-minimal`
- `8.3-minimal` → `8.3-alpine-minimal`

**OS-specific latest**:
- `debian` → `8.3-bookworm`
- `ubuntu` → `8.3-ubuntu-24.04`

## Deprecation Policy

1. **Current + 1**: Support current OS version + 1 previous version
2. **PHP EOL**: Remove PHP versions 6 months after PHP project EOL
3. **OS EOL**: Remove OS versions 3 months after OS vendor EOL
4. **Migration Path**: Always provide clear upgrade path in docs

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

### Ubuntu Preference (Full Edition)
```yaml
services:
  app:
    image: ghcr.io/phpeek/baseimages/php-fpm:8.3-ubuntu-24.04
```

## See Also

- [Available Images](available-images.md) - Complete list of all images
- [Choosing a Variant](../getting-started/choosing-variant.md) - Which OS to choose
- [Minimal vs Full Editions](editions-comparison.md) - Edition feature comparison
