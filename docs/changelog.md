---
title: "Changelog"
description: "What's new in Cbox base images - features, improvements, and security updates"
weight: 99
---

# Changelog

All notable changes to Cbox base images.

## [Unreleased]

### Breaking Changes
- **OS Variant Simplification** - Only Debian 12 (Bookworm) is now supported
  - Removed Alpine variant
  - Removed Debian 13 (Trixie) variant
  - Removed Ubuntu variant (FrankenPHP, Swoole, OpenSwoole)
  - All images now based on Debian 12 (Bookworm) with glibc

### Migration from Alpine/Trixie

**Tag changes:**
```yaml
# OLD (Alpine)
image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-alpine

# NEW (Bookworm)
image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm
```

**Why this change?**
- Simplified maintenance and testing
- Better glibc compatibility for all extensions
- Consistent behavior across all deployments
- Focus on stability over variety

**Custom extension installation:**
```dockerfile
# OLD (Alpine)
RUN apk add --no-cache package-name

# NEW (Bookworm)
RUN apt-get update && apt-get install -y package-name && rm -rf /var/lib/apt/lists/*
```

### Added
- PHP 8.5-beta support (experimental)
- Laravel Reverb WebSocket support (`LARAVEL_REVERB=true`)
- mTLS client certificate authentication
- Reverse proxy support (Cloudflare, Traefik, HAProxy)

---

## [2024.12] - December 2024

### Added
- **3-Tier Image System** - Slim, Standard, Full tiers for different use cases
  - **Slim** (~120MB): Core extensions, APIs/microservices
  - **Standard** (~250MB): + ImageMagick, vips, Node.js 22 (DEFAULT)
  - **Full** (~700MB): + Chromium for Browsershot/Dusk
- **gRPC extension** - Added to all tiers
- **Rootless variants** - All tiers support `-rootless` suffix
- New tag format: `{type}:{php-version}-{os}[-tier][-rootless]`

### Changed
- Renamed "Minimal" edition to "Slim" tier
- Renamed "Full" edition to "Standard" tier (now the default)
- New "Full" tier includes Chromium (previously separate)
- Tag format changed from `-minimal` suffix to `-slim` suffix
- Standard tier is now the default (no suffix)

### Migration Guide

**Tag format changes:**
```yaml
# OLD (2024.11)
image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm           # Full edition
image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm-minimal   # Minimal edition

# NEW (2024.12)
image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm           # Standard tier (default)
image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm-slim      # Slim tier
image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm-full      # Full tier (with Chromium)
```

**Tier selection guide:**
| Old Tag | New Tag | When to Use |
|---------|---------|-------------|
| `8.4-bookworm` | `8.4-bookworm` | Most apps (Standard is default) |
| `8.4-bookworm-minimal` | `8.4-bookworm-slim` | APIs, microservices |
| N/A | `8.4-bookworm-full` | Browsershot, Dusk, PDF |

---

## [2024.11] - November 2024

### Added
- **Cbox Init** - Go-based process manager replacing bash scripts
- Laravel Horizon support (`LARAVEL_HORIZON=true`)
- Queue worker scaling (`CBOX_INIT_PROCESS_QUEUE_DEFAULT_SCALE`)
- JSON structured logging
- Graceful shutdown handling

### Changed
- Entrypoint rewritten in Go for better performance
- Health checks now include process monitoring
- Default PHP memory limit: 256M → 512M

### Security
- Weekly automated rebuilds for security patches
- Trivy CVE scanning in CI/CD
- Non-root container support

---

## [2024.10] - October 2024

### Added
- PHP 8.4 GA support
- Debian Trixie (testing) variant
- SPX Profiler in dev images
- Multi-architecture builds (amd64/arm64)

### Changed
- Base images updated to Alpine 3.20, Debian 12.7
- OPcache JIT enabled by default
- Redis extension updated to 6.0.2

---

## [2024.09] - September 2024

### Added
- Minimal edition (`-minimal` suffix) - now Slim tier
- Development edition (`-dev` suffix) with Xdebug
- Framework auto-detection (Laravel, Symfony, WordPress)
- Automatic permission fixes

### Changed
- Nginx security headers enabled by default
- PHP-FPM dynamic process management

---

## Upgrade Guide

### From 2024.11 to 2024.12 (Tier System)

**Step 1: Identify your current usage**

| If you used... | You need... |
|----------------|-------------|
| `8.4-bookworm` (Full edition) | `8.4-bookworm` (Standard tier) - same tag! |
| `8.4-bookworm-minimal` | `8.4-bookworm-slim` |
| Browsershot/Dusk | `8.4-bookworm-full` |

**Step 2: Update your docker-compose.yml**

```yaml
# Most apps - no change needed!
image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm

# For Browsershot/Dusk users - use Full tier
image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm-full

# For API/microservices - use Slim tier
image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm-slim
```

### From bash-based entrypoint to Cbox Init

**Before (v2024.09)**:
```yaml
environment:
  - LARAVEL_SCHEDULER_ENABLED=true
```

**After (v2024.11)**:
```yaml
environment:
  - LARAVEL_SCHEDULER=true  # Simplified naming
```

### Environment variable changes

| Old Variable | New Variable |
|--------------|--------------|
| `LARAVEL_SCHEDULER_ENABLED` | `LARAVEL_SCHEDULER` |
| `LARAVEL_AUTO_OPTIMIZE` | `LARAVEL_OPTIMIZE` |
| `LARAVEL_AUTO_MIGRATE` | `LARAVEL_MIGRATE` |

---

## Security Updates

Cbox images are rebuilt weekly (Mondays 03:00 UTC) with latest security patches.

**To get updates**:
```bash
docker compose pull
docker compose up -d
```

**Check current version**:
```bash
docker compose exec app cat /etc/cbox-version
```

---

## Reporting Issues

- **Bugs**: [GitHub Issues](https://github.com/cboxdk/baseimages/issues)
- **Security**: See [SECURITY.md](https://github.com/cboxdk/baseimages/blob/main/SECURITY.md)
- **Questions**: [GitHub Discussions](https://github.com/cboxdk/baseimages/discussions)
