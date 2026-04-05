---
title: "Cbox PHP Base Images"
description: "Production-ready PHP Docker containers with Cbox Init process manager"
weight: 1
---

## Start Here

1. **[5-Minute Quickstart](getting-started/quickstart)** -- Get running in 5 minutes
2. **[Choosing Your Image](getting-started/choosing-your-image)** -- Tiers, sizes, and when to use each
3. **[Laravel Guide](guides/laravel-guide)** -- Full Laravel setup (most popular)

## Image Tiers

| Tier | Tag Suffix | Size | Best For |
|------|------------|------|----------|
| **Slim** | `-slim` | ~120 MiB | APIs, microservices |
| **Standard** | *(none)* | ~250 MiB | Most apps (default) |
| **Chromium** | `-chromium` | ~700 MiB | Browsershot, Dusk, PDF |
| **Dev** | `-dev` | ~750 MiB | Chromium + Xdebug, PCOV, SPX |

```yaml
# Standard (default) -- most Laravel/PHP apps
image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm

# Slim -- APIs, microservices
image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-slim

# Chromium -- Browsershot, Dusk, PDF generation
image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-chromium
```

## Documentation

### Getting Started

- [Introduction](getting-started/introduction) -- Why Cbox? Comparisons
- [Installation](getting-started/installation) -- All installation methods
- [Choosing Your Image](getting-started/choosing-your-image) -- Tiers, root vs rootless, single vs multi-service

### Framework Guides

- [Laravel Guide](guides/laravel-guide) -- Full setup with MySQL, Redis, Scheduler
- [Symfony Guide](guides/symfony-guide) -- Complete Symfony setup
- [WordPress Guide](guides/wordpress-guide) -- WordPress with MySQL
- [Development Workflow](guides/development-workflow) -- Xdebug, hot-reload, debugging
- [Production Deployment](guides/production-deployment) -- Security, performance, CI/CD

### Operations

- [Extending Images](advanced/extending-images) -- Custom extensions and packages
- [Performance Tuning](advanced/performance-tuning) -- PHP-FPM, OPcache, Nginx
- [Security Hardening](advanced/security-hardening) -- CVE management, secrets

### Reference

- [Quick Reference](reference/quick-reference) -- Copy-paste snippets
- [Environment Variables](reference/environment-variables) -- Complete env var list
- [Configuration Options](reference/configuration-options) -- PHP, FPM, Nginx settings
- [Available Extensions](reference/available-extensions) -- 40+ extensions by tier
- [Health Checks](reference/health-checks) -- Monitoring and probes

### Help

- [Common Issues](troubleshooting/common-issues) -- FAQ-style solutions
- [Debugging Guide](troubleshooting/debugging-guide) -- Systematic debugging
- [Migration Guide](troubleshooting/migration-guide) -- From ServerSideUp, Bitnami, custom images
- [Changelog](changelog) -- What's new
