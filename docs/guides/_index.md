---
title: "Framework Guides"
description: "Complete setup guides for Laravel, Symfony, WordPress, and other popular PHP frameworks using Cbox base images"
weight: 10
---

# Framework & Workflow Guides

Step-by-step guides for popular PHP frameworks and development workflows.

## Available Guides

### Framework-Specific Guides

- **[Laravel Complete Guide](laravel-guide.md)** ⭐ Most Popular
  - Full Laravel setup with MySQL, Redis, and Scheduler
  - Development environment with Xdebug and MailHog
  - Production deployment configuration
  - Common mistakes and solutions

- **[Symfony Complete Guide](symfony-guide.md)**
  - Complete Symfony setup with PostgreSQL and Redis
  - Cache pools and session configuration
  - Doctrine migrations and database management
  - Production optimization

- **[WordPress Complete Guide](wordpress-guide.md)**
  - WordPress installation with MySQL
  - WP-CLI usage and plugin development
  - Redis Object Cache setup
  - Production deployment and optimization

- **[Magento Guide](magento-guide.md)** ✨ New
  - MySQL, Redis, and OpenSearch stack
  - Cron and queue configuration
  - Production storage layout

- **[Drupal Guide](drupal-guide.md)** ✨ New
  - PostgreSQL or MySQL setup
  - Redis cache + Drush cron
  - File storage best practices

- **[TYPO3 Guide](typo3-guide.md)** ✨ New
  - Composer-based install flow
  - Redis caching + scheduler
  - Persistent volumes for fileadmin

- **[Statamic Guide](statamic-guide.md)** ✨ New
  - Laravel-based Statamic stack
  - Queue + scheduler toggles
  - Asset + Glide configuration

### High-Performance (Laravel Octane)

- **[Laravel Octane Guide](laravel-octane.md)** ⚡ Performance
  - Swoole, RoadRunner, and FrankenPHP comparison
  - Complete configuration reference
  - Production considerations

- **[Swoole Guide](swoole-guide.md)**
  - Maximum performance with coroutines
  - Task workers for background processing
  - Memory management and scaling

- **[FrankenPHP Guide](frankenphp-guide.md)**
  - Automatic HTTPS with Let's Encrypt
  - HTTP/3 and Early Hints support
  - Caddy integration and custom Caddyfile

### Workflow Guides

- **[Development Workflow](development-workflow.md)**
  - Local development with hot-reload
  - Xdebug setup and debugging tips
  - Testing and quality assurance
  - Git workflow integration

- **[Image Processing Guide](image-processing.md)** 🖼️ New
  - GD, ImageMagick, and libvips comparison
  - HEIC/HEIF conversion (iPhone photos)
  - PDF generation and SVG rendering
  - Browsershot setup for screenshots/PDFs
  - Laravel integration (Intervention, Spatie Media)

- **[Production Deployment](production-deployment.md)**
  - Security hardening checklist
  - Performance optimization
  - Monitoring and logging
  - CI/CD integration
  - Zero-downtime deployments

- **[Cbox vs ServerSideUp](cbox-vs-serversideup.md)** ✨ New
  - DX, docs, and feature scorecard
  - Actionable follow-ups to widen the gap
  - Talking points for stakeholders

- **[Health Checks & CI Templates](healthchecks-ci.md)** ✨ New
  - Docker Compose health-check override file
  - GitHub Actions workflow for `php artisan test`
  - Deployment-ready verification checklist

## What You'll Learn

- Complete framework setup from scratch
- Database and caching configuration
- Development and production environments
- Image processing with GD, ImageMagick, libvips
- Common mistakes and how to avoid them
- Testing and debugging strategies
- Deployment best practices

## Prerequisites

Before starting these guides, you should:

1. Complete the [5-Minute Quickstart](../getting-started/quickstart.md)
2. Have Docker and Docker Compose installed
3. Have your framework application ready (or create a new one)

## Common Patterns

All framework guides follow these principles:

- **Copy-paste ready examples** - All code works without modification
- **Progressive complexity** - Start simple, add features incrementally
- **Real explanations** - Understand WHY, not just WHAT
- **Expected output** - See what success looks like
- **Inline troubleshooting** - Common mistakes with solutions
- **Production ready** - Configuration suitable for real deployments

## Need Help?

- **Quick answers**: Check [Common Issues](../troubleshooting/common-issues.md)
- **Debugging**: Use our [Debugging Guide](../troubleshooting/debugging-guide.md)
- **Migration**: See our [Migration Guide](../troubleshooting/migration-guide.md)
- **Community**: Join [GitHub Discussions](https://github.com/cboxdk/baseimages/discussions)

---

**Can't find your framework?** Check the [Community Guides](https://github.com/cboxdk/baseimages/discussions/categories/guides) or create one and share it!
