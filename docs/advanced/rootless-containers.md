---
title: "Rootless Containers"
description: "Run PHPeek Base Images as non-root containers for OpenShift, Kubernetes Pod Security, and enterprise compliance"
weight: 60
---

# Rootless Containers

Guide for running PHPeek Base Images as non-root containers for enhanced security and compliance.

## Available Image Variants

PHPeek Base Images provide **official rootless variants** for all images:

| Image Type | Root (Default) | Rootless |
|------------|----------------|----------|
| php-base | `8.4-alpine` | `8.4-alpine-rootless` |
| php-cli | `8.4-alpine` | `8.4-alpine-rootless` |
| php-fpm | `8.4-alpine` | `8.4-alpine-rootless` |
| php-fpm-nginx | `8.4-alpine` | `8.4-alpine-rootless` |

All OS variants (Alpine, Bookworm, Trixie) have corresponding rootless versions.

## Quick Start: Using Rootless Images

### Docker

```bash
# Pull rootless image
docker pull ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine-rootless

# Run with port mapping (rootless uses port 8080)
docker run -d -p 80:8080 ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine-rootless
```

### Docker Compose

```yaml
version: '3.8'

services:
  app:
    image: ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine-rootless
    ports:
      - "80:8080"  # Map host 80 to container 8080
    volumes:
      - ./:/var/www/html
    # Optional: Explicitly set user (already set in image)
    user: "82:82"  # www-data UID:GID on Alpine
```

### Kubernetes

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: phpeek-app
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 82        # www-data UID
    runAsGroup: 82       # www-data GID
    fsGroup: 82
    seccompProfile:
      type: RuntimeDefault

  containers:
  - name: app
    image: ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine-rootless
    ports:
    - containerPort: 8080

    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
```

## Security Model Comparison

### Root Images (Default)

- Container starts as root for initialization
- Processes run as www-data after setup
- PUID/PGID mapping supported for host file ownership
- Can bind to privileged ports (80, 443)

### Rootless Images

- Container runs entirely as www-data (UID 82 on Alpine, 33 on Debian)
- No root privileges at any point
- No PUID/PGID mapping (not needed)
- Uses unprivileged port 8080
- `PHPEEK_ROOTLESS=true` environment variable set

## When to Use Rootless

Rootless images are required for:

- **OpenShift** deployments (enforces non-root containers)
- **Kubernetes** with restrictive Pod Security Standards/Policies
- **Enterprise compliance** requirements (PCI-DSS, HIPAA strict environments)
- **Corporate security policies** prohibiting root containers
- **Defense-in-depth** security strategies

## Key Differences

### Port Configuration

| Image Type | HTTP Port | HTTPS Port |
|------------|-----------|------------|
| Root | 80 | 443 |
| Rootless | 8080 | N/A |

Map external ports to 8080:

```yaml
# Docker Compose
ports:
  - "80:8080"

# Kubernetes Service
apiVersion: v1
kind: Service
spec:
  ports:
  - port: 80
    targetPort: 8080
```

### File Permissions

Rootless images require correct file ownership at build time:

```dockerfile
FROM ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine-rootless

# Copy application with correct ownership
COPY --chown=www-data:www-data . /var/www/html

# Pre-create directories with ownership
RUN mkdir -p /var/www/html/storage/logs && \
    chown -R www-data:www-data /var/www/html/storage
```

### PUID/PGID Not Available

The `PUID` and `PGID` environment variables are ignored in rootless mode. The entrypoint automatically skips user mapping when `PHPEEK_ROOTLESS=true`.

## Laravel with Rootless Images

### Build-Time Optimization

Run Laravel optimizations during image build:

```dockerfile
FROM ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine-rootless

COPY --chown=www-data:www-data . /var/www/html

WORKDIR /var/www/html

# Build-time optimization (as www-data)
RUN composer install --no-dev --optimize-autoloader && \
    php artisan config:cache && \
    php artisan route:cache && \
    php artisan view:cache
```

### Migrations with Init Containers

For database migrations, use Kubernetes init containers:

```yaml
initContainers:
- name: laravel-migrate
  image: ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine-rootless
  command: ["/bin/sh", "-c"]
  args:
    - |
      php artisan migrate --force
```

### Storage Configuration

Ensure storage directory is writable:

```yaml
volumeMounts:
- name: app-storage
  mountPath: /var/www/html/storage

volumes:
- name: app-storage
  emptyDir: {}
```

Or with persistent storage:

```yaml
volumes:
- name: app-storage
  persistentVolumeClaim:
    claimName: app-storage
```

## OpenShift Deployment

OpenShift assigns random UIDs. The rootless images are compatible:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: phpeek-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: phpeek
  template:
    metadata:
      labels:
        app: phpeek
    spec:
      securityContext:
        fsGroup: 82

      containers:
      - name: app
        image: ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine-rootless
        ports:
        - containerPort: 8080
          protocol: TCP

        volumeMounts:
        - name: storage
          mountPath: /var/www/html/storage

      volumes:
      - name: storage
        persistentVolumeClaim:
          claimName: app-storage
```

## PHPeek PM with Rootless

PHPeek PM works seamlessly with rootless containers:

```yaml
environment:
  # PHPeek PM is already configured
  PHPEEK_PM_PROCESS_PHP_FPM_ENABLED: "true"
  PHPEEK_PM_PROCESS_NGINX_ENABLED: "true"

  # Queue workers work as-is
  PHPEEK_PM_PROCESS_QUEUE_DEFAULT_ENABLED: "true"

  # Laravel features
  LARAVEL_SCHEDULER: "true"
  LARAVEL_HORIZON: "true"
```

## Testing Rootless Setup

### Verify Non-Root Execution

```bash
# Check container user
docker run --rm ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine-rootless id
# Output: uid=82(www-data) gid=82(www-data)

# Verify PHPEEK_ROOTLESS is set
docker run --rm ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine-rootless \
  printenv PHPEEK_ROOTLESS
# Output: true

# Verify processes
docker run -d --name test ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine-rootless
docker exec test ps aux
# All processes should run as www-data, not root
docker stop test && docker rm test
```

### Security Scanning

```bash
# Scan for vulnerabilities
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine-rootless

# Check user configuration
docker inspect ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine-rootless \
  | jq '.[0].Config.User'
# Should output: "www-data"
```

### Kubernetes Security Test

```bash
# Verify Pod Security Standards compliance
kubectl run test \
  --image=ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine-rootless \
  --dry-run=server -o yaml
```

## Production Checklist

Before deploying rootless containers to production:

- [ ] Using official `-rootless` image tag
- [ ] Application copied with `--chown=www-data:www-data`
- [ ] Storage directories writable by www-data
- [ ] Port mapping configured (host port -> 8080)
- [ ] Health checks updated for port 8080
- [ ] Load balancer/ingress configured for new port
- [ ] Init containers configured for migrations
- [ ] Log paths writable by www-data
- [ ] Storage volumes mounted with correct permissions
- [ ] Security context configured in orchestrator
- [ ] Tested with actual workload
- [ ] Vulnerability scan passed

## Troubleshooting

### Permission Denied Errors

```bash
# Check file ownership
docker exec app ls -la /var/www/html/storage

# Should all be www-data:www-data
# If not, rebuild with correct COPY --chown
```

### Nginx Won't Start

```bash
# Check nginx error logs
docker exec app cat /var/log/nginx/error.log

# Common issue: Verify port configuration
docker exec app cat /etc/nginx/conf.d/default.conf | grep listen
# Should show: listen 8080
```

### Can't Write to Storage

```bash
# Verify www-data can write
docker exec app touch /var/www/html/storage/test.txt

# If fails, check volume mount permissions
# May need fsGroup in Kubernetes
```

### Health Check Failures

The rootless images use port 8080 for health checks:

```bash
# Test health endpoint
curl http://localhost:8080/health
```

Update Kubernetes probes:

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
```

## Building Custom Rootless Images

To build your own rootless image from PHPeek base:

```dockerfile
FROM ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine-rootless

# Copy application (ownership already correct as www-data runs the build)
COPY --chown=www-data:www-data . /var/www/html

WORKDIR /var/www/html

# Install dependencies
RUN composer install --no-dev --optimize-autoloader

# Laravel optimizations
RUN php artisan config:cache && \
    php artisan route:cache && \
    php artisan view:cache
```

Build:

```bash
docker build -t myapp:rootless .
```

## References

- [Docker Security Best Practices](https://docs.docker.com/develop/security-best-practices/)
- [Kubernetes Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [OpenShift Security Context Constraints](https://docs.openshift.com/container-platform/latest/authentication/managing-security-context-constraints.html)
- [Rootless Docker](https://docs.docker.com/engine/security/rootless/)

---

**Need help?** [GitHub Discussions](https://github.com/gophpeek/baseimages/discussions) | [Security Guide](security-hardening.md)
