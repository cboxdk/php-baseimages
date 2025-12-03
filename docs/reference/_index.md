---
title: "Reference Documentation"
description: "Complete technical reference for PHPeek base images including environment variables, configuration options, and available extensions"
weight: 30
---

# Reference Documentation

Complete technical reference materials for PHPeek base images.

## Available References

### Configuration & Settings

- **[Environment Variables](environment-variables)**
  - Complete list of all environment variables
  - Framework-specific variables
  - PHP, PHP-FPM, and Nginx configuration
  - Default values and examples

- **[Configuration Options](configuration-options)**
  - PHP.ini customization
  - PHP-FPM pool configuration
  - Nginx server blocks and includes
  - Custom configuration patterns

### Image Information

- **[Available Extensions](available-extensions)**
  - Complete list of 40+ pre-installed extensions
  - Extension usage examples
  - Version information by PHP version
  - Enabling/disabling extensions

- **[Available Images](available-images)**
  - All image tags and variants
  - Image sizes and architecture
  - Version support matrix
  - Deprecation notices

### Monitoring & Operations

- **[Health Checks](health-checks)**
  - Built-in health check internals
  - Docker healthcheck configuration
  - Kubernetes liveness/readiness probes
  - Custom health check scripts

### Architecture Decisions

- **[Multi-Service vs Separate](multi-service-vs-separate)**
  - Architecture comparison guide
  - When to use each approach
  - Trade-offs and considerations
  - Migration between approaches

## How to Use This Section

### Quick Lookups

Looking for a specific setting or variable?

- **Environment variable**: Check [Environment Variables](environment-variables)
- **PHP setting**: Check [Configuration Options](configuration-options#php-ini)
- **Extension availability**: Check [Available Extensions](available-extensions)
- **Image tag**: Check [Available Images](available-images)

### Integration Examples

Most reference pages include copy-paste ready examples:

```yaml
services:
  app:
    image: ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.3-alpine
    environment:
      # Reference: docs/reference/environment-variables
      - PHP_MEMORY_LIMIT=256M
      - PHP_MAX_EXECUTION_TIME=60
```

### Cross-References

Reference documentation links to:

- **Guides**: Practical usage in context
- **Advanced Topics**: Deep dives and customization
- **Troubleshooting**: Common issues and solutions

## Contributing to Reference Docs

Found an undocumented variable or option?

1. Check existing issues: [GitHub Issues](https://github.com/gophpeek/baseimages/issues)
2. Submit a pull request with documentation
3. Include example usage and expected behavior

---

**Need more help?** Check the [guides](../guides) for practical examples or [troubleshooting](../troubleshooting/common-issues) for common issues.
