---
title: "Getting Started"
description: "Get started with Cbox PHP Base Images - installation, quickstart guides, and choosing the right tier for your project"
weight: 10
---

# Getting Started with Cbox

New to Cbox? This section will help you get up and running quickly.

## Start Here

1. **[5-Minute Quickstart](./quickstart)** - Get your first PHP application running in just 5 minutes
2. **[Introduction](./introduction)** - Learn why Cbox exists and how it compares to alternatives
3. **[Installation](./installation)** - Detailed installation instructions for all platforms
4. **[Choosing Your Image](./choosing-your-image)** - Tiers, sizes, root vs rootless, single vs multi-service

## Quick Decision Guide

```
What do you need?
│
├─ Local development with Xdebug, PCOV, SPX?
│  └─ Dev Tier (`8.4-bookworm-dev`)
│
├─ PDF generation, browser testing (Browsershot/Dusk)?
│  └─ Chromium Tier (`8.4-bookworm-chromium`)
│
├─ Image processing (ImageMagick, vips), Node.js?
│  └─ Standard Tier (`8.4-bookworm`) ✅ DEFAULT
│
└─ Minimal footprint, APIs, microservices?
   └─ Slim Tier (`8.4-bookworm-slim`)
```

## What You'll Learn

- How to run Cbox containers with Docker Compose
- Differences between Slim, Standard, Chromium, and Dev tiers
- When to use multi-service vs single-process containers
- Basic configuration and environment variables

## Prerequisites

- Docker 20.10+ and Docker Compose 2.0+
- Basic understanding of Docker concepts
- A PHP application to containerize (or use our examples)

## Next Steps

Once you've completed the getting started guides:

- **Framework Users**: Check out our [Laravel Guide](../guides/laravel-guide), [Symfony Guide](../guides/symfony-guide), or [WordPress Guide](../guides/wordpress-guide)
- **Customization Needs**: Learn how to [extend images](../advanced/extending-images) with custom extensions
- **Production Deployment**: Read our [production deployment](../guides/production-deployment) best practices

---

**Questions?** Check our [troubleshooting guides](../troubleshooting/common-issues) or [GitHub Discussions](https://github.com/cboxdk/php-baseimages/discussions).
