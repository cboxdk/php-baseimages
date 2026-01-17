# Cbox Dockerfile Templates

Ready-to-use Dockerfile templates for common development scenarios.

## Available Templates

### 1. Dockerfile.production - Multi-Stage Production Build
**Use case:** Production deployments with optimized images and minimal footprint

```bash
# Build production image
docker build --target production -t myapp:prod -f templates/Dockerfile.production .

# Build with specific PHP version
docker build --build-arg PHP_VERSION=8.3 --target production -t myapp:prod -f templates/Dockerfile.production .

# Multi-platform build (AMD64 + ARM64)
docker buildx build --platform linux/amd64,linux/arm64 \
  --target production -t myapp:prod -f templates/Dockerfile.production --push .
```

**Includes:**
- Multi-stage build (frontend + backend separation)
- Composer dependencies without dev packages
- Pre-built frontend assets (Vite/Webpack)
- Laravel/Symfony cache warming
- Optimized for both AMD64 and ARM64
- Development target for local testing

**Stages:**
1. `frontend-builder` - Builds Node.js/Vite assets
2. `composer-builder` - Installs PHP dependencies
3. `production` - Minimal production runtime
4. `development` - Optional dev environment with Xdebug

**Perfect for:**
- Kubernetes deployments
- CI/CD pipelines
- Production hosting

---

### 2. Dockerfile.node - PHP + Node.js
**Use case:** Full-stack applications needing both PHP and Node.js (Laravel + Vite, Inertia.js, etc.)

```bash
# Build your image
docker build -f templates/Dockerfile.node -t myapp:node .

# Run with Vite dev server
docker run -p 8000:80 -p 5173:5173 -v $(pwd):/var/www/html myapp:node
```

**Includes:**
- ✅ Node.js & npm
- ✅ Ready for Vite HMR (port 5173)
- ✅ Optional Yarn/pnpm installation

**Perfect for:**
- Laravel + Vite
- Symfony + Webpack Encore
- WordPress + modern build tools

### 3. Dockerfile.dev - Development Environment
**Use case:** Development with Xdebug, SPX profiler, and debugging tools

```bash
# Build development image
docker build -f templates/Dockerfile.dev -t myapp:dev .

# Run with Xdebug enabled
docker run -p 8000:80 -p 9003:9003 \
  -e XDEBUG_MODE=debug \
  -v $(pwd):/var/www/html \
  myapp:dev
```

**Includes:**
- ✅ Xdebug 3.4 (step debugging, coverage, profiling)
- ✅ SPX Profiler (performance profiling)
- ✅ Node.js & npm
- ✅ Development tools (git, vim, nano)
- ✅ Development PHP settings (display_errors, etc.)

**Access SPX Profiler:**
```
http://localhost:8000/?SPX_KEY=dev&SPX_UI_URI=/
```

**Perfect for:**
- Local development
- Debugging with VS Code / PhpStorm
- Performance profiling
- Frontend + backend development

### 4. Dockerfile.ci - CI/CD Optimized
**Use case:** Continuous Integration pipelines (GitHub Actions, GitLab CI, etc.)

```bash
# Build CI image
docker build -f templates/Dockerfile.ci -t myapp:ci .

# Run tests
docker run --rm -v $(pwd):/var/www/html myapp:ci php artisan test
```

**Includes:**
- ✅ Git, zip, unzip
- ✅ Node.js for frontend testing
- ✅ Pre-warmed Composer cache (PHPUnit, PHPStan, PHP CS Fixer)
- ✅ CI-optimized PHP settings
- ✅ No health checks (faster startup)

**Perfect for:**
- GitHub Actions
- GitLab CI
- Bitbucket Pipelines
- Any CI/CD platform

## Development Docker Compose

Use `docker-compose.dev.yml` for complete local development environment:

```bash
docker-compose -f templates/docker-compose.dev.yml up -d
```

**Includes:**
- ✅ PHP + Nginx (with Xdebug, SPX, Node.js)
- ✅ MySQL 8.3
- ✅ Redis 7
- ✅ Mailpit (email testing)
- ✅ Volume caching for Composer and npm
- ✅ All ports exposed for debugging

**Access:**
- App: http://localhost:8000
- Mailpit UI: http://localhost:8025
- Vite HMR: http://localhost:5173

**Common commands:**
```bash
# Install dependencies
docker-compose -f templates/docker-compose.dev.yml exec app composer install
docker-compose -f templates/docker-compose.dev.yml exec app npm install

# Run migrations
docker-compose -f templates/docker-compose.dev.yml exec app php artisan migrate

# Start Vite dev server
docker-compose -f templates/docker-compose.dev.yml exec app npm run dev

# Access bash
docker-compose -f templates/docker-compose.dev.yml exec app bash
```

## CI/CD Examples

### GitHub Actions
See `examples/ci/github-actions-laravel.yml` for complete Laravel CI/CD pipeline.

**Features:**
- Multi-version PHP testing (8.2, 8.3, 8.4)
- ✅ MySQL and Redis services
- ✅ Dependency caching
- ✅ Frontend build (Vite)
- ✅ PHPStan, PHP CS Fixer
- ✅ PHPUnit with coverage
- ✅ Automatic deployment

**Usage:**
```bash
cp examples/ci/github-actions-laravel.yml .github/workflows/ci.yml
```

### GitLab CI
See `examples/ci/gitlab-ci-symfony.yml` for complete Symfony CI/CD pipeline.

**Features:**
- ✅ Build, test, deploy stages
- ✅ Docker image building
- ✅ PHPStan, PHP CS Fixer, PHPUnit
- ✅ Security auditing
- ✅ Staging and production deployment

**Usage:**
```bash
cp examples/ci/gitlab-ci-symfony.yml .gitlab-ci.yml
```

### Bitbucket Pipelines
See `examples/ci/bitbucket-pipelines.yml` for Laravel pipeline.

**Features:**
- ✅ Parallel testing
- ✅ Branch-specific workflows
- ✅ Docker build and push
- ✅ Automated deployment

**Usage:**
```bash
cp examples/ci/bitbucket-pipelines.yml bitbucket-pipelines.yml
```

## Customization Guide

### Adding Additional Tools

**Example: Add pdepend to dev image:**
```dockerfile
FROM templates/Dockerfile.dev

RUN composer global require pdepend/pdepend
```

**Example: Add specific Node.js version:**
```dockerfile
FROM ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm

# Install specific Node.js version
RUN apt-get update && apt-get install -y nodejs npm && rm -rf /var/lib/apt/lists/*
```

### Environment-Specific Configuration

**Development:**
```dockerfile
FROM templates/Dockerfile.dev AS development
# All dev tools included
```

**Staging:**
```dockerfile
FROM ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm AS staging
# Production base + additional logging
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*  # For health checks
```

**Production:**
```dockerfile
FROM ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm AS production
# Minimal, optimized for performance
COPY --chown=www-data:www-data . /var/www/html
```

## Multi-Stage Build Example

Build assets with Node.js, run with PHP only:

```dockerfile
# Stage 1: Build frontend assets
FROM node:20-alpine AS frontend-builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 2: Production PHP runtime
FROM ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm
WORKDIR /var/www/html

# Copy built assets from frontend builder
COPY --from=frontend-builder /app/public/build ./public/build

# Copy application code
COPY --chown=www-data:www-data . .

# Install production dependencies
RUN composer install --no-dev --optimize-autoloader && \
    php artisan config:cache && \
    php artisan route:cache && \
    php artisan view:cache
```

## SPX Profiler Usage

SPX is included in `Dockerfile.dev` for performance profiling.

### Enable SPX

Add to URL:
```
http://localhost:8000/?SPX_KEY=dev&SPX_UI_URI=/
```

### Profile Specific Endpoint

```
http://localhost:8000/api/users?SPX_KEY=dev&SPX_UI_URI=/
```

### View Results

Access the SPX UI:
```
http://localhost:8000/?SPX_KEY=dev&SPX_UI_URI=/
```

**Features:**
- Flat profile view
- Flamegraph visualization
- Timeline view
- Memory profiling
- Function call analysis

## Xdebug Configuration

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

1. **Settings → PHP → Debug**
   - Xdebug port: 9003
   - ✅ Can accept external connections

2. **Settings → PHP → Servers**
   - Name: localhost
   - Host: localhost
   - Port: 8000
   - Path mapping: `/var/www/html` → project root

3. **Click "Start Listening for PHP Debug Connections"**

### Command Line Debugging

```bash
# Run single command with Xdebug
docker-compose exec -e XDEBUG_SESSION=1 app php artisan migrate
```

## Best Practices

### Development
- ✅ Use `Dockerfile.dev` for local development
- ✅ Mount code as volume for hot-reload
- ✅ Use `docker-compose.dev.yml` for full stack
- ✅ Enable Xdebug only when debugging (performance impact)

### CI/CD
- ✅ Use `Dockerfile.ci` for test pipelines
- ✅ Cache Composer and npm dependencies
- ✅ Run tests in parallel
- ✅ Build production image after tests pass

### Production
- ✅ Use base Cbox images (no dev tools)
- ✅ Multi-stage builds for frontend assets
- ✅ Pre-cache Laravel configurations
- ✅ Run as non-root with security hardening

## Troubleshooting

### Xdebug Not Connecting

```bash
# Check Xdebug is loaded
docker-compose exec app php -m | grep xdebug

# Check Xdebug configuration
docker-compose exec app php -i | grep xdebug

# Test connection
docker-compose exec app php -dxdebug.mode=debug -dxdebug.start_with_request=yes artisan tinker
```

### SPX Not Loading

```bash
# Verify SPX extension
docker-compose exec app php -m | grep spx

# Check SPX configuration
docker-compose exec app php -i | grep spx
```

### Node.js Not Found

```bash
# Verify Node.js installation
docker-compose exec app node --version
docker-compose exec app npm --version

# If missing, rebuild image
docker-compose build --no-cache app
```

## Need Help?

- 📖 [Full Documentation](../docs/)
- 💬 [GitHub Discussions](https://github.com/cboxdk/baseimages/discussions)
- 🐛 [Report Issues](https://github.com/cboxdk/baseimages/issues)
