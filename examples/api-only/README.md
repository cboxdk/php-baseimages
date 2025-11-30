---
title: "API-Only Setup"
description: "Minimal API backend with PostgreSQL and Redis for high-performance APIs"
weight: 6
---

# API-Only Setup

Minimal API backend optimized for JSON responses. No frontend assets, no Vite, no Node.js.

## Quick Start

```bash
# Create Laravel API project
composer create-project laravel/laravel . --prefer-dist
# Or use Lumen for microservices
composer create-project laravel/lumen .

# Start containers
docker compose up -d

# Setup
docker compose exec api composer install
docker compose exec api php artisan key:generate
docker compose exec api php artisan migrate

# Test API
curl http://localhost:8080/api/health
```

## Architecture

```
┌─────────────────┐     ┌─────────────────┐
│   API Clients   │────▶│    API:8080     │
└─────────────────┘     └────────┬────────┘
                                 │
        ┌────────────────────────┼────────────────────────┐
        │                        │                        │
┌───────▼───────┐       ┌────────▼────────┐      ┌────────▼────────┐
│   PostgreSQL  │       │      Redis      │      │     Worker      │
│   (database)  │       │  (cache/queue)  │      │  (background)   │
└───────────────┘       └─────────────────┘      └─────────────────┘
```

## Recommended Optimizations

### Remove Unnecessary Packages

```bash
# Remove frontend tooling
docker compose exec api composer remove laravel/breeze laravel/ui
docker compose exec api rm -rf resources/js resources/css vite.config.js package.json
```

### API-Only Middleware

In `app/Http/Kernel.php`, use only API middleware:

```php
protected $middlewareGroups = [
    'api' => [
        \Laravel\Sanctum\Http\Middleware\EnsureFrontendRequestsAreStateful::class,
        \Illuminate\Routing\Middleware\ThrottleRequests::class.':api',
        \Illuminate\Routing\Middleware\SubstituteBindings::class,
    ],
];
```

### Health Check Endpoint

Add to `routes/api.php`:

```php
Route::get('/health', function () {
    return response()->json([
        'status' => 'healthy',
        'timestamp' => now()->toIso8601String(),
    ]);
});
```

## Common Commands

```bash
# Run tests
docker compose exec api php artisan test

# Generate API documentation
docker compose exec api php artisan l5-swagger:generate

# Clear all caches
docker compose exec api php artisan optimize:clear

# Scale workers
docker compose up -d --scale worker=3
```

## Production Notes

For production:
- Set `APP_ENV=production`
- Set `APP_DEBUG=false`
- Enable response caching
- Use API rate limiting
- Configure CORS properly
- Consider API versioning
