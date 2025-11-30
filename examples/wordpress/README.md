---
title: "WordPress Setup"
description: "WordPress with MySQL and optimized PHP settings for media uploads"
weight: 5
---

# WordPress Setup

WordPress with MySQL and optimized PHP settings for media handling.

## Quick Start

```bash
# Start containers
docker compose up -d

# Download WordPress (if not using volume)
docker compose exec app wp core download --allow-root

# Or manually download
curl -O https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz --strip-components=1

# Visit http://localhost:8080 to complete installation
```

## Upload Configuration

The `uploads.ini` file optimizes PHP for media uploads:

```ini
upload_max_filesize = 64M
post_max_size = 64M
max_execution_time = 300
memory_limit = 256M
```

Create this file in the same directory as docker-compose.yml.

## WP-CLI Usage

```bash
# Install WP-CLI in container
docker compose exec app sh -c "curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && chmod +x wp-cli.phar && mv wp-cli.phar /usr/local/bin/wp"

# Use WP-CLI
docker compose exec app wp plugin list --allow-root
docker compose exec app wp theme list --allow-root
docker compose exec app wp cache flush --allow-root
```

## Common Commands

```bash
# View logs
docker compose logs -f app

# Access MySQL
docker compose exec mysql mysql -u wordpress -psecret wordpress

# Backup database
docker compose exec mysql mysqldump -u wordpress -psecret wordpress > backup.sql

# Restore database
docker compose exec -T mysql mysql -u wordpress -psecret wordpress < backup.sql
```

## Production Notes

For production:
- Use strong passwords
- Enable HTTPS (use reverse proxy like Traefik)
- Configure Redis object cache
- Set `WP_DEBUG=false`
- Consider separate uploads volume for CDN integration
