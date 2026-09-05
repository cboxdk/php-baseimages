# Cbox PHP Base Images

**Production PHP containers with an actual runtime control plane.** They
supervise their own processes, understand their memory budget, and stay
security-patched without silently changing their runtime contract.

[![PHP-FPM-Nginx](https://github.com/cboxdk/php-baseimages/actions/workflows/build-php-fpm-nginx.yml/badge.svg)](https://github.com/cboxdk/php-baseimages/actions/workflows/build-php-fpm-nginx.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Official PHP images give you PHP. These images give you a container that
understands *how it is being run*:

- **A control plane as PID 1** — [Cbox Init](https://github.com/cboxdk/init)
  supervises PHP-FPM, Nginx, queue workers, Horizon, Reverb, and schedulers
  as a dependency graph, with health-check-driven restarts, supervisor-owned
  readiness (`/readyz`, `/livez`), warmup hooks that gate traffic, Prometheus
  metrics, structured JSON logs, and a management API/CLI.
- **Capacity that measures instead of guesses** — `pm.max_children` is seeded
  from the container's real cgroup limits at boot, and (opt-in) re-sized at
  runtime from live per-worker memory via [fpm-tune](https://github.com/cboxdk/fpm-tune):
  atomic drop-in, graceful reload, zero dropped connections.
- **Pin your behavior, not your vulnerabilities** — release-channel tags
  (`8.4-bookworm-v1`) lock the runtime contract to a major while weekly
  rebuilds keep OS security patches flowing. Rolling tags and immutable
  digests exist too. [Tagging strategy →](docs/reference/tagging-strategy.md)
- **Frameworks handled at startup** — Laravel, Symfony, and WordPress are
  auto-detected; permissions, schedulers, and workers configured accordingly.
- **Four tiers, root and rootless** — Slim (~120 MiB) → Standard → Chromium
  (Browsershot/Dusk) → Dev (Xdebug/PCOV/SPX), on Debian 12, amd64 + arm64,
  Cosign-signed and Trivy-scanned.

📖 **[Cbox Init Documentation →](docs/observability/cbox-init-integration.md)**

## 🚀 Quick Start (5 Minutes)

Create `docker-compose.yml`:

```yaml
version: '3.8'

services:
  app:
    # -v1 = release channel: behavior pinned, security patches keep flowing
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-v1
    ports:
      - "8000:80"
    volumes:
      - ./:/var/www/html
    environment:
      - PUID=1000  # Match your host user (run: id -u)
      - PGID=1000  # Match your host group (run: id -g)
```

Start your application:

```bash
docker-compose up -d
```

**Access:** http://localhost:8000

📖 **Full guide:** [5-Minute Quickstart →](docs/getting-started/quickstart.md)

## 🎨 Available Images

### Base OS

All images are built on **Debian 12 (Bookworm)** with glibc for maximum compatibility.

| Base Image | OS Version | Package Manager | libc |
|------------|------------|-----------------|------|
| `php:8.x-cli-bookworm` | Debian 12 (Bookworm) | apt | glibc |

### Image Types

| Image Type | Use Case |
|------------|----------|
| **php-fpm-nginx** | Multi-service container (PHP-FPM + Nginx + Cbox Init) |
| **php-fpm** | Single-process PHP-FPM |
| **php-cli** | CLI workers, cron jobs |
| **nginx** | Standalone Nginx (`bookworm` tag only) |

**Full image name:** `ghcr.io/cboxdk/php-baseimages/{type}:{php}-bookworm[-tier][-rootless]`

**PHP versions:** `8.2`, `8.3`, `8.4`, `8.5`

### Available Tags

Each PHP image type is available in all tier and rootless combinations:

| Tier | Tag | Rootless Tag |
|------|-----|--------------|
| **Standard** (default) | `8.4-bookworm` | `8.4-bookworm-rootless` |
| **Slim** | `8.4-bookworm-slim` | `8.4-bookworm-slim-rootless` |
| **Chromium** | `8.4-bookworm-chromium` | `8.4-bookworm-chromium-rootless` |
| **Dev** | `8.4-bookworm-dev` | `8.4-bookworm-dev-rootless` |

```bash
# Standard tier
ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm
ghcr.io/cboxdk/php-baseimages/php-fpm:8.3-bookworm

# Slim tier
ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-slim

# Chromium tier
ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-chromium

# Dev tier
ghcr.io/cboxdk/php-baseimages/php-fpm:8.3-bookworm-dev

# Rootless variants
ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-rootless
ghcr.io/cboxdk/php-baseimages/php-cli:8.2-bookworm-slim-rootless
```

### Image Tiers: Slim / Standard / Chromium / Dev

| Tier | Size | Extensions | Best For |
|------|------|------------|----------|
| **Slim** | ~120 MiB | 25+ core | API/microservices, minimal footprint |
| **Standard** (default) | ~250 MiB | 30+ with ImageMagick, vips, Node.js | Most Laravel/PHP apps |
| **Chromium** | ~700 MiB | Standard + Chromium | Browsershot, Dusk, PDF generation |
| **Dev** | ~750 MiB | Chromium + Xdebug, PCOV, SPX | Development, testing, CI/CD |

**Tag Suffixes:**

| Tier | Tag Format | Example |
|------|------------|---------|
| Standard (default) | `{version}-bookworm` | `8.4-bookworm` |
| Slim | `{version}-bookworm-slim` | `8.4-bookworm-slim` |
| Chromium | `{version}-bookworm-chromium` | `8.4-bookworm-chromium` |
| Dev | `{version}-bookworm-dev` | `8.4-bookworm-dev` |
| Rootless variants | Add `-rootless` | `8.4-bookworm-rootless`, `8.4-bookworm-dev-rootless` |

**What's included:**

| Tier | Extensions |
|------|------------|
| **Slim** | Redis, APCu, msgpack, GD (WebP), intl, bcmath, zip, PCNTL, sockets |
| **Standard** | Slim + ImageMagick, libvips, GD (AVIF), Node.js 22, MongoDB, exiftool |
| **Chromium** | Standard + Chromium, Puppeteer support |
| **Dev** | Chromium + Xdebug 3.5, PCOV 1.0, SPX profiler |

📖 **Detailed comparison:** [Choosing Your Image →](docs/getting-started/choosing-your-image.md)

### Development Images

Add `-dev` suffix for development images with debugging and profiling tools:

| Production | Development |
|------------|-------------|
| `php-fpm-nginx:8.4-bookworm` | `php-fpm-nginx:8.4-bookworm-dev` |
| `php-fpm:8.3-bookworm` | `php-fpm:8.3-bookworm-dev` |
| `php-fpm:8.2-bookworm` | `php-fpm:8.2-bookworm-dev` |

**Dev images include:**
- **Xdebug 3.5** - Step debugging, code coverage, profiling
- **PCOV 1.0** - Fast code coverage (10x faster than Xdebug)
- **SPX** - Performance profiler with web UI
- Pre-configured for IDE integration (VS Code, PhpStorm)

📖 **Complete image list:** [Available Images →](docs/reference/available-images.md)

## 🚀 Ready-to-Use Templates

**NEW:** Pre-built Dockerfile templates for common scenarios:

- **[Dockerfile.production](templates/Dockerfile.production)** - Multi-stage production build (AMD64 + ARM64)
- **[Dockerfile.node](templates/Dockerfile.node)** - PHP + Node.js for Laravel + Vite, full-stack apps
- **[Dockerfile.dev](templates/Dockerfile.dev)** - Development with Xdebug, SPX profiler, debugging tools
- **[Dockerfile.ci](templates/Dockerfile.ci)** - CI/CD optimized for GitHub Actions, GitLab CI
- **[docker-compose.dev.yml](templates/docker-compose.dev.yml)** - Complete dev environment with MySQL, Redis, Mailpit

**CI/CD Examples:**
- [GitHub Actions (Laravel)](examples/ci/github-actions-laravel.yml)
- [GitLab CI (Symfony)](examples/ci/gitlab-ci-symfony.yml)
- [Bitbucket Pipelines](examples/ci/bitbucket-pipelines.yml)

📖 **[Templates Documentation](templates/)** - Complete usage guide

## 🎓 Documentation

### Getting Started
- **[5-Minute Quickstart](docs/getting-started/quickstart.md)** - Get running in minutes
- [Introduction](docs/getting-started/introduction.md) - Why Cbox?
- [Installation](docs/getting-started/installation.md) - All installation methods
- **[Choosing Your Image](docs/getting-started/choosing-your-image.md)** - Tiers, sizes, root vs rootless, single vs multi-service

### Framework Guides
- **[Laravel Complete Guide](docs/guides/laravel-guide.md)** - Full Laravel setup with MySQL, Redis, Scheduler
- [Symfony Complete Guide](docs/guides/symfony-guide.md) - Symfony with database and caching
- [WordPress Complete Guide](docs/guides/wordpress-guide.md) - WordPress with MySQL
- **[Queue Workers Guide](docs/guides/queue-workers.md)** - Background jobs, Horizon, scaling
- [Development Workflow](docs/guides/development-workflow.md) - Local development + Xdebug
- [Production Deployment](docs/guides/production-deployment.md) - Deploy to production

### Advanced Topics
- **[Extending Images](docs/advanced/extending-images.md)** - Add custom extensions and packages
- [Custom Extensions](docs/advanced/custom-extensions.md) - PECL extension examples
- [Custom Initialization](docs/advanced/custom-initialization.md) - Startup scripts
- [Performance Tuning](docs/advanced/performance-tuning.md) - Optimization guide
- [Security Hardening](docs/security/security-hardening.md) - Security best practices
- [Rootless Containers](docs/security/rootless-containers.md) - Non-root execution
- **[Multi-Architecture Builds](docs/advanced/multi-architecture.md)** - AMD64 + ARM64 support

### Reference
- **[Cbox Init Integration](docs/observability/cbox-init-integration.md)** - Process manager guide
- **[Environment Variables](docs/reference/environment-variables.md)** - All configuration options including Cbox Init
- [Environment Variables](docs/reference/environment-variables.md) - All configuration options
- [Configuration Options](docs/reference/configuration-options.md) - PHP/FPM/Nginx configs
- [Available Extensions](docs/reference/available-extensions.md) - Complete extension list
- [Health Checks](docs/observability/health-checks.md) - Monitoring guide
- [Choosing Your Image](docs/getting-started/choosing-your-image.md) - Architecture decision (single vs multi-service)

### Help & Troubleshooting
- [Common Issues](docs/troubleshooting/common-issues.md) - FAQ and solutions
- [Debugging Guide](docs/troubleshooting/debugging-guide.md) - Systematic debugging
- [Migration Guide](docs/getting-started/migration-guide.md) - From other images

## ✨ Key Features

### Multi-Service Container
Single container with both PHP-FPM and Nginx:

- ✅ Cbox Init process manager (lightweight Go binary)
- ✅ Framework auto-detection (Laravel/Symfony/WordPress)
- ✅ Laravel Scheduler with cron support
- ✅ Auto-fixes permissions
- ✅ Graceful shutdown handling
- ✅ Automated weekly security updates

### Pre-Installed Extensions

**Slim Tier (all tiers inherit these):**
- **Core:** opcache, apcu, redis, pdo_mysql, pdo_pgsql, mysqli, pgsql, zip, intl, bcmath, sockets, pcntl
- **Data:** msgpack
- **Images:** gd (WebP), exif
- **Features:** bz2, gmp

**Standard + Chromium + Dev Tiers add:**
- **Data:** mongodb
- **Images:** imagick, vips, gd (AVIF support)
- **Features:** soap, xsl, ldap, calendar, gettext, sysv IPC
- **Tools:** Node.js 22, npm, exiftool

**Chromium Tier adds:**
- **Browser:** Chromium for Browsershot/Dusk/Puppeteer

📖 **Complete list:** [Available Extensions →](docs/reference/available-extensions.md)

### Framework Auto-Detection

Automatically optimizes for your framework:

| Framework | Auto-Detection | Features |
|-----------|---------------|----------|
| **Laravel** | `artisan` file | Storage/cache setup, Scheduler, migrations |
| **Symfony** | `bin/console` + `var/` | Cache/log directories, permissions |
| **WordPress** | `wp-config.php` | Uploads directory, permissions |

### Intelligent Entrypoint

- Framework detection and optimization
- Configuration validation (PHP-FPM + Nginx)
- Permission auto-fixing
- Custom init script support (`/docker-entrypoint-init.d/`)
- Graceful shutdown (SIGTERM/SIGQUIT)
- Colored logging

### Comprehensive Health Checks

Deep health validation:
- Process status
- Port connectivity
- OPcache status
- Critical extensions
- Memory usage

## ⚙️ Configuration

**53 environment variables** for complete customization - every setting is configurable:

### Quick Examples

```yaml
environment:
  # Fix file permission issues (match your host user)
  - PUID=1000
  - PGID=1000

  # PHP Settings
  - PHP_MEMORY_LIMIT=512M
  - PHP_MAX_EXECUTION_TIME=120

  # Laravel Features
  - LARAVEL_SCHEDULER=true
  - LARAVEL_HORIZON=true

  # Security Headers (all customizable)
  - NGINX_HEADER_CSP=default-src 'self'

  # Disable features (set to empty)
  - NGINX_HEADER_COEP=           # Disable Cross-Origin-Embedder-Policy
  - NGINX_GZIP=off               # Disable gzip compression
  - NGINX_OPEN_FILE_CACHE=off    # Disable file cache
```

### PUID/PGID — Fix File Permission Issues

The most common Docker problem: files created in the container can't be edited on your host. Set `PUID`/`PGID` to match your host user (`id -u` / `id -g`):

```yaml
environment:
  - PUID=1000
  - PGID=1000
```

This remaps the container's `www-data` user and automatically fixes ownership of your application files, `storage/`, `bootstrap/cache/`, and other framework directories.

### Configuration Categories

| Category | Variables | Examples |
|----------|-----------|----------|
| **PHP Settings** | 12 | `PHP_MEMORY_LIMIT`, `PHP_MAX_EXECUTION_TIME` |
| **OPcache** | 8 | `PHP_OPCACHE_ENABLE`, `PHP_OPCACHE_JIT` |
| **Nginx Server** | 5 | `NGINX_HTTP_PORT`, `NGINX_WEBROOT` |
| **Security Headers** | 9 | `NGINX_HEADER_CSP`, `NGINX_HEADER_COOP` |
| **Gzip Compression** | 6 | `NGINX_GZIP`, `NGINX_GZIP_COMP_LEVEL` |
| **File Cache** | 4 | `NGINX_OPEN_FILE_CACHE` |
| **FastCGI** | 6 | `NGINX_FASTCGI_READ_TIMEOUT` |
| **SSL** | 6 | `SSL_MODE`, `SSL_CERTIFICATE_FILE` |

📖 **Complete reference:** [Environment Variables →](docs/reference/environment-variables.md)

## 🔐 Security & Trust

### Weekly Automated Rebuilds

**Schedule:** Every Monday at 03:00 UTC

**What's Updated:**
- Latest upstream Debian base images
- Latest PHP patch versions (8.x.y → 8.x.z)
- OS security patches
- Automated CVE scanning with Trivy

**Stay Secure:**
```bash
# Pull latest security patches
docker pull ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm
docker-compose up -d
```

### Image Tag Formats

| Tag Type | Example | Use Case |
|----------|---------|----------|
| **Standard** | `8.4-bookworm` | Most apps (default tier) |
| **Slim** | `8.4-bookworm-slim` | Minimal footprint, microservices |
| **Chromium** | `8.4-bookworm-chromium` | Browsershot, Dusk, PDF generation |
| **Dev** | `8.4-bookworm-dev` | Development, testing, CI/CD |
| **Rootless** | `8.4-bookworm-rootless` | Security-restricted environments |
| **Slim + Rootless** | `8.4-bookworm-slim-rootless` | Minimal + non-root |
| **Chromium + Rootless** | `8.4-bookworm-chromium-rootless` | Chromium + non-root |
| **Dev + Rootless** | `8.4-bookworm-dev-rootless` | Development + non-root |
| **PHP Pinned** | `8.4.7-bookworm` | Production version lock |

**Standard Tier** (most applications):
```yaml
services:
  app:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm
    # ImageMagick, vips, Node.js included
```

**Slim Tier** (microservices, APIs):
```yaml
services:
  api:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-slim
    # Minimal size (~120 MiB), core extensions only
```

**Chromium Tier** (PDF generation, browser testing):
```yaml
services:
  app:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-chromium
    # Includes Chromium for Browsershot/Dusk
```

**Rootless** (security-restricted environments):
```yaml
services:
  app:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-rootless
    # Runs as www-data user, not root
```

📖 **Security guide:** [Security Documentation →](docs/security/security-hardening.md)

## 📊 Image Sizes

| Tier | Size (FPM-Nginx) | Best For |
|------|------------------|----------|
| **Slim** | ~120 MiB | APIs, microservices |
| **Standard** | ~250 MiB | Most PHP applications |
| **Chromium** | ~700 MiB | PDF generation, browser testing |
| **Dev** | ~750 MiB | Development, testing, CI/CD |

📖 **Detailed comparison:** [Choosing Your Image →](docs/getting-started/choosing-your-image.md)

## 🏗️ Building Locally

```bash
# Clone repository
git clone https://github.com/cboxdk/php-baseimages.git
cd php-baseimages

# Build multi-service image
docker build -f php-fpm-nginx/Dockerfile --build-arg PHP_VERSION=8.3 -t my-image:8.3-bookworm .

# Test it
docker run --rm -p 8000:80 my-image:8.3-bookworm
```

## 🧪 Testing

**Comprehensive E2E test suite with 138+ test cases:**

| Category | Tests | Coverage |
|----------|-------|----------|
| Quick Tests | 3 | PHP basics, health checks, env config |
| Framework Tests | 2 | Laravel, WordPress integration |
| Comprehensive Tests | 6 | Image formats, database, security, Browsershot, Pest, Dusk |

```bash
# Run all tests
./tests/e2e/run-all-tests.sh

# Run quick tests only
./tests/e2e/run-all-tests.sh --quick

# Run specific test
./tests/e2e/run-all-tests.sh --specific database
./tests/e2e/run-all-tests.sh --specific security

# Run extension tests
./tests/test-extensions.sh ghcr.io/cboxdk/php-baseimages/php-fpm:8.3-bookworm
```

📖 **Test documentation:** [tests/README.md](tests/README.md)

## 📝 Examples

**Production-ready example setups available:**

| Example | Description |
|---------|-------------|
| [Laravel Basic](examples/laravel-basic/) | PHP + MySQL basic setup |
| [Laravel Horizon](examples/laravel-horizon/) | Queue workers + Scheduler + Redis |
| [Symfony Basic](examples/symfony-basic/) | Symfony + PostgreSQL |
| [WordPress](examples/wordpress/) | WordPress with optimized uploads |
| [API Only](examples/api-only/) | REST/GraphQL backend |
| [Development](examples/development/) | Xdebug, Vite HMR, MailHog |
| [Production](examples/laravel-production/) | Resource limits, security |
| [Multi-Tenant](examples/multi-tenant/) | SaaS with database-per-tenant |
| [Microservices](examples/microservices/) | Multiple PHP services |
| [WebSockets](examples/reverb-websockets/) | Laravel Reverb real-time |
| [Static Assets](examples/static-assets/) | Pre-built frontend |

📖 **All examples:** [examples/README.md](examples/README.md)

### Laravel with MySQL and Redis

```yaml
version: '3.8'

services:
  app:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.3-bookworm
    ports:
      - "8000:80"
    volumes:
      - ./:/var/www/html
    environment:
      - PUID=1000
      - PGID=1000
      - LARAVEL_SCHEDULER=true
      - LARAVEL_AUTO_OPTIMIZE=true
    depends_on:
      - mysql
      - redis

  mysql:
    image: mysql:8.0
    environment:
      MYSQL_DATABASE: laravel
      MYSQL_ROOT_PASSWORD: secret
    volumes:
      - mysql-data:/var/lib/mysql

  redis:
    image: redis:7-alpine

volumes:
  mysql-data:
```

📖 **Full examples:** [Complete Laravel Guide →](docs/guides/laravel-guide.md)

### Separate PHP-FPM and Nginx

```yaml
version: '3.8'

services:
  php-fpm:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm:8.3-bookworm
    volumes:
      - ./:/var/www/html

  nginx:
    image: ghcr.io/cboxdk/php-baseimages/nginx:bookworm
    ports:
      - "80:80"
    volumes:
      - ./:/var/www/html:ro
    depends_on:
      - php-fpm
```

### Development with Xdebug

```yaml
services:
  app:
    image: ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm-dev
    volumes:
      - ./:/var/www/html
    environment:
      - XDEBUG_MODE=debug
      - XDEBUG_CONFIG=client_host=host.docker.internal
```

### Fast Code Coverage with PCOV

```bash
# 10x faster than Xdebug coverage
docker run --rm -v $(pwd):/var/www/html \
  ghcr.io/cboxdk/php-baseimages/php-fpm:8.4-bookworm-dev \
  php -d pcov.enabled=1 vendor/bin/phpunit --coverage-text
```

## 🤝 Contributing

We welcome contributions!

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test locally with `docker-compose`
5. Submit a pull request

📖 **Contributing guide:** See the steps above or open a [GitHub Discussion](https://github.com/cboxdk/php-baseimages/discussions)

## 📖 Additional Resources

- [Official PHP Documentation](https://www.php.net/docs.php)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Laravel Documentation](https://laravel.com/docs)
- [Symfony Documentation](https://symfony.com/doc)

## 🗺️ Roadmap

- [x] PHP 8.2, 8.3, 8.4, 8.5 support
- [x] Multi-service containers
- [x] Weekly security rebuilds
- [x] Laravel Scheduler support
- [x] Framework auto-detection
- [x] Comprehensive E2E test suite (138+ tests)
- [x] Example applications library (12 production-ready setups)
- [x] Image selection decision matrix
- [x] Queue workers guide
- [ ] Automated security scanning in docs
- [ ] Performance benchmarking suite

## 📝 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Credits

Built by [Cbox](https://github.com/cboxdk) team.

Inspired by the PHP community's need for clean, no-nonsense base images without unnecessary complexity.

## 💬 Support

- **Documentation:** [docs/](docs/getting-started/introduction.md)
- **Issues:** [GitHub Issues](https://github.com/cboxdk/php-baseimages/issues)
- **Discussions:** [GitHub Discussions](https://github.com/cboxdk/php-baseimages/discussions)
- **Security:** [GitHub Security Advisories](https://github.com/cboxdk/php-baseimages/security)

---

**Ready to get started?** → [5-Minute Quickstart](docs/getting-started/quickstart.md)
