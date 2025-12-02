---
title: "Custom Extensions"
description: "Add PECL extensions, compile from source, and manage extension versions in PHPeek images"
weight: 5
---

# Custom PHP Extensions

PHPeek includes 40+ extensions, but you may need others. This guide covers adding extensions via PECL, compiling from source, and version management.

## Quick Reference

```dockerfile
# PECL extension (most common)
RUN pecl install extension-name && docker-php-ext-enable extension-name

# Core extension (bundled with PHP)
RUN docker-php-ext-install extension-name

# Extension with dependencies
RUN apk add --no-cache dependency-package \
    && pecl install extension-name \
    && docker-php-ext-enable extension-name
```

## PECL Extensions

### Basic Installation

```dockerfile
FROM ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine

# Install build dependencies, extension, enable, cleanup
RUN apk add --no-cache $PHPIZE_DEPS \
    && pecl install swoole \
    && docker-php-ext-enable swoole \
    && apk del $PHPIZE_DEPS
```

### With Version Pinning

```dockerfile
FROM ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine

# Pin specific version for reproducibility
RUN apk add --no-cache $PHPIZE_DEPS \
    && pecl install swoole-5.1.1 \
    && docker-php-ext-enable swoole \
    && apk del $PHPIZE_DEPS
```

### Common PECL Extensions

#### Swoole (Async/Coroutines)

```dockerfile
RUN apk add --no-cache $PHPIZE_DEPS openssl-dev curl-dev \
    && pecl install swoole \
    && docker-php-ext-enable swoole \
    && apk del $PHPIZE_DEPS
```

#### gRPC + Protobuf

```dockerfile
# Note: Works better on Debian due to glibc
FROM ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-debian

RUN apt-get update && apt-get install -y \
    libgrpc-dev libprotobuf-dev protobuf-compiler \
    && pecl install grpc protobuf \
    && docker-php-ext-enable grpc protobuf \
    && rm -rf /var/lib/apt/lists/*
```

#### Memcached

```dockerfile
RUN apk add --no-cache $PHPIZE_DEPS libmemcached-dev zlib-dev \
    && pecl install memcached \
    && docker-php-ext-enable memcached \
    && apk del $PHPIZE_DEPS
```

#### SSH2

```dockerfile
RUN apk add --no-cache $PHPIZE_DEPS libssh2-dev \
    && pecl install ssh2 \
    && docker-php-ext-enable ssh2 \
    && apk del $PHPIZE_DEPS
```

#### AMQP (RabbitMQ)

```dockerfile
RUN apk add --no-cache $PHPIZE_DEPS rabbitmq-c-dev \
    && pecl install amqp \
    && docker-php-ext-enable amqp \
    && apk del $PHPIZE_DEPS
```

#### Event (libevent)

```dockerfile
RUN apk add --no-cache $PHPIZE_DEPS libevent-dev openssl-dev \
    && pecl install event \
    && docker-php-ext-enable event \
    && apk del $PHPIZE_DEPS
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

Already included in PHPeek:
- bcmath, calendar, exif, gettext, intl, opcache, pcntl, pdo_mysql, pdo_pgsql, sockets, zip

Can be added if needed:
- dba, enchant, ffi, ftp, oci8, odbc, pdo_odbc, pspell, shmop, snmp, sysvmsg, sysvsem, sysvshm, tidy

## Compiling from Source

For extensions not on PECL or needing custom options:

### Example: OpenSwoole with Custom Options

```dockerfile
FROM ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine

RUN apk add --no-cache $PHPIZE_DEPS git openssl-dev curl-dev \
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
    && apk del $PHPIZE_DEPS git
```

### Example: Xhprof (Facebook's Profiler)

```dockerfile
RUN apk add --no-cache $PHPIZE_DEPS git \
    && git clone https://github.com/longxinH/xhprof.git \
    && cd xhprof/extension \
    && phpize \
    && ./configure \
    && make \
    && make install \
    && docker-php-ext-enable xhprof \
    && cd ../.. && rm -rf xhprof \
    && apk del $PHPIZE_DEPS git
```

## Debian vs Alpine

Some extensions compile better on Debian (glibc):

### Extensions That May Need Debian

| Extension | Alpine | Debian |
|-----------|--------|--------|
| grpc | Issues | Works |
| oci8 | Not supported | Works |
| sqlsrv | Issues | Works |
| pdo_sqlsrv | Issues | Works |
| newrelic | Not supported | Works |

### Debian Example

```dockerfile
FROM ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-debian

RUN apt-get update && apt-get install -y \
    build-essential \
    && pecl install grpc \
    && docker-php-ext-enable grpc \
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
docker run --rm -it ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine sh
apk add $PHPIZE_DEPS
pecl install extension-name
```

### Missing Dependencies

```bash
# Alpine: Search for package
apk search libname

# Debian: Search for package
apt-cache search libname
```

### Common Dependency Mappings

| Extension | Alpine Package | Debian Package |
|-----------|---------------|----------------|
| gd | freetype-dev libpng-dev | libfreetype6-dev libpng-dev |
| imagick | imagemagick-dev | libmagickwand-dev |
| memcached | libmemcached-dev | libmemcached-dev |
| mongodb | openssl-dev | libssl-dev |
| ssh2 | libssh2-dev | libssh2-1-dev |
| amqp | rabbitmq-c-dev | librabbitmq-dev |
| event | libevent-dev | libevent-dev |

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
FROM ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-alpine

# Build dependencies
RUN apk add --no-cache $PHPIZE_DEPS openssl-dev curl-dev

# Swoole with options
RUN pecl install swoole-5.1.1 \
    && docker-php-ext-enable swoole \
    && echo "swoole.use_shortname=Off" > /usr/local/etc/php/conf.d/99-swoole.ini

# Cleanup
RUN apk del $PHPIZE_DEPS

COPY . /var/www/html
RUN composer install --no-dev --optimize-autoloader
```

### API with gRPC + Protobuf

```dockerfile
FROM ghcr.io/gophpeek/baseimages/php-fpm-nginx:8.4-debian

RUN apt-get update && apt-get install -y \
    libgrpc-dev libprotobuf-dev protobuf-compiler \
    && pecl install grpc-1.60.0 protobuf-3.25.1 \
    && docker-php-ext-enable grpc protobuf \
    && rm -rf /var/lib/apt/lists/*

COPY . /var/www/html
RUN composer install --no-dev --optimize-autoloader
```

## Next Steps

- **[Extending Images](extending-images)** - Complete customization guide
- **[Custom Initialization](custom-initialization)** - Startup scripts
- **[Performance Tuning](performance-tuning)** - Optimize your extensions
