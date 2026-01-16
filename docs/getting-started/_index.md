---
title: "Getting Started"
description: "Get started with Cbox base images - installation, quickstart guides, and choosing the right tier for your project"
weight: 1
---

# Getting Started with Cbox

New to Cbox? This section will help you get up and running quickly.

## Start Here

1. **[5-Minute Quickstart](quickstart.md)** - Get your first PHP application running in just 5 minutes
2. **[Introduction](introduction.md)** - Learn why Cbox exists and how it compares to alternatives
3. **[Installation](installation.md)** - Detailed installation instructions for all platforms
4. **[Choosing a Variant](choosing-variant.md)** - Slim vs Standard vs Full - which tier is right for you?

## Quick Decision Guide

```
What do you need?
│
├─ PDF generation, browser testing (Browsershot/Dusk)?
│  └─ Full Tier (`8.4-bookworm-full`)
│
├─ Image processing (ImageMagick, vips), Node.js?
│  └─ Standard Tier (`8.4-bookworm`) ✅ DEFAULT
│
└─ Minimal footprint, APIs, microservices?
   └─ Slim Tier (`8.4-bookworm-slim`)
```

## What You'll Learn

- How to run Cbox containers with Docker Compose
- Differences between Slim, Standard, and Full tiers
- When to use multi-service vs single-process containers
- Basic configuration and environment variables

## Prerequisites

- Docker 20.10+ and Docker Compose 2.0+
- Basic understanding of Docker concepts
- A PHP application to containerize (or use our examples)

## Next Steps

Once you've completed the getting started guides:

- **Framework Users**: Check out our [Laravel Guide](../guides/laravel-guide.md), [Symfony Guide](../guides/symfony-guide.md), or [WordPress Guide](../guides/wordpress-guide.md)
- **Customization Needs**: Learn how to [extend images](../advanced/extending-images.md) with custom extensions
- **Production Deployment**: Read our [production deployment](../guides/production-deployment.md) best practices

---

**Questions?** Check our [troubleshooting guides](../troubleshooting/common-issues.md) or [GitHub Discussions](https://github.com/cboxdk/baseimages/discussions).
