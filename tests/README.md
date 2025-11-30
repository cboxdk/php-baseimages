# PHPeek Base Images - Test Suite

Comprehensive test coverage for PHPeek Docker images.

## Test Summary

| Category | Tests | Description |
|----------|-------|-------------|
| **Quick Tests** | 3 | Basic PHP, health checks, environment config |
| **Framework Tests** | 2 | Laravel, WordPress integration |
| **Comprehensive Tests** | 6 | Image formats, database, security, Browsershot, Pest, Dusk |

**Total: 11 test scenarios with 138+ individual test cases**

## Running Tests

### Run All Tests

```bash
./tests/e2e/run-all-tests.sh
```

### Run Specific Categories

```bash
# Quick tests only (fast)
./tests/e2e/run-all-tests.sh --quick

# Framework integration tests
./tests/e2e/run-all-tests.sh --frameworks

# Comprehensive tests (image formats, database, security)
./tests/e2e/run-all-tests.sh --comprehensive

# Specific test
./tests/e2e/run-all-tests.sh --specific database
./tests/e2e/run-all-tests.sh --specific security
```

## Test Categories

### Quick Tests (~1 min)

| Test | Description | Assertions |
|------|-------------|------------|
| `test-plain-php.sh` | PHP info, extensions, configuration | ~10 |
| `test-health-checks.sh` | Container health endpoints | ~8 |
| `test-env-config.sh` | Environment variable handling | ~15 |

### Framework Integration Tests (~2 min)

| Test | Description | Assertions |
|------|-------------|------------|
| `test-laravel.sh` | Laravel app startup, routing, artisan | ~12 |
| `test-wordpress.sh` | WordPress with MySQL, WP-CLI | ~10 |

### Comprehensive Tests (~10 min)

| Test | Description | Assertions |
|------|-------------|------------|
| `test-image-formats.sh` | GD, ImageMagick: JPEG, PNG, GIF, WebP, AVIF, PDF | 27 |
| `test-database.sh` | MySQL, PostgreSQL, SQLite connections | 15 |
| `test-security.sh` | Headers, file blocking, PHP security | 20 |
| `test-browsershot.sh` | Node.js, Chromium, Puppeteer, PDF generation | 20 |
| `test-pest.sh` | Pest PHP testing framework integration | 38 |
| `test-dusk-capabilities.sh` | Laravel Dusk browser testing capabilities | 18 |

## Test Coverage Details

### Image Format Tests

Tests GD and ImageMagick support for:
- JPEG (create, read, resize, quality settings)
- PNG (transparency, compression)
- GIF (animation support)
- WebP (lossy/lossless)
- AVIF (modern format)
- PDF (ImageMagick conversion)

### Database Tests

- MySQL 8.0 connection and queries
- PostgreSQL 16 connection and queries
- SQLite file-based and in-memory
- PDO driver availability
- Connection pooling behavior

### Security Tests

- Security headers (X-Frame-Options, X-Content-Type-Options, etc.)
- Sensitive file blocking (.env, .git, composer.json)
- PHP configuration (expose_php, display_errors)
- Upload directory restrictions
- Hidden file access prevention

### Browsershot Tests

- Node.js version detection
- npm package availability
- Chromium/Puppeteer installation
- PDF generation from HTML
- Screenshot capabilities
- Memory and process limits

### Pest Tests

- Pest v4 installation and configuration
- describe() block support
- Dataset functionality
- Architecture testing
- Custom expectations
- Test coverage with Xdebug

### Dusk Capability Tests

- ChromeDriver compatibility
- WebDriver protocol support
- Required PHP extensions
- Headless browser execution
- Screenshot capabilities
- Browser automation libraries

## CI/CD Integration

### GitHub Actions

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build images
        run: docker compose build

      - name: Run quick tests
        run: ./tests/e2e/run-all-tests.sh --quick

      - name: Run comprehensive tests
        run: ./tests/e2e/run-all-tests.sh --comprehensive
```

### Local Development

```bash
# Build test image
docker build -f php-fpm-nginx/8.3/alpine/Dockerfile -t phpeek-test:local .

# Run with custom image
IMAGE=phpeek-test:local ./tests/e2e/scenarios/test-database.sh
```

## Writing New Tests

### Test Script Template

```bash
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-helpers.sh"

# Test configuration
TEST_NAME="my-feature"
FIXTURE_DIR="$SCRIPT_DIR/../fixtures/$TEST_NAME"

setup_test() {
    log_info "Setting up $TEST_NAME test..."
    cd "$FIXTURE_DIR"
    docker compose up -d --build
    wait_for_healthy "container-name" 60
}

cleanup_test() {
    cd "$FIXTURE_DIR"
    docker compose down -v --remove-orphans
}

# Register cleanup
trap cleanup_test EXIT

# Run tests
setup_test

run_test "Feature works correctly" \
    docker compose exec app php -r "echo 'works';"

run_test "Another test case" \
    curl -sf http://localhost:8080/

print_summary
```

### Adding Test Fixtures

1. Create fixture directory: `tests/e2e/fixtures/my-feature/`
2. Add `docker-compose.yml` for the test environment
3. Add any required files (PHP scripts, configs)
4. Create test script in `tests/e2e/scenarios/test-my-feature.sh`

## Troubleshooting

### Tests Failing Locally

```bash
# Check Docker is running
docker info

# Check available resources
docker system df

# Clean up old containers
docker compose down -v --remove-orphans
docker system prune -f
```

### Debugging Individual Tests

```bash
# Run with verbose output
bash -x ./tests/e2e/scenarios/test-database.sh

# Keep containers running after test
KEEP_RUNNING=1 ./tests/e2e/scenarios/test-database.sh

# Check container logs
docker compose logs -f
```

### Common Issues

| Issue | Solution |
|-------|----------|
| Port conflicts | Stop other containers using same ports |
| Docker timeout | Increase `wait_for_healthy` timeout |
| Permission denied | Run `chmod +x` on test scripts |
| Container not starting | Check `docker compose logs` |
