---
title: "Advanced Topics"
description: "Deep dives into customization, extensions, performance tuning, and security hardening for PHPeek base images"
weight: 20
---

# Advanced Topics

Deep dives for experienced users who need to customize and optimize PHPeek images for their specific requirements.

## Available Topics

### Customization

- **[Extending Images](extending-images)** ⭐ Most Requested
  - Add custom PHP extensions (PECL and compiled)
  - Install system packages
  - Custom PHP and Nginx configuration
  - Multi-stage builds for dev/prod separation
  - Custom initialization scripts

- **[Custom Extensions](custom-extensions)** - Complete Guide
  - PECL extension installation examples
  - Compiling extensions from source
  - Version pinning strategies
  - Extension configuration best practices

- **[Custom Initialization](custom-initialization)** - Complete Guide
  - Startup script patterns
  - Wait-for-dependency scripts
  - Database migration automation
  - Dynamic configuration generation

### Performance & Optimization

- **[Performance Tuning](performance-tuning)**
  - PHP-FPM pool optimization
  - OPcache configuration tuning
  - Nginx performance settings
  - Memory and resource optimization
  - Benchmarking and profiling

### Security

- **[Reverse Proxy & mTLS](reverse-proxy-mtls)** - Production Critical
  - Cloudflare, HAProxy, Traefik, Nginx, Fastly configuration
  - Tailscale, Cloudflare Tunnel, VPN support
  - mTLS client certificate authentication
  - Zero-trust network integration (Istio, service mesh)

- **[Security Hardening](security-hardening)**
  - Security best practices checklist
  - CVE management and patching strategy
  - Secrets management (environment variables, Docker secrets)
  - User permissions and file ownership
  - Network security and isolation

- **[Rootless Containers](rootless-containers)**
  - Running containers as non-root
  - OpenShift and Kubernetes Pod Security Standards
  - Enterprise compliance (PCI-DSS, HIPAA)

### Platform & Architecture

- **[Multi-Architecture Builds](multi-architecture)** 🆕
  - AMD64 and ARM64 support
  - Apple Silicon (M1/M2/M3) development
  - AWS Graviton deployment optimization
  - Multi-platform Docker Buildx workflows
  - CI/CD for multi-architecture images

### Development & Testing

- **[Testing Guide](testing-guide)** 🆕
  - E2E test scenarios (Laravel, Symfony, WordPress)
  - Matrix testing across PHP versions and OS variants
  - Writing custom tests with fixtures
  - Test utilities and assertions
  - CI/CD integration

## What You'll Learn

- How to create custom Docker images based on PHPeek
- Advanced PHP and Nginx configuration techniques
- Performance optimization strategies
- Security hardening for production deployments
- Troubleshooting complex issues

## Prerequisites

Before diving into advanced topics:

1. Comfortable with Docker and Dockerfiles
2. Completed at least one [framework guide](../guides)
3. Running PHPeek in development successfully
4. Basic understanding of PHP-FPM and Nginx

## When to Use Advanced Topics

- **Extending Images**: Need PHP extensions not included by default
- **Custom Extensions**: Building specialized extensions or compiling from source
- **Custom Initialization**: Complex startup requirements or migrations
- **Performance Tuning**: Optimizing for high-traffic production workloads
- **Security Hardening**: Preparing for production deployment

## Best Practices

### Testing Custom Images

Always test custom images locally before deploying:

```bash
# Build custom image
docker build -f Dockerfile.custom -t my-app:dev .

# Test locally
docker run --rm -p 8000:80 my-app:dev

# Verify extensions
docker run --rm my-app:dev php -m
```

### Version Pinning

Pin specific versions in production:

```dockerfile
# ✅ GOOD: Pin specific versions
RUN pecl install redis-6.0.2

# ❌ BAD: Use latest (unpredictable)
RUN pecl install redis
```

### Documentation

Document all customizations in your repository:

```markdown
# Custom Image Documentation

## Added Extensions
- Redis 6.0.2 (caching)
- MongoDB 1.20.1 (database)

## System Packages
- ffmpeg (video processing)
- node 20.x (asset compilation)

## Configuration
- PHP memory_limit: 256M
- OPcache enabled with validation
```

## Need Help?

- **Quick Answers**: [Common Issues](../troubleshooting/common-issues)
- **Debugging**: [Debugging Guide](../troubleshooting/debugging-guide)
- **Reference**: [Environment Variables](../reference/environment-variables)
- **Community**: [GitHub Discussions](https://github.com/phpeek/baseimages/discussions)

---

**Want to contribute?** Share your customization patterns in [GitHub Discussions](https://github.com/phpeek/baseimages/discussions/categories/show-and-tell)!
