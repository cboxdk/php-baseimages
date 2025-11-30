---
title: "Microservices Setup"
description: "Multiple PHP services with separate databases communicating via HTTP and Redis"
weight: 11
---

# Microservices Setup

Multiple independent PHP services with database-per-service pattern.

## Architecture

```
                    ┌─────────────────┐
                    │   API Gateway   │ :8080
                    └────────┬────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
┌───────▼───────┐   ┌────────▼────────┐   ┌──────▼──────┐
│ User Service  │   │  Order Service  │   │ Notification│
└───────┬───────┘   └────────┬────────┘   │   Service   │
        │                    │            └──────┬──────┘
┌───────▼───────┐   ┌────────▼────────┐          │
│  MySQL Users  │   │  MySQL Orders   │   ┌──────▼──────┐
└───────────────┘   └─────────────────┘   │   Worker    │
                                          └─────────────┘
                             │
                    ┌────────▼────────┐
                    │      Redis      │
                    │ (Cache + Queue) │
                    └─────────────────┘
```

## Services

| Service | Responsibility | Database |
|---------|----------------|----------|
| Gateway | Routing, auth validation | None |
| User Service | Users, auth, profiles | mysql-users |
| Order Service | Orders, inventory | mysql-orders |
| Notification | Emails, SMS, push | Redis queue |

## Quick Start

```bash
# Create service directories
mkdir -p gateway user-service order-service notification-service

# Initialize each as Laravel project
for service in gateway user-service order-service notification-service; do
    cd $service && composer create-project laravel/laravel . && cd ..
done

# Start all services
docker compose up -d

# Run migrations per service
docker compose exec user-service php artisan migrate
docker compose exec order-service php artisan migrate
```

## Service Communication

### HTTP Client (Synchronous)

```php
// In OrderService calling UserService
$response = Http::get(env('USER_SERVICE_URL') . '/api/users/' . $userId);
$user = $response->json();
```

### Events via Redis (Asynchronous)

```php
// In OrderService - publish event
Redis::publish('order.created', json_encode([
    'order_id' => $order->id,
    'user_id' => $order->user_id,
]));

// In NotificationService - subscribe
Redis::subscribe(['order.created'], function ($message) {
    // Send notification
});
```

### Queue Jobs (Background)

```php
// Dispatch job to notification service queue
dispatch(new SendOrderConfirmation($order))->onQueue('notifications');
```

## Gateway Pattern

```php
// gateway/routes/api.php
Route::prefix('users')->group(function () {
    Route::get('/', fn() => Http::get(env('USER_SERVICE_URL') . '/api/users'));
    Route::get('/{id}', fn($id) => Http::get(env('USER_SERVICE_URL') . '/api/users/' . $id));
});

Route::prefix('orders')->group(function () {
    Route::get('/', fn() => Http::get(env('ORDER_SERVICE_URL') . '/api/orders'));
    Route::post('/', fn(Request $r) => Http::post(env('ORDER_SERVICE_URL') . '/api/orders', $r->all()));
});
```

## Health Check Endpoints

Each service should expose `/health`:

```php
// routes/api.php
Route::get('/health', function () {
    return response()->json([
        'service' => config('app.name'),
        'status' => 'healthy',
        'database' => DB::connection()->getPdo() ? 'connected' : 'disconnected',
    ]);
});
```

## Scaling

```bash
# Scale specific service
docker compose up -d --scale order-service=3

# Scale workers
docker compose up -d --scale notification-worker=5
```

## Common Commands

```bash
# View all service logs
docker compose logs -f

# Specific service logs
docker compose logs -f order-service

# Run command in service
docker compose exec user-service php artisan tinker

# Restart after code changes
docker compose restart user-service
```

## Production Considerations

- **Service Discovery**: Use Consul, etcd, or Kubernetes DNS
- **Load Balancing**: Put Traefik/Nginx in front of scaled services
- **Circuit Breaker**: Implement with packages like `ackintosh/ganesha`
- **Distributed Tracing**: Use Jaeger or Zipkin
- **API Versioning**: `/v1/users`, `/v2/users`
- **Centralized Logging**: ELK Stack or Grafana Loki
