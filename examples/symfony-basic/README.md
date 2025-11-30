---
title: "Symfony Basic Setup"
description: "Symfony framework with PostgreSQL and Messenger queue worker"
weight: 4
---

# Symfony Basic Setup

Full Symfony setup with PostgreSQL database and Messenger queue worker.

## Quick Start

```bash
# Create new Symfony project
composer create-project symfony/skeleton .

# Or webapp for full-stack
composer create-project symfony/webapp-pack .

# Start containers
docker compose up -d

# Install dependencies
docker compose exec app composer install

# Create database
docker compose exec app php bin/console doctrine:database:create
docker compose exec app php bin/console doctrine:migrations:migrate

# Visit http://localhost:8080
```

## Services

| Service | Purpose | Port |
|---------|---------|------|
| `app` | Web application | 8080 |
| `worker` | Messenger consumer | - |
| `postgres` | PostgreSQL 16 | 5432 |

## Common Commands

```bash
# Symfony console
docker compose exec app php bin/console

# Clear cache
docker compose exec app php bin/console cache:clear

# Run migrations
docker compose exec app php bin/console doctrine:migrations:migrate

# Create entity
docker compose exec app php bin/console make:entity

# Restart queue worker after code changes
docker compose restart worker

# View worker logs
docker compose logs -f worker
```

## Messenger Configuration

In `config/packages/messenger.yaml`:

```yaml
framework:
    messenger:
        transports:
            async: '%env(MESSENGER_TRANSPORT_DSN)%'
        routing:
            'App\Message\MyMessage': async
```

## Production Notes

For production:
- Set `APP_ENV=prod`
- Set `APP_DEBUG=0`
- Use strong database password
- Consider Redis for Messenger transport
- Scale workers: `docker compose up -d --scale worker=3`
