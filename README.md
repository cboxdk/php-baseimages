# PHPeek Base Images

Clean, minimal, and production-ready PHP Docker base images for modern PHP applications. Built with comprehensive extensions, multiple OS variants, and no unnecessary complexity.

[![Build Status](https://github.com/phpeek/baseimages/workflows/Build/badge.svg)](https://github.com/phpeek/baseimages/actions)
[![Security Scan](https://github.com/phpeek/baseimages/workflows/Security/badge.svg)](https://github.com/phpeek/baseimages/security)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

## 🎯 Philosophy

- **Two Editions**: Minimal (Laravel-optimized, 17 extensions) OR Full (comprehensive, 32+ extensions)
- **Flexible Process Management**: Choose simple bash OR production-grade [PHPeek PM](https://github.com/phpeek/phpeek-pm)
- **Flexible Architecture**: Choose single-process OR multi-service containers
- **Multiple Variants**: Alpine (smallest), Debian Bookworm, Ubuntu 24.04
- **Framework Optimized**: Auto-detection for Laravel, Symfony, WordPress
- **Production Ready**: Optimized configurations for real-world applications

### 🚀 NEW: PHPeek Process Manager (v1.0.0)

**Production-grade Go-based process manager** with structured logging, health checks, and Prometheus metrics.

- ✅ Multi-process orchestration (PHP-FPM + Nginx + Horizon + Reverb + Queue Workers)
- ✅ Structured JSON logging with process segmentation
- ✅ Lifecycle hooks for Laravel optimizations
- ✅ Health checks (TCP, HTTP, exec) with auto-restart
- ✅ Prometheus metrics for observability
- ✅ Graceful shutdown with configurable timeouts

**Enable with**: `PHPEEK_PROCESS_MANAGER=phpeek-pm`

📖 **[PHPeek PM Documentation →](docs/phpeek-pm-integration.md)**

## 🚀 Quick Start (5 Minutes)

Create `docker-compose.yml`:

```yaml
version: '3.8'

services:
  app:
    image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine
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

## 🎨 Choose Your Edition

### Minimal Edition (Laravel-Optimized)
**Perfect for Laravel apps and modern PHP projects** - 17 essential extensions, 30-40% smaller.

```yaml
image: ghcr.io/phpeek/baseimages/php-fpm:8.3-alpine-minimal
```

✅ All Laravel requirements (GD, EXIF, POSIX, Redis)
✅ Smaller images (~130MB Alpine, ~280MB Debian)
✅ Faster startup and deployment
✅ Explicit configuration (OPcache disabled by default)

### Full Edition (Comprehensive)
**Everything included** - 36+ extensions for enterprise and legacy apps.

```yaml
image: ghcr.io/phpeek/baseimages/php-fpm:8.3-alpine
```

✅ MongoDB, ImageMagick, libvips
✅ SOAP, LDAP, IMAP for enterprise integration
✅ Production-ready (OPcache enabled by default)
✅ ImageMagick security policy included

📖 **Detailed comparison:** [Minimal vs Full Editions →](docs/reference/editions-comparison.md)

## 📦 Available Images

All images available on [GitHub Container Registry](https://github.com/orgs/phpeek/packages).

### Multi-Service Images (PHP-FPM + Nginx in One Container)

**Perfect for simple deployments without orchestration complexity.**

#### Production Images
| Image | PHP Version | OS | Size | Security Updates |
|-------|-------------|----|----- |------------------|
| `php-fpm-nginx:8.4-alpine` | 8.4 | Alpine | ~70MB | Weekly |
| `php-fpm-nginx:8.3-alpine` | 8.3 | Alpine | ~70MB | Weekly |
| `php-fpm-nginx:8.2-alpine` | 8.2 | Alpine | ~70MB | Weekly |
| `php-fpm-nginx:8.4-debian` | 8.4 | Debian | ~150MB | Weekly |
| `php-fpm-nginx:8.4-ubuntu` | 8.4 | Ubuntu | ~160MB | Weekly |

#### Development Images (with Xdebug)
| Image | PHP Version | OS | Includes |
|-------|-------------|----|----- |
| `php-fpm-nginx:8.4-alpine-dev` | 8.4 | Alpine | Xdebug 3.x, dev settings |
| `php-fpm-nginx:8.3-alpine-dev` | 8.3 | Alpine | Xdebug 3.3, dev settings |
| `php-fpm-nginx:8.2-alpine-dev` | 8.2 | Alpine | Xdebug 3.3, dev settings |
| `php-fpm-nginx:8.4-debian-dev` | 8.4 | Debian | Xdebug 3.x, dev settings |
| `php-fpm-nginx:8.4-ubuntu-dev` | 8.4 | Ubuntu | Xdebug 3.x, dev settings |

**Dev images include:** Xdebug pre-configured, PHP error display enabled, OPcache timestamp validation enabled, port 9003 exposed for debugging.

📖 **All versions:** [Complete Image List →](docs/reference/available-images.md)

### Single-Process Images (Traditional Separation)

| Type | Image | Description |
|------|-------|-------------|
| PHP-FPM | `php-fpm:8.3-alpine` | PHP-FPM only |
| PHP-CLI | `php-cli:8.3-alpine` | Command-line PHP |
| Nginx | `nginx:alpine` | Nginx web server |

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
- [Introduction](docs/getting-started/introduction.md) - Why PHPeek?
- [Installation](docs/getting-started/installation.md) - All installation methods
- [Choosing a Variant](docs/getting-started/choosing-variant.md) - Alpine vs Debian vs Ubuntu
- **[Choosing an Image](docs/getting-started/choosing-an-image.md)** - Decision matrix for image selection

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
- [Security Hardening](docs/advanced/security-hardening.md) - Security best practices
- [Rootless Containers](docs/advanced/rootless-containers.md) - Non-root execution
- **[Multi-Architecture Builds](docs/advanced/multi-architecture.md)** - AMD64 + ARM64 support

### Reference
- **[PHPeek PM Integration](docs/phpeek-pm-integration.md)** - Process manager guide
- **[PHPeek PM Environment Variables](docs/phpeek-pm-environment-variables.md)** - PM configuration
- **[PHPeek PM Architecture](docs/phpeek-pm-architecture.md)** - Technical deep dive
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

- ✅ Vanilla bash entrypoint (no S6 complexity)
- ✅ Framework auto-detection (Laravel/Symfony/WordPress)
- ✅ Laravel Scheduler with cron support
- ✅ Auto-fixes permissions
- ✅ Graceful shutdown handling
- ✅ Automated weekly security updates

### Pre-Installed Extensions (40+)

**Core:** opcache, apcu, redis, pdo_mysql, pdo_pgsql, mysqli, pgsql, zip, intl, bcmath, sockets, pcntl

**Images:** gd (WebP/AVIF), imagick, exif

**Features:** soap, xsl, ldap, imap, bz2, calendar, gettext

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
- Latest upstream base images (Alpine/Debian/Ubuntu)
- Latest PHP patch versions (8.x.y → 8.x.z)
- OS security patches
- Automated CVE scanning with Trivy

**Stay Secure:**
```bash
# Pull latest security patches
docker pull ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine
docker-compose up -d
```

### Rolling vs Immutable Tags

**Recommended: Rolling Tags** (automatic security patches)
```yaml
services:
  app:
    image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine
    # ↑ Automatically gets weekly security patches
```

**Advanced: Immutable SHA Tags** (reproducible builds)
```yaml
services:
  app:
    image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine-sha256:abc123...
    # ↑ Locked to specific build
```

📖 **Security guide:** [Security Documentation →](docs/advanced/security-hardening.md)

## 📊 Image Comparison

| Variant | Size (FPM) | Build Time | Compatibility | Best For |
|---------|-----------|------------|---------------|----------|
| **Alpine** | ~50MB | Fast | Good | Production, size-constrained |
| **Debian** | ~120MB | Moderate | Excellent | Production, compatibility |
| **Ubuntu** | ~130MB | Moderate | Excellent | Development, familiar |

📖 **Detailed comparison:** [Choosing a Variant →](docs/getting-started/choosing-variant.md)

## 🏗️ Building Locally

```bash
# Clone repository
git clone https://github.com/phpeek/baseimages.git
cd baseimages

# Build multi-service image
docker build -f php-fpm-nginx/8.3/alpine/Dockerfile -t my-image:8.3-alpine .

# Test it
docker run --rm -p 8000:80 my-image:8.3-alpine
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
./tests/test-extensions.sh ghcr.io/phpeek/baseimages/php-fpm:8.3-alpine
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
    image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine
    ports:
      - "8000:80"
    volumes:
      - ./:/var/www/html
    environment:
      - LARAVEL_SCHEDULER_ENABLED=true
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
    image: ghcr.io/phpeek/baseimages/php-fpm:8.3-alpine
    volumes:
      - ./:/var/www/html

  nginx:
    image: ghcr.io/phpeek/baseimages/nginx:alpine
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
    image: ghcr.io/phpeek/baseimages/php-fpm-nginx:8.3-alpine-dev
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

- [x] PHP 8.2, 8.3, 8.4 support
- [x] Multi-service containers
- [x] Weekly security rebuilds
- [x] Laravel Scheduler support
- [x] Framework auto-detection
- [x] Comprehensive E2E test suite (138+ tests)
- [x] Example applications library (12 production-ready setups)
- [x] Image selection decision matrix
- [x] Queue workers guide
- [ ] PHP 8.5 stable release
- [ ] Automated security scanning in docs
- [ ] Performance benchmarking suite

## 📝 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Credits

Built by [PHPeek](https://github.com/phpeek) team.

Inspired by the PHP community's need for clean, no-nonsense base images without unnecessary complexity.

## 💬 Support

- **Documentation:** [docs/](docs/)
- **Issues:** [GitHub Issues](https://github.com/phpeek/baseimages/issues)
- **Discussions:** [GitHub Discussions](https://github.com/phpeek/baseimages/discussions)
- **Security:** [SECURITY.md](SECURITY.md)

---

**Ready to get started?** → [5-Minute Quickstart](docs/getting-started/quickstart.md)
