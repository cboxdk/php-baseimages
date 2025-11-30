---
title: "Laravel Basic Setup"
description: "Simple Laravel application with MySQL database - the most common setup"
weight: 1
---

# Laravel Basic Setup

The most common Laravel setup: PHP-FPM + Nginx + MySQL.

## Quick Start

```bash
# Clone your Laravel project or create new one
composer create-project laravel/laravel .

# Copy environment file
cp .env.example .env

# Start containers
docker compose up -d

# Install dependencies and setup
docker compose exec app composer install
docker compose exec app php artisan key:generate
docker compose exec app php artisan migrate

# Visit http://localhost:8080
```

## What's Included

- **PHP 8.3** with all Laravel extensions
- **Nginx** optimized for Laravel routing
- **MySQL 8.0** with persistent storage
- **Health checks** for all services

## Environment Variables

The following are pre-configured in docker-compose.yml:

| Variable | Value | Description |
|----------|-------|-------------|
| `APP_ENV` | local | Laravel environment |
| `DB_HOST` | mysql | Database hostname |
| `DB_DATABASE` | laravel | Database name |
| `DB_USERNAME` | laravel | Database user |
| `DB_PASSWORD` | secret | Database password |

## Common Commands

```bash
# Run artisan commands
docker compose exec app php artisan migrate
docker compose exec app php artisan tinker

# Run tests
docker compose exec app php artisan test

# View logs
docker compose logs -f app

# Access MySQL
docker compose exec mysql mysql -u laravel -psecret laravel
```

## Production Notes

For production, change:
- `APP_ENV=production`
- `APP_DEBUG=false`
- Use strong passwords
- Add Redis for caching/sessions
- Consider using the `laravel-horizon` example for queues
