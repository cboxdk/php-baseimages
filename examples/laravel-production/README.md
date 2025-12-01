---
title: "Production Setup"
description: "Production-optimized configuration with resource limits, health checks, and security"
weight: 8
---

# Production Setup

Production-ready configuration with optimizations, security, and monitoring.

## Quick Start

```bash
# Create .env file with secrets
cp .env.example .env
# Edit .env with strong passwords

# Start services
docker compose up -d

# Verify health
docker compose ps
curl http://localhost/health
```

## Security Checklist

- [ ] Set strong passwords in `.env`
- [ ] Use HTTPS (reverse proxy like Traefik/Nginx)
- [ ] Set `APP_DEBUG=false`
- [ ] Configure firewall rules
- [ ] Enable rate limiting
- [ ] Set up log monitoring
- [ ] Configure backup strategy

## Environment Variables

Create `.env` file:

```env
DB_PASSWORD=your-strong-password-here
MYSQL_ROOT_PASSWORD=your-root-password-here
```

## Resource Limits

| Service | CPU | Memory |
|---------|-----|--------|
| app | 2 cores | 512MB |
| horizon | 1 core | 256MB |
| scheduler | 0.5 core | 128MB |
| mysql | 2 cores | 1GB |
| redis | 0.5 core | 256MB |

Adjust in `docker-compose.yml` based on your server capacity.

## MySQL Optimization

Create `mysql/my.cnf`:

```ini
[mysqld]
# InnoDB settings
innodb_buffer_pool_size = 512M
innodb_log_file_size = 128M
innodb_flush_log_at_trx_commit = 2

# Query cache (MySQL 8.0 uses different approach)
# Consider using Redis for query caching

# Connection settings
max_connections = 200
wait_timeout = 600

# Logging
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 2
```

## Scaling

### Horizontal Scaling (Multiple App Instances)

```bash
# Scale app containers
docker compose up -d --scale app=3

# Use load balancer (Traefik example in separate config)
```

### Vertical Scaling (More Resources)

Edit resource limits in `docker-compose.yml`:

```yaml
deploy:
  resources:
    limits:
      cpus: '4'
      memory: 1G
```

## Monitoring

### Health Endpoint

Add to your Laravel app `routes/api.php`:

```php
Route::get('/health', function () {
    $checks = [
        'database' => DB::connection()->getPdo() ? 'ok' : 'failed',
        'cache' => Cache::has('health-check') || Cache::put('health-check', true, 10) ? 'ok' : 'failed',
        'redis' => Redis::ping() ? 'ok' : 'failed',
    ];

    $healthy = !in_array('failed', $checks);

    return response()->json([
        'status' => $healthy ? 'healthy' : 'unhealthy',
        'checks' => $checks,
        'timestamp' => now()->toIso8601String(),
    ], $healthy ? 200 : 503);
});
```

### Log Aggregation

Logs go to stderr for easy collection:

```bash
# View all logs
docker compose logs -f

# Specific service
docker compose logs -f app

# Export to file
docker compose logs --no-color > logs.txt
```

## Backup Strategy

### Database Backup

```bash
# Backup
docker compose exec mysql mysqldump -u root -p${MYSQL_ROOT_PASSWORD} app > backup-$(date +%Y%m%d).sql

# Restore
docker compose exec -T mysql mysql -u root -p${MYSQL_ROOT_PASSWORD} app < backup.sql
```

### Automated Backups (cron)

```bash
# Add to host crontab
0 2 * * * cd /path/to/project && docker compose exec -T mysql mysqldump -u root -p$MYSQL_ROOT_PASSWORD app | gzip > /backups/db-$(date +\%Y\%m\%d).sql.gz
```

## Zero-Downtime Deployment

```bash
# Pull new image
docker compose pull app

# Recreate with zero downtime
docker compose up -d --no-deps --scale app=2 app
sleep 30
docker compose up -d --no-deps --scale app=1 app
```
