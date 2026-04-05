---
title: "Cbox vs ServerSideUp"
description: "Technical comparison of Cbox and ServerSideUp PHP Docker images"
weight: 60
---

# Cbox vs ServerSideUp

Both projects provide production-ready PHP Docker images. This page compares them on technical merits so you can pick the right fit.

## At a Glance

| | Cbox | ServerSideUp |
|---|---|---|
| Process Manager | Cbox Init (Go binary, ~8 MiB) | S6 Overlay |
| Image Tiers | 4 (Slim / Standard / Chromium / Dev) | 2 (Base / Full) |
| PHP Versions | 8.2--8.5 | 8.1--8.5 |
| OS Support | Debian 12 | Debian 12, Alpine |
| Extensions (base) | 15 (Slim) / 28+ (Standard) | 6 |
| Framework Detection | Auto (Laravel, Symfony, WordPress) | Laravel only (opt-in) |
| Prometheus Metrics | Built-in | No |
| Health Checks | Built-in with auto-restart | Manual |
| Multi-arch | Native ARM64 builds | Depot.dev |
| FPM base size | ~120 MiB (Slim) | ~170 MiB |

## Extensions

ServerSideUp ships 6 extensions and expects users to install their own. Cbox ships 15 (Slim) to 28+ (Standard) per tier, so most Laravel, Symfony, and WordPress applications work without a custom Dockerfile. Extensions like `gd`, `intl`, `redis`, `imagick`, and `vips` are included out of the box on Standard and above.

## Process Management

S6 Overlay is a proven init system with a large user base and flexible service definitions. Cbox Init takes a different approach: a single Go binary configured with YAML, with built-in Prometheus metrics (`/metrics`), structured JSON logging, and automatic health-check-driven restarts. The trade-off is simplicity and observability versus ecosystem maturity.

## Framework Support

ServerSideUp targets Laravel. Cbox auto-detects Laravel, Symfony, and WordPress at container startup and configures permissions, cron schedules, and process workers accordingly.

## Image Tiers

ServerSideUp offers 2 tiers (Base, Full). Cbox offers 4:

| Tier | Use Case |
|------|----------|
| **Slim** (~120 MiB) | APIs, microservices, minimal footprint |
| **Standard** (~250 MiB) | Most apps -- ImageMagick, vips, Node.js (DEFAULT) |
| **Chromium** (~700 MiB) | Browsershot, Dusk, PDF generation |
| **Dev** (~750 MiB) | Chromium + Xdebug, PCOV, SPX for local development |

## When ServerSideUp Might Be Better

- You need Alpine-based images
- You need PHP 8.1 support
- You prefer a larger community with more third-party tutorials
- You are already invested in the S6 Overlay ecosystem
