---
title: "Production Deployment Guide"
description: "Deploy Cbox containers to production with security hardening, performance optimization, and zero-downtime deployment strategies"
weight: 14
---

# Production Deployment Guide

Guide for deploying Cbox containers to production environments with security, performance, and reliability.

## Pre-Deployment Checklist

- [ ] **Image tier selected** (see [Choosing Your Image](../getting-started/choosing-your-image))
- [ ] **Environment variables** stored securely (not in git)
- [ ] **Database migrations** tested
- [ ] **SSL certificates** configured
- [ ] **Health checks** configured and tested
- [ ] **Monitoring** set up
- [ ] **Backup strategy** in place
- [ ] **Rollback plan** documented
- [ ] **Security hardening** completed (see [Security Hardening](../advanced/security-hardening))

## Production Environment Variables

### PHP Production Settings

```yaml
services:
  app:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm
    environment:
      # PHP Production
      - PHP_DISPLAY_ERRORS=Off
      - PHP_DISPLAY_STARTUP_ERRORS=Off
      - PHP_LOG_ERRORS=On
      - PHP_ERROR_REPORTING=E_ALL & ~E_DEPRECATED & ~E_STRICT
      - PHP_MEMORY_LIMIT=512M
      - PHP_MAX_EXECUTION_TIME=60

      # OPcache Optimized
      - PHP_OPCACHE_VALIDATE_TIMESTAMPS=0
      - PHP_OPCACHE_MEMORY_CONSUMPTION=256
      - PHP_OPCACHE_MAX_ACCELERATED_FILES=20000

      # PHP-FPM Production
      - PHP_FPM_PM=static
      - PHP_FPM_PM_MAX_CHILDREN=50
      - PHP_FPM_REQUEST_TERMINATE_TIMEOUT=60

      # Laravel Production
      - LARAVEL_SCHEDULER=true
      - LARAVEL_AUTO_OPTIMIZE=true
      - APP_ENV=production
      - APP_DEBUG=false
```

For a complete docker-compose setup with MySQL and Redis, see [Quickstart](../getting-started/quickstart).

### Secrets Management

Never commit `.env` files to git. Add to `.gitignore`:

```
.env
.env.production
.env.*.local
```

For Docker Swarm secrets, Kubernetes secrets, and vault integration, see [Security Hardening](../advanced/security-hardening#secrets-management).

## Performance Optimization

### OPcache Configuration

Disable timestamp validation in production -- files do not change after deployment:

```yaml
environment:
  - PHP_OPCACHE_VALIDATE_TIMESTAMPS=0  # Don't check file changes
  - PHP_OPCACHE_MEMORY_CONSUMPTION=256
  - PHP_OPCACHE_INTERNED_STRINGS_BUFFER=16
  - PHP_OPCACHE_MAX_ACCELERATED_FILES=20000
```

### PHP-FPM Static Process Manager

For predictable traffic, use static process management:

```yaml
environment:
  - PHP_FPM_PM=static
  - PHP_FPM_PM_MAX_CHILDREN=50  # Tune based on available memory
```

Calculate `max_children`:

```
Available RAM for PHP-FPM: 2GB = 2048MB
Average PHP process memory: 50MB
Max children = 2048MB / 50MB = ~40 processes
```

Check actual memory per process:

```bash
docker exec <container> sh -c 'ps aux | grep "php-fpm: pool" | awk "{sum+=\$6} END {print sum/NR/1024 \"MB\"}"'
```

### Nginx Compression

Create `docker/nginx/compression.conf`:

```nginx
gzip on;
gzip_vary on;
gzip_proxied any;
gzip_comp_level 6;
gzip_min_length 256;
gzip_types text/plain text/css text/xml text/javascript
    application/json application/javascript application/xml+rss image/svg+xml;
```

### Static Asset Caching

```nginx
location ~* \.(jpg|jpeg|gif|png|webp|svg|woff|woff2|ttf|css|js|ico|xml)$ {
    expires 365d;
    add_header Cache-Control "public, immutable";
    access_log off;
}
```

## Health Checks

Cbox includes built-in health checks:

```bash
curl http://localhost/health
# {"status":"healthy","php-fpm":"running","nginx":"running"}
```

### Docker Compose Health Check

```yaml
services:
  app:
    healthcheck:
      test: ["CMD", "php-fpm-healthcheck"]
      interval: 10s
      timeout: 3s
      retries: 3
      start_period: 30s
```

### Resource Limits

```yaml
services:
  app:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 4G
        reservations:
          cpus: '1'
          memory: 2G
```

## Logging

### JSON File Driver with Rotation

```yaml
services:
  app:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

### Prometheus Metrics

```yaml
services:
  php-fpm-exporter:
    image: hipages/php-fpm_exporter:latest
    ports:
      - "9253:9253"
    environment:
      - PHP_FPM_SCRAPE_URI=tcp://app:9000/status
```

## Zero-Downtime Deployments

### Rolling Update Strategy

```yaml
services:
  app:
    deploy:
      replicas: 3
      update_config:
        parallelism: 1
        delay: 10s
        failure_action: rollback
        order: start-first
      rollback_config:
        parallelism: 1
        delay: 5s
```

### Deployment Script with Health Check

```bash
#!/bin/bash
set -e

echo "Starting deployment..."

docker-compose pull app

health_check() {
  curl -f http://localhost/health || return 1
}

# Rolling restart
for i in {1..3}; do
  echo "Restarting instance $i..."
  docker-compose up -d --scale app=$((3-i))
  sleep 5

  if ! health_check; then
    echo "Health check failed! Rolling back..."
    docker-compose up -d --scale app=3
    exit 1
  fi

  docker-compose up -d --scale app=3
  echo "Instance $i restarted successfully"
  sleep 10
done

echo "Deployment complete!"
```

### Blue-Green Deployment

```bash
#!/bin/bash
# Deploy to green environment
docker-compose -f docker-compose.green.yml up -d

# Wait for health check
sleep 10
if curl -f http://localhost:8001/health; then
  # Switch load balancer to green, then stop blue
  docker-compose -f docker-compose.blue.yml down
  echo "Switched to green environment"
else
  echo "Health check failed! Keeping blue environment"
  docker-compose -f docker-compose.green.yml down
  exit 1
fi
```

## Kubernetes Deployment

For Kubernetes deployments, use the standard Deployment/Service/HPA pattern with these Cbox-specific settings:

```yaml
containers:
- name: app
  image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm
  env:
  - name: PHP_OPCACHE_VALIDATE_TIMESTAMPS
    value: "0"
  - name: PHP_FPM_PM
    value: "static"
  - name: PHP_FPM_PM_MAX_CHILDREN
    value: "50"
  livenessProbe:
    httpGet:
      path: /health
      port: 80
    initialDelaySeconds: 30
    periodSeconds: 10
  readinessProbe:
    httpGet:
      path: /health
      port: 80
    initialDelaySeconds: 10
    periodSeconds: 5
  resources:
    requests:
      memory: "512Mi"
      cpu: "500m"
    limits:
      memory: "2Gi"
      cpu: "2000m"
```

For complete Kubernetes manifests including Services, PVCs, HPA, and secrets management, see the [Kubernetes documentation](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/).

## Backup & Recovery

### Database Backup

```bash
#!/bin/bash
BACKUP_DIR=/backups
DATE=$(date +%Y%m%d_%H%M%S)

docker exec mysql mysqldump -u root -p${MYSQL_ROOT_PASSWORD} ${DB_DATABASE} \
  | gzip > ${BACKUP_DIR}/db_${DATE}.sql.gz

# Keep only last 7 days
find ${BACKUP_DIR} -name "db_*.sql.gz" -mtime +7 -delete
```

### Automated Backup Schedule

```bash
# /etc/cron.d/cbox-backup
0 2 * * * root /opt/myapp/backup-db.sh >> /var/log/backup.log 2>&1
```

## Production Checklist

### Performance
- [ ] OPcache validation disabled (`PHP_OPCACHE_VALIDATE_TIMESTAMPS=0`)
- [ ] Static process manager configured
- [ ] Gzip compression enabled
- [ ] Static assets cached
- [ ] Load testing completed

### Reliability
- [ ] Health checks configured
- [ ] Auto-restart enabled (`restart: unless-stopped`)
- [ ] Resource limits set
- [ ] Backup automation running
- [ ] Monitoring alerts configured
- [ ] Rollback procedure documented

### Operations
- [ ] CI/CD pipeline tested
- [ ] Zero-downtime deployment verified
- [ ] Log rotation configured
- [ ] On-call procedures documented

## Related Documentation

- [Security Hardening](../advanced/security-hardening) - Detailed security guide
- [Performance Tuning](../advanced/performance-tuning) - Optimization deep dive
- [Environment Variables](../reference/environment-variables) - Configuration reference
- [Health Checks](../reference/health-checks) - Monitoring guide

---

**Questions?** Check [common issues](../troubleshooting/common-issues) or ask in [GitHub Discussions](https://github.com/cboxdk/php-baseimages/discussions).
