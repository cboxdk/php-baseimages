---
title: "Configuration Options Reference"
description: "Complete reference for customizing PHP.ini, PHP-FPM pools, and Nginx server blocks in PHPeek base images"
weight: 32
---

# Configuration Options Reference

Complete reference for advanced PHP, PHP-FPM, and Nginx configuration in PHPeek base images.

## Table of Contents

- [PHP.ini Customization](#phpini-customization)
- [PHP-FPM Pool Configuration](#php-fpm-pool-configuration)
- [Nginx Server Blocks](#nginx-server-blocks)
- [Custom Configuration Files](#custom-configuration-files)
- [Configuration Precedence](#configuration-precedence)

## PHP.ini Customization

### Method 1: Environment Variables (Recommended)

Use environment variables for simple settings (see [Environment Variables Reference](environment-variables)).

```yaml
services:
  app:
    environment:
      - PHP_MEMORY_LIMIT=256M
      - PHP_MAX_EXECUTION_TIME=60
```

### Method 2: Custom php.ini via Volume Mount

For complex configuration, mount a custom PHP configuration file.

**Create `docker/php/custom.ini`:**

```ini
[PHP]
; Memory & Execution
memory_limit = 512M
max_execution_time = 120
max_input_time = 120

; File Uploads
upload_max_filesize = 100M
post_max_size = 120M
max_file_uploads = 50

; Error Handling
display_errors = Off
display_startup_errors = Off
error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT
log_errors = On
error_log = /proc/self/fd/2

; Date & Timezone
date.timezone = UTC

; Sessions
session.save_handler = redis
session.save_path = "tcp://redis:6379?database=2"
session.gc_maxlifetime = 7200
session.cookie_secure = 1
session.cookie_httponly = 1
session.cookie_samesite = "Strict"

[opcache]
opcache.enable = 1
opcache.memory_consumption = 256
opcache.interned_strings_buffer = 16
opcache.max_accelerated_files = 20000
opcache.validate_timestamps = 0
opcache.save_comments = 1
opcache.enable_file_override = 1

[apcu]
apc.enabled = 1
apc.shm_size = 128M
apc.ttl = 7200
apc.gc_ttl = 3600
```

**Mount in docker-compose.yml:**

```yaml
services:
  app:
    image: ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.3-alpine
    volumes:
      - ./:/var/www/html
      - ./docker/php/custom.ini:/usr/local/etc/php/conf.d/zz-custom.ini:ro
```

**Filename Convention:**
- Prefix with `zz-` to ensure it loads last (alphabetical order)
- Files in `conf.d/` override previous settings
- Use `.ini` extension

### Method 3: Dockerfile Extension

For permanent custom configuration in your image:

```dockerfile
FROM ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.3-alpine

# Copy custom PHP configuration
COPY docker/php/custom.ini /usr/local/etc/php/conf.d/zz-custom.ini
```

### Common PHP.ini Sections

#### Date & Time

```ini
[Date]
date.timezone = "America/New_York"
date.default_latitude = 40.7128
date.default_longitude = -74.0060
```

#### Security Settings

```ini
[Security]
; Disable dangerous functions
disable_functions = exec,passthru,shell_exec,system,proc_open,popen,curl_exec,curl_multi_exec,parse_ini_file,show_source

; Hide PHP version
expose_php = Off

; Restrict file access
open_basedir = /var/www/html:/tmp

; Session security
session.cookie_secure = 1
session.cookie_httponly = 1
session.cookie_samesite = "Strict"
session.use_strict_mode = 1
```

#### Performance Tuning

```ini
[Performance]
; Realpath cache (speed up file lookups)
realpath_cache_size = 4M
realpath_cache_ttl = 600

; Output buffering
output_buffering = 4096
implicit_flush = Off

; Disable unused extensions
;extension=sodium  ; Uncomment if not needed
```

## PHP-FPM Pool Configuration

### Method 1: Environment Variables (Basic)

Use environment variables for common settings:

```yaml
services:
  app:
    environment:
      - PHP_FPM_PM=dynamic
      - PHP_FPM_PM_MAX_CHILDREN=50
      - PHP_FPM_PM_START_SERVERS=10
```

### Method 2: Custom Pool Configuration (Advanced)

**Create `docker/php-fpm/www.conf`:**

```ini
[www]
; Unix user/group of processes
user = www-data
group = www-data

; Process manager
pm = dynamic
pm.max_children = 50
pm.start_servers = 10
pm.min_spare_servers = 5
pm.max_spare_servers = 20
pm.max_requests = 1000

; Process timeout
request_terminate_timeout = 60s

; Slow request logging
request_slowlog_timeout = 5s
slowlog = /proc/self/fd/2

; Resource limits
rlimit_files = 4096
rlimit_core = 0

; Status page
pm.status_path = /fpm-status

; Ping page
ping.path = /fpm-ping
ping.response = pong

; Access log
access.log = /proc/self/fd/2
access.format = "%R - %u %t \"%m %r%Q%q\" %s %f %{mili}d %{kilo}M %C%%"

; Security
security.limit_extensions = .php

; Environment variables
clear_env = no
env[PATH] = /usr/local/bin:/usr/bin:/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] = /tmp

; PHP.ini values (pool-specific)
php_admin_value[error_log] = /proc/self/fd/2
php_admin_flag[log_errors] = on
php_value[session.save_handler] = redis
php_value[session.save_path] = "tcp://redis:6379"
```

**Mount in docker-compose.yml:**

```yaml
services:
  app:
    volumes:
      - ./docker/php-fpm/www.conf:/usr/local/etc/php-fpm.d/zz-www.conf:ro
```

### Multiple PHP-FPM Pools

Run different pools for different applications:

**Create `docker/php-fpm/api.conf`:**

```ini
[api]
user = www-data
group = www-data
listen = 127.0.0.1:9001

pm = dynamic
pm.max_children = 20
pm.start_servers = 4
pm.min_spare_servers = 2
pm.max_spare_servers = 6

request_terminate_timeout = 30s
php_value[memory_limit] = 128M
```

**Update Nginx to route to different pools:**

```nginx
location /api {
    fastcgi_pass 127.0.0.1:9001;  # API pool
    # ... other fastcgi settings
}

location / {
    fastcgi_pass 127.0.0.1:9000;  # Default pool
    # ... other fastcgi settings
}
```

## Nginx Server Blocks

### Method 1: Custom Nginx Configuration via Volume

**Create `docker/nginx/default.conf`:**

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name example.com;
    root /var/www/html/public;
    index index.php index.html;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript
               application/json application/javascript application/xml+rss
               application/rss+xml application/atom+xml image/svg+xml
               text/x-component text/x-cross-domain-policy;

    # Client settings
    client_max_body_size 100m;
    client_body_timeout 60s;

    # Logging
    access_log /proc/self/fd/1;
    error_log /proc/self/fd/2 warn;

    # Default location
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    # PHP-FPM
    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;

        # Timeouts
        fastcgi_read_timeout 60s;
        fastcgi_send_timeout 60s;
        fastcgi_connect_timeout 60s;

        # Buffers
        fastcgi_buffer_size 128k;
        fastcgi_buffers 256 16k;
        fastcgi_busy_buffers_size 256k;
        fastcgi_temp_file_write_size 256k;
    }

    # Deny access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Static files caching
    location ~* \.(jpg|jpeg|gif|png|webp|svg|woff|woff2|ttf|css|js|ico|xml)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
        access_log off;
    }
}
```

**Mount in docker-compose.yml:**

```yaml
services:
  app:
    volumes:
      - ./:/var/www/html
      - ./docker/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
```

### Laravel-Specific Nginx Configuration

```nginx
server {
    listen 80;
    server_name laravel.local;
    root /var/www/html/public;
    index index.php;

    charset utf-8;

    # Laravel public directory
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    # PHP-FPM
    location ~ \.php$ {
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }

    # Deny access to .env files
    location ~ /\.env {
        deny all;
    }

    # Deny access to storage and bootstrap/cache
    location ~ ^/(storage|bootstrap/cache) {
        deny all;
    }

    # Allow Laravel Horizon dashboard
    location /horizon {
        try_files $uri $uri/ /index.php?$query_string;
    }

    error_page 404 /index.php;
}
```

### Symfony-Specific Nginx Configuration

```nginx
server {
    listen 80;
    server_name symfony.local;
    root /var/www/html/public;
    index index.php;

    location / {
        # Try to serve file directly, fallback to index.php
        try_files $uri /index.php$is_args$args;
    }

    # DEV, PROD, and profiler
    location ~ ^/(index|index_dev|config)\.php(/|$) {
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_split_path_info ^(.+\.php)(/.*)$;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT $realpath_root;
        internal;
    }

    # Return 404 for all other php files
    location ~ \.php$ {
        return 404;
    }
}
```

### WordPress-Specific Nginx Configuration

```nginx
server {
    listen 80;
    server_name wordpress.local;
    root /var/www/html;
    index index.php;

    # WordPress permalinks
    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    # PHP-FPM
    location ~ \.php$ {
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    # Deny access to sensitive files
    location ~ /\.(ht|git|svn) {
        deny all;
    }

    location = /xmlrpc.php {
        deny all;
        access_log off;
    }

    # Static files caching
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # WordPress uploads
    location ~* ^/wp-content/uploads/.*\.(php|php5|php7|phtml)$ {
        deny all;
    }
}
```

### SSL/HTTPS Configuration

```nginx
server {
    listen 80;
    server_name example.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name example.com;
    root /var/www/html/public;

    # SSL certificates
    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;

    # SSL settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # HSTS
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # ... rest of configuration
}
```

## Custom Configuration Files

### Directory Structure

```
project/
├── docker/
│   ├── php/
│   │   ├── custom.ini           # PHP configuration
│   │   └── 99-custom.ini        # Additional PHP settings
│   ├── php-fpm/
│   │   ├── www.conf             # PHP-FPM pool
│   │   └── api.conf             # Additional pool
│   └── nginx/
│       ├── default.conf         # Main server block
│       ├── includes/
│       │   ├── security.conf    # Security headers
│       │   └── gzip.conf        # Compression settings
│       └── ssl/
│           ├── cert.pem
│           └── key.pem
├── docker-compose.yml
└── Dockerfile
```

### docker-compose.yml with All Configs

```yaml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "443:443"
      - "80:80"
    volumes:
      # Application code
      - ./:/var/www/html

      # PHP configuration
      - ./docker/php/custom.ini:/usr/local/etc/php/conf.d/zz-custom.ini:ro
      - ./docker/php/99-custom.ini:/usr/local/etc/php/conf.d/zz-99-custom.ini:ro

      # PHP-FPM configuration
      - ./docker/php-fpm/www.conf:/usr/local/etc/php-fpm.d/zz-www.conf:ro
      - ./docker/php-fpm/api.conf:/usr/local/etc/php-fpm.d/zz-api.conf:ro

      # Nginx configuration
      - ./docker/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
      - ./docker/nginx/includes/:/etc/nginx/includes/:ro
      - ./docker/nginx/ssl/:/etc/nginx/ssl/:ro
    environment:
      - PHP_MEMORY_LIMIT=512M
```

### Nginx Include Files

**docker/nginx/includes/security.conf:**

```nginx
# Security headers
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "no-referrer-when-downgrade" always;
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline';" always;
```

**docker/nginx/includes/gzip.conf:**

```nginx
# Gzip compression
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
    application/rss+xml
    application/atom+xml
    image/svg+xml
    text/x-component
    text/x-cross-domain-policy;
```

**Use in main nginx config:**

```nginx
server {
    listen 80;
    # ... other settings

    # Include security headers
    include /etc/nginx/includes/security.conf;

    # Include compression settings
    include /etc/nginx/includes/gzip.conf;
}
```

## Configuration Precedence

### PHP Configuration Loading Order

1. **Built-in defaults** (`/usr/local/etc/php/php.ini-production`)
2. **Additional .ini files** (alphabetically from `/usr/local/etc/php/conf.d/`)
   - `docker-php-ext-*.ini` (extensions)
   - `zz-custom.ini` (your overrides)
3. **PHP-FPM pool directives** (`php_value`, `php_admin_value`)
4. **Runtime** (`.htaccess`, `ini_set()`)

**Example precedence:**

```
php.ini:                memory_limit = 128M
zz-custom.ini:         memory_limit = 256M  ← Overrides php.ini
php-fpm pool:          memory_limit = 512M  ← Overrides zz-custom.ini
```

### Verification Commands

```bash
# Check which php.ini is loaded
docker exec <container> php --ini

# Check specific setting
docker exec <container> php -r "echo ini_get('memory_limit');"

# Check all settings
docker exec <container> php -i | grep memory_limit

# Check PHP-FPM pool config
docker exec <container> cat /usr/local/etc/php-fpm.d/www.conf

# Check Nginx config syntax
docker exec <container> nginx -t

# Check active Nginx config
docker exec <container> cat /etc/nginx/conf.d/default.conf
```

## Testing Configuration Changes

### 1. Test Locally First

```bash
# Build with new config
docker-compose build

# Start container
docker-compose up -d

# Check logs for errors
docker-compose logs -f

# Verify settings
docker exec $(docker-compose ps -q app) php -i | grep memory_limit
```

### 2. Test Nginx Configuration

```bash
# Test Nginx syntax
docker exec <container> nginx -t

# Reload Nginx (no downtime)
docker exec <container> nginx -s reload
```

### 3. Test PHP-FPM Configuration

```bash
# Test PHP-FPM config
docker exec <container> php-fpm -t

# Reload PHP-FPM (graceful)
docker exec <container> kill -USR2 1
```

## Common Configuration Patterns

### High Traffic Configuration

```ini
# PHP
memory_limit = 512M
max_execution_time = 30

# OPcache
opcache.memory_consumption = 512
opcache.max_accelerated_files = 50000
opcache.validate_timestamps = 0

# PHP-FPM
pm = static
pm.max_children = 100
pm.max_requests = 1000
```

### Development Configuration

```ini
# PHP
display_errors = On
error_reporting = E_ALL
opcache.validate_timestamps = 1
opcache.revalidate_freq = 0

# PHP-FPM
pm = dynamic
pm.max_children = 10
request_slowlog_timeout = 1s
```

### Memory-Constrained Configuration

```ini
# PHP
memory_limit = 128M

# OPcache
opcache.memory_consumption = 64

# PHP-FPM
pm = ondemand
pm.max_children = 20
pm.process_idle_timeout = 10s
```

## Related Documentation

- [Environment Variables Reference](environment-variables) - Simple configuration via env vars
- [Performance Tuning](../advanced/performance-tuning) - Optimization strategies
- [Security Hardening](../advanced/security-hardening) - Security best practices
- [Extending Images](../advanced/extending-images) - Creating custom images

---

**Questions?** Check [common issues](../troubleshooting/common-issues) or ask in [GitHub Discussions](https://github.com/phpeek/baseimages/discussions).
