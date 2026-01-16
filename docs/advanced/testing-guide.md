---
title: "Testing Guide"
description: "Comprehensive guide to testing Cbox Base Images with E2E and unit tests"
weight: 50
---

# Testing Guide

This guide covers how to test Cbox Base Images locally during development.

## Test Infrastructure Overview

Cbox uses a layered testing approach:

| Test Type | Location | Purpose |
|-----------|----------|---------|
| Unit Tests | `tests/unit/` | Extension verification, configuration |
| E2E Tests | `tests/e2e/` | Framework integration, full scenarios |
| Matrix Tests | `tests/unit/run-matrix-tests.sh` | Cross-variant testing |

---

## Quick Start

### Run All Unit Tests

```bash
cd tests/unit
./run-matrix-tests.sh --build
```

### Run E2E Tests

```bash
cd tests/e2e
./run-e2e-tests.sh ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm
```

### Run Specific Scenario

```bash
./run-e2e-tests.sh ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm laravel
```

---

## E2E Test Scenarios

Available test scenarios in `tests/e2e/scenarios/`:

| Scenario | Tests |
|----------|-------|
| `plain-php` | Basic PHP functionality, extensions |
| `laravel` | Laravel detection, scheduler, permissions |
| `symfony` | Symfony detection, console, cache |
| `wordpress` | WordPress detection, wp-config handling |
| `health-checks` | Health check endpoints |
| `database` | MySQL, PostgreSQL, Redis connectivity |
| `security` | Security headers, file permissions |
| `image-formats` | GD, ImageMagick, libvips support |
| `cbox-init` | Process manager integration |
| `pest` | Pest/PHPUnit test execution |
| `browsershot` | Puppeteer/Browsershot capabilities |
| `dusk-capabilities` | Laravel Dusk browser testing |

### Running Individual Scenarios

```bash
# Laravel E2E test
./tests/e2e/scenarios/test-laravel.sh

# Symfony E2E test
./tests/e2e/scenarios/test-symfony.sh

# Cbox PM integration
./tests/e2e/scenarios/test-cbox-init.sh
```

---

## Test Fixtures

Test fixtures are located in `tests/e2e/fixtures/`:

```
fixtures/
├── laravel/          # Minimal Laravel app
│   ├── app/
│   │   ├── artisan
│   │   └── public/index.php
│   └── docker-compose.yml
├── symfony/          # Minimal Symfony app
│   ├── app/
│   │   ├── bin/console
│   │   ├── public/index.php
│   │   └── var/
│   └── docker-compose.yml
├── wordpress/        # Minimal WordPress setup
├── database/         # Database connectivity tests
├── security/         # Security validation tests
└── cbox-init/        # Process manager tests
```

Each fixture contains a `docker-compose.yml` that uses the `IMAGE` environment variable:

```yaml
services:
  app:
    image: ${IMAGE:-ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm}
    # ...
```

---

## Matrix Testing

Test across all PHP versions and OS variants:

```bash
# Test all variants
./tests/unit/run-matrix-tests.sh --build

# Test only php-fpm images
./tests/unit/run-matrix-tests.sh --fpm --build

# Test only php-fpm-nginx images
./tests/unit/run-matrix-tests.sh --fpm-nginx --build

# Quick mode (skip slow tests)
./tests/unit/run-matrix-tests.sh --quick
```

### Matrix Configuration

The matrix tests cover:

- **PHP Versions**: 8.2, 8.3, 8.4, 8.5
- **Tiers**: Slim, Standard, Full
- **Image Types**: php-fpm, php-fpm-nginx

---

## Test Utilities

Shared test utilities are in `tests/e2e/lib/test-utils.sh`:

```bash
# Source test utilities
source "$SCRIPT_DIR/../lib/test-utils.sh"

# Available functions:
log_section "Test Section Name"
log_info "Information message"
log_success "Test passed"
log_fail "Test failed"
log_warn "Warning message"

# Assertions
assert_http_code "$URL" 200 "Health endpoint"
assert_http_contains "$URL" "expected text" "Response content"
assert_file_exists "$CONTAINER" "/path/to/file" "File description"
assert_dir_exists "$CONTAINER" "/path/to/dir" "Directory description"
assert_exec_succeeds "$CONTAINER" "command" "Command description"

# Docker Compose helpers
wait_for_healthy "$CONTAINER_NAME" 60  # Wait up to 60 seconds
cleanup_compose "$COMPOSE_FILE" "$PROJECT_NAME"
get_e2e_root  # Returns E2E test root directory

# Summary
print_summary  # Print test summary with pass/fail counts
```

---

## Writing New Tests

### 1. Create Test Scenario

Create a new file in `tests/e2e/scenarios/test-{name}.sh`:

```bash
#!/bin/bash
# E2E Test: Description of your test
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-utils.sh"

E2E_ROOT="$(get_e2e_root)"
FIXTURE_DIR="$E2E_ROOT/fixtures/{name}"
PROJECT_NAME="e2e-{name}"
CONTAINER_NAME="e2e-{name}-app"
BASE_URL="http://localhost:{port}"

# Cleanup on exit
trap 'cleanup_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME" 2>/dev/null || true' EXIT

log_section "Your Test Name"

# Clean up and start
cleanup_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME" 2>/dev/null || true
docker compose -f "$FIXTURE_DIR/docker-compose.yml" -p "$PROJECT_NAME" up -d

wait_for_healthy "$CONTAINER_NAME" 60

# Your tests here
log_section "Test 1: Description"
assert_http_code "$BASE_URL/health" 200 "Health check"

print_summary
```

### 2. Create Fixture Directory

Create `tests/e2e/fixtures/{name}/`:

```bash
mkdir -p tests/e2e/fixtures/{name}/app
```

### 3. Create docker-compose.yml

```yaml
services:
  app:
    image: ${IMAGE:-ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm}
    container_name: e2e-{name}-app
    ports:
      - "{port}:80"
    volumes:
      - ./app:/var/www/html
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 5s
      timeout: 3s
      retries: 5
      start_period: 30s
```

### 4. Make Executable

```bash
chmod +x tests/e2e/scenarios/test-{name}.sh
```

---

## Local Development Testing

### Build and Test Local Image

```bash
# Build local image
docker build -f php-fpm-nginx/8.3/debian/bookworm/Dockerfile -t my-test-image:local .

# Run E2E tests against local image
IMAGE=my-test-image:local ./tests/e2e/run-e2e-tests.sh
```

### Interactive Debugging

```bash
# Start fixture container
cd tests/e2e/fixtures/laravel
IMAGE=my-test-image:local docker compose up -d

# Shell into container
docker compose exec app sh

# Check logs
docker compose logs -f

# Manual health check
docker compose exec app /usr/local/bin/healthcheck.sh

# Cleanup
docker compose down -v
```

---

## CI/CD Integration

Tests run automatically in GitHub Actions:

```yaml
# .github/workflows/test.yml
jobs:
  test:
    runs-on: linux-latest  # Use your CI provider's Linux runner
    steps:
      - uses: actions/checkout@v4

      - name: Build images
        run: docker compose build

      - name: Run unit tests
        run: ./tests/unit/run-matrix-tests.sh

      - name: Run E2E tests
        run: ./tests/e2e/run-e2e-tests.sh
```

---

## Troubleshooting Tests

### Container Won't Start

```bash
# Check container logs
docker logs e2e-laravel-app

# Check if port is in use
lsof -i :8091
```

### Test Timeouts

```bash
# Increase wait time
wait_for_healthy "$CONTAINER_NAME" 120  # 2 minutes
```

### Cleanup Stuck Containers

```bash
# Force cleanup all E2E containers
docker ps -a | grep 'e2e-' | awk '{print $1}' | xargs docker rm -f
docker network ls | grep 'e2e-' | awk '{print $1}' | xargs docker network rm
```

### Debug Specific Test

```bash
# Run with verbose output
VERBOSE=true ./tests/e2e/run-e2e-tests.sh my-image laravel

# Or run test directly
bash -x ./tests/e2e/scenarios/test-laravel.sh
```

---

## Next Steps

| Topic | Guide |
|-------|-------|
| Image customization | [Extending Images](extending-images.md) |
| Performance testing | [Performance Tuning](performance-tuning.md) |
| Security testing | [Security Hardening](security-hardening.md) |
| CI/CD setup | [Production Deployment](../guides/production-deployment.md) |
