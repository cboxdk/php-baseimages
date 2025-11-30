---
title: "Static Assets Setup"
description: "Production setup with pre-compiled frontend assets and no Node.js runtime"
weight: 10
---

# Static Assets Setup

Minimal production setup: PHP serves pre-compiled frontend assets. No Node.js in production.

## Architecture

```
Development:
┌─────────────┐     ┌─────────────┐
│   Node.js   │────▶│ Build Step  │
└─────────────┘     └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │ public/build │
                    └──────┬──────┘
                           │
Production:               ▼
┌─────────────────────────────────┐
│         PHP + Nginx             │
│   (serves static + dynamic)     │
└─────────────────────────────────┘
```

## Build Process

### During Development

```bash
# Start with live reload
npm run dev

# Or use Docker
docker compose --profile build run --rm builder npm run dev
```

### For Production

```bash
# Build assets locally
npm run build

# Or use Docker builder
docker compose --profile build run --rm builder

# Then deploy
docker compose up -d app
```

## CI/CD Pipeline

```yaml
# GitHub Actions example
jobs:
  build:
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Build assets
        run: |
          npm ci
          npm run build

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: assets
          path: public/build/

  deploy:
    needs: build
    steps:
      - name: Download assets
        uses: actions/download-artifact@v4
        with:
          name: assets
          path: public/build/

      - name: Deploy
        run: docker compose up -d app
```

## Vite Configuration

```javascript
// vite.config.js
import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';

export default defineConfig({
    plugins: [
        laravel({
            input: ['resources/css/app.css', 'resources/js/app.js'],
            refresh: true,
        }),
    ],
    build: {
        manifest: true,
        outDir: 'public/build',
        rollupOptions: {
            output: {
                manualChunks: {
                    vendor: ['vue', 'axios'],
                },
            },
        },
    },
});
```

## Asset Versioning

Laravel's Vite plugin handles versioning automatically:

```php
// In Blade templates
@vite(['resources/css/app.css', 'resources/js/app.js'])

// Outputs (with hash for cache busting):
<link rel="stylesheet" href="/build/assets/app-BjsH2g4K.css">
<script src="/build/assets/app-C3nD8j2L.js"></script>
```

## Benefits

| Aspect | This Setup | Node in Production |
|--------|------------|-------------------|
| Container size | ~50MB | ~200MB+ |
| Attack surface | Minimal | Node + npm |
| Memory usage | Low | Higher |
| Startup time | Fast | Slower |
| Complexity | Simple | More moving parts |

## Common Commands

```bash
# Build assets
docker compose --profile build run --rm builder

# Build with watch (development)
docker compose --profile build run --rm builder npm run dev

# Check built files
ls -la public/build/

# Start production
docker compose up -d app
```

## SQLite for Simple Apps

This example uses SQLite for simplicity:

```bash
# Create database
touch database/database.sqlite

# Run migrations
docker compose exec app php artisan migrate
```

For larger apps, add MySQL/PostgreSQL service.
