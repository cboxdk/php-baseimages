---
title: "Common Issues & Solutions"
description: "Quick solutions to common problems with Cbox PHP Base Images including connection errors, permission issues, and configuration problems"
weight: 1
---

# Common Issues & Solutions

Quick copy-paste solutions to the most common problems with Cbox containers.

## Container Problems

### Container Won't Start

**Symptom:** `docker-compose up` exits immediately

```bash
# Check logs
docker-compose logs app
```

**Common Cause 1: Port Already in Use**

```bash
# Error: "port is already allocated"

# Find process using port
lsof -i :8000  # macOS/Linux
netstat -ano | findstr :8000  # Windows

# Solution: Change port in docker-compose.yml
ports:
  - "8001:80"  # Use different port
```

**Common Cause 2: Permission Issues**

```bash
# Error: "permission denied"

# Fix file permissions
chmod -R 755 /path/to/project
chown -R $USER:$USER /path/to/project

# Or use PUID/PGID
environment:
  - PUID=1000
  - PGID=1000
```

### Container Exits Immediately

```bash
# Check exit code
docker-compose ps

# View full logs
docker-compose logs --tail=100 app

# Common causes:
# - Syntax error in docker-compose.yml
# - Missing environment variables
# - Invalid configuration files
```

**Solution:**

```bash
# Rebuild without cache
docker-compose build --no-cache
docker-compose up
```

### Custom Dockerfile starts nothing after adding ENTRYPOINT

**Symptom:** `FROM ghcr.io/cboxdk/...` + your own `ENTRYPOINT` = container exits instantly

Docker resets the inherited `CMD` whenever a child image defines `ENTRYPOINT`.
Restate the command:

```dockerfile
FROM ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.5-bookworm-v1
ENTRYPOINT ["/my-wrapper.sh"]
# ❌ Without this line the container starts NOTHING:
CMD ["/usr/local/bin/docker-entrypoint.sh"]
```

### nginx overrides vanished after an image update

**Symptom:** Custom nginx config worked, then broke after pulling a new image

Mounting the whole directory hides every file the image ships - including new
ones an update adds:

```yaml
# ❌ Wrong: masks the image's own conf.d (and future additions)
volumes:
  - ./nginx-conf:/etc/nginx/conf.d

# ✅ Right: mount individual files over the ones you mean to replace
volumes:
  - ./my-site.conf:/etc/nginx/conf.d/my-site.conf
```

## Connection Problems

### Can't Access Application (502 Bad Gateway)

```bash
# Verify PHP-FPM is running
docker-compose exec app ps aux | grep php-fpm

# If not running, check PHP errors
docker-compose logs app | grep -i "fatal error"
```

**Common Cause: PHP Fatal Error**

```yaml
# Increase PHP memory limit
environment:
  - PHP_MEMORY_LIMIT=256M
```

### Connection Refused (Laravel/Symfony)

❌ **WRONG:**
```text
DB_HOST=localhost  # Don't use localhost!
```

✅ **CORRECT:**
```text
DB_HOST=mysql  # Use Docker service name
```

**Full fix:**

```env
# .env
DB_HOST=mysql  # Service name from docker-compose.yml
DB_PORT=3306
DB_DATABASE=your_database
DB_USERNAME=your_user
DB_PASSWORD=your_password
```

### nginx: "readv() failed (104: Connection reset by peer)" or "recv() failed"

**Symptom:** Intermittent 502s; nginx error log shows `readv() failed ... while reading upstream`

This is almost never an nginx problem: it means the PHP-FPM worker DIED mid-request,
and a segfault is the usual killer. Look two layers down:

```bash
# Any segfaults in the FPM log?
docker compose logs app | grep -iE "SIGSEGV|core dumped|child .* exited on signal"

# A misbehaving zend extension is the classic cause - list what is loaded
docker compose exec app php -v
docker compose exec app php -m
```

If a third-party zend extension (ionCube, custom profilers) appears, test with it
disabled first - other image projects spent months chasing these as "nginx bugs".

## Database Problems

### Database Connection Failed

**Error:** `SQLSTATE[HY000] [2002] Connection refused`

```bash
# Check database is running
docker-compose ps mysql

# Test connection
docker-compose exec app nc -zv mysql 3306

# Wait for database to be ready
docker-compose exec app sh -c 'until nc -z mysql 3306; do sleep 1; done; echo "MySQL ready"'
```

**Solution: Add healthcheck and depends_on**

```yaml
services:
  mysql:
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 5s
      timeout: 3s
      retries: 5

  app:
    depends_on:
      mysql:
        condition: service_healthy
```

### Database Not Ready on Startup

**Laravel migrations fail immediately**

```yaml
# Add initialization script
services:
  app:
    volumes:
      - ./docker-entrypoint-init.d:/docker-entrypoint-init.d
```

**Create `docker-entrypoint-init.d/01-wait-for-db.sh`:**

```bash
#!/bin/sh
echo "Waiting for database..."
until php artisan migrate --force 2>&1; do
    echo "Database not ready, retrying in 2 seconds..."
    sleep 2
done
echo "Database ready, migrations complete"
```

## PHP Problems

### White Screen / No Output

```bash
# Enable error display (development only!)
environment:
  - PHP_DISPLAY_ERRORS=On
  - PHP_ERROR_REPORTING=E_ALL

# Check PHP-FPM logs
docker-compose logs app | grep -i error

# Check Nginx error log
docker-compose exec app cat /var/log/nginx/error.log
```

### PHP Memory Exhausted

**Error:** `Fatal error: Allowed memory size of X bytes exhausted`

```yaml
services:
  app:
    environment:
      - PHP_MEMORY_LIMIT=512M  # Increase from default 128M
```

### PHP-FPM Not Responding

```bash
# Check processes
docker-compose exec app ps aux | grep php-fpm

# Restart PHP-FPM
docker-compose exec app kill -USR2 1

# Or restart container
docker-compose restart app
```

### error_log() output carries a "NOTICE: PHP message:" prefix

**Symptom:** Structured/JSON log lines are wrapped in `NOTICE: PHP message: ...`, breaking parsers

PHP-FPM adds this prefix to everything workers write via `error_log()`, and no
FPM setting removes it cleanly (upstream: wontfix). Write structured logs
directly to the stream instead:

```php
// ❌ Gets prefixed by FPM
error_log(json_encode($event));

// ✅ Reaches the container log verbatim
file_put_contents('php://stderr', json_encode($event) . PHP_EOL);
```

Laravel/Monolog users: use the `stderr` log channel (`LOG_CHANNEL=stderr`).

## Permission Issues

### Storage/Cache Not Writable (Laravel)

```bash
# Fix permissions inside container
docker-compose exec app chown -R www-data:www-data storage bootstrap/cache
docker-compose exec app chmod -R 775 storage bootstrap/cache
```

### var/ Directory Not Writable (Symfony)

```bash
# Fix Symfony permissions
docker-compose exec app chown -R www-data:www-data var/
docker-compose exec app chmod -R 775 var/
```

### Uploads Directory Not Writable (WordPress)

```bash
# Fix WordPress permissions
docker-compose exec app chown -R www-data:www-data wp-content/uploads
docker-compose exec app chmod -R 755 wp-content/uploads
```

## Performance Issues

### Slow on macOS/Windows

**Docker Desktop Performance:**

```yaml
# Use delegated mode
volumes:
  - ./:/var/www/html:delegated
```

**Disable Xdebug when not debugging:**

```yaml
environment:
  - XDEBUG_MODE=off
```

### High Memory Usage

```bash
# Check actual usage
docker stats app

# Reduce PHP-FPM processes
environment:
  - PHP_FPM_PM_MAX_CHILDREN=10  # Reduce from default
```

## Xdebug Issues

### Xdebug Not Connecting

```bash
# Verify Xdebug is enabled
docker-compose exec app php -m | grep xdebug

# Check configuration
docker-compose exec app php -i | grep xdebug
```

**Fix:**

```yaml
services:
  app:
    environment:
      - XDEBUG_MODE=debug
      - XDEBUG_CONFIG=client_host=host.docker.internal
```

**VS Code launch.json:**

```json
{
  "pathMappings": {
    "/var/www/html": "${workspaceFolder}"
  }
}
```

## Laravel-Specific Issues

### Laravel Mix/Vite Assets Not Found

```bash
# Run asset compilation
docker-compose exec app npm install
docker-compose exec app npm run dev

# For production
docker-compose exec app npm run build
```

### Laravel Queue Not Processing

```yaml
# Enable queue worker
environment:
  - LARAVEL_QUEUE=true
  - LARAVEL_QUEUE_CONNECTION=redis
```

### Laravel Scheduler Not Running

```yaml
# Enable scheduler
environment:
  - LARAVEL_SCHEDULER=true
```

`LARAVEL_SCHEDULER_ENABLED` still works for older configs, but `LARAVEL_SCHEDULER` is the preferred flag.

**Verify:**

```bash
# Check crontab
docker-compose exec app crontab -l

# Test schedule
docker-compose exec app php artisan schedule:run
```

## Composer Issues

### Composer Install Fails

```bash
# Run with more memory
docker-compose exec app php -d memory_limit=-1 /usr/bin/composer install

# Or increase limit
environment:
  - PHP_MEMORY_LIMIT=512M
```

### Composer Packages Not Found

```bash
# Clear Composer cache
docker-compose exec app composer clear-cache

# Update packages
docker-compose exec app composer update
```

## Quick Diagnostics Checklist

When something isn't working:

- [ ] Check logs: `docker-compose logs -f app`
- [ ] Verify services running: `docker-compose ps`
- [ ] Test connectivity: `docker-compose exec app curl http://localhost`
- [ ] Check database: `docker-compose exec app nc -zv mysql 3306`
- [ ] Verify permissions: `docker-compose exec app ls -la storage/`
- [ ] Check PHP-FPM: `docker-compose exec app ps aux | grep php-fpm`
- [ ] Review environment: `docker-compose exec app env`

## Related Documentation

- [Debugging Guide](./debugging-guide) - Systematic troubleshooting
- [Development Workflow](../guides/development-workflow) - Development setup
- [Laravel Guide](../guides/laravel-guide) - Laravel-specific issues
- [Environment Variables](../reference/environment-variables) - Configuration reference

---

**Still stuck?** Ask in [GitHub Discussions](https://github.com/cboxdk/php-baseimages/discussions).
