---
title: "Health Checks"
description: "Configure Docker, Kubernetes, and custom health checks for PHPeek base images"
weight: 50
---

# Health Checks

PHPeek base images include comprehensive health checking for Docker and Kubernetes environments.

## Built-in Health Check

All PHPeek images include a deep health validation script at `/usr/local/bin/healthcheck.sh`.

### What It Checks

| Check | Description | Failure Impact |
|-------|-------------|----------------|
| **PHP-FPM Process** | Verifies php-fpm master process is running | Container unhealthy |
| **Nginx Process** | Verifies nginx master process is running | Container unhealthy |
| **Port 80** | Tests TCP connection to port 80 | Container unhealthy |
| **Port 9000** | Tests PHP-FPM FastCGI port | Container unhealthy |
| **OPcache Status** | Verifies OPcache is functioning | Warning only |
| **Critical Extensions** | Checks pdo_mysql, redis are loaded | Warning only |
| **Memory Usage** | Reports PHP-FPM memory consumption | Informational |

### Running Manually

```bash
# Execute health check
docker exec myapp /usr/local/bin/healthcheck.sh

# Expected output (healthy):
# ✓ PHP-FPM running
# ✓ Nginx running
# ✓ Port 80 responding
# ✓ Port 9000 responding
# ✓ OPcache enabled
# ✓ Critical extensions loaded
# Memory: 45MB / 512MB
```

## Docker Health Check

### Default Configuration

PHPeek images include a Docker HEALTHCHECK instruction:

```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1
```

| Parameter | Value | Description |
|-----------|-------|-------------|
| `interval` | 30s | Time between health checks |
| `timeout` | 5s | Maximum time for check to complete |
| `start-period` | 10s | Grace period during container startup |
| `retries` | 3 | Failures before marking unhealthy |

### Checking Health Status

```bash
# View container health
docker inspect --format='{{.State.Health.Status}}' myapp
# Output: healthy | unhealthy | starting

# Detailed health history
docker inspect --format='{{json .State.Health}}' myapp | jq

# Watch health checks in real-time
docker events --filter container=myapp --filter event=health_status
```

### Customizing Health Check

Override in docker-compose.yml:

```yaml
services:
  app:
    image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-alpine
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 15s
      timeout: 5s
      retries: 5
      start_period: 30s
```

Or in Dockerfile:

```dockerfile
FROM ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-alpine

# Custom health check
HEALTHCHECK --interval=15s --timeout=10s --retries=5 \
    CMD curl -f http://localhost/health || exit 1
```

### Disabling Health Check

For CI/CD or testing scenarios:

```yaml
services:
  app:
    image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-alpine
    healthcheck:
      disable: true
```

## Kubernetes Health Probes

### Liveness Probe

Determines if container should be restarted:

```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: app
    image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-alpine
    livenessProbe:
      httpGet:
        path: /health
        port: 80
      initialDelaySeconds: 10
      periodSeconds: 30
      timeoutSeconds: 5
      failureThreshold: 3
```

### Readiness Probe

Determines if container should receive traffic:

```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: app
    image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-alpine
    readinessProbe:
      httpGet:
        path: /health
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 10
      timeoutSeconds: 3
      successThreshold: 1
      failureThreshold: 3
```

### Startup Probe

For slow-starting applications:

```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: app
    image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-alpine
    startupProbe:
      httpGet:
        path: /health
        port: 80
      initialDelaySeconds: 0
      periodSeconds: 5
      timeoutSeconds: 3
      failureThreshold: 30  # 30 * 5s = 150s max startup
```

### Complete Kubernetes Configuration

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
      containers:
      - name: app
        image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-alpine
        ports:
        - containerPort: 80

        # Restart if completely stuck
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 30
          timeoutSeconds: 5
          failureThreshold: 3

        # Remove from service if not ready
        readinessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
          timeoutSeconds: 3
          failureThreshold: 3

        # Allow slow startup (migrations, cache warming)
        startupProbe:
          httpGet:
            path: /health
            port: 80
          periodSeconds: 5
          failureThreshold: 60  # 5 minutes max
```

## Application-Level Health Check

### Laravel Health Endpoint

Create a dedicated health route:

```php
// routes/web.php
Route::get('/health', function () {
    try {
        // Check database
        DB::connection()->getPdo();

        // Check Redis
        Redis::ping();

        // Check storage
        Storage::disk('local')->exists('.gitignore');

        return response()->json([
            'status' => 'healthy',
            'timestamp' => now()->toIso8601String(),
        ]);
    } catch (\Exception $e) {
        return response()->json([
            'status' => 'unhealthy',
            'error' => $e->getMessage(),
        ], 503);
    }
});
```

### Symfony Health Endpoint

```php
// src/Controller/HealthController.php
#[Route('/health')]
public function health(
    EntityManagerInterface $em,
    CacheInterface $cache
): JsonResponse {
    try {
        // Check database
        $em->getConnection()->executeQuery('SELECT 1');

        // Check cache
        $cache->get('health_check', fn() => true);

        return new JsonResponse(['status' => 'healthy']);
    } catch (\Exception $e) {
        return new JsonResponse(
            ['status' => 'unhealthy', 'error' => $e->getMessage()],
            Response::HTTP_SERVICE_UNAVAILABLE
        );
    }
}
```

## Nginx Health Endpoint

PHPeek images include a built-in `/health` endpoint in Nginx:

```nginx
# Included in default.conf
location /health {
    access_log off;
    return 200 "healthy\n";
    add_header Content-Type text/plain;
}
```

This endpoint:
- Returns HTTP 200 with "healthy" text
- Does NOT require PHP (fast, low overhead)
- Disabled access logging (reduces noise)

### Custom Nginx Health Check

Override in your custom config:

```nginx
location /health {
    access_log off;

    # Detailed health with PHP
    try_files $uri /health.php;
}
```

## PHPeek PM Health Checks

When using PHPeek Process Manager, additional health checks are available:

### Process Health Checks

```yaml
environment:
  # Enable PHPeek PM
  PHPEEK_PROCESS_MANAGER: phpeek-pm

  # Health check configuration
  PHPEEK_PM_PROCESS_PHP_FPM_HEALTH_CHECK_TYPE: tcp
  PHPEEK_PM_PROCESS_PHP_FPM_HEALTH_CHECK_TARGET: "127.0.0.1:9000"
  PHPEEK_PM_PROCESS_PHP_FPM_HEALTH_CHECK_INTERVAL: 10

  PHPEEK_PM_PROCESS_NGINX_HEALTH_CHECK_TYPE: http
  PHPEEK_PM_PROCESS_NGINX_HEALTH_CHECK_TARGET: "http://127.0.0.1/health"
  PHPEEK_PM_PROCESS_NGINX_HEALTH_CHECK_INTERVAL: 10
```

### Health Check Types

| Type | Target Format | Use Case |
|------|---------------|----------|
| `tcp` | `host:port` | Process listening check |
| `http` | `http://host/path` | HTTP endpoint check |
| `exec` | `/path/to/script` | Custom script check |

### Prometheus Metrics

PHPeek PM exposes health metrics on port 9090:

```bash
# Get health metrics
curl http://localhost:9090/metrics | grep health

# Example output:
# phpeek_pm_health_check_status{process="php-fpm",check_type="tcp"} 1
# phpeek_pm_health_check_status{process="nginx",check_type="http"} 1
```

## Troubleshooting

### Health Check Failing

```bash
# Check what's happening
docker exec myapp /usr/local/bin/healthcheck.sh

# Check process status
docker exec myapp ps aux

# Check logs
docker logs myapp

# Check if ports are listening
docker exec myapp netstat -tlnp
```

### Common Issues

**PHP-FPM not starting:**
```bash
# Check PHP-FPM config
docker exec myapp php-fpm -t

# Check PHP-FPM logs
docker exec myapp cat /var/log/php-fpm/error.log
```

**Nginx not starting:**
```bash
# Check Nginx config
docker exec myapp nginx -t

# Check Nginx logs
docker exec myapp cat /var/log/nginx/error.log
```

**Port not responding:**
```bash
# Check if processes are listening
docker exec myapp ss -tlnp

# Test port internally
docker exec myapp curl -v http://127.0.0.1/health
```

### Health Check Timeouts

If health checks timeout during startup:

```yaml
# Increase start period for slow apps
healthcheck:
  start_period: 60s  # Allow 60s for startup
  interval: 30s
  timeout: 10s
  retries: 3
```

---

**Need more help?** [Common Issues](../troubleshooting/common-issues) | [PHPeek PM Integration](../phpeek-pm-integration)
