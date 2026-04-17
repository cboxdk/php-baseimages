# PHP-CLI Cbox Init Support — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable php-cli images to run CLI workloads (queue workers, scheduler, horizon) through cbox-init for structured logging, metrics, health checks, graceful shutdown, and CLI management — instead of raw `command:` overrides.

**Architecture:** Add a `cbox-init.yaml` for CLI workloads (no php-fpm/nginx, just Laravel processes). Modify the php-cli entrypoint to detect `cbox-init` as the command (or as default when `CBOX_INIT_ENABLED=true`) and start cbox-init with the CLI config. Same env var aliases (`LARAVEL_QUEUE`, `LARAVEL_HORIZON`, etc.) work identically to php-fpm-nginx. The existing php-cli `command: php artisan ...` pattern continues to work unchanged for backward compatibility.

**Tech Stack:** Shell (entrypoint), YAML (cbox-init config), Docker (Dockerfile COPY directives), Markdown (docs)

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `php-cli/common/cbox-init.yaml` | Create | CLI cbox-init config — queue workers, horizon, scheduler, reverb (no php-fpm/nginx) |
| `php-cli/common/cbox-init-rootless.yaml` | Create | Same as above but identical (CLI has no port differences) |
| `php-cli/common/docker-entrypoint.sh` | Modify | Add cbox-init detection, env var mapping, config patching, cbox-init startup |
| `php-cli/common/healthcheck.sh` | Modify | Add cbox-init metrics endpoint check when cbox-init is running |
| `php-cli/Dockerfile` | Modify | COPY cbox-init.yaml + rootless variant into all 8 stages, mkdir /etc/cbox-init |
| `docs/guides/queue-workers.md` | Modify | Add "Managed by Cbox Init" section as the recommended approach |
| `docs/cbox-init-integration.md` | Modify | Add "CLI Workloads" section explaining php-cli + cbox-init |
| `docs/getting-started/choosing-your-image.md` | Modify | Update php-cli description to mention cbox-init support |
| `docs/reference/environment-variables.md` | Modify | Add `CBOX_INIT_ENABLED` var |

---

### Task 1: Create CLI cbox-init config

**Files:**
- Create: `php-cli/common/cbox-init.yaml`
- Create: `php-cli/common/cbox-init-rootless.yaml`

- [ ] **Step 1: Create `php-cli/common/cbox-init.yaml`**

This is a stripped-down version of `php-fpm-nginx/common/cbox-init.yaml` without php-fpm and nginx processes. Only CLI workload processes: horizon, reverb, queue workers, scheduler. Same global config (metrics, API, logging). Same env var conventions (`CBOX_INIT_PROCESS_*_ENABLED`).

```yaml
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  Cbox Init Configuration (CLI)                                            ║
# ║  Process Manager for PHP CLI Containers (queue workers, schedulers)       ║
# ║  https://github.com/cboxdk/init                                          ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

version: "1.0"

global:
  # Shutdown timeout for graceful process termination
  shutdown_timeout: 30

  # Logging configuration
  log_level: info
  log_format: json

  # Management API (disabled by default for security)
  api_enabled: false
  api_port: 9180
  api_auth: ""

  # Prometheus Metrics (enabled by default, localhost only for security)
  metrics_enabled: true
  metrics_port: 9090
  metrics_path: /metrics

  # Restart configuration with exponential backoff
  restart_backoff_initial: 1s
  restart_backoff_max: 60s
  max_restart_attempts: 5

# ═══════════════════════════════════════════════════════════════════════════
# Process Definitions — CLI workloads only (no php-fpm, no nginx)
# ═══════════════════════════════════════════════════════════════════════════
processes:
  # ─────────────────────────────────────────────────────────────────────────
  # Laravel Horizon - Queue Manager
  # Enable via CBOX_INIT_PROCESS_HORIZON_ENABLED=true or LARAVEL_HORIZON=true
  # ─────────────────────────────────────────────────────────────────────────
  horizon:
    enabled: false
    command: ["php", "artisan", "horizon"]
    type: longrun
    restart: always
    scale: 1
    working_dir: /var/www/html
    stdout: true
    stderr: true
    shutdown:
      pre_stop_hook:
        command: ["php", "artisan", "horizon:terminate"]
        timeout: 60
    logging:
      files:
        laravel-log:
          path: /var/www/html/storage/logs/laravel.log
          json: { enabled: true, detect_auto: true }
          rotate:
            max_size: 50MB
            max_files: 7

  # ─────────────────────────────────────────────────────────────────────────
  # Laravel Reverb - WebSocket Server
  # Enable via CBOX_INIT_PROCESS_REVERB_ENABLED=true or LARAVEL_REVERB=true
  # ─────────────────────────────────────────────────────────────────────────
  reverb:
    enabled: false
    command: ["php", "artisan", "reverb:start", "--host=0.0.0.0", "--port=8080"]
    type: longrun
    restart: always
    scale: 1
    working_dir: /var/www/html
    stdout: true
    stderr: true

  # ─────────────────────────────────────────────────────────────────────────
  # Queue Workers - Default Queue
  # Enable via CBOX_INIT_PROCESS_QUEUE_DEFAULT_ENABLED=true or LARAVEL_QUEUE=true
  # ─────────────────────────────────────────────────────────────────────────
  queue-default:
    enabled: false
    command: ["php", "artisan", "queue:work", "redis", "--queue=default", "--tries=3"]
    type: longrun
    restart: always
    scale: 2
    working_dir: /var/www/html
    stdout: true
    stderr: true

  # ─────────────────────────────────────────────────────────────────────────
  # Queue Workers - High Priority Queue
  # Enable via CBOX_INIT_PROCESS_QUEUE_HIGH_ENABLED=true or LARAVEL_QUEUE_HIGH=true
  # ─────────────────────────────────────────────────────────────────────────
  queue-high:
    enabled: false
    command: ["php", "artisan", "queue:work", "redis", "--queue=high", "--tries=3"]
    type: longrun
    restart: always
    scale: 1
    working_dir: /var/www/html
    stdout: true
    stderr: true

  # ─────────────────────────────────────────────────────────────────────────
  # Laravel Scheduler
  # Enable via CBOX_INIT_PROCESS_SCHEDULER_ENABLED=true or LARAVEL_SCHEDULER=true
  # ─────────────────────────────────────────────────────────────────────────
  scheduler:
    enabled: false
    command: ["php", "artisan", "schedule:work"]
    type: longrun
    restart: always
    scale: 1
    working_dir: /var/www/html
    stdout: true
    stderr: true
```

- [ ] **Step 2: Copy to rootless variant**

```bash
cp php-cli/common/cbox-init.yaml php-cli/common/cbox-init-rootless.yaml
```

The rootless variant is identical for CLI because there are no port-binding differences (no nginx). Update the header comment in the rootless file:

```yaml
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  Cbox Init Configuration (CLI - Rootless)                                 ║
# ║  Process Manager for PHP CLI Containers (queue workers, schedulers)       ║
# ║  https://github.com/cboxdk/init                                          ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
```

- [ ] **Step 3: Commit**

```bash
git add php-cli/common/cbox-init.yaml php-cli/common/cbox-init-rootless.yaml
git commit -m "feat: add cbox-init config for CLI workloads (queue, horizon, scheduler)"
```

---

### Task 2: Add COPY directives to php-cli Dockerfile

**Files:**
- Modify: `php-cli/Dockerfile`

The Dockerfile has 8 stages (4 root + 4 rootless). Each needs:
1. `mkdir -p /etc/cbox-init` (rootless stages need `chown`)
2. `COPY php-cli/common/cbox-init.yaml /etc/cbox-init/cbox-init.yaml` (rootless uses `cbox-init-rootless.yaml`)

- [ ] **Step 1: Add COPY to all 4 root stages**

In each root stage (`slim-root`, `root`, `chromium-root`, `dev-root`), add after the existing `COPY` + `RUN chmod` block, before the `HEALTHCHECK`:

```dockerfile
RUN mkdir -p /etc/cbox-init
COPY php-cli/common/cbox-init.yaml /etc/cbox-init/cbox-init.yaml
```

- [ ] **Step 2: Add COPY to all 4 rootless stages**

In each rootless stage (`slim-rootless`, `rootless`, `chromium-rootless`, `dev-rootless`), add inside the `USER root` block (before `USER www-data`):

```dockerfile
RUN mkdir -p /etc/cbox-init && chown -R www-data:www-data /etc/cbox-init
COPY php-cli/common/cbox-init-rootless.yaml /etc/cbox-init/cbox-init.yaml
```

- [ ] **Step 3: Build and verify**

```bash
docker build -f php-cli/Dockerfile --build-arg PHP_VERSION=8.4 --target root -t cbox-cli-test:latest .
docker run --rm cbox-cli-test:latest cat /etc/cbox-init/cbox-init.yaml | head -5
```

Expected: Shows the CLI cbox-init.yaml header.

- [ ] **Step 4: Commit**

```bash
git add php-cli/Dockerfile
git commit -m "feat: ship cbox-init.yaml with php-cli images"
```

---

### Task 3: Modify php-cli entrypoint to support cbox-init

**Files:**
- Modify: `php-cli/common/docker-entrypoint.sh`

The entrypoint needs to:
1. Map LARAVEL_* env aliases to CBOX_INIT_PROCESS_* vars (same as php-fpm-nginx)
2. Apply cbox-init global config overrides via sed (API, metrics, logging — same as php-fpm-nginx)
3. When `$1` is `cbox-init` OR no args are given AND any `CBOX_INIT_PROCESS_*_ENABLED` or `LARAVEL_*` process var is true → start cbox-init
4. Otherwise exec `"$@"` as before (backward compatible)

- [ ] **Step 1: Add env alias mapping function**

Add after the signal handler setup (line ~34), before the lifecycle check:

```sh
###########################################
# Map LARAVEL_* aliases to CBOX_INIT_PROCESS_* env vars
# Same mapping as php-fpm-nginx entrypoint
###########################################
map_env_aliases() {
    [ -n "$LARAVEL_HORIZON" ] && export CBOX_INIT_PROCESS_HORIZON_ENABLED="$LARAVEL_HORIZON"
    [ -n "$LARAVEL_REVERB" ] && export CBOX_INIT_PROCESS_REVERB_ENABLED="$LARAVEL_REVERB"
    [ -n "$LARAVEL_SCHEDULER" ] && export CBOX_INIT_PROCESS_SCHEDULER_ENABLED="$LARAVEL_SCHEDULER"
    [ -n "$LARAVEL_QUEUE" ] && export CBOX_INIT_PROCESS_QUEUE_DEFAULT_ENABLED="$LARAVEL_QUEUE"
    [ -n "$LARAVEL_QUEUE_HIGH" ] && export CBOX_INIT_PROCESS_QUEUE_HIGH_ENABLED="$LARAVEL_QUEUE_HIGH"
    # Backward compatibility
    [ -n "$LARAVEL_SCHEDULER_ENABLED" ] && export CBOX_INIT_PROCESS_SCHEDULER_ENABLED="$LARAVEL_SCHEDULER_ENABLED"
    [ -n "$LARAVEL_AUTO_OPTIMIZE" ] && export LARAVEL_OPTIMIZE_ENABLED="$LARAVEL_AUTO_OPTIMIZE"
    [ -n "$LARAVEL_AUTO_MIGRATE" ] && export LARAVEL_MIGRATE_ENABLED="$LARAVEL_AUTO_MIGRATE"
}
```

- [ ] **Step 2: Add cbox-init config override function**

Same `apply_cbox_init_env_overrides()` as php-fpm-nginx:

```sh
###########################################
# Cbox Init Environment Variable Overrides
# Copies config to /tmp and patches with sed
###########################################
apply_cbox_init_env_overrides() {
    local src="${CBOX_INIT_CONFIG:-/etc/cbox-init/cbox-init.yaml}"
    local dst="/tmp/cbox-init.yaml"

    [ ! -f "$src" ] && return 0

    cp "$src" "$dst"

    # Management API overrides
    [ -n "$CBOX_INIT_API_ENABLED" ] && sed -i "s/^\(\s*\)api_enabled:.*/\1api_enabled: ${CBOX_INIT_API_ENABLED}/" "$dst"
    [ -n "$CBOX_INIT_API_PORT" ] && sed -i "s/^\(\s*\)api_port:.*/\1api_port: ${CBOX_INIT_API_PORT}/" "$dst"
    [ -n "$CBOX_INIT_API_AUTH" ] && sed -i "s/^\(\s*\)api_auth:.*/\1api_auth: \"${CBOX_INIT_API_AUTH}\"/" "$dst"

    # Metrics overrides
    [ -n "$CBOX_INIT_METRICS_ENABLED" ] && sed -i "s/^\(\s*\)metrics_enabled:.*/\1metrics_enabled: ${CBOX_INIT_METRICS_ENABLED}/" "$dst"
    [ -n "$CBOX_INIT_METRICS_PORT" ] && sed -i "s/^\(\s*\)metrics_port:.*/\1metrics_port: ${CBOX_INIT_METRICS_PORT}/" "$dst"

    # Logging overrides
    [ -n "$CBOX_INIT_LOG_LEVEL" ] && sed -i "s/^\(\s*\)log_level:.*/\1log_level: ${CBOX_INIT_LOG_LEVEL}/" "$dst"
    [ -n "$CBOX_INIT_LOG_FORMAT" ] && sed -i "s/^\(\s*\)log_format:.*/\1log_format: ${CBOX_INIT_LOG_FORMAT}/" "$dst"

    # Shutdown timeout override
    [ -n "$CBOX_INIT_SHUTDOWN_TIMEOUT" ] && sed -i "s/^\(\s*\)shutdown_timeout:.*/\1shutdown_timeout: ${CBOX_INIT_SHUTDOWN_TIMEOUT}/" "$dst"

    export CBOX_INIT_CONFIG="$dst"
}
```

- [ ] **Step 3: Add cbox-init detection function**

```sh
###########################################
# Check if any cbox-init process is enabled
###########################################
has_cbox_init_processes() {
    [ "${CBOX_INIT_PROCESS_HORIZON_ENABLED:-false}" = "true" ] && return 0
    [ "${CBOX_INIT_PROCESS_REVERB_ENABLED:-false}" = "true" ] && return 0
    [ "${CBOX_INIT_PROCESS_QUEUE_DEFAULT_ENABLED:-false}" = "true" ] && return 0
    [ "${CBOX_INIT_PROCESS_QUEUE_HIGH_ENABLED:-false}" = "true" ] && return 0
    [ "${CBOX_INIT_PROCESS_SCHEDULER_ENABLED:-false}" = "true" ] && return 0
    return 1
}
```

- [ ] **Step 4: Modify the command execution block**

Replace the existing exec block (lines ~84-91) with:

```sh
# Map env aliases before checking
map_env_aliases

# Execute command
if [ "$1" = "cbox-init" ] || { [ -z "$1" ] && has_cbox_init_processes; }; then
    # Start via cbox-init process manager
    if ! command -v cbox-init >/dev/null 2>&1; then
        log_error "Cbox Init binary not found"
        exit 1
    fi

    CBOX_INIT_CONFIG="${CBOX_INIT_CONFIG:-/etc/cbox-init/cbox-init.yaml}"
    apply_cbox_init_env_overrides
    log_info "Starting Cbox Init process manager"
    log_info "Config: $CBOX_INIT_CONFIG"
    exec /usr/local/bin/cbox-init serve --config "$CBOX_INIT_CONFIG"
elif [ -z "$1" ]; then
    log_info "No command specified, starting interactive shell"
    exec /bin/sh
else
    log_info "Executing: $*"
    exec "$@"
fi
```

- [ ] **Step 5: Test backward compatibility**

```bash
# Direct command still works
docker run --rm cbox-cli-test:latest php -v
# Expected: PHP 8.4.x output

# cbox-init starts when LARAVEL_QUEUE=true and no command
docker run --rm -e LARAVEL_QUEUE=true cbox-cli-test:latest 2>&1 | head -10
# Expected: Cbox Init starting, queue-default process starting

# Explicit cbox-init command works
docker run --rm -e LARAVEL_SCHEDULER=true cbox-cli-test:latest cbox-init 2>&1 | head -10
# Expected: Same as above
```

- [ ] **Step 6: Commit**

```bash
git add php-cli/common/docker-entrypoint.sh
git commit -m "feat: php-cli entrypoint supports cbox-init for managed CLI workloads"
```

---

### Task 4: Update healthcheck for cbox-init mode

**Files:**
- Modify: `php-cli/common/healthcheck.sh`

When cbox-init is running (PID 1), the healthcheck should also check the metrics/health endpoint.

- [ ] **Step 1: Add cbox-init health check**

After the existing "Check 5: Cbox Init" block (line ~84), add:

```sh
# ─────────────────────────────────────────────────────────────────────────────
# Check 5b: Cbox Init Health (when running as PID 1)
# ─────────────────────────────────────────────────────────────────────────────
METRICS_PORT="${CBOX_INIT_METRICS_PORT:-9090}"
if [ "$(cat /proc/1/comm 2>/dev/null)" = "cbox-init" ]; then
    if curl -sf "http://127.0.0.1:${METRICS_PORT}/health" >/dev/null 2>&1; then
        check_passed "Cbox Init health endpoint healthy"
    else
        _check_failed "Cbox Init health endpoint not responding on :${METRICS_PORT}"
    fi
fi
```

- [ ] **Step 2: Test healthcheck**

```bash
docker run -d --name cli-health-test -e LARAVEL_QUEUE=true cbox-cli-test:latest
sleep 5
docker exec cli-health-test /usr/local/bin/healthcheck.sh
docker rm -f cli-health-test
```

Expected: Shows "Cbox Init health endpoint healthy" along with other checks.

- [ ] **Step 3: Commit**

```bash
git add php-cli/common/healthcheck.sh
git commit -m "feat: php-cli healthcheck detects cbox-init and checks health endpoint"
```

---

### Task 5: Update documentation

**Files:**
- Modify: `docs/guides/queue-workers.md`
- Modify: `docs/cbox-init-integration.md`
- Modify: `docs/getting-started/choosing-your-image.md`
- Modify: `docs/reference/environment-variables.md`

- [ ] **Step 1: Rewrite queue-workers.md Quick Start**

Replace the current Quick Start section (lines 12-34) that shows raw `command:` override with the cbox-init approach as primary, and move raw command to an "Alternative: Direct Command" subsection:

```markdown
## Quick Start

Use `php-cli` with Cbox Init for managed queue workers with structured logging, metrics, health checks, and graceful shutdown:

\```yaml
# docker-compose.yml
services:
  worker:
    image: ghcr.io/cboxdk/php-baseimages/php-cli:8.4-bookworm
    volumes:
      - ./:/var/www/html
    environment:
      LARAVEL_QUEUE: "true"
      REDIS_HOST: redis
    depends_on:
      - redis

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data

volumes:
  redis_data:
\```

This starts the queue worker through Cbox Init, giving you:
- Structured JSON logging in `docker logs`
- Prometheus metrics on port 9090
- Automatic restart with exponential backoff
- Graceful shutdown on `docker stop`
- CLI management: `docker exec worker cbox-init list`

### Scaling Workers

\```yaml
environment:
  LARAVEL_QUEUE: "true"
  CBOX_INIT_PROCESS_QUEUE_DEFAULT_SCALE: "5"
\```

### Multiple Queue Types

\```yaml
environment:
  LARAVEL_QUEUE: "true"
  LARAVEL_QUEUE_HIGH: "true"
  CBOX_INIT_PROCESS_QUEUE_DEFAULT_SCALE: "3"
  CBOX_INIT_PROCESS_QUEUE_HIGH_SCALE: "2"
\```

### Alternative: Direct Command

For simple use cases without process management:

\```yaml
worker:
  image: ghcr.io/cboxdk/php-baseimages/php-cli:8.4-bookworm
  command: php artisan queue:work redis --sleep=3 --tries=3
  restart: unless-stopped
\```
```

- [ ] **Step 2: Add CLI workloads section to cbox-init-integration.md**

Add a new section after the "Quick Start" section (around line 24):

```markdown
## CLI Workloads

Cbox Init also works with `php-cli` images for background workloads like queue workers, schedulers, and Horizon — without running PHP-FPM or Nginx.

### Why use cbox-init for CLI?

Running `command: php artisan queue:work` directly means no structured logging, no metrics, no health checks, and no graceful shutdown. Cbox Init wraps your CLI processes with all of these.

### Usage

Set process env vars and omit the `command:` — the entrypoint auto-detects and starts cbox-init:

\```yaml
services:
  worker:
    image: ghcr.io/cboxdk/php-baseimages/php-cli:8.4-bookworm
    environment:
      LARAVEL_QUEUE: "true"
      CBOX_INIT_PROCESS_QUEUE_DEFAULT_SCALE: "5"

  scheduler:
    image: ghcr.io/cboxdk/php-baseimages/php-cli:8.4-bookworm
    environment:
      LARAVEL_SCHEDULER: "true"

  horizon:
    image: ghcr.io/cboxdk/php-baseimages/php-cli:8.4-bookworm
    environment:
      LARAVEL_HORIZON: "true"
\```

All the same env vars, CLI commands, metrics, and Management API work identically to `php-fpm-nginx`.
```

- [ ] **Step 3: Update choosing-your-image.md**

In the "Single-Service vs Multi-Service" section, add a note about php-cli + cbox-init for workers. After the existing `php-cli` size matrix (around line 62), add:

```markdown
**php-cli with Cbox Init:** Use `php-cli` for background workloads (queue workers, schedulers, Horizon). Set `LARAVEL_QUEUE=true` or similar env vars and the entrypoint automatically starts Cbox Init with structured logging, metrics, and health checks. See [Queue Workers Guide](../guides/queue-workers).
```

- [ ] **Step 4: Commit**

```bash
git add docs/guides/queue-workers.md docs/cbox-init-integration.md docs/getting-started/choosing-your-image.md
git commit -m "docs: document php-cli with cbox-init for managed CLI workloads"
```

---

### Task 6: Integration test

- [ ] **Step 1: Build full php-cli image locally**

```bash
docker build -f php-cli/Dockerfile --build-arg PHP_VERSION=8.4 --target root -t cbox-cli-init:test .
```

- [ ] **Step 2: Test cbox-init mode with queue worker**

```bash
docker run -d --name cli-queue-test \
  -e LARAVEL_QUEUE=true \
  -e CBOX_INIT_PROCESS_QUEUE_DEFAULT_SCALE=3 \
  -e CBOX_INIT_METRICS_PORT=9090 \
  cbox-cli-init:test

sleep 5
docker logs cli-queue-test 2>&1 | head -20
# Expected: Cbox Init starting, queue-default process starting with scale=3

docker exec cli-queue-test cbox-init list 2>&1
# Expected: Shows queue-default process

docker exec cli-queue-test curl -sf http://127.0.0.1:9090/health
# Expected: OK or {"status":"healthy"}

docker rm -f cli-queue-test
```

- [ ] **Step 3: Test backward compat (direct command still works)**

```bash
docker run --rm cbox-cli-init:test php -v
# Expected: PHP 8.4.x, NOT cbox-init

docker run --rm cbox-cli-init:test php -r "echo 'hello';"
# Expected: hello
```

- [ ] **Step 4: Test cbox-init API**

```bash
docker run -d --name cli-api-test \
  -e LARAVEL_QUEUE=true \
  -e CBOX_INIT_API_ENABLED=true \
  -e CBOX_INIT_API_AUTH=test123 \
  -p 9180:9180 \
  cbox-cli-init:test

sleep 5
curl -sf -H "Authorization: Bearer test123" http://localhost:9180/api/v1/processes
# Expected: JSON with queue-default process

docker rm -f cli-api-test
```

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "test: verify php-cli cbox-init integration"
```
