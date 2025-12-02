---
title: "Installation"
description: "Install PHPeek base images with Docker, Docker Compose, or Kubernetes"
weight: 2
---

# Installation

PHPeek images are available from GitHub Container Registry (ghcr.io). No authentication required for pulling.

## Quick Install

### Docker CLI

```bash
# Pull the recommended image
docker pull ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine

# Verify installation
docker run --rm ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine php -v
```

**Expected output**:
```
PHP 8.4.x (cli) (built: ...)
Copyright (c) The PHP Group
Zend Engine v4.4.x, Copyright (c) Zend Technologies
    with Zend OPcache v8.4.x, Copyright (c), by Zend Technologies
```

### Docker Compose

```yaml
# docker-compose.yml
services:
  app:
    image: ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine
    ports:
      - "8000:80"
    volumes:
      - .:/var/www/html
```

```bash
docker compose up -d
open http://localhost:8000
```

## Available Images

### Multi-Service (Recommended)

PHP-FPM + Nginx in one container. Best for most applications.

```bash
# Alpine (smallest, ~50MB)
ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine

# Debian (glibc, ~120MB)
ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-debian
```

### Development Editions

Include Xdebug and SPX profiler:

```bash
ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine-dev
ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-debian-dev
```

### Single-Process (Microservices)

For Kubernetes or when you need separate scaling:

```bash
# PHP-FPM only
ghcr.io/gophpeek/baseimages/php-fpm:8.4-alpine

# PHP CLI only
ghcr.io/gophpeek/baseimages/php-cli:8.4-alpine

# Nginx only
ghcr.io/gophpeek/baseimages/nginx:alpine
```

## PHP Version Support

| Version | Status | Recommended |
|---------|--------|-------------|
| PHP 8.4 | Active | Yes |
| PHP 8.3 | Active | Yes |
| PHP 8.2 | Active | Legacy support |

```bash
# PHP 8.4 (latest)
ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine

# PHP 8.3
ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.3-alpine

# PHP 8.2
ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.2-alpine
```

## Tagging Strategy

### Rolling Tags (Recommended)

Updated weekly with security patches:

```bash
php-fpm-nginx:8.4-alpine    # Latest 8.4 on Alpine
php-fpm-nginx:8.4-debian    # Latest 8.4 on Debian
```

### Immutable Tags

For reproducible builds:

```bash
php-fpm-nginx:8.4-alpine-sha256:abc123...
```

## Installation Methods

### Method 1: Direct Docker Run

```bash
docker run -d \
  --name myapp \
  -p 8000:80 \
  -v $(pwd):/var/www/html \
  ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine
```

### Method 2: Docker Compose (Recommended)

```yaml
# docker-compose.yml
services:
  app:
    image: ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine
    ports:
      - "8000:80"
    volumes:
      - .:/var/www/html
    environment:
      PHP_MEMORY_LIMIT: 256M
```

### Method 3: Custom Dockerfile

```dockerfile
FROM ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine

# Add custom extensions
RUN apk add --no-cache $PHPIZE_DEPS \
    && pecl install swoole \
    && docker-php-ext-enable swoole \
    && apk del $PHPIZE_DEPS

# Copy application
COPY . /var/www/html
```

### Method 4: Kubernetes

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: app
          image: ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine
          ports:
            - containerPort: 80
          env:
            - name: PHP_MEMORY_LIMIT
              value: "512M"
```

### Method 5: CI/CD Pipeline

**GitHub Actions**:

```yaml
# .github/workflows/deploy.yml
jobs:
  build:
    runs-on: linux-latest  # Use your CI provider's Linux runner
    steps:
      - uses: actions/checkout@v4

      - name: Build image
        run: |
          docker build -t myapp:${{ github.sha }} .

      - name: Push to registry
        run: |
          docker push myapp:${{ github.sha }}
```

**GitLab CI**:

```yaml
# .gitlab-ci.yml
build:
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA .
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
```

## Verify Installation

### Check PHP Version and Extensions

```bash
# PHP version
docker run --rm ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine php -v

# Installed extensions
docker run --rm ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine php -m

# Specific extension
docker run --rm ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine php -m | grep redis
```

### Check Services

```bash
# Start container
docker run -d --name test ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine

# Check processes
docker exec test ps aux

# Check health
docker exec test /usr/local/bin/healthcheck.sh

# Cleanup
docker rm -f test
```

### Test Web Server

```bash
# Create test file
echo '<?php phpinfo();' > index.php

# Run container
docker run -d --name test -p 8000:80 -v $(pwd):/var/www/html/public \
  ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine

# Test
curl http://localhost:8000

# Cleanup
docker rm -f test
rm index.php
```

## Troubleshooting Installation

### Image Not Found

```bash
# Error: manifest unknown
docker pull ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine

# Solution: Check image name spelling
# Correct: php-fpm-nginx (with hyphens)
# Wrong: php_fpm_nginx, phpfpmnginx
```

### Permission Denied

```bash
# Error: permission denied
# Solution: Add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

### Architecture Mismatch

```bash
# Error: no matching manifest for linux/arm64
# Solution: PHPeek supports both architectures
# Check your platform
docker info | grep Architecture

# Force platform if needed
docker pull --platform linux/amd64 ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine
```

## Next Steps

- **[5-Minute Quickstart](quickstart)** - Get a Laravel app running
- **[Choosing a Variant](choosing-variant)** - Alpine vs Debian
- **[Laravel Guide](../guides/laravel-guide)** - Complete Laravel setup
