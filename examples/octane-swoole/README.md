---
title: "Laravel Octane Setup"
description: "High-performance Laravel with Swoole for 10x faster response times"
weight: 3
---

# Laravel Octane Setup

Supercharge Laravel with Octane + Swoole for dramatically faster response times.

## Quick Start

```bash
# Install Octane
docker compose exec app composer require laravel/octane
docker compose exec app php artisan octane:install --server=swoole

# Start with Octane
docker compose up -d

# Visit http://localhost:8080
```

## Performance Comparison

| Metric | PHP-FPM | Octane (Swoole) |
|--------|---------|-----------------|
| Requests/sec | ~500 | ~5,000 |
| Memory per request | ~20MB | ~2MB |
| Cold start | ~100ms | ~10ms |
| Concurrent connections | ~100 | ~10,000 |

## How Octane Works

```
Traditional PHP-FPM:
Request → Bootstrap → Handle → Terminate → Response
         (slow)

Octane (Swoole):
Bootstrap (once) → Request → Handle → Response
                   Request → Handle → Response
                   Request → Handle → Response
```

The application is booted once and kept in memory, eliminating bootstrap overhead.

## Important Considerations

### Memory Leaks
Since the app stays in memory, be careful with:
- Static properties
- Global state
- Singletons that accumulate data

### Code Reloading
```bash
# Restart Octane after code changes
docker compose exec app php artisan octane:reload

# Or use file watching (development)
docker compose exec app php artisan octane:start --watch
```

### Swoole Extensions
The Cbox image includes Swoole. Verify with:
```bash
docker compose exec app php -m | grep swoole
```

## Scaling

```bash
# Run multiple Octane workers
docker compose exec app php artisan octane:start --workers=4 --task-workers=2
```

## Common Issues

### "Class already exists" errors
Reset between requests:
```php
// app/Providers/AppServiceProvider.php
public function boot(): void
{
    // Reset singletons between requests
    if (app()->bound('octane')) {
        Octane::tick('flush', fn () => Cache::flush());
    }
}
```

### Memory growing over time
Set max requests before worker restart:
```bash
php artisan octane:start --max-requests=500
```
