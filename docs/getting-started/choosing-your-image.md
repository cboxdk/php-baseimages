---
title: "Choosing Your Image"
description: "Image tiers, sizes, root vs rootless, and single-service vs multi-service explained"
weight: 3
---

## Image Size Matrix

### php-fpm-nginx (multi-service)

| Tag | Tier | Size |
|-----|------|------|
| `php-fpm-nginx:8.5-bookworm-slim` | Slim | ~120 MiB |
| `php-fpm-nginx:8.5-bookworm` | Standard | ~250 MiB |
| `php-fpm-nginx:8.5-bookworm-chromium` | Chromium | ~700 MiB |
| `php-fpm-nginx:8.4-bookworm-slim` | Slim | ~120 MiB |
| `php-fpm-nginx:8.4-bookworm` | Standard | ~250 MiB |
| `php-fpm-nginx:8.4-bookworm-chromium` | Chromium | ~700 MiB |
| `php-fpm-nginx:8.3-bookworm-slim` | Slim | ~120 MiB |
| `php-fpm-nginx:8.3-bookworm` | Standard | ~250 MiB |
| `php-fpm-nginx:8.3-bookworm-chromium` | Chromium | ~700 MiB |
| `php-fpm-nginx:8.2-bookworm-slim` | Slim | ~120 MiB |
| `php-fpm-nginx:8.2-bookworm` | Standard | ~250 MiB |
| `php-fpm-nginx:8.2-bookworm-chromium` | Chromium | ~700 MiB |

All tags also have `-rootless` and `-dev` variants (append the suffix).

### php-fpm (single-service)

| Tag | Tier | Size |
|-----|------|------|
| `php-fpm:8.5-bookworm-slim` | Slim | ~100 MiB |
| `php-fpm:8.5-bookworm` | Standard | ~230 MiB |
| `php-fpm:8.4-bookworm-slim` | Slim | ~100 MiB |
| `php-fpm:8.4-bookworm` | Standard | ~230 MiB |
| `php-fpm:8.3-bookworm-slim` | Slim | ~100 MiB |
| `php-fpm:8.3-bookworm` | Standard | ~230 MiB |
| `php-fpm:8.2-bookworm-slim` | Slim | ~100 MiB |
| `php-fpm:8.2-bookworm` | Standard | ~230 MiB |

### php-cli (single-service)

| Tag | Tier | Size |
|-----|------|------|
| `php-cli:8.5-bookworm-slim` | Slim | ~100 MiB |
| `php-cli:8.5-bookworm` | Standard | ~230 MiB |
| `php-cli:8.5-bookworm-chromium` | Chromium | ~680 MiB |
| `php-cli:8.5-bookworm-dev` | Dev | ~700 MiB |
| `php-cli:8.4-bookworm-slim` | Slim | ~100 MiB |
| `php-cli:8.4-bookworm` | Standard | ~230 MiB |
| `php-cli:8.4-bookworm-chromium` | Chromium | ~680 MiB |
| `php-cli:8.4-bookworm-dev` | Dev | ~700 MiB |
| `php-cli:8.3-bookworm-slim` | Slim | ~100 MiB |
| `php-cli:8.3-bookworm` | Standard | ~230 MiB |
| `php-cli:8.3-bookworm-chromium` | Chromium | ~680 MiB |
| `php-cli:8.3-bookworm-dev` | Dev | ~700 MiB |
| `php-cli:8.2-bookworm-slim` | Slim | ~100 MiB |
| `php-cli:8.2-bookworm` | Standard | ~230 MiB |
| `php-cli:8.2-bookworm-chromium` | Chromium | ~680 MiB |
| `php-cli:8.2-bookworm-dev` | Dev | ~700 MiB |

All tags also have `-rootless` variants (append the suffix).

All images are prefixed with `ghcr.io/cboxdk/php-baseimages/`.

## Tiers

**Slim** (`-slim`) -- Core PHP extensions (opcache, pdo_mysql, pdo_pgsql, redis, apcu, msgpack, intl, bcmath, gd with WebP, zip, pcntl, sockets) plus Composer and Cbox Init. Best for APIs, microservices, and CI pipelines where image size matters.

**Standard** (no suffix, default) -- Everything in Slim plus ImageMagick, libvips, GD with AVIF, Node.js 22, mongodb, soap, ldap, xsl, calendar, gettext, sysv IPC, exiftool, ghostscript, and librsvg. The right choice for most Laravel, Symfony, and WordPress applications.

**Chromium** (`-chromium`) -- Everything in Standard plus Chromium, Puppeteer environment, NSS, HarfBuzz, and fonts. Required for Browsershot, Laravel Dusk, Puppeteer, and PDF generation via headless browser.

**Dev** (`-dev`) -- Chromium tier with Xdebug, PCOV, and SPX pre-installed. Use for local development and CI test runs. Never use in production.

## Root vs Rootless

| Variant | Runs as | Tag example |
|---------|---------|-------------|
| Root (default) | `root` at start, drops to `www-data` | `8.4-bookworm` |
| Rootless | `www-data` from start | `8.4-bookworm-rootless` |

Rootless variants append `-rootless` to any tag: `8.4-bookworm-slim-rootless`, `8.4-bookworm-chromium-rootless`, etc.

**Use rootless when:**
- Kubernetes with `runAsNonRoot: true` security policies
- OpenShift (requires non-root by default)
- CIS benchmark compliance

**Use root (default) when:**
- Docker Compose on a single server
- You need to bind to port 80 directly
- No specific rootless requirement

## Single-Service vs Multi-Service

| Aspect | Multi-service (`php-fpm-nginx`) | Single-service (`php-fpm` + `nginx`) |
|--------|-------------------------------|--------------------------------------|
| Containers | 1 | 2 |
| Setup | Simpler | More config |
| Scaling | Together | Independent |
| Failure isolation | Shared | Independent |
| Best for | Docker Compose, small/medium apps | Kubernetes, independent scaling |

**Use multi-service (`php-fpm-nginx`)** for most projects. It runs PHP-FPM and Nginx in one container managed by Cbox Init, with framework auto-detection, health checks, and graceful shutdown built in.

**Use single-service (`php-fpm` + `nginx`)** when you need to scale PHP-FPM and Nginx independently, or when your orchestrator (Kubernetes, Nomad) expects one process per container.

```yaml
# Multi-service (recommended for most projects)
services:
  app:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm
    ports:
      - "80:80"

# Single-service (Kubernetes / independent scaling)
services:
  php:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm:8.4-bookworm
  nginx:
    image: ghcr.io/cboxdk/php-baseimages/nginx:bookworm
    ports:
      - "80:80"
    depends_on:
      - php
```

## Next Steps

- [5-Minute Quickstart](quickstart) -- Get running immediately
- [Laravel Guide](../guides/laravel-guide) -- Complete Laravel setup
- [Available Extensions](../reference/available-extensions) -- Full extension list by tier
