---
title: "Observability & Health Checks"
description: "Application-level health checks, queue metrics, and autoscaling with cboxdk packages"
weight: 8
---

# Observability & Health Checks

Cbox images include infrastructure-level observability out of the box (Prometheus metrics on port 9090, process health checks). This guide adds **application-level** observability using three optional packages from Cbox.

## Overview

| Layer | What it monitors | Package |
|-------|-----------------|---------|
| **Infrastructure** | Process alive? CPU/memory per process, restart counts | Built-in (cbox-init) |
| **Application Health** | Can the app reach DB, Redis, cache, storage? | `cboxdk/laravel-health` |
| **Queue Observability** | Job P95/P99 latency, failure rates, queue depth, worker utilization | `cboxdk/laravel-queue-metrics` |
| **Queue Autoscaling** | Dynamic worker count based on load, SLA targets, resource limits | `cboxdk/laravel-queue-autoscale` |

All three packages are optional. Install only what you need.

## Laravel Health

Application-level health checks with Kubernetes-ready probe endpoints.

- **Package:** [cbox.dk/packages/laravel-health](https://cbox.dk/packages/laravel-health)
- **Docs:** [cbox.dk/packages/laravel-health/docs](https://cbox.dk/packages/laravel-health/docs)

### Install

```bash
composer require cboxdk/laravel-health
php artisan vendor:publish --tag="health-config"
```

### What it checks

| Check | What it verifies | Used by default |
|-------|-----------------|-----------------|
| `DatabaseCheck` | PDO connection to configured database | Liveness + Readiness |
| `RedisCheck` | PING/PONG to Redis | Readiness |
| `CacheCheck` | Write/read/delete cycle on cache store | Readiness |
| `QueueCheck` | Queue connection + reports queue size | Readiness |
| `StorageCheck` | Write/delete temp file on disk | Readiness |
| `ScheduleCheck` | Scheduler heartbeat freshness (requires `health:heartbeat` scheduled command) | — |
| `CpuCheck` | Load average per core vs threshold | — |
| `MemoryCheck` | Memory usage vs threshold | — |
| `DiskSpaceCheck` | Disk usage vs threshold (all mounts) | — |
| `EnvironmentCheck` | Required env vars exist | — |

### Endpoints

| Path | Purpose | Auth required |
|------|---------|---------------|
| `/health/` | Liveness probe (DB only) | No (public by default) |
| `/health/ready` | Readiness probe (DB + Redis + Cache + Queue + Storage) | Yes |
| `/health/startup` | Startup probe (always passes — "is Laravel booted?") | Yes |
| `/health/status` | Full status with system metrics | Yes |
| `/health/metrics` | Prometheus format | Yes |
| `/health/metrics/json` | JSON format system metrics | Yes |

Returns HTTP 200 when healthy, 503 when critical. Warnings still return 200.

### Using with Cbox Init

**php-fpm-nginx (HTTP health check):**

The liveness endpoint at `/health/` requires no authentication and works directly as a cbox-init health check. However, the default Nginx config includes a static `/health` location block that returns "healthy" without reaching PHP-FPM. Use the trailing-slash path to reach Laravel:

```yaml
# docker-compose.yml
services:
  app:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm
    environment:
      LARAVEL_SCHEDULER: "true"
```

To use application-level health checks instead of the static Nginx response, mount a custom `cbox-init.yaml` with the health check URL pointing to `/health/`:

```yaml
# custom-cbox-init.yaml (partial)
processes:
  nginx:
    health_check:
      type: http
      url: "http://127.0.0.1:80/health/"
      expected_status: 200
      period: 30
      timeout: 10
```

**php-cli (exec health check):**

For CLI workloads with no web server, use the `health:check` artisan command:

```yaml
# custom-cbox-init.yaml (partial)
processes:
  queue-default:
    health_check:
      type: exec
      command: ["php", "artisan", "health:check", "--endpoint=readiness"]
      period: 30
      timeout: 10
```

This verifies DB, Redis, cache, and queue connectivity before considering the worker healthy.

### Scheduler heartbeat

Add to your Laravel scheduler to enable `ScheduleCheck`:

```php
// routes/console.php or app/Console/Kernel.php
Schedule::command('health:heartbeat')->everyMinute();
```

When `LARAVEL_SCHEDULER=true`, cbox-init runs `schedule:work` which picks this up automatically.

---

## Laravel Queue Metrics

Production-grade queue observability with per-job performance tracking and Prometheus export.

- **Package:** [cbox.dk/packages/laravel-queue-metrics](https://cbox.dk/packages/laravel-queue-metrics)
- **Docs:** [cbox.dk/packages/laravel-queue-metrics/docs](https://cbox.dk/packages/laravel-queue-metrics/docs)

### Install

```bash
composer require cboxdk/laravel-queue-metrics
```

Zero configuration needed — the package hooks into Laravel's queue events automatically.

### What it tracks

**Per job class:**
- Duration: avg, P50, P95, P99, max
- Memory: avg, peak, P95, P99 (real RSS via `/proc`, including child processes)
- CPU time per job
- Success/failure counts and rates
- Throughput (jobs/min, jobs/hour)

**Per queue:**
- Pending, delayed, reserved job counts
- Oldest job age (backlog staleness)
- Throughput and failure rates

**Workers:**
- Active/idle counts and utilization percentage
- Stale worker detection
- Horizon-aware (includes supervisor context)

**Baselines & Trends:**
- Automatic performance baselines with deviation detection
- Linear regression trends with forecasting

### Prometheus endpoint

Exposed at `/queue-metrics/prometheus`. Namespace configurable via `QUEUE_METRICS_PROMETHEUS_NAMESPACE` (default: `laravel_queue`).

### Combined Prometheus scrape config

Scrape both cbox-init infrastructure metrics and application metrics:

```yaml
# prometheus.yml
scrape_configs:
  - job_name: cbox-init
    static_configs:
      - targets: ['app:9090']
    metrics_path: /metrics

  - job_name: laravel-health
    static_configs:
      - targets: ['app:80']
    metrics_path: /health/metrics

  - job_name: laravel-queue
    static_configs:
      - targets: ['app:80']
    metrics_path: /queue-metrics/prometheus
```

### Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `QUEUE_METRICS_ENABLED` | `true` | Master switch |
| `QUEUE_METRICS_STORAGE` | `redis` | Storage driver (`redis` or `database`) |
| `QUEUE_METRICS_PROMETHEUS_ENABLED` | `true` | Enable Prometheus endpoint |
| `QUEUE_METRICS_PROMETHEUS_NAMESPACE` | `laravel_queue` | Prometheus metric prefix |
| `QUEUE_METRICS_STALE_THRESHOLD` | `60` | Seconds before worker is considered stale |

### What cbox-init sees vs what queue-metrics sees

| Question | cbox-init answers | queue-metrics answers |
|----------|------------------|----------------------|
| Is the worker process running? | Yes (TCP/exec check) | — |
| How much RAM does the worker use? | 500MB (process level) | ProcessOrder: peak 120MB per job |
| Are jobs failing? | — | SendEmail: 12% failure rate, P95=3.2s |
| Is the queue backing up? | — | 5,000 pending, oldest job 45s, trending up |
| Should we scale workers? | — | Current throughput: 200/min, arrival: 350/min |

---

## Laravel Queue Autoscale

Dynamic queue worker scaling based on real-time queue depth, arrival rates, and SLA targets.

- **Package:** [cbox.dk/packages/laravel-queue-autoscale](https://cbox.dk/packages/laravel-queue-autoscale)
- **Docs:** [cbox.dk/packages/laravel-queue-autoscale/docs](https://cbox.dk/packages/laravel-queue-autoscale/docs)

### Install

```bash
composer require cboxdk/laravel-queue-autoscale
php artisan vendor:publish --tag="queue-autoscale-config"
```

Requires `cboxdk/laravel-queue-metrics` (installed automatically as a dependency).

### How it works

The autoscaler runs as a long-lived process that evaluates every 5 seconds:

1. **Rate-based** (Little's Law): `workers = arrival_rate × avg_job_time`
2. **Trend-based** (predictive): Applies a growth buffer (10-30%) based on trend direction
3. **Backlog-based** (SLA protection): Calculates workers needed to drain the queue before SLA breach
4. Takes the **maximum** of all three, then clamps to resource limits (CPU, memory) and configured min/max bounds

### Using with Cbox Init

The autoscaler spawns its own `queue:work` child processes — it does **not** use cbox-init's scale API. When using the autoscaler, disable cbox-init's own queue workers to avoid conflicts:

```yaml
# docker-compose.yml
services:
  autoscaler:
    image: ghcr.io/cboxdk/php-baseimages/php-cli:8.4-bookworm
    environment:
      CBOX_QUEUE_AUTOSCALER: "true"
      # Do NOT set LARAVEL_QUEUE or LARAVEL_QUEUE_HIGH — autoscaler manages workers itself
```

This runs `php artisan queue:autoscale` as a cbox-init managed process, which then spawns and manages its own queue workers dynamically.

### Profile presets

| Profile | SLA target | Workers | Cooldown | Use case |
|---------|-----------|---------|----------|----------|
| `critical` | 10s | 5-50 | 30s | Payment processing, real-time |
| `highVolume` | 20s | 3-40 | 45s | High throughput APIs |
| `balanced` | 30s | 1-10 | 30s | Most apps (default) |
| `bursty` | 60s | 0-100 | 20s | Unpredictable spikes |
| `background` | 300s | 0-5 | 120s | Reports, exports, low priority |

### Environment variables

Configure per-queue SLA targets in `config/queue-autoscale.php`. The main env vars:

| Variable | Default | Description |
|----------|---------|-------------|
| `CBOX_QUEUE_AUTOSCALER` | `false` | Enable autoscaler via cbox-init |

---

## Full Stack Example

Complete Laravel setup with all three packages:

```yaml
services:
  # Web application with health checks
  app:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm
    ports:
      - "80:80"
      - "9090:9090"    # cbox-init Prometheus metrics
    environment:
      LARAVEL_SCHEDULER: "true"
      LARAVEL_OPTIMIZE_ENABLED: "true"

  # Queue autoscaler (manages its own workers)
  autoscaler:
    image: ghcr.io/cboxdk/php-baseimages/php-cli:8.4-bookworm
    environment:
      CBOX_QUEUE_AUTOSCALER: "true"
    volumes:
      - ./:/var/www/html
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_healthy

  # Prometheus
  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9091:9090"

  mysql:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: secret
      MYSQL_DATABASE: laravel
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      retries: 5
```

```yaml
# prometheus.yml
scrape_configs:
  - job_name: cbox-init
    static_configs:
      - targets: ['app:9090']

  - job_name: laravel-health
    static_configs:
      - targets: ['app:80']
    metrics_path: /health/metrics

  - job_name: laravel-queue
    static_configs:
      - targets: ['app:80']
    metrics_path: /queue-metrics/prometheus
```
