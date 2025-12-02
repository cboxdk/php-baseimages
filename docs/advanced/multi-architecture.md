---
title: "Multi-Architecture Builds"
description: "Build and deploy PHPeek images for AMD64 and ARM64 platforms including Apple Silicon and AWS Graviton"
weight: 50
---

# Multi-Architecture Builds

Guide for building and deploying PHPeek images across AMD64 (x86_64) and ARM64 (aarch64) platforms.

## Platform Support

PHPeek Base Images are built for both architectures:

| Platform | Architecture | Examples |
|----------|--------------|----------|
| **AMD64** | x86_64 | Intel/AMD servers, most cloud VMs |
| **ARM64** | aarch64 | Apple Silicon (M1/M2/M3), AWS Graviton, Raspberry Pi 4+ |

## Quick Start

### Pull Multi-Arch Images

Docker automatically selects the correct architecture:

```bash
# Works on both AMD64 and ARM64
docker pull ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine
```

### Build Multi-Platform Images

Use Docker Buildx for multi-architecture builds:

```bash
# Create builder instance (one-time setup)
docker buildx create --name multiarch --driver docker-container --use

# Build for both platforms
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t myapp:latest \
  --push .
```

## ARM64 Optimization

### Apple Silicon (M1/M2/M3) Development

PHPeek images run natively on Apple Silicon without emulation:

```yaml
# docker-compose.yml for Apple Silicon
version: '3.8'

services:
  app:
    image: ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine
    platform: linux/arm64  # Native ARM64
    ports:
      - "8000:80"
    volumes:
      - ./:/var/www/html
```

**Performance tip:** Native ARM64 images are 2-3x faster than emulated AMD64 on Apple Silicon.

### AWS Graviton Deployment

For cost-effective AWS deployments on Graviton instances:

```yaml
# ECS Task Definition
{
  "family": "phpeek-app",
  "runtimePlatform": {
    "cpuArchitecture": "ARM64",
    "operatingSystemFamily": "LINUX"
  },
  "containerDefinitions": [
    {
      "name": "app",
      "image": "ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine",
      "portMappings": [
        { "containerPort": 80, "protocol": "tcp" }
      ]
    }
  ]
}
```

**Cost savings:** Graviton instances typically offer 20-40% better price/performance.

## Building Custom Multi-Arch Images

### Using Dockerfile.production Template

The production template supports multi-architecture builds out of the box:

```bash
# Build and push multi-platform image
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --target production \
  -t ghcr.io/yourorg/myapp:latest \
  -f templates/Dockerfile.production \
  --push .
```

### CI/CD Multi-Platform Builds

#### GitHub Actions

```yaml
name: Build Multi-Platform

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: linux-latest  # Use your CI provider's Linux runner
    steps:
      - uses: actions/checkout@v4

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          platforms: linux/amd64,linux/arm64
          push: true
          tags: ghcr.io/${{ github.repository }}:latest
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

#### GitLab CI

```yaml
build:
  stage: build
  image: docker:24
  services:
    - docker:24-dind
  variables:
    DOCKER_BUILDKIT: 1
  before_script:
    - docker buildx create --use
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
  script:
    - docker buildx build
        --platform linux/amd64,linux/arm64
        --push
        -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
        -t $CI_REGISTRY_IMAGE:latest .
```

## Architecture-Specific Considerations

### Extension Compatibility

All PHPeek extensions are available on both architectures:

| Extension | AMD64 | ARM64 | Notes |
|-----------|-------|-------|-------|
| OPcache | Built-in | |||
| Redis | PECL | |||
| APCu | PECL | |||
| ImageMagick | System package | |||
| GD | Built-in | |||
| Xdebug | PECL | |||

### Performance Differences

| Workload | AMD64 | ARM64 | Winner |
|----------|-------|-------|--------|
| PHP Execution | Baseline | ~5-15% faster | ARM64 |
| String Operations | Baseline | Similar | Tie |
| JSON Processing | Baseline | ~10% faster | ARM64 |
| Image Processing | Baseline | Similar | Tie |
| Memory Efficiency | Baseline | ~10-20% better | ARM64 |

### Image Sizes

| Image | AMD64 | ARM64 | Difference |
|-------|-------|-------|------------|
| php-fpm-nginx:8.4-alpine | ~70MB | ~68MB | ARM64 slightly smaller |
| php-fpm-nginx:8.4-debian | ~150MB | ~145MB | ARM64 slightly smaller |
| php-fpm-nginx:8.4-alpine-dev | ~180MB | ~175MB | ARM64 slightly smaller |

## Troubleshooting

### Emulation Performance Issues

If you see slow performance on Apple Silicon:

```bash
# Check if running under emulation
docker run --rm ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine uname -m
# Should output: aarch64 (not x86_64)
```

**Fix:** Ensure you're pulling ARM64 images:

```bash
# Force ARM64 architecture
docker pull --platform linux/arm64 ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine
```

### Build Failures on ARM64

Some PECL extensions may need source compilation on ARM64:

```dockerfile
# Example: Building custom extension for ARM64
FROM ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine

# Ensure build tools are available
RUN apk add --no-cache $PHPIZE_DEPS

# Install extension from source
RUN pecl install some-extension && \
    docker-php-ext-enable some-extension && \
    apk del $PHPIZE_DEPS
```

### Cross-Platform Testing

Test your image on both architectures locally:

```bash
# Test AMD64 build (on ARM64 machine)
docker run --platform linux/amd64 --rm myapp:latest php -v

# Test ARM64 build (on AMD64 machine)
docker run --platform linux/arm64 --rm myapp:latest php -v
```

## Best Practices

### 1. Use Multi-Platform Manifests

Always build and push multi-platform images:

```bash
# Build manifest with both architectures
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t myapp:v1.0.0 \
  --push .
```

### 2. Pin Architecture When Needed

For reproducibility in production:

```yaml
# docker-compose.prod.yml
services:
  app:
    image: ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine
    platform: linux/amd64  # Pin to specific architecture
```

### 3. Cache Multi-Platform Builds

Use registry caching for faster CI builds:

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --cache-from type=registry,ref=myapp:cache \
  --cache-to type=registry,ref=myapp:cache,mode=max \
  -t myapp:latest \
  --push .
```

### 4. Test on Target Architecture

Always test on the deployment architecture:

```yaml
# GitHub Actions: Test on ARM64 runner
jobs:
  test-arm64:
    runs-on: linux-arm64  # Use your CI provider's ARM64 runner
    steps:
      - uses: actions/checkout@v4
      - name: Test
        run: docker run --rm myapp:latest php artisan test
```

## Kubernetes Multi-Architecture

### Mixed Architecture Clusters

For clusters with both AMD64 and ARM64 nodes:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: phpeek-app
spec:
  template:
    spec:
      # Allow scheduling on any architecture
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: kubernetes.io/arch
                    operator: In
                    values:
                      - amd64
                      - arm64
      containers:
        - name: app
          image: ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine
```

### Architecture-Specific Scheduling

For workloads that perform better on specific architectures:

```yaml
# Schedule on ARM64 nodes for cost optimization
spec:
  nodeSelector:
    kubernetes.io/arch: arm64
```

## References

- [Docker Buildx Documentation](https://docs.docker.com/buildx/working-with-buildx/)
- [AWS Graviton Getting Started](https://aws.amazon.com/ec2/graviton/)
- [Apple Silicon Docker Guide](https://docs.docker.com/desktop/mac/apple-silicon/)
- [Kubernetes Multi-Architecture](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#writing-a-deployment-spec)

---

**Need help?** [GitHub Discussions](https://github.com/phpeek/baseimages/discussions) | [Performance Tuning](performance-tuning.md)
