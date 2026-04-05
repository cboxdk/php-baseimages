# Changelog

All notable changes to Cbox PHP Base Images will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

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
- Slim, Standard, and Chromium editions
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

