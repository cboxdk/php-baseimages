---
title: "Extending Cbox Images"
description: "Learn how to customize Cbox base images to add custom PHP extensions, system packages, and initialization scripts"
weight: 21
---

# Extending Cbox Images

Learn how to customize Cbox base images to add your own PHP extensions, system packages, configurations, and initialization scripts.

## Table of Contents

- [Why Extend an Image?](#why-extend-an-image)
- [Method 1: Simple Dockerfile Extension](#method-1-simple-dockerfile-extension-recommended)
- [Method 2: Multi-Stage Builds](#method-2-multi-stage-builds-advanced)
- [Common Extension Examples](#common-extension-examples)
- [Custom Initialization Scripts](#custom-initialization-scripts)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Why Extend an Image?

Cbox images come with 40+ PHP extensions pre-installed, but you might need to:

- ✅ Add custom PHP extensions (MongoDB, Swoole, etc.)
- ✅ Install system packages (FFmpeg, wkhtmltopdf, etc.)
- ✅ Add custom PHP/Nginx configurations
- ✅ Run initialization scripts on container startup
- ✅ Install additional tools (Node.js, Python, etc.)

**Important:** Always start with Cbox base images, never start from scratch! You get:
- Pre-configured PHP-FPM + Nginx
- 40+ extensions already installed
- Framework auto-detection
- Health checks
- Weekly security updates

---

## Method 1: Simple Dockerfile Extension (Recommended)

This is the easiest way to extend Cbox images. Perfect for most use cases!

### Example 1: Adding MongoDB Extension

Create `Dockerfile` in your project root:

```dockerfile
# Start from Cbox base image
FROM ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm

# Install MongoDB PHP extension
RUN apt-get update && apt-get install -y $PHPIZE_DEPS && \
    pecl install mongodb-1.20.1 && \
    docker-php-ext-enable mongodb && \
    apk del $PHPIZE_DEPS

# Verify installation
RUN php -m | grep mongodb
```

Update your `docker-compose.yml` to build from this Dockerfile:

```yaml
services:
  app:
    build: .                 # Build from local Dockerfile
    # image: ghcr.io/...    # Remove this line
    ports:
      - "8000:80"
    volumes:
      - ./:/var/www/html
```

Build and start:

```bash
docker-compose build
docker-compose up -d
```

**Verify MongoDB extension is installed:**

```bash
docker-compose exec app php -m | grep mongodb
```

**Expected Output:**
```
mongodb
```

---

### Example 2: Adding System Package (FFmpeg)

Need video processing capabilities?

```dockerfile
FROM ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm

# Install FFmpeg for video/audio processing
RUN apt-get update && apt-get install -y ffmpeg

# Verify installation
RUN ffmpeg -version
```

**Test FFmpeg:**

```bash
docker-compose exec app ffmpeg -version
```

---

### Example 3: Installing Node.js for Asset Compilation

Need to run `npm` or build frontend assets?

```dockerfile
FROM ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm

# Install Node.js and npm
RUN apt-get update && apt-get install -y nodejs npm

# Verify installation
RUN node --version && npm --version
```

Now you can run npm commands:

```bash
docker-compose exec app npm install
docker-compose exec app npm run build
```

---

### Example 4: Adding Multiple Extensions

```dockerfile
FROM ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm

# Install build dependencies (needed for compiling extensions)
RUN apt-get update && apt-get install -y $PHPIZE_DEPS

# Install multiple PECL extensions
RUN pecl install mongodb-1.20.1 && \
    pecl install swoole-5.1.5 && \
    pecl install xdebug-3.3.2

# Enable all extensions
RUN docker-php-ext-enable mongodb swoole xdebug

# Remove build dependencies to keep image small
RUN apk del $PHPIZE_DEPS

# Verify installations
RUN php -m | grep -E "(mongodb|swoole|xdebug)"
```

---

### Example 5: Custom PHP Configuration

Add custom PHP settings without rebuilding:

Create `custom-php.ini`:

```ini
; custom-php.ini
; Custom PHP configuration overrides

; Increase memory limit for data processing
memory_limit = 512M

; Longer execution time for imports
max_execution_time = 300

; Larger upload sizes
upload_max_filesize = 128M
post_max_size = 128M

; Enable all error reporting in development
error_reporting = E_ALL
display_errors = On
display_startup_errors = On

; OPcache settings for development
opcache.validate_timestamps = 1
opcache.revalidate_freq = 0
```

Mount it in `docker-compose.yml`:

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm
    volumes:
      - ./:/var/www/html
      # Mount custom PHP configuration
      - ./custom-php.ini:/usr/local/etc/php/conf.d/99-custom.ini:ro
```

**Verify configuration:**

```bash
docker-compose exec app php -i | grep memory_limit
```

**Expected Output:**
```
memory_limit => 512M => 512M
```

---

### Example 6: Custom Nginx Configuration

Add custom Nginx server block:

Create `custom-nginx.conf`:

```nginx
# custom-nginx.conf
# Custom Nginx server block

server {
    listen 80;
    server_name _;
    root /var/www/html/public;

    index index.php index.html;

    # Custom headers
    add_header X-Custom-Header "My Custom Value";
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    # Increase client body size for large uploads
    client_max_body_size 128M;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;

        # Longer timeout for complex operations
        fastcgi_read_timeout 300;
    }

    # Cache static files
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

Mount in `docker-compose.yml`:

```yaml
services:
  app:
    volumes:
      - ./:/var/www/html
      # Replace default Nginx config
      - ./custom-nginx.conf:/etc/nginx/conf.d/default.conf:ro
```

**Test Nginx configuration:**

```bash
docker-compose exec app nginx -t
```

**Expected Output:**
```
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

---

## Method 2: Multi-Stage Builds (Advanced)

For complex builds with different development and production configurations:

```dockerfile
# ======================
# Base Stage - Common to all environments
# ======================
FROM ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm AS base

# Install common extensions
RUN apt-get update && apt-get install -y $PHPIZE_DEPS && \
    pecl install redis-6.1.0 mongodb-1.20.1 && \
    docker-php-ext-enable redis mongodb && \
    apk del $PHPIZE_DEPS

# Install Node.js for asset compilation
RUN apt-get update && apt-get install -y nodejs npm

# ======================
# Development Stage
# ======================
FROM base AS development

# Install Xdebug for debugging
RUN apt-get update && apt-get install -y $PHPIZE_DEPS && \
    pecl install xdebug-3.3.2 && \
    docker-php-ext-enable xdebug && \
    apk del $PHPIZE_DEPS

# Copy development PHP configuration
COPY docker/dev-php.ini /usr/local/etc/php/conf.d/99-dev.ini

# Install development tools
RUN apt-get update && apt-get install -y git vim

# ======================
# Production Stage
# ======================
FROM base AS production

# Copy production PHP configuration
COPY docker/prod-php.ini /usr/local/etc/php/conf.d/99-prod.ini

# Copy application code (for production builds)
COPY --chown=www-data:www-data . /var/www/html

# Install Composer dependencies (production only)
RUN composer install --no-dev --optimize-autoloader --no-interaction

# Build frontend assets
RUN npm ci && npm run build && rm -rf node_modules

# Set production permissions
RUN chmod -R 755 /var/www/html && \
    chmod -R 777 /var/www/html/storage /var/www/html/bootstrap/cache
```

Build specific stage:

```bash
# Build development image
docker build --target development -t my-app:dev .

# Build production image
docker build --target production -t my-app:prod .
```

Use in `docker-compose.yml`:

```yaml
services:
  app:
    build:
      context: .
      target: development  # or 'production'
```

---

## Common Extension Examples

### Pre-Installed Extensions (You Already Have These!)

Cbox includes these extensions by default - **no need to install**:

✅ opcache, ✅ apcu, ✅ redis, ✅ pdo_mysql, ✅ pdo_pgsql, ✅ mysqli, ✅ pgsql,
✅ zip, ✅ intl, ✅ bcmath, ✅ gd, ✅ imagick, ✅ exif, ✅ pcntl, ✅ sockets,
✅ soap, ✅ xsl, ✅ ldap, ✅ imap, ✅ bz2, ✅ calendar, ✅ gettext, ✅ shmop

**Check installed extensions:**
```bash
docker-compose exec app php -m
```

### MongoDB Extension

```dockerfile
FROM ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm

RUN apt-get update && apt-get install -y $PHPIZE_DEPS && \
    pecl install mongodb-1.20.1 && \
    docker-php-ext-enable mongodb && \
    apk del $PHPIZE_DEPS
```

**Usage in PHP:**
```php
$client = new MongoDB\Client("mongodb://mongodb:27017");
$collection = $client->mydb->mycollection;
```

### Swoole Extension (High-Performance PHP)

```dockerfile
FROM ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm

RUN apt-get update && apt-get install -y $PHPIZE_DEPS && \
    pecl install swoole-5.1.5 && \
    docker-php-ext-enable swoole && \
    apk del $PHPIZE_DEPS
```

### Memcached Extension

```dockerfile
FROM ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm

RUN apt-get update && apt-get install -y $PHPIZE_DEPS libmemcached-dev zlib-dev && \
    pecl install memcached-3.3.0 && \
    docker-php-ext-enable memcached && \
    apk del $PHPIZE_DEPS
```

### GRPc Extension (for microservices)

```dockerfile
FROM ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm

RUN apt-get update && apt-get install -y $PHPIZE_DEPS linux-headers && \
    pecl install grpc-1.68.0 && \
    docker-php-ext-enable grpc && \
    apk del $PHPIZE_DEPS
```

### Decimal Extension (for financial calculations)

```dockerfile
FROM ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm

RUN apt-get update && apt-get install -y $PHPIZE_DEPS mpdecimal-dev && \
    pecl install decimal-2.0.0 && \
    docker-php-ext-enable decimal && \
    apk del $PHPIZE_DEPS
```

---

## Custom Initialization Scripts

Cbox images support custom initialization scripts that run **before** PHP-FPM and Nginx start.

### How It Works

1. Create executable scripts in `/docker-entrypoint-init.d/`
2. Scripts run in alphabetical order during container startup
3. Scripts run as root (be careful!)
4. Perfect for setup tasks like waiting for databases, seeding data, etc.

### Example 1: Wait for Database

Create `docker/wait-for-db.sh`:

```bash
#!/bin/bash
# Wait for database to be ready before starting application

set -e

echo "Waiting for MySQL to be ready..."

until docker-compose exec -T mysql mysqladmin ping -h mysql --silent; do
    echo "MySQL is unavailable - sleeping"
    sleep 2
done

echo "MySQL is up - continuing"
```

Add to Dockerfile:

```dockerfile
FROM ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm

# Copy initialization script
COPY docker/wait-for-db.sh /docker-entrypoint-init.d/01-wait-for-db.sh
RUN chmod +x /docker-entrypoint-init.d/01-wait-for-db.sh
```

**Note:** The `01-` prefix ensures it runs first (alphabetical order).

### Example 2: Run Database Migrations

Create `docker/run-migrations.sh`:

```bash
#!/bin/bash
# Run Laravel migrations on startup (only for development!)

set -e

# Only run in development
if [ "$APP_ENV" = "local" ] || [ "$APP_ENV" = "development" ]; then
    echo "Running database migrations..."
    cd /var/www/html
    php artisan migrate --force
    echo "Migrations complete"
fi
```

Add to Dockerfile:

```dockerfile
FROM ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm

COPY docker/run-migrations.sh /docker-entrypoint-init.d/02-run-migrations.sh
RUN chmod +x /docker-entrypoint-init.d/02-run-migrations.sh
```

### Example 3: Generate Application Key

Create `docker/generate-key.sh`:

```bash
#!/bin/bash
# Generate Laravel application key if not set

set -e

cd /var/www/html

# Check if APP_KEY is empty
if [ -z "$APP_KEY" ] || [ "$APP_KEY" = "base64:" ]; then
    echo "Generating application key..."
    php artisan key:generate --force
    echo "Application key generated"
else
    echo "Application key already set"
fi
```

Add to Dockerfile:

```dockerfile
FROM ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm

COPY docker/generate-key.sh /docker-entrypoint-init.d/03-generate-key.sh
RUN chmod +x /docker-entrypoint-init.d/03-generate-key.sh
```

### Example 4: Custom Environment Setup

Create `docker/setup-environment.sh`:

```bash
#!/bin/bash
# Custom environment setup

set -e

echo "Setting up custom environment..."

# Create required directories
mkdir -p /var/www/html/storage/uploads
mkdir -p /var/www/html/storage/exports

# Set correct permissions
chown -R www-data:www-data /var/www/html/storage
chmod -R 775 /var/www/html/storage

# Link storage (for Laravel)
if [ -d "/var/www/html/public" ] && [ ! -L "/var/www/html/public/storage" ]; then
    ln -s /var/www/html/storage/app/public /var/www/html/public/storage
fi

echo "Environment setup complete"
```

---

## Best Practices

### 1. Always Start with Cbox Base

❌ **Wrong:**
```dockerfile
FROM php:8.3-fpm-bookworm
# Now you need to install everything yourself...
```

✅ **Correct:**
```dockerfile
FROM ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm
# Everything is already configured!
```

### 2. Version Your PECL Extensions

❌ **Wrong:**
```dockerfile
RUN pecl install redis  # Gets latest, might break
```

✅ **Correct:**
```dockerfile
RUN pecl install redis-6.1.0  # Locked version
```

### 3. Clean Up Build Dependencies

❌ **Wrong:**
```dockerfile
RUN apt-get update && apt-get install -y $PHPIZE_DEPS
RUN pecl install mongodb
# Leaves build tools in final image (+50MB!)
```

✅ **Correct:**
```dockerfile
RUN apt-get update && apt-get install -y $PHPIZE_DEPS && \
    pecl install mongodb && \
    docker-php-ext-enable mongodb && \
    apk del $PHPIZE_DEPS  # ← Removes build tools
```

### 4. Use Multi-Stage Builds for Complex Images

Separate build and runtime stages to keep production images small:

```dockerfile
# Build stage with all tools
FROM node:20-alpine AS frontend-builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Production stage - small and secure
FROM ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm
COPY --from=frontend-builder /app/public/build /var/www/html/public/build
```

### 5. Test Locally Before Deploying

```bash
# Build image
docker build -t my-app:test .

# Test it works
docker run --rm my-app:test php -v

# Test extensions
docker run --rm my-app:test php -m | grep mongodb

# Interactive testing
docker run --rm -it my-app:test /bin/bash
```

### 6. Keep Dockerfiles Readable

Use comments and logical grouping:

```dockerfile
FROM ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm

# ======================
# PHP Extensions
# ======================
RUN apt-get update && apt-get install -y $PHPIZE_DEPS && \
    # Database extensions
    pecl install mongodb-1.20.1 && \
    # Caching extensions
    pecl install memcached-3.3.0 && \
    # Enable all
    docker-php-ext-enable mongodb memcached && \
    # Cleanup
    apk del $PHPIZE_DEPS

# ======================
# System Packages
# ======================
RUN apt-get update && apt-get install -y \
    ffmpeg \
    imagemagick \
    nodejs \
    npm

# ======================
# Application Setup
# ======================
COPY . /var/www/html
RUN composer install --no-dev
```

---

## Troubleshooting

### Extension Not Loading

**Check if extension is installed:**
```bash
docker-compose exec app php -m | grep extension_name
```

**If not listed, check for errors:**
```bash
docker-compose exec app php -i | grep extension_name
```

**Check PHP error log:**
```bash
docker-compose exec app tail -f /var/log/php-fpm.log
```

### Build Failures

**Enable verbose build output:**
```bash
docker build --progress=plain --no-cache -t my-app:test .
```

**Common build errors:**

**Error: "pecl/mongodb requires PHP (version >= 8.2.0)"**
- Solution: Use PHP 8.2+ base image

**Error: "mpdecimal.h: No such file"**
- Solution: Install development headers: `apt-get update && apt-get install -y libmpdec-dev`

**Error: "Cannot find autoconf"**
- Solution: Install build tools: `apt-get update && apt-get install -y build-essential`

### Image Too Large

**Check image size:**
```bash
docker images my-app:test
```

**Common causes:**
1. Not removing build dependencies (`apk del $PHPIZE_DEPS`)
2. Including unnecessary files (use `.dockerignore`)
3. Not using multi-stage builds

**Create `.dockerignore`:**
```
node_modules/
.git/
.env
tests/
*.md
.github/
```

### Permission Issues

**Error: "Permission denied" in container**

**Solution: Fix ownership:**
```dockerfile
FROM ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm

COPY --chown=www-data:www-data . /var/www/html

RUN chmod -R 755 storage bootstrap/cache && \
    chmod -R 777 storage/logs storage/framework
```

---

## Next Steps

- **[Custom Extensions Guide](custom-extensions.md)** - Deep dive into PECL extensions
- **[Performance Tuning](performance-tuning.md)** - Optimize PHP/Nginx for production
- **[Security Hardening](security-hardening.md)** - Secure your custom images
- **[CI/CD Integration](ci-cd-integration.md)** - Automate builds and deployments

---

**Questions or Issues?** Check our [Troubleshooting Guide](../troubleshooting/common-issues.md) or [open an issue on GitHub](https://github.com/cboxdk/baseimages/issues).
