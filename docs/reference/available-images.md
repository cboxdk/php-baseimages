---
title: "Available Images"
description: "Complete matrix of all Cbox base image tags, variants, and architectures"
weight: 3
---

# Available Images

Complete reference of all available Cbox base image tags and variants.

## Image Registry

All images are published to GitHub Container Registry:

```text
ghcr.io/cboxdk/php-baseimages/{image-type}:{tag}
```

## Image Tiers

All images come in four tiers to match your needs:

| Tier | Tag Suffix | Size (Debian 12) | Best For |
|------|------------|------------------|----------|
| **Slim** | `-slim` | ~120 MiB | APIs, microservices |
| **Standard** | (none) | ~250 MiB | Most apps (DEFAULT) |
| **Chromium** | `-chromium` | ~700 MiB | Browsershot, Dusk, PDF |
| **Dev** | `-dev` | ~750 MiB | Chromium + Xdebug, PCOV, SPX |

## Multi-Service Images (PHP-FPM + Nginx)

Single container with both PHP-FPM and Nginx - perfect for simple deployments.

### Standard Tier (Default)

| Image Tag | PHP | OS | Size | Architecture |
|-----------|-----|----|----- |--------------|
| `php-fpm-nginx:8.5-bookworm` | 8.5 | Debian 12 | ~250 MiB | amd64, arm64 |
| `php-fpm-nginx:8.4-bookworm` | 8.4 | Debian 12 | ~250 MiB | amd64, arm64 |
| `php-fpm-nginx:8.3-bookworm` | 8.3 | Debian 12 | ~250 MiB | amd64, arm64 |
| `php-fpm-nginx:8.2-bookworm` | 8.2 | Debian 12 | ~250 MiB | amd64, arm64 |

### Slim Tier

Optimized for APIs and microservices with minimal footprint:

| Image Tag | PHP | OS | Size | Architecture |
|-----------|-----|----|----- |--------------|
| `php-fpm-nginx:8.5-bookworm-slim` | 8.5 | Debian 12 | ~120 MiB | amd64, arm64 |
| `php-fpm-nginx:8.4-bookworm-slim` | 8.4 | Debian 12 | ~120 MiB | amd64, arm64 |
| `php-fpm-nginx:8.3-bookworm-slim` | 8.3 | Debian 12 | ~120 MiB | amd64, arm64 |
| `php-fpm-nginx:8.2-bookworm-slim` | 8.2 | Debian 12 | ~120 MiB | amd64, arm64 |

### Chromium Tier

Includes Chromium for Browsershot, Dusk, and PDF generation:

| Image Tag | PHP | OS | Size | Architecture |
|-----------|-----|----|----- |--------------|
| `php-fpm-nginx:8.5-bookworm-chromium` | 8.5 | Debian 12 | ~700 MiB | amd64, arm64 |
| `php-fpm-nginx:8.4-bookworm-chromium` | 8.4 | Debian 12 | ~700 MiB | amd64, arm64 |
| `php-fpm-nginx:8.3-bookworm-chromium` | 8.3 | Debian 12 | ~700 MiB | amd64, arm64 |
| `php-fpm-nginx:8.2-bookworm-chromium` | 8.2 | Debian 12 | ~700 MiB | amd64, arm64 |

### Rootless Variants

All tiers support rootless execution (runs as `www-data` user). Available for all PHP versions:

| Image Tag | Tier | Description |
|-----------|------|-------------|
| `php-fpm-nginx:{version}-bookworm-rootless` | Standard | Default + rootless |
| `php-fpm-nginx:{version}-bookworm-slim-rootless` | Slim | Slim + rootless |
| `php-fpm-nginx:{version}-bookworm-chromium-rootless` | Chromium | Chromium + rootless |
| `php-fpm-nginx:{version}-bookworm-dev-rootless` | Dev | Dev + rootless |

Where `{version}` is `8.2`, `8.3`, `8.4`, or `8.5`.

## Tag Format

```text
{type}:{php_version}-{os}[-tier][-rootless][-vN]

Examples:
php-fpm-nginx:8.4-bookworm-v1           # Standard tier, release channel (RECOMMENDED)
php-fpm-nginx:8.4-bookworm-slim-v1      # Slim tier, release channel
php-fpm-nginx:8.4-bookworm-chromium-v1  # Chromium tier, release channel
php-fpm-nginx:8.4-bookworm-rootless-v1  # Standard + rootless, release channel
php-fpm-nginx:8.4-bookworm              # Standard tier, rolling (follows latest release)
php-fpm-nginx:8.4-bookworm-slim-rootless  # Slim + rootless, rolling
```

Every tag in the matrices above also exists with the `-v1` release-channel
suffix — that is the variant to pin in production.

## Release Channel Tags (Recommended for Production)

Channel tags are rebuilt weekly with OS security patches but never cross a
tooling major — your runtime contract stays put, the machine underneath
stays patched:

```yaml
# Behavior pinned to major v1, security patches keep flowing
image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-v1
```

## Rolling Tags

Rolling tags also receive weekly security updates, but follow the newest
tooling release — including future majors:

```yaml
# Follows the latest release, rebuilt every Monday
image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm
```

## Immutable Digests

For byte-exact reproduction, pin the digest (ages by design — it contains
the CVEs of its build day):

```yaml
# Locked to a specific build
image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-v1@sha256:abc123...
```

See [Tagging Strategy](tagging-strategy) for the full policy.

## Architecture Support

All images are built for multiple architectures:

| Architecture | Platform | Examples |
|--------------|----------|----------|
| `amd64` | x86_64 | Intel/AMD servers, most cloud VMs |
| `arm64` | aarch64 | Apple Silicon, AWS Graviton, Raspberry Pi 4+ |

Docker automatically pulls the correct architecture:

```bash
# Works on both AMD64 and ARM64
docker pull ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-v1
```

## OS Information

Cbox PHP Base Images use Debian 12 (Bookworm) as the base operating system.

| Feature | Debian 12 (Bookworm) |
|---------|----------------------|
| **Base Size** | ~120 MiB |
| **Package Manager** | apt-get |
| **libc** | glibc |
| **Security Updates** | Weekly |
| **Compatibility** | Excellent |
| **Best For** | Production, compatibility |

## Tier Comparison

| Feature | Slim | Standard | Chromium | Dev |
|---------|------|----------|----------|-----|
| **Size (Debian 12)** | ~120 MiB | ~250 MiB | ~700 MiB | ~750 MiB |
| **Core Extensions** | ✅ 25+ | ✅ 25+ | ✅ 25+ | ✅ 25+ |
| **ImageMagick** | ❌ | ✅ | ✅ | ✅ |
| **vips** | ❌ | ✅ | ✅ | ✅ |
| **Node.js 22 (+ npm/npx)** | ❌ | ✅ | ✅ | ✅ |
| **Bun** | ❌ | ✅ | ✅ | ✅ |
| **Chromium** | ❌ | ❌ | ✅ | ✅ |
| **Xdebug/PCOV/SPX** | ❌ | ❌ | ❌ | ✅ |
| **Best For** | APIs, microservices | Most apps | Browser automation | Development, CI/CD |

## Version Support

| PHP Version | Status | Security Support Until |
|-------------|--------|------------------------|
| PHP 8.5 | Active | November 2029 |
| PHP 8.4 | Active | November 2028 |
| PHP 8.3 | Active | November 2027 |
| PHP 8.2 | EOL | December 2025 |

**Recommendation**: Use PHP 8.4 or 8.5 for production. PHP 8.5 includes the latest language features.

## Usage Examples

### Docker CLI

```bash
# Pull standard tier (most Laravel/PHP apps)
docker pull ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-v1

# Pull slim tier (APIs, microservices)
docker pull ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-slim-v1

# Pull chromium tier (Browsershot, Dusk)
docker pull ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-chromium-v1

# Run with volume mount
docker run -p 8000:80 -v $(pwd):/var/www/html \
  ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-v1
```

### Docker Compose

```yaml
services:
  # Standard tier - most Laravel apps
  app:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-v1
    ports:
      - "8000:80"
    volumes:
      - ./:/var/www/html

  # Slim tier - API service
  api:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-slim-v1
    ports:
      - "8001:80"

  # Chromium tier - PDF generation service
  pdf:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-chromium-v1
    environment:
      PHP_MEMORY_LIMIT: "1G"
```

### Dockerfile

```dockerfile
# Standard tier for most apps
FROM ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-v1

COPY --chown=www-data:www-data . /var/www/html

RUN composer install --no-dev --optimize-autoloader
```

```dockerfile
# Chromium tier for Browsershot
FROM ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-chromium-v1

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
docker pull ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-v1
docker-compose up -d --pull always
```

---

**Need help choosing?** See [Choosing Your Image](../getting-started/choosing-your-image)
