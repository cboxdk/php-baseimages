---
title: "Available Extensions"
description: "Complete list of 40+ pre-installed PHP extensions in PHPeek base images with version information"
weight: 30
---

# Available Extensions

Complete reference of all PHP extensions included in PHPeek base images.

## Extension Overview

PHPeek images come with **40+ extensions** pre-installed, organized into categories:

| Category | Extensions | Purpose |
|----------|-----------|---------|
| Core PHP | opcache, apcu, bcmath, intl | Performance and internationalization |
| Database | pdo_mysql, pdo_pgsql, mysqli, pgsql, redis | Database connectivity |
| Images | gd, imagick, exif | Image processing |
| Compression | zip, bz2, zlib | File compression |
| Communication | sockets, pcntl, posix | Process and network |
| XML/SOAP | xml, xsl, soap, xmlreader, xmlwriter | Data exchange |
| Enterprise | ldap, imap | Enterprise integration |

## Full Edition Extensions

The Full Edition includes all extensions for maximum compatibility.

### Core & Performance

| Extension | Full | Minimal | Description |
|-----------|------|---------|-------------|
| `opcache` | Built-in | Built-in | Bytecode caching for performance |
| `apcu` | PECL | PECL | User-land data caching |
| `bcmath` | Built-in | Built-in | Arbitrary precision mathematics |
| `intl` | Built-in | Built-in | Internationalization functions |
| `mbstring` | Built-in | Built-in | Multibyte string handling |

### Database Extensions

| Extension | Full | Minimal | Description |
|-----------|------|---------|-------------|
| `pdo` | Built-in | Built-in | PHP Data Objects base |
| `pdo_mysql` | Built-in | Built-in | MySQL PDO driver |
| `pdo_pgsql` | Built-in | Built-in | PostgreSQL PDO driver |
| `pdo_sqlite` | Built-in | Built-in | SQLite PDO driver |
| `mysqli` | Built-in | Built-in | MySQL improved extension |
| `pgsql` | Built-in | Built-in | PostgreSQL extension |
| `redis` | PECL | PECL | Redis client extension |
| `mongodb` | PECL | - | MongoDB driver (Full only) |

### Image Processing

| Extension | Full | Minimal | Description |
|-----------|------|---------|-------------|
| `gd` | Built-in | Built-in | Image creation and manipulation |
| `imagick` | PECL | - | ImageMagick binding (Full only) |
| `vips` | PECL | - | High-performance libvips binding (Full only) |
| `exif` | Built-in | Built-in | EXIF metadata reading |

#### Format Support Matrix

| Format | GD | ImageMagick | libvips | Notes |
|--------|:--:|:-----------:|:-------:|-------|
| JPEG | ✓ | ✓ | ✓ | Universal support |
| PNG | ✓ | ✓ | ✓ | With transparency |
| GIF | ✓ | ✓ | ✓ | Animated GIF support |
| WebP | ✓ | ✓ | ✓ | Modern web format |
| AVIF | ✓ | ✓ | ✓ | Next-gen compression |
| HEIC/HEIF | - | ✓ | ✓ | iPhone photos (requires libheif) |
| PDF | - | ✓ | - | Read/write via Ghostscript |
| SVG | - | ✓ | ✓ | Read-only (security) |
| BMP | ✓ | ✓ | ✓ | Legacy format |
| TIFF | - | ✓ | ✓ | Professional imaging |

#### Pre-installed Image Processing Tools

| Tool | Purpose | Usage |
|------|---------|-------|
| `exiftool` | Image metadata extraction | `exiftool image.jpg` |
| `chromium` | PDF generation via Browsershot | Puppeteer/Browsershot |
| `ghostscript` | PDF/PostScript processing | ImageMagick PDF support |

> **Note**: HEIC/HEIF support requires `libheif` which is pre-installed. PDF operations require Ghostscript which is also pre-installed. See [Image Processing Guide](../guides/image-processing) for usage examples.

### Compression

| Extension | Full | Minimal | Description |
|-----------|------|---------|-------------|
| `zip` | Built-in | Built-in | ZIP archive support |
| `bz2` | Built-in | - | Bzip2 compression (Full only) |
| `zlib` | Built-in | Built-in | Gzip compression |

### Process & Communication

| Extension | Full | Minimal | Description |
|-----------|------|---------|-------------|
| `pcntl` | Built-in | Built-in | Process control (signals, forking) |
| `posix` | Built-in | Built-in | POSIX functions |
| `sockets` | Built-in | Built-in | Low-level socket interface |

### XML & Data Exchange

| Extension | Full | Minimal | Description |
|-----------|------|---------|-------------|
| `xml` | Built-in | Built-in | XML parsing |
| `xmlreader` | Built-in | Built-in | XML pull parser |
| `xmlwriter` | Built-in | Built-in | XML stream writing |
| `xsl` | Built-in | - | XSL transformations (Full only) |
| `soap` | Built-in | - | SOAP protocol (Full only) |
| `simplexml` | Built-in | Built-in | SimpleXML interface |
| `dom` | Built-in | Built-in | DOM manipulation |

### Enterprise Integration

| Extension | Full | Minimal | Description |
|-----------|------|---------|-------------|
| `ldap` | Built-in | - | LDAP directory services (Full only) |
| `imap` | Built-in | - | IMAP email protocol (Full only) |

### Utility Extensions

| Extension | Full | Minimal | Description |
|-----------|------|---------|-------------|
| `calendar` | Built-in | - | Calendar conversion (Full only) |
| `gettext` | Built-in | - | Gettext localization (Full only) |
| `ctype` | Built-in | Built-in | Character type checking |
| `curl` | Built-in | Built-in | URL transfer library |
| `fileinfo` | Built-in | Built-in | File information |
| `ftp` | Built-in | - | FTP protocol (Full only) |
| `iconv` | Built-in | Built-in | Character encoding conversion |
| `json` | Built-in | Built-in | JSON encoding/decoding |
| `openssl` | Built-in | Built-in | OpenSSL cryptography |
| `phar` | Built-in | Built-in | PHP Archive support |
| `readline` | Built-in | Built-in | Interactive shell |
| `sodium` | Built-in | Built-in | Modern cryptography |
| `tokenizer` | Built-in | Built-in | PHP tokenizer |

## Minimal Edition Extensions

The Minimal Edition includes **17 essential extensions** optimized for Laravel:

```
apcu, bcmath, ctype, curl, dom, exif, fileinfo, gd, iconv, intl,
json, mbstring, openssl, pcntl, pdo_mysql, pdo_pgsql, pdo_sqlite,
phar, posix, redis, simplexml, sockets, sodium, tokenizer, xml,
xmlreader, xmlwriter, zip, zlib
```

**Minimal-only difference**: OPcache is **disabled by default** (explicit enable recommended).

## Development Extensions

Development images (`-dev` suffix) include additional debugging tools:

| Extension | Purpose | Configuration |
|-----------|---------|---------------|
| `xdebug` | Step debugging, coverage, profiling | `XDEBUG_MODE=debug,develop,coverage` |

### Xdebug Configuration

```ini
; Default development settings
xdebug.mode=debug,develop,coverage
xdebug.client_host=host.docker.internal
xdebug.client_port=9003
xdebug.start_with_request=yes
```

## Extension Versions by PHP Version

### PHP 8.4

| Extension | Version | Notes |
|-----------|---------|-------|
| Redis | 6.x | Latest stable |
| APCu | 5.1.x | Latest stable |
| Imagick | 3.7.x | Latest stable |
| MongoDB | 1.19.x | Latest stable |
| Xdebug | 3.4.x | Dev images only |

### PHP 8.3

| Extension | Version | Notes |
|-----------|---------|-------|
| Redis | 6.x | Latest stable |
| APCu | 5.1.x | Latest stable |
| Imagick | 3.7.x | Latest stable |
| MongoDB | 1.19.x | Latest stable |
| Xdebug | 3.3.x | Dev images only |

### PHP 8.2

| Extension | Version | Notes |
|-----------|---------|-------|
| Redis | 6.x | Latest stable |
| APCu | 5.1.x | Latest stable |
| Imagick | 3.7.x | Latest stable |
| MongoDB | 1.18.x | Latest stable |
| Xdebug | 3.3.x | Dev images only |

## Checking Installed Extensions

### List All Extensions

```bash
# In running container
docker exec myapp php -m

# One-liner
docker run --rm ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine php -m
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
FROM ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine

# Install PECL extension
RUN apk add --no-cache $PHPIZE_DEPS && \
    pecl install swoole && \
    docker-php-ext-enable swoole && \
    apk del $PHPIZE_DEPS
```

### Core Extensions

```dockerfile
FROM ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine

# Enable a disabled core extension
RUN docker-php-ext-install shmop
```

### System Dependencies

Some extensions require system packages:

```dockerfile
FROM ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine

# Example: Installing GMP
RUN apk add --no-cache gmp-dev && \
    docker-php-ext-install gmp
```

## Framework Requirements

### Laravel

All Laravel requirements are satisfied:

| Requirement | Extension | Status |
|-------------|-----------|--------|
| PHP >= 8.2 | - | PHP 8.2, 8.3, 8.4 available |
| Ctype | ctype | Included |
| cURL | curl | Included |
| DOM | dom | Included |
| Fileinfo | fileinfo | Included |
| Filter | filter | Built-in |
| Hash | hash | Built-in |
| Mbstring | mbstring | Included |
| OpenSSL | openssl | Included |
| PCRE | pcre | Built-in |
| PDO | pdo, pdo_mysql/pgsql | Included |
| Session | session | Built-in |
| Tokenizer | tokenizer | Included |
| XML | xml | Included |

### Symfony

All Symfony requirements are satisfied:

| Requirement | Extension | Status |
|-------------|-----------|--------|
| PHP >= 8.2 | - | PHP 8.2, 8.3, 8.4 available |
| Ctype | ctype | Included |
| iconv | iconv | Included |
| JSON | json | Included |
| PCRE | pcre | Built-in |
| Session | session | Built-in |
| SimpleXML | simplexml | Included |
| Tokenizer | tokenizer | Included |

### WordPress

All WordPress requirements are satisfied:

| Requirement | Extension | Status |
|-------------|-----------|--------|
| PHP >= 7.4 | - | PHP 8.2+ available |
| MySQL | mysqli, pdo_mysql | Included |
| JSON | json | Included |
| cURL | curl | Included |
| DOM | dom | Included |
| EXIF | exif | Included |
| Fileinfo | fileinfo | Included |
| Imagick/GD | gd, imagick | Included |
| Mbstring | mbstring | Included |
| OpenSSL | openssl | Included |
| XML | xml | Included |
| Zip | zip | Included |

## Troubleshooting

### Extension Not Loading

```bash
# Check PHP error log
docker exec myapp cat /var/log/php-fpm/error.log

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

**Need a specific extension?** See [Extending Images](../advanced/extending-images) | [Custom Extensions](../advanced/custom-extensions)
