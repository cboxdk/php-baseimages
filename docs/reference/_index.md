---
title: "Reference Documentation"
description: "Complete technical reference for Cbox base images including image tiers, environment variables, and available extensions"
weight: 30
---

# Reference Documentation

Complete technical reference materials for Cbox base images.

## Image Tiers

Cbox images come in three tiers:

| Tier | Tag Suffix | Size | Best For |
|------|------------|------|----------|
| **Slim** | `-slim` | ~120MB | APIs, microservices |
| **Standard** | (none) | ~250MB | Most apps (DEFAULT) |
| **Full** | `-full` | ~700MB | Browsershot, Dusk, PDF |

## Available References

### Image Information

- **[Image Tiers Comparison](editions-comparison.md)**
  - Slim vs Standard vs Full comparison
  - Extension differences by tier
  - Use case recommendations
  - Migration between tiers

- **[Available Images](available-images.md)**
  - All image tags and variants
  - Image sizes and architecture
  - Version support matrix
  - Rootless variants

- **[Tagging Strategy](tagging-strategy.md)**
  - Tag format and naming conventions
  - Rolling vs immutable tags
  - Deprecation policy

### Configuration & Settings

- **[Environment Variables](environment-variables.md)**
  - Complete list of all environment variables
  - Framework-specific variables
  - PHP, PHP-FPM, and Nginx configuration
  - Default values and examples

- **[Configuration Options](configuration-options.md)**
  - PHP.ini customization
  - PHP-FPM pool configuration
  - Nginx server blocks and includes
  - Custom configuration patterns

- **[Available Extensions](available-extensions.md)**
  - Extensions by tier (Slim/Standard/Full)
  - Extension usage examples
  - Version information
  - Adding custom extensions

### Monitoring & Operations

- **[Health Checks](health-checks.md)**
  - Built-in health check internals
  - Docker healthcheck configuration
  - Kubernetes liveness/readiness probes
  - Custom health check scripts

### Architecture Decisions

- **[Multi-Service vs Separate](multi-service-vs-separate.md)**
  - Architecture comparison guide
  - When to use each approach
  - Trade-offs and considerations
  - Migration between approaches

## Quick Tier Selection

```yaml
# Standard tier (DEFAULT) - Most Laravel/PHP apps
image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm

# Slim tier - APIs, microservices
image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm-slim

# Full tier - Browsershot, Dusk, PDF generation
image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm-full

# Rootless variants (add -rootless suffix)
image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm-rootless
```

## How to Use This Section

### Quick Lookups

Looking for a specific setting or variable?

- **Image tier**: Check [Image Tiers Comparison](editions-comparison.md)
- **Environment variable**: Check [Environment Variables](environment-variables.md)
- **PHP setting**: Check [Configuration Options](configuration-options.md#php-ini)
- **Extension availability**: Check [Available Extensions](available-extensions.md)
- **Image tag**: Check [Available Images](available-images.md)

### Integration Examples

Most reference pages include copy-paste ready examples:

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm
    environment:
      # Reference: docs/reference/environment-variables.md
      PHP_MEMORY_LIMIT: "512M"
      PHP_MAX_EXECUTION_TIME: "60"
```

### Cross-References

Reference documentation links to:

- **Guides**: Practical usage in context
- **Advanced Topics**: Deep dives and customization
- **Troubleshooting**: Common issues and solutions

## Contributing to Reference Docs

Found an undocumented variable or option?

1. Check existing issues: [GitHub Issues](https://github.com/cboxdk/baseimages/issues)
2. Submit a pull request with documentation
3. Include example usage and expected behavior

---

**Need more help?** Check the [guides](../guides/_index.md) for practical examples or [troubleshooting](../troubleshooting/common-issues.md) for common issues.
