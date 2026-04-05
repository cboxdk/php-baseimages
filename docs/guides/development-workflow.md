---
title: "Development Workflow Guide"
description: "Optimize your local development workflow with Cbox including Xdebug setup, hot-reload, testing, and debugging strategies"
weight: 15
---

# Development Workflow Guide

Optimize your local development experience with Cbox PHP Base Images including Xdebug, hot-reload, profiling, and efficient debugging.

## Dev Images

Cbox provides **pre-built development images** with Xdebug, PCOV, and SPX already installed. These are the easiest way to get started with debugging and profiling.

Available dev images:
- `ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.5-bookworm-dev`
- `ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-dev`
- `ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.3-bookworm-dev`
- `ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.2-bookworm-dev`

For choosing between dev, slim, standard, and chromium tiers, see [Choosing Your Image](../getting-started/choosing-your-image).

## Development docker-compose.yml

```yaml
version: '3.8'

services:
  app:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-dev
    ports:
      - "8000:80"
      - "9003:9003"  # Xdebug port
    volumes:
      - ./:/var/www/html
    environment:
      # Xdebug configuration
      - XDEBUG_MODE=debug,develop,coverage
      - XDEBUG_CONFIG=client_host=host.docker.internal client_port=9003
      - PHP_IDE_CONFIG=serverName=docker

      # Application
      - APP_ENV=local
      - APP_DEBUG=true
      - DB_HOST=mysql
      - REDIS_HOST=redis
    depends_on:
      - mysql
      - redis

  mysql:
    image: mysql:8.3
    ports:
      - "3306:3306"
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: development
      MYSQL_USER: dev
      MYSQL_PASSWORD: dev
    volumes:
      - mysql-data:/var/lib/mysql

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

volumes:
  mysql-data:
```

For a full setup with mailhog, adminer, and other services, see [Quickstart](../getting-started/quickstart).

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f app

# Access application
open http://localhost:8000
```

## Xdebug Configuration

### VS Code Setup

Install the "PHP Debug" extension by Xdebug, then create `.vscode/launch.json`:

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
      },
      "log": false,
      "xdebugSettings": {
        "max_data": 65535,
        "show_hidden": 1,
        "max_children": 100,
        "max_depth": 5
      }
    }
  ]
}
```

**Usage:**
1. Set breakpoints in your PHP files
2. Press F5 and select "Listen for Xdebug"
3. Access your application in browser
4. Debugger stops at breakpoints

### PHPStorm Setup

1. Go to **Settings > PHP > Debug** and set Xdebug port to `9003`
2. Go to **Settings > PHP > Servers**, add a server:
   - Name: `docker`
   - Host: `localhost`, Port: `8000`
   - Debugger: `Xdebug`
   - Enable "Use path mappings" and map project root to `/var/www/html`
3. Click "Start Listening for PHP Debug Connections"
4. Set breakpoints and access your application

### CLI Debugging

Debug artisan commands or scripts:

```bash
docker-compose exec app sh -c 'export XDEBUG_MODE=debug && php artisan migrate'
docker-compose exec app sh -c 'export XDEBUG_MODE=debug && php script.php'
```

### Controlling Xdebug Performance

Xdebug adds overhead. Disable when not actively debugging:

```yaml
services:
  app:
    environment:
      - XDEBUG_MODE=${XDEBUG_MODE:-off}
```

```bash
# Enable when needed
XDEBUG_MODE=debug docker-compose up -d

# Disable (default)
XDEBUG_MODE=off docker-compose up -d
```

## PHP Development Configuration

Create `docker/php/development.ini` for custom settings:

```ini
[PHP]
display_errors = On
display_startup_errors = On
error_reporting = E_ALL
memory_limit = 256M
max_execution_time = 300
upload_max_filesize = 100M
post_max_size = 120M

; OPcache for development (revalidate on every request)
opcache.enable = 1
opcache.validate_timestamps = 1
opcache.revalidate_freq = 0

[xdebug]
xdebug.mode = debug,coverage
xdebug.start_with_request = yes
xdebug.client_host = host.docker.internal
xdebug.client_port = 9003
xdebug.log_level = 0
```

## Hot-Reload Setup

### File Watching with Bind Mounts

Already configured with bind mounts in the docker-compose above:

```yaml
volumes:
  - ./:/var/www/html  # Changes reflect immediately
```

File changes on host are immediately visible in the container. OPcache revalidation is enabled in dev mode, so PHP sees changes without restart.

### Asset Compilation (Vite)

Run Node.js as a separate service for HMR:

```yaml
services:
  node:
    image: node:20-alpine
    working_dir: /app
    volumes:
      - ./:/app
    command: npm run dev
    ports:
      - "5173:5173"  # Vite HMR
```

Configure Vite for Docker:

```js
// vite.config.js
export default defineConfig({
    server: {
        host: '0.0.0.0',
        hmr: { host: 'localhost' },
    },
});
```

## SPX Profiler

Dev images include [SPX](https://github.com/NoiseByNorthworthy/php-spx), a low-overhead profiler with a web UI.

Enable SPX:

```yaml
environment:
  - SPX_ENABLED=1
  - SPX_KEY=dev
```

Access the SPX web UI at `http://localhost:8000/?SPX_KEY=dev&SPX_UI_URI=/` to get flame graphs and detailed function-level profiling without the overhead of Xdebug's profiler.

## macOS/Windows Performance

Bind mounts on Docker Desktop can be slow with large projects. Two options:

**Option 1: VirtioFS (Recommended)**
Enable VirtioFS under Docker Desktop > Settings > Resources > File Sharing.

**Option 2: Mutagen**

```bash
brew install mutagen-io/mutagen/mutagen
docker compose up -d
mutagen sync create ./ app://cbox-app/var/www/html
```

Replace `cbox-app` with your container name from `docker compose ps`.

## Testing in Docker

```bash
# Run all tests
docker-compose exec app php artisan test

# Run with coverage (Xdebug or PCOV)
docker-compose exec app php artisan test --coverage

# Pest
docker-compose exec app ./vendor/bin/pest
docker-compose exec app ./vendor/bin/pest --coverage
```

### In-Memory Test Database

```yaml
services:
  mysql-test:
    image: mysql:8.3
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: testing
    tmpfs:
      - /var/lib/mysql  # In-memory for speed
```

Update `phpunit.xml`:

```xml
<php>
    <env name="DB_HOST" value="mysql-test"/>
    <env name="DB_DATABASE" value="testing"/>
</php>
```

## Quick Commands (Makefile)

```makefile
up:
	docker-compose up -d

down:
	docker-compose down

logs:
	docker-compose logs -f app

shell:
	docker-compose exec app sh

test:
	docker-compose exec app php artisan test

fresh:
	docker-compose exec app php artisan migrate:fresh --seed
```

## Troubleshooting

For common issues with containers not starting, permission problems, Xdebug connectivity, and slow performance, see the [Debugging Guide](../troubleshooting/debugging-guide).

## Related Documentation

- [Laravel Guide](laravel-guide) - Laravel-specific development
- [Symfony Guide](symfony-guide) - Symfony-specific development
- [Extending Images](../advanced/extending-images) - Custom development images
- [Debugging Guide](../troubleshooting/debugging-guide) - Advanced debugging

---

**Questions?** Check [common issues](../troubleshooting/common-issues) or ask in [GitHub Discussions](https://github.com/cboxdk/php-baseimages/discussions).
