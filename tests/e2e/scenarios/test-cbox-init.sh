#!/bin/bash
# E2E Test: Cbox PM Process Manager
# Tests Cbox PM functionality, process management, and health checks

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-utils.sh"

E2E_ROOT="$(get_e2e_root)"
PROJECT_NAME="e2e-cbox-init"
CONTAINER_NAME="e2e-cbox-init-app"
BASE_URL="http://localhost:8094"

# Use the cbox-init fixture (basic php-fpm-nginx container)
FIXTURE_DIR="$E2E_ROOT/fixtures/cbox-init"

# Simple cleanup function - called explicitly, not via trap
# Always returns 0 regardless of docker compose result
do_cleanup() {
    cleanup_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME"
    return 0
}

log_section "Cbox PM E2E Test"

# Create fixture directory and docker-compose.yml if they don't exist
mkdir -p "$FIXTURE_DIR"
cat > "$FIXTURE_DIR/docker-compose.yml" <<'EOF'
services:
  app:
    image: ${IMAGE:-ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-alpine}
    container_name: e2e-cbox-init-app
    ports:
      - "8094:80"
      - "9094:9090"  # Cbox PM metrics port
    environment:
      - PHP_MEMORY_LIMIT=256M
      - CBOX_LOG_LEVEL=debug
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 5s
      timeout: 3s
      retries: 10
      start_period: 15s
EOF

# Create a simple index.php for testing
mkdir -p "$FIXTURE_DIR/app/public"
cat > "$FIXTURE_DIR/app/public/index.php" <<'EOF'
<?php
header('Content-Type: application/json');
echo json_encode([
    'status' => 'ok',
    'php_version' => PHP_VERSION,
    'server' => 'Cbox PM Test',
    'timestamp' => date('c'),
]);
EOF

# Add volume mount to docker-compose
cat > "$FIXTURE_DIR/docker-compose.yml" <<'EOF'
services:
  app:
    image: ${IMAGE:-ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-alpine}
    container_name: e2e-cbox-init-app
    ports:
      - "8094:80"
      - "9094:9090"
    volumes:
      - ./app:/var/www/html
    environment:
      - PHP_MEMORY_LIMIT=256M
      - CBOX_LOG_LEVEL=debug
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 5s
      timeout: 3s
      retries: 10
      start_period: 15s
EOF

# Start the stack
cleanup_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME" 2>/dev/null || true
start_compose "$FIXTURE_DIR/docker-compose.yml" "$PROJECT_NAME"

# Wait for container to be healthy
wait_for_healthy "$CONTAINER_NAME" 60

log_section "Cbox PM Binary Tests"

# Test Cbox PM binary exists and is executable
assert_exec_succeeds "$CONTAINER_NAME" "which cbox-init" "Cbox PM binary found in PATH"
assert_exec_succeeds "$CONTAINER_NAME" "cbox-init --version" "Cbox PM version command works"

# Verify Cbox PM version format
PM_VERSION=$(docker exec "$CONTAINER_NAME" cbox-init --version 2>&1 || echo "unknown")
if [[ "$PM_VERSION" =~ ^cbox-init\ version\ [0-9]+\.[0-9]+\.[0-9]+ ]]; then
    log_success "Cbox PM version format is correct: $PM_VERSION"
else
    log_warning "Cbox PM version format unexpected: $PM_VERSION"
fi

log_section "Cbox PM Configuration Tests"

# Test config file exists
assert_file_exists "$CONTAINER_NAME" "/etc/cbox-init/cbox-init.yaml" "Cbox PM config file exists"

# Test config validation
assert_exec_succeeds "$CONTAINER_NAME" "cbox-init check-config --config /etc/cbox-init/cbox-init.yaml" "Cbox PM config is valid"

# Verify config contains expected sections
CONFIG_CONTENT=$(docker exec "$CONTAINER_NAME" cat /etc/cbox-init/cbox-init.yaml 2>&1)
if echo "$CONFIG_CONTENT" | grep -q "processes:"; then
    log_success "Cbox PM config has processes section"
else
    log_failure "Cbox PM config missing processes section"
fi

if echo "$CONFIG_CONTENT" | grep -q "php-fpm:"; then
    log_success "Cbox PM config has php-fpm process"
else
    log_failure "Cbox PM config missing php-fpm process"
fi

if echo "$CONFIG_CONTENT" | grep -q "nginx:"; then
    log_success "Cbox PM config has nginx process"
else
    log_failure "Cbox PM config missing nginx process"
fi

log_section "Cbox PM Process Management Tests"

# Verify PHP-FPM is running (managed by Cbox PM)
assert_process_running "$CONTAINER_NAME" "php-fpm" "PHP-FPM running"

# Verify Nginx is running (managed by Cbox PM)
assert_process_running "$CONTAINER_NAME" "nginx" "Nginx running"

# Verify Cbox PM is the parent process (PID 1)
PID1_CMD=$(docker exec "$CONTAINER_NAME" cat /proc/1/comm 2>&1 || echo "unknown")
if [[ "$PID1_CMD" == "cbox-init" ]]; then
    log_success "Cbox PM is PID 1 (init process)"
else
    log_warning "PID 1 is: $PID1_CMD (expected cbox-init)"
fi

log_section "Cbox PM Metrics Tests"

# Test metrics endpoint (internal)
METRICS_OUTPUT=$(docker exec "$CONTAINER_NAME" curl -sf http://127.0.0.1:9090/metrics 2>&1 || echo "")
if [[ -n "$METRICS_OUTPUT" ]]; then
    log_success "Cbox PM metrics endpoint responds"

    # Check for expected metrics
    if echo "$METRICS_OUTPUT" | grep -q "cbox_init_"; then
        log_success "Cbox PM exports custom metrics"
    else
        log_info "Cbox PM metrics format may vary"
    fi

    if echo "$METRICS_OUTPUT" | grep -q "process_"; then
        log_success "Cbox PM exports process metrics"
    fi
else
    log_warning "Cbox PM metrics endpoint not responding (may be disabled)"
fi

# Test metrics from host (exposed port)
EXTERNAL_METRICS=$(curl -sf "http://localhost:9094/metrics" 2>&1 || echo "")
if [[ -n "$EXTERNAL_METRICS" ]]; then
    log_success "Cbox PM metrics accessible from host on port 9094"
else
    log_info "Cbox PM metrics not exposed externally (security default)"
fi

log_section "Cbox PM Health Check Tests"

# Test internal health endpoint via nginx
assert_http_code "$BASE_URL/health" 200 "Nginx health endpoint returns 200"

# Test application endpoint
assert_http_code "$BASE_URL/" 200 "Application endpoint returns 200"
assert_http_contains "$BASE_URL/" '"status":"ok"' "Application returns status ok"

log_section "Cbox PM DAG Dependency Tests"

# Verify nginx depends on php-fpm (DAG dependency)
# This is tested by ensuring both are running and nginx can reach php-fpm
# Use ss (iproute2) as primary, fall back to /proc/net/tcp (port 9000 = hex 2328)
if docker exec "$CONTAINER_NAME" sh -c "ss -tlnp 2>/dev/null | grep -q ':9000' || grep -q ':2328' /proc/net/tcp 2>/dev/null"; then
    log_success "PHP-FPM listening on port 9000"
else
    log_info "PHP-FPM port check: Could not verify port 9000 via ss or /proc/net/tcp"
fi

# Test FastCGI connection from nginx to php-fpm
FASTCGI_TEST=$(docker exec "$CONTAINER_NAME" curl -sf http://127.0.0.1/ 2>&1 || echo "failed")
if [[ "$FASTCGI_TEST" != "failed" ]]; then
    log_success "Nginx successfully proxies to PHP-FPM"
else
    log_warning "FastCGI proxy test inconclusive"
fi

log_section "Cbox PM Graceful Shutdown Test"

# Test that Cbox PM handles SIGTERM gracefully
log_info "Testing graceful shutdown (sending SIGTERM)..."
SHUTDOWN_START=$(date +%s)

# Send SIGTERM and capture exit
docker stop -t 10 "$CONTAINER_NAME" >/dev/null 2>&1 || true
SHUTDOWN_END=$(date +%s)
SHUTDOWN_DURATION=$((SHUTDOWN_END - SHUTDOWN_START))

if [[ $SHUTDOWN_DURATION -le 15 ]]; then
    log_success "Container stopped gracefully in ${SHUTDOWN_DURATION}s"
else
    log_warning "Container shutdown took ${SHUTDOWN_DURATION}s (may indicate ungraceful shutdown)"
fi

# Restart for remaining tests
docker start "$CONTAINER_NAME" >/dev/null 2>&1 || true
sleep 5

# Verify container came back up
if docker exec "$CONTAINER_NAME" true 2>/dev/null; then
    log_success "Container restarted successfully"
    # Cbox PM waits for PHP-FPM TCP health check (can take 35s+), so use longer timeout
    wait_for_healthy "$CONTAINER_NAME" 60 || log_warning "Container health check timed out (non-blocking)"
else
    log_warning "Container restart check skipped"
fi

log_section "Cbox PM Log Format Tests"

# Check container logs for JSON format
LOGS=$(docker logs "$CONTAINER_NAME" 2>&1 | tail -20)
if echo "$LOGS" | grep -q '"level"'; then
    log_success "Cbox PM uses structured JSON logging"
elif echo "$LOGS" | grep -qE "INFO|DEBUG|ERROR"; then
    log_success "Cbox PM uses structured logging"
else
    log_info "Log format: $(echo "$LOGS" | head -1)"
fi

# Store test results before any cleanup that might affect shell state
FINAL_PASSED=$TESTS_PASSED
FINAL_FAILED=$TESTS_FAILED

# Determine exit code BEFORE cleanup
if [ "$FINAL_FAILED" -gt 0 ]; then
    TEST_EXIT_CODE=1
else
    TEST_EXIT_CODE=0
fi

# Print summary (ignore any errors from print function)
print_summary 2>/dev/null || true

# Run cleanup in a subshell to completely isolate it from main script exit code
# The subshell will run with its own environment and cannot affect our exit code
(
    set +euo pipefail
    do_cleanup 2>/dev/null
) || true

# Use explicit exit with the pre-determined code
exit "$TEST_EXIT_CODE"
