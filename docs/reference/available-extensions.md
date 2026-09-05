---
title: "Available Extensions"
description: "Complete list of PHP extensions by image tier - Slim, Standard, Chromium, and Dev"
weight: 4
---

# Available Extensions

Complete reference of all PHP extensions included in Cbox PHP Base Images by tier.

## Extension Overview by Tier

Cbox images come in four tiers with different extension sets:

| Tier | Extensions | Best For |
|------|-----------|----------|
| **Slim** | 25+ core | APIs, microservices |
| **Standard** | Slim + ImageMagick, vips, Node.js, Bun | Most apps (DEFAULT) |
| **Chromium** | Standard + Chromium | Browsershot, Dusk, PDF |
| **Dev** | Chromium + Xdebug, PCOV, SPX | Development, testing, CI/CD |

## Slim Tier Extensions

The Slim tier includes all core extensions needed for most PHP applications.

### PHP Extensions

| Extension | Type | Purpose |
|-----------|------|---------|
| `opcache` | Built-in | Bytecode caching for performance |
| `pdo_mysql` | Built-in | MySQL PDO driver |
| `pdo_pgsql` | Built-in | PostgreSQL PDO driver |
| `mysqli` | Built-in | MySQL improved extension |
| `pgsql` | Built-in | PostgreSQL extension |
| `redis` | PECL | Redis client extension |
| `apcu` | PECL | User-land data caching |
| `msgpack` | PECL | MessagePack serialization |
| `zip` | Built-in | ZIP archive support |
| `intl` | Built-in | Internationalization functions |
| `bcmath` | Built-in | Arbitrary precision mathematics |
| `gd` | Built-in | Image processing (WebP, JPEG, PNG) |
| `exif` | Built-in | EXIF metadata reading |
| `pcntl` | Built-in | Process control (signals, forking) |
| `sockets` | Built-in | Low-level socket interface |
| `bz2` | Built-in | Bzip2 compression |
| `gmp` | Built-in | Arbitrary precision math |

### Standard Tier Additions

These extensions are added in the standard tier (and inherited by chromium/dev):

| Extension | Source | Description |
|-----------|--------|-------------|
| `mongodb` | PECL | MongoDB driver |
| `imagick` | PECL | ImageMagick bindings |
| `vips` | PECL | libvips image processing |
| `soap` | Built-in | SOAP protocol |
| `xsl` | Built-in | XSL transformations |
| `ldap` | Built-in | LDAP directory services |
| `calendar` | Built-in | Calendar conversion |
| `gettext` | Built-in | GNU translations |
| `shmop` | Built-in | Shared memory operations |
| `sysvmsg` | Built-in | System V message queue |
| `sysvsem` | Built-in | System V semaphore |
| `sysvshm` | Built-in | System V shared memory |

### Tools Included

| Tool | Purpose |
|------|---------|
| Composer 2 | PHP package manager |
| Cbox Init | Process manager |
| curl, wget | HTTP clients |
| git | Version control |
| unzip | Archive extraction |

## Standard Tier Extensions

The Standard tier includes everything in Slim, plus image processing, Node.js, and Bun.

### Additional Extensions (on top of Slim)

| Extension | Type | Purpose |
|-----------|------|---------|
| `imagick` | PECL | ImageMagick for complex image operations |
| `vips` | PECL | High-performance libvips (4-10x faster) |
| `gd` (AVIF) | Built-in | GD rebuilt with AVIF support |

### Additional Tools

| Tool | Purpose |
|------|---------|
| Node.js 22 | JavaScript runtime |
| npm / npx | Node package manager |
| Bun | Fast JavaScript runtime & package manager |
| exiftool | Advanced image metadata |
| ghostscript | PDF/PostScript support |
| librsvg | SVG rendering |
| icu-data-full | Complete ICU locale data |

### Image Format Support (Standard Tier)

| Format | GD | ImageMagick | libvips |
|--------|:--:|:-----------:|:-------:|
| JPEG | ✅ | ✅ | ✅ |
| PNG | ✅ | ✅ | ✅ |
| GIF | ✅ | ✅ | ✅ |
| WebP | ✅ | ✅ | ✅ |
| AVIF | ✅ | ✅ | ✅ |
| HEIC/HEIF | ❌ | ✅ | ✅ |
| PDF | ❌ | ✅ | ❌ |
| SVG | ❌ | ✅ | ✅ |
| TIFF | ❌ | ✅ | ✅ |

## Chromium Tier Extensions

The Chromium tier includes everything in Standard, plus Chromium for browser automation.

### Additional Components (on top of Standard)

| Component | Purpose |
|-----------|---------|
| Chromium | Headless browser |
| nss | Network Security Services |
| harfbuzz | Text shaping |
| ttf-freefont | Free fonts |

### Environment Variables (auto-set)

```text
PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
```

## Dev Tier Extensions

The Dev tier includes everything in Chromium, plus development and profiling tools.

### Additional Extensions (on top of Chromium)

| Extension | Type | Version | Purpose |
|-----------|------|---------|---------|
| `xdebug` | PECL | 3.5.0 | Step debugging, code coverage, profiling |
| `pcov` | PECL | 1.0.12 | Fast code coverage (10x faster than Xdebug) |
| `spx` | GitHub | 0.4.22 | Simple performance profiler with web UI |

### Xdebug Configuration

The dev tier includes pre-configured Xdebug settings:

```ini
xdebug.mode=develop,debug,coverage
xdebug.client_host=host.docker.internal
xdebug.client_port=9003
xdebug.start_with_request=trigger
xdebug.discover_client_host=true
xdebug.log=/tmp/xdebug.log
xdebug.idekey=VSCODE
```

**Xdebug Modes:**
- `off` - Disabled
- `develop` - Development helpers (var_dump improvements)
- `coverage` - Code coverage collection
- `debug` - Step debugging
- `gcstats` - Garbage collection statistics
- `profile` - Profiling
- `trace` - Function tracing

### PCOV Configuration

PCOV is disabled by default (for faster execution). Enable it when running tests:

```ini
pcov.enabled=0
pcov.directory=/var/www/html
```

**Usage:**
```bash
# Enable PCOV for PHPUnit coverage
php -d pcov.enabled=1 vendor/bin/phpunit --coverage-text
```

### SPX Profiler

SPX provides a web-based UI for profiling:

```ini
spx.http_enabled=1
spx.http_key=dev
spx.http_ip_whitelist=*
```

**Access the SPX UI:**
```text
http://your-app/?SPX_KEY=dev&SPX_UI_URI=/
```

### Dev Tier Best Practices

1. **Use PCOV for CI coverage** - It's 10x faster than Xdebug coverage
2. **Disable Xdebug in production** - Dev tier is NOT for production
3. **Use SPX for performance profiling** - More visual than Xdebug profiler
4. **Switch modes as needed** - Only enable what you need

```bash
# Fast coverage in CI
docker run --rm -e XDEBUG_MODE=off \
  -v $(pwd):/var/www/html \
  ghcr.io/cboxdk/php-baseimages/php-fpm:8.4-bookworm-dev \
  php -d pcov.enabled=1 vendor/bin/phpunit --coverage-text

# Step debugging
docker run --rm -e XDEBUG_MODE=debug \
  ghcr.io/cboxdk/php-baseimages/php-fpm:8.4-bookworm-dev \
  php artisan test
```

## Extension Comparison by Tier

| Extension | Slim | Standard | Chromium | Dev |
|-----------|:----:|:--------:|:----:|:---:|
| opcache | ✅ | ✅ | ✅ | ✅ |
| pdo_mysql, pdo_pgsql | ✅ | ✅ | ✅ | ✅ |
| mysqli, pgsql | ✅ | ✅ | ✅ | ✅ |
| redis | ✅ | ✅ | ✅ | ✅ |
| apcu | ✅ | ✅ | ✅ | ✅ |
| msgpack | ✅ | ✅ | ✅ | ✅ |
| intl | ✅ | ✅ | ✅ | ✅ |
| bcmath | ✅ | ✅ | ✅ | ✅ |
| gd (WebP) | ✅ | ✅ | ✅ | ✅ |
| exif | ✅ | ✅ | ✅ | ✅ |
| pcntl | ✅ | ✅ | ✅ | ✅ |
| sockets | ✅ | ✅ | ✅ | ✅ |
| bz2 | ✅ | ✅ | ✅ | ✅ |
| gmp | ✅ | ✅ | ✅ | ✅ |
| zip | ✅ | ✅ | ✅ | ✅ |
| gd (AVIF) | ❌ | ✅ | ✅ | ✅ |
| imagick | ❌ | ✅ | ✅ | ✅ |
| vips | ❌ | ✅ | ✅ | ✅ |
| mongodb | ❌ | ✅ | ✅ | ✅ |
| soap | ❌ | ✅ | ✅ | ✅ |
| xsl | ❌ | ✅ | ✅ | ✅ |
| ldap | ❌ | ✅ | ✅ | ✅ |
| calendar | ❌ | ✅ | ✅ | ✅ |
| gettext | ❌ | ✅ | ✅ | ✅ |
| shmop | ❌ | ✅ | ✅ | ✅ |
| sysvmsg, sysvsem, sysvshm | ❌ | ✅ | ✅ | ✅ |
| **Node.js 22 (+ npm/npx)** | ❌ | ✅ | ✅ | ✅ |
| **Bun** | ❌ | ✅ | ✅ | ✅ |
| **Chromium** | ❌ | ❌ | ✅ | ✅ |
| **Xdebug** | ❌ | ❌ | ❌ | ✅ |
| **PCOV** | ❌ | ❌ | ❌ | ✅ |
| **SPX** | ❌ | ❌ | ❌ | ✅ |

## Extension Versions

All PECL extensions use pinned versions for reproducibility:

| Extension | Version |
|-----------|---------|
| redis | 6.3.0 |
| apcu | 5.1.27 |
| mongodb | 2.1.4 |
| msgpack | 3.0.0 |
| imagick | 3.8.1 |
| vips | 1.0.13 |
| xdebug | 3.5.0 |
| pcov | 1.0.12 |
| spx | 0.4.22 (from GitHub) |

## Checking Installed Extensions

### List All Extensions

```bash
# In running container
docker exec myapp php -m

# One-liner
docker run --rm ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm php -m
```

### Check Specific Extension

```bash
# Check if redis is loaded
docker exec myapp php -m | grep redis

# Get extension version
docker exec myapp php -r "echo phpversion('redis');"
```

### Full Extension Info

```bash
# Detailed extension information
docker exec myapp php -i | grep -A 10 "redis"
```

## Adding Extensions

### PECL Extensions

```dockerfile
FROM ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm

# Install PECL extension
RUN apt-get update && apt-get install -y $PHPIZE_DEPS && \
    pecl install swoole && \
    docker-php-ext-enable swoole && \
    apt-get purge -y --auto-remove $PHPIZE_DEPS && rm -rf /var/lib/apt/lists/*
```

### Core Extensions

```dockerfile
FROM ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm

# Enable a disabled core extension
RUN docker-php-ext-install shmop
```

### System Dependencies

Some extensions require system packages:

```dockerfile
FROM ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.4-bookworm

# Example: Adding additional libraries
RUN apt-get update && apt-get install -y some-package-dev && \
    docker-php-ext-install some-extension
```

## Framework Requirements

### Laravel

All Laravel requirements are satisfied by **Slim tier**:

| Requirement | Extension | Status |
|-------------|-----------|--------|
| PHP >= 8.2 | - | ✅ PHP 8.2, 8.3, 8.4, 8.5 |
| Ctype | ctype | ✅ Built-in |
| cURL | curl | ✅ Built-in |
| DOM | dom | ✅ Built-in |
| Fileinfo | fileinfo | ✅ Built-in |
| Mbstring | mbstring | ✅ Built-in |
| OpenSSL | openssl | ✅ Built-in |
| PDO | pdo_mysql/pgsql | ✅ Included |
| Tokenizer | tokenizer | ✅ Built-in |
| XML | xml | ✅ Built-in |

### Symfony

All Symfony requirements are satisfied by **Slim tier**:

| Requirement | Extension | Status |
|-------------|-----------|--------|
| PHP >= 8.2 | - | ✅ PHP 8.2, 8.3, 8.4, 8.5 |
| Ctype | ctype | ✅ Built-in |
| iconv | iconv | ✅ Built-in |
| JSON | json | ✅ Built-in |
| SimpleXML | simplexml | ✅ Built-in |

### WordPress

All WordPress requirements are satisfied by **Standard tier** (for ImageMagick):

| Requirement | Extension | Status |
|-------------|-----------|--------|
| PHP >= 7.4 | - | ✅ PHP 8.2+ |
| MySQL | mysqli | ✅ Included |
| cURL | curl | ✅ Built-in |
| DOM | dom | ✅ Built-in |
| EXIF | exif | ✅ Included |
| Imagick/GD | gd, imagick | ✅ Standard tier |
| Mbstring | mbstring | ✅ Built-in |
| ZIP | zip | ✅ Included |

### Browsershot / Laravel Dusk

Requires **Chromium tier** for Chromium:

| Requirement | Status |
|-------------|--------|
| Chromium | ✅ Chromium tier |
| Puppeteer env vars | ✅ Auto-configured |

## Troubleshooting

### Extension Not Loading

```bash
# Check PHP error log
docker exec myapp cat /var/log/php/error.log

# Verify extension file exists
docker exec myapp ls /usr/local/lib/php/extensions/
```

### Missing System Dependency

```bash
# Check for missing libraries
docker exec myapp ldd /usr/local/lib/php/extensions/*/redis.so
```

### Version Conflicts

```bash
# Check loaded extension versions
docker exec myapp php -r "foreach(get_loaded_extensions() as \$ext) echo \$ext.': '.phpversion(\$ext).PHP_EOL;"
```

---

**Need a specific extension?** See [Extending Images](../advanced/extending-images) | [Choosing Your Image](../getting-started/choosing-your-image)
