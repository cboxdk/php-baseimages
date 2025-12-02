# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PHPeek Base Images is a Docker image build system providing production-ready PHP containers with two architectural approaches:

1. **Single-Process Containers**: Separate PHP-FPM, PHP-CLI, and Nginx containers (traditional microservices)
2. **Multi-Service Containers**: PHP-FPM + Nginx in one container with vanilla bash entrypoint (no S6 Overlay)

**Key Philosophy**: Vanilla approach with simple bash entrypoints, comprehensive PHP extensions (40+), multiple OS variants (Alpine/Debian/Ubuntu), and framework auto-detection (Laravel/Symfony/WordPress).

## Architecture

### Directory Structure

```
.
├── php-fpm/           # Single-process PHP-FPM images
│   ├── {version}/     # 8.2, 8.3, 8.4
│   │   ├── alpine/    # Smallest (~50MB)
│   │   ├── debian/    # glibc compatibility (~120MB)
│   │   └── ubuntu/    # Familiar environment (~130MB)
│   └── common/        # Shared config (entrypoint, healthcheck, php.ini, fpm-pool.conf)
│
├── php-cli/           # Single-process PHP-CLI images
│   ├── {version}/
│   │   └── {os}/
│   └── common/        # Shared CLI entrypoint and healthcheck
│
├── nginx/             # Standalone Nginx images
│   ├── {os}/
│   └── common/
│
├── php-fpm-nginx/     # Multi-service containers (PHP-FPM + Nginx)
│   ├── {version}/     # 8.2, 8.3, 8.4, 8.5-beta
│   │   └── {os}/
│   └── common/        # Shared multi-service entrypoint, nginx config, healthcheck
│
├── .github/workflows/ # CI/CD with weekly security rebuilds
└── docs/             # Comprehensive documentation (junior-friendly)
```

### Multi-Service Architecture (Key Innovation)

**File**: `php-fpm-nginx/common/docker-entrypoint.sh`

This entrypoint manages both PHP-FPM and Nginx with two operating modes:

1. **Framework Detection**: Detects Laravel (`artisan`), Symfony (`bin/console`), WordPress (`wp-config.php`)
2. **Permission Auto-Fix**: Creates and fixes permissions for framework directories
3. **Laravel Features**: Scheduler, Horizon, Reverb, Queue workers
4. **Process Management** (two modes):
   - **Primary Mode (PHPeek PM)**: Go-based process manager with health checks, metrics, and structured logging
   - **Fallback Mode (Vanilla Bash)**: PHP-FPM daemonized + Nginx foreground if PM unavailable
5. **Graceful Shutdown**: Handles SIGTERM/SIGQUIT for clean shutdowns

**Critical Design**:
- **Primary**: PHPeek PM (lightweight Go binary) as PID 1 for production
- **Fallback**: Vanilla bash mode (no S6 Overlay, supervisord) if PM not installed
- Enable PHPeek PM with: `PHPEEK_PROCESS_MANAGER=phpeek-pm`

### Shared Configuration Pattern

All variants share common configuration from `{type}/common/`:
- `docker-entrypoint.sh` - Startup logic with framework detection
- `healthcheck.sh` - Deep health validation (process, port, opcache, extensions)
- `php.ini` / `php-dev.ini` - PHP configuration (prod/dev)
- `fpm-pool.conf` - PHP-FPM pool settings
- `default.conf` - Nginx server block (for multi-service)

**Dockerfile Pattern**: Each variant copies from common:
```dockerfile
COPY {type}/common/docker-entrypoint.sh /usr/local/bin/
COPY {type}/common/healthcheck.sh /usr/local/bin/
COPY {type}/common/php.ini /usr/local/etc/php/conf.d/99-custom.ini
```

### OS-Specific Differences

**Alpine**:
- Uses musl libc
- Package manager: `apk`
- Nginx user: `nginx`
- Smallest images
- Cron: `dcron`

**Debian/Ubuntu**:
- Uses glibc
- Package manager: `apt`
- Nginx user: `www-data` (requires sed fix in Dockerfile)
- PHP-FPM on Ubuntu uses socket by default → must change to TCP `0.0.0.0:9000`
- Cron: `cron`

## Build System

### Local Development Builds

```bash
# Build single-process containers (default profile)
docker-compose build php-fpm-alpine nginx-alpine php-cli-alpine

# Build multi-service containers (multi profile)
docker-compose --profile multi build php-fpm-nginx-alpine
docker-compose --profile multi build php-fpm-nginx-debian php-fpm-nginx-ubuntu

# Build specific PHP version variant
docker build -f php-fpm-nginx/8.3/alpine/Dockerfile -t test-image .

# Build with no cache (force rebuild)
docker-compose build --no-cache php-fpm-alpine
```

### Testing Built Images

```bash
# Test single-process setup (port 8080)
docker-compose up -d
open http://localhost:8080

# Test multi-service containers
docker-compose --profile multi up -d php-fpm-nginx-alpine
open http://localhost:8081  # Alpine
open http://localhost:8082  # Debian
open http://localhost:8083  # Ubuntu

# Run extension tests
./tests/test-extensions.sh phpeek-fpm-alpine
./tests/test-extensions.sh ghcr.io/gophpeek/baseimages/php-fpm:8.3-alpine

# Check logs for entrypoint behavior
docker-compose logs -f php-fpm-nginx-alpine

# Interactive debugging
docker-compose exec php-fpm-nginx-alpine /bin/bash
docker-compose exec php-fpm-nginx-alpine php -m  # List extensions
docker-compose exec php-fpm-nginx-alpine php -v  # Check version
```

### CI/CD Workflows

Located in `.github/workflows/`:

- `build-php-fpm.yml` - Builds PHP-FPM images (Alpine/Debian/Ubuntu)
- `build-php-cli.yml` - Builds PHP-CLI images
- `build-nginx.yml` - Builds Nginx images
- `build-php-fpm-nginx.yml` - **Multi-service images with weekly security rebuilds**

**Key CI Features**:
- **Matrix builds**: All PHP versions × OS variants in parallel
- **Weekly schedule**: Every Monday 03:00 UTC (`cron: '0 3 * * 1'`)
- **Rolling tags**: `8.3-alpine` gets updated weekly with security patches
- **Immutable tags**: `8.3-alpine-sha256:...` for reproducibility
- **Trivy scanning**: CVE scanning with results to GitHub Security tab
- **Multi-arch**: Builds for `linux/amd64` and `linux/arm64`

## Common Development Tasks

### Adding a New PHP Version

1. Copy directory structure:
```bash
cp -r php-fpm-nginx/8.3 php-fpm-nginx/8.6
cp -r php-fpm/8.3 php-fpm/8.6
cp -r php-cli/8.3 php-cli/8.6
```

2. Update Dockerfiles: Change `FROM php:8.3-*` to `FROM php:8.6-*`

3. Update GitHub Actions workflow matrix:
```yaml
matrix:
  php_version: ['8.2', '8.3', '8.4', '8.6']
```

4. Update documentation in `README.md` and `docs/`

### Adding a New PHP Extension

Extensions are installed in Dockerfiles. Pattern:

```dockerfile
# Alpine
RUN apk add --no-cache $PHPIZE_DEPS && \
    pecl install extension-version && \
    docker-php-ext-enable extension && \
    apk del $PHPIZE_DEPS

# Debian/Ubuntu
RUN apt-get update && apt-get install -y \
    php{version}-extension && \
    rm -rf /var/lib/apt/lists/*
```

**Update these files**:
- All Dockerfiles for that image type (php-fpm, php-cli, php-fpm-nginx)
- `tests/test-extensions.sh` - Add to required or optional extensions
- `docs/reference/available-extensions.md` - Document the extension
- `README.md` - Update extension count if needed

### Modifying Entrypoint Behavior

**Single-process entrypoints**:
- `php-fpm/common/docker-entrypoint.sh` - PHP-FPM only
- `php-cli/common/docker-entrypoint.sh` - CLI only
- `nginx/common/docker-entrypoint.sh` - Nginx only

**Multi-service entrypoint**:
- `php-fpm-nginx/common/docker-entrypoint.sh` - Both PHP-FPM and Nginx

**Key functions**:
- `detect_framework()` - Framework detection logic
- `setup_laravel()` - Laravel-specific setup (permissions, scheduler)
- `setup_symfony()` - Symfony-specific setup
- `setup_wordpress()` - WordPress-specific setup

**Testing entrypoint changes**:
```bash
# Rebuild with entrypoint changes
docker-compose build --no-cache php-fpm-nginx-alpine

# Watch startup logs
docker-compose up php-fpm-nginx-alpine

# Check framework detection
docker-compose exec php-fpm-nginx-alpine cat /tmp/detected-framework.txt
```

### Testing Health Checks

Health checks are in `{type}/common/healthcheck.sh`:

```bash
# Manually run health check
docker-compose exec php-fpm-nginx-alpine /usr/local/bin/healthcheck.sh

# Check health status
docker-compose ps

# Watch health check logs
docker inspect phpeek-fpm-nginx-alpine --format='{{json .State.Health}}' | jq
```

## Critical Files

### php-fpm-nginx/common/docker-entrypoint.sh
The heart of multi-service containers. Handles:
- Framework detection and auto-configuration
- Permission fixes (Laravel storage/, Symfony var/, etc.)
- Laravel Scheduler cron setup
- PHP-FPM daemonization
- Nginx foreground execution
- Custom init scripts from `/docker-entrypoint-init.d/`

### php-fpm-nginx/common/default.conf
Nginx server block for multi-service containers:
- FastCGI configuration for PHP-FPM on `127.0.0.1:9000`
- Health check endpoint at `/health`
- Optimized for Laravel/Symfony/WordPress routing

### .github/workflows/build-php-fpm-nginx.yml
CI/CD with security focus:
- Matrix builds: `php_version × os_variant`
- Weekly rebuilds: `cron: '0 3 * * 1'`
- Rolling + SHA tags
- Trivy CVE scanning
- Multi-arch (amd64/arm64)

## Documentation Structure

Comprehensive docs in `docs/` following ServerSideUp quality standards:

**For Juniors**:
- `docs/getting-started/quickstart.md` - 5-minute setup
- `docs/guides/laravel-guide.md` - Complete Laravel guide with common mistakes
- `docs/advanced/extending-images.md` - Customization examples

**Documentation Principles**:
- Copy-paste ready examples
- Expected output for every command
- Inline troubleshooting (❌ Wrong → ✅ Correct patterns)
- Progressive complexity (Basic → Advanced)
- Real explanations (WHY, not just WHAT)

## Environment Variables

### Multi-Service Containers

```bash
# Laravel Features
LARAVEL_SCHEDULER=true            # Enable cron for schedule:run (LARAVEL_SCHEDULER_ENABLED still accepted)
LARAVEL_AUTO_OPTIMIZE=false       # Auto-cache config/routes on startup
LARAVEL_AUTO_MIGRATE=false        # Auto-run migrations (dangerous in prod!)

# Xdebug (dev images only)
XDEBUG_MODE=debug,develop,coverage
XDEBUG_CONFIG=client_host=host.docker.internal client_port=9003
PHP_IDE_CONFIG=serverName=docker
```

These are handled in `php-fpm-nginx/common/docker-entrypoint.sh`

## Common Gotchas

### Debian/Ubuntu Nginx User
Debian/Ubuntu use `www-data` as the nginx user, not `nginx`. All Debian/Ubuntu Dockerfiles must include:
```dockerfile
RUN sed -i 's/user nginx;/user www-data;/' /etc/nginx/nginx.conf
```

### Ubuntu PHP-FPM Socket vs TCP
Ubuntu PHP-FPM defaults to Unix socket. Must change to TCP for multi-service:
```dockerfile
RUN sed -i 's|listen = /run/php/php8.3-fpm.sock|listen = 0.0.0.0:9000|' /etc/php/8.3/fpm/pool.d/www.conf
```

### Nginx Config Path
**Alpine**: `/etc/nginx/conf.d/`
**Debian/Ubuntu**: Also `/etc/nginx/conf.d/` (NOT `/etc/nginx/sites-available/`)

nginx.conf includes: `include /etc/nginx/conf.d/*.conf;`

### Build Context
All Dockerfiles must be built from repository root with proper context:
```bash
docker build -f php-fpm-nginx/8.3/alpine/Dockerfile .
# NOT: docker build php-fpm-nginx/8.3/alpine/
```

This is because Dockerfiles copy from `{type}/common/` which is relative to repo root.

## Security & Weekly Rebuilds

**Strategy**: Rolling tags for automatic security updates

**Schedule**: GitHub Actions runs every Monday 03:00 UTC
- Pulls latest upstream base images (php:8.x-fpm-alpine, etc.)
- Rebuilds all variants
- Tags with rolling version (`8.3-alpine`) AND immutable SHA
- Runs Trivy CVE scan
- Pushes to ghcr.io

**Users**: Simply `docker pull` weekly to get security patches

**Tags**:
- `8.3-alpine` - Rolling (recommended for most users)
- `8.3-alpine-sha256:abc...` - Immutable (for reproducibility)
- `latest` - Points to newest stable (8.4-alpine)

## Image Publishing

Images published to GitHub Container Registry: `ghcr.io/gophpeek/baseimages/`

**Naming convention**:
- `php-fpm:8.3-alpine`
- `php-cli:8.3-debian`
- `nginx:alpine`
- `php-fpm-nginx:8.3-ubuntu` (multi-service)

**Authentication** (for CI):
```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_ACTOR --password-stdin
```

---

# PHPeek Documentation Standards

This repository follows the PHPeek.com documentation standards for consistent display across the platform.

## Documentation Structure Requirements

This guide explains how to structure documentation for PHPeek packages to ensure optimal display and navigation on phpeek.com.

## Core Concepts

### Major Version Management
- PHPeek displays ONE entry per major version (v1, v2, v3)
- System automatically tracks the latest release within each major version
- URLs use major version: `/docs/{package}/v1`, `/docs/{package}/v2`
- When you release v1.2.1 after v1.2.0, the website updates automatically

### Files NOT Used on PHPeek.com

**README.md - GitHub Only**
- ⚠️ README.md is **NEVER** displayed on PHPeek.com
- README.md is only for GitHub repository display
- All documentation must be in the `/docs` folder
- Do NOT reference README.md in your docs

**Files Used on PHPeek.com**
- All `.md` files in the `/docs` folder
- All image/asset files within `/docs`
- `_index.md` files for directory landing pages (optional but recommended)

## Directory Structure

### Recommended Structure
```
docs/
├── introduction.md              # What is this package?
├── installation.md              # How to install
├── quickstart.md               # 5-minute getting started
├── basic-usage/                # Core features
│   ├── _index.md              # Optional: Section overview
│   ├── feature-one.md
│   └── feature-two.md
├── advanced-usage/             # Complex scenarios
│   ├── _index.md
│   └── advanced-feature.md
├── api-reference.md            # Complete API docs
└── testing.md                  # How to test
```

### Directory Naming Rules
- ✅ Use lowercase with hyphens: `basic-usage/`, `advanced-features/`
- ✅ Keep names short: `api-reference/`, `platform-support/`
- ✅ Max 2-3 levels of nesting
- ❌ Don't use spaces or special characters
- ❌ Don't create deeply nested structures (>3 levels)

## Metadata (Frontmatter)

### Required Fields
Every `.md` file **MUST** have frontmatter with `title` and `description`:

```yaml
---
title: "Page Title"           # REQUIRED
description: "Brief summary"  # REQUIRED
weight: 99                    # OPTIONAL (default: 99)
hidden: false                 # OPTIONAL (default: false)
---
```

### How Metadata Is Used

**Title**
- Navigation sidebar link text
- Page header `<h1>` tag
- Browser tab title
- SEO meta tags
- Social media sharing

**Description**
- SEO meta description
- Search engine result snippets
- Social media preview text
- May influence click-through rate

**Weight**
- Controls navigation order (lower = first)
- Default is 99
- Same weight = alphabetical by title
- Only affects current directory

**Hidden**
- Set to `true` to hide from navigation
- Page still accessible via direct URL
- Useful for drafts or deprecated content

### Metadata Best Practices

**Title Guidelines**
```yaml
# ✅ Good titles
title: "CPU Metrics"
title: "Error Handling"
title: "API Reference"

# ❌ Avoid
title: "Page 1"                    # Generic
title: "System Metrics CPU Stuff"  # Too long, redundant
title: "cpu-metrics"               # Not Title Case
```

**Description Guidelines**
```yaml
# ✅ Good descriptions (60-160 chars, action-oriented)
description: "Get raw CPU time counters and per-core metrics from the system"
description: "Master the Result<T> pattern for explicit error handling"
description: "Monitor resource usage for individual processes or process groups"

# ❌ Avoid
description: "This page describes CPU metrics"  # Too generic
description: "CPU stuff"                        # Too vague
description: "A very long description that goes on and on..."  # Too long (>160 chars)
```

**Weight Organization**
```yaml
# Recommended weight ranges:
1-10:   Critical pages (introduction, installation, quickstart)
11-30:  Common features (basic usage)
31-70:  Advanced features
71-99:  Reference material (API docs, appendices)

# Example:
# docs/introduction.md
weight: 1

# docs/installation.md
weight: 2

# docs/quickstart.md
weight: 3

# docs/basic-usage/cpu-metrics.md
weight: 10
```

## Links and URLs

### Internal Documentation Links

Use **relative paths** to link between documentation pages:

```markdown
# Link to sibling file in same directory
[Installation Guide](installation)

# Link to file in parent directory
[Back to Introduction](../introduction)

# Link to file in subdirectory
[CPU Metrics](basic-usage/cpu-metrics)

# Link to file in different subdirectory
[Platform Comparison](../platform-support/comparison)

# Link with anchor to heading
[Error Handling](advanced-usage/error-handling#result-pattern)
```

**Link Best Practices**
- ✅ Use descriptive link text: `[View API Reference](api-reference)`
- ✅ Remove `.md` extension: `[Guide](installation)` not `[Guide](installation.md)`
- ✅ Use relative paths: `[Guide](../guide)`
- ❌ Don't use generic text: `[Click here](guide)` or `[Read more](docs)`
- ❌ Don't hardcode absolute URLs: `[Guide](/docs/package/v1/guide)`
- ❌ Don't link to README.md (it's not displayed)

### External Links

```markdown
# Always use full URLs with https://
[GitHub Repository](https://github.com/owner/repo)
[Official Website](https://example.com)

# ✅ Good
[Documentation](https://example.com/docs)

# ❌ Avoid
[Documentation](example.com/docs)  # Missing https://
```

## Images and Assets

### Image References

Use **relative paths** for images:

```markdown
# Image in same directory
![Performance Chart](performance.png)

# Image in subdirectory
![Diagram](images/architecture.png)

# Image in parent images folder
![Logo](../images/logo.svg)

# Image with alt text and tooltip
![Chart](chart.png "CPU Performance Over Time")
```

**Image Best Practices**
- ✅ Always include alt text: `![Diagram](image.png)` not `![](image.png)`
- ✅ Use relative paths
- ✅ Organize in `/docs/images/` or feature-specific folders
- ✅ Supported formats: `.png`, `.jpg`, `.jpeg`, `.gif`, `.svg`, `.webp`
- ❌ Don't use absolute URLs
- ❌ Don't reference images outside `/docs` folder

### Asset Organization

```
docs/
├── images/              # Shared images
│   ├── logo.png
│   └── architecture.svg
├── basic-usage/
│   ├── cpu-chart.png   # Feature-specific image
│   └── cpu-metrics.md
└── screenshots/         # UI screenshots
    └── dashboard.png
```

## Code Blocks

### Syntax Highlighting

Always specify the language after the opening fence:

````markdown
```php
use PHPeek\SystemMetrics\SystemMetrics;

$cpu = SystemMetrics::cpu()->get();
echo "Cores: {$cpu->cores}\n";
```
````

**Supported Languages**
- PHP, JavaScript, Bash, JSON, YAML, XML, HTML, Markdown, SQL, Dockerfile

**Code Block Best Practices**
````markdown
# ✅ Good - Language specified
```php
$metrics = SystemMetrics::cpu()->get();
```

# ❌ Avoid - No language
```
$metrics = SystemMetrics::cpu()->get();
```
````

## Index Files (_index.md)

### Purpose
- Creates landing pages for directory sections
- Provides section overview
- Optional but recommended for better UX

### When to Use

**✅ Create _index.md for:**
- Major sections with 3+ child pages
- Directories needing explanation
- Sections requiring custom intro text

**❌ Skip _index.md for:**
- Simple directories with 1-2 pages
- Self-explanatory sections

### Example _index.md

```markdown
---
title: "Basic Usage"
description: "Essential features for getting started with the package"
weight: 1
---

# Basic Usage

This section covers the fundamental features you'll use daily:

- CPU and memory monitoring
- Disk usage tracking
- Network statistics
- System uptime

Start with the "System Overview" guide for a quick introduction.
```

## Complete Example

**File**: `docs/basic-usage/cpu-metrics.md`

```markdown
---
title: "CPU Metrics"
description: "Get raw CPU time counters and per-core metrics from the system"
weight: 10
---

# CPU Metrics

Monitor CPU usage and performance with real-time metrics.

## Getting CPU Statistics

```php
use PHPeek\SystemMetrics\SystemMetrics;

$cpu = SystemMetrics::cpu()->get();

echo "CPU Cores: {$cpu->cores}\n";
echo "User Time: {$cpu->user}ms\n";
echo "System Time: {$cpu->system}ms\n";
```

## Per-Core Metrics

```php
foreach ($cpu->perCore as $core) {
    echo "Core {$core->id}: {$core->usage}%\n";
}
```

## Performance Considerations

![CPU Performance Chart](../images/cpu-performance.png)

The metrics collection is highly optimized:
- No system calls for static data
- Efficient caching for hardware info
- Minimal overhead (<1ms per call)

See [Performance Caching](../architecture/performance-caching) for details.

## Platform Support

- ✅ Linux: Full support via `/proc/stat`
- ✅ macOS: Full support via `host_processor_info()`

See [Platform Comparison](../platform-support/comparison) for detailed differences.
```

## Quality Checklist

Before publishing, verify:

### Metadata
- [ ] Every `.md` file has `title` and `description`
- [ ] Titles are unique and descriptive (Title Case)
- [ ] Descriptions are 60-160 characters
- [ ] Weight values create logical ordering
- [ ] No generic titles like "Page 1", "Document"

### Structure
- [ ] Major sections have `_index.md` files
- [ ] Directory nesting is shallow (max 2-3 levels)
- [ ] File names use lowercase-with-hyphens
- [ ] Directory names are short and descriptive

### Content
- [ ] Code blocks specify language
- [ ] Images have alt text
- [ ] Links use relative paths
- [ ] No references to README.md
- [ ] All internal links tested

### Files
- [ ] All documentation in `/docs` folder
- [ ] No absolute URLs for internal content
- [ ] Images stored within `/docs` directory
- [ ] No spaces or special characters in filenames

## Troubleshooting

### Navigation Not Showing
- Check frontmatter exists and is valid YAML
- Verify `title` and `description` are present
- Ensure file has `.md` extension
- Confirm `hidden: false` (or field omitted)
- Verify file is in `/docs` folder (not root)

### Images Not Loading
- Use relative paths: `![](../images/file.png)`
- Verify image exists in repository
- Check file extension is supported
- Ensure image is within `/docs` directory

### Wrong Page Order
- Add `weight` to frontmatter
- Lower numbers appear first (1, 2, 3...)
- Default weight is 99
- Same weight = alphabetical by title

### Code Not Highlighting
- Specify language: \`\`\`php not just \`\`\`
- Supported: php, js, bash, json, yaml, xml, html, md, sql, dockerfile
- Check spelling of language name
- Ensure code block is properly closed

## URL Structure

Your documentation will be available at:

```
https://phpeek.com/docs/{package}/{major_version}/{page_path}

Examples:
/docs/system-metrics/v1/introduction
/docs/system-metrics/v1/basic-usage/cpu-metrics
/docs/system-metrics/v2/advanced-usage/custom-implementations
```

**How URLs Are Generated**
```
File: docs/basic-usage/cpu-metrics.md
URL:  /docs/system-metrics/v1/basic-usage/cpu-metrics

File: docs/introduction.md
URL:  /docs/system-metrics/v1/introduction
```

## SEO Tips

**Title Impact**
- Shown in Google search results
- Used in social media shares
- Displayed in browser tabs
- Should be unique and descriptive

**Description Impact**
- Shown as snippet in search results
- Used in social media previews
- Should be 120 characters ideal
- Should explain page value to users

**Best Practices**
- ✅ Unique title per page
- ✅ Descriptive URLs (via good filenames)
- ✅ 60-160 character descriptions
- ✅ Include relevant keywords naturally
- ❌ Don't stuff keywords
- ❌ Don't use duplicate titles
- ❌ Don't create duplicate content
