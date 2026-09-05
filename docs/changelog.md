---
title: "Changelog"
description: "What's new in Cbox PHP Base Images - features, improvements, and security updates"
weight: 90
---

# Changelog

All notable changes to Cbox PHP Base Images.

## [Unreleased]

### Added
- **Release channel tags (`-vN`)** - e.g. `8.4-bookworm-v1`: rebuilt weekly with OS security patches, but never crossing a tooling major. The recommended production pin: stable behavior without CVE rot. Rolling tags keep following the latest release; SHA/digest tags remain the immutable option. Channel comes from `release.channel` in versions.json; previous majors stay supported for 6 months after a new major (see docs/reference/tagging-strategy.md)

## [1.0.0] - 2026-09-05

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
image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-alpine

# NEW (Bookworm)
image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm
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
- **Cbox Init v3.1.2 with runtime PHP-FPM tuning (fpm-tune)** - measures live per-worker memory (PSS) and resizes the pool via an atomic drop-in + graceful SIGUSR2 reload (master PID unchanged, zero dropped connections - verified under saturated load through 20 reloads). Off by default; enable with `CBOX_FPM_TUNE=true` (`CBOX_INIT_FPM_TUNE_MODE/INTERVAL/METRICS_ADDR` for mode, cadence and Prometheus metrics). Works in root and rootless variants
- **Small-container crash-loop fixed** - the published 3.0.0 images crash-looped every container under ~512MB at boot (the boot autotune exited PID 1 when the default `medium` profile did not fit the memory limit). Fixed upstream in cbox-init 3.1.2 (cboxdk/init#133): the calculator now clamps with a warning and boots; `PHP_FPM_AUTOTUNE_STRICT=1` restores fail-hard for deploy-time checks. Verified: 128MB and 256MB containers boot and serve with defaults
- **Cbox Init v3.0.0** - env-defined lifecycle hooks, full init signal plane, hardened API
  - Application warmup hooks via env vars (`CBOX_INIT_HOOK_PRE_START_<N>_COMMAND`, `_TIMEOUT`, `_ALLOW_FAILURE`) - run supervised pre-flight work (Statamic stache warm, Symfony cache warmup) before health checks start succeeding
  - `SIGHUP` reloads config; `SIGUSR1`/`SIGUSR2` forwarded to all managed process groups (`docker kill -s USR2` = php-fpm graceful reload)
  - Per-process signal action via CLI/API (e.g. nginx config reload without touching the stack)
  - Management API now binds loopback-only by default (plus Unix socket); new `CBOX_INIT_API_HOST` env var (set `0.0.0.0` + `CBOX_INIT_API_AUTH` to expose via a published port) - **breaking** if you previously published port 9180
  - REST log endpoints renamed fields to match the SSE stream (`timestamp`, `process`, `instance`) - **breaking** for API log consumers
  - Strict config validation: unknown YAML keys are rejected at load (shipped configs validated)
- **Brotli compression** in all php-fpm-nginx tiers - ngx_brotli compiled against Debian's exact nginx, statically linked. On by default (`NGINX_BROTLI`, `NGINX_BROTLI_COMP_LEVEL`, `NGINX_BROTLI_TYPES`, `NGINX_BROTLI_STATIC`); pre-compressed `.br` assets served straight from disk
- **headers-more nginx module** in all php-fpm-nginx tiers; `NGINX_SERVER_HEADER` rebrands the Server header (`none` removes it)
- **`NGINX_LOG_FORMAT`** - `combined` (default), `combined_no_query` (privacy: no query strings on disk), `json` (structured)
- **`gzip_static on`** by default (`NGINX_GZIP_STATIC`) - pre-compressed `.gz` assets served straight from disk
- PHP 8.5 support
- Laravel Reverb WebSocket support (`LARAVEL_REVERB=true`)
- mTLS client certificate authentication
- Reverse proxy support (Cloudflare, Traefik, HAProxy)
- **Cbox Init v2.1.0** - CLI commands, log file tailing, API authentication
  - CLI commands via Unix socket: `list`, `status`, `start`, `stop`, `restart`, `scale`, `logs -f`, `reload-config`
  - Log file tailing with JSON parsing and size-based rotation (Laravel log tailed by default)
  - SSE log streaming (`/api/v1/logs/stream` and `cbox-init logs -f`)
  - Bearer token authentication for Management API (`CBOX_INIT_API_AUTH`)
  - New API endpoints: `start`, `stop`, `health`, `logs/stream`
- Environment variable overrides for cbox-init global config (`CBOX_INIT_API_ENABLED`, `CBOX_INIT_API_PORT`, `CBOX_INIT_API_AUTH`, `CBOX_INIT_METRICS_ENABLED`, `CBOX_INIT_METRICS_PORT`, `CBOX_INIT_LOG_LEVEL`, `CBOX_INIT_LOG_FORMAT`)

---

## [2024.12] - December 2024

### Added
- **4-Tier Image System** - Slim, Standard, Chromium, Dev tiers for different use cases
  - **Slim** (~120 MiB): Core extensions, APIs/microservices
  - **Standard** (~250 MiB): + ImageMagick, vips, Node.js 22 (DEFAULT)
  - **Chromium** (~700 MiB): + Chromium for Browsershot/Dusk
  - **Dev** (~750 MiB): + Xdebug, PCOV, SPX for local development
- **gRPC extension** - Added to all tiers
- **Rootless variants** - All tiers support `-rootless` suffix
- New tag format: `{type}:{php-version}-{os}[-tier][-rootless]`

### Changed
- Renamed "Minimal" edition to "Slim" tier
- Renamed "Full" edition to "Standard" tier (now the default)
- New "Chromium" tier includes Chromium (previously separate)
- Tag format changed from `-minimal` suffix to `-slim` suffix
- Standard tier is now the default (no suffix)

### Migration Guide

**Tag format changes:**
```yaml
# OLD (2024.11)
image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm           # Full edition
image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-minimal   # Minimal edition

# NEW (2024.12)
image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm           # Standard tier (default)
image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-slim      # Slim tier
image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-chromium  # Chromium tier (with Chromium)
```

**Tier selection guide:**
| Old Tag | New Tag | When to Use |
|---------|---------|-------------|
| `8.4-bookworm` | `8.4-bookworm` | Most apps (Standard is default) |
| `8.4-bookworm-minimal` | `8.4-bookworm-slim` | APIs, microservices |
| N/A | `8.4-bookworm-chromium` | Browsershot, Dusk, PDF |
| N/A | `8.4-bookworm-dev` | Local development (Xdebug, PCOV, SPX) |

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
| Browsershot/Dusk | `8.4-bookworm-chromium` |

**Step 2: Update your docker-compose.yml**

```yaml
# Most apps - no change needed!
image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm

# For Browsershot/Dusk users - use Chromium tier
image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-chromium

# For API/microservices - use Slim tier
image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-slim
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
| `LARAVEL_AUTO_OPTIMIZE` | `LARAVEL_OPTIMIZE_ENABLED` |
| `LARAVEL_AUTO_MIGRATE` | `LARAVEL_MIGRATE_ENABLED` |

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

- **Bugs**: [GitHub Issues](https://github.com/cboxdk/php-baseimages/issues)
- **Security**: See [SECURITY.md](https://github.com/cboxdk/php-baseimages/blob/main/SECURITY.md)
- **Questions**: [GitHub Discussions](https://github.com/cboxdk/php-baseimages/discussions)
