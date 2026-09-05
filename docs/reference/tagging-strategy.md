---
title: "Image Tagging Strategy"
description: "Comprehensive guide to Cbox image tagging, versioning, and deprecation policies"
weight: 5
---

# Image Tagging Strategy

Cbox PHP Base Images follow a clear, predictable tagging strategy with four image tiers and rootless variants.

## Tag Format

```
{image-type}:{php-version}-{os}[-tier][-rootless][-vN]
```

## Release Channels & Pinning

A tag can promise one of two things — **identical bits** (reproducibility) or a
**stable behavior contract** (no breaking changes) — and no single tag can stay
CVE-free while promising identical bits. So we publish three kinds of tags:

| Kind | Example | Rebuilt weekly? | Crosses tooling majors? | Use when |
|------|---------|-----------------|------------------------|----------|
| Rolling | `8.4-bookworm` | ✅ yes | ✅ yes (follows latest release) | You track upstream and want everything newest |
| **Channel** | `8.4-bookworm-v1` | ✅ yes | ❌ never | **Recommended for production**: entrypoint/tooling behavior locked to major v1, OS security patches keep flowing |
| Digest / SHA | `8.4-bookworm-sha-abc1234` or `@sha256:…` | ❌ immutable | — | Audits, reproductions, byte-exact rollbacks. Ages by design — contains the CVEs of its build day |

GitHub releases (`vX.Y.Z`) version the **image tooling** — entrypoint behavior,
cbox-init version, nginx modules, the extension set — not PHP itself. The
channel tag `-vN` follows the newest release within major `N`.

**Support policy:** the current major's channel tags are rebuilt weekly. When a
new major ships, the previous major's channel keeps receiving weekly security
rebuilds for **6 months** (from a `release/vN` maintenance branch), then goes
EOL. Which majors are in support is recorded in `versions.json` under
`release.supported_majors`.

```yaml
# Recommended production pin: behavior locked, security patches current
image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-v1
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

Two deliberately distinct concepts, both defined in `versions.json`:

- **Newest** (`php.newest`, currently **8.5**): the newest stable PHP. This is
  what the `latest` tag follows, per Docker ecosystem convention.
- **Recommended default** (`php.default`, currently **8.4**): what the
  documentation examples use and what we suggest for new projects — one minor
  behind newest, with the widest extension/ecosystem compatibility.

**Latest (follows `php.newest`)**:
- `latest` → `8.5-bookworm`
- `8.5` → `8.5-bookworm`

**Tier aliases**:
- `slim` → `8.5-bookworm-slim`
- `chromium` → `8.5-bookworm-chromium`

Don't use `latest` in production — pin a release channel tag
(`8.4-bookworm-v1`) instead.

## Deprecation Policy

Cbox follows a predictable deprecation schedule based on upstream EOL dates.

**PHP has two lifecycle dates**, and our policy keys off the second one:

- **Active support end**: php.net stops shipping bug fixes; security fixes
  continue for two more years. This is a *normal, supported state* — images
  keep building weekly, no warnings. Roughly half the PHP fleet is in this
  phase at any given time.
- **Security support end**: the date that matters. 90 days before it, images
  enter the deprecation warning phase; after it, the removal countdown starts.

Both dates live in `versions.json` (`php.active_support_until` and
`php.security_support_until`, sourced from
[php.net/supported-versions](https://www.php.net/supported-versions.php)).

### Timeline

| Component | Removal After Security EOL | Warning Period |
|-----------|---------------------------|----------------|
| PHP       | 6 months          | 90 days        |
| Debian    | 3 months          | 90 days        |
| Node.js   | 6 months          | 90 days        |

### Current EOL Dates

Check `versions.json` for current support dates, or run:

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

- [Available Images](./available-images) - Complete list of all images
- [Choosing Your Image](../getting-started/choosing-your-image) - Tiers, sizes, and when to use each
