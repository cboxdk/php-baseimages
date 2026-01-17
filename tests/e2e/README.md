# Cbox E2E Test Suite

End-to-end tests for Cbox base images ensuring stability across all code types.

## Quick Start

```bash
# Run all tests with default image (8.3-bookworm)
./run-e2e-tests.sh

# Test specific image
./run-e2e-tests.sh ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm

# Test specific scenario
./run-e2e-tests.sh local-image:latest laravel

# Test all variants
./run-all-variants.sh
```

## Test Scenarios

| Scenario | Tests |
|----------|-------|
| `plain-php` | Basic PHP, extensions, health checks, filesystem |
| `laravel` | MySQL, Redis, scheduler, artisan, API endpoints |
| `wordpress` | MySQL, wp-config detection, URL rewriting |
| `health-checks` | Internal health scripts, process monitoring, OPcache |

## Directory Structure

```
tests/e2e/
├── run-e2e-tests.sh       # Main test runner
├── run-all-variants.sh    # Multi-variant runner
├── lib/
│   └── test-utils.sh      # Shared utilities
├── fixtures/
│   ├── plain-php/         # Plain PHP test app
│   ├── laravel/           # Laravel-like test app
│   └── wordpress/         # WordPress-like test app
└── scenarios/
    ├── test-plain-php.sh
    ├── test-laravel.sh
    ├── test-wordpress.sh
    └── test-health-checks.sh
```

## Running Locally

### Prerequisites
- Docker 20.10+
- Docker Compose v2
- bash, curl, jq

### Test a local build

```bash
# Build image
docker build -f php-fpm-nginx/8.3/debian/bookworm/Dockerfile -t test-image:local .

# Run tests
./tests/e2e/run-e2e-tests.sh test-image:local all
```

### Test specific scenarios

```bash
# Quick smoke test
./tests/e2e/run-e2e-tests.sh test-image:local plain-php

# Full Laravel stack test
./tests/e2e/run-e2e-tests.sh test-image:local laravel

# Health check validation
./tests/e2e/run-e2e-tests.sh test-image:local health-checks
```

### Test all variants

```bash
# Test default versions
PHP_VERSIONS="8.3" ./tests/e2e/run-all-variants.sh

# Test all PHP versions
PHP_VERSIONS="8.2 8.3 8.4" ./tests/e2e/run-all-variants.sh all
```

## CI Integration

The `.github/workflows/e2e-tests.yml` runs:

1. **Smoke test** (every push): Plain PHP + health checks
2. **Comprehensive** (main branch): Full suite on 8.3-bookworm, 8.4-bookworm
3. **Manual trigger**: Any combination of version/scenario

## Adding New Tests

### New assertion in existing scenario

```bash
# In scenarios/test-*.sh
assert_http_contains "$BASE_URL/endpoint" "expected" "Description"
assert_exec_succeeds "$CONTAINER" "command" "Description"
```

### New test scenario

1. Create fixture in `fixtures/your-scenario/`
2. Create scenario in `scenarios/test-your-scenario.sh`
3. Source `lib/test-utils.sh`
4. Use provided assertion functions

### Available assertions

```bash
assert_http_code URL CODE "description"
assert_http_contains URL "expected" "description"
assert_exec_succeeds CONTAINER "command" "description"
assert_exec_contains CONTAINER "command" "expected" "description"
assert_process_running CONTAINER "process" "description"
assert_file_exists CONTAINER "path" "description"
assert_dir_exists CONTAINER "path" "description"
```

## Troubleshooting

### Tests fail locally but pass in CI

Check Docker resource limits:
```bash
docker system info | grep -E "CPUs|Memory"
```

### Container won't start

Check logs:
```bash
docker logs e2e-<scenario>-app
```

### MySQL/Redis not connecting

Wait times may need adjustment. Check `wait_for_healthy` timeout in scenario.
