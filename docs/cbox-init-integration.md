---
title: "Cbox Init Integration"
description: "Cbox Process Manager - advanced multi-process orchestration for PHP containers"
weight: 15
---

# Cbox Process Manager

Cbox Init is the built-in Go-based process manager for all `php-fpm-nginx` images. It provides multi-process orchestration, structured logging, health checks, Prometheus metrics, and graceful lifecycle management.

## Quick Start

Cbox Init is included and enabled by default. Just use the image:

```yaml
services:
  app:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm
    ports:
      - "80:80"
      - "9090:9090"  # Prometheus metrics
```

## Enable Laravel Services

Configure Laravel features via environment variables:

```yaml
environment:
  # Laravel optimizations
  LARAVEL_OPTIMIZE_CONFIG: "true"
  LARAVEL_OPTIMIZE_ROUTE: "true"
  LARAVEL_MIGRATE_ENABLED: "true"

  # Enable Horizon
  CBOX_INIT_PROCESS_HORIZON_ENABLED: "true"

  # Enable Queue Workers (with scaling)
  CBOX_INIT_PROCESS_QUEUE_DEFAULT_ENABLED: "true"
  CBOX_INIT_PROCESS_QUEUE_DEFAULT_SCALE: "3"
```

### 3. Start Container

```bash
docker-compose up -d
```

## Key Features

### 🎯 Multi-Process Orchestration
- **PHP-FPM** + **Nginx** - Core web stack (Priority 10, 20)
- **Laravel Horizon** - Queue dashboard with graceful termination (Priority 30)
- **Laravel Reverb** - WebSocket server for real-time features (Priority 40)
- **Queue Workers** - Scalable queue:work processes (Priority 50+)
- **Scheduled Tasks** - Built-in cron-like scheduler (no external cron needed) (Priority 60+)

### 🔄 Lifecycle Hooks
Pre-start hooks for Laravel optimization:
- `config:cache`, `route:cache`, `view:cache`, `event:cache`
- `storage:link`
- `migrate --force`

Per-process hooks:
- Horizon: `horizon:terminate` on shutdown

### 📊 Health Monitoring
- **TCP checks** - PHP-FPM (port 9000), Reverb (port 8080)
- **HTTP checks** - Nginx (port 80 /health)
- **Exec checks** - Horizon (`php artisan horizon:status`)

### 🔁 Restart Policies
- `always` - Restart on any exit (default)
- `on-failure` - Restart only on non-zero exit
- `never` - Never restart
- Exponential backoff with configurable max attempts

### 📈 Prometheus Metrics
Exported on port 9090 at `/metrics`:

**Process Metrics:**
- `cbox_init_process_up` - Process running status
- `cbox_init_process_restarts_total` - Restart counts
- `cbox_init_process_cpu_seconds_total` - CPU usage
- `cbox_init_process_memory_bytes` - Memory usage
- `cbox_init_health_check_status` - Health check results
- `cbox_init_process_desired_scale` - Desired instances
- `cbox_init_process_current_scale` - Running instances

**Scheduled Task Metrics (v1.1.0+):**
- `cbox_init_scheduled_task_last_run_timestamp` - Last execution time
- `cbox_init_scheduled_task_next_run_timestamp` - Next scheduled time
- `cbox_init_scheduled_task_last_exit_code` - Most recent exit code
- `cbox_init_scheduled_task_duration_seconds` - Execution duration
- `cbox_init_scheduled_task_total` - Total runs by status (success/failure)

### 🔌 Management API (Phase 5)
REST API on port 8080 (when enabled):
- `GET /api/v1/processes` - List processes
- `POST /api/v1/processes/{name}/scale` - Dynamic scaling
- `POST /api/v1/processes/{name}/restart` - Restart process

## Architecture

### Startup Sequence

When the container starts:

1. **docker-entrypoint.sh** runs:
   - Detects framework (Laravel, Symfony, WordPress)
   - Sets up critical directories and permissions
   - Validates PHP-FPM and Nginx configs
   - Generates runtime config from template + env vars
2. **cbox-init binary** starts as PID 1:
   - Executes pre-start hooks (Laravel optimizations, migrations)
   - Starts processes in priority order with dependency resolution
   - Monitors health checks
   - Handles graceful shutdown on SIGTERM

### Configuration Flow

```
cbox-init.yaml (template)
    ↓ (environment variable substitution)
/tmp/cbox-init.yaml (runtime config)
    ↓
cbox-init binary reads config
    ↓
Processes start with environment-specific settings
```

### File Locations

| File | Location | Purpose |
|------|----------|---------|
| Template config | `/etc/cbox-init/cbox-init.yaml` | Base config with env var placeholders |
| Runtime config | `/tmp/cbox-init.yaml` | Generated config with actual values |
| Cbox Init binary | `/usr/local/bin/cbox-init` | Process manager executable |
| Entrypoint | `/usr/local/bin/docker-entrypoint.sh` | Container startup script |

## Examples

### Minimal (PHP-FPM + Nginx)

```yaml
services:
  app:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm
    ports:
      - "80:80"
```

### Laravel with Horizon

```yaml
services:
  app:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm
    environment:
      LARAVEL_OPTIMIZE_CONFIG: "true"
      LARAVEL_OPTIMIZE_ROUTE: "true"
      LARAVEL_MIGRATE_ENABLED: "true"
      CBOX_INIT_PROCESS_HORIZON_ENABLED: "true"
    ports:
      - "80:80"
      - "9090:9090"  # Prometheus metrics
```

### Full Laravel Stack

A complete example configuration for Laravel:

```yaml
services:
  app:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm
    environment:
      # Laravel optimizations
      LARAVEL_OPTIMIZE_CONFIG: "true"
      LARAVEL_OPTIMIZE_ROUTE: "true"
      LARAVEL_OPTIMIZE_VIEW: "true"
      LARAVEL_MIGRATE_ENABLED: "true"

      # Enable Horizon
      CBOX_INIT_PROCESS_HORIZON_ENABLED: "true"

      # Enable Reverb (WebSockets)
      CBOX_INIT_PROCESS_REVERB_ENABLED: "true"

      # Enable Queue Workers (with scaling)
      CBOX_INIT_PROCESS_QUEUE_DEFAULT_ENABLED: "true"
      CBOX_INIT_PROCESS_QUEUE_DEFAULT_SCALE: "3"
      CBOX_INIT_PROCESS_QUEUE_HIGH_ENABLED: "true"
      CBOX_INIT_PROCESS_QUEUE_HIGH_SCALE: "2"
    ports:
      - "80:80"
      - "8080:8080"   # Reverb WebSocket
      - "9090:9090"   # Prometheus metrics
    depends_on:
      - mysql
      - redis

  mysql:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: secret
      MYSQL_DATABASE: laravel

  redis:
    image: redis:7-alpine
```

## Environment Variables

Complete reference: [cbox-init-environment-variables.md](./cbox-init-environment-variables.md)

**Quick reference**:

| Category | Key Variables |
|----------|---------------|
| **Laravel Hooks** | `LARAVEL_OPTIMIZE_*`, `LARAVEL_MIGRATE_ENABLED` |
| **Process Control** | `CBOX_INIT_PROCESS_*_ENABLED` |
| **Scaling** | `CBOX_INIT_PROCESS_QUEUE_*_SCALE` |
| **Observability** | `CBOX_INIT_METRICS_ENABLED`, `CBOX_INIT_API_ENABLED` |
| **Logging** | `CBOX_INIT_LOG_LEVEL`, `CBOX_INIT_LOG_FORMAT` |

## Monitoring

### Prometheus Scraping

Add to `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'cbox-init'
    static_configs:
      - targets: ['app:9090']
```

### Grafana Dashboard

Import dashboard from Cbox Init repository (coming in Phase 4).

### Health Check Endpoint

```bash
curl http://localhost:80/health
```

### Logs (JSON format)

```bash
docker logs app | jq .
```

Example output:
```json
{
  "time": "2024-01-15T10:30:45Z",
  "level": "INFO",
  "msg": "Process started successfully",
  "instance_id": "queue-default-0",
  "pid": 123
}
```

## Scheduled Tasks (v1.1.0+)

Cbox Init includes a built-in cron-like scheduler for running periodic tasks **without requiring a separate cron daemon**. Perfect for Laravel scheduled commands, backups, cleanups, and maintenance tasks.

### Quick Start

Enable scheduled tasks with standard cron expressions:

```yaml
environment:
  # Laravel scheduled command (every 15 minutes)
  CBOX_INIT_PROCESS_CACHE_WARMUP_ENABLED: "true"
  CBOX_INIT_PROCESS_CACHE_WARMUP_COMMAND: "php,artisan,cache:warm"
  CBOX_INIT_PROCESS_CACHE_WARMUP_SCHEDULE: "*/15 * * * *"

  # Database backup (daily at 2 AM)
  CBOX_INIT_PROCESS_DB_BACKUP_ENABLED: "true"
  CBOX_INIT_PROCESS_DB_BACKUP_COMMAND: "php,artisan,backup:run"
  CBOX_INIT_PROCESS_DB_BACKUP_SCHEDULE: "0 2 * * *"
```

### Cron Expression Format

Standard 5-field format (minute, hour, day, month, weekday):

```
┌───────────── minute (0 - 59)
│ ┌───────────── hour (0 - 23)
│ │ ┌───────────── day of the month (1 - 31)
│ │ │ ┌───────────── month (1 - 12)
│ │ │ │ ┌───────────── day of the week (0 - 6) (Sunday to Saturday)
│ │ │ │ │
* * * * *
```

**Special characters:**
- `*` - any value
- `,` - value list separator
- `-` - range of values
- `/` - step values

**Common examples:**
```yaml
"0 0 * * *"      # Daily at midnight
"*/15 * * * *"   # Every 15 minutes
"0 2 * * 0"      # Every Sunday at 2 AM
"0 9-17 * * 1-5" # Every hour from 9 AM to 5 PM, Monday to Friday
"30 3 1 * *"     # At 3:30 AM on the first day of every month
```

### Features

- ✅ **No External Cron**: Built-in scheduler, no cron daemon needed
- ✅ **Per-Task Statistics**: Track run count, success/failure rates, execution duration
- ✅ **External Monitoring**: Integrate with healthchecks.io, Cronitor, Better Uptime
- ✅ **Structured Logging**: Task-specific logs with execution context
- ✅ **Graceful Shutdown**: Running tasks are cancelled cleanly
- ✅ **Prometheus Metrics**: Full observability of scheduled task execution

### Heartbeat Integration

Monitor critical scheduled tasks with external services:

```yaml
environment:
  # Critical backup with external monitoring
  CBOX_INIT_PROCESS_CRITICAL_BACKUP_ENABLED: "true"
  CBOX_INIT_PROCESS_CRITICAL_BACKUP_COMMAND: "php,artisan,backup:critical"
  CBOX_INIT_PROCESS_CRITICAL_BACKUP_SCHEDULE: "0 3 * * *"
  CBOX_INIT_PROCESS_CRITICAL_BACKUP_HEARTBEAT_URL: "https://hc-ping.com/your-uuid-here"
  CBOX_INIT_PROCESS_CRITICAL_BACKUP_HEARTBEAT_TIMEOUT: "300"
```

**How it works:**
1. **Task Start**: Pings `/start` endpoint when task begins
2. **Task Success**: Pings main URL when task completes with exit code 0
3. **Task Failure**: Pings `/fail` endpoint with exit code when task fails

**Supported services:**
- healthchecks.io: `https://hc-ping.com/uuid`
- Cronitor: `https://cronitor.link/p/key/job-name`
- Better Uptime: `https://betteruptime.com/api/v1/heartbeat/uuid`
- Custom endpoints: Any URL accepting GET/POST requests

### Environment Variables

Scheduled tasks receive additional context:

```bash
CBOX_INIT_PROCESS_NAME=backup-job
CBOX_INIT_INSTANCE_ID=backup-job-run-42
CBOX_INIT_SCHEDULED=true
CBOX_INIT_SCHEDULE="0 2 * * *"
CBOX_INIT_START_TIME=1732141200
```

### Laravel Scheduler Example

Replace Laravel's cron entry with Cbox Init scheduled tasks:

**Old approach** (requires cron):
```cron
* * * * * cd /var/www && php artisan schedule:run >> /dev/null 2>&1
```

**New approach** (Cbox Init):
```yaml
environment:
  # Cache warmup every 15 minutes
  CBOX_INIT_PROCESS_CACHE_WARMUP_ENABLED: "true"
  CBOX_INIT_PROCESS_CACHE_WARMUP_COMMAND: "php,artisan,cache:warm"
  CBOX_INIT_PROCESS_CACHE_WARMUP_SCHEDULE: "*/15 * * * *"

  # Database backup daily at 2 AM
  CBOX_INIT_PROCESS_DB_BACKUP_ENABLED: "true"
  CBOX_INIT_PROCESS_DB_BACKUP_COMMAND: "php,artisan,backup:run"
  CBOX_INIT_PROCESS_DB_BACKUP_SCHEDULE: "0 2 * * *"
  CBOX_INIT_PROCESS_DB_BACKUP_HEARTBEAT_URL: "https://hc-ping.com/backup-uuid"

  # Report generation Monday-Friday at 8 AM
  CBOX_INIT_PROCESS_REPORTS_ENABLED: "true"
  CBOX_INIT_PROCESS_REPORTS_COMMAND: "php,artisan,reports:generate"
  CBOX_INIT_PROCESS_REPORTS_SCHEDULE: "0 8 * * 1-5"
```

### Metrics

Monitor scheduled tasks via Prometheus:

```promql
# Last execution time
cbox_init_scheduled_task_last_run_timestamp{process="backup-job"}

# Next scheduled execution
cbox_init_scheduled_task_next_run_timestamp{process="backup-job"}

# Task success rate
rate(cbox_init_scheduled_task_total{status="success"}[1h])
```

## Advanced Logging (v1.1.0+)

Cbox Init provides enterprise-grade log processing with intelligent parsing and security features.

### Automatic Log Level Detection

Detects log levels from various formats automatically:

```
[ERROR] Database connection failed      → ERROR
2024-11-20 ERROR: Query timeout         → ERROR
{"level":"warn","msg":"Slow query"}     → WARN
php artisan: INFO - Cache cleared       → INFO
```

Supports: `ERROR`, `WARN/WARNING`, `INFO`, `DEBUG`, `TRACE`, `FATAL`, `CRITICAL`

### Multiline Log Handling

Stack traces and multi-line errors are automatically reassembled:

```
[ERROR] Exception in Controller
    at App\Http\Controllers\UserController->store()
    at Illuminate\Routing\Controller->callAction()
    at Illuminate\Routing\ControllerDispatcher->dispatch()
```

**Enable multiline handling:**
```yaml
environment:
  CBOX_INIT_LOG_MULTILINE_ENABLED: "true"
  CBOX_INIT_LOG_MULTILINE_PATTERN: '^\[|^\d{4}-|^{"'  # Regex for line starts
  CBOX_INIT_LOG_MULTILINE_TIMEOUT: "500"  # milliseconds
  CBOX_INIT_LOG_MULTILINE_MAX_LINES: "100"
```

### JSON Log Parsing

Extracts structured fields from JSON logs:

```json
{"level":"error","msg":"Query failed","query":"SELECT *","duration":5000}
```

Becomes:
```
ERROR [query_failed] Query failed (duration: 5000ms, query: SELECT *)
```

### Sensitive Data Redaction 🔒

Automatically redacts credentials to prevent leaks:

```yaml
environment:
  CBOX_INIT_LOG_REDACTION_ENABLED: "true"
  CBOX_INIT_LOG_REDACTION_PATTERNS: "password,api_key,secret,token"
  CBOX_INIT_LOG_REDACTION_PLACEHOLDER: "***REDACTED***"
```

**Redacted patterns:**
- Passwords: `password`, `passwd`, `pwd`
- API tokens: `token`, `api_key`, `secret`, `auth`
- Connection strings: `mysql://`, `postgres://`, database URLs
- Credit cards: Card number patterns

**Example:**
```
Before: {"password":"secret123","api_key":"sk_live_abc"}
After:  {"password":"***REDACTED***","api_key":"***REDACTED***"}
```

Perfect for PCI compliance and security audits.

## Advanced Usage

### Custom Configuration

Mount a custom `cbox-init.yaml`:

```yaml
services:
  app:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm
    environment:
      CBOX_INIT_CONFIG: /app/config/cbox-init.yaml
    volumes:
      - ./custom-cbox-init.yaml:/app/config/cbox-init.yaml:ro
```

### Dynamic Scaling (Phase 5)

Via Management API:

```bash
# Scale queue workers to 10 instances
curl -X POST \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"replicas": 10}' \
  http://localhost:8080/api/v1/processes/queue-default/scale
```

### Multiple Queue Types

```yaml
environment:
  # Default queue
  CBOX_INIT_PROCESS_QUEUE_DEFAULT_ENABLED: "true"
  CBOX_INIT_PROCESS_QUEUE_DEFAULT_SCALE: "3"

  # High priority queue
  CBOX_INIT_PROCESS_QUEUE_HIGH_ENABLED: "true"
  CBOX_INIT_PROCESS_QUEUE_HIGH_SCALE: "2"
```

Each queue worker group is independently scalable and monitored.

## Migration Guide

### From Supervisor/S6-Overlay

If you're migrating from images using Supervisor or S6-Overlay, Cbox Init offers a simpler, lighter alternative.

**Benefits of switching**:
- ✅ Structured JSON logging with process segmentation
- ✅ Native Prometheus metrics
- ✅ Health checks with automatic restart
- ✅ Graceful shutdown handling (Horizon: horizon:terminate)
- ✅ Dynamic scaling via API (Phase 5)
- ✅ Dependency management (DAG-based startup order)

**No breaking changes** - Cbox Init is a drop-in replacement.

## Troubleshooting

### Enable Debug Logging

```yaml
environment:
  CBOX_INIT_LOG_LEVEL: debug
  CBOX_DEBUG: "true"
```

### Check Process Status

```bash
# Via metrics
curl http://localhost:9090/metrics | grep cbox_init_process_up

# Via logs
docker logs app | jq 'select(.msg | contains("Process"))'
```

### Disable Specific Processes

```yaml
environment:
  CBOX_INIT_PROCESS_HORIZON_ENABLED: "false"
```

### Restart Issues

Increase restart attempts and backoff:
```yaml
environment:
  CBOX_INIT_MAX_RESTART_ATTEMPTS: "10"
  CBOX_INIT_RESTART_BACKOFF: "10"
```

## Features (v1.0.0)

Cbox Init v1.0.0 includes:

- ✅ Multi-process orchestration with DAG dependency resolver
- ✅ Health checks (TCP, HTTP, exec) with auto-restart
- ✅ Restart policies with exponential backoff
- ✅ Pre/post start/stop lifecycle hooks
- ✅ Per-process hooks (Horizon terminate)
- ✅ Prometheus metrics (process, health check, scaling)
- ✅ Structured JSON logging with multiline support
- ✅ Sensitive data redaction
- ✅ Scheduled tasks with cron expressions

**Coming soon:**
- Management API for dynamic scaling
- Grafana dashboard templates

## Resources

- **Cbox Init Repository**: https://github.com/cboxdk/init
- **Environment Variables**: See [cbox-init-environment-variables.md](./cbox-init-environment-variables.md)
- **Example Configs**: See examples throughout this documentation

## Support

For issues and feature requests:
- Cbox Base Images: [GitHub Issues](https://github.com/cboxdk/baseimages/issues)
- Cbox Init: [GitHub Issues](https://github.com/cboxdk/init/issues)
