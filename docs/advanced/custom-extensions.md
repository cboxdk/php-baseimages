---
title: "Custom Extensions"
description: "Add PECL extensions, compile from source, and manage extension versions in Cbox images"
weight: 5
---

# Custom PHP Extensions

Cbox includes 40+ extensions, but you may need others. This guide covers adding extensions via PECL, compiling from source, and version management.

## Quick Reference

```dockerfile
# PECL extension (most common)
RUN pecl install extension-name && docker-php-ext-enable extension-name

# Core extension (bundled with PHP)
RUN docker-php-ext-install extension-name

# Extension with dependencies
RUN apt-get update && apt-get install -y dependency-package \
    && pecl install extension-name \
    && docker-php-ext-enable extension-name
```

## PECL Extensions

### Basic Installation

```dockerfile
FROM ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm

# Install build dependencies, extension, enable, cleanup
RUN apt-get update && apt-get install -y $PHPIZE_DEPS \
    && pecl install swoole \
    && docker-php-ext-enable swoole \
    && apt-get purge -y --auto-remove $PHPIZE_DEPS \
    && rm -rf /var/lib/apt/lists/*
```

### With Version Pinning

```dockerfile
FROM ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm

# Pin specific version for reproducibility
RUN apt-get update && apt-get install -y $PHPIZE_DEPS \
    && pecl install swoole-5.1.1 \
    && docker-php-ext-enable swoole \
    && apt-get purge -y --auto-remove $PHPIZE_DEPS \
    && rm -rf /var/lib/apt/lists/*
```

### Common PECL Extensions

#### Swoole (Async/Coroutines)

```dockerfile
RUN apt-get update && apt-get install -y $PHPIZE_DEPS libssl-dev libcurl4-openssl-dev \
    && pecl install swoole \
    && docker-php-ext-enable swoole \
    && apt-get purge -y --auto-remove $PHPIZE_DEPS \
    && rm -rf /var/lib/apt/lists/*
```

#### gRPC + Protobuf

```dockerfile
FROM ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm

RUN apt-get update && apt-get install -y \
    libgrpc-dev libprotobuf-dev protobuf-compiler \
    && pecl install grpc protobuf \
    && docker-php-ext-enable grpc protobuf \
    && rm -rf /var/lib/apt/lists/*
```

#### Memcached

```dockerfile
RUN apt-get update && apt-get install -y $PHPIZE_DEPS libmemcached-dev zlib1g-dev \
    && pecl install memcached \
    && docker-php-ext-enable memcached \
    && apt-get purge -y --auto-remove $PHPIZE_DEPS \
    && rm -rf /var/lib/apt/lists/*
```

#### SSH2

```dockerfile
RUN apt-get update && apt-get install -y $PHPIZE_DEPS libssh2-1-dev \
    && pecl install ssh2 \
    && docker-php-ext-enable ssh2 \
    && apt-get purge -y --auto-remove $PHPIZE_DEPS \
    && rm -rf /var/lib/apt/lists/*
```

#### AMQP (RabbitMQ)

```dockerfile
RUN apt-get update && apt-get install -y $PHPIZE_DEPS librabbitmq-dev \
    && pecl install amqp \
    && docker-php-ext-enable amqp \
    && apt-get purge -y --auto-remove $PHPIZE_DEPS \
    && rm -rf /var/lib/apt/lists/*
```

#### Event (libevent)

```dockerfile
RUN apt-get update && apt-get install -y $PHPIZE_DEPS libevent-dev libssl-dev \
    && pecl install event \
    && docker-php-ext-enable event \
    && apt-get purge -y --auto-remove $PHPIZE_DEPS \
    && rm -rf /var/lib/apt/lists/*
```

## Core Extensions

Extensions bundled with PHP source (use `docker-php-ext-install`):

```dockerfile
# Single extension
RUN docker-php-ext-install sockets

# Multiple extensions
RUN docker-php-ext-install pdo_mysql mysqli

# Extension requiring configuration
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install gd
```

### Available Core Extensions

Already included in Cbox:
- bcmath, calendar, exif, gettext, intl, opcache, pcntl, pdo_mysql, pdo_pgsql, sockets, zip

Can be added if needed:
- dba, enchant, ffi, ftp, oci8, odbc, pdo_odbc, pspell, shmop, snmp, sysvmsg, sysvsem, sysvshm, tidy

## Compiling from Source

For extensions not on PECL or needing custom options:

### Example: OpenSwoole with Custom Options

```dockerfile
FROM ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm

RUN apt-get update && apt-get install -y $PHPIZE_DEPS git libssl-dev libcurl4-openssl-dev \
    && git clone https://github.com/openswoole/swoole-src.git \
    && cd swoole-src \
    && phpize \
    && ./configure \
        --enable-openssl \
        --enable-http2 \
        --enable-mysqlnd \
        --enable-sockets \
    && make -j$(nproc) \
    && make install \
    && docker-php-ext-enable openswoole \
    && cd .. && rm -rf swoole-src \
    && apt-get purge -y --auto-remove $PHPIZE_DEPS git \
    && rm -rf /var/lib/apt/lists/*
```

### Example: Xhprof (Facebook's Profiler)

```dockerfile
RUN apt-get update && apt-get install -y $PHPIZE_DEPS git \
    && git clone https://github.com/longxinH/xhprof.git \
    && cd xhprof/extension \
    && phpize \
    && ./configure \
    && make \
    && make install \
    && docker-php-ext-enable xhprof \
    && cd ../.. && rm -rf xhprof \
    && apt-get purge -y --auto-remove $PHPIZE_DEPS git \
    && rm -rf /var/lib/apt/lists/*
```

## Extension Configuration

### php.ini Settings

```dockerfile
# Create custom ini file
RUN echo "extension_setting=value" > /usr/local/etc/php/conf.d/99-extension.ini
```

### Example: Swoole Configuration

```dockerfile
RUN echo "swoole.use_shortname=Off" > /usr/local/etc/php/conf.d/99-swoole.ini
```

### Example: OPcache for Production

```dockerfile
RUN echo "opcache.enable=1" > /usr/local/etc/php/conf.d/99-opcache.ini \
    && echo "opcache.memory_consumption=256" >> /usr/local/etc/php/conf.d/99-opcache.ini \
    && echo "opcache.validate_timestamps=0" >> /usr/local/etc/php/conf.d/99-opcache.ini
```

## Version Pinning Best Practices

### Pin Versions in Production

```dockerfile
# Good: Pin specific versions
RUN pecl install redis-6.0.2 \
    && pecl install igbinary-3.2.15 \
    && pecl install msgpack-3.0.0

# Bad: Use latest (unpredictable)
RUN pecl install redis igbinary msgpack
```

### Use Build Arguments

```dockerfile
ARG REDIS_VERSION=6.0.2
ARG SWOOLE_VERSION=5.1.1

RUN pecl install redis-${REDIS_VERSION} \
    && pecl install swoole-${SWOOLE_VERSION}
```

### Override at Build Time

```bash
docker build \
  --build-arg REDIS_VERSION=6.1.0 \
  --build-arg SWOOLE_VERSION=5.2.0 \
  -t myapp .
```

## Testing Extensions

### Verify Installation

```bash
# Check extension loaded
docker run --rm myapp php -m | grep swoole

# Check extension version
docker run --rm myapp php -r "echo phpversion('swoole');"

# Check extension config
docker run --rm myapp php -i | grep swoole
```

### Automated Testing

```dockerfile
# Add health check for extension
HEALTHCHECK --interval=30s --timeout=3s \
    CMD php -r "if (!extension_loaded('swoole')) exit(1);" || exit 1
```

## Troubleshooting

### Extension Won't Compile

```bash
# Check build logs
docker build --progress=plain -t test .

# Interactive debugging
docker run --rm -it ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm sh
apt-get update && apt-get install -y build-essential
pecl install extension-name
```

### Missing Dependencies

```bash
# Search for Debian packages
apt-cache search libname

# Or use apt-file to find which package provides a file
apt-file search library-name
```

### Common Dependency Mappings (Debian)

| Extension | Debian Package |
|-----------|----------------|
| gd | libfreetype6-dev libpng-dev |
| imagick | libmagickwand-dev |
| memcached | libmemcached-dev |
| mongodb | libssl-dev |
| ssh2 | libssh2-1-dev |
| amqp | librabbitmq-dev |
| event | libevent-dev |
| curl | libcurl4-openssl-dev |
| zip | libzip-dev |

### Extension Conflicts

```dockerfile
# Load order matters for some extensions
# igbinary should load before redis (for serialization)
RUN pecl install igbinary \
    && docker-php-ext-enable igbinary \
    && pecl install --configureoptions 'enable-redis-igbinary="yes"' redis \
    && docker-php-ext-enable redis
```

## Complete Examples

### Laravel with Swoole + Redis

```dockerfile
FROM ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm

# Build dependencies
RUN apt-get update && apt-get install -y $PHPIZE_DEPS libssl-dev libcurl4-openssl-dev \
    && pecl install swoole-5.1.1 \
    && docker-php-ext-enable swoole \
    && echo "swoole.use_shortname=Off" > /usr/local/etc/php/conf.d/99-swoole.ini \
    && apt-get purge -y --auto-remove $PHPIZE_DEPS \
    && rm -rf /var/lib/apt/lists/*

COPY . /var/www/html
RUN composer install --no-dev --optimize-autoloader
```

### API with gRPC + Protobuf

```dockerfile
FROM ghcr.io/cboxdk/baseimages/php-fpm-nginx:8.4-bookworm

RUN apt-get update && apt-get install -y \
    libgrpc-dev libprotobuf-dev protobuf-compiler \
    && pecl install grpc-1.60.0 protobuf-3.25.1 \
    && docker-php-ext-enable grpc protobuf \
    && rm -rf /var/lib/apt/lists/*

COPY . /var/www/html
RUN composer install --no-dev --optimize-autoloader
```

## Next Steps

- **[Extending Images](extending-images.md)** - Complete customization guide
- **[Custom Initialization](custom-initialization.md)** - Startup scripts
- **[Performance Tuning](performance-tuning.md)** - Optimize your extensions
