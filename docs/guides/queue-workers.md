---
title: "Queue Workers Guide"
description: "Running background jobs with Laravel queues, Horizon, and PHP workers"
weight: 4
---

# Queue Workers Guide

Run background jobs reliably with Cbox images.

## Quick Start

Use the `php-cli` image with process env vars. The entrypoint auto-starts Cbox Init with structured logging, metrics, health checks, and graceful shutdown:

```yaml
# docker-compose.yml
services:
  worker:
    image: ghcr.io/cboxdk/php-baseimages/php-cli:8.5-bookworm-v1
    volumes:
      - ./:/var/www/html
    environment:
      LARAVEL_QUEUE: "true"
      QUEUE_CONNECTION: redis
      REDIS_HOST: redis
    depends_on:
      - redis

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data

volumes:
  redis_data:
```

Scale workers within a single container using `CBOX_INIT_PROCESS_QUEUE_DEFAULT_SCALE`:

```yaml
  worker:
    image: ghcr.io/cboxdk/php-baseimages/php-cli:8.5-bookworm-v1
    environment:
      LARAVEL_QUEUE: "true"
      CBOX_INIT_PROCESS_QUEUE_DEFAULT_SCALE: "5"
```

Add a high-priority queue with `LARAVEL_QUEUE_HIGH`:

```yaml
  worker:
    image: ghcr.io/cboxdk/php-baseimages/php-cli:8.5-bookworm-v1
    environment:
      LARAVEL_QUEUE: "true"
      LARAVEL_QUEUE_HIGH: "true"
      CBOX_INIT_PROCESS_QUEUE_DEFAULT_SCALE: "3"
      CBOX_INIT_PROCESS_QUEUE_HIGH_SCALE: "2"
```

### Alternative: Direct Command

If you need full control over the `queue:work` arguments, you can bypass Cbox Init with a direct command override. This loses structured logging, metrics, health checks, and graceful shutdown:

```yaml
  worker:
    image: ghcr.io/cboxdk/php-baseimages/php-cli:8.5-bookworm-v1
    command: php artisan queue:work redis --sleep=3 --tries=3
    volumes:
      - ./:/var/www/html
    environment:
      QUEUE_CONNECTION: redis
      REDIS_HOST: redis
```

## Worker Types

### Basic Queue Worker

Simple worker for processing jobs:

```yaml
worker:
  image: ghcr.io/cboxdk/php-baseimages/php-cli:8.5-bookworm-v1
  environment:
    LARAVEL_QUEUE: "true"
  restart: unless-stopped
```

Cbox Init manages restarts, memory limits, and graceful shutdown automatically. To customize `queue:work` arguments, use a direct command override instead:

```yaml
worker:
  image: ghcr.io/cboxdk/php-baseimages/php-cli:8.5-bookworm-v1
  command: php artisan queue:work redis --sleep=3 --tries=3 --max-jobs=1000 --max-time=3600
  restart: unless-stopped
```

**Options explained** (direct command only):
- `--sleep=3`: Wait 3 seconds when no jobs
- `--tries=3`: Retry failed jobs 3 times
- `--max-jobs=1000`: Restart after 1000 jobs (prevents memory leaks)
- `--max-time=3600`: Restart after 1 hour

### Laravel Horizon

Comprehensive queue management with dashboard:

```yaml
horizon:
  image: ghcr.io/cboxdk/php-baseimages/php-cli:8.5-bookworm-v1
  restart: unless-stopped
  volumes:
    - ./:/var/www/html
  environment:
    LARAVEL_HORIZON: "true"
    QUEUE_CONNECTION: redis
    REDIS_HOST: redis
```

Access dashboard at `/horizon` after installing:

```bash
composer require laravel/horizon
php artisan horizon:install
php artisan migrate
```

### Scheduler (Cron Jobs)

Run Laravel scheduled tasks:

```yaml
scheduler:
  image: ghcr.io/cboxdk/php-baseimages/php-cli:8.5-bookworm-v1
  restart: unless-stopped
  environment:
    LARAVEL_SCHEDULER: "true"
```

Cbox Init runs `schedule:work` with structured logging, metrics, and graceful shutdown.

**Alternative: Direct Command** (loses Cbox Init features):

```yaml
scheduler:
  image: ghcr.io/cboxdk/php-baseimages/php-cli:8.5-bookworm-v1
  command: >
    sh -c "while true; do
      php artisan schedule:run --verbose --no-interaction
      sleep 60
    done"
  restart: unless-stopped
```

## Architecture Patterns

### Simple Setup (1-5 workers)

```yaml
services:
  app:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.5-bookworm-v1

  worker:
    image: ghcr.io/cboxdk/php-baseimages/php-cli:8.5-bookworm-v1
    environment:
      LARAVEL_QUEUE: "true"
      CBOX_INIT_PROCESS_QUEUE_DEFAULT_SCALE: "3"
```

### Queue Priority Setup

```yaml
services:
  worker:
    image: ghcr.io/cboxdk/php-baseimages/php-cli:8.5-bookworm-v1
    environment:
      LARAVEL_QUEUE: "true"
      LARAVEL_QUEUE_HIGH: "true"
      CBOX_INIT_PROCESS_QUEUE_DEFAULT_SCALE: "2"
      CBOX_INIT_PROCESS_QUEUE_HIGH_SCALE: "2"
```

### Horizon with Auto-Scaling

```php
// config/horizon.php
'environments' => [
    'production' => [
        'supervisor-1' => [
            'connection' => 'redis',
            'queue' => ['high', 'default', 'low'],
            'balance' => 'auto',
            'minProcesses' => 1,
            'maxProcesses' => 10,
            'balanceMaxShift' => 1,
            'balanceCooldown' => 3,
        ],
    ],
],
```

## Who the Workers Run As, and Where

Both answers follow PHP-FPM, so a job never leaves behind a file the web
requests cannot write.

**User.** When the container starts as root, the workers, scheduler, Horizon,
Reverb and the queue autoscaler all run as the PHP-FPM pool user — `www-data`,
remapped if you set `PUID`/`PGID`. That matters more than it sounds: a job that
writes a cache entry, compiles a view, appends to a log, or commits through
Statamic's git automation used to leave those files root-owned, and the next web
request could not write them.

```bash
# Workers and the FPM pool report the same uid
docker compose exec app ps -eo user,uid,args | grep -E "queue:work|php-fpm: pool"
```

In a container that is already unprivileged — a `-rootless` image,
`--user 1000:1000`, OpenShift's arbitrary UID — there is nothing to drop to, and
the processes simply run as the container's own user. Override a single process
with `CBOX_INIT_PROCESS_<NAME>_USER` when you really need to.

**Directory.** Every app process starts in `$WORKDIR` (default
`/var/www/html`). Set `WORKDIR` and the workers follow, which is what makes
release-based deploys work:

```yaml
environment:
  WORKDIR: /app/current          # a symlink to the live release
  NGINX_WEBROOT: /app/current/public
  LARAVEL_QUEUE: "true"
```

After a release swap, `php artisan queue:restart` is enough: the workers exit,
Cbox Init restarts them, and they come back up in the new release.

## Queue Drivers

### Redis (Recommended)

```yaml
services:
  worker:
    environment:
      QUEUE_CONNECTION: redis
      REDIS_HOST: redis

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data

volumes:
  redis_data:
```

### Database

```yaml
services:
  worker:
    environment:
      QUEUE_CONNECTION: database
      DB_HOST: mysql
```

Run migration first:
```bash
php artisan queue:table
php artisan migrate
```

### Amazon SQS

```yaml
services:
  worker:
    environment:
      QUEUE_CONNECTION: sqs
      AWS_ACCESS_KEY_ID: your-key
      AWS_SECRET_ACCESS_KEY: your-secret
      SQS_PREFIX: https://sqs.us-east-1.amazonaws.com/your-account
      SQS_QUEUE: your-queue
```

## Job Configuration

### Creating Jobs

```php
// app/Jobs/ProcessOrder.php
class ProcessOrder implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public $tries = 3;
    public $timeout = 120;
    public $maxExceptions = 2;

    public function __construct(
        public Order $order
    ) {}

    public function handle(): void
    {
        // Process order
    }

    public function failed(Throwable $exception): void
    {
        // Handle failure
    }
}
```

### Dispatching Jobs

```php
// Immediate dispatch
ProcessOrder::dispatch($order);

// Delayed dispatch
ProcessOrder::dispatch($order)->delay(now()->addMinutes(5));

// Specific queue
ProcessOrder::dispatch($order)->onQueue('high');

// Chain jobs
Bus::chain([
    new ProcessOrder($order),
    new SendConfirmation($order),
    new NotifyAdmin($order),
])->dispatch();
```

### Batching Jobs

```php
$batch = Bus::batch([
    new ProcessOrder($order1),
    new ProcessOrder($order2),
    new ProcessOrder($order3),
])->then(function (Batch $batch) {
    // All jobs completed
})->catch(function (Batch $batch, Throwable $e) {
    // First failure
})->finally(function (Batch $batch) {
    // Batch finished
})->dispatch();
```

## Monitoring

### Health Check Endpoint

```php
// routes/api.php
Route::get('/health/queue', function () {
    $pending = Queue::size();
    $failed = DB::table('failed_jobs')->count();

    return response()->json([
        'status' => $pending < 1000 ? 'healthy' : 'backlog',
        'pending_jobs' => $pending,
        'failed_jobs' => $failed,
    ]);
});
```

### Horizon Metrics

```php
// Access via Horizon dashboard or API
$metrics = app('horizon.metrics');
$throughput = $metrics->throughput();
$runtime = $metrics->runtime();
```

### Failed Jobs

```bash
# List failed jobs
php artisan queue:failed

# Retry all failed
php artisan queue:retry all

# Retry specific job
php artisan queue:retry 5

# Clear failed jobs
php artisan queue:flush
```

## Best Practices

### Memory Management

```php
// In job class
public function handle(): void
{
    // Process in chunks to manage memory
    Order::chunk(100, function ($orders) {
        foreach ($orders as $order) {
            $this->process($order);
        }
    });
}
```

### Graceful Shutdown

```yaml
worker:
  stop_grace_period: 30s
  command: php artisan queue:work --timeout=25
```

The worker will finish current job before shutting down.

### Job Timeouts

```php
class LongRunningJob implements ShouldQueue
{
    public $timeout = 3600; // 1 hour

    public function retryUntil(): DateTime
    {
        return now()->addHours(24);
    }
}
```

### Unique Jobs

```php
class ProcessPodcast implements ShouldQueue, ShouldBeUnique
{
    public function uniqueId(): string
    {
        return $this->podcast->id;
    }

    public function uniqueFor(): int
    {
        return 60; // seconds
    }
}
```

## Scaling

### Horizontal Scaling

```bash
# Scale workers
docker compose up -d --scale worker=5
```

### Auto-Scaling (Kubernetes)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: queue-worker
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: queue-worker
  minReplicas: 1
  maxReplicas: 10
  metrics:
    - type: External
      external:
        metric:
          name: redis_queue_size
        target:
          type: AverageValue
          averageValue: 100
```

## Troubleshooting

### Jobs Not Processing

1. Check worker is running: `docker compose ps`
2. Check queue connection: `php artisan queue:monitor`
3. Check Redis connection: `redis-cli ping`
4. Check job syntax: `php artisan queue:work --once`

### `Could not open input file: artisan` in the worker log

The workers start in `$WORKDIR`, and your app is somewhere else. Set `WORKDIR`
to the directory that holds `artisan` (for release-based deploys, your `current`
symlink) and the workers follow it.

### A job wrote a file the web requests cannot read or write

Check that the workers and the FPM pool agree on a uid:

```bash
docker compose exec app ps -eo user,uid,args | grep -E "queue:work|php-fpm: pool"
```

They should match. If the worker shows `root` while the pool shows your app
user, something overrode it — look for a `CBOX_INIT_PROCESS_*_USER` or an
explicit `CBOX_APP_USER` in your environment. To repair what is already on disk:

```bash
docker compose exec app chown -R www-data:www-data storage bootstrap/cache
```

### Memory Exhaustion

1. Add `--max-jobs=1000` to restart workers periodically
2. Process data in chunks
3. Use `gc_collect_cycles()` for complex jobs

### Jobs Timing Out

1. Increase `--timeout` value
2. Set job-specific `$timeout` property
3. Break into smaller jobs
4. Use job chaining

### High Failure Rate

1. Check `failed_jobs` table for errors
2. Implement proper error handling
3. Use exponential backoff
4. Add dead letter queue for inspection
