---
title: "Environment Variables Reference"
description: "Complete reference for all Cbox environment variables"
weight: 1
---

# Environment Variables Reference

Complete reference for all environment variables supported by Cbox PHP Base Images powered by Cbox Init.

## Quick Start Variables

These are the most commonly used variables. Just set what you need!

| Variable | Default | Description |
|----------|---------|-------------|
| `PUID` | *(container default)* | User ID for application files — fixes permission issues |
| `PGID` | *(container default)* | Group ID for application files |
| `LARAVEL_SCHEDULER` | `false` | Enable Laravel scheduler |
| `LARAVEL_HORIZON` | `false` | Enable Laravel Horizon |
| `LARAVEL_REVERB` | `false` | Enable Laravel Reverb WebSockets |
| `LARAVEL_QUEUE` | `false` | Enable queue workers |
| `PHP_MEMORY_LIMIT` | `256M` | PHP memory limit |
| `PHP_MAX_EXECUTION_TIME` | `30` | Max script execution time |

---

## User/Group Mapping (PUID/PGID)

**The most common Docker problem:** files created inside the container are owned by `www-data` (UID 33), but your host user has a different UID (typically 1000). This causes permission denied errors on bind mounts, and files created in the container can't be edited on the host.

**PUID/PGID solves this** by remapping the container's `www-data` user to match your host user.

| Variable | Default | Description |
|----------|---------|-------------|
| `PUID` | *(container default)* | Set the UID that `www-data` runs as |
| `PGID` | *(container default)* | Set the GID that `www-data` runs as |
| `APP_USER` | `www-data` | Application user name |
| `APP_GROUP` | `www-data` | Application group name |

### Find your host UID/GID

```bash
id -u    # Your UID (typically 1000)
id -g    # Your GID (typically 1000)
```

### Basic usage

```yaml
services:
  app:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm
    volumes:
      - ./:/var/www/html
    environment:
      - PUID=1000
      - PGID=1000
```

### Common scenarios

**Linux with bind mounts** — the most common case. Without PUID/PGID, Laravel's `storage/` and `bootstrap/cache/` will be owned by UID 33, and your editor/IDE can't write to them:

```yaml
environment:
  - PUID=1000
  - PGID=1000
```

**NFS volumes** — NFS preserves the original UID/GID. Match them to avoid permission issues:

```yaml
environment:
  - PUID=1001
  - PGID=1001
```

**CI/CD pipelines** — GitHub Actions and GitLab CI run as UID 1001 or similar:

```yaml
environment:
  - PUID=1001
  - PGID=1001
```

### What happens when you set PUID/PGID

1. The container's `www-data` user is remapped to the specified UID/GID
2. Ownership of `/var/www/html` is updated to match
3. Framework directories (`storage/`, `bootstrap/cache/`, `var/`) are chowned automatically
4. PHP-FPM runs worker processes as the remapped user
5. Files created by PHP have the correct ownership on your host

### Important notes

- **Requires root mode** — PUID/PGID only works in root images (the default). Rootless images skip PUID/PGID mapping since the container already runs as `www-data`.
- **Docker Desktop (macOS/Windows)** — Docker Desktop handles permission translation automatically via its VM layer, so PUID/PGID is usually not needed. It won't break anything if set, though.
- **Only set what you need** — if you only need to change the UID, just set `PUID`. If you only need the GID, just set `PGID`.

---

## Laravel Shorthand Variables

These user-friendly variables are automatically mapped to Cbox Init process controls by the entrypoint script.

### Process Control

| Variable | Maps To | Description |
|----------|---------|-------------|
| `LARAVEL_SCHEDULER` | `CBOX_INIT_PROCESS_SCHEDULER_ENABLED` | Enable `php artisan schedule:work` |
| `LARAVEL_HORIZON` | `CBOX_INIT_PROCESS_HORIZON_ENABLED` | Enable Laravel Horizon |
| `LARAVEL_REVERB` | `CBOX_INIT_PROCESS_REVERB_ENABLED` | Enable Laravel Reverb |
| `LARAVEL_QUEUE` | `CBOX_INIT_PROCESS_QUEUE_DEFAULT_ENABLED` | Enable default queue worker |
| `LARAVEL_QUEUE_HIGH` | `CBOX_INIT_PROCESS_QUEUE_HIGH_ENABLED` | Enable high priority queue |
| `CBOX_QUEUE_AUTOSCALER` | `CBOX_INIT_PROCESS_AUTOSCALER_ENABLED` | Enable queue autoscaler (`cboxdk/laravel-queue-autoscale`) |

### Queue Scaling

| Variable | Default | Description |
|----------|---------|-------------|
| `CBOX_INIT_PROCESS_QUEUE_DEFAULT_SCALE` | `2` | Number of default queue worker instances |
| `CBOX_INIT_PROCESS_QUEUE_HIGH_SCALE` | `1` | Number of high priority queue worker instances |

### Laravel Startup Hooks

| Variable | Default | Description |
|----------|---------|-------------|
| `LARAVEL_OPTIMIZE_ENABLED` | `false` | Run `config:cache`, `route:cache`, `view:cache` on startup |
| `LARAVEL_MIGRATE_ENABLED` | `false` | Run `php artisan migrate --force` on startup |
| `LARAVEL_MIGRATE_ALLOW_FAILURE` | `false` | Continue container startup if migrations fail |

---

## PHP Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `PHP_MEMORY_LIMIT` | `256M` | Memory limit |
| `PHP_MAX_EXECUTION_TIME` | `30` | Max execution time |
| `PHP_MAX_INPUT_TIME` | `60` | Max input time |
| `PHP_POST_MAX_SIZE` | `100M` | Max POST size |
| `PHP_UPLOAD_MAX_FILESIZE` | `100M` | Max upload size |
| `PHP_MAX_FILE_UPLOADS` | `20` | Max simultaneous uploads |
| `PHP_MAX_INPUT_VARS` | `1000` | Max input variables |
| `PHP_DATE_TIMEZONE` | `UTC` | Default timezone |
| `PHP_DISPLAY_ERRORS` | `Off` | Display errors (use `On` for dev) |
| `PHP_DISPLAY_STARTUP_ERRORS` | `Off` | Display startup errors |
| `PHP_ERROR_REPORTING` | `E_ALL & ~E_DEPRECATED & ~E_STRICT` | Error reporting level |
| `PHP_LOG_ERRORS` | `On` | Log errors |
| `PHP_ERROR_LOG` | `/dev/stderr` | Error log destination |
| `PHP_SESSION_COOKIE_SECURE` | *(not set)* | Restrict session cookies to HTTPS (`1` recommended for prod) |
| `PHP_REALPATH_CACHE_TTL` | `600` | Path cache TTL in seconds |
| `PHP_OPEN_BASEDIR` | the app's directories + read-only kernel statistics (below) | `open_basedir` for the FPM pool. Empty means no restriction — which is what the **dev** tier sets. |

#### One definition, and why that took three attempts

`open_basedir` is set in exactly one place: the entrypoint writes
`zz-env-overrides.conf` from `PHP_OPEN_BASEDIR`, which the image always sets. The
static pool defines it nowhere.

It has to be that way. **PHP-FPM takes the FIRST definition of a
`php_admin_value`, not the last** — the opposite of php.ini's `conf.d` rule — and
pool files load alphabetically. So while `fpm-pool.conf` (installed as
`zz-custom.conf`) carried a narrow default, no override could ever win, and the
comment beside it claiming the variable "loads after this pool and wins" was
simply false. Setting the variable did nothing, on both the php-fpm and
php-fpm-nginx images.

**Empty is a value.** With `PHP_OPEN_BASEDIR=""` no directive is written at all
and the pool runs unrestricted. That is how the **dev** tier turns it off: a
package sandbox reads fixtures, writes caches and dumps profiler traces at paths
nobody can enumerate in advance, and a restriction widened once per surprise is
one that ends up at `/`. No other tier does this, and the dev tier is never a
base for a deployed application.

Verify it in a request rather than in a file — the CLI has no `open_basedir` at
all, so `php -i` will tell you nothing:

```bash
docker exec -e SCRIPT_FILENAME=/var/www/html/probe.php -e REQUEST_METHOD=GET \
    <container> cgi-fcgi -bind -connect 127.0.0.1:9000
```

#### What the default lets through, and what it does not

The default is the application's own directories **plus the read-only kernel
statistics** `cboxdk/system-metrics` reads — `/proc/stat`, `/proc/loadavg`,
`/proc/meminfo`, `/proc/uptime`, `/proc/cpuinfo`, `/proc/diskstats`,
`/proc/mounts`, `/proc/net/`, `/proc/self/cgroup`, `/sys/fs/cgroup` and
`/sys/class/dmi/id/`.

Without them `cboxdk/laravel-telemetry` collects nothing from a web request and
says so nowhere: the collector degrades to empty and reports a healthy
application with no metrics.

**`/proc/1/environ` is deliberately absent**, and it is why this is a list rather
than plain `/proc`: PID 1's environment is every secret the container holds, and
a file-read primitive in an application that could reach it would have the
database password. system-metrics reads it as one of several container-detection
probes and degrades cleanly without it. `/proc/self/environ` and
`/proc/*/cmdline` are absent for the same reason.

### OPcache

| Variable | Default | Description |
|----------|---------|-------------|
| `PHP_OPCACHE_ENABLE` | `1` | Enable OPcache |
| `PHP_OPCACHE_MEMORY_CONSUMPTION` | `256` | OPcache memory (MB) |
| `PHP_OPCACHE_INTERNED_STRINGS_BUFFER` | `16` | Interned strings buffer (MB) |
| `PHP_OPCACHE_MAX_ACCELERATED_FILES` | `20000` | Max cached files |
| `PHP_OPCACHE_REVALIDATE_FREQ` | `0` | Revalidation frequency |
| `PHP_OPCACHE_VALIDATE_TIMESTAMPS` | `0` | Validate timestamps (1 for dev) |
| `PHP_OPCACHE_JIT` | `tracing` | JIT mode: `tracing`, `function`, `off` |
| `PHP_OPCACHE_JIT_BUFFER_SIZE` | `128M` | JIT buffer size |

### PHP-FPM worker auto-tuning (boot seed)

By default the worker pool is **auto-tuned by cbox-init from the container's cgroup
memory and CPU limits** — it reads `memory.max`, reserves headroom for nginx/opcache/system,
and derives `pm.max_children` (and the other PM values). A 512 MB container yields ~4 workers,
768 MB ~6, etc. This replaces guessing a static `pm.max_children` and prevents OOM-kills.

| Variable | Default | Description |
|----------|---------|-------------|
| `PHP_FPM_AUTOTUNE_PROFILE` | *(adaptive, see below)* | Sizing profile: `dev`, `light`, `medium`, `heavy`, `bursty`. Set to empty (`""`) to disable auto-tuning and use the static values below. |

**Adaptive default:** each profile has a memory floor below which cbox-init refuses
to start (medium needs ≥512 MB, light ≥384 MB, heavy ≥2 GB). When you don't set a
profile, the entrypoint picks one that fits the container's memory limit: ≥512 MB
(or no limit) → `medium`, ≥384 MB → `light`, below that auto-tuning is disabled
with a warning and the static fallbacks below apply. An **explicitly** set profile
is never rewritten — if it doesn't fit the limit, the container exits with a clear
error so the misconfiguration is caught at deploy time.

**To size manually**, set `PHP_FPM_MAX_CHILDREN` (this pins the count and turns auto-tuning off),
or disable with `PHP_FPM_AUTOTUNE_PROFILE=""` and set the pool values explicitly:

| Variable | Fallback | Description |
|----------|---------|-------------|
| `PHP_FPM_PM` | `dynamic` | Process manager: `dynamic`, `static`, `ondemand` |
| `PHP_FPM_MAX_CHILDREN` | *(auto)* | Max concurrent child processes. Setting this pins sizing and disables auto-tuning. |
| `PHP_FPM_START_SERVERS` | `2` | Initial child count (dynamic mode) |
| `PHP_FPM_MIN_SPARE` | `1` | Min idle processes (dynamic mode) |
| `PHP_FPM_MAX_SPARE` | `6` | Max idle processes (dynamic mode) |
| `PHP_FPM_MAX_REQUESTS` | `500` | Requests per child before recycling (0 = unlimited) |
| `PHP_FPM_REQUEST_TERMINATE_TIMEOUT` | `60s` | Max request execution time before kill |

### Runtime PHP-FPM tuning (fpm-tune, cbox-init 3.1+)

The boot profile above is a **seed** — it sizes the pool once, before traffic.
cbox-init 3.1 embeds [fpm-tune](https://github.com/cboxdk/fpm-tune) as a runtime
loop: it measures live per-worker memory (PSS, which does not double-count shared
OPcache), and when the right size has moved it rewrites a pool drop-in
(`zz-fpm-tune.conf`) and reloads php-fpm gracefully with SIGUSR2 — never a
restart, the master PID stays. Every change is validated against a throwaway
copy, written atomically, and rolled back if the master does not come back.

| Variable | Default | Description |
|----------|---------|-------------|
| `CBOX_FPM_TUNE` | `false` | Enable the runtime tuner (`true`/`false`) |
| `CBOX_INIT_FPM_TUNE_ENABLED` | `false` | Same switch, long spelling |
| `CBOX_INIT_FPM_TUNE_MODE` | `apply` | `apply` = write drop-ins + reload; `advisory` = observe and recommend only |
| `CBOX_INIT_FPM_TUNE_INTERVAL` | `30s` | Measurement interval |
| `CBOX_INIT_FPM_TUNE_METRICS_ADDR` | *(empty)* | e.g. `:9110` to expose `fpm_tune_*` Prometheus metrics (worker PSS, budget, recommended vs configured workers) |

```yaml
# Example: runtime tuning on, with metrics
environment:
  CBOX_FPM_TUNE: "true"
  CBOX_INIT_FPM_TUNE_METRICS_ADDR: ":9110"
```

These map onto cbox-init's native `CBOX_INIT_GLOBAL_FPM_TUNE_*` overrides, which
also work directly and win over the `fpm_tune` block in cbox-init.yaml. Works in
both root and rootless variants. Do not run a separate standalone `fpm-tune`
daemon against the same pools — the embedded loop holds a lock on its state file.

**Reloads are connection-lossless.** php-fpm's graceful SIGUSR2 reload keeps the
listening socket open while workers respawn, so nginx needs no retry
configuration: measured on these images, 4,900+ requests (sequential and
saturated-concurrent) through 20 forced reloads produced zero non-200 responses.

### Live config reload

| Variable | Default | Description |
|----------|---------|-------------|
| `CBOX_INIT_WATCH` | `true` | Watch the generated config and reload changed processes **without a container restart**. |

Beyond watch mode, cbox-init exposes live process control over its Unix socket — no restart needed:

```bash
cbox-init reload-config          # re-read config from disk and apply
cbox-init scale queue-default 8  # change a worker's replica count
cbox-init restart horizon        # restart one supervised process
cbox-init start|stop <process>   # start/stop a daemon on the fly
```

This is how you run and manage standalone daemons (queue workers, scheduler, Horizon, Reverb, or
your own) — via cbox-init, with or without nginx/php-fpm (the `php-cli` tier ships the same
supervisor for daemon-only containers).

---

## Nginx Configuration

### Server Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `NGINX_HTTP_PORT` | `80` | HTTP port |
| `NGINX_HTTPS_PORT` | `443` | HTTPS port |
| `NGINX_WEBROOT` | `/var/www/html/public` | Document root |
| `NGINX_INDEX` | `index.php index.html` | Index files |
| `NGINX_SERVER_TOKENS` | `off` | Hide Nginx version |

### Client Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `NGINX_CLIENT_MAX_BODY_SIZE` | `100M` | Max request body |
| `NGINX_CLIENT_BODY_TIMEOUT` | `60s` | Body read timeout |
| `NGINX_CLIENT_HEADER_TIMEOUT` | `60s` | Header read timeout |

### Security Headers

**All security headers are fully configurable via environment variables.** Set to empty string to disable.

| Variable | Default | Description |
|----------|---------|-------------|
| `NGINX_HEADER_X_FRAME_OPTIONS` | `SAMEORIGIN` | Clickjacking protection |
| `NGINX_HEADER_X_CONTENT_TYPE_OPTIONS` | `nosniff` | MIME sniffing protection |
| `NGINX_HEADER_X_XSS_PROTECTION` | `1; mode=block` | XSS filter |
| `NGINX_HEADER_CSP` | *(see below)* | Content-Security-Policy |
| `NGINX_HEADER_REFERRER_POLICY` | `strict-origin-when-cross-origin` | Referrer information |
| `NGINX_HEADER_COOP` | *(disabled)* | Cross-Origin-Opener-Policy (opt-in) |
| `NGINX_HEADER_COEP` | *(disabled)* | Cross-Origin-Embedder-Policy (opt-in) |
| `NGINX_HEADER_CORP` | *(disabled)* | Cross-Origin-Resource-Policy (opt-in) |
| `NGINX_HEADER_PERMISSIONS_POLICY` | *(see below)* | Browser feature permissions |

**Default CSP:**
```
default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self'; frame-ancestors 'self'
```

**Default Permissions-Policy:**
```
accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=()
```

**Cross-Origin Isolation Headers (COOP/COEP/CORP):**

These headers are **disabled by default** because they break most applications that use:
- External APIs (payment gateways, analytics, social login)
- CDN resources (fonts, scripts, images)
- Third-party embeds (YouTube, maps, widgets)

**Enable for maximum security** (advanced use cases only):
```yaml
environment:
  - NGINX_HEADER_COOP=same-origin
  - NGINX_HEADER_COEP=require-corp
  - NGINX_HEADER_CORP=same-origin
```

**Disable a header** (set to empty):
```yaml
environment:
  - NGINX_HEADER_CSP=       # Disable Content-Security-Policy
```

See [Security Hardening](../security/security-hardening#content-security-policy) for customization examples.

### Gzip Compression

| Variable | Default | Description |
|----------|---------|-------------|
| `NGINX_GZIP` | `on` | Enable gzip (`on`/`off`) |
| `NGINX_GZIP_VARY` | `on` | Add Vary: Accept-Encoding |
| `NGINX_GZIP_PROXIED` | `any` | Compress proxied requests |
| `NGINX_GZIP_COMP_LEVEL` | `6` | Compression level (1-9) |
| `NGINX_GZIP_MIN_LENGTH` | `1000` | Min size to compress (bytes) |
| `NGINX_GZIP_TYPES` | *(see below)* | MIME types to compress |
| `NGINX_GZIP_STATIC` | `on` | Serve pre-compressed `.gz` files from disk (`on`/`off`) |

**Default gzip types:**
```
text/plain text/css text/xml text/javascript application/json application/javascript application/xml application/xml+rss application/x-javascript image/svg+xml
```

**Disable gzip:**
```yaml
environment:
  - NGINX_GZIP=off
```

**Pre-compressed assets** (`gzip_static`, enabled by default): when your build
pipeline emits `.gz` files next to the originals (Vite, Webpack, Rollup, and
esbuild all have plugins for this), nginx serves `app.css.gz` directly from disk
for a request to `app.css` — no per-request compression CPU at all. When no
`.gz` file exists, nginx falls back to dynamic gzip transparently.

### Brotli Compression

| Variable | Default | Description |
|----------|---------|-------------|
| `NGINX_BROTLI` | `on` | Enable brotli (`on`/`off`) |
| `NGINX_BROTLI_COMP_LEVEL` | `6` | Compression level (0-11) |
| `NGINX_BROTLI_TYPES` | *(mirrors `NGINX_GZIP_TYPES`)* | MIME types to compress |
| `NGINX_BROTLI_STATIC` | `on` | Serve pre-compressed `.br` files from disk (`on`/`off`) |

Brotli typically compresses 15-20% smaller than gzip at the same CPU budget and
is supported by every modern browser. The [ngx_brotli](https://github.com/google/ngx_brotli)
module is compiled into all `php-fpm-nginx` images (statically linked — no
extra runtime dependencies). Content negotiation is automatic: clients sending
`Accept-Encoding: br` get brotli, everyone else gets gzip.

**Pre-compressed `.br` assets** work exactly like `.gz` ones: emit them from
your build pipeline and nginx serves them straight from disk, preferring `.br`
over `.gz` when the client supports both.

### Open File Cache

| Variable | Default | Description |
|----------|---------|-------------|
| `NGINX_OPEN_FILE_CACHE` | `max=10000 inactive=20s` | Cache config (`off` to disable) |
| `NGINX_OPEN_FILE_CACHE_VALID` | `30s` | Cache validation interval |
| `NGINX_OPEN_FILE_CACHE_MIN_USES` | `2` | Min uses before caching |
| `NGINX_OPEN_FILE_CACHE_ERRORS` | `on` | Cache file errors |

**Disable file cache:**
```yaml
environment:
  - NGINX_OPEN_FILE_CACHE=off
```

### FastCGI Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `NGINX_FASTCGI_PASS` | `127.0.0.1:9000` | PHP-FPM address |
| `NGINX_FASTCGI_BUFFERS` | `8 8k` | FastCGI buffers |
| `NGINX_FASTCGI_BUFFER_SIZE` | `8k` | Buffer size |
| `NGINX_FASTCGI_BUSY_BUFFERS_SIZE` | `16k` | Busy buffers size |
| `NGINX_FASTCGI_CONNECT_TIMEOUT` | `60s` | Connect timeout |
| `NGINX_FASTCGI_SEND_TIMEOUT` | `60s` | Send timeout |
| `NGINX_FASTCGI_READ_TIMEOUT` | `60s` | Read timeout |

### Logging

| Variable | Default | Description |
|----------|---------|-------------|
| `NGINX_ACCESS_LOG` | `/var/log/nginx/access.log` | Access log path (`off` or `false` to disable) |
| `NGINX_LOG_FORMAT` | `combined` | Access log format: `combined`, `combined_no_query`, or `json` |
| `NGINX_ERROR_LOG` | `/var/log/nginx/error.log` | Error log path |
| `NGINX_ERROR_LOG_LEVEL` | `warn` | Error log level |

**Disable access logging** (reduces disk I/O in high-traffic scenarios):
```yaml
environment:
  - NGINX_ACCESS_LOG=false
  # or
  - NGINX_ACCESS_LOG=off
```

**Access log formats** (`NGINX_LOG_FORMAT`):

- `combined` (default) — nginx's standard format, full request line including
  query string. Unchanged for backwards compatibility.
- `combined_no_query` — same layout, but logs the path only. Query strings
  (magic-link tokens, OAuth `code=...` callbacks, search terms) never reach
  disk or downstream log shippers. The privacy/GDPR-friendly choice.
- `json` — structured logging for Loki, Datadog, ELK, and friends. Path only
  (no query string), plus timing fields for latency analysis.

Example log lines per format for `GET /index.php?token=SECRET`:

```
# combined
172.18.0.1 - - [26/Aug/2026:09:09:07 +0000] "GET /index.php?token=SECRET HTTP/1.1" 200 1024 "-" "curl/8.7.1"

# combined_no_query
172.18.0.1 - - [26/Aug/2026:09:09:07 +0000] "GET /index.php HTTP/1.1" 200 1024 "-" "curl/8.7.1"

# json
{"time":"2026-08-26T09:09:07+00:00","remote_addr":"172.18.0.1","method":"GET","path":"/index.php","status":200,"body_bytes_sent":1024,"request_time":0.127,"upstream_response_time":"0.127","referer":"","user_agent":"curl/8.7.1","host":"example.com"}
```

Custom formats remain possible by volume-mounting your own server config.

### Server Header

| Variable | Default | Description |
|----------|---------|-------------|
| `NGINX_SERVER_HEADER` | *(unset)* | Replace the `Server` response header, or `none` to remove it entirely |

The default `Server: nginx` (version hidden via `server_tokens off`) can be
rebranded or stripped — something plain `add_header` cannot do:

```yaml
environment:
  - NGINX_SERVER_HEADER=Acme API    # Server: Acme API
  # or
  - NGINX_SERVER_HEADER=none        # no Server header at all
```

This is powered by the [headers-more module](https://github.com/openresty/headers-more-nginx-module),
which is loaded in all `php-fpm-nginx` images. Custom configs mounted into
`/etc/nginx/conf.d/` can therefore also use `more_set_headers` /
`more_clear_headers` directly, e.g. to strip noisy upstream headers.

### Static Files

| Variable | Default | Description |
|----------|---------|-------------|
| `NGINX_STATIC_EXPIRES` | `1y` | Static file cache duration |
| `NGINX_STATIC_CACHE_CONTROL` | `public, immutable` | Cache-Control header |
| `NGINX_STATIC_ACCESS_LOG` | `off` | Static file access logging |
| `NGINX_TRY_FILES` | `/index.php?$query_string` | try_files fallback |

---

## Reverse Proxy Configuration

Configure Cbox to run behind Cloudflare, HAProxy, Traefik, Nginx, Fastly, Tailscale, or other reverse proxies.

| Variable | Default | Description |
|----------|---------|-------------|
| `NGINX_TRUSTED_PROXIES` | *(empty)* | Space-separated list of trusted proxy IPs/CIDRs |
| `NGINX_REAL_IP_HEADER` | `X-Forwarded-For` | Header containing real client IP |
| `NGINX_REAL_IP_RECURSIVE` | `on` | Recursive IP extraction from proxy chain |

### Common Proxy Configurations

```yaml
# Docker/Kubernetes internal networks
NGINX_TRUSTED_PROXIES: "10.0.0.0/8 172.16.0.0/12 192.168.0.0/16"

# Cloudflare
NGINX_TRUSTED_PROXIES: "173.245.48.0/20 103.21.244.0/22 ..."
NGINX_REAL_IP_HEADER: "CF-Connecting-IP"

# Tailscale
NGINX_TRUSTED_PROXIES: "100.64.0.0/10"

# Traefik/HAProxy (Docker network)
NGINX_TRUSTED_PROXIES: "172.16.0.0/12"
```

### Headers Forwarded to PHP

When proxies are configured, these headers are available in PHP:

| PHP Variable | Description |
|--------------|-------------|
| `$_SERVER['REMOTE_ADDR']` | Real client IP (after proxy extraction) |
| `$_SERVER['HTTP_X_FORWARDED_FOR']` | Full proxy chain |
| `$_SERVER['HTTP_X_FORWARDED_PROTO']` | Original protocol (http/https) |
| `$_SERVER['HTTP_X_FORWARDED_HOST']` | Original hostname |
| `$_SERVER['HTTP_X_REAL_IP']` | Real client IP |

See [Reverse Proxy & mTLS Guide](../security/reverse-proxy-mtls) for detailed setup.

---

## SSL Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `SSL_MODE` | `off` | SSL mode: `off`, `on`, `full` |
| `SSL_CERTIFICATE_FILE` | `/etc/ssl/certs/cbox-selfsigned.crt` | Certificate path |
| `SSL_PRIVATE_KEY_FILE` | `/etc/ssl/private/cbox-selfsigned.key` | Private key path |
| `SSL_PROTOCOLS` | `TLSv1.2 TLSv1.3` | SSL protocols |
| `SSL_CIPHERS` | `HIGH:!aNULL:!MD5` | SSL ciphers |
| `SSL_HSTS_HEADER` | `max-age=31536000; includeSubDomains` | HSTS header value |

### SSL Modes

- `off` - HTTP only
- `on` - HTTPS enabled (HTTP still available)
- `full` - HTTPS with HTTP to HTTPS redirect

---

## mTLS (Mutual TLS) Configuration

Enable client certificate authentication for zero-trust networks, service mesh, or API authentication.

| Variable | Default | Description |
|----------|---------|-------------|
| `MTLS_ENABLED` | `false` | Enable mTLS client verification |
| `MTLS_CLIENT_CA_FILE` | `/etc/ssl/certs/client-ca.crt` | CA certificate for client verification |
| `MTLS_VERIFY_CLIENT` | `optional` | `optional`, `on` (required), or `optional_no_ca` |
| `MTLS_VERIFY_DEPTH` | `2` | Maximum certificate chain depth |

### mTLS Client Info in PHP

When mTLS is enabled, client certificate details are available:

| PHP Variable | Description |
|--------------|-------------|
| `$_SERVER['SSL_CLIENT_VERIFY']` | `SUCCESS`, `FAILED`, or `NONE` |
| `$_SERVER['SSL_CLIENT_S_DN']` | Client subject DN (e.g., `/CN=service-name`) |
| `$_SERVER['SSL_CLIENT_I_DN']` | Client issuer DN |
| `$_SERVER['SSL_CLIENT_SERIAL']` | Certificate serial number |
| `$_SERVER['SSL_CLIENT_FINGERPRINT']` | Certificate fingerprint |

### Example mTLS Setup

```yaml
services:
  app:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm
    environment:
      SSL_MODE: "on"
      MTLS_ENABLED: "true"
      MTLS_VERIFY_CLIENT: "optional"
    volumes:
      - ./certs/client-ca.crt:/etc/ssl/certs/client-ca.crt:ro
      - ./certs/server.crt:/etc/ssl/certs/cbox-selfsigned.crt:ro
      - ./certs/server.key:/etc/ssl/private/cbox-selfsigned.key:ro
```

See [Reverse Proxy & mTLS Guide](../security/reverse-proxy-mtls#mtls-mutual-tls-client-authentication) for complete setup.

---

---

## Laravel .env Decryption

Automatically decrypt `.env.encrypted` files at container startup.

| Variable | Default | Description |
|----------|---------|-------------|
| `LARAVEL_ENV_ENCRYPTION_KEY` | *(empty)* | Decryption key (e.g., `base64:xxx`) |
| `LARAVEL_ENV_ENCRYPTION_KEY_FILE` | *(empty)* | Path to file containing decryption key |
| `LARAVEL_ENV_FORCE_DECRYPT` | `false` | Overwrite existing `.env` file |

**Using environment variable:**
```yaml
environment:
  - LARAVEL_ENV_ENCRYPTION_KEY=base64:your-encryption-key-here
```

**Using Docker secrets:**
```yaml
environment:
  - LARAVEL_ENV_ENCRYPTION_KEY_FILE=/run/secrets/laravel_env_key
secrets:
  - laravel_env_key
```

---

## Cbox Init Management API

The Management API provides runtime control over container processes. It is **disabled by default** for security.

| Variable | Default | Description |
|----------|---------|-------------|
| `CBOX_INIT_API_ENABLED` | `false` | Enable the Management API |
| `CBOX_INIT_API_HOST` | `127.0.0.1` | API bind address. Loopback-only by default (cbox-init 3.0+); set `0.0.0.0` + `CBOX_INIT_API_AUTH` to reach it via a published port |
| `CBOX_INIT_API_PORT` | `9180` | Port the API listens on |
| `CBOX_INIT_API_AUTH` | *(empty)* | Bearer token for API authentication |

```yaml
services:
  app:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm
    ports:
      - "9180:9180"
    environment:
      CBOX_INIT_API_ENABLED: "true"
      CBOX_INIT_API_AUTH: "my-secret"
```

See [Cbox Init Integration](../observability/cbox-init-integration#-management-api) for endpoints, CLI commands, and examples.

---

## Cbox Init Global Config

| Variable | Default | Description |
|----------|---------|-------------|
| `CBOX_INIT_METRICS_ENABLED` | `true` | Enable Prometheus metrics endpoint |
| `CBOX_INIT_METRICS_PORT` | `9090` | Metrics endpoint port |
| `CBOX_INIT_LOG_LEVEL` | `info` | Log level: `debug`, `info`, `warn`, `error` |
| `CBOX_INIT_LOG_FORMAT` | `json` | Log format: `json`, `text` |
| `CBOX_INIT_SHUTDOWN_TIMEOUT` | `30` | Seconds to wait for graceful process shutdown |
| `CBOX_INIT_CONFIG` | `/etc/cbox-init/cbox-init.yaml` | Path to cbox-init config file |

---

## Application Warmup Hooks (cbox-init 3.0+)

Run app-specific pre-flight work — Statamic `stache:warm`, Symfony
`cache:warmup`, custom seeding — **before** the services start and health
checks begin succeeding. Hooks are executed by cbox-init itself: supervised,
with a timeout, and logged with structured fields (name, duration, exit code).

Define hooks entirely via environment variables, no YAML mount needed:

```
CBOX_INIT_HOOK_PRE_START_<N>_NAME           # Optional (defaults to pre-start-<N>)
CBOX_INIT_HOOK_PRE_START_<N>_COMMAND        # Required, comma-separated argv or JSON array
CBOX_INIT_HOOK_PRE_START_<N>_TIMEOUT        # Seconds
CBOX_INIT_HOOK_PRE_START_<N>_ALLOW_FAILURE  # true = log the failure, continue startup
```

```yaml
# Example: Statamic stache warm + best-effort event cache
environment:
  CBOX_INIT_HOOK_PRE_START_0_NAME: "stache-warm"
  CBOX_INIT_HOOK_PRE_START_0_COMMAND: "php,please,stache:warm"
  CBOX_INIT_HOOK_PRE_START_0_TIMEOUT: "300"
  CBOX_INIT_HOOK_PRE_START_1_COMMAND: "php,artisan,event:cache"
  CBOX_INIT_HOOK_PRE_START_1_ALLOW_FAILURE: "true"
```

Notes:

- A hook that fails (or times out) **aborts container startup** unless
  `ALLOW_FAILURE` is `true` — right for migrations, opt out for best-effort
  warmup (a cold cache is degraded, not down).
- For a full shell line, wrap it: `COMMAND: "/bin/sh,-c,php please stache:warm && php please static:warm"`.
- Hooks needing the web server up (HTTP-based warming) belong in
  `hooks.post-start` in a mounted cbox-init.yaml instead.
- Simpler alternative for scripts: drop a `*.sh` file into
  `/docker-entrypoint-init.d/` — it runs before cbox-init starts, but without
  cbox-init's supervision, timeout, or structured logging.

---

## Development (Dev Images Only)

| Variable | Default | Description |
|----------|---------|-------------|
| `XDEBUG_MODE` | `off` | Xdebug mode: `debug`, `develop`, `coverage`, `profile`, or comma-separated |
| `XDEBUG_CONFIG` | *(empty)* | Xdebug config string (e.g., `client_host=host.docker.internal client_port=9003`) |
| `PHP_IDE_CONFIG` | *(empty)* | IDE server mapping (e.g., `serverName=docker`) |

```yaml
# Example: Enable step debugging
environment:
  XDEBUG_MODE: "debug"
  XDEBUG_CONFIG: "client_host=host.docker.internal client_port=9003"
  PHP_IDE_CONFIG: "serverName=docker"
```

---

## Other Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `WORKDIR` | `/var/www/html` | Working directory |
| `CBOX_INIT_CONFIG` | `/etc/cbox-init/cbox-init.yaml` | Cbox Init config path |
| `REVERB_PORT` | `8080` | Reverb port for healthcheck (override if using non-default port) |

---

## Example Configurations

### Development

```yaml
environment:
  - PUID=1000
  - PGID=1000
  - PHP_DISPLAY_ERRORS=On
  - PHP_OPCACHE_VALIDATE_TIMESTAMPS=1
```

### Production Laravel

```yaml
environment:
  - PUID=1000
  - PGID=1000
  - LARAVEL_SCHEDULER=true
  - PHP_MEMORY_LIMIT=512M
```

### High-Traffic API

```yaml
environment:
  - PHP_MEMORY_LIMIT=1G
  - PHP_MAX_EXECUTION_TIME=120
  - NGINX_FASTCGI_READ_TIMEOUT=120s
  - LARAVEL_QUEUE=true
```

### Laravel with Horizon

```yaml
environment:
  - LARAVEL_HORIZON=true
  - LARAVEL_SCHEDULER=true
```

### Laravel with Reverb (WebSockets)

```yaml
environment:
  - LARAVEL_REVERB=true
ports:
  - "8000:80"
  - "8080:8080"
```
