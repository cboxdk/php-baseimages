---
title: "Production Deployment Guide"
description: "Deploy PHPeek containers to production with security hardening, performance optimization, and zero-downtime deployment strategies"
weight: 14
---

# Production Deployment Guide

Complete guide for deploying PHPeek containers to production environments with security, performance, and reliability.

## Table of Contents

- [Pre-Deployment Checklist](#pre-deployment-checklist)
- [Security Hardening](#security-hardening)
- [Performance Optimization](#performance-optimization)
- [Docker Compose Production Setup](#docker-compose-production-setup)
- [Kubernetes Deployment](#kubernetes-deployment)
- [CI/CD Integration](#cicd-integration)
- [Monitoring & Logging](#monitoring--logging)
- [Zero-Downtime Deployments](#zero-downtime-deployments)
- [Backup & Recovery](#backup--recovery)

## Pre-Deployment Checklist

Before deploying to production:

- [ ] **Security hardening** completed
- [ ] **Environment variables** stored securely (not in git)
- [ ] **Database migrations** tested
- [ ] **SSL certificates** configured
- [ ] **Health checks** configured
- [ ] **Monitoring** set up
- [ ] **Backup strategy** in place
- [ ] **Rollback plan** documented
- [ ] **Load testing** completed
- [ ] **Documentation** updated

## Security Hardening

### 1. Disable PHP Display Errors

```yaml
services:
  app:
    environment:
      - PHP_DISPLAY_ERRORS=Off
      - PHP_DISPLAY_STARTUP_ERRORS=Off
      - PHP_LOG_ERRORS=On
```

### 2. Use Secrets for Sensitive Data

**Docker Swarm Secrets:**

```yaml
version: '3.8'

services:
  app:
    image: ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.3-alpine
    secrets:
      - app_key
      - db_password
    environment:
      - APP_KEY_FILE=/run/secrets/app_key
      - DB_PASSWORD_FILE=/run/secrets/db_password

secrets:
  app_key:
    external: true
  db_password:
    external: true
```

**Create secrets:**

```bash
echo "your-app-key" | docker secret create app_key -
echo "your-db-password" | docker secret create db_password -
```

### 3. Security Headers (Nginx)

**Create `docker/nginx/security.conf`:**

```nginx
# Security headers
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "no-referrer-when-downgrade" always;
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline';" always;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

# Hide Nginx version
server_tokens off;
```

### 4. Restrict PHP Functions

```ini
; docker/php/production.ini
disable_functions = exec,passthru,shell_exec,system,proc_open,popen,curl_exec,curl_multi_exec,parse_ini_file,show_source
expose_php = Off
allow_url_fopen = Off
allow_url_include = Off
```

### 5. Run as Non-Root User

PHPeek images already run as non-root, but verify:

```bash
docker exec <container> whoami
# Should output: www-data (Debian) or nginx (Alpine)
```

## Performance Optimization

### 1. OPcache Configuration

```yaml
services:
  app:
    environment:
      # OPcache optimized for production
      - PHP_OPCACHE_VALIDATE_TIMESTAMPS=0  # Don't check file changes
      - PHP_OPCACHE_MEMORY_CONSUMPTION=256
      - PHP_OPCACHE_INTERNED_STRINGS_BUFFER=16
      - PHP_OPCACHE_MAX_ACCELERATED_FILES=20000
```

### 2. PHP-FPM Static Process Manager

For predictable traffic:

```yaml
services:
  app:
    environment:
      - PHP_FPM_PM=static
      - PHP_FPM_PM_MAX_CHILDREN=50  # Tune based on available memory
```

**Calculate max_children:**

```
Available RAM for PHP-FPM: 2GB = 2048MB
Average PHP process memory: 50MB
Max children = 2048MB / 50MB = ~40 processes
```

Check actual memory per process:

```bash
docker exec <container> sh -c 'ps aux | grep "php-fpm: pool" | awk "{sum+=\$6} END {print sum/NR/1024 \"MB\"}"'
```

### 3. Enable Gzip Compression

```nginx
# docker/nginx/compression.conf
gzip on;
gzip_vary on;
gzip_proxied any;
gzip_comp_level 6;
gzip_min_length 256;
gzip_types
    text/plain
    text/css
    text/xml
    text/javascript
    application/json
    application/javascript
    application/xml+rss
    image/svg+xml;
```

### 4. Static Asset Caching

```nginx
location ~* \.(jpg|jpeg|gif|png|webp|svg|woff|woff2|ttf|css|js|ico|xml)$ {
    expires 365d;
    add_header Cache-Control "public, immutable";
    access_log off;
}
```

## Docker Compose Production Setup

### Complete Production Stack

```yaml
version: '3.8'

services:
  app:
    image: ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.3-alpine
    restart: unless-stopped
    volumes:
      - ./:/var/www/html:ro  # Read-only for security
      - app-storage:/var/www/html/storage  # Writable storage
      - ./bootstrap/cache:/var/www/html/bootstrap/cache
      - ./docker/php/production.ini:/usr/local/etc/php/conf.d/zz-production.ini:ro
      - ./docker/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
      - ./docker/nginx/ssl:/etc/nginx/ssl:ro
    environment:
      # PHP Production
      - PHP_DISPLAY_ERRORS=Off
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
      - APP_KEY=${APP_KEY}

      # Database
      - DB_HOST=mysql
      - DB_DATABASE=${DB_DATABASE}
      - DB_USERNAME=${DB_USERNAME}
      - DB_PASSWORD=${DB_PASSWORD}

      # Cache
      - CACHE_DRIVER=redis
      - SESSION_DRIVER=redis
      - REDIS_HOST=redis
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "php-fpm-healthcheck"]
      interval: 10s
      timeout: 3s
      retries: 3
      start_period: 30s
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 4G
        reservations:
          cpus: '1'
          memory: 2G
    networks:
      - app-network
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  mysql:
    image: mysql:8.3
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${DB_DATABASE}
      MYSQL_USER: ${DB_USERNAME}
      MYSQL_PASSWORD: ${DB_PASSWORD}
    volumes:
      - mysql-data:/var/lib/mysql
      - ./docker/mysql/my.cnf:/etc/mysql/conf.d/custom.cnf:ro
    command: --default-authentication-plugin=mysql_native_password
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5
    deploy:
      resources:
        limits:
          memory: 2G
    networks:
      - app-network
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    command: redis-server --appendonly yes --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis-data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "--raw", "incr", "ping"]
      interval: 10s
      timeout: 3s
      retries: 5
    deploy:
      resources:
        limits:
          memory: 512M
    networks:
      - app-network
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

volumes:
  app-storage:
    driver: local
  mysql-data:
    driver: local
  redis-data:
    driver: local

networks:
  app-network:
    driver: bridge
```

### Environment Variables (.env)

**Never commit this file to git!**

```bash
# .env.production

# Application
APP_KEY=base64:your-generated-key-here
APP_ENV=production
APP_DEBUG=false
APP_URL=https://example.com

# Database
DB_DATABASE=production_db
DB_USERNAME=production_user
DB_PASSWORD=your-secure-password-here
MYSQL_ROOT_PASSWORD=your-root-password-here

# Redis
REDIS_PASSWORD=your-redis-password-here

# Mail
MAIL_MAILER=smtp
MAIL_HOST=smtp.example.com
MAIL_PORT=587
MAIL_USERNAME=your-mail-username
MAIL_PASSWORD=your-mail-password
MAIL_ENCRYPTION=tls
```

**Add to `.gitignore`:**

```
.env
.env.production
.env.*.local
```

## Kubernetes Deployment

### Deployment Manifest

```yaml
# kubernetes/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: phpeek-app
  namespace: production
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: phpeek-app
  template:
    metadata:
      labels:
        app: phpeek-app
    spec:
      containers:
      - name: app
        image: ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.3-alpine
        ports:
        - containerPort: 80
          name: http
        env:
        - name: APP_ENV
          value: "production"
        - name: APP_KEY
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: app-key
        - name: DB_HOST
          value: "mysql-service"
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secrets
              key: password
        - name: REDIS_HOST
          value: "redis-service"
        - name: PHP_OPCACHE_VALIDATE_TIMESTAMPS
          value: "0"
        - name: PHP_FPM_PM
          value: "static"
        - name: PHP_FPM_PM_MAX_CHILDREN
          value: "50"
        volumeMounts:
        - name: app-storage
          mountPath: /var/www/html/storage
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "2000m"
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 3
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
      volumes:
      - name: app-storage
        persistentVolumeClaim:
          claimName: app-storage-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: phpeek-app-service
  namespace: production
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
  selector:
    app: phpeek-app
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-storage-pvc
  namespace: production
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
```

### Secrets Management

```bash
# Create secrets
kubectl create secret generic app-secrets \
  --from-literal=app-key='base64:your-key-here' \
  --namespace=production

kubectl create secret generic db-secrets \
  --from-literal=password='your-db-password' \
  --namespace=production
```

### Horizontal Pod Autoscaling

```yaml
# kubernetes/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: phpeek-app-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: phpeek-app
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

## CI/CD Integration

### GitHub Actions

```yaml
# .github/workflows/deploy-production.yml
name: Deploy to Production

on:
  push:
    branches:
      - main

jobs:
  test:
    runs-on: linux-latest  # Use your CI provider's Linux runner
    steps:
      - uses: actions/checkout@v4

      - name: Run Tests
        run: |
          docker-compose -f docker-compose.test.yml up --abort-on-container-exit
          docker-compose -f docker-compose.test.yml down

  build:
    needs: test
    runs-on: linux-latest  # Use your CI provider's Linux runner
    steps:
      - uses: actions/checkout@v4

      - name: Build Production Image
        run: |
          docker build -f Dockerfile.prod -t myapp:${{ github.sha }} .

      - name: Push to Registry
        run: |
          echo ${{ secrets.REGISTRY_TOKEN }} | docker login ghcr.io -u ${{ github.actor }} --password-stdin
          docker tag myapp:${{ github.sha }} ghcr.io/myorg/myapp:${{ github.sha }}
          docker tag myapp:${{ github.sha }} ghcr.io/myorg/myapp:latest
          docker push ghcr.io/myorg/myapp:${{ github.sha }}
          docker push ghcr.io/myorg/myapp:latest

  deploy:
    needs: build
    runs-on: linux-latest  # Use your CI provider's Linux runner
    steps:
      - name: Deploy to Production
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.PROD_HOST }}
          username: ${{ secrets.PROD_USER }}
          key: ${{ secrets.PROD_SSH_KEY }}
          script: |
            cd /opt/myapp
            docker pull ghcr.io/myorg/myapp:${{ github.sha }}
            docker-compose up -d
            docker system prune -af
```

### GitLab CI/CD

```yaml
# .gitlab-ci.yml
stages:
  - test
  - build
  - deploy

test:
  stage: test
  script:
    - docker-compose -f docker-compose.test.yml up --abort-on-container-exit
    - docker-compose -f docker-compose.test.yml down

build:
  stage: build
  script:
    - docker build -f Dockerfile.prod -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA .
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
  only:
    - main

deploy_production:
  stage: deploy
  script:
    - ssh $PROD_USER@$PROD_HOST "cd /opt/myapp && docker pull $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA && docker-compose up -d"
  only:
    - main
  environment:
    name: production
    url: https://example.com
```

## Monitoring & Logging

### Health Check Endpoint

PHPeek includes built-in health checks:

```bash
# Check health
curl http://localhost/health

# Expected output:
# {"status":"healthy","php-fpm":"running","nginx":"running"}
```

### Prometheus Metrics

**Install PHP-FPM exporter:**

```yaml
services:
  app:
    # ... app config

  php-fpm-exporter:
    image: hipages/php-fpm_exporter:latest
    ports:
      - "9253:9253"
    environment:
      - PHP_FPM_SCRAPE_URI=tcp://app:9000/status
```

### Log Aggregation (ELK Stack)

```yaml
services:
  app:
    logging:
      driver: "fluentd"
      options:
        fluentd-address: localhost:24224
        tag: phpeek.app

  fluentd:
    image: fluent/fluentd:latest
    ports:
      - "24224:24224"
    volumes:
      - ./fluentd/fluent.conf:/fluentd/etc/fluent.conf
```

## Zero-Downtime Deployments

### Rolling Update Strategy

```yaml
# docker-compose.yml
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

### Deployment Script

```bash
#!/bin/bash
# deploy.sh

set -e

echo "🚀 Starting deployment..."

# Pull new image
docker-compose pull app

# Health check function
health_check() {
  curl -f http://localhost/health || return 1
}

# Rolling restart
for i in {1..3}; do
  echo "Restarting instance $i..."

  # Stop one instance
  docker-compose up -d --scale app=$((3-i))

  # Wait for health check
  sleep 5
  if ! health_check; then
    echo "❌ Health check failed! Rolling back..."
    docker-compose up -d --scale app=3
    exit 1
  fi

  # Start new instance
  docker-compose up -d --scale app=3

  echo "✅ Instance $i restarted successfully"
  sleep 10
done

echo "✅ Deployment complete!"
```

### Blue-Green Deployment

```bash
#!/bin/bash
# blue-green-deploy.sh

# Deploy to green environment
docker-compose -f docker-compose.green.yml up -d

# Wait for health check
sleep 10
if curl -f http://localhost:8001/health; then
  # Switch load balancer to green
  # (Update your load balancer configuration)

  # Stop blue environment
  docker-compose -f docker-compose.blue.yml down

  echo "✅ Switched to green environment"
else
  echo "❌ Health check failed! Keeping blue environment"
  docker-compose -f docker-compose.green.yml down
  exit 1
fi
```

## Backup & Recovery

### Database Backup

```bash
#!/bin/bash
# backup-db.sh

BACKUP_DIR=/backups
DATE=$(date +%Y%m%d_%H%M%S)

# Backup database
docker exec mysql mysqldump \
  -u root \
  -p${MYSQL_ROOT_PASSWORD} \
  ${DB_DATABASE} \
  | gzip > ${BACKUP_DIR}/db_${DATE}.sql.gz

# Keep only last 7 days
find ${BACKUP_DIR} -name "db_*.sql.gz" -mtime +7 -delete

echo "✅ Backup completed: db_${DATE}.sql.gz"
```

### Application Storage Backup

```bash
#!/bin/bash
# backup-storage.sh

BACKUP_DIR=/backups
DATE=$(date +%Y%m%d_%H%M%S)

# Backup storage volume
docker run --rm \
  -v app-storage:/source:ro \
  -v ${BACKUP_DIR}:/backup \
  alpine tar czf /backup/storage_${DATE}.tar.gz -C /source .

echo "✅ Storage backup completed: storage_${DATE}.tar.gz"
```

### Restore Script

```bash
#!/bin/bash
# restore.sh

BACKUP_FILE=$1

if [ -z "$BACKUP_FILE" ]; then
  echo "Usage: ./restore.sh <backup-file>"
  exit 1
fi

# Restore database
if [[ $BACKUP_FILE == *.sql.gz ]]; then
  gunzip < $BACKUP_FILE | docker exec -i mysql mysql \
    -u root \
    -p${MYSQL_ROOT_PASSWORD} \
    ${DB_DATABASE}
  echo "✅ Database restored"
fi

# Restore storage
if [[ $BACKUP_FILE == *.tar.gz ]]; then
  docker run --rm \
    -v app-storage:/target \
    -v $(dirname $BACKUP_FILE):/backup \
    alpine tar xzf /backup/$(basename $BACKUP_FILE) -C /target
  echo "✅ Storage restored"
fi
```

### Automated Backup with Cron

```bash
# /etc/cron.d/phpeek-backup
0 2 * * * root /opt/myapp/backup-db.sh >> /var/log/backup.log 2>&1
0 3 * * * root /opt/myapp/backup-storage.sh >> /var/log/backup.log 2>&1
```

## Production Checklist

Before going live:

### Security
- [ ] SSL/TLS certificates configured
- [ ] Security headers enabled
- [ ] Secrets stored securely (not in code)
- [ ] Database passwords rotated
- [ ] Firewall rules configured
- [ ] Rate limiting enabled

### Performance
- [ ] OPcache validation disabled
- [ ] Static process manager configured
- [ ] Gzip compression enabled
- [ ] Static assets cached
- [ ] Database queries optimized
- [ ] Load testing completed

### Reliability
- [ ] Health checks configured
- [ ] Auto-restart enabled
- [ ] Resource limits set
- [ ] Backup automation running
- [ ] Monitoring alerts configured
- [ ] Rollback procedure documented

### Operations
- [ ] CI/CD pipeline tested
- [ ] Zero-downtime deployment verified
- [ ] Log aggregation working
- [ ] Metrics collection active
- [ ] On-call procedures documented
- [ ] Runbooks created

## Related Documentation

- [Security Hardening](../advanced/security-hardening) - Detailed security guide
- [Performance Tuning](../advanced/performance-tuning) - Optimization deep dive
- [Environment Variables](../reference/environment-variables) - Configuration reference
- [Health Checks](../reference/health-checks) - Monitoring guide

---

**Questions?** Check [common issues](../troubleshooting/common-issues) or ask in [GitHub Discussions](https://github.com/gophpeek/baseimages/discussions).
