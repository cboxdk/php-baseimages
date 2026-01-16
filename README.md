# Cbox Base Images

Clean, minimal, and production-ready PHP Docker base images for modern PHP applications. Built with comprehensive extensions on Debian 12 (Bookworm) and no unnecessary complexity.

[![PHP-FPM-Nginx](https://github.com/cboxdk/baseimages/actions/workflows/build-php-fpm-nginx.yml/badge.svg)](https://github.com/cboxdk/baseimages/actions/workflows/build-php-fpm-nginx.yml)
[![Swoole](https://github.com/cboxdk/baseimages/actions/workflows/build-php-swoole.yml/badge.svg)](https://github.com/cboxdk/baseimages/actions/workflows/build-php-swoole.yml)
[![FrankenPHP](https://github.com/cboxdk/baseimages/actions/workflows/build-frankenphp.yml/badge.svg)](https://github.com/cboxdk/baseimages/actions/workflows/build-frankenphp.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

## 🎯 Philosophy

- **Three Tiers**: Slim (~120MB), Standard (~250MB), Full (~700MB) - choose your needs
- **Cbox Process Manager**: Production-grade Go-based process manager built-in
- **Flexible Architecture**: Choose single-process OR multi-service containers
- **Debian 12 (Bookworm)**: Stable, glibc-based images with excellent compatibility
- **Framework Optimized**: Auto-detection for Laravel, Symfony, WordPress
- **Production Ready**: Optimized configurations for real-world applications

### 🔧 Cbox Process Manager

All `php-fpm-nginx` images include [Cbox PM](https://github.com/cboxdk/cbox-pm) - a production-grade Go-based process manager with:

- ✅ Multi-process orchestration (PHP-FPM + Nginx + Horizon + Reverb + Queue Workers)
- ✅ Structured JSON logging with process segmentation
- ✅ Lifecycle hooks for Laravel optimizations
- ✅ Health checks (TCP, HTTP, exec) with auto-restart
- ✅ Prometheus metrics for observability
- ✅ Graceful shutdown with configurable timeouts

📖 **[Cbox PM Documentation →](docs/cbox-pm-integration.md)**

## 🚀 Quick Start (5 Minutes)

Create `docker-compose.yml`:

```yaml
version: '3.8'

services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm
    ports:
      - "8000:80"
    volumes:
      - ./:/var/www/html
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

### Image Matrix

| Image Type | Available Tags | Use Case |
|------------|----------------|----------|
| **php-fpm-nginx** | `8.2-bookworm` `8.3-bookworm` `8.4-bookworm` `8.5-bookworm` | Multi-service container |
| **php-fpm** | `8.2-bookworm` `8.3-bookworm` `8.4-bookworm` `8.5-bookworm` | Single-process PHP-FPM |
| **php-cli** | `8.2-bookworm` `8.3-bookworm` `8.4-bookworm` `8.5-bookworm` | CLI workers, cron jobs |
| **nginx** | `bookworm` | Standalone Nginx |

### High-Performance Images (Laravel Octane)

| Image Type | Available Tags | Server | Best For |
|------------|----------------|--------|----------|
| **php-swoole** | `8.2-bookworm` `8.3-bookworm` `8.4-bookworm` | Swoole | Maximum performance, coroutines |
| **php-openswoole** | `8.2-bookworm` `8.3-bookworm` `8.4-bookworm` | OpenSwoole | Swoole fork with async I/O |
| **frankenphp** | `8.2-bookworm` `8.3-bookworm` `8.4-bookworm` | FrankenPHP | Auto HTTPS, HTTP/3, worker mode |

📖 **Laravel Octane guide:** [Laravel Octane →](docs/guides/laravel-octane.md)

**Full image name:** `ghcr.io/cboxdk/baseimages/{type}:{tag}`

```bash
# Standard images
ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm
ghcr.io/cboxdk/baseimages/php-fpm:8.3-bookworm
ghcr.io/cboxdk/baseimages/php-cli:8.2-bookworm

# High-performance images (Laravel Octane)
ghcr.io/cboxdk/baseimages/php-swoole:8.4-bookworm
ghcr.io/cboxdk/baseimages/php-openswoole:8.4-bookworm
ghcr.io/cboxdk/baseimages/frankenphp:8.4-bookworm
```

### Image Tiers: Slim / Standard / Full

| Tier | Size | Extensions | Best For |
|------|------|------------|----------|
| **Slim** | ~120MB | 25+ core | API/microservices, minimal footprint |
| **Standard** (default) | ~250MB | 30+ with ImageMagick, vips, Node.js | Most Laravel/PHP apps |
| **Full** | ~700MB | Standard + Chromium | Browsershot, Dusk, PDF generation |

**Tag Suffixes:**

| Tier | Tag Format | Example |
|------|------------|---------|
| Standard (default) | `{version}-bookworm` | `8.4-bookworm` |
| Slim | `{version}-bookworm-slim` | `8.4-bookworm-slim` |
| Full | `{version}-bookworm-full` | `8.4-bookworm-full` |
| Rootless variants | Add `-rootless` | `8.4-bookworm-rootless`, `8.4-bookworm-slim-rootless` |

**What's included:**

| Tier | Extensions |
|------|------------|
| **Slim** | Redis, APCu, MongoDB, gRPC, GD (WebP), intl, bcmath, zip, PCNTL, sockets |
| **Standard** | Slim + ImageMagick, libvips, GD (AVIF), Node.js 22, exiftool |
| **Full** | Standard + Chromium, Puppeteer support |

📖 **Detailed comparison:** [Image Tiers Guide →](docs/reference/editions-comparison.md)

### Development Images

Add `-dev` suffix for development images with Xdebug:

| Production | Development |
|------------|-------------|
| `php-fpm-nginx:8.4-bookworm` | `php-fpm-nginx:8.4-bookworm-dev` |
| `php-fpm:8.3-bookworm` | `php-fpm:8.3-bookworm-dev` |
| `php-fpm:8.2-bookworm` | `php-fpm:8.2-bookworm-dev` |

**Dev images include:** Xdebug 3.x, PHP error display, OPcache timestamp validation, port 9003

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
- [Choosing a Variant](docs/getting-started/choosing-variant.md) - Image tier selection guide
- **[Choosing an Image](docs/getting-started/choosing-an-image.md)** - Decision matrix for image selection

### Framework Guides
- **[Laravel Complete Guide](docs/guides/laravel-guide.md)** - Full Laravel setup with MySQL, Redis, Scheduler
- [Symfony Complete Guide](docs/guides/symfony-guide.md) - Symfony with database and caching
- [WordPress Complete Guide](docs/guides/wordpress-guide.md) - WordPress with MySQL
- **[Queue Workers Guide](docs/guides/queue-workers.md)** - Background jobs, Horizon, scaling
- [Development Workflow](docs/guides/development-workflow.md) - Local development + Xdebug
- [Production Deployment](docs/guides/production-deployment.md) - Deploy to production

### High-Performance (Laravel Octane)
- **[Laravel Octane Guide](docs/guides/laravel-octane.md)** - Swoole, RoadRunner, FrankenPHP
- [Swoole Guide](docs/guides/swoole-guide.md) - Coroutines, task workers, maximum performance
- [FrankenPHP Guide](docs/guides/frankenphp-guide.md) - Auto HTTPS, HTTP/3, Caddy integration

### Advanced Topics
- **[Extending Images](docs/advanced/extending-images.md)** - Add custom extensions and packages
- [Custom Extensions](docs/advanced/custom-extensions.md) - PECL extension examples
- [Custom Initialization](docs/advanced/custom-initialization.md) - Startup scripts
- [Performance Tuning](docs/advanced/performance-tuning.md) - Optimization guide
- [Security Hardening](docs/advanced/security-hardening.md) - Security best practices
- [Rootless Containers](docs/advanced/rootless-containers.md) - Non-root execution
- **[Multi-Architecture Builds](docs/advanced/multi-architecture.md)** - AMD64 + ARM64 support

### Reference
- **[Cbox PM Integration](docs/cbox-pm-integration.md)** - Process manager guide
- **[Cbox PM Environment Variables](docs/cbox-pm-environment-variables.md)** - PM configuration
- **[Cbox PM Architecture](docs/cbox-pm-architecture.md)** - Technical deep dive
- [Environment Variables](docs/reference/environment-variables.md) - All configuration options
- [Configuration Options](docs/reference/configuration-options.md) - PHP/FPM/Nginx configs
- [Available Extensions](docs/reference/available-extensions.md) - Complete extension list
- [Health Checks](docs/reference/health-checks.md) - Monitoring guide
- [Multi-Service vs Separate](docs/reference/multi-service-vs-separate.md) - Architecture decision

### Help & Troubleshooting
- [Common Issues](docs/troubleshooting/common-issues.md) - FAQ and solutions
- [Debugging Guide](docs/troubleshooting/debugging-guide.md) - Systematic debugging
- [Migration Guide](docs/troubleshooting/migration-guide.md) - From other images

## ✨ Key Features

### Multi-Service Container
Single container with both PHP-FPM and Nginx:

- ✅ Cbox PM process manager (lightweight Go binary)
- ✅ Framework auto-detection (Laravel/Symfony/WordPress)
- ✅ Laravel Scheduler with cron support
- ✅ Auto-fixes permissions
- ✅ Graceful shutdown handling
- ✅ Automated weekly security updates

### Pre-Installed Extensions

**All Tiers (Slim/Standard/Full):**
- **Core:** opcache, apcu, redis, pdo_mysql, pdo_pgsql, mysqli, pgsql, zip, intl, bcmath, sockets, pcntl
- **Data:** mongodb, igbinary, msgpack, grpc
- **Images:** gd (WebP), exif
- **Features:** soap, xsl, ldap, bz2, calendar, gettext, gmp

**Standard + Full Tiers add:**
- **Images:** imagick, vips, gd (AVIF support)
- **Tools:** Node.js 22, npm, exiftool

**Full Tier adds:**
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
docker pull ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm
docker-compose up -d
```

### Image Tag Formats

| Tag Type | Example | Use Case |
|----------|---------|----------|
| **Standard** | `8.4-bookworm` | Most apps (default tier) |
| **Slim** | `8.4-bookworm-slim` | Minimal footprint, microservices |
| **Full** | `8.4-bookworm-full` | Browsershot, Dusk, PDF generation |
| **Rootless** | `8.4-bookworm-rootless` | Security-restricted environments |
| **Slim + Rootless** | `8.4-bookworm-slim-rootless` | Minimal + non-root |
| **Full + Rootless** | `8.4-bookworm-full-rootless` | Chromium + non-root |
| **PHP Pinned** | `8.4.7-bookworm` | Production version lock |

**Standard Tier** (most applications):
```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm
    # ImageMagick, vips, Node.js included
```

**Slim Tier** (microservices, APIs):
```yaml
services:
  api:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm-slim
    # Minimal size (~120MB), core extensions only
```

**Full Tier** (PDF generation, browser testing):
```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm-full
    # Includes Chromium for Browsershot/Dusk
```

**Rootless** (security-restricted environments):
```yaml
services:
  app:
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm-rootless
    # Runs as www-data user, not root
```

📖 **Security guide:** [Security Documentation →](docs/advanced/security-hardening.md)

## 📊 Image Sizes

| Tier | Size (FPM-Nginx) | Best For |
|------|------------------|----------|
| **Slim** | ~120MB | APIs, microservices |
| **Standard** | ~250MB | Most PHP applications |
| **Full** | ~700MB | PDF generation, browser testing |

📖 **Detailed comparison:** [Image Tiers Guide →](docs/reference/editions-comparison.md)

## 🏗️ Building Locally

```bash
# Clone repository
git clone https://github.com/cboxdk/baseimages.git
cd baseimages

# Build multi-service image
docker build -f php-fpm-nginx/8.3/debian/bookworm/Dockerfile -t my-image:8.3-bookworm .

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
./tests/test-extensions.sh ghcr.io/cboxdk/baseimages/php-fpm:8.3-bookworm
```

📖 **Test documentation:** [tests/README.md](tests/README.md)

## 📝 Examples

**12 production-ready example setups available:**

| Example | Description |
|---------|-------------|
| [Laravel Basic](examples/laravel-basic/) | PHP + MySQL basic setup |
| [Laravel Horizon](examples/laravel-horizon/) | Queue workers + Scheduler + Redis |
| [Laravel Octane](examples/laravel-octane/) | High-performance Swoole |
| [Symfony Basic](examples/symfony-basic/) | Symfony + PostgreSQL |
| [WordPress](examples/wordpress/) | WordPress with optimized uploads |
| [API Only](examples/api-only/) | REST/GraphQL backend |
| [Development](examples/development/) | Xdebug, Vite HMR, MailHog |
| [Production](examples/production/) | Resource limits, security |
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
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm
    ports:
      - "8000:80"
    volumes:
      - ./:/var/www/html
    environment:
      - LARAVEL_SCHEDULER=true
      - LARAVEL_AUTO_OPTIMIZE=true
    depends_on:
      - mysql
      - redis

  mysql:
    image: mysql:8.3
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
    image: ghcr.io/cboxdk/baseimages/php-fpm:8.3-bookworm
    volumes:
      - ./:/var/www/html

  nginx:
    image: ghcr.io/cboxdk/baseimages/nginx:bookworm
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
    image: ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.3-bookworm-dev
    volumes:
      - ./:/var/www/html
    environment:
      - XDEBUG_MODE=debug
      - XDEBUG_CONFIG=client_host=host.docker.internal
```

## 🤝 Contributing

We welcome contributions!

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test locally with `docker-compose`
5. Submit a pull request

📖 **Contributing guide:** [CONTRIBUTING.md](CONTRIBUTING.md)

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

- **Documentation:** [docs/](docs/)
- **Issues:** [GitHub Issues](https://github.com/cboxdk/baseimages/issues)
- **Discussions:** [GitHub Discussions](https://github.com/cboxdk/baseimages/discussions)
- **Security:** [SECURITY.md](SECURITY.md)

---

**Ready to get started?** → [5-Minute Quickstart](docs/getting-started/quickstart.md)
