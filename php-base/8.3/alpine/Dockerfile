# ============================================================================
# PHPeek PHP Base Image - Alpine 8.3
# ============================================================================
# LAYER 2: Single source of truth for all PHP extensions, Composer, Node, PHPeek PM
# All other images (php-cli, php-fpm, php-fpm-nginx, php-swoole, etc.) extend this
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
FROM node:${NODE_VERSION}-alpine AS node

# Stage 2: PHP CLI base (NOT FPM - that's a separate layer)
FROM php:8.3-cli-alpine

LABEL org.opencontainers.image.title="PHPeek PHP Base 8.3 Alpine"
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
# System Dependencies
# ============================================================================
RUN apk add --no-cache \
    # Essential tools
    bash curl wget git unzip procps \
    # Cron for Laravel Scheduler (dcron for Alpine)
    dcron \
    # Extension runtime dependencies
    icu-libs icu-data-full \
    libpq \
    libzip \
    libpng libjpeg-turbo freetype libwebp libavif \
    imagemagick \
    # HEIC/HEIF support for ImageMagick
    libheif \
    # PDF support for ImageMagick (Ghostscript)
    ghostscript \
    # SVG support for ImageMagick
    librsvg \
    vips vips-tools \
    libxml2 libxslt \
    libsodium \
    oniguruma \
    c-ares \
    openldap \
    bzip2 \
    gmp \
    readline \
    gettext \
    # Exiftool for image metadata
    exiftool \
    # Chromium for Browsershot/Puppeteer PDF generation
    chromium \
    nss \
    freetype \
    harfbuzz \
    ca-certificates \
    ttf-freefont

# Set Puppeteer to use installed Chromium
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

# ============================================================================
# PHP Extensions (40+)
# ============================================================================

# Install build dependencies (will be removed after compilation)
RUN apk add --no-cache --virtual .build-deps \
    $PHPIZE_DEPS \
    icu-dev \
    postgresql-dev \
    libzip-dev \
    libpng-dev libjpeg-turbo-dev freetype-dev libwebp-dev libavif-dev \
    imagemagick-dev \
    vips-dev \
    libxml2-dev libxslt-dev \
    libsodium-dev \
    oniguruma-dev \
    c-ares-dev \
    openldap-dev \
    bzip2-dev \
    gmp-dev \
    readline-dev \
    gettext-dev \
    linux-headers

# Configure GD with WebP/AVIF support
RUN docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg \
    --with-webp \
    --with-avif

# Install core PHP extensions
RUN docker-php-ext-install -j$(nproc) \
    opcache \
    pdo_mysql pdo_pgsql mysqli pgsql \
    zip intl bcmath gd exif \
    pcntl sockets soap xsl ldap bz2 \
    calendar gettext shmop sysvmsg sysvsem sysvshm \
    gmp

# Install PECL extensions with PINNED versions (igbinary first for redis serialization)
RUN pecl install igbinary-${IGBINARY_VERSION} && \
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
RUN apk del .build-deps && \
    rm -rf /tmp/* /var/cache/apk/* /var/tmp/* \
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
# ImageMagick Security Policy
# ============================================================================
COPY php-base/common/imagemagick-policy.xml /etc/ImageMagick-7/policy.xml

# ============================================================================
# Working Directory Setup
# ============================================================================
RUN mkdir -p /var/www/html && \
    chown -R www-data:www-data /var/www

WORKDIR /var/www/html
