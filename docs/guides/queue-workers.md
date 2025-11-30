---
title: "Queue Workers Guide"
description: "Running background jobs with Laravel queues, Horizon, and PHP workers"
weight: 5
---

# Queue Workers Guide

Run background jobs reliably with PHPeek images.

## Quick Start

```yaml
# docker-compose.yml
services:
  worker:
    image: phpeek/php-fpm-nginx:8.3-alpine
    command: php artisan queue:work redis --sleep=3 --tries=3
    volumes:
      - ./:/var/www/html
    environment:
      QUEUE_CONNECTION: redis
      REDIS_HOST: redis
    depends_on:
      - redis
```

## Worker Types

### Basic Queue Worker

Simple worker for processing jobs:

```yaml
worker:
  image: phpeek/php-fpm-nginx:8.3-alpine
  command: php artisan queue:work redis --sleep=3 --tries=3 --max-jobs=1000 --max-time=3600
  restart: unless-stopped
```

**Options explained**:
- `--sleep=3`: Wait 3 seconds when no jobs
- `--tries=3`: Retry failed jobs 3 times
- `--max-jobs=1000`: Restart after 1000 jobs (prevents memory leaks)
- `--max-time=3600`: Restart after 1 hour

### Laravel Horizon

Comprehensive queue management with dashboard:

```yaml
horizon:
  image: phpeek/php-fpm-nginx:8.3-alpine
  command: php artisan horizon
  restart: unless-stopped
  volumes:
    - ./:/var/www/html
  environment:
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
  image: phpeek/php-fpm-nginx:8.3-alpine
  command: >
    sh -c "while true; do
      php artisan schedule:run --verbose --no-interaction
      sleep 60
    done"
  restart: unless-stopped
```

Or use the built-in cron support:

```yaml
scheduler:
  image: phpeek/php-fpm-nginx:8.3-alpine
  environment:
    LARAVEL_SCHEDULER_ENABLED: "true"
```

## Architecture Patterns

### Simple Setup (1-5 workers)

```yaml
services:
  app:
    image: phpeek/php-fpm-nginx:8.3-alpine

  worker:
    image: phpeek/php-fpm-nginx:8.3-alpine
    command: php artisan queue:work
    deploy:
      replicas: 3
```

### Queue Priority Setup

```yaml
services:
  worker-high:
    image: phpeek/php-fpm-nginx:8.3-alpine
    command: php artisan queue:work --queue=high,default

  worker-low:
    image: phpeek/php-fpm-nginx:8.3-alpine
    command: php artisan queue:work --queue=low
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
