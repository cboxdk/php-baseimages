# ============================================================================
# Cbox PHP Base Image - Debian 8.4 (Bookworm)
# ============================================================================
# LAYER 2: Single source of truth for all PHP extensions, Composer, Node, Cbox Init
# All other images (php-cli, php-fpm, php-fpm-nginx, php-swoole, etc.) extend this
#
# IMAGE TIERS:
# - slim:     Core PHP + database/cache/queue extensions - API/microservices
#             (opcache, pdo_mysql, pdo_pgsql, mysqli, pgsql, redis, apcu, msgpack,
#              zip, intl, bcmath, gd, exif, pcntl, sockets, bz2, gmp)
# - standard: + ImageMagick, vips, Node.js, mongodb, soap, ldap, xsl,
#               calendar, gettext, shmop, sysvmsg, sysvsem, sysvshm - Most Laravel apps (DEFAULT)
# - chromium: + Chromium for Browsershot/Dusk (~800MB) - PDF generation, testing
# ============================================================================

# ============================================================================
# Extension Versions (from versions.json - passed as build args by CI)
# ============================================================================
ARG REDIS_VERSION=6.3.0
ARG IMAGICK_VERSION=3.8.1
ARG APCU_VERSION=5.1.27
ARG MONGODB_VERSION=2.1.4
ARG MSGPACK_VERSION=3.0.0
ARG VIPS_VERSION=1.0.13
ARG XDEBUG_VERSION=3.5.0
ARG PCOV_VERSION=1.0.12

# Stage 1: Get Node.js from official image
ARG NODE_VERSION=22
FROM node:${NODE_VERSION}-bookworm-slim AS node

# ============================================================================
# Cbox Init binary selection (multi-stage to avoid dead layers)
# Only the correct architecture binary is ever present in the final image.
# ============================================================================
FROM scratch AS cbox-init-amd64
COPY cbox-init/binaries/cbox-init-linux-amd64 /cbox-init

FROM scratch AS cbox-init-arm64
COPY cbox-init/binaries/cbox-init-linux-arm64 /cbox-init

ARG TARGETARCH
FROM cbox-init-${TARGETARCH} AS cbox-init-bin

# ============================================================================
# SLIM BASE - Minimal dependencies, essential extensions only
# ============================================================================
FROM php:8.4-cli-bookworm AS slim-base

LABEL org.opencontainers.image.title="Cbox PHP Base 8.4 Debian"
LABEL org.opencontainers.image.description="Base PHP image with extensions, Composer, and Cbox Init"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/php-baseimages"

# Re-declare ARGs after FROM (they don't persist)
ARG REDIS_VERSION
ARG APCU_VERSION
ARG MSGPACK_VERSION

# ============================================================================
# SLIM: System Dependencies (Runtime only - minimal set)
# ============================================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Essential tools
    bash curl wget git unzip procps \
    # Cron for Laravel Scheduler
    cron \
    # Runtime libraries (minimal set for slim tier)
    libpng16-16 libjpeg62-turbo libfreetype6 libwebp7 \
    libpq5 libicu72 libzip4 \
    libxml2 \
    libbz2-1.0 libonig5 libreadline8 libgmp10 \
    && rm -rf /var/lib/apt/lists/*

# ============================================================================
# SLIM: PHP Extensions (essential only)
# ============================================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    $PHPIZE_DEPS \
    libpng-dev libjpeg62-turbo-dev libfreetype6-dev libwebp-dev \
    libpq-dev libicu-dev libzip-dev \
    libbz2-dev libonig-dev libreadline-dev libgmp-dev \
    && rm -rf /var/lib/apt/lists/*

# Configure GD with WebP support (no AVIF in slim to keep size down)
RUN docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg \
    --with-webp

# Install core PHP extensions
RUN docker-php-ext-install -j$(nproc) \
    opcache \
    pdo_mysql pdo_pgsql mysqli pgsql \
    zip intl bcmath gd exif \
    pcntl sockets bz2 \
    gmp

# Install PECL extensions with PINNED versions
RUN pecl install redis-${REDIS_VERSION} && \
    pecl install apcu-${APCU_VERSION} && \
    pecl install msgpack-${MSGPACK_VERSION} && \
    docker-php-ext-enable redis apcu msgpack

# Cleanup build deps
RUN apt-get purge -y --auto-remove $PHPIZE_DEPS \
    libpng-dev libjpeg62-turbo-dev libfreetype6-dev libwebp-dev \
    libpq-dev libicu-dev libzip-dev \
    libbz2-dev libonig-dev libreadline-dev libgmp-dev && \
    rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/* \
    /usr/share/doc /usr/share/man /usr/share/locale/* \
    /root/.pearrc /root/.pear && \
    find /usr/local/lib/php/extensions -name '*.so' -exec strip --strip-all {} \; 2>/dev/null || true

# ============================================================================
# Composer
# ============================================================================
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# ============================================================================
# Cbox Init (Process Manager)
# ============================================================================
ARG CBOX_INIT_VERSION=2.0.1
ARG CBOX_INIT_SHA256_AMD64=5a5b6c92374f0c15a338ca3b925884e077269664f281328c133004bfc0879cbd
ARG CBOX_INIT_SHA256_ARM64=7139ecd6a4570414e801ad343ef02882bbdafd738f755cbef3f2a00a997a0b84
ARG TARGETARCH

COPY --from=cbox-init-bin /cbox-init /usr/local/bin/cbox-init

RUN set -eux; \
    case "${TARGETARCH}" in \
        amd64) CBOX_INIT_CHECKSUM="${CBOX_INIT_SHA256_AMD64}" ;; \
        arm64) CBOX_INIT_CHECKSUM="${CBOX_INIT_SHA256_ARM64}" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    echo "${CBOX_INIT_CHECKSUM}  /usr/local/bin/cbox-init" | sha256sum -c -; \
    chmod +x /usr/local/bin/cbox-init; \
    /usr/local/bin/cbox-init --version

# ============================================================================
# Base PHP Configuration
# ============================================================================
COPY php-base/common/php.ini /usr/local/etc/php/conf.d/99-cbox.ini

# ============================================================================
# Cbox Shared Libraries (entrypoint helpers, lifecycle checks)
# ============================================================================
RUN mkdir -p /usr/local/lib/cbox
COPY common/lib/entrypoint-lib.sh /usr/local/lib/cbox/
COPY common/lib/lifecycle-check.sh /usr/local/lib/cbox/
RUN chmod +x /usr/local/lib/cbox/*.sh

# ============================================================================
# Lifecycle State (set at build time via CI)
# ============================================================================
ARG CBOX_LIFECYCLE=stable
ARG CBOX_PHP_VERSION=8.4
ARG CBOX_PHP_EOL=
ARG CBOX_REMOVAL_DATE=
ARG CBOX_PREVIEW_STATUS=

ENV CBOX_LIFECYCLE=${CBOX_LIFECYCLE} \
    CBOX_PHP_VERSION=${CBOX_PHP_VERSION} \
    CBOX_PHP_EOL=${CBOX_PHP_EOL} \
    CBOX_REMOVAL_DATE=${CBOX_REMOVAL_DATE} \
    CBOX_PREVIEW_STATUS=${CBOX_PREVIEW_STATUS}

# ============================================================================
# Working Directory Setup
# ============================================================================
RUN mkdir -p /var/www/html && \
    chown -R www-data:www-data /var/www

WORKDIR /var/www/html

# ============================================================================
# STANDARD BASE - Add ImageMagick, vips, Node.js (DEFAULT)
# ============================================================================
FROM slim-base AS standard-base

# Re-declare ARGs
ARG IMAGICK_VERSION
ARG VIPS_VERSION
ARG MONGODB_VERSION

# Copy Node.js binaries from official node image
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules

# Create npm/npx symlinks
RUN ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -sf /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

# ============================================================================
# STANDARD: Additional runtime deps + ImageMagick/vips extensions
# ============================================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    # AVIF support
    libavif15 \
    # ImageMagick runtime
    libmagickwand-6.q16-6 \
    # HEIC/HEIF support for ImageMagick
    libheif1 \
    # PDF support for ImageMagick (Ghostscript)
    ghostscript \
    # SVG support for ImageMagick
    librsvg2-bin \
    # vips runtime
    libvips42 libvips-tools \
    # Exiftool for image metadata
    libimage-exiftool-perl \
    # Netcat for health checks
    netcat-openbsd \
    # Runtime libs for extensions moved from slim (soap, xsl, ldap)
    libxslt1.1 libldap-2.5-0 \
    && rm -rf /var/lib/apt/lists/*

# Install build deps for ImageMagick/vips + moved extensions
RUN apt-get update && apt-get install -y --no-install-recommends \
    $PHPIZE_DEPS \
    libavif-dev libmagickwand-dev libvips-dev \
    libpng-dev libjpeg62-turbo-dev libfreetype6-dev libwebp-dev \
    libxml2-dev libxslt1-dev libldap2-dev \
    && rm -rf /var/lib/apt/lists/*

# Reconfigure GD with AVIF support
RUN docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg \
    --with-webp \
    --with-avif && \
    docker-php-ext-install -j$(nproc) gd

# Install extensions moved from slim tier (niche/enterprise)
RUN docker-php-ext-install -j$(nproc) \
    soap xsl ldap \
    calendar gettext shmop sysvmsg sysvsem sysvshm

# Install ImageMagick, vips, and mongodb PECL extensions
RUN pecl install imagick-${IMAGICK_VERSION} && \
    pecl install vips-${VIPS_VERSION} && \
    pecl install mongodb-${MONGODB_VERSION} && \
    docker-php-ext-enable imagick vips mongodb

# Cleanup build deps
RUN apt-get purge -y --auto-remove $PHPIZE_DEPS \
    libavif-dev libmagickwand-dev libvips-dev \
    libpng-dev libjpeg62-turbo-dev libfreetype6-dev libwebp-dev \
    libxml2-dev libxslt1-dev libldap2-dev && \
    rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/* \
    /root/.pearrc /root/.pear && \
    find /usr/local/lib/php/extensions -name '*.so' -exec strip --strip-all {} \; 2>/dev/null || true

# ImageMagick Security Policy (Debian uses ImageMagick-6)
COPY php-base/common/imagemagick-policy.xml /etc/ImageMagick-6/policy.xml

# ============================================================================
# CHROMIUM BASE - Add Chromium for Browsershot/Dusk/Puppeteer
# ============================================================================
FROM standard-base AS chromium-base

# Chromium and dependencies for headless browser
RUN apt-get update && apt-get install -y --no-install-recommends \
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
# DEV BASE - Chromium + Development tools (Xdebug, PCOV, SPX)
# ============================================================================
FROM chromium-base AS dev-base

ARG XDEBUG_VERSION
ARG PCOV_VERSION

# Install dev extensions (Xdebug, PCOV, SPX)
RUN apt-get update && apt-get install -y --no-install-recommends \
    $PHPIZE_DEPS git zlib1g-dev \
    && pecl install xdebug-${XDEBUG_VERSION} \
    && pecl install pcov-${PCOV_VERSION} \
    && docker-php-ext-enable xdebug pcov \
    # SPX from GitHub (not on PECL)
    && git clone --depth=1 https://github.com/NoiseByNorthwest/php-spx.git /tmp/php-spx \
    && cd /tmp/php-spx \
    && phpize && ./configure && make && make install \
    && docker-php-ext-enable spx \
    && rm -rf /tmp/php-spx \
    # Cleanup
    && apt-get purge -y --auto-remove $PHPIZE_DEPS git \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Copy dev extension configurations
COPY php-base/common/xdebug.ini /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini
COPY php-base/common/spx.ini /usr/local/etc/php/conf.d/docker-php-ext-spx.ini
COPY php-base/common/pcov.ini /usr/local/etc/php/conf.d/docker-php-ext-pcov.ini

# ═══════════════════════════════════════════════════════════════════════════
# SLIM VARIANTS (root + rootless)
# ═══════════════════════════════════════════════════════════════════════════
FROM slim-base AS slim-root
ENV CBOX_ROOTLESS=false \
    CBOX_IMAGE_TIER=slim

FROM slim-base AS slim-rootless
RUN mkdir -p \
    /var/www/html /var/www/.composer /var/www/.npm \
    /var/lib/php/sessions /tmp/cbox /docker-entrypoint-init.d && \
    chown -R www-data:www-data \
        /var/www /var/lib/php/sessions /tmp/cbox /docker-entrypoint-init.d
ENV CBOX_ROOTLESS=true \
    CBOX_IMAGE_TIER=slim \
    HOME=/var/www
USER www-data
WORKDIR /var/www/html

# ═══════════════════════════════════════════════════════════════════════════
# STANDARD VARIANTS (root + rootless) - DEFAULT
# ═══════════════════════════════════════════════════════════════════════════
FROM standard-base AS root
ENV CBOX_ROOTLESS=false \
    CBOX_IMAGE_TIER=standard

FROM standard-base AS rootless
RUN mkdir -p \
    /var/www/html /var/www/.composer /var/www/.npm \
    /var/lib/php/sessions /tmp/cbox /docker-entrypoint-init.d && \
    chown -R www-data:www-data \
        /var/www /var/lib/php/sessions /tmp/cbox /docker-entrypoint-init.d
ENV CBOX_ROOTLESS=true \
    CBOX_IMAGE_TIER=standard \
    HOME=/var/www
USER www-data
WORKDIR /var/www/html

# ═══════════════════════════════════════════════════════════════════════════
# CHROMIUM VARIANTS (root + rootless)
# ═══════════════════════════════════════════════════════════════════════════
FROM chromium-base AS chromium-root
ENV CBOX_ROOTLESS=false \
    CBOX_IMAGE_TIER=chromium

FROM chromium-base AS chromium-rootless
RUN mkdir -p \
    /var/www/html /var/www/.composer /var/www/.npm \
    /var/lib/php/sessions /tmp/cbox /docker-entrypoint-init.d && \
    chown -R www-data:www-data \
        /var/www /var/lib/php/sessions /tmp/cbox /docker-entrypoint-init.d
ENV CBOX_ROOTLESS=true \
    CBOX_IMAGE_TIER=chromium \
    HOME=/var/www
USER www-data
WORKDIR /var/www/html

# ═══════════════════════════════════════════════════════════════════════════
# DEV VARIANTS (root + rootless) - Chromium + Xdebug, PCOV, SPX
# ═══════════════════════════════════════════════════════════════════════════
FROM dev-base AS dev-root
ENV CBOX_ROOTLESS=false \
    CBOX_IMAGE_TIER=dev

FROM dev-base AS dev-rootless
RUN mkdir -p \
    /var/www/html /var/www/.composer /var/www/.npm \
    /var/lib/php/sessions /tmp/cbox /docker-entrypoint-init.d && \
    chown -R www-data:www-data \
        /var/www /var/lib/php/sessions /tmp/cbox /docker-entrypoint-init.d
ENV CBOX_ROOTLESS=true \
    CBOX_IMAGE_TIER=dev \
    HOME=/var/www
USER www-data
WORKDIR /var/www/html
