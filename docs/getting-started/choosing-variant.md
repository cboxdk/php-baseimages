---
title: "Choosing a Variant"
description: "Alpine vs Debian - which OS variant and edition to use for your PHP application"
weight: 4
---

# Choosing a Variant

PHPeek offers two OS variants and multiple editions. This guide helps you choose the right combination.

## Quick Decision Matrix

| Use Case | Recommended Variant |
|----------|---------------------|
| Production (default) | `8.4-alpine` |
| Need glibc compatibility | `8.4-debian` |
| Local development | `8.4-alpine-dev` |
| Native extensions | `8.4-debian` |

## OS Variants

### Alpine Linux

```bash
ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-alpine
```

**Size**: ~50MB (smallest)

**Pros**:
- Smallest image size
- Fast pull/push times
- Reduced attack surface
- Efficient for Kubernetes

**Cons**:
- Uses musl libc (not glibc)
- Some native extensions may not work
- Different package manager (apk)

**Best for**:
- Production deployments
- Microservices
- Kubernetes clusters
- CI/CD pipelines (fast builds)

**Example**:
```yaml
services:
  app:
    image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-alpine
    # ~50MB, boots in <1 second
```

### Debian (Bookworm)

```bash
ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-debian
```

**Size**: ~120MB

**Pros**:
- Uses glibc (maximum compatibility)
- Native extension support
- Familiar apt package manager
- Stable, well-tested

**Cons**:
- Larger image size
- More packages = larger attack surface

**Best for**:
- Applications requiring glibc
- Native PHP extensions (some PECL)
- Legacy application migration
- When Alpine causes issues

**Example**:
```yaml
services:
  app:
    image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-debian
    # glibc compatibility for all extensions
```

## Editions

### Standard Edition

```bash
ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-alpine
```

**Includes**: 40+ PHP extensions for production

**Best for**: Production deployments

### Development Edition

```bash
ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-alpine-dev
```

**Includes**:
- All standard extensions
- Xdebug 3.x (step debugging, profiling, coverage)
- SPX Profiler (performance analysis)
- Development PHP settings

**Best for**: Local development

**Example**:
```yaml
services:
  app:
    image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-alpine-dev
    environment:
      XDEBUG_MODE: debug,develop,coverage
      XDEBUG_CONFIG: client_host=host.docker.internal client_port=9003
    ports:
      - "8000:80"
      - "9003:9003"  # Xdebug
```

### Minimal Edition

```bash
ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-alpine-minimal
```

**Includes**: Core extensions only (opcache, pdo, json, etc.)

**Best for**:
- Microservices with specific needs
- Maximum security (minimal attack surface)
- When you'll add extensions yourself

## Size Comparison

| Variant | Standard | Dev | Minimal |
|---------|----------|-----|---------|
| Alpine | ~50MB | ~80MB | ~30MB |
| Debian | ~120MB | ~150MB | ~80MB |

## Decision Flowchart

```
Start
  |
  v
Need Xdebug/debugging?
  |
  +-- Yes --> Use -dev edition
  |
  +-- No --> Continue
        |
        v
    Need glibc compatibility?
    (Native extensions, Oracle, etc.)
        |
        +-- Yes --> Debian
        |
        +-- No --> Alpine (recommended)
```

## Common Scenarios

### Scenario 1: New Laravel Project

```yaml
# Development
services:
  app:
    image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-alpine-dev

# Production
services:
  app:
    image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-alpine
```

### Scenario 2: Legacy PHP Application

```yaml
# Debian for maximum compatibility
services:
  app:
    image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-debian
```

### Scenario 3: Kubernetes Microservices

```yaml
# Alpine for smallest footprint
spec:
  containers:
    - image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-alpine
```

## When Alpine Doesn't Work

Alpine uses musl libc instead of glibc. Some scenarios where you need Debian:

### Oracle Database (oci8)

```dockerfile
# oci8 requires glibc - use Debian
FROM ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-debian

RUN apt-get update && apt-get install -y libaio1 \
    && pecl install oci8
```

### Microsoft SQL Server (sqlsrv)

```dockerfile
# sqlsrv works better with glibc
FROM ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-debian

RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
    && curl https://packages.microsoft.com/config/debian/12/prod.list > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install -y msodbcsql18 unixodbc-dev \
    && pecl install sqlsrv pdo_sqlsrv
```

### Custom Native Extensions

```dockerfile
# Some PECL extensions compile better with glibc
FROM ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-debian

# Extensions that may have musl issues
RUN pecl install grpc protobuf
```

## Multi-Stage for Dev/Prod

Use different bases for dev and prod:

```dockerfile
# Development target
FROM ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-alpine-dev AS development
COPY . /var/www/html

# Production target
FROM ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-alpine AS production
COPY --from=development /var/www/html /var/www/html
RUN composer install --no-dev --optimize-autoloader
```

```bash
# Build for development
docker build --target development -t myapp:dev .

# Build for production
docker build --target production -t myapp:prod .
```

## Recommendations Summary

| Situation | Recommendation |
|-----------|----------------|
| Starting new project | `8.4-alpine` |
| Local development | `8.4-alpine-dev` |
| Need specific extension | `8.4-debian` |
| Kubernetes production | `8.4-alpine` |
| CI/CD pipelines | `8.4-alpine` (fast) |
| Legacy migration | `8.3-debian` |
| Maximum security | `8.4-alpine-minimal` |

## Next Steps

- **[5-Minute Quickstart](quickstart)** - Get running immediately
- **[Laravel Guide](../guides/laravel-guide)** - Complete Laravel setup
- **[Extending Images](../advanced/extending-images)** - Add custom extensions
