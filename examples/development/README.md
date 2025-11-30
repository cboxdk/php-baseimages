---
title: "Development Environment"
description: "Full development setup with Xdebug, Vite HMR, MailHog, and exposed ports"
weight: 7
---

# Development Environment

Full-featured development environment with debugging, hot reload, and email testing.

## Quick Start

```bash
# Start all services
docker compose up -d

# Install dependencies
docker compose exec app composer install
docker compose exec app npm install

# Setup application
docker compose exec app php artisan key:generate
docker compose exec app php artisan migrate

# Start Vite (if not using vite service)
docker compose exec app npm run dev
```

## Services & Ports

| Service | Purpose | Port |
|---------|---------|------|
| `app` | PHP application | 8080 |
| `vite` | Vite dev server | 5174 |
| `mysql` | Database | 3306 |
| `redis` | Cache | 6379 |
| `mailhog` | Email testing | 8025 (Web), 1025 (SMTP) |

## Xdebug Setup

### VS Code (launch.json)

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Listen for Xdebug",
            "type": "php",
            "request": "launch",
            "port": 9003,
            "pathMappings": {
                "/var/www/html": "${workspaceFolder}"
            }
        }
    ]
}
```

### PhpStorm

1. Go to **Settings → PHP → Servers**
2. Add server: Name=`docker`, Host=`localhost`, Port=`8080`
3. Enable path mappings: `/var/www/html` → your project path
4. Go to **Run → Start Listening for PHP Debug Connections**

### Xdebug Configuration (docker/xdebug.ini)

```ini
zend_extension=xdebug
xdebug.mode=debug,develop,coverage
xdebug.client_host=host.docker.internal
xdebug.client_port=9003
xdebug.start_with_request=yes
xdebug.discover_client_host=0
xdebug.idekey=VSCODE
```

## Hot Module Replacement (Vite)

Configure `vite.config.js`:

```javascript
export default defineConfig({
    server: {
        host: '0.0.0.0',
        port: 5173,
        hmr: {
            host: 'localhost',
            port: 5174,
        },
    },
});
```

## Email Testing with MailHog

Configure Laravel `.env`:

```env
MAIL_MAILER=smtp
MAIL_HOST=mailhog
MAIL_PORT=1025
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
```

View emails at: http://localhost:8025

## Database Tools

Connect with any MySQL client:
- Host: `localhost`
- Port: `3306`
- User: `app` or `root`
- Password: `secret` or `root`

## Common Commands

```bash
# Run tests with coverage
docker compose exec app php artisan test --coverage

# Watch tests
docker compose exec app php artisan test --watch

# Fresh database
docker compose exec app php artisan migrate:fresh --seed

# View all logs
docker compose logs -f
```

## Performance Note

This setup prioritizes **developer experience** over performance:
- Xdebug adds overhead (~30% slower)
- Volume mounts are slower than production
- All ports are exposed for tooling access

For production-like testing, use the `production` example instead.
