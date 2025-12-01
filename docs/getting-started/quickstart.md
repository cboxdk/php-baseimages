---
title: "5-Minute Quickstart"
description: "Get your PHP application running with PHPeek in 5 minutes"
weight: 1
---

# 5-Minute Quickstart

Get a production-ready PHP environment running in under 5 minutes.

## Prerequisites

- Docker 20.10+ (`docker --version`)
- Docker Compose (`docker compose version`)

## Step 1: Create Project

```bash
mkdir my-php-app && cd my-php-app
mkdir public
```

## Step 2: Create Test File

```bash
cat > public/index.php << 'EOF'
<?php
echo "<h1>PHPeek Works!</h1>";
echo "<p>PHP " . PHP_VERSION . " with " . count(get_loaded_extensions()) . " extensions</p>";
EOF
```

## Step 3: Create docker-compose.yml

```yaml
services:
  app:
    image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine
    ports:
      - "8000:80"
    volumes:
      - .:/var/www/html
```

## Step 4: Start

```bash
docker compose up
```

## Step 5: Open Browser

Visit **http://localhost:8000**

---

## What You Get

- PHP 8.3 with 40+ extensions (Redis, ImageMagick, MongoDB, etc.)
- Nginx with security headers
- OPcache JIT enabled
- Automatic health checks
- Graceful shutdown handling

## Quick Commands

```bash
docker compose up -d          # Start background
docker compose logs -f        # View logs
docker compose down           # Stop
docker compose exec app sh    # Shell access
curl localhost:8000/health    # Health check
```

---

## Next Steps

| Goal | Guide |
|------|-------|
| Laravel setup | [Laravel Guide](../guides/laravel-guide) |
| Add PHP extensions | [Extending Images](../advanced/extending-images) |
| Production deployment | [Production Guide](../guides/production-deployment) |
| All environment variables | [Environment Variables](../reference/environment-variables) |

## Available Images

Use Alpine (smallest), Debian for glibc compatibility:

```
ghcr.io/phpeek/baseimages/php-fpm-nginx:8.4-alpine  # ~80MB
ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine
ghcr.io/phpeek/baseimages/php-fpm-nginx:8.2-alpine
ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-debian  # ~150MB
```

## Troubleshooting

**Port in use?** Change `8000:80` to `8001:80`

**Permission errors?** PHPeek auto-fixes Laravel directories. Manual: `docker compose exec app chown -R www-data:www-data storage`

**More help?** See [Common Issues](../troubleshooting/common-issues)
