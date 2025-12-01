---
title: "Magento Guide"
description: "Deploy Magento 2 with PHPeek including MySQL, OpenSearch, Redis, and cron"
weight: 30
---

# Magento Guide

Run Magento 2 with PHPeek base images plus the required search, cache, and cron services.

## Quick Start

```yaml
# docker-compose.magento.yml
version: '3.8'

services:
  app:
    image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine
    ports:
      - "8080:80"
    volumes:
      - ./:/var/www/html
    environment:
      - APP_ENV=local
      - MAGENTO_MODE=developer
      - DB_HOST=mysql
      - DB_DATABASE=magento
      - DB_USERNAME=magento
      - DB_PASSWORD=secret
      - REDIS_HOST=redis
      - ELASTICSEARCH_HOST=opensearch
      - LARAVEL_SCHEDULER=true          # Enables cron (bin/magento cron:run)
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_healthy
      opensearch:
        condition: service_started

  mysql:
    image: mysql:8.0
    environment:
      MYSQL_DATABASE: magento
      MYSQL_USER: magento
      MYSQL_PASSWORD: secret
      MYSQL_ROOT_PASSWORD: root_secret
    volumes:
      - mysql-data:/var/lib/mysql
    command: --default-authentication-plugin=mysql_native_password
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 5s
      timeout: 3s
      retries: 10

  redis:
    image: redis:7-alpine
    command: ["redis-server", "--save", "", "--appendonly", "no"]

  opensearch:
    image: opensearchproject/opensearch:2.15.0
    environment:
      - discovery.type=single-node
      - plugins.security.disabled=true
      - OPENSEARCH_JAVA_OPTS=-Xms512m -Xmx512m
    ulimits:
      memlock:
        soft: -1
        hard: -1
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9200"]
      interval: 30s
      timeout: 10s
      retries: 5

volumes:
  mysql-data:
```

## Install Magento

```bash
composer create-project --repository-url=https://repo.magento.com/ magento/project-community-edition magento
mv magento/* .
rm -rf magento

docker compose -f docker-compose.magento.yml up -d --wait
docker compose exec app bin/magento setup:install \
  --base-url=http://localhost:8080 \
  --db-host=mysql \
  --db-name=magento \
  --db-user=magento \
  --db-password=secret \
  --backend-frontname=admin \
  --admin-firstname=Admin \
  --admin-lastname=User \
  --admin-email=admin@example.com \
  --admin-user=admin \
  --admin-password=Admin123! \
  --language=en_US \
  --currency=USD \
  --timezone=UTC \
  --use-rewrites=1 \
  --elasticsearch-host=opensearch \
  --elasticsearch-port=9200
```

## Cache & Sessions

Enable Redis for cache + sessions in `app/etc/env.php`:

```php
'cache' => [
    'frontend' => [
        'default' => [
            'backend' => 'Cm_Cache_Backend_Redis',
            'backend_options' => [
                'server' => 'redis',
                'port' => '6379',
                'database' => '0',
            ],
        ],
        'page_cache' => [
            'backend' => 'Cm_Cache_Backend_Redis',
            'backend_options' => [
                'server' => 'redis',
                'port' => '6379',
                'database' => '1',
            ],
        ],
    ],
],
'session' => [
    'save' => 'redis',
    'redis' => [
        'host' => 'redis',
        'port' => '6379',
        'database' => '2',
    ],
],
```

## Cron & Queue

Magento requires cron every minute. PHPeek handles that when `LARAVEL_SCHEDULER=true`:

```bash
docker compose exec app bin/magento cron:install
docker compose exec app bin/magento cron:run
```

## Development Tips

- Use `ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine-dev` for Xdebug.
- Disable static content deployment for faster dev: `bin/magento deploy:mode:set developer`.
- Flush caches quickly: `bin/magento cache:flush`.

## Production Checklist

```yaml
services:
  app:
    image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine
    volumes:
      - ./:/var/www/html:ro
      - ./var:/var/www/html/var
      - ./pub/media:/var/www/html/pub/media
      - ./generated:/var/www/html/generated
    environment:
      - APP_ENV=production
      - PHP_DISPLAY_ERRORS=Off
      - PHP_OPCACHE_VALIDATE_TIMESTAMPS=0
      - LARAVEL_SCHEDULER=true
```

```bash
bin/magento deploy:mode:set production
bin/magento setup:di:compile
bin/magento setup:static-content:deploy -f
bin/magento cache:flush
```

## Troubleshooting

- **Search not indexing**: check OpenSearch logs via `docker compose logs opensearch` and verify host/port.
- **Cron stalled**: run `docker compose exec app bin/magento cron:run --group=index` and ensure scheduler env var is set.
- **File permissions**: fix with `docker compose exec app chown -R www-data:www-data var pub/media generated`.
