---
title: "Laravel Horizon Setup"
description: "Laravel with Redis queues, Horizon dashboard, and scheduled tasks"
weight: 2
---

# Laravel Horizon Setup

Full Laravel setup with Redis-backed queues, Horizon dashboard, and task scheduler.

## Quick Start

```bash
# Start all services
docker compose up -d

# Install Horizon
docker compose exec app composer require laravel/horizon
docker compose exec app php artisan horizon:install
docker compose exec app php artisan migrate

# Visit http://localhost:8080/horizon
```

## Architecture

```
┌─────────────────┐     ┌─────────────────┐
│   Web Browser   │────▶│    Nginx:80     │
└─────────────────┘     └────────┬────────┘
                                 │
                        ┌────────▼────────┐
                        │    PHP-FPM      │
                        │   (app service) │
                        └────────┬────────┘
                                 │
        ┌────────────────────────┼────────────────────────┐
        │                        │                        │
┌───────▼───────┐       ┌────────▼────────┐      ┌────────▼────────┐
│    MySQL      │       │     Redis       │      │    Horizon      │
│   (database)  │       │  (cache/queue)  │      │    (worker)     │
└───────────────┘       └─────────────────┘      └─────────────────┘
                                                         │
                                                 ┌───────▼───────┐
                                                 │   Scheduler   │
                                                 │ (cron tasks)  │
                                                 └───────────────┘
```

## Services

| Service | Purpose | Port |
|---------|---------|------|
| `app` | Web application | 8080 |
| `horizon` | Queue worker | - |
| `scheduler` | Cron jobs | - |
| `mysql` | Database | 3306 |
| `redis` | Cache & Queue | 6379 |

## Common Commands

```bash
# Monitor Horizon
docker compose exec app php artisan horizon:status
docker compose logs -f horizon

# Restart workers after code changes
docker compose exec app php artisan horizon:terminate
docker compose restart horizon

# Run specific queue
docker compose exec app php artisan queue:work redis --queue=high,default

# Clear caches
docker compose exec app php artisan cache:clear
docker compose exec app php artisan config:clear
```

## Scaling Workers

```bash
# Scale Horizon workers
docker compose up -d --scale horizon=3
```

## Production Configuration

In `config/horizon.php`, adjust:

```php
'environments' => [
    'production' => [
        'supervisor-1' => [
            'maxProcesses' => 10,
            'balanceMaxShift' => 1,
            'balanceCooldown' => 3,
        ],
    ],
],
```
