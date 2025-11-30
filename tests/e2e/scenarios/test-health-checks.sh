#!/bin/bash
# E2E Test: Health Check Validation
# Tests all health check mechanisms across variants

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-utils.sh"

E2E_ROOT="$(get_e2e_root)"
FIXTURE_DIR="$E2E_ROOT/fixtures/plain-php"
PROJECT_NAME="e2e-health-check"
CONTAINER_NAME="e2e-health-check"
BASE_URL="http://localhost:8093"

# Cleanup on exit
trap 'cleanup_compose "$FIXTURE_DIR/docker-compose.override.yml" "$PROJECT_NAME" 2>/dev/null || true' EXIT

log_section "Health Check E2E Test"

# Create override for different port
cat > "$FIXTURE_DIR/docker-compose.override.yml" << 'EOF'
services:
  app:
    container_name: e2e-health-check
    ports:
      - "8093:80"
EOF

# Start the stack
docker compose -f "$FIXTURE_DIR/docker-compose.yml" -f "$FIXTURE_DIR/docker-compose.override.yml" -p "$PROJECT_NAME" down -v --remove-orphans 2>/dev/null || true
docker compose -f "$FIXTURE_DIR/docker-compose.yml" -f "$FIXTURE_DIR/docker-compose.override.yml" -p "$PROJECT_NAME" up -d --build

# Wait for healthy
wait_for_healthy "$CONTAINER_NAME" 60

log_section "Internal Health Check Script Tests"

# Test PHP-FPM is responding on its port (healthcheck.sh requires PHPeek PM in production)
assert_exec_succeeds "$CONTAINER_NAME" "netstat -tlnp | grep ':9000'" "PHP-FPM listening on port 9000"

# Test Nginx is responding on its port
assert_exec_succeeds "$CONTAINER_NAME" "netstat -tlnp | grep ':80'" "Nginx listening on port 80"

# Test that PHP-FPM and Nginx processes are running
assert_process_running "$CONTAINER_NAME" "php-fpm" "PHP-FPM process running"
assert_process_running "$CONTAINER_NAME" "nginx" "Nginx process running"

log_section "HTTP Health Endpoint Tests"

# Test /health endpoint
assert_http_code "$BASE_URL/health.php" 200 "HTTP health endpoint returns 200"

# Test response format
RESPONSE=$(curl -s "$BASE_URL/health.php")
if echo "$RESPONSE" | jq . >/dev/null 2>&1; then
    log_success "Health response is valid JSON"
else
    log_fail "Health response is not valid JSON"
fi

log_section "Process Health Tests"

# PHP-FPM process check
assert_process_running "$CONTAINER_NAME" "php-fpm: master" "PHP-FPM master process exists"

# Nginx process check
assert_process_running "$CONTAINER_NAME" "nginx: master" "Nginx master process exists"

# Check for zombie processes (STAT column contains 'Z')
# grep -c returns 1 exit code when no match but still outputs 0, so capture output only
ZOMBIES=$(docker exec "$CONTAINER_NAME" sh -c "ps aux | awk '\$8 ~ /Z/ {count++} END {print count+0}'" 2>/dev/null)
if [ "$ZOMBIES" = "0" ] || [ -z "$ZOMBIES" ]; then
    log_success "No zombie processes detected"
else
    log_fail "Found $ZOMBIES zombie processes"
fi

log_section "Port Health Tests"

# Test PHP-FPM port
assert_exec_succeeds "$CONTAINER_NAME" "nc -z 127.0.0.1 9000" "PHP-FPM listening on port 9000"

# Test Nginx port
assert_exec_succeeds "$CONTAINER_NAME" "nc -z 127.0.0.1 80" "Nginx listening on port 80"

log_section "OPcache Health Tests"

# Test OPcache is enabled via FPM (CLI has opcache.enable_cli=Off by default)
assert_http_contains "$BASE_URL/" '"opcache": true' "OPcache is enabled (via FPM)"

# Test OPcache extension is loaded in FPM
assert_http_contains "$BASE_URL/health.php" '"opcache":' "OPcache check in health endpoint"

log_section "Docker Health Check Integration Tests"

# Test Docker's view of health
DOCKER_HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "unknown")
if [ "$DOCKER_HEALTH" = "healthy" ]; then
    log_success "Docker reports container as healthy"
else
    log_fail "Docker reports container as: $DOCKER_HEALTH"
fi

# Test health check history
HEALTH_LOGS=$(docker inspect --format='{{range .State.Health.Log}}{{.Output}}{{end}}' "$CONTAINER_NAME" 2>/dev/null | head -100)
if [ -n "$HEALTH_LOGS" ]; then
    log_success "Health check history available"
else
    log_skip "No health check history yet"
fi

# Cleanup override file
rm -f "$FIXTURE_DIR/docker-compose.override.yml"

# Manual cleanup since trap uses different compose file
docker compose -f "$FIXTURE_DIR/docker-compose.yml" -p "$PROJECT_NAME" down -v --remove-orphans 2>/dev/null || true

print_summary
