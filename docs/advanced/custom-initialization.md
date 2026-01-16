---
title: "Custom Initialization"
description: "Startup scripts, wait-for-dependency patterns, database migrations, and dynamic configuration"
weight: 6
---

# Custom Initialization

Cbox provides hooks for running custom code at container startup. Use these for database migrations, waiting for services, cache warming, and dynamic configuration.

## Initialization Methods

### Method 1: Init Scripts Directory

Place executable scripts in `/docker-entrypoint-init.d/`:

```dockerfile
FROM ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm

COPY scripts/init-*.sh /docker-entrypoint-init.d/
RUN chmod +x /docker-entrypoint-init.d/*.sh
```

**Execution order**: Scripts run alphabetically by filename.

```
/docker-entrypoint-init.d/
  01-wait-for-db.sh      # Runs first
  02-run-migrations.sh   # Runs second
  03-cache-warmup.sh     # Runs third
```

### Method 2: Environment Variables

Use built-in Laravel features:

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm
    environment:
      LARAVEL_MIGRATE_ENABLED: "true"    # Run migrations
      LARAVEL_OPTIMIZE_ENABLED: "true"   # Cache config/routes
```

### Method 3: Custom Entrypoint

For complete control:

```dockerfile
FROM ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm

COPY custom-entrypoint.sh /usr/local/bin/custom-entrypoint.sh
RUN chmod +x /usr/local/bin/custom-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/custom-entrypoint.sh"]
```

```bash
#!/bin/bash
# custom-entrypoint.sh

# Your custom initialization
echo "Running custom initialization..."
# ... your code ...

# Call original entrypoint
exec /usr/local/bin/docker-entrypoint.sh "$@"
```

## Common Patterns

### Wait for Database

```bash
#!/bin/bash
# /docker-entrypoint-init.d/01-wait-for-db.sh

set -e

MAX_RETRIES=30
RETRY_INTERVAL=2

echo "Waiting for database..."

for i in $(seq 1 $MAX_RETRIES); do
    if php artisan db:monitor --database=mysql 2>/dev/null; then
        echo "Database is ready!"
        exit 0
    fi
    echo "Attempt $i/$MAX_RETRIES: Database not ready, waiting ${RETRY_INTERVAL}s..."
    sleep $RETRY_INTERVAL
done

echo "ERROR: Database not available after $MAX_RETRIES attempts"
exit 1
```

### Wait for Redis

```bash
#!/bin/bash
# /docker-entrypoint-init.d/01-wait-for-redis.sh

set -e

REDIS_HOST="${REDIS_HOST:-redis}"
REDIS_PORT="${REDIS_PORT:-6379}"
MAX_RETRIES=30

echo "Waiting for Redis at $REDIS_HOST:$REDIS_PORT..."

for i in $(seq 1 $MAX_RETRIES); do
    if nc -z "$REDIS_HOST" "$REDIS_PORT" 2>/dev/null; then
        echo "Redis is ready!"
        exit 0
    fi
    echo "Attempt $i/$MAX_RETRIES: Redis not ready..."
    sleep 2
done

echo "ERROR: Redis not available"
exit 1
```

### Run Migrations

```bash
#!/bin/bash
# /docker-entrypoint-init.d/02-run-migrations.sh

set -e

if [ -f "/var/www/html/artisan" ]; then
    echo "Running database migrations..."

    if [ "${APP_ENV:-production}" = "production" ]; then
        php artisan migrate --force --no-interaction
    else
        php artisan migrate --no-interaction
    fi

    echo "Migrations completed!"
fi
```

### Cache Warmup (Laravel)

```bash
#!/bin/bash
# /docker-entrypoint-init.d/03-cache-warmup.sh

set -e

if [ -f "/var/www/html/artisan" ]; then
    echo "Warming up caches..."

    php artisan config:cache
    php artisan route:cache
    php artisan view:cache
    php artisan event:cache

    echo "Cache warmup completed!"
fi
```

### Generate App Key (If Missing)

```bash
#!/bin/bash
# /docker-entrypoint-init.d/00-generate-key.sh

set -e

if [ -f "/var/www/html/artisan" ]; then
    # Check if APP_KEY is set
    if [ -z "${APP_KEY}" ] || [ "${APP_KEY}" = "base64:" ]; then
        echo "WARNING: APP_KEY not set, generating..."
        php artisan key:generate --force
    fi
fi
```

### Fix Permissions

```bash
#!/bin/bash
# /docker-entrypoint-init.d/00-fix-permissions.sh

set -e

WORKDIR="${WORKDIR:-/var/www/html}"

echo "Fixing permissions..."

# Laravel directories
for dir in storage bootstrap/cache; do
    if [ -d "$WORKDIR/$dir" ]; then
        chown -R www-data:www-data "$WORKDIR/$dir"
        chmod -R 775 "$WORKDIR/$dir"
    fi
done

echo "Permissions fixed!"
```

### Dynamic Configuration

```bash
#!/bin/bash
# /docker-entrypoint-init.d/01-dynamic-config.sh

set -e

# Generate config from environment
cat > /var/www/html/config/dynamic.php << EOF
<?php
return [
    'api_url' => '${API_URL}',
    'feature_flags' => [
        'new_feature' => ${FEATURE_NEW:-false},
    ],
];
EOF

echo "Dynamic configuration generated!"
```

### Download Remote Configuration

```bash
#!/bin/bash
# /docker-entrypoint-init.d/01-fetch-config.sh

set -e

CONFIG_URL="${CONFIG_URL:-}"

if [ -n "$CONFIG_URL" ]; then
    echo "Fetching configuration from $CONFIG_URL..."
    curl -sSL "$CONFIG_URL" -o /var/www/html/.env.remote

    # Merge with existing
    if [ -f /var/www/html/.env ]; then
        cat /var/www/html/.env.remote >> /var/www/html/.env
    fi
fi
```

## Docker Compose Examples

### Complete Laravel Setup

```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm
    volumes:
      - .:/var/www/html
      - ./docker/init:/docker-entrypoint-init.d:ro
    environment:
      DB_HOST: db
      REDIS_HOST: redis
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy

  db:
    image: mysql:8.0
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 5s
      timeout: 3s
      retries: 10

  redis:
    image: redis:7-alpine
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 10
```

### Init Scripts Directory

```
docker/
  init/
    01-wait-for-services.sh
    02-run-migrations.sh
    03-seed-database.sh
    04-cache-warmup.sh
```

## Kubernetes Patterns

### Init Containers

```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      initContainers:
        # Wait for database
        - name: wait-for-db
          image: busybox:1.36
          command: ['sh', '-c', 'until nc -z db 3306; do sleep 2; done']

        # Run migrations
        - name: migrations
          image: ghcr.io/cboxdk/baseimages/php-cli:8.4-bookworm
          command: ['php', 'artisan', 'migrate', '--force']
          volumeMounts:
            - name: app
              mountPath: /var/www/html

      containers:
        - name: app
          image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm
```

### Lifecycle Hooks

```yaml
containers:
  - name: app
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm
    lifecycle:
      postStart:
        exec:
          command: ["/bin/sh", "-c", "php artisan cache:clear"]
      preStop:
        exec:
          command: ["/bin/sh", "-c", "php artisan down"]
```

## Error Handling

### Exit on Failure

```bash
#!/bin/bash
set -e  # Exit on any error

# Commands that must succeed
php artisan migrate --force || exit 1
```

### Continue on Failure

```bash
#!/bin/bash
# Don't use set -e

# Non-critical operation
php artisan cache:clear || echo "WARNING: Cache clear failed"

# Critical operation - explicit check
if ! php artisan migrate --force; then
    echo "ERROR: Migration failed"
    exit 1
fi
```

### Conditional Execution

```bash
#!/bin/bash
set -e

# Only run in production
if [ "${APP_ENV}" = "production" ]; then
    php artisan config:cache
    php artisan route:cache
fi

# Only run if flag is set
if [ "${RUN_MIGRATIONS:-false}" = "true" ]; then
    php artisan migrate --force
fi
```

## Debugging Init Scripts

### Enable Verbose Output

```bash
#!/bin/bash
set -ex  # -x prints each command

echo "DEBUG: Starting initialization"
echo "DEBUG: APP_ENV=$APP_ENV"
```

### Check Script Execution

```bash
# List init scripts
docker exec myapp ls -la /docker-entrypoint-init.d/

# Run specific script manually
docker exec myapp /docker-entrypoint-init.d/02-migrations.sh

# Check script permissions
docker exec myapp stat /docker-entrypoint-init.d/02-migrations.sh
```

### Watch Container Logs

```bash
# Real-time logs during startup
docker logs -f myapp

# Filter for init messages
docker logs myapp 2>&1 | grep -i "init\|migration\|cache"
```

## Best Practices

### 1. Use Numbered Prefixes

```
01-wait.sh      # Dependencies first
02-migrate.sh   # Database changes
03-seed.sh      # Data population
04-cache.sh     # Cache warming
```

### 2. Keep Scripts Idempotent

```bash
# Good: Can run multiple times safely
php artisan migrate --force

# Bad: Fails on second run
php artisan db:seed  # Use --force or check first
```

### 3. Fail Fast

```bash
#!/bin/bash
set -e  # Stop on first error

# Critical operations at the top
php artisan migrate --force

# Non-critical at the bottom
php artisan cache:clear || true
```

### 4. Log Everything

```bash
#!/bin/bash
echo "$(date): Starting initialization..."
echo "$(date): Environment: ${APP_ENV}"
echo "$(date): Database: ${DB_HOST}"
```

### 5. Use Health Checks

```yaml
services:
  app:
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      start_period: 60s  # Give init scripts time to complete
```

## Next Steps

- **[Extending Images](extending-images.md)** - Custom Dockerfiles
- **[Custom Extensions](custom-extensions.md)** - Add PHP extensions
- **[Performance Tuning](performance-tuning.md)** - Optimize startup time
