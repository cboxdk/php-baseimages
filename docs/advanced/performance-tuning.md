---
title: "Performance Tuning Guide"
description: "Optimize PHP-FPM, OPcache, and Nginx for maximum performance in PHPeek base images"
weight: 22
---

# Performance Tuning Guide

Comprehensive guide to optimizing PHPeek containers for maximum performance in production environments.

## Table of Contents

- [Performance Benchmarking](#performance-benchmarking)
- [PHP-FPM Optimization](#php-fpm-optimization)
- [OPcache Tuning](#opcache-tuning)
- [Nginx Optimization](#nginx-optimization)
- [Database Connection Pooling](#database-connection-pooling)
- [Caching Strategies](#caching-strategies)
- [Resource Limits](#resource-limits)
- [Monitoring Performance](#monitoring-performance)

## Performance Benchmarking

### Baseline Measurement

Always measure before optimizing:

```bash
# Install Apache Bench
apt-get install apache2-utils

# Simple benchmark (1000 requests, 10 concurrent)
ab -n 1000 -c 10 http://localhost/

# With keep-alive
ab -n 1000 -c 10 -k http://localhost/

# POST request benchmark
ab -n 1000 -c 10 -p data.json -T application/json http://localhost/api/endpoint
```

### Load Testing with K6

```javascript
// load-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '1m', target: 50 },   // Ramp up
    { duration: '3m', target: 50 },   // Stay at 50 users
    { duration: '1m', target: 100 },  // Ramp to 100
    { duration: '3m', target: 100 },  // Stay at 100
    { duration: '1m', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],  // 95% under 500ms
    http_req_failed: ['rate<0.01'],    // Less than 1% failed
  },
};

export default function () {
  const res = http.get('http://localhost:8000');
  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });
  sleep(1);
}
```

```bash
# Run load test
k6 run load-test.js
```

## PHP-FPM Optimization

### Process Manager Selection

**Dynamic (Default - Best for Variable Traffic):**

```yaml
services:
  app:
    environment:
      - PHP_FPM_PM=dynamic
      - PHP_FPM_PM_MAX_CHILDREN=50
      - PHP_FPM_PM_START_SERVERS=10
      - PHP_FPM_PM_MIN_SPARE_SERVERS=5
      - PHP_FPM_PM_MAX_SPARE_SERVERS=15
      - PHP_FPM_PM_MAX_REQUESTS=1000
```

**Static (Best for Consistent High Traffic):**

```yaml
services:
  app:
    environment:
      - PHP_FPM_PM=static
      - PHP_FPM_PM_MAX_CHILDREN=50
```

**OnDemand (Best for Low Traffic / Memory Constrained):**

```yaml
services:
  app:
    environment:
      - PHP_FPM_PM=ondemand
      - PHP_FPM_PM_MAX_CHILDREN=20
      - PHP_FPM_PM_PROCESS_IDLE_TIMEOUT=10s
```

### Calculating Optimal max_children

**Formula:**

```
max_children = Available RAM / Average Process Memory
```

**Measure process memory:**

```bash
# Average PHP-FPM process memory
docker exec <container> sh -c 'ps aux | grep "php-fpm: pool" | awk "{sum+=\$6} END {print sum/NR/1024 \"MB\"}"'

# Example output: 45MB per process

# If you have 2GB for PHP-FPM:
# max_children = 2048MB / 45MB = ~45 processes
```

**Verification:**

```bash
# Monitor actual usage
docker stats <container>

# Check PHP-FPM status
curl http://localhost/fpm-status

# Watch process count
watch -n 1 'docker exec <container> ps aux | grep php-fpm | wc -l'
```

### Process Manager Tuning by Workload

**API Server (Stateless, Fast Requests):**

```ini
pm = static
pm.max_children = 100
pm.max_requests = 500
request_terminate_timeout = 10s
```

**Web Application (Mixed Workload):**

```ini
pm = dynamic
pm.max_children = 50
pm.start_servers = 10
pm.min_spare_servers = 10
pm.max_spare_servers = 20
pm.max_requests = 1000
request_terminate_timeout = 30s
```

**Background Jobs (Long-Running Tasks):**

```ini
pm = ondemand
pm.max_children = 10
pm.process_idle_timeout = 30s
request_terminate_timeout = 300s
```

### Request Lifecycle Optimization

```ini
; Prevent memory leaks by recycling processes
pm.max_requests = 1000

; Terminate long-running requests
request_terminate_timeout = 60s

; Log slow requests
request_slowlog_timeout = 5s
slowlog = /proc/self/fd/2

; Increase buffer sizes for large requests
php_admin_value[post_max_size] = 100M
php_admin_value[upload_max_filesize] = 100M
```

## OPcache Tuning

### Production Configuration

```ini
[opcache]
; Enable OPcache
opcache.enable = 1
opcache.enable_cli = 0

; Memory allocation
opcache.memory_consumption = 256        ; Increase for large codebases
opcache.interned_strings_buffer = 16   ; Increase for many classes
opcache.max_accelerated_files = 20000  ; More than total PHP files

; Validation (disable in production for speed)
opcache.validate_timestamps = 0        ; Don't check file changes
opcache.revalidate_freq = 0            ; Not used when validation disabled

; Performance optimizations
opcache.enable_file_override = 1       ; Faster file_exists checks
opcache.save_comments = 1              ; Required for some frameworks
opcache.fast_shutdown = 1              ; Faster shutdown

; Optimization level
opcache.optimization_level = 0x7FFEBFFF  ; Maximum optimization

; JIT (PHP 8.0+)
opcache.jit = 1255                     ; Enable JIT compilation
opcache.jit_buffer_size = 100M         ; JIT buffer size
```

**Via environment variables:**

```yaml
services:
  app:
    environment:
      # OPcache Production
      - PHP_OPCACHE_ENABLE=1
      - PHP_OPCACHE_VALIDATE_TIMESTAMPS=0
      - PHP_OPCACHE_MEMORY_CONSUMPTION=256
      - PHP_OPCACHE_INTERNED_STRINGS_BUFFER=16
      - PHP_OPCACHE_MAX_ACCELERATED_FILES=20000
```

### OPcache Monitoring

```php
<?php
// opcache-status.php
$status = opcache_get_status();
$config = opcache_get_configuration();

header('Content-Type: application/json');
echo json_encode([
    'enabled' => $status !== false,
    'memory_usage' => [
        'used_memory' => $status['memory_usage']['used_memory'],
        'free_memory' => $status['memory_usage']['free_memory'],
        'wasted_memory' => $status['memory_usage']['wasted_memory'],
        'current_wasted_percentage' => $status['memory_usage']['current_wasted_percentage'],
    ],
    'opcache_statistics' => [
        'num_cached_scripts' => $status['opcache_statistics']['num_cached_scripts'],
        'num_cached_keys' => $status['opcache_statistics']['num_cached_keys'],
        'max_cached_keys' => $status['opcache_statistics']['max_cached_keys'],
        'hits' => $status['opcache_statistics']['hits'],
        'misses' => $status['opcache_statistics']['misses'],
        'hit_rate' => round($status['opcache_statistics']['opcache_hit_rate'], 2),
    ],
]);
```

```bash
# Check OPcache status
curl http://localhost/opcache-status.php | jq

# Clear OPcache (when needed)
docker exec <container> kill -USR2 1  # Reload PHP-FPM
```

### OPcache Sizing

```bash
# Count PHP files in your application
find /var/www/html -type f -name "*.php" | wc -l

# Example: 5000 files
# Set max_accelerated_files to next prime > 5000 * 2 = 10000
# Closest prime: 10007 or 20000 (safe)
```

**OPcache memory calculation:**

```
Average file size * Number of files * 2 = Memory needed
10KB * 5000 * 2 = 100MB

Add 50% buffer = 150MB minimum
Recommended: 256MB for production
```

## Nginx Optimization

### Worker Configuration

```nginx
# /etc/nginx/nginx.conf
user www-data;
worker_processes auto;  # CPU count
worker_rlimit_nofile 65535;
pid /run/nginx.pid;

events {
    worker_connections 4096;  # connections per worker
    use epoll;                # Linux optimization
    multi_accept on;
}

http {
    # Basic optimizations
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    types_hash_max_size 2048;
    server_tokens off;

    # Keepalive
    keepalive_timeout 30;
    keepalive_requests 100;

    # Client settings
    client_max_body_size 100m;
    client_body_buffer_size 128k;
    client_header_buffer_size 1k;
    large_client_header_buffers 4 8k;

    # Timeouts
    client_body_timeout 12;
    client_header_timeout 12;
    send_timeout 10;

    # Include configs
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
}
```

### FastCGI Optimization

```nginx
# Increase buffer sizes for PHP-FPM
fastcgi_buffer_size 128k;
fastcgi_buffers 256 16k;
fastcgi_busy_buffers_size 256k;
fastcgi_temp_file_write_size 256k;

# Connection settings
fastcgi_connect_timeout 60s;
fastcgi_send_timeout 60s;
fastcgi_read_timeout 60s;

# Caching (optional)
fastcgi_cache_path /var/cache/nginx levels=1:2 keys_zone=PHPCACHE:100m inactive=60m;
fastcgi_cache_key "$scheme$request_method$host$request_uri";
```

### Static Asset Caching

```nginx
# Cache static assets
location ~* \.(jpg|jpeg|gif|png|webp|svg|ico|pdf)$ {
    expires 365d;
    add_header Cache-Control "public, immutable";
    access_log off;
}

location ~* \.(css|js|woff|woff2|ttf|eot)$ {
    expires 30d;
    add_header Cache-Control "public, immutable";
    access_log off;
}

# Enable gzip
gzip on;
gzip_vary on;
gzip_proxied any;
gzip_comp_level 6;
gzip_min_length 256;
gzip_types
    application/atom+xml
    application/javascript
    application/json
    application/ld+json
    application/manifest+json
    application/rss+xml
    application/vnd.geo+json
    application/vnd.ms-fontobject
    application/x-font-ttf
    application/x-web-app-manifest+json
    application/xhtml+xml
    application/xml
    font/opentype
    image/bmp
    image/svg+xml
    image/x-icon
    text/cache-manifest
    text/css
    text/plain
    text/vcard
    text/vnd.rim.location.xloc
    text/vtt
    text/x-component
    text/x-cross-domain-policy;
```

### Open File Cache

```nginx
# Cache file descriptors
open_file_cache max=10000 inactive=20s;
open_file_cache_valid 30s;
open_file_cache_min_uses 2;
open_file_cache_errors on;
```

## Database Connection Pooling

### PgBouncer (PostgreSQL)

```yaml
services:
  pgbouncer:
    image: edoburu/pgbouncer:latest
    environment:
      - DB_HOST=postgres
      - DB_USER=app
      - DB_PASSWORD=${DB_PASSWORD}
      - POOL_MODE=transaction
      - MAX_CLIENT_CONN=1000
      - DEFAULT_POOL_SIZE=25
    ports:
      - "6432:6432"

  app:
    environment:
      - DB_HOST=pgbouncer
      - DB_PORT=6432
```

### ProxySQL (MySQL)

```yaml
services:
  proxysql:
    image: proxysql/proxysql:latest
    ports:
      - "6033:6033"
    volumes:
      - ./proxysql.cnf:/etc/proxysql.cnf
    depends_on:
      - mysql

  app:
    environment:
      - DB_HOST=proxysql
      - DB_PORT=6033
```

### Laravel Connection Pooling

```php
// config/database.php
'mysql' => [
    'driver' => 'mysql',
    'host' => env('DB_HOST'),
    'options' => [
        PDO::ATTR_PERSISTENT => true,  // Persistent connections
    ],
    'sticky' => true,
],
```

## Caching Strategies

### APCu for Local Cache

```php
// Laravel cache config
'stores' => [
    'apcu' => [
        'driver' => 'apcu',
    ],
],

// Usage
Cache::store('apcu')->remember('users', 3600, function () {
    return DB::table('users')->get();
});
```

### Redis for Distributed Cache

**Optimized Redis configuration:**

```bash
# redis.conf
maxmemory 512mb
maxmemory-policy allkeys-lru

# Persistence (optional)
save 900 1
save 300 10
save 60 10000

# Performance
tcp-backlog 511
timeout 0
tcp-keepalive 300
```

**Laravel Redis optimization:**

```php
// config/cache.php
'redis' => [
    'driver' => 'redis',
    'connection' => 'cache',
    'lock_connection' => 'default',
],

// config/database.php
'redis' => [
    'client' => 'phpredis',  // Faster than predis
    'options' => [
        'cluster' => env('REDIS_CLUSTER', 'redis'),
        'prefix' => env('REDIS_PREFIX', Str::slug(env('APP_NAME'), '_').'_database_'),
    ],
    'cache' => [
        'url' => env('REDIS_URL'),
        'host' => env('REDIS_HOST'),
        'password' => env('REDIS_PASSWORD'),
        'port' => env('REDIS_PORT'),
        'database' => env('REDIS_CACHE_DB', 1),
    ],
],
```

### HTTP Caching Headers

```nginx
location / {
    # Cache-Control for dynamic content
    add_header Cache-Control "private, no-cache, no-store, must-revalidate";
    add_header Pragma "no-cache";
    add_header Expires 0;
}

location /api/ {
    # API responses with short cache
    add_header Cache-Control "public, max-age=300";
}

location ~* \.(jpg|jpeg|gif|png|webp|svg)$ {
    # Long-term caching for images
    add_header Cache-Control "public, max-age=31536000, immutable";
}
```

## Resource Limits

### Container Resource Limits

```yaml
services:
  app:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 4G
        reservations:
          cpus: '1.0'
          memory: 2G
```

### PHP Memory Limits

```yaml
services:
  app:
    environment:
      # Set based on application needs
      - PHP_MEMORY_LIMIT=512M  # Per-request memory
```

**Calculate safe limits:**

```
Total container memory: 4GB
PHP-FPM processes: 50
Safe memory per process: 4GB / 50 = ~80MB
Set PHP_MEMORY_LIMIT: 80M * 0.8 = 64M (with buffer)
```

### Nginx Connection Limits

```nginx
# Limit connections per IP
limit_conn_zone $binary_remote_addr zone=conn_limit_per_ip:10m;
limit_conn conn_limit_per_ip 10;

# Rate limiting
limit_req_zone $binary_remote_addr zone=req_limit_per_ip:10m rate=10r/s;
limit_req zone=req_limit_per_ip burst=20 nodelay;
```

## Monitoring Performance

### PHP-FPM Status Page

Enable in PHP-FPM config:

```ini
pm.status_path = /fpm-status
```

```nginx
location /fpm-status {
    access_log off;
    allow 127.0.0.1;
    deny all;
    fastcgi_pass 127.0.0.1:9000;
    include fastcgi_params;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
}
```

```bash
# Check status
curl http://localhost/fpm-status?full

# JSON format
curl http://localhost/fpm-status?json
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

  nginx-exporter:
    image: nginx/nginx-prometheus-exporter:latest
    ports:
      - "9113:9113"
    command:
      - -nginx.scrape-uri=http://app/nginx_status
```

### Application Performance Monitoring (APM)

**New Relic:**

```dockerfile
FROM ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.3-alpine

RUN curl -L https://download.newrelic.com/php_agent/release/newrelic-php5-10.x-linux.tar.gz | tar -C /tmp -zx \
    && export NR_INSTALL_USE_CP_NOT_LN=1 \
    && export NR_INSTALL_SILENT=1 \
    && /tmp/newrelic-php5-*/newrelic-install install \
    && rm -rf /tmp/newrelic-php5-*
```

**Blackfire:**

```yaml
services:
  blackfire:
    image: blackfire/blackfire:2
    environment:
      - BLACKFIRE_SERVER_ID=${BLACKFIRE_SERVER_ID}
      - BLACKFIRE_SERVER_TOKEN=${BLACKFIRE_SERVER_TOKEN}
```

## Performance Checklist

### ✅ PHP-FPM
- [ ] Process manager tuned for workload
- [ ] max_children calculated based on memory
- [ ] max_requests set to prevent memory leaks
- [ ] request_terminate_timeout configured
- [ ] Slow request logging enabled

### ✅ OPcache
- [ ] OPcache enabled and sized correctly
- [ ] validate_timestamps = 0 in production
- [ ] max_accelerated_files > total PHP files
- [ ] JIT enabled (PHP 8.0+)
- [ ] Monitoring in place

### ✅ Nginx
- [ ] Worker processes = CPU count
- [ ] Worker connections increased
- [ ] FastCGI buffers optimized
- [ ] Static asset caching enabled
- [ ] Gzip compression configured
- [ ] Open file cache enabled

### ✅ Caching
- [ ] OPcache for PHP bytecode
- [ ] APCu for local data cache
- [ ] Redis for distributed cache
- [ ] HTTP caching headers set
- [ ] Database query caching enabled

### ✅ Monitoring
- [ ] PHP-FPM status page enabled
- [ ] Nginx metrics exposed
- [ ] APM tool integrated
- [ ] Log aggregation configured
- [ ] Alerts set up

## Related Documentation

- [Environment Variables](../reference/environment-variables) - Configuration options
- [Configuration Options](../reference/configuration-options) - Detailed config
- [Production Deployment](../guides/production-deployment) - Production setup
- [Security Hardening](security-hardening) - Security optimizations

---

**Questions?** Check [common issues](../troubleshooting/common-issues) or ask in [GitHub Discussions](https://github.com/gophpeek/baseimages/discussions).
