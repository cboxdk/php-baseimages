---
title: "Available Images"
description: "Complete matrix of all PHPeek base image tags, variants, and architectures"
weight: 40
---

# Available Images

Complete reference of all available PHPeek base image tags and variants.

## Image Registry

All images are published to GitHub Container Registry:

```
ghcr.io/phpeek/baseimages/{image-type}:{tag}
```

## Multi-Service Images (PHP-FPM + Nginx)

Single container with both PHP-FPM and Nginx - perfect for simple deployments.

### Production Images

| Image Tag | PHP | OS | Size | Architecture |
|-----------|-----|----|----- |--------------|
| `php-fpm-nginx:8.4-alpine` | 8.4 | Alpine | ~70MB | amd64, arm64 |
| `php-fpm-nginx:8.3-alpine` | 8.3 | Alpine | ~70MB | amd64, arm64 |
| `php-fpm-nginx:8.2-alpine` | 8.2 | Alpine | ~70MB | amd64, arm64 |
| `php-fpm-nginx:8.4-debian` | 8.4 | Debian Bookworm | ~150MB | amd64, arm64 |
| `php-fpm-nginx:8.3-debian` | 8.3 | Debian Bookworm | ~150MB | amd64, arm64 |
| `php-fpm-nginx:8.2-debian` | 8.2 | Debian Bookworm | ~150MB | amd64, arm64 |

### Development Images (with Xdebug)

| Image Tag | PHP | OS | Includes |
|-----------|-----|----|----- |
| `php-fpm-nginx:8.4-alpine-dev` | 8.4 | Alpine | Xdebug 3.4, dev settings |
| `php-fpm-nginx:8.3-alpine-dev` | 8.3 | Alpine | Xdebug 3.3, dev settings |
| `php-fpm-nginx:8.2-alpine-dev` | 8.2 | Alpine | Xdebug 3.3, dev settings |
| `php-fpm-nginx:8.4-debian-dev` | 8.4 | Debian | Xdebug 3.4, dev settings |
| `php-fpm-nginx:8.3-debian-dev` | 8.3 | Debian | Xdebug 3.3, dev settings |
| `php-fpm-nginx:8.2-debian-dev` | 8.2 | Debian | Xdebug 3.3, dev settings |

## Single-Process Images

### PHP-FPM (Full Edition)

| Image Tag | PHP | OS | Size |
|-----------|-----|----|----- |
| `php-fpm:8.4-alpine` | 8.4 | Alpine | ~50MB |
| `php-fpm:8.3-alpine` | 8.3 | Alpine | ~50MB |
| `php-fpm:8.2-alpine` | 8.2 | Alpine | ~50MB |
| `php-fpm:8.4-debian` | 8.4 | Debian | ~120MB |
| `php-fpm:8.3-debian` | 8.3 | Debian | ~120MB |
| `php-fpm:8.2-debian` | 8.2 | Debian | ~120MB |

### PHP-FPM (Minimal Edition)

Optimized for Laravel with ~30% smaller size:

| Image Tag | PHP | OS | Size |
|-----------|-----|----|----- |
| `php-fpm:8.4-alpine-minimal` | 8.4 | Alpine | ~35MB |
| `php-fpm:8.3-alpine-minimal` | 8.3 | Alpine | ~35MB |
| `php-fpm:8.2-alpine-minimal` | 8.2 | Alpine | ~35MB |
| `php-fpm:8.4-debian-minimal` | 8.4 | Debian | ~85MB |
| `php-fpm:8.3-debian-minimal` | 8.3 | Debian | ~85MB |
| `php-fpm:8.2-debian-minimal` | 8.2 | Debian | ~85MB |

### PHP-FPM Development Images

| Image Tag | PHP | OS | Includes |
|-----------|-----|----|----- |
| `php-fpm:8.4-alpine-dev` | 8.4 | Alpine | Xdebug 3.4 |
| `php-fpm:8.3-alpine-dev` | 8.3 | Alpine | Xdebug 3.3 |
| `php-fpm:8.2-alpine-dev` | 8.2 | Alpine | Xdebug 3.3 |
| `php-fpm:8.4-debian-dev` | 8.4 | Debian | Xdebug 3.4 |
| `php-fpm:8.3-debian-dev` | 8.3 | Debian | Xdebug 3.3 |
| `php-fpm:8.2-debian-dev` | 8.2 | Debian | Xdebug 3.3 |

### PHP-CLI

| Image Tag | PHP | OS | Size |
|-----------|-----|----|----- |
| `php-cli:8.4-alpine` | 8.4 | Alpine | ~45MB |
| `php-cli:8.3-alpine` | 8.3 | Alpine | ~45MB |
| `php-cli:8.2-alpine` | 8.2 | Alpine | ~45MB |
| `php-cli:8.4-debian` | 8.4 | Debian | ~110MB |
| `php-cli:8.3-debian` | 8.3 | Debian | ~110MB |
| `php-cli:8.2-debian` | 8.2 | Debian | ~110MB |

### Nginx

| Image Tag | OS | Size |
|-----------|----|----- |
| `nginx:alpine` | Alpine | ~25MB |
| `nginx:debian` | Debian | ~60MB |

## Tag Conventions

### Rolling Tags (Recommended)

Rolling tags receive weekly security updates:

```yaml
# Automatically gets security patches every Monday
image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-alpine
```

### Immutable SHA Tags

For reproducible builds, use SHA-pinned tags:

```yaml
# Locked to specific build
image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-alpine@sha256:abc123...
```

### Tag Format

```
{type}:{php_version}-{os}[-variant]

Examples:
php-fpm-nginx:8.4-alpine         # Production, Alpine
php-fpm-nginx:8.4-alpine-dev     # Development, Alpine
php-fpm:8.4-alpine-minimal       # Minimal edition, Alpine
php-cli:8.4-debian               # CLI, Debian
```

## Architecture Support

All images are built for multiple architectures:

| Architecture | Platform | Examples |
|--------------|----------|----------|
| `amd64` | x86_64 | Intel/AMD servers, most cloud VMs |
| `arm64` | aarch64 | Apple Silicon, AWS Graviton, Raspberry Pi 4+ |

Docker automatically pulls the correct architecture:

```bash
# Works on both AMD64 and ARM64
docker pull ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-alpine
```

## OS Variant Comparison

| Feature | Alpine | Debian |
|---------|--------|--------|
| **Base Size** | ~5MB | ~125MB |
| **Package Manager** | apk | apt |
| **libc** | musl | glibc |
| **Security Updates** | Weekly | Weekly |
| **Compatibility** | Good | Excellent |
| **Best For** | Production, size | Compatibility |

### When to Choose

**Alpine** (Recommended for most):
- Smallest image size
- Fastest pull times
- Works for 99% of PHP applications

**Debian**:
- Maximum compatibility with native extensions
- Required for some enterprise software
- glibc-dependent packages

## Edition Comparison

| Feature | Full Edition | Minimal Edition |
|---------|--------------|-----------------|
| **Extensions** | 40+ | 17 essential |
| **Image Size** | Baseline | ~30% smaller |
| **OPcache** | Enabled | Disabled (explicit) |
| **MongoDB** | Included | Not included |
| **ImageMagick** | Included | Not included |
| **SOAP/LDAP/IMAP** | Included | Not included |
| **Best For** | Enterprise, legacy | Laravel, modern PHP |

## Version Support

| PHP Version | Status | Security Support Until |
|-------------|--------|------------------------|
| PHP 8.4 | Active | November 2028 |
| PHP 8.3 | Active | November 2027 |
| PHP 8.2 | Active | December 2026 |
| PHP 8.1 | Security Only | December 2025 |
| PHP 8.0 | EOL | Not supported |

**Recommendation**: Use PHP 8.4 for new projects, PHP 8.3 for production stability.

## Usage Examples

### Docker CLI

```bash
# Pull latest PHP 8.4 Alpine
docker pull ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-alpine

# Run with volume mount
docker run -p 8000:80 -v $(pwd):/var/www/html \
  ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-alpine
```

### Docker Compose

```yaml
version: '3.8'

services:
  app:
    image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-alpine
    ports:
      - "8000:80"
    volumes:
      - ./:/var/www/html
```

### Dockerfile

```dockerfile
FROM ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-alpine

COPY --chown=www-data:www-data . /var/www/html

RUN composer install --no-dev --optimize-autoloader
```

## Weekly Security Rebuilds

All images are automatically rebuilt every Monday at 03:00 UTC:

- Latest upstream PHP patches
- Latest OS security updates
- CVE scanning with Trivy
- Multi-architecture builds

**Stay secure**: Pull images regularly to get security patches.

```bash
# Pull latest security patches
docker pull ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-alpine
docker-compose up -d --pull always
```

---

**Need help choosing?** See [Choosing a Variant](../getting-started/choosing-variant) | [Editions Comparison](editions-comparison)
