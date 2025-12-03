---
title: "Systematic Debugging Guide"
description: "Step-by-step systematic debugging process for PHPeek containers including log analysis and performance profiling"
weight: 42
---

# Systematic Debugging Guide

Methodical approach to debugging issues with PHPeek containers.

## Debugging Process

### Step 1: Identify the Problem

**Symptoms checklist:**
- [ ] Container starts but application inaccessible
- [ ] Container exits immediately
- [ ] Slow performance
- [ ] Intermittent errors
- [ ] Database connection issues
- [ ] Memory/CPU problems

### Step 2: Gather Information

```bash
# Container status
docker-compose ps

# Recent logs
docker-compose logs --tail=100 app

# Follow logs in real-time
docker-compose logs -f app

# Resource usage
docker stats app

# Network connectivity
docker-compose exec app netstat -tulpn
```

### Step 3: Isolate the Component

**Test each layer:**

```bash
# 1. Docker layer
docker --version
docker-compose version

# 2. Container layer
docker-compose exec app sh  # Can we access?

# 3. PHP layer
docker-compose exec app php -v
docker-compose exec app php -m

# 4. Web server layer
docker-compose exec app curl http://localhost

# 5. Application layer
docker-compose exec app curl http://localhost/health
```

### Step 4: Reproduce and Document

1. Document exact steps to reproduce
2. Note expected vs actual behavior
3. Check if issue is consistent or intermittent
4. Identify what changed recently

### Step 5: Fix and Verify

1. Apply fix
2. Test thoroughly
3. Document solution
4. Add monitoring if needed

## Log Analysis

### Application Logs

```bash
# Laravel logs
docker-compose exec app tail -f storage/logs/laravel.log

# Symfony logs
docker-compose exec app tail -f var/log/dev.log

# Search for errors
docker-compose logs app | grep -i "error\|fatal\|exception"

# Filter by timeframe
docker-compose logs --since 1h app

# Export logs
docker-compose logs app > debug.log 2>&1
```

### PHP-FPM Logs

```bash
# PHP-FPM error log
docker-compose logs app | grep "php-fpm"

# Slow request log
docker-compose logs app | grep "slow"

# Check PHP-FPM status
curl http://localhost/fpm-status?full
```

### Nginx Logs

```bash
# Access log
docker-compose exec app tail -f /var/log/nginx/access.log

# Error log
docker-compose exec app tail -f /var/log/nginx/error.log

# Filter 5xx errors
docker-compose logs app | grep "HTTP/.*\" 5[0-9][0-9]"
```

## Common Debug Patterns

### Pattern 1: Container Dies Immediately

```bash
# Check exit code
docker-compose ps

# Build without cache
docker-compose build --no-cache

# Run interactively
docker-compose run --rm app sh

# Check config syntax
docker-compose config
```

### Pattern 2: Intermittent 502 Errors

```bash
# Monitor PHP-FPM processes
watch -n 1 'docker-compose exec app ps aux | grep php-fpm'

# Check for memory exhaustion
docker stats app

# Review PHP-FPM slow log
docker-compose logs app | grep "pool www"

# Increase PHP-FPM processes
environment:
  - PHP_FPM_PM_MAX_CHILDREN=50
```

### Pattern 3: Slow Performance

```bash
# Profile with Xdebug
environment:
  - XDEBUG_MODE=profile
  - XDEBUG_OUTPUT_DIR=/var/www/html/storage/xdebug

# Or use Blackfire
docker-compose exec app blackfire run php artisan some:command

# Check OPcache status
curl http://localhost/opcache-status.php

# Monitor query performance
docker-compose logs mysql | grep "Query_time"
```

## Performance Profiling

### PHP Profiling

```php
// Add to code
$start = microtime(true);

// Your code here

$end = microtime(true);
Log::info('Execution time: ' . ($end - $start) . ' seconds');
```

### Database Query Profiling

```php
// Laravel - Enable query log
DB::enableQueryLog();

// Your queries

dd(DB::getQueryLog());
```

### APM Tools

```yaml
# New Relic
services:
  app:
    environment:
      - NEW_RELIC_LICENSE_KEY=${NEW_RELIC_KEY}
      - NEW_RELIC_APP_NAME=MyApp
```

## Advanced Debugging

### Interactive Debugging

```bash
# Access container shell
docker-compose exec app sh

# Run artisan commands
php artisan tinker

# Test database connection
php artisan db:show

# Clear all caches
php artisan optimize:clear
```

### Network Debugging

```bash
# Test external connectivity
docker-compose exec app ping -c 3 google.com

# Check DNS resolution
docker-compose exec app nslookup mysql

# Test port connectivity
docker-compose exec app nc -zv mysql 3306

# Trace network
docker-compose exec app traceroute mysql
```

### Filesystem Debugging

```bash
# Check disk space
docker-compose exec app df -h

# Find large files
docker-compose exec app du -sh /var/www/html/*

# Check permissions
docker-compose exec app ls -la /var/www/html/storage

# Find permission issues
docker-compose exec app find /var/www/html -type f ! -perm 644
```

## Debugging Checklist

When debugging an issue:

### ✅ Initial Assessment
- [ ] Can access container shell?
- [ ] Logs show specific error?
- [ ] Issue reproducible?
- [ ] Recent changes identified?

### ✅ Environment Check
- [ ] Environment variables correct?
- [ ] Dependencies installed?
- [ ] File permissions correct?
- [ ] Disk space available?

### ✅ Service Health
- [ ] PHP-FPM running?
- [ ] Nginx responding?
- [ ] Database accessible?
- [ ] Redis/cache working?

### ✅ Configuration Review
- [ ] PHP memory limit sufficient?
- [ ] PHP-FPM process count adequate?
- [ ] OPcache configured correctly?
- [ ] Nginx timeouts appropriate?

## Related Documentation

- [Common Issues](common-issues) - Quick fixes
- [Performance Tuning](../advanced/performance-tuning) - Optimization
- [Development Workflow](../guides/development-workflow) - Development setup
- [Environment Variables](../reference/environment-variables) - Configuration

---

**Need more help?** Ask in [GitHub Discussions](https://github.com/gophpeek/baseimages/discussions).
