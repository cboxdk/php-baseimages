---
title: "Available Extensions"
description: "Complete list of PHP extensions by image tier - Slim, Standard, and Full"
weight: 30
---

# Available Extensions

Complete reference of all PHP extensions included in Cbox base images by tier.

## Extension Overview by Tier

Cbox images come in three tiers with different extension sets:

| Tier | Extensions | Best For |
|------|-----------|----------|
| **Slim** | 25+ core | APIs, microservices |
| **Standard** | Slim + ImageMagick, vips, Node.js | Most apps (DEFAULT) |
| **Full** | Standard + Chromium | Browsershot, Dusk, PDF |

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
| `mongodb` | PECL | MongoDB driver |
| `igbinary` | PECL | Fast serialization |
| `msgpack` | PECL | MessagePack serialization |
| `grpc` | PECL | gRPC protocol support |
| `zip` | Built-in | ZIP archive support |
| `intl` | Built-in | Internationalization functions |
| `bcmath` | Built-in | Arbitrary precision mathematics |
| `gd` | Built-in | Image processing (WebP, JPEG, PNG) |
| `exif` | Built-in | EXIF metadata reading |
| `pcntl` | Built-in | Process control (signals, forking) |
| `sockets` | Built-in | Low-level socket interface |
| `soap` | Built-in | SOAP protocol |
| `xsl` | Built-in | XSL transformations |
| `ldap` | Built-in | LDAP directory services |
| `bz2` | Built-in | Bzip2 compression |
| `calendar` | Built-in | Calendar conversion |
| `gettext` | Built-in | GNU translations |
| `gmp` | Built-in | Arbitrary precision math |
| `shmop` | Built-in | Shared memory operations |
| `sysvmsg` | Built-in | System V message queue |
| `sysvsem` | Built-in | System V semaphore |
| `sysvshm` | Built-in | System V shared memory |

### Tools Included

| Tool | Purpose |
|------|---------|
| Composer 2 | PHP package manager |
| Cbox PM | Process manager |
| curl, wget | HTTP clients |
| git | Version control |
| unzip | Archive extraction |

## Standard Tier Extensions

The Standard tier includes everything in Slim, plus image processing and Node.js.

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
| npm | Node package manager |
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

## Full Tier Extensions

The Full tier includes everything in Standard, plus Chromium for browser automation.

### Additional Components (on top of Standard)

| Component | Purpose |
|-----------|---------|
| Chromium | Headless browser |
| nss | Network Security Services |
| harfbuzz | Text shaping |
| ttf-freefont | Free fonts |

### Environment Variables (auto-set)

```
PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
```

## Extension Comparison by Tier

| Extension | Slim | Standard | Full |
|-----------|:----:|:--------:|:----:|
| opcache | ✅ | ✅ | ✅ |
| pdo_mysql, pdo_pgsql | ✅ | ✅ | ✅ |
| mysqli, pgsql | ✅ | ✅ | ✅ |
| redis | ✅ | ✅ | ✅ |
| apcu | ✅ | ✅ | ✅ |
| mongodb | ✅ | ✅ | ✅ |
| grpc | ✅ | ✅ | ✅ |
| igbinary, msgpack | ✅ | ✅ | ✅ |
| intl | ✅ | ✅ | ✅ |
| bcmath | ✅ | ✅ | ✅ |
| gd (WebP) | ✅ | ✅ | ✅ |
| gd (AVIF) | ❌ | ✅ | ✅ |
| imagick | ❌ | ✅ | ✅ |
| vips | ❌ | ✅ | ✅ |
| exif | ✅ | ✅ | ✅ |
| pcntl | ✅ | ✅ | ✅ |
| sockets | ✅ | ✅ | ✅ |
| soap | ✅ | ✅ | ✅ |
| xsl | ✅ | ✅ | ✅ |
| ldap | ✅ | ✅ | ✅ |
| bz2 | ✅ | ✅ | ✅ |
| zip | ✅ | ✅ | ✅ |
| **Node.js 22** | ❌ | ✅ | ✅ |
| **Chromium** | ❌ | ❌ | ✅ |

## Extension Versions

All PECL extensions use pinned versions for reproducibility:

| Extension | Version |
|-----------|---------|
| redis | 6.3.0 |
| apcu | 5.1.27 |
| mongodb | 2.1.4 |
| igbinary | 3.2.16 |
| msgpack | 3.0.0 |
| imagick | 3.8.1 |
| vips | 1.0.13 |
| grpc | 1.72.0 |

## Checking Installed Extensions

### List All Extensions

```bash
# In running container
docker exec myapp php -m

# One-liner
docker run --rm ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm php -m
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
FROM ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm

# Install PECL extension
RUN apt-get update && apt-get install -y $PHPIZE_DEPS && \
    pecl install swoole && \
    docker-php-ext-enable swoole && \
    apk del $PHPIZE_DEPS
```

### Core Extensions

```dockerfile
FROM ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm

# Enable a disabled core extension
RUN docker-php-ext-install shmop
```

### System Dependencies

Some extensions require system packages:

```dockerfile
FROM ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm

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

Requires **Full tier** for Chromium:

| Requirement | Status |
|-------------|--------|
| Chromium | ✅ Full tier |
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

**Need a specific extension?** See [Extending Images](../advanced/extending-images.md) | [Image Tiers Comparison](editions-comparison.md)
