---
title: "Rootless Containers"
description: "Run PHPeek Base Images as non-root containers for OpenShift, Kubernetes Pod Security, and enterprise compliance"
weight: 60
---

# Rootless Containers

Guide for running PHPeek Base Images as non-root containers for enhanced security and compliance.

## Current Security Model

PHPeek images use a **hybrid security approach**:

- ✅ **Container starts as root** - Allows initialization (migrations, caching, file ownership)
- ✅ **Processes run as www-data** - PHP-FPM and Nginx execute as non-root user
- ✅ **Proper file ownership** - Application files owned by www-data

This provides **80% of security benefits** while maintaining ease of use.

## When You Need Rootless

Fully rootless containers (non-root from start) are required for:

- **OpenShift** deployments (enforces non-root containers)
- **Kubernetes** with restrictive Pod Security Standards/Policies
- **Enterprise compliance** requirements (PCI-DSS, HIPAA strict environments)
- **Corporate security policies** prohibiting root containers
- **Defense-in-depth** security strategies

## Rootless Conversion

### Quick Conversion (Alpine)

Create a `Dockerfile.rootless`:

```dockerfile
FROM ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-alpine

# Switch Nginx to unprivileged port
RUN sed -i 's/listen 80/listen 8080/' /etc/nginx/conf.d/default.conf && \
    # Ensure proper ownership
    chown -R www-data:www-data /var/www /var/log/nginx /run/nginx && \
    # Update nginx to run without privileges
    sed -i 's/user nginx;/user www-data;/' /etc/nginx/nginx.conf

# Switch to non-root user
USER www-data:www-data

# Expose unprivileged port
EXPOSE 8080
```

Build and run:

```bash
docker build -f Dockerfile.rootless -t myapp:rootless .
docker run -p 8080:8080 myapp:rootless
```

### Debian/Ubuntu Conversion

```dockerfile
FROM ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-debian

# Configure unprivileged Nginx
RUN sed -i 's/listen 80/listen 8080/' /etc/nginx/conf.d/default.conf && \
    # Ensure ownership
    chown -R www-data:www-data /var/www /var/log/nginx /run/nginx && \
    # PID file location (www-data can write here)
    mkdir -p /tmp/nginx && chown www-data:www-data /tmp/nginx && \
    sed -i 's|pid /run/nginx.pid;|pid /tmp/nginx/nginx.pid;|' /etc/nginx/nginx.conf

USER www-data:www-data
EXPOSE 8080
```

### Docker Compose Configuration

```yaml
version: '3.8'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile.rootless
    ports:
      - "8000:8080"  # Map host 8000 to container 8080
    volumes:
      - ./:/var/www/html
    # Optional: Explicitly set user
    user: "82:82"  # www-data UID:GID
```

## Advanced: Build-Time Rootless

For complete control, modify the base Dockerfile:

```dockerfile
FROM php:8.4-fpm-alpine

# ... (standard installation steps)

# Configure for rootless from the start
RUN mkdir -p /var/www/html /run/nginx /var/log/nginx /tmp/nginx && \
    chown -R www-data:www-data /var/www /run/nginx /var/log/nginx /tmp/nginx

# Copy configurations
COPY --chown=www-data:www-data nginx-rootless.conf /etc/nginx/conf.d/default.conf
COPY --chown=www-data:www-data entrypoint-rootless.sh /entrypoint.sh

# Switch to non-root user
USER www-data:www-data

EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]
```

### Rootless Nginx Configuration

`nginx-rootless.conf`:

```nginx
server {
    listen 8080;
    server_name _;
    root /var/www/html/public;

    index index.php index.html;

    # Error and access logs (www-data writable)
    error_log /var/log/nginx/error.log;
    access_log /var/log/nginx/access.log;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
```

### Rootless Entrypoint

`entrypoint-rootless.sh`:

```bash
#!/bin/bash
set -e

# Can't chown or run root commands
# All initialization must work as www-data

# Start PHP-FPM (background)
php-fpm -D

# Start Nginx (foreground)
exec nginx -g "daemon off;"
```

Make executable:
```bash
chmod +x entrypoint-rootless.sh
```

## Kubernetes Deployment

### Pod Security Standards

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
    image: myapp:rootless
    ports:
    - containerPort: 8080

    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
      readOnlyRootFilesystem: false  # Laravel needs writable storage

    volumeMounts:
    - name: app-storage
      mountPath: /var/www/html/storage
    - name: tmp
      mountPath: /tmp

  volumes:
  - name: app-storage
    emptyDir: {}
  - name: tmp
    emptyDir: {}
```

### OpenShift Deployment

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
      # OpenShift assigns random UID - ensure compatibility
      securityContext:
        fsGroup: 82

      containers:
      - name: app
        image: myapp:rootless
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

## Limitations and Workarounds

### 1. Port Binding

**Issue:** Can't bind to ports < 1024 as non-root.

**Solution:** Use port 8080+ and map externally.

```yaml
# Docker Compose
ports:
  - "80:8080"  # External 80 → Internal 8080

# Kubernetes Service
apiVersion: v1
kind: Service
spec:
  ports:
  - port: 80
    targetPort: 8080
```

### 2. File Permissions

**Issue:** Can't chown files at runtime.

**Solution:** Ensure correct ownership during build.

```dockerfile
# Set ownership during image build
COPY --chown=www-data:www-data . /var/www/html

# Pre-create directories with ownership
RUN mkdir -p /var/www/html/storage/logs && \
    chown -R www-data:www-data /var/www/html/storage
```

### 3. Laravel Initialization

**Issue:** Can't run `artisan` commands requiring root.

**Solution:** Run initialization as build steps or init containers.

```dockerfile
# Build-time optimization
RUN php artisan config:cache && \
    php artisan route:cache && \
    php artisan view:cache
```

Or use Kubernetes init containers:

```yaml
initContainers:
- name: laravel-init
  image: myapp:rootless
  command: ["/bin/sh", "-c"]
  args:
    - |
      php artisan migrate --force
      php artisan config:cache
```

### 4. Log Files

**Issue:** Default log locations may not be writable.

**Solution:** Configure logs to writable locations.

```php
// config/logging.php
'channels' => [
    'single' => [
        'driver' => 'single',
        'path' => env('LOG_CHANNEL_PATH', '/tmp/laravel.log'),
    ],
],
```

## PHPeek PM with Rootless

PHPeek PM works with rootless containers:

```dockerfile
FROM ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-alpine

# PHPeek PM already installed, just configure for rootless
RUN sed -i 's/listen 80/listen 8080/' /etc/nginx/conf.d/default.conf && \
    chown -R www-data:www-data /var/www /var/log /run

USER www-data:www-data
EXPOSE 8080
```

Configuration:

```yaml
environment:
  PHPEEK_PROCESS_MANAGER: phpeek-pm

  # Core processes work as-is
  PHPEEK_PM_PROCESS_PHP_FPM_ENABLED: "true"
  PHPEEK_PM_PROCESS_NGINX_ENABLED: "true"

  # Queue workers (no special config needed)
  PHPEEK_PM_PROCESS_QUEUE_DEFAULT_ENABLED: "true"
```

## Testing Rootless Setup

### Verify Non-Root Execution

```bash
# Check container user
docker run --rm myapp:rootless id
# Output: uid=82(www-data) gid=82(www-data)

# Verify processes
docker run -d --name test myapp:rootless
docker exec test ps aux
# All processes should run as www-data, not root
```

### Security Scanning

```bash
# Scan for vulnerabilities
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image myapp:rootless

# Check user configuration
docker inspect myapp:rootless | jq '.[0].Config.User'
# Should output: "www-data" or "82:82"
```

### Kubernetes Security Test

```bash
# Try to run as root (should fail)
kubectl run test --image=myapp:rootless --dry-run=server
# Should be blocked by Pod Security Standards
```

## Production Checklist

Before deploying rootless containers to production:

- [ ] Nginx configured for port 8080+
- [ ] All directories writable by www-data
- [ ] USER directive set in Dockerfile
- [ ] File ownership correct (www-data:www-data)
- [ ] Health checks updated for new port
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

# Common issue: PID file location
# Ensure nginx.conf uses /tmp/nginx/nginx.pid
```

### Can't Write to Storage

```bash
# Verify www-data can write
docker exec app touch /var/www/html/storage/test.txt

# If fails, check volume mount permissions
# May need fsGroup in Kubernetes
```

## Future: Official Rootless Images

PHPeek may provide official `-rootless` image variants if there's sufficient demand:

```yaml
# Future (not yet available)
image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-alpine-rootless
```

**Want this?** Open a GitHub issue to express interest and describe your use case.

## References

- [Docker Security Best Practices](https://docs.docker.com/develop/security-best-practices/)
- [Kubernetes Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [OpenShift Security Context Constraints](https://docs.openshift.com/container-platform/latest/authentication/managing-security-context-constraints.html)
- [Rootless Docker](https://docs.docker.com/engine/security/rootless/)
- [Bitnami Non-Root Containers](https://docs.bitnami.com/tutorials/work-with-non-root-containers/)

---

**Need help?** [GitHub Discussions](https://github.com/phpeek/baseimages/discussions) | [Security Guide](security-hardening.md)
