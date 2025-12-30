# Changelog

All notable changes to PHPeek Base Images will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **New PHP extensions** in Full edition (now 36+ extensions):
  - `mongodb` - MongoDB NoSQL database driver
  - `gmp` - GNU Multiple Precision arithmetic (crypto/math libraries)
  - `igbinary` - Binary serializer (Redis performance optimization)
  - `msgpack` - MessagePack serialization format
- Redis extension updated to 6.3.0 for PHP 8.4 compatibility
- APCu extension updated to 5.1.27 for PHP 8.4 (5.1.23 has build issues)
- Ready-to-use Dockerfile templates (Node.js, Development, CI/CD)
- CI/CD pipeline examples (GitHub Actions, GitLab CI, Bitbucket)
- Rootless container documentation
- Development environment with Xdebug + SPX profiler

### Changed
- IMAP extension removed from PHP 8.4 (deprecated by PHP core)

### Known Issues
- PHP 8.5 support postponed: PECL extensions (igbinary, msgpack, mongodb) not yet compatible with PHP 8.5.0
  - Will be added once PHP 8.5.1+ and compatible PECL versions are released
- PHP 8.5 test profiles in docker-compose.yml (`--profile php85`)

### Documentation
- PHPeek PM v1.1.0 features documented
  - Scheduled Tasks (cron-like) implementation
  - Heartbeat monitoring integration (healthchecks.io, Cronitor, Better Uptime)
  - Advanced logging (level detection, multiline, JSON parsing, sensitive data redaction)
- Complete environment variable reference for v1.1.0
- Scheduled tasks example configuration (`docker-compose-scheduled-tasks.yml`)

## [1.0.0] - 2024-11-19

### Added
- Initial release with PHP 8.2, 8.3, 8.4 support
- Multi-service images (PHP-FPM + Nginx)
- Minimal and Full editions
- Alpine, Debian, and Ubuntu variants
- PHPeek PM v1.0.0 integration
- Comprehensive documentation structure
- Weekly security rebuilds via GitHub Actions
- Multi-architecture support (amd64, arm64)

### PHP Versions
- PHP 8.2 (all variants)
- PHP 8.3 (all variants)
- PHP 8.4 (all variants)
- PHP 8.5 (all variants)

### Process Management
- PHPeek PM v1.0.0 built-in for all php-fpm-nginx images
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

[Unreleased]: https://github.com/gophpeek/baseimages/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/gophpeek/baseimages/releases/tag/v1.0.0
