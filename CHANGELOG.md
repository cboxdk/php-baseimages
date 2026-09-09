# Changelog

All notable changes to Cbox PHP Base Images.

## [Unreleased]

### Added
- **Benchmarks page in the docs** - the measured scaling proof against the field (ServerSideUp, webdevops, trafex, DIY vanilla, Apache, FrankenPHP): static worker defaults lose throughput when the container grows (DIY 0.82x hello going 2c->4c with its pm.max_children=5 default), while these images size from real limits at boot and correct from live measurements (1.7-2.1x). See docs/reference/benchmarks.md
- **Process-manager modes as first-class envs** - `PHP_FPM_PM=dynamic|ondemand|static` (default dynamic, unchanged behavior). ondemand spawns workers per burst and lets idle ones die (`PHP_FPM_PROCESS_IDLE_TIMEOUT`, default 10s) - the right shape for bursty/low-traffic pods, and what trafex ships as its default. Mode-specific directives are written as a drop-in so no mode boots with another mode's directives; fpm-tune is already mode-aware upstream (resizes only max_children for non-dynamic pools, and its advice engine flags mode/workload mismatches). Completed the pm env surface while at it: `PHP_FPM_MAX_SPAWN_RATE` (32), `PHP_FPM_LISTEN_BACKLOG` (511), and `PHP_FPM_REQUEST_TERMINATE_TIMEOUT`/`PHP_FPM_REQUEST_SLOWLOG_TIMEOUT` now actually drive the pool (previously hardcoded 60s/5s while the docs promised the env)
- **Unix-socket transport for the nginx->FPM hop** - `PHP_FPM_LISTEN=unix` serves FastCGI over a unix socket instead of TCP loopback: measured ~+23% PHP requests/second on the same hardware. TCP stays the default (`PHP_FPM_LISTEN=tcp`) because both have real use cases - sockets for single-container throughput, TCP for anything that reaches FPM from outside the container. nginx, the health probe (exec socket check), fpm-exporter autodiscovery and fpm-tune all follow the transport automatically; `PHP_FPM_SOCKET_PATH` overrides the location; works in root and rootless (rootless images now ship a writable `/run/php`)

## [1.3.0] - 2026-09-09

### Added
- **cbox-init 3.3.0 with fpm-tune v1.1.0** - a pool that queues while the host's CPU is full is now HELD at its current size instead of grown ([cboxdk/fpm-tune#15](https://github.com/cboxdk/fpm-tune/pull/15)): CBOX_FPM_TUNE no longer trades CPU-bound throughput (measured -16% before) for workers no core can run. Verified end-to-end on the benchmark harness: 90s saturated CPU load, pool steady at its size, throughput equal to the untuned default (363 vs 360 rps). Also exposes `fpm_tune.cpu_ceiling`/`cpu_headroom` (init#142) for CPU-bound pools with >=50ms requests

### Changed
- **Extension bumps from the first working weekly PR** - apcu 5.1.28, mongodb 2.5.2, msgpack 3.0.1, xdebug 3.5.3, uuid 1.3.0, excimer 1.2.6 (all verified on PECL)

### Fixed
- **Weekly update automation hardened after its first live run** - the workflow committed its own log files into the PR (outputs now live in runner temp and the PR only adds versions.json), and the Node.js fetcher wrote a bare major ("24") that would break the image build while silently jumping LTS lines - it now tracks patches on the current LTS line and warns when a newer LTS exists
- **Cold start 6.2s → 1.3s** - benchmarking against the field exposed that container start was dominated by cbox-init's silent 5s `initial_delay` default before the FIRST health probe (php-fpm listens ~50ms after start; nginx waited out the delay on the dependency chain). Fixed upstream (no `initial_delay` default + 100ms fast-start probing until first success, failure semantics unchanged - [cboxdk/init#143](https://github.com/cboxdk/init/pull/143)), and the entrypoint no longer runs a redundant pre-flight check-config (serve validates the rendered config with better errors). Measured: dependency gate 4.95s → 0.20s, whole-container start → first HTTP 200 median 6.15s → 1.26s

## [1.2.1] - 2026-09-08

### Fixed
- **Repo-root CHANGELOG.md brought back in sync** - GitHub renders the root file, but releases were only ever stamped in docs/changelog.md, so visitors saw a changelog frozen at the pre-1.0 April state. The root file now carries the full release history (pre-1.0 development history preserved at the bottom) and a lint gate fails any future drift
- **Stray cbox.com references corrected to cbox.dk** - documentation-standards guides, the observability README, the Grafana dashboard help link, and a template maintainer label pointed at a domain that is not ours
- **SBOMs made visible** - the SPDX SBOM attestations were always on the images but practically undiscoverable: SECURITY.md now shows the exact one-liner to extract the SBOM and provenance from any public image, and GitHub releases carry the default-PHP images' SBOMs as downloadable assets (added retroactively to v1.2.0)


## [1.2.0] - 2026-09-07

### Added
- **One scrape, one story: cbox-init 3.2.0** - the main `:9090` metrics endpoint now carries the whole container's telemetry. `fpm_tune_*` rides on it natively while the tuner runs, and `CBOX_FPM_EXPORTER=true` also folds `phpfpm_*`/`laravel_*` in via the new `metrics_federate` (activated by the entrypoint only when the exporter is enabled, so a disabled exporter never emits a permanent `cbox_init_federate_up 0`; a source that is down degrades to `up 0`, never a failed scrape). cbox-init 3.2.0 also fixes Symfony framework detection on fresh deploys ([cboxdk/init#137](https://github.com/cboxdk/init/pull/137)) - detection required the `var/cache` directory that permission setup itself creates, so fresh Symfony apps never got their cache directory; verified end-to-end by the Symfony E2E scenario going green
- **PHP-FPM metrics exporter dogfooded** - [cboxdk/fpm-exporter](https://github.com/cboxdk/fpm-exporter) v3.1.1 ships in every image as a disabled-by-default supervised process (`CBOX_FPM_EXPORTER=true`). Exposes `phpfpm_*` + Laravel metrics on :9114 via FastCGI pool autodiscovery - `listen_queue` and worker saturation are the horizontal-scaling signals the stack was missing (fpm-tune covers the vertical axis). Binaries verified against sha256 pins in versions.json (upstream publishes no checksums yet). Verified end-to-end in root and rootless: supervised with depends_on php-fpm, disabled default leaves no listener

### Fixed
- **E2E suite made trustworthy end-to-end** - a deep local run exposed that most "failures" were suite bugs masking each other: scenarios only cleaned up on success, so one failure leaked its containers and the shared ports (8090-8096) sank every later scenario; 32 `VAR=$(docker exec ...)` substitutions could kill scenarios mid-run under `set -e`; the pest fixture shipped three genuinely failing architecture tests and referenced a custom-expectation test that did not exist; the magento fixture's OpenSearch 2.15 refused to start (post-2.12 admin-password requirement); the rootless fixture mounted `public/` one level too high so every request 404'd; and the rootless scenario asserted a pre-Docker-20.10 kernel behavior (unprivileged port-80 bind refusal). The runner now guarantees teardown after every scenario, skips chromium-only scenarios on images without Chromium, and runs the rootless scenario against `ROOTLESS_IMAGE` when provided. Full suite is green locally: 17 passed, 2 tier-skips on the standard image, chromium pair green against the chromium tier
- **Symfony framework detection aligned with cbox-init fix** - shell-side `detect_framework()` required `symfony.lock`, missing non-Flex apps; it now also accepts a `symfony/framework-bundle` composer dependency, and `fix_symfony_permissions()` creates `var/cache`/`var/log` instead of skipping them when absent (mirrors [cboxdk/init#137](https://github.com/cboxdk/init/pull/137), where the same chicken-and-egg bug prevented fresh Symfony deploys from ever getting their cache directory)
- **Parent-image packages now receive security upgrades too** - upstream php/nginx images ship packages our `apt-get install` never touches (install does not upgrade unrelated preinstalled packages; libssh2 via curl was the caught case - the CVE gate refused promotion three cascades in a row). The weekly cache-refresh layer now runs `apt-get upgrade` against bookworm-security, making the weekly-patch promise hold for every package in the image, not only the ones we install
- **Weekly security rebuilds now actually refresh packages** - the CI layer cache had no cache busting, so a scheduled rebuild replayed cached apt layers whenever nothing else invalidated them: the "rebuilt weekly with security patches" promise only held when upstream PHP happened to push a new digest. Exposed by the pre-promotion CVE gate catching a libssh2 fix already published in bookworm-security that a fresh build did not contain. Root stages now take an ISO-week CACHE_REFRESH build-arg: scheduled rebuilds bust once per week, intra-week pushes keep full cache speed

### Changed
- **Default PHP version is now 8.5** - `php.default`, every Dockerfile's `ARG PHP_VERSION` default, docker-compose, and 260+ documentation/template/example references moved from 8.4 to 8.5. Version-matrix enumerations keep listing all supported versions. `latest` already followed 8.5

## [1.1.1] - 2026-09-07

### Fixed
- **Docs, templates and examples now use the release channel tag** - v1.1.0 introduced `-v1` channel tags but 250+ image references across the documentation, Dockerfile templates and example stacks still showed rolling tags. Every example now pins `-v1` (the recommended production pin), the tag-format references document the `[-vN]` dimension, and Available Images explains all three tag kinds
- **Stray root Dockerfile relocated** - an app template (Statamic/Laravel + Vite with composer-auth build secrets) sat at the repository root referencing a non-existent private tag; now lives at `templates/Dockerfile.statamic` with correct channel tags

## [1.1.0] - 2026-09-05

### Added
- **Digest promotion** - production tags now move only AFTER verification: the CVE regression gate and the per-image smoke test run against the pushed-by-digest image, and a failure leaves every tag pointing at the previous good image. Attestations carry over unchanged (promotion is a pure manifest operation)
- **SECURITY.md** - honest security policy: private vulnerability reporting via GitHub, the weekly-rebuild patch model, signature/attestation verification, and the supported-versions policy
- **Release channel tags (`-vN`)** - e.g. `8.4-bookworm-v1`: rebuilt weekly with OS security patches, but never crossing a tooling major. The recommended production pin: stable behavior without CVE rot. Rolling tags keep following the latest release; SHA/digest tags remain the immutable option. Channel comes from `release.channel` in versions.json; previous majors stay supported for 6 months after a new major (see docs/reference/tagging-strategy.md)
- **SLSA provenance + SPDX SBOM attestations** on every image (BuildKit `mode=max`; verified to survive the multi-arch manifest merge). Inspect with `docker buildx imagetools inspect --format '{{ json .Provenance }}'`
- **Trivy regression gate** - builds now FAIL on any new fixable CRITICAL/HIGH CVE not in the triaged `.trivyignore` baseline (84 pre-existing entries, each annotated with its fix path). Full unfiltered scans still go to the Security tab

### Fixed
- **Lifecycle banners now work in php-fpm and php-fpm-nginx** - these images COPY from php-base instead of building FROM it, so the baked lifecycle ENV never reached them and deprecation/EOL banners could only ever fire in php-cli. The lifecycle ARG/ENV block is now declared in both Dockerfiles (CI already passed the build-args). Verified: deprecated shows the banner, security-only and stable stay silent
- **PHP lifecycle data corrected** - `versions.json` carried pre-2022-policy EOL dates (e.g. 8.2: 2025-12-08; actual security support runs to 2026-12-31), so images showed FALSE deprecation banners for 8.2/8.3. Now modeled as `active_support_until` + `security_support_until` (php.net verified); a new `security-only` lifecycle state is banner-free (it is a normal, supported phase), and warnings key off security EOL
- **Weekly version automation repaired** - the update script died silently every week on a dead pre-rebrand endpoint (`gophpeek/phpeek-pm`) before writing its result, masked by `|| true`; it also tried to re-add removed swoole/frankenphp keys and skipped PHP 8.5 in patch checks. `latest_patch` and `_meta` are current again
- **`latest` tag concept clarified** - `latest` now follows `php.newest` (8.5) from versions.json instead of a hardcoded workflow default (8.4); `php.default` (8.4) remains the documented recommendation. Docs and CI agree again
- **ServerSideUp comparison page rewritten** - previous version claimed ServerSideUp lacks health checks (they ship native health checks); now an honest comparison verified against their current docs

## [1.0.0] - 2026-09-05

### Breaking Changes
- **OS Variant Simplification** - Only Debian 12 (Bookworm) is now supported
  - Removed Alpine variant
  - Removed Debian 13 (Trixie) variant
  - Removed Ubuntu variant (FrankenPHP, Swoole, OpenSwoole)
  - All images now based on Debian 12 (Bookworm) with glibc

### Migration from Alpine/Trixie

**Tag changes:**
```yaml
# OLD (Alpine)
image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-alpine

# NEW (Bookworm)
image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm
```

**Why this change?**
- Simplified maintenance and testing
- Better glibc compatibility for all extensions
- Consistent behavior across all deployments
- Focus on stability over variety

**Custom extension installation:**
```dockerfile
# OLD (Alpine)
RUN apk add --no-cache package-name

# NEW (Bookworm)
RUN apt-get update && apt-get install -y package-name && rm -rf /var/lib/apt/lists/*
```

### Added
- **Cbox Init v3.1.2 with runtime PHP-FPM tuning (fpm-tune)** - measures live per-worker memory (PSS) and resizes the pool via an atomic drop-in + graceful SIGUSR2 reload (master PID unchanged, zero dropped connections - verified under saturated load through 20 reloads). Off by default; enable with `CBOX_FPM_TUNE=true` (`CBOX_INIT_FPM_TUNE_MODE/INTERVAL/METRICS_ADDR` for mode, cadence and Prometheus metrics). Works in root and rootless variants
- **Small-container crash-loop fixed** - the published 3.0.0 images crash-looped every container under ~512MB at boot (the boot autotune exited PID 1 when the default `medium` profile did not fit the memory limit). Fixed upstream in cbox-init 3.1.2 (cboxdk/init#133): the calculator now clamps with a warning and boots; `PHP_FPM_AUTOTUNE_STRICT=1` restores fail-hard for deploy-time checks. Verified: 128MB and 256MB containers boot and serve with defaults
- **Cbox Init v3.0.0** - env-defined lifecycle hooks, full init signal plane, hardened API
  - Application warmup hooks via env vars (`CBOX_INIT_HOOK_PRE_START_<N>_COMMAND`, `_TIMEOUT`, `_ALLOW_FAILURE`) - run supervised pre-flight work (Statamic stache warm, Symfony cache warmup) before health checks start succeeding
  - `SIGHUP` reloads config; `SIGUSR1`/`SIGUSR2` forwarded to all managed process groups (`docker kill -s USR2` = php-fpm graceful reload)
  - Per-process signal action via CLI/API (e.g. nginx config reload without touching the stack)
  - Management API now binds loopback-only by default (plus Unix socket); new `CBOX_INIT_API_HOST` env var (set `0.0.0.0` + `CBOX_INIT_API_AUTH` to expose via a published port) - **breaking** if you previously published port 9180
  - REST log endpoints renamed fields to match the SSE stream (`timestamp`, `process`, `instance`) - **breaking** for API log consumers
  - Strict config validation: unknown YAML keys are rejected at load (shipped configs validated)
- **Brotli compression** in all php-fpm-nginx tiers - ngx_brotli compiled against Debian's exact nginx, statically linked. On by default (`NGINX_BROTLI`, `NGINX_BROTLI_COMP_LEVEL`, `NGINX_BROTLI_TYPES`, `NGINX_BROTLI_STATIC`); pre-compressed `.br` assets served straight from disk
- **headers-more nginx module** in all php-fpm-nginx tiers; `NGINX_SERVER_HEADER` rebrands the Server header (`none` removes it)
- **`NGINX_LOG_FORMAT`** - `combined` (default), `combined_no_query` (privacy: no query strings on disk), `json` (structured)
- **`gzip_static on`** by default (`NGINX_GZIP_STATIC`) - pre-compressed `.gz` assets served straight from disk
- PHP 8.5 support
- Laravel Reverb WebSocket support (`LARAVEL_REVERB=true`)
- mTLS client certificate authentication
- Reverse proxy support (Cloudflare, Traefik, HAProxy)
- **Cbox Init v2.1.0** - CLI commands, log file tailing, API authentication
  - CLI commands via Unix socket: `list`, `status`, `start`, `stop`, `restart`, `scale`, `logs -f`, `reload-config`
  - Log file tailing with JSON parsing and size-based rotation (Laravel log tailed by default)
  - SSE log streaming (`/api/v1/logs/stream` and `cbox-init logs -f`)
  - Bearer token authentication for Management API (`CBOX_INIT_API_AUTH`)
  - New API endpoints: `start`, `stop`, `health`, `logs/stream`
- Environment variable overrides for cbox-init global config (`CBOX_INIT_API_ENABLED`, `CBOX_INIT_API_PORT`, `CBOX_INIT_API_AUTH`, `CBOX_INIT_METRICS_ENABLED`, `CBOX_INIT_METRICS_PORT`, `CBOX_INIT_LOG_LEVEL`, `CBOX_INIT_LOG_FORMAT`)

---

## [2024.12] - December 2024

### Added
- **4-Tier Image System** - Slim, Standard, Chromium, Dev tiers for different use cases
  - **Slim** (~120 MiB): Core extensions, APIs/microservices
  - **Standard** (~250 MiB): + ImageMagick, vips, Node.js 22 (DEFAULT)
  - **Chromium** (~700 MiB): + Chromium for Browsershot/Dusk
  - **Dev** (~750 MiB): + Xdebug, PCOV, SPX for local development
- **gRPC extension** - Added to all tiers
- **Rootless variants** - All tiers support `-rootless` suffix
- New tag format: `{type}:{php-version}-{os}[-tier][-rootless]`

### Changed
- Renamed "Minimal" edition to "Slim" tier
- Renamed "Full" edition to "Standard" tier (now the default)
- New "Chromium" tier includes Chromium (previously separate)
- Tag format changed from `-minimal` suffix to `-slim` suffix
- Standard tier is now the default (no suffix)

### Migration Guide

**Tag format changes:**
```yaml
# OLD (2024.11)
image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm           # Full edition
image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-minimal   # Minimal edition

# NEW (2024.12)
image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm           # Standard tier (default)
image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-slim      # Slim tier
image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-chromium  # Chromium tier (with Chromium)
```

**Tier selection guide:**
| Old Tag | New Tag | When to Use |
|---------|---------|-------------|
| `8.4-bookworm` | `8.4-bookworm` | Most apps (Standard is default) |
| `8.4-bookworm-minimal` | `8.4-bookworm-slim` | APIs, microservices |
| N/A | `8.4-bookworm-chromium` | Browsershot, Dusk, PDF |
| N/A | `8.4-bookworm-dev` | Local development (Xdebug, PCOV, SPX) |

---

## [2024.11] - November 2024

### Added
- **Cbox Init** - Go-based process manager replacing bash scripts
- Laravel Horizon support (`LARAVEL_HORIZON=true`)
- Queue worker scaling (`CBOX_INIT_PROCESS_QUEUE_DEFAULT_SCALE`)
- JSON structured logging
- Graceful shutdown handling

### Changed
- Entrypoint rewritten in Go for better performance
- Health checks now include process monitoring
- Default PHP memory limit: 256M → 512M

### Security
- Weekly automated rebuilds for security patches
- Trivy CVE scanning in CI/CD
- Non-root container support

---

## [2024.10] - October 2024

### Added
- PHP 8.4 GA support
- Debian Trixie (testing) variant
- SPX Profiler in dev images
- Multi-architecture builds (amd64/arm64)

### Changed
- Base images updated to Alpine 3.20, Debian 12.7
- OPcache JIT enabled by default
- Redis extension updated to 6.0.2

---

## [2024.09] - September 2024

### Added
- Minimal edition (`-minimal` suffix) - now Slim tier
- Development edition (`-dev` suffix) with Xdebug
- Framework auto-detection (Laravel, Symfony, WordPress)
- Automatic permission fixes

### Changed
- Nginx security headers enabled by default
- PHP-FPM dynamic process management

---

## Upgrade Guide

### From 2024.11 to 2024.12 (Tier System)

**Step 1: Identify your current usage**

| If you used... | You need... |
|----------------|-------------|
| `8.4-bookworm` (Full edition) | `8.4-bookworm` (Standard tier) - same tag! |
| `8.4-bookworm-minimal` | `8.4-bookworm-slim` |
| Browsershot/Dusk | `8.4-bookworm-chromium` |

**Step 2: Update your docker-compose.yml**

```yaml
# Most apps - no change needed!
image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm

# For Browsershot/Dusk users - use Chromium tier
image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-chromium

# For API/microservices - use Slim tier
image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-slim
```

### From bash-based entrypoint to Cbox Init

**Before (v2024.09)**:
```yaml
environment:
  - LARAVEL_SCHEDULER_ENABLED=true
```

**After (v2024.11)**:
```yaml
environment:
  - LARAVEL_SCHEDULER=true  # Simplified naming
```

### Environment variable changes

| Old Variable | New Variable |
|--------------|--------------|
| `LARAVEL_SCHEDULER_ENABLED` | `LARAVEL_SCHEDULER` |
| `LARAVEL_AUTO_OPTIMIZE` | `LARAVEL_OPTIMIZE_ENABLED` |
| `LARAVEL_AUTO_MIGRATE` | `LARAVEL_MIGRATE_ENABLED` |

---

## Security Updates

Cbox images are rebuilt weekly (Mondays 03:00 UTC) with latest security patches.

**To get updates**:
```bash
docker compose pull
docker compose up -d
```

**Check current version**:
```bash
docker compose exec app cat /etc/cbox-version
```

---

## Reporting Issues

- **Bugs**: [GitHub Issues](https://github.com/cboxdk/php-baseimages/issues)
- **Security**: See [SECURITY.md](https://github.com/cboxdk/php-baseimages/blob/main/SECURITY.md)
- **Questions**: [GitHub Discussions](https://github.com/cboxdk/php-baseimages/discussions)

---

## Pre-1.0 development history

Everything below predates the v1.0.0 release and the release-channel model.

## 2026-04-04

### Breaking Changes
- **Tier renamed: `full` → `chromium`** — Docker tags change from `-full` to `-chromium` (e.g., `8.4-bookworm-chromium`). The "full" name implied other tiers were incomplete; "chromium" is honest about what the extra 450MB adds.
- **Slim tier resized** — mongodb, soap, ldap, xsl, grpc, calendar, gettext, and System V IPC extensions moved from slim to standard. Slim is now truly minimal (~15 core extensions). If you use these extensions with slim, switch to standard.
- **igbinary removed** — Abandoned upstream, unable to keep up with PHP releases. Redis falls back to PHP's native serializer. Users with `Redis::SERIALIZER_IGBINARY` must switch to `Redis::SERIALIZER_PHP` or `Redis::SERIALIZER_MSGPACK`.
- **Migration failure now exits by default** — `LARAVEL_MIGRATE_ENABLED=true` will exit 1 on failure instead of continuing. Set `LARAVEL_MIGRATE_ALLOW_FAILURE=true` to restore the old behavior.

### Added
- **Custom command support** — `docker run myimage php artisan migrate` now works. Entrypoint runs setup (permissions, framework detection) then execs the command directly, without starting the process manager.
- **Reusable CI workflow** — `_build-image.yml` encapsulates the entire build-scan-test pipeline. Workflow YAML reduced from 3,976 to 1,610 lines (59% reduction).
- **Build dependency chain** — `workflow_run` triggers ensure base → fpm → fpm-nginx builds in correct order (no more relying on staggered cron times).
- **Binary download script** — `scripts/download-cbox-init.sh` downloads Cbox Init binaries for local development. Binaries removed from git (saves 35MB in repo).
- Ready-to-use Dockerfile templates (Node.js, Development, CI/CD)
- Rootless container documentation
- Development environment with Xdebug + SPX profiler

### Changed
- **Rebranded to "Cbox PHP Base Images"** — consistent naming across all docs, README, and CLAUDE.md
- **Docker image layer optimization** — Cbox Init binary no longer leaves dead layers (~17MB saved per image via multi-stage scratch approach)
- **php-fpm Dockerfile dedup** — Shared dependency stages eliminate 8x apt-get duplication (491 → 381 lines per Dockerfile)
- **Entrypoint function dedup** — Removed duplicate functions, consolidated with shared library
- **Reverb port in rootless mode** — Changed from 8080 to 6001 to avoid conflict with rootless Nginx
- **CI timeout** — Reduced from 8 hours (Alpine-era leftover) to 90 minutes
- Redis extension updated to 6.3.0 for PHP 8.4 compatibility
- APCu extension updated to 5.1.27 for PHP 8.4
- IMAP extension removed from PHP 8.4 (deprecated by PHP core)
- Cleaned 30+ stale Alpine references from CI and docs

### Documentation
- **Major docs refactor** — 48 → 41 files, 17k → 12.8k lines
- Landing page trimmed to ~70 lines, rebranded "Cbox PHP Base Images"
- New `choosing-your-image.md` with ServersideUp-style image size matrix
- Deleted 4 niche framework guides (Drupal, Magento, TYPO3, Statamic) — replaced with "Other Frameworks" section
- Trimmed security-hardening (1,341 → 340 lines), production-deployment (889 → 362), development-workflow (847 → 329)
- Eliminated duplicated docker-compose examples across 13+ pages
- Fixed all GitHub URLs (`cboxdk/baseimages` → `cboxdk/php-baseimages`)
- CLAUDE.md rewritten to reflect actual architecture (php-base layer, tier system)
- Internal planning docs moved from `docs/superpowers/` to `superpowers/`

## 2024-11-19

### Added
- Initial release with PHP 8.2, 8.3, 8.4 support
- Multi-service images (PHP-FPM + Nginx)
- Slim, Standard, Chromium, and Dev editions
- Alpine, Debian, and Ubuntu variants
- Cbox Init v1.0.0 integration
- Comprehensive documentation structure
- Weekly security rebuilds via GitHub Actions
- Multi-architecture support (amd64, arm64)

### PHP Versions
- PHP 8.2 (all variants)
- PHP 8.3 (all variants)
- PHP 8.4 (all variants)
- PHP 8.5 (all variants)

### Process Management
- Cbox Init v1.0.0 built-in for all php-fpm-nginx images
  - Multi-process orchestration
  - Structured logging
  - Health checks with auto-restart
  - Prometheus metrics
  - Scheduled tasks with cron expressions

### Documentation
- 5-minute quickstart guide
- Laravel complete guide
- Symfony complete guide
- WordPress complete guide
- Production deployment guide
- Development workflow guide
- Performance tuning guide
- Security hardening guide
- Troubleshooting guides
