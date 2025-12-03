---
title: "PHPeek PM Integration"
description: "PHPeek Process Manager - advanced multi-process orchestration for PHP containers"
weight: 15
---

# PHPeek Process Manager Integration

PHPeek PM is a Go-based process manager providing advanced multi-process orchestration for PHP containers. It offers structured logging, health checks, Prometheus metrics, and graceful lifecycle management.

## Quick Start

Enable PHPeek PM with a single environment variable:

```yaml
services:
  app:
    image: ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine
    environment:
      PHPEEK_PROCESS_MANAGER: phpeek-pm
    ports:
      - "80:80"
      - "9090:9090"  # Prometheus metrics
```

## Process Management Modes

PHPeek base images support two process management modes:

| Mode | Best For | Features |
|------|----------|----------|
| **Default (bash)** | Simple deployments, development | PHP-FPM + Nginx, framework detection, graceful shutdown |
| **PHPeek PM** | Production, complex stacks | All default features + structured logging, health checks, metrics, multi-process |

**Switch modes** with `PHPEEK_PROCESS_MANAGER=phpeek-pm`

## Enable PHPeek PM

```yaml
services:
  app:
    image: ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine
    environment:
      PHPEEK_PROCESS_MANAGER: phpeek-pm
    ports:
      - "80:80"
      - "9090:9090"  # Prometheus metrics
```

### Enable Laravel Services

```yaml
environment:
  PHPEEK_PROCESS_MANAGER: phpeek-pm

  # Laravel optimizations
  LARAVEL_OPTIMIZE_CONFIG: "true"
  LARAVEL_OPTIMIZE_ROUTE: "true"
  LARAVEL_MIGRATE_ENABLED: "true"

  # Enable Horizon
  PHPEEK_PM_PROCESS_HORIZON_ENABLED: "true"

  # Enable Queue Workers (with scaling)
  PHPEEK_PM_PROCESS_QUEUE_DEFAULT_ENABLED: "true"
  PHPEEK_PM_PROCESS_QUEUE_DEFAULT_SCALE: "3"
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
- `phpeek_pm_process_up` - Process running status
- `phpeek_pm_process_restarts_total` - Restart counts
- `phpeek_pm_process_cpu_seconds_total` - CPU usage
- `phpeek_pm_process_memory_bytes` - Memory usage
- `phpeek_pm_health_check_status` - Health check results
- `phpeek_pm_process_desired_scale` - Desired instances
- `phpeek_pm_process_current_scale` - Running instances

**Scheduled Task Metrics (v1.1.0+):**
- `phpeek_pm_scheduled_task_last_run_timestamp` - Last execution time
- `phpeek_pm_scheduled_task_next_run_timestamp` - Next scheduled time
- `phpeek_pm_scheduled_task_last_exit_code` - Most recent exit code
- `phpeek_pm_scheduled_task_duration_seconds` - Execution duration
- `phpeek_pm_scheduled_task_total` - Total runs by status (success/failure)

### 🔌 Management API (Phase 5)
REST API on port 8080 (when enabled):
- `GET /api/v1/processes` - List processes
- `POST /api/v1/processes/{name}/scale` - Dynamic scaling
- `POST /api/v1/processes/{name}/restart` - Restart process

## Architecture

### Process Management Modes

PHPeek base images support two process management modes:

1. **Default Mode** (simple)
   - Direct PHP-FPM + Nginx startup
   - Bash-based lifecycle management
   - Good for: Simple deployments, development

2. **PHPeek PM Mode** (phpeek-pm)
   - Go-based production process manager
   - Structured logging, health checks, metrics
   - Good for: Production, complex stacks, observability

**Switch modes** with `PHPEEK_PROCESS_MANAGER=phpeek-pm`

### Startup Sequence

When `PHPEEK_PROCESS_MANAGER=phpeek-pm`:

1. **docker-entrypoint.sh** detects PHPeek PM mode
2. **docker-entrypoint-phpeek-pm.sh** executes:
   - Detects framework (Laravel, Symfony, WordPress)
   - Sets up critical directories and permissions
   - Validates PHP-FPM and Nginx configs
   - Generates runtime config from template + env vars
3. **phpeek-pm binary** starts as PID 1:
   - Executes pre-start hooks (Laravel optimizations, migrations)
   - Starts processes in priority order with dependency resolution
   - Monitors health checks
   - Handles graceful shutdown on SIGTERM

### Configuration Flow

```
phpeek-pm.yaml (template)
    ↓ (environment variable substitution)
/tmp/phpeek-pm.yaml (runtime config)
    ↓
phpeek-pm binary reads config
    ↓
Processes start with environment-specific settings
```

### File Locations

| File | Location | Purpose |
|------|----------|---------|
| Template config | `/etc/phpeek-pm/phpeek-pm.yaml.template` | Base config with env var placeholders |
| Runtime config | `/tmp/phpeek-pm.yaml` | Generated config with actual values |
| PHPeek PM binary | `/usr/local/bin/phpeek-pm` | Process manager executable |
| Default entrypoint | `/usr/local/bin/docker-entrypoint.sh` | Mode selector |
| PHPeek PM entrypoint | `/usr/local/bin/docker-entrypoint-phpeek-pm.sh` | PHPeek PM setup |

## Examples

### Minimal (PHP-FPM + Nginx)

```yaml
services:
  app:
    image: phpeek/php-fpm-nginx:8.3-alpine
    environment:
      PHPEEK_PROCESS_MANAGER: phpeek-pm
```

### Laravel with Horizon

```yaml
services:
  app:
    image: phpeek/php-fpm-nginx:8.3-alpine
    environment:
      PHPEEK_PROCESS_MANAGER: phpeek-pm
      LARAVEL_OPTIMIZE_CONFIG: "true"
      LARAVEL_OPTIMIZE_ROUTE: "true"
      LARAVEL_MIGRATE_ENABLED: "true"
      PHPEEK_PM_PROCESS_HORIZON_ENABLED: "true"
```

### Full Laravel Stack

A complete example configuration for Laravel with PHPeek PM:

```yaml
services:
  app:
    image: ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine
    environment:
      PHPEEK_PROCESS_MANAGER: phpeek-pm

      # Laravel optimizations
      LARAVEL_OPTIMIZE_CONFIG: "true"
      LARAVEL_OPTIMIZE_ROUTE: "true"
      LARAVEL_OPTIMIZE_VIEW: "true"
      LARAVEL_MIGRATE_ENABLED: "true"

      # Enable Horizon
      PHPEEK_PM_PROCESS_HORIZON_ENABLED: "true"

      # Enable Reverb (WebSockets)
      PHPEEK_PM_PROCESS_REVERB_ENABLED: "true"

      # Enable Queue Workers (with scaling)
      PHPEEK_PM_PROCESS_QUEUE_DEFAULT_ENABLED: "true"
      PHPEEK_PM_PROCESS_QUEUE_DEFAULT_SCALE: "3"
      PHPEEK_PM_PROCESS_QUEUE_HIGH_ENABLED: "true"
      PHPEEK_PM_PROCESS_QUEUE_HIGH_SCALE: "2"
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

Complete reference: [phpeek-pm-environment-variables.md](./phpeek-pm-environment-variables.md)

**Quick reference**:

| Category | Key Variables |
|----------|---------------|
| **Mode Selection** | `PHPEEK_PROCESS_MANAGER=phpeek-pm` |
| **Laravel Hooks** | `LARAVEL_OPTIMIZE_*`, `LARAVEL_MIGRATE_ENABLED` |
| **Process Control** | `PHPEEK_PM_PROCESS_*_ENABLED` |
| **Scaling** | `PHPEEK_PM_PROCESS_QUEUE_*_SCALE` |
| **Observability** | `PHPEEK_PM_METRICS_ENABLED`, `PHPEEK_PM_API_ENABLED` |
| **Logging** | `PHPEEK_PM_LOG_LEVEL`, `PHPEEK_PM_LOG_FORMAT` |

## Monitoring

### Prometheus Scraping

Add to `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'phpeek-pm'
    static_configs:
      - targets: ['app:9090']
```

### Grafana Dashboard

Import dashboard from PHPeek PM repository (coming in Phase 4).

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

PHPeek PM includes a built-in cron-like scheduler for running periodic tasks **without requiring a separate cron daemon**. Perfect for Laravel scheduled commands, backups, cleanups, and maintenance tasks.

### Quick Start

Enable scheduled tasks with standard cron expressions:

```yaml
environment:
  PHPEEK_PROCESS_MANAGER: phpeek-pm

  # Laravel scheduled command (every 15 minutes)
  PHPEEK_PM_PROCESS_CACHE_WARMUP_ENABLED: "true"
  PHPEEK_PM_PROCESS_CACHE_WARMUP_COMMAND: "php,artisan,cache:warm"
  PHPEEK_PM_PROCESS_CACHE_WARMUP_SCHEDULE: "*/15 * * * *"

  # Database backup (daily at 2 AM)
  PHPEEK_PM_PROCESS_DB_BACKUP_ENABLED: "true"
  PHPEEK_PM_PROCESS_DB_BACKUP_COMMAND: "php,artisan,backup:run"
  PHPEEK_PM_PROCESS_DB_BACKUP_SCHEDULE: "0 2 * * *"
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
  PHPEEK_PM_PROCESS_CRITICAL_BACKUP_ENABLED: "true"
  PHPEEK_PM_PROCESS_CRITICAL_BACKUP_COMMAND: "php,artisan,backup:critical"
  PHPEEK_PM_PROCESS_CRITICAL_BACKUP_SCHEDULE: "0 3 * * *"
  PHPEEK_PM_PROCESS_CRITICAL_BACKUP_HEARTBEAT_URL: "https://hc-ping.com/your-uuid-here"
  PHPEEK_PM_PROCESS_CRITICAL_BACKUP_HEARTBEAT_TIMEOUT: "300"
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
PHPEEK_PM_PROCESS_NAME=backup-job
PHPEEK_PM_INSTANCE_ID=backup-job-run-42
PHPEEK_PM_SCHEDULED=true
PHPEEK_PM_SCHEDULE="0 2 * * *"
PHPEEK_PM_START_TIME=1732141200
```

### Laravel Scheduler Example

Replace Laravel's cron entry with PHPeek PM scheduled tasks:

**Old approach** (requires cron):
```cron
* * * * * cd /var/www && php artisan schedule:run >> /dev/null 2>&1
```

**New approach** (PHPeek PM v1.1.0+):
```yaml
environment:
  PHPEEK_PROCESS_MANAGER: phpeek-pm

  # Cache warmup every 15 minutes
  PHPEEK_PM_PROCESS_CACHE_WARMUP_ENABLED: "true"
  PHPEEK_PM_PROCESS_CACHE_WARMUP_COMMAND: "php,artisan,cache:warm"
  PHPEEK_PM_PROCESS_CACHE_WARMUP_SCHEDULE: "*/15 * * * *"

  # Database backup daily at 2 AM
  PHPEEK_PM_PROCESS_DB_BACKUP_ENABLED: "true"
  PHPEEK_PM_PROCESS_DB_BACKUP_COMMAND: "php,artisan,backup:run"
  PHPEEK_PM_PROCESS_DB_BACKUP_SCHEDULE: "0 2 * * *"
  PHPEEK_PM_PROCESS_DB_BACKUP_HEARTBEAT_URL: "https://hc-ping.com/backup-uuid"

  # Report generation Monday-Friday at 8 AM
  PHPEEK_PM_PROCESS_REPORTS_ENABLED: "true"
  PHPEEK_PM_PROCESS_REPORTS_COMMAND: "php,artisan,reports:generate"
  PHPEEK_PM_PROCESS_REPORTS_SCHEDULE: "0 8 * * 1-5"
```

### Metrics

Monitor scheduled tasks via Prometheus:

```promql
# Last execution time
phpeek_pm_scheduled_task_last_run_timestamp{process="backup-job"}

# Next scheduled execution
phpeek_pm_scheduled_task_next_run_timestamp{process="backup-job"}

# Task success rate
rate(phpeek_pm_scheduled_task_total{status="success"}[1h])
```

## Advanced Logging (v1.1.0+)

PHPeek PM provides enterprise-grade log processing with intelligent parsing and security features.

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
  PHPEEK_PM_LOG_MULTILINE_ENABLED: "true"
  PHPEEK_PM_LOG_MULTILINE_PATTERN: '^\[|^\d{4}-|^{"'  # Regex for line starts
  PHPEEK_PM_LOG_MULTILINE_TIMEOUT: "500"  # milliseconds
  PHPEEK_PM_LOG_MULTILINE_MAX_LINES: "100"
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
  PHPEEK_PM_LOG_REDACTION_ENABLED: "true"
  PHPEEK_PM_LOG_REDACTION_PATTERNS: "password,api_key,secret,token"
  PHPEEK_PM_LOG_REDACTION_PLACEHOLDER: "***REDACTED***"
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

Mount a custom `phpeek-pm.yaml`:

```yaml
services:
  app:
    image: phpeek/php-fpm-nginx:8.3-alpine
    environment:
      PHPEEK_PROCESS_MANAGER: phpeek-pm
      PHPEEK_PM_CONFIG: /app/config/phpeek-pm.yaml
    volumes:
      - ./custom-phpeek-pm.yaml:/app/config/phpeek-pm.yaml:ro
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
  PHPEEK_PM_PROCESS_QUEUE_DEFAULT_ENABLED: "true"
  PHPEEK_PM_PROCESS_QUEUE_DEFAULT_SCALE: "3"

  # High priority queue
  PHPEEK_PM_PROCESS_QUEUE_HIGH_ENABLED: "true"
  PHPEEK_PM_PROCESS_QUEUE_HIGH_SCALE: "2"
```

Each queue worker group is independently scalable and monitored.

## Migration Guide

### From Default Mode

**Before**:
```yaml
environment:
  PHPEEK_AUTORUN_ENABLED: "true"
  LARAVEL_AUTO_OPTIMIZE: "true"
  LARAVEL_AUTO_MIGRATE: "true"
```

**After**:
```yaml
environment:
  PHPEEK_PROCESS_MANAGER: phpeek-pm
  LARAVEL_OPTIMIZE_CONFIG: "true"
  LARAVEL_OPTIMIZE_ROUTE: "true"
  LARAVEL_OPTIMIZE_VIEW: "true"
  LARAVEL_MIGRATE_ENABLED: "true"
```

### From Supervisor/s6-overlay

**Benefits of switching**:
- ✅ Structured JSON logging with process segmentation
- ✅ Native Prometheus metrics
- ✅ Health checks with automatic restart
- ✅ Graceful shutdown handling (Horizon: horizon:terminate)
- ✅ Dynamic scaling via API (Phase 5)
- ✅ Dependency management (DAG-based startup order)

**No breaking changes** - PHPeek PM is a drop-in replacement.

## Troubleshooting

### Enable Debug Logging

```yaml
environment:
  PHPEEK_PM_LOG_LEVEL: debug
  PHPEEK_DEBUG: "true"
```

### Check Process Status

```bash
# Via metrics
curl http://localhost:9090/metrics | grep phpeek_pm_process_up

# Via logs
docker logs app | jq 'select(.msg | contains("Process"))'
```

### Disable Specific Processes

```yaml
environment:
  PHPEEK_PM_PROCESS_HORIZON_ENABLED: "false"
```

### Restart Issues

Increase restart attempts and backoff:
```yaml
environment:
  PHPEEK_PM_MAX_RESTART_ATTEMPTS: "10"
  PHPEEK_PM_RESTART_BACKOFF: "10"
```

## Roadmap

- [x] **Phase 1** - Core foundation with single process support
- [ ] **Phase 2** - Multi-process orchestration with dependencies (current)
  - DAG dependency resolver
  - Health checks (TCP, HTTP, exec)
  - Restart policies with exponential backoff
- [ ] **Phase 3** - Lifecycle hooks
  - Pre/post start/stop hooks
  - Per-process hooks (Horizon terminate)
- [ ] **Phase 4** - Prometheus metrics
  - Process metrics (up, restarts, CPU, memory)
  - Health check metrics
  - Scaling metrics
- [ ] **Phase 5** - Management API
  - REST API with authentication
  - Dynamic scaling endpoint
  - Process control (start, stop, restart)
- [ ] **Phase 6** - Testing & production readiness
  - Comprehensive tests
  - Documentation
  - Grafana dashboards

## Resources

- **PHPeek PM Repository**: https://github.com/gophpeek/phpeek-pm
- **Environment Variables**: See [phpeek-pm-environment-variables.md](./phpeek-pm-environment-variables.md)
- **Example Configs**: See examples throughout this documentation

## Support

For issues and feature requests:
- PHPeek Base Images: [GitHub Issues](https://github.com/gophpeek/baseimages/issues)
- PHPeek PM: [GitHub Issues](https://github.com/gophpeek/phpeek-pm/issues)
