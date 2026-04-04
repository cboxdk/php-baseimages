---
title: "Frequently Asked Questions"
description: "Common questions and answers about Cbox PHP Base Images, troubleshooting, and best practices"
weight: 10
---

# Frequently Asked Questions

## General Questions

### What is Cbox PHP Base Images?

Production-ready PHP Docker containers with 25+ extensions pre-installed, three tiers (Slim/Standard/Chromium), framework auto-detection, and Cbox Init process management. See the [Introduction](introduction) for details.

### Which image should I use?

See [Choosing Your Image](choosing-your-image) for the full decision matrix with image sizes, tier comparisons, and root vs rootless guidance.

## Installation & Setup

### How do I get started quickly?

See the [5-Minute Quickstart](quickstart) for a step-by-step guide with docker-compose.

### How do I use the development image with Xdebug?

See the [Development Workflow](../guides/development-workflow) guide for Xdebug setup with VS Code and PhpStorm.

### What PHP extensions are included?

See [Available Extensions](../reference/available-extensions) for the complete list by tier. Run `php -m` inside a container to see all enabled extensions.

## Configuration

### How do I customize PHP or Nginx settings?

Use environment variables at runtime or a custom config file at build time. See [Configuration Options](../reference/configuration-options) and [Environment Variables](../reference/environment-variables) for the full reference.

### How do I enable the Laravel scheduler?

```yaml
environment:
  LARAVEL_SCHEDULER: "true"
```

This automatically sets up cron to run `php artisan schedule:run` every minute. See the [Laravel Guide](../guides/laravel-guide) for all Laravel-specific features.

## Performance

### What performance optimizations are included?

OPcache with JIT, realpath cache, Nginx open file cache, gzip compression, and production-tuned PHP-FPM pools are all configured out of the box. See [Performance Tuning](../advanced/performance-tuning) for details and customization.

### Why is my container slow on first request?

First requests trigger OPcache warming and framework bootstrapping. Enable warm-up in production:
```yaml
environment:
  LARAVEL_AUTO_OPTIMIZE: "true"  # Runs optimize on startup
```

## Security

### What security features are included?

HTTP security headers, hidden file blocking, PHP execution prevention in upload directories, and ImageMagick policy hardening are all configured by default. See [Security Hardening](../advanced/security-hardening) for the full list and customization options.

### Is the /health endpoint secure?

Yes. The `/health` endpoint is restricted to localhost only, so it works for Docker and Kubernetes health checks but is not publicly accessible. See [Health Checks](../reference/health-checks) for details.

## Troubleshooting

For detailed troubleshooting, see [Common Issues](../troubleshooting/common-issues) and the [Debugging Guide](../troubleshooting/debugging-guide).

## Updates & Maintenance

### How often are images updated?

- **Weekly security rebuilds** every Monday at 03:00 UTC
- **PHP version updates** within 48 hours of release
- **Extension updates** as needed

### How do I update my images?

```bash
# Pull latest
docker pull ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm

# Rebuild your image
docker-compose build --pull

# Restart containers
docker-compose up -d
```

### How do I pin to a specific version?

Use SHA-based tags for reproducibility:
```yaml
image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm@sha256:abc123...
```

Rolling tags (`8.4-bookworm`) get weekly security updates automatically.

## Migration

### Migrating from serversideup images?

**Key differences**:
1. No S6 Overlay - services managed by bash entrypoint
2. Different environment variable names (check docs)
3. Config paths may differ

**Migration steps**:
1. Update `image:` in docker-compose.yml
2. Review environment variables
3. Test locally before production

### Migrating from official PHP images?

Cbox includes everything from official images plus:
- 40+ extensions pre-installed
- Nginx bundled (multi-service)
- Framework auto-detection
- Production optimizations

**Simply change your `FROM` line**:
```dockerfile
# Before
FROM php:8.4-fpm-bookworm

# After
FROM ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm
```

## Getting Help

### Where can I report issues?

GitHub Issues: [github.com/cboxdk/php-baseimages/issues](https://github.com/cboxdk/php-baseimages/issues)

### How do I contribute?

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

See [Contributing Guide](../contributing.md) for details.
