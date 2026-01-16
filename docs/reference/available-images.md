---
title: "Available Images"
description: "Complete matrix of all Cbox base image tags, variants, and architectures"
weight: 40
---

# Available Images

Complete reference of all available Cbox base image tags and variants.

## Image Registry

All images are published to GitHub Container Registry:

```
ghcr.io/cboxdk/baseimages/{image-type}:{tag}
```

## Image Tiers

All images come in three tiers to match your needs:

| Tier | Tag Suffix | Size (Debian 12) | Best For |
|------|------------|------------------|----------|
| **Slim** | `-slim` | ~120MB | APIs, microservices |
| **Standard** | (none) | ~250MB | Most apps (DEFAULT) |
| **Full** | `-full` | ~700MB | Browsershot, Dusk, PDF |

## Multi-Service Images (PHP-FPM + Nginx)

Single container with both PHP-FPM and Nginx - perfect for simple deployments.

### Standard Tier (Default)

| Image Tag | PHP | OS | Size | Architecture |
|-----------|-----|----|----- |--------------|
| `php-fpm-nginx:8.5-bookworm` | 8.5 | Debian 12 | ~250MB | amd64, arm64 |
| `php-fpm-nginx:8.4-bookworm` | 8.4 | Debian 12 | ~250MB | amd64, arm64 |
| `php-fpm-nginx:8.3-bookworm` | 8.3 | Debian 12 | ~250MB | amd64, arm64 |
| `php-fpm-nginx:8.2-bookworm` | 8.2 | Debian 12 | ~250MB | amd64, arm64 |

### Slim Tier

Optimized for APIs and microservices with minimal footprint:

| Image Tag | PHP | OS | Size | Architecture |
|-----------|-----|----|----- |--------------|
| `php-fpm-nginx:8.5-bookworm-slim` | 8.5 | Debian 12 | ~120MB | amd64, arm64 |
| `php-fpm-nginx:8.4-bookworm-slim` | 8.4 | Debian 12 | ~120MB | amd64, arm64 |
| `php-fpm-nginx:8.3-bookworm-slim` | 8.3 | Debian 12 | ~120MB | amd64, arm64 |
| `php-fpm-nginx:8.2-bookworm-slim` | 8.2 | Debian 12 | ~120MB | amd64, arm64 |

### Full Tier

Includes Chromium for Browsershot, Dusk, and PDF generation:

| Image Tag | PHP | OS | Size | Architecture |
|-----------|-----|----|----- |--------------|
| `php-fpm-nginx:8.5-bookworm-full` | 8.5 | Debian 12 | ~700MB | amd64, arm64 |
| `php-fpm-nginx:8.4-bookworm-full` | 8.4 | Debian 12 | ~700MB | amd64, arm64 |
| `php-fpm-nginx:8.3-bookworm-full` | 8.3 | Debian 12 | ~700MB | amd64, arm64 |
| `php-fpm-nginx:8.2-bookworm-full` | 8.2 | Debian 12 | ~700MB | amd64, arm64 |

### Rootless Variants

All tiers support rootless execution (runs as `www-data` user). Available for all PHP versions:

| Image Tag | Tier | Description |
|-----------|------|-------------|
| `php-fpm-nginx:{version}-bookworm-rootless` | Standard | Default + rootless |
| `php-fpm-nginx:{version}-bookworm-slim-rootless` | Slim | Slim + rootless |
| `php-fpm-nginx:{version}-bookworm-full-rootless` | Full | Full + rootless |

Where `{version}` is `8.2`, `8.3`, `8.4`, or `8.5`.

## High-Performance Images (Laravel Octane)

Specialized images for high-performance PHP applications using Laravel Octane.

### PHP Swoole

Swoole extension for maximum performance with coroutines and task workers.

| Image Tag | PHP | Swoole | Architecture |
|-----------|-----|--------|--------------|
| `php-swoole:8.4-bookworm` | 8.4 | Latest | amd64, arm64 |
| `php-swoole:8.3-bookworm` | 8.3 | Latest | amd64, arm64 |
| `php-swoole:8.2-bookworm` | 8.2 | Latest | amd64, arm64 |

**Includes:** Swoole extension with OpenSSL, cURL, c-ares, all Cbox extensions, Composer, Node.js, Cbox Init.

```yaml
# Laravel Octane with Swoole
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-swoole:8.4-bookworm
    ports:
      - "8000:8000"
```

📖 **Guide:** [Swoole Guide](../guides/swoole-guide.md)

### PHP OpenSwoole

OpenSwoole fork with async I/O and similar features to Swoole.

| Image Tag | PHP | OpenSwoole | Architecture |
|-----------|-----|------------|--------------|
| `php-openswoole:8.4-bookworm` | 8.4 | Latest | amd64, arm64 |
| `php-openswoole:8.3-bookworm` | 8.3 | Latest | amd64, arm64 |
| `php-openswoole:8.2-bookworm` | 8.2 | Latest | amd64, arm64 |

**Includes:** OpenSwoole extension with OpenSSL, cURL, c-ares, all Cbox extensions, Composer, Node.js, Cbox Init.

```yaml
# Laravel Octane with OpenSwoole
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-openswoole:8.4-bookworm
    ports:
      - "8000:8000"
```

### FrankenPHP

Modern PHP application server built on Caddy with automatic HTTPS and HTTP/3.

| Image Tag | PHP | FrankenPHP | Architecture |
|-----------|-----|------------|--------------|
| `frankenphp:8.4-bookworm` | 8.4 | Latest | amd64, arm64 |
| `frankenphp:8.3-bookworm` | 8.3 | Latest | amd64, arm64 |
| `frankenphp:8.2-bookworm` | 8.2 | Latest | amd64, arm64 |

**Includes:** FrankenPHP binary, Caddy web server, all Cbox extensions, Composer, Node.js, Cbox Init.

```yaml
# Laravel Octane with FrankenPHP (auto HTTPS)
services:
  app:
    image: ghcr.io/cboxdk/baseimages/frankenphp:8.4-bookworm
    ports:
      - "80:80"
      - "443:443"
```

📖 **Guide:** [FrankenPHP Guide](../guides/frankenphp-guide.md)

### Server Comparison

| Feature | Swoole | OpenSwoole | FrankenPHP |
|---------|--------|------------|------------|
| **Performance** | Fastest | Fast | Fast |
| **Coroutines** | Yes | Yes | No |
| **Task Workers** | Yes | Yes | No |
| **HTTP/3** | No | No | Yes |
| **Auto HTTPS** | No | No | Yes (Caddy) |
| **Memory** | Lowest | Low | Medium |
| **Best For** | Max performance | Async I/O | Easy HTTPS |

📖 **Complete guide:** [Laravel Octane Guide](../guides/laravel-octane.md)

## Tag Format

```
{type}:{php_version}-{os}[-tier][-rootless]

Examples:
php-fpm-nginx:8.4-bookworm              # Standard tier (default)
php-fpm-nginx:8.4-bookworm-slim         # Slim tier
php-fpm-nginx:8.4-bookworm-full         # Full tier
php-fpm-nginx:8.4-bookworm-rootless     # Standard + rootless
php-fpm-nginx:8.4-bookworm-slim-rootless  # Slim + rootless
php-fpm-nginx:8.4-bookworm-full-rootless  # Full + rootless
```

## Rolling Tags (Recommended)

Rolling tags receive weekly security updates:

```yaml
# Automatically gets security patches every Monday
image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm
```

## Immutable SHA Tags

For reproducible builds, use SHA-pinned tags:

```yaml
# Locked to specific build
image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm@sha256:abc123...
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
docker pull ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm
```

## OS Information

Cbox Base Images use Debian 12 (Bookworm) as the base operating system.

| Feature | Debian 12 (Bookworm) |
|---------|----------------------|
| **Base Size** | ~120MB |
| **Package Manager** | apt-get |
| **libc** | glibc |
| **Security Updates** | Weekly |
| **Compatibility** | Excellent |
| **Best For** | Production, compatibility |

## Tier Comparison

| Feature | Slim | Standard | Full |
|---------|------|----------|------|
| **Size (Debian 12)** | ~120MB | ~250MB | ~700MB |
| **Core Extensions** | ✅ 25+ | ✅ 25+ | ✅ 25+ |
| **ImageMagick** | ❌ | ✅ | ✅ |
| **vips** | ❌ | ✅ | ✅ |
| **Node.js 22** | ❌ | ✅ | ✅ |
| **Chromium** | ❌ | ❌ | ✅ |
| **Best For** | APIs, microservices | Most apps | Browser automation |

## Version Support

| PHP Version | Status | Security Support Until |
|-------------|--------|------------------------|
| PHP 8.5 | Active | November 2029 |
| PHP 8.4 | Active | November 2028 |
| PHP 8.3 | Active | November 2027 |
| PHP 8.2 | Active | December 2026 |

**Recommendation**: Use PHP 8.4 for production stability, PHP 8.5 for latest features.

## Usage Examples

### Docker CLI

```bash
# Pull standard tier (most Laravel/PHP apps)
docker pull ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm

# Pull slim tier (APIs, microservices)
docker pull ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm-slim

# Pull full tier (Browsershot, Dusk)
docker pull ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm-full

# Run with volume mount
docker run -p 8000:80 -v $(pwd):/var/www/html \
  ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm
```

### Docker Compose

```yaml
services:
  # Standard tier - most Laravel apps
  app:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm
    ports:
      - "8000:80"
    volumes:
      - ./:/var/www/html

  # Slim tier - API service
  api:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm-slim
    ports:
      - "8001:80"

  # Full tier - PDF generation service
  pdf:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm-full
    environment:
      PHP_MEMORY_LIMIT: "1G"
```

### Dockerfile

```dockerfile
# Standard tier for most apps
FROM ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm

COPY --chown=www-data:www-data . /var/www/html

RUN composer install --no-dev --optimize-autoloader
```

```dockerfile
# Full tier for Browsershot
FROM ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm-full

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
docker pull ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm
docker-compose up -d --pull always
```

---

**Need help choosing?** See [Choosing a Variant](../getting-started/choosing-variant.md) | [Image Tiers Comparison](./editions-comparison.md)
