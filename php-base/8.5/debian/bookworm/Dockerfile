# ============================================================================
# PHPeek PHP Base Image - Debian 8.5 (Bookworm) - Release Candidate
# ============================================================================
# LAYER 2: Single source of truth for all PHP extensions, Composer, Node, PHPeek PM
# All other images (php-cli, php-fpm, php-fpm-nginx, php-swoole, etc.) extend this
# ============================================================================
# NOTE: PHP 8.5 is currently in Release Candidate stage - use for testing only
# Alpine variant not available due to PHP 8.5 RC build issues on musl libc
# ============================================================================

# ============================================================================
# Extension Versions (from versions.json - passed as build args by CI)
# ============================================================================
ARG REDIS_VERSION=6.3.0
ARG IMAGICK_VERSION=3.8.1
ARG APCU_VERSION=5.1.27
ARG MONGODB_VERSION=2.1.4
ARG IGBINARY_VERSION=3.2.16
ARG MSGPACK_VERSION=3.0.0
ARG VIPS_VERSION=1.0.13

# Stage 1: Get Node.js from official image
ARG NODE_VERSION=22
FROM node:${NODE_VERSION}-bookworm-slim AS node

# Stage 2: PHP CLI base (NOT FPM - that's a separate layer)
FROM php:8.5-rc-cli-bookworm

LABEL org.opencontainers.image.title="PHPeek PHP Base 8.5 Debian"
LABEL org.opencontainers.image.description="Base PHP image with all extensions, Composer, Node.js, and PHPeek PM"
LABEL org.opencontainers.image.vendor="PHPeek"
LABEL org.opencontainers.image.source="https://github.com/phpeek/baseimages"

# Re-declare ARGs after FROM (they don't persist)
ARG REDIS_VERSION
ARG IMAGICK_VERSION
ARG APCU_VERSION
ARG MONGODB_VERSION
ARG IGBINARY_VERSION
ARG MSGPACK_VERSION
ARG VIPS_VERSION

# Copy Node.js binaries from official node image
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules

# Create npm/npx symlinks
RUN ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -sf /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

# ============================================================================
# System Dependencies (Runtime only)
# ============================================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Essential tools
    bash curl wget git unzip procps \
    # Cron for Laravel Scheduler
    cron \
    # Runtime libraries (NOT -dev packages)
    libpng16-16 libjpeg62-turbo libfreetype6 \
    libwebp7 libavif15 libmagickwand-6.q16-6 \
    # HEIC/HEIF support for ImageMagick
    libheif1 \
    # PDF support for ImageMagick (Ghostscript)
    ghostscript \
    # SVG support for ImageMagick
    librsvg2-bin \
    libvips42 libvips-tools \
    libpq5 libicu72 libzip4 \
    libxml2 libxslt1.1 libldap-2.5-0 \
    libbz2-1.0 libonig5 libreadline8 libgmp10 \
    # Exiftool for image metadata
    libimage-exiftool-perl \
    # Chromium for Browsershot/Puppeteer PDF generation
    chromium \
    fonts-liberation \
    libnss3 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    && rm -rf /var/lib/apt/lists/*

# Set Puppeteer to use installed Chromium
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium

# ============================================================================
# PHP Extensions (40+)
# NOTE: PHP 8.5 RC has issues with parallel extension builds, using -j1
# opcache is already enabled in PHP 8.5 RC base image
# ============================================================================

# Install build dependencies (will be removed after compilation)
RUN apt-get update && apt-get install -y --no-install-recommends \
    $PHPIZE_DEPS \
    libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
    libwebp-dev libavif-dev libmagickwand-dev \
    libvips-dev \
    libpq-dev libicu-dev libzip-dev \
    libxml2-dev libxslt1-dev libldap2-dev \
    libbz2-dev libonig-dev libreadline-dev libgmp-dev \
    && rm -rf /var/lib/apt/lists/*

# Configure GD with WebP/AVIF support
RUN docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg \
    --with-webp \
    --with-avif

# Install core PHP extensions (one at a time for PHP 8.5 RC stability)
RUN docker-php-ext-install -j1 pdo_mysql pdo_pgsql mysqli pgsql && \
    docker-php-ext-install -j1 zip intl bcmath gd exif && \
    docker-php-ext-install -j1 pcntl sockets soap xsl ldap bz2 && \
    docker-php-ext-install -j1 calendar gettext shmop sysvmsg sysvsem sysvshm gmp

# Install PECL extensions with PINNED versions (igbinary first for redis serialization)
# NOTE: PHP 8.5 requires igbinary-beta (3.2.17RC1+) for compatibility
RUN pecl install igbinary-beta && \
    docker-php-ext-enable igbinary && \
    pecl install redis-${REDIS_VERSION} --configureoptions 'enable-igbinary-serializer="yes"' && \
    pecl install imagick-${IMAGICK_VERSION} && \
    pecl install apcu-${APCU_VERSION} && \
    pecl install msgpack-${MSGPACK_VERSION} && \
    pecl install mongodb-${MONGODB_VERSION} && \
    pecl install vips-${VIPS_VERSION} && \
    docker-php-ext-enable redis imagick apcu msgpack mongodb vips

# ============================================================================
# Cleanup: Remove build deps, caches, and unnecessary files for slim image
# ============================================================================
RUN apt-get purge -y --auto-remove $PHPIZE_DEPS \
    libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
    libwebp-dev libavif-dev libmagickwand-dev \
    libvips-dev \
    libpq-dev libicu-dev libzip-dev \
    libxml2-dev libxslt1-dev libldap2-dev \
    libbz2-dev libonig-dev libreadline-dev libgmp-dev && \
    rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/* \
    /usr/share/doc /usr/share/man /usr/share/locale/* \
    /root/.pearrc /root/.pear && \
    # Strip debug symbols from PHP extensions
    find /usr/local/lib/php/extensions -name '*.so' -exec strip --strip-all {} \; 2>/dev/null || true

# ============================================================================
# Composer
# ============================================================================
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# ============================================================================
# PHPeek PM (Process Manager)
# ============================================================================
ARG PHPEEK_PM_VERSION=1.0.0
ARG PHPEEK_PM_SHA256_AMD64=d9c52e1bc4cc497b900cf401a3f7640e08dd44d1e3612bff8aa8e41d1cbbe4a7
ARG PHPEEK_PM_SHA256_ARM64=3482f1b3c76a94d41fb24afcb6f28500e4de3d4ce0e11b625bb48b764a5ba624
ARG TARGETPLATFORM

COPY phpeek-pm/binaries/phpeek-pm-linux-amd64 /tmp/phpeek-pm-linux-amd64
COPY phpeek-pm/binaries/phpeek-pm-linux-arm64 /tmp/phpeek-pm-linux-arm64

RUN set -eux; \
    case "${TARGETPLATFORM}" in \
        linux/amd64) \
            PHPEEK_PM_ARCH="amd64"; \
            PHPEEK_PM_CHECKSUM="${PHPEEK_PM_SHA256_AMD64}" ;; \
        linux/arm64) \
            PHPEEK_PM_ARCH="arm64"; \
            PHPEEK_PM_CHECKSUM="${PHPEEK_PM_SHA256_ARM64}" ;; \
        *) \
            echo "Unsupported platform: ${TARGETPLATFORM}"; \
            exit 1 ;; \
    esac; \
    echo "${PHPEEK_PM_CHECKSUM}  /tmp/phpeek-pm-linux-${PHPEEK_PM_ARCH}" | sha256sum -c -; \
    mv /tmp/phpeek-pm-linux-${PHPEEK_PM_ARCH} /usr/local/bin/phpeek-pm; \
    chmod +x /usr/local/bin/phpeek-pm; \
    rm -f /tmp/phpeek-pm-linux-*; \
    /usr/local/bin/phpeek-pm --version

# ============================================================================
# Base PHP Configuration
# ============================================================================
COPY php-base/common/php.ini /usr/local/etc/php/conf.d/99-phpeek.ini

# ============================================================================
# ImageMagick Security Policy (Debian uses ImageMagick-6)
# ============================================================================
COPY php-base/common/imagemagick-policy.xml /etc/ImageMagick-6/policy.xml

# ============================================================================
# Working Directory Setup
# ============================================================================
RUN mkdir -p /var/www/html && \
    chown -R www-data:www-data /var/www

WORKDIR /var/www/html
