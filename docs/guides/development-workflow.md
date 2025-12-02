---
title: "Development Workflow Guide"
description: "Optimize your local development workflow with PHPeek including Xdebug setup, hot-reload, testing, and debugging strategies"
weight: 15
---

# Development Workflow Guide

Optimize your local development experience with PHPeek base images including Xdebug, hot-reload, testing, and efficient debugging.

## Table of Contents

- [Local Development Setup](#local-development-setup)
- [Xdebug Configuration](#xdebug-configuration)
- [Hot-Reload Setup](#hot-reload-setup)
- [Testing Workflow](#testing-workflow)
- [Debugging Strategies](#debugging-strategies)
- [Database Management](#database-management)
- [Git Workflow Integration](#git-workflow-integration)
- [Performance Tips](#performance-tips)

## Local Development Setup

### Using Pre-built Development Images (Recommended)

PHPeek provides **pre-built development images** with Xdebug already installed and configured. These are the easiest way to get started with debugging.

**Available dev images:**
- `ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine-dev`
- `ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.3-alpine-dev`
- `ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.2-alpine-dev`
- Also available: `-debian-dev` variant

### Development docker-compose.yml

```yaml
version: '3.8'

services:
  app:
    # Use the pre-built dev image with Xdebug included!
    image: ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine-dev
    ports:
      - "8000:80"
      - "9003:9003"  # Xdebug port
    volumes:
      # Bind mount for hot-reload
      - ./:/var/www/html
    environment:
      # Xdebug configuration
      - XDEBUG_MODE=debug,develop,coverage
      - XDEBUG_CONFIG=client_host=host.docker.internal client_port=9003
      - PHP_IDE_CONFIG=serverName=docker

      # Application
      - APP_ENV=local
      - APP_DEBUG=true
      - DB_HOST=mysql
      - REDIS_HOST=redis
    depends_on:
      - mysql
      - redis
      - mailhog

  mysql:
    image: mysql:8.3
    ports:
      - "3306:3306"
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: development
      MYSQL_USER: dev
      MYSQL_PASSWORD: dev
    volumes:
      - mysql-data:/var/lib/mysql
      # Seed database on startup
      - ./docker/mysql/init:/docker-entrypoint-initdb.d:ro
    command: --default-authentication-plugin=mysql_native_password

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  mailhog:
    image: mailhog/mailhog:latest
    ports:
      - "8025:8025"  # Web UI
      - "1025:1025"  # SMTP

volumes:
  mysql-data:
```

### PHP Development Configuration

**Create `docker/php/development.ini`:**

```ini
[PHP]
; Display all errors
display_errors = On
display_startup_errors = On
error_reporting = E_ALL
log_errors = On

; Generous limits for development
memory_limit = 256M
max_execution_time = 300
upload_max_filesize = 100M
post_max_size = 120M

; OPcache for development
opcache.enable = 1
opcache.validate_timestamps = 1
opcache.revalidate_freq = 0
opcache.max_accelerated_files = 10000

[xdebug]
; Xdebug 3 configuration
xdebug.mode = debug,coverage
xdebug.start_with_request = yes
xdebug.client_host = host.docker.internal
xdebug.client_port = 9003
xdebug.log_level = 0

; Coverage settings
xdebug.coverage_enable = 1

; Profiling (enable when needed)
; xdebug.mode = profile
; xdebug.output_dir = /var/www/html/storage/xdebug
```

### Start Development Environment

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f app

# Check services
docker-compose ps

# Access application
open http://localhost:8000
```

## Xdebug Configuration

### VS Code Setup

**Install Extension:**
- Search for "PHP Debug" by Xdebug
- Install the extension

**Create `.vscode/launch.json`:**

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Listen for Xdebug",
      "type": "php",
      "request": "launch",
      "port": 9003,
      "pathMappings": {
        "/var/www/html": "${workspaceFolder}"
      },
      "log": false,
      "xdebugSettings": {
        "max_data": 65535,
        "show_hidden": 1,
        "max_children": 100,
        "max_depth": 5
      }
    }
  ]
}
```

**Usage:**
1. Set breakpoints in your PHP files
2. Click "Run and Debug" (or press F5)
3. Select "Listen for Xdebug"
4. Access your application in browser
5. Debugger will stop at breakpoints

### PHPStorm Setup

**Configure Xdebug:**
1. Go to Settings → PHP → Debug
2. Set Xdebug port to `9003`
3. Enable "Break at first line in PHP scripts"

**Configure Server:**
1. Go to Settings → PHP → Servers
2. Add new server:
   - Name: `docker`
   - Host: `localhost`
   - Port: `8000`
   - Debugger: `Xdebug`
3. Enable "Use path mappings"
4. Map project root to `/var/www/html`

**Usage:**
1. Set breakpoints
2. Click "Start Listening for PHP Debug Connections"
3. Access your application
4. PHPStorm will stop at breakpoints

### Xdebug CLI Debugging

Debug artisan commands or scripts:

```bash
# Enable Xdebug for CLI
docker-compose exec app sh -c 'export XDEBUG_MODE=debug && php artisan migrate'

# Debug specific script
docker-compose exec app sh -c 'export XDEBUG_MODE=debug && php script.php'
```

### Xdebug Performance Impact

Xdebug can slow down your application. Disable when not debugging:

```yaml
services:
  app:
    environment:
      # Disable Xdebug
      - XDEBUG_MODE=off

      # Or enable only when needed
      - XDEBUG_MODE=${XDEBUG_MODE:-off}
```

```bash
# Enable Xdebug
XDEBUG_MODE=debug docker-compose up -d

# Disable Xdebug
XDEBUG_MODE=off docker-compose up -d
````

### macOS/Windows Performance Boost (Optional)

Bind mounts on Docker Desktop can feel sluggish with large projects. Use a file-sync helper (Mutagen or Docker Desktop VirtioFS) to keep DX fast without touching your PHPeek stack.

**Mutagen workflow:**

```bash
brew install mutagen-io/mutagen/mutagen

# Start services as usual
docker compose up -d

# Sync host source to the container webroot
mutagen sync create ./ app://phpeek-app/var/www/html
```

> Replace `phpeek-app` with the container name from `docker compose ps`. Mutagen mirrors files quickly while PHPeek still sees a bind mount.

Prefer native tooling? Enable **VirtioFS** under Docker Desktop → Settings → Resources → File Sharing for a big speed-up on macOS/Windows.

## Hot-Reload Setup

### File Watching with Bind Mounts

Already configured with bind mounts:

```yaml
services:
  app:
    volumes:
      - ./:/var/www/html  # Changes reflect immediately
```

**How it works:**
- File changes on host → Immediately visible in container
- OPcache revalidation enabled → PHP sees changes
- No container restart needed

### Asset Compilation (Laravel Mix/Vite)

**Install Node.js in container (Dockerfile.dev):**

```dockerfile
FROM ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.3-alpine

# Install Node.js
RUN apk add --no-cache nodejs npm

USER root
WORKDIR /var/www/html
```

**Or run Node.js separately:**

```yaml
services:
  # ... app service

  node:
    image: node:20-alpine
    working_dir: /app
    volumes:
      - ./:/app
    command: npm run dev
    ports:
      - "5173:5173"  # Vite HMR
```

**Laravel Vite Configuration:**

```js
// vite.config.js
import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';

export default defineConfig({
    plugins: [
        laravel({
            input: ['resources/css/app.css', 'resources/js/app.js'],
            refresh: true,
        }),
    ],
    server: {
        host: '0.0.0.0',  // Allow external connections
        hmr: {
            host: 'localhost',
        },
    },
});
```

## Testing Workflow

### PHPUnit Testing

**Run tests in container:**

```bash
# Run all tests
docker-compose exec app php artisan test

# Run specific test file
docker-compose exec app php artisan test tests/Feature/AuthTest.php

# Run with coverage
docker-compose exec app php artisan test --coverage

# Run specific test method
docker-compose exec app php artisan test --filter testUserCanLogin
```

### Pest Testing (Laravel)

```bash
# Run all Pest tests
docker-compose exec app ./vendor/bin/pest

# Run specific file
docker-compose exec app ./vendor/bin/pest tests/Feature/AuthTest.php

# Watch mode (re-run on changes)
docker-compose exec app ./vendor/bin/pest --watch

# Coverage
docker-compose exec app ./vendor/bin/pest --coverage
```

### Testing with Separate Database

```yaml
services:
  # ... app service

  mysql-test:
    image: mysql:8.3
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: testing
    tmpfs:
      - /var/lib/mysql  # In-memory for speed
```

**Update phpunit.xml:**

```xml
<php>
    <env name="DB_CONNECTION" value="mysql"/>
    <env name="DB_HOST" value="mysql-test"/>
    <env name="DB_DATABASE" value="testing"/>
</php>
```

### Parallel Testing

```bash
# Install parallel testing
docker-compose exec app composer require --dev brianium/paratest

# Run tests in parallel
docker-compose exec app php artisan test --parallel

# Specify process count
docker-compose exec app php artisan test --parallel --processes=4
```

## Debugging Strategies

### Laravel Debugbar

**Install:**

```bash
docker-compose exec app composer require barryvdh/laravel-debugbar --dev
```

**Configuration (.env):**

```
DEBUGBAR_ENABLED=true
```

**Access:** Bottom of your Laravel application pages

### Laravel Telescope

**Install:**

```bash
docker-compose exec app composer require laravel/telescope --dev
docker-compose exec app php artisan telescope:install
docker-compose exec app php artisan migrate
```

**Access:** http://localhost:8000/telescope

### Logging Best Practices

**Use structured logging:**

```php
// Laravel
Log::info('User logged in', [
    'user_id' => $user->id,
    'ip' => $request->ip(),
]);

// Symfony
$logger->info('User logged in', [
    'user_id' => $user->getId(),
    'ip' => $request->getClientIp(),
]);
```

**View logs:**

```bash
# Tail application logs
docker-compose logs -f app

# Search logs
docker-compose logs app | grep "ERROR"

# Export logs
docker-compose logs app > debug.log
```

### Database Query Debugging

**Laravel:**

```php
// Log all queries
DB::listen(function ($query) {
    Log::info($query->sql, $query->bindings);
});

// Or use Laravel Debugbar (shows queries in browser)
```

**Symfony:**

```yaml
# config/packages/dev/doctrine.yaml
doctrine:
    dbal:
        logging: true
        profiling: true
```

### API Debugging Tools

```bash
# Test API endpoints with curl
docker-compose exec app curl http://localhost/api/users

# Or use HTTPie
docker-compose exec app apk add httpie
docker-compose exec app http GET http://localhost/api/users
```

## Database Management

### Database GUI Tools

**Adminer (Lightweight):**

```yaml
services:
  adminer:
    image: adminer:latest
    ports:
      - "8080:8080"
    environment:
      ADMINER_DEFAULT_SERVER: mysql
```

Access: http://localhost:8080

**phpMyAdmin:**

```yaml
services:
  phpmyadmin:
    image: phpmyadmin:latest
    ports:
      - "8080:80"
    environment:
      PMA_HOST: mysql
      PMA_USER: root
      PMA_PASSWORD: root
```

### Database Seeding

**Laravel:**

```bash
# Run migrations
docker-compose exec app php artisan migrate

# Seed database
docker-compose exec app php artisan db:seed

# Fresh migration with seed
docker-compose exec app php artisan migrate:fresh --seed
```

**Symfony:**

```bash
# Run migrations
docker-compose exec app php bin/console doctrine:migrations:migrate

# Load fixtures
docker-compose exec app php bin/console doctrine:fixtures:load
```

### Database Backups

```bash
# Backup database
docker-compose exec mysql mysqldump -u root -proot development > backup.sql

# Restore database
docker-compose exec -T mysql mysql -u root -proot development < backup.sql

# Copy database to another container
docker-compose exec mysql mysqldump -u root -proot development | \
  docker-compose exec -T mysql-test mysql -u root -proot testing
```

## Git Workflow Integration

### Pre-Commit Hooks

**Install PHP CS Fixer:**

```bash
docker-compose exec app composer require --dev friendsofphp/php-cs-fixer
```

**Create `.git/hooks/pre-commit`:**

```bash
#!/bin/bash

# Run PHP CS Fixer
docker-compose exec -T app ./vendor/bin/php-cs-fixer fix --dry-run --diff

if [ $? -ne 0 ]; then
    echo "❌ Code style issues found. Run: docker-compose exec app ./vendor/bin/php-cs-fixer fix"
    exit 1
fi

# Run tests
docker-compose exec -T app php artisan test

if [ $? -ne 0 ]; then
    echo "❌ Tests failed"
    exit 1
fi

echo "✅ Pre-commit checks passed"
```

```bash
# Make executable
chmod +x .git/hooks/pre-commit
```

### Husky Alternative (PHP)

**Install GrumPHP:**

```bash
docker-compose exec app composer require --dev phpro/grumphp
```

**Create `grumphp.yml`:**

```yaml
grumphp:
  tasks:
    phpcs:
      standard: PSR12
    phpunit:
      always_execute: false
    composer:
      no_check_all: true
```

### Branch-Based Environments

```yaml
# docker-compose.override.yml (gitignored)
services:
  app:
    environment:
      - APP_ENV=${GIT_BRANCH:-local}
      - DB_DATABASE=app_${GIT_BRANCH:-local}
```

```bash
# Automatically use branch name
export GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
docker-compose up -d
```

## Performance Tips

### Optimize Docker Performance

**macOS (Docker Desktop):**

```yaml
# Use delegated mode for better performance
services:
  app:
    volumes:
      - ./:/var/www/html:delegated
```

**Linux:** Native performance, no optimization needed

**Windows (WSL 2):** Keep files in WSL filesystem

### Reduce Build Time

**Use BuildKit:**

```bash
# Enable BuildKit
export DOCKER_BUILDKIT=1

# Build with cache
docker-compose build
```

### Optimize Composer Install

```dockerfile
# Cache composer dependencies
FROM ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.3-alpine

COPY composer.json composer.lock ./
RUN composer install --no-scripts --no-autoloader

COPY . .
RUN composer dump-autoload --optimize
```

### Development vs Production Images

**Dockerfile.dev:**

```dockerfile
FROM ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.3-alpine

# Install Xdebug
RUN apk add --no-cache $PHPIZE_DEPS \
    && pecl install xdebug \
    && docker-php-ext-enable xdebug

# Install Node.js for asset compilation
RUN apk add --no-cache nodejs npm

# Development tools
RUN apk add --no-cache git vim
```

**Dockerfile.prod:**

```dockerfile
FROM ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.3-alpine

# Production optimizations only
COPY --chown=www-data:www-data . /var/www/html

RUN composer install --no-dev --optimize-autoloader
```

## Quick Development Commands

### Makefile

**Create `Makefile`:**

```makefile
.PHONY: help

help:
	@echo "Available commands:"
	@echo "  make up         - Start development environment"
	@echo "  make down       - Stop development environment"
	@echo "  make logs       - View logs"
	@echo "  make shell      - Open shell in app container"
	@echo "  make test       - Run tests"
	@echo "  make migrate    - Run migrations"
	@echo "  make seed       - Seed database"
	@echo "  make fresh      - Fresh migration with seed"

up:
	docker-compose up -d

down:
	docker-compose down

logs:
	docker-compose logs -f app

shell:
	docker-compose exec app sh

test:
	docker-compose exec app php artisan test

migrate:
	docker-compose exec app php artisan migrate

seed:
	docker-compose exec app php artisan db:seed

fresh:
	docker-compose exec app php artisan migrate:fresh --seed

fix:
	docker-compose exec app ./vendor/bin/php-cs-fixer fix
```

**Usage:**

```bash
make up
make test
make fresh
```

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker-compose logs app

# Rebuild without cache
docker-compose build --no-cache

# Remove all containers and volumes
docker-compose down -v
```

### Permission Issues

```bash
# Fix permissions
docker-compose exec app chown -R www-data:www-data /var/www/html/storage

# Or set PUID/PGID
docker-compose exec app sh -c 'export PUID=1000 PGID=1000'
```

### Xdebug Not Working

```bash
# Verify Xdebug is enabled
docker-compose exec app php -m | grep xdebug

# Check Xdebug configuration
docker-compose exec app php -i | grep xdebug

# Test connection
docker-compose exec app php -r "xdebug_info();"
```

### Slow Performance

```bash
# Disable Xdebug when not debugging
XDEBUG_MODE=off docker-compose up -d

# Use delegated mounts (macOS)
volumes:
  - ./:/var/www/html:delegated

# Check Docker resource allocation (Docker Desktop → Settings → Resources)
```

## Related Documentation

- [Laravel Guide](laravel-guide) - Laravel-specific development
- [Symfony Guide](symfony-guide) - Symfony-specific development
- [Extending Images](../advanced/extending-images) - Custom development images
- [Debugging Guide](../troubleshooting/debugging-guide) - Advanced debugging

---

**Questions?** Check [common issues](../troubleshooting/common-issues) or ask in [GitHub Discussions](https://github.com/phpeek/baseimages/discussions).
