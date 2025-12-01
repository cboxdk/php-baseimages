---
title: "Changelog"
description: "What's new in PHPeek base images - features, improvements, and security updates"
weight: 99
---

# Changelog

All notable changes to PHPeek base images.

## [Unreleased]

### Added
- PHP 8.5-beta support (experimental)
- Laravel Reverb WebSocket support (`LARAVEL_REVERB=true`)
- mTLS client certificate authentication
- Reverse proxy support (Cloudflare, Traefik, HAProxy)

---

## [2024.11] - November 2024

### Added
- **PHPeek PM** - Go-based process manager replacing bash scripts
- Laravel Horizon support (`LARAVEL_HORIZON=true`)
- Queue worker scaling (`PHPEEK_PM_PROCESS_QUEUE_DEFAULT_SCALE`)
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
- Minimal edition (`-minimal` suffix)
- Development edition (`-dev` suffix) with Xdebug
- Framework auto-detection (Laravel, Symfony, WordPress)
- Automatic permission fixes

### Changed
- Nginx security headers enabled by default
- PHP-FPM dynamic process management

---

## Upgrade Guide

### From bash-based entrypoint to PHPeek PM

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
| `LARAVEL_AUTO_OPTIMIZE` | `LARAVEL_OPTIMIZE` |
| `LARAVEL_AUTO_MIGRATE` | `LARAVEL_MIGRATE` |

---

## Security Updates

PHPeek images are rebuilt weekly (Mondays 03:00 UTC) with latest security patches.

**To get updates**:
```bash
docker compose pull
docker compose up -d
```

**Check current version**:
```bash
docker compose exec app cat /etc/phpeek-version
```

---

## Reporting Issues

- **Bugs**: [GitHub Issues](https://github.com/phpeek/baseimages/issues)
- **Security**: See [SECURITY.md](https://github.com/phpeek/baseimages/blob/main/SECURITY.md)
- **Questions**: [GitHub Discussions](https://github.com/phpeek/baseimages/discussions)
