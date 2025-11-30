---
title: "Laravel Reverb WebSockets"
description: "Real-time features with Laravel's native PHP WebSocket server"
weight: 12
---

# Laravel Reverb WebSockets

Real-time broadcasting with Laravel Reverb - native PHP WebSocket server.

## Quick Start

```bash
# Install Reverb
docker compose exec app composer require laravel/reverb
docker compose exec app php artisan reverb:install

# Start all services
docker compose up -d

# Test WebSocket connection
# Visit http://localhost:8080 and check browser console
```

## Architecture

```
┌─────────────────┐     ┌─────────────────┐
│   Web Browser   │────▶│    App:8080     │
│  (Echo client)  │     └────────┬────────┘
└────────┬────────┘              │
         │ WebSocket             │ Broadcast
         │                       ▼
┌────────▼────────┐     ┌─────────────────┐
│  Reverb:8085    │◀────│     Worker      │
│ (WebSocket srv) │     └────────┬────────┘
└────────┬────────┘              │
         │                       │
         └───────────┬───────────┘
                     │
              ┌──────▼──────┐
              │    Redis    │
              │ (Pub/Sub)   │
              └─────────────┘
```

## Frontend Setup

### Install Laravel Echo

```bash
npm install --save-dev laravel-echo pusher-js
```

### Configure Echo

```javascript
// resources/js/bootstrap.js
import Echo from 'laravel-echo';
import Pusher from 'pusher-js';

window.Pusher = Pusher;

window.Echo = new Echo({
    broadcaster: 'reverb',
    key: import.meta.env.VITE_REVERB_APP_KEY,
    wsHost: import.meta.env.VITE_REVERB_HOST,
    wsPort: import.meta.env.VITE_REVERB_PORT ?? 8085,
    wssPort: import.meta.env.VITE_REVERB_PORT ?? 443,
    forceTLS: (import.meta.env.VITE_REVERB_SCHEME ?? 'https') === 'https',
    enabledTransports: ['ws', 'wss'],
});
```

### Environment Variables

```env
VITE_REVERB_APP_KEY=app-key
VITE_REVERB_HOST=localhost
VITE_REVERB_PORT=8085
VITE_REVERB_SCHEME=http
```

## Broadcasting Events

### Create Event

```php
// app/Events/MessageSent.php
class MessageSent implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public Message $message
    ) {}

    public function broadcastOn(): array
    {
        return [
            new Channel('chat'),
            // Or private channel
            new PrivateChannel('chat.' . $this->message->room_id),
        ];
    }
}
```

### Dispatch Event

```php
// In your controller
event(new MessageSent($message));

// Or using broadcast helper
broadcast(new MessageSent($message));

// To others only (exclude sender)
broadcast(new MessageSent($message))->toOthers();
```

### Listen in Frontend

```javascript
// Public channel
Echo.channel('chat')
    .listen('MessageSent', (e) => {
        console.log('New message:', e.message);
    });

// Private channel (requires authentication)
Echo.private(`chat.${roomId}`)
    .listen('MessageSent', (e) => {
        console.log('New message:', e.message);
    });
```

## Channel Authorization

```php
// routes/channels.php
Broadcast::channel('chat.{roomId}', function ($user, $roomId) {
    return $user->belongsToRoom($roomId);
});
```

## Presence Channels

For "who's online" features:

```javascript
Echo.join(`room.${roomId}`)
    .here((users) => {
        console.log('Users in room:', users);
    })
    .joining((user) => {
        console.log('User joined:', user);
    })
    .leaving((user) => {
        console.log('User left:', user);
    });
```

## Common Commands

```bash
# Start Reverb manually
docker compose exec reverb php artisan reverb:start --debug

# Check Reverb status
docker compose exec reverb php artisan reverb:status

# Restart after config changes
docker compose restart reverb worker

# View WebSocket logs
docker compose logs -f reverb
```

## Scaling

```bash
# Scale workers for high broadcast volume
docker compose up -d --scale worker=3
```

## Production Notes

- Use WSS (secure WebSockets) with SSL certificate
- Configure proper CORS headers
- Set up Redis cluster for horizontal scaling
- Monitor WebSocket connections with metrics
- Consider connection limits per user
