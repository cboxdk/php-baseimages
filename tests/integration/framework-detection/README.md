# Framework Detection Integration Tests

Comprehensive integration tests for PHPeek's automatic framework detection system.

## Test Coverage

- ✅ Laravel detection (artisan file presence)
- ✅ Symfony detection (bin/console + var/cache presence)
- ✅ WordPress detection (wp-config.php presence)
- ✅ Generic PHP detection (no framework markers)
- ✅ Detection priority (framework-specific wins over generic)
- ✅ Cross-OS testing (Alpine, Debian, Ubuntu)

## Test Suites

### 1. Unit Tests (`test-runner.sh`)
Tests the framework detection logic directly without Docker containers.

```bash
./tests/integration/framework-detection/test-runner.sh
```

**What it tests:**
- Framework detection function logic
- File structure pattern matching
- Priority and fallback behavior
- Detection with various file combinations

### 2. Docker Integration Tests (`docker-test.sh`)
Tests framework detection within actual Docker containers across OS variants.

```bash
./tests/integration/framework-detection/docker-test.sh
```

**What it tests:**
- Laravel detection in Alpine container
- Symfony detection in Debian container
- WordPress detection in Ubuntu container
- Generic PHP detection in Alpine container
- Real entrypoint execution and behavior

## Running Tests

### Run All Tests
```bash
# Run unit tests
./tests/integration/framework-detection/test-runner.sh

# Run Docker integration tests
./tests/integration/framework-detection/docker-test.sh
```

### CI/CD Integration
Tests are designed to run in CI/CD pipelines:

```yaml
# GitHub Actions example
- name: Run Framework Detection Tests
  run: |
    ./tests/integration/framework-detection/test-runner.sh
    ./tests/integration/framework-detection/docker-test.sh
```

## Test Output

### Successful Test Run
```
==========================================
Framework Detection Integration Tests
==========================================

ℹ Testing Laravel framework detection...
✓ Laravel detection with artisan file
ℹ Testing Symfony framework detection...
✓ Symfony detection with bin/console and var/cache
ℹ Testing WordPress framework detection...
✓ WordPress detection with wp-config.php
ℹ Testing generic PHP detection...
✓ Generic PHP detection with no framework markers
ℹ Testing detection priority (Laravel with generic files)...
✓ Laravel takes priority over generic files

==========================================
Test Results
==========================================
Passed: 5
Failed: 0
Total: 5
All tests passed!
```

### Failed Test Example
```
✗ Laravel detection with artisan file
  Expected: laravel
  Got: generic
```

## Test Structure

```
tests/integration/framework-detection/
├── README.md                 # This file
├── test-runner.sh           # Unit tests (direct function testing)
├── docker-test.sh           # Docker integration tests
└── fixtures/                # Temporary test fixtures (created/cleaned automatically)
    ├── laravel/
    ├── symfony/
    ├── wordpress/
    └── generic/
```

## Adding New Tests

### Add Unit Test
Edit `test-runner.sh` and add a new test function:

```bash
test_new_framework() {
    info "Testing new framework detection..."

    # Create test structure
    TEMP_DIR=$(mktemp -d)
    mkdir -p "$TEMP_DIR/var/www/html"
    touch "$TEMP_DIR/var/www/html/framework-marker.php"

    # Run detection
    cd "$TEMP_DIR/var/www/html"
    RESULT=$("$TEST_DIR/../../../php-fpm-nginx/common/docker-entrypoint.sh" detect_framework 2>/dev/null || echo "error")

    # Cleanup
    rm -rf "$TEMP_DIR"

    if [ "$RESULT" = "newframework" ]; then
        pass "New framework detected"
    else
        fail "New framework detection" "newframework" "$RESULT"
    fi
}
```

Then call it from `main()`:
```bash
main() {
    # ... existing tests ...
    test_new_framework
    # ...
}
```

### Add Docker Integration Test
Edit `docker-test.sh` and add a new container test:

```bash
test_newframework_container() {
    info "Testing new framework detection in Alpine container..."

    # Create test structure
    mkdir -p tests/integration/framework-detection/fixtures/newframework
    touch tests/integration/framework-detection/fixtures/newframework/framework-marker.php

    # Run container
    docker run --rm \
        -v "$(pwd)/tests/integration/framework-detection/fixtures/newframework:/var/www/html" \
        --entrypoint /bin/sh \
        ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine \
        -c "source /usr/local/bin/docker-entrypoint.sh && detect_framework" > /tmp/newframework-test.log 2>&1

    RESULT=$(cat /tmp/newframework-test.log | grep -o "newframework" || echo "error")

    # Cleanup
    rm -rf tests/integration/framework-detection/fixtures/newframework
    rm -f /tmp/newframework-test.log

    if [ "$RESULT" = "newframework" ]; then
        pass "New framework detected in Alpine container"
    else
        fail "New framework detection in Alpine container" "Got: $RESULT"
    fi
}
```

## Troubleshooting

### Docker Tests Failing
If Docker tests fail:

1. **Check Docker is running:**
   ```bash
   docker ps
   ```

2. **Check images are available:**
   ```bash
   docker images | grep phpeek
   ```

3. **Pull latest images:**
   ```bash
   docker pull ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine
   docker pull ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-debian
   docker pull ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-ubuntu
   ```

### Unit Tests Failing
If unit tests fail:

1. **Check entrypoint exists:**
   ```bash
   ls -la php-fpm-nginx/common/docker-entrypoint.sh
   ```

2. **Check script is executable:**
   ```bash
   chmod +x php-fpm-nginx/common/docker-entrypoint.sh
   ```

3. **Run detection manually:**
   ```bash
   source php-fpm-nginx/common/docker-entrypoint.sh
   cd /path/to/test/directory
   detect_framework
   ```

## Future Enhancements

Potential test additions:

- [ ] Test framework detection with edge cases (symlinks, readonly filesystems)
- [ ] Test detection performance (timing benchmarks)
- [ ] Test detection with mixed framework markers (conflicting signals)
- [ ] Test detection in separate containers (php-fpm vs php-fpm-nginx)
- [ ] Test detection with custom framework patterns
- [ ] Test detection error handling (missing permissions, corrupted files)
- [ ] Add property-based testing for comprehensive coverage
- [ ] Add mutation testing to validate test effectiveness

## Related Documentation

- [docker-entrypoint.sh](../../../php-fpm-nginx/common/docker-entrypoint.sh) - Main entrypoint with detection logic
- [Laravel Guide](../../../docs/guides/laravel-guide.md) - Laravel-specific documentation
- [Symfony Guide](../../../docs/guides/symfony-guide.md) - Symfony-specific documentation
- [WordPress Guide](../../../docs/guides/wordpress-guide.md) - WordPress-specific documentation
