# ============================================================================
# PHPeek PHP Base Image - Alpine 8.2
# ============================================================================
# LAYER 2: Single source of truth for all PHP extensions, Composer, Node, PHPeek PM
# All other images (php-cli, php-fpm, php-fpm-nginx, php-swoole, etc.) extend this
#
# IMAGE TIERS:
# - slim:     Minimal PHP + essential extensions (~120MB) - API/microservices
# - standard: + ImageMagick, vips, Node.js (~250MB) - Most Laravel apps (DEFAULT)
# - full:     + Chromium for Browsershot/Dusk (~700MB) - PDF generation, testing
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
ARG GRPC_VERSION=1.72.0

# Stage 1: Get Node.js from official image
ARG NODE_VERSION=22
FROM node:${NODE_VERSION}-alpine AS node

# ============================================================================
# SLIM BASE - Minimal dependencies, essential extensions only
# ============================================================================
FROM php:8.2-cli-alpine AS slim-base

LABEL org.opencontainers.image.title="PHPeek PHP Base 8.2 Alpine"
LABEL org.opencontainers.image.description="Base PHP image with extensions, Composer, and PHPeek PM"
LABEL org.opencontainers.image.vendor="PHPeek"
LABEL org.opencontainers.image.source="https://github.com/gophpeek/baseimages"

# Re-declare ARGs after FROM (they don't persist)
ARG REDIS_VERSION
ARG APCU_VERSION
ARG MONGODB_VERSION
ARG IGBINARY_VERSION
ARG MSGPACK_VERSION
ARG GRPC_VERSION

# ============================================================================
# SLIM: Runtime Dependencies + PHP Extensions (all in one layer)
# ============================================================================
RUN set -eux; \
    # Install runtime dependencies
    apk add --no-cache \
        bash curl wget git unzip procps \
        dcron \
        icu-libs \
        libpq \
        libzip \
        libpng libjpeg-turbo freetype libwebp \
        libxml2 libxslt \
        libsodium \
        oniguruma \
        c-ares \
        openldap \
        bzip2 \
        gmp \
        readline \
        gettext \
        grpc; \
    \
    # Install build dependencies (will be removed at end)
    apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        icu-dev \
        postgresql-dev \
        libzip-dev \
        libpng-dev libjpeg-turbo-dev freetype-dev libwebp-dev \
        libxml2-dev libxslt-dev \
        libsodium-dev \
        oniguruma-dev \
        c-ares-dev \
        openldap-dev \
        bzip2-dev \
        gmp-dev \
        readline-dev \
        gettext-dev \
        grpc-dev \
        linux-headers; \
    \
    # Configure GD with WebP support (no AVIF in slim to keep size down)
    docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
        --with-webp; \
    \
    # Install core PHP extensions
    docker-php-ext-install -j$(nproc) \
        opcache \
        pdo_mysql pdo_pgsql mysqli pgsql \
        zip intl bcmath gd exif \
        pcntl sockets soap xsl ldap bz2 \
        calendar gettext shmop sysvmsg sysvsem sysvshm \
        gmp; \
    \
    # Install PECL extensions with PINNED versions
    pecl install igbinary-${IGBINARY_VERSION}; \
    docker-php-ext-enable igbinary; \
    pecl install redis-${REDIS_VERSION}; \
    pecl install apcu-${APCU_VERSION}; \
    pecl install msgpack-${MSGPACK_VERSION}; \
    pecl install mongodb-${MONGODB_VERSION}; \
    pecl install grpc-${GRPC_VERSION}; \
    docker-php-ext-enable redis apcu msgpack mongodb grpc; \
    \
    # Cleanup build deps and temp files (same layer = no size penalty)
    apk del --no-network .build-deps; \
    rm -rf /tmp/* /var/cache/apk/* /var/tmp/* /root/.pearrc /root/.pear; \
    # Strip debug symbols from extensions
    find /usr/local/lib/php/extensions -name '*.so' -exec strip --strip-all {} \; 2>/dev/null || true

# ============================================================================
# Composer
# ============================================================================
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# ============================================================================
# PHPeek PM (Process Manager)
# ============================================================================
ARG PHPEEK_PM_VERSION=1.0.0
ARG PHPEEK_PM_SHA256_AMD64=5a5b6c92374f0c15a338ca3b925884e077269664f281328c133004bfc0879cbd
ARG PHPEEK_PM_SHA256_ARM64=7139ecd6a4570414e801ad343ef02882bbdafd738f755cbef3f2a00a997a0b84
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
# PHPeek Shared Libraries (entrypoint helpers, lifecycle checks)
# ============================================================================
RUN mkdir -p /usr/local/lib/phpeek
COPY common/lib/entrypoint-lib.sh /usr/local/lib/phpeek/
COPY common/lib/lifecycle-check.sh /usr/local/lib/phpeek/
RUN chmod +x /usr/local/lib/phpeek/*.sh

# ============================================================================
# Lifecycle State (set at build time via CI)
# ============================================================================
ARG PHPEEK_LIFECYCLE=stable
ARG PHPEEK_PHP_VERSION=8.2
ARG PHPEEK_PHP_EOL=
ARG PHPEEK_REMOVAL_DATE=
ARG PHPEEK_PREVIEW_STATUS=

ENV PHPEEK_LIFECYCLE=${PHPEEK_LIFECYCLE} \
    PHPEEK_PHP_VERSION=${PHPEEK_PHP_VERSION} \
    PHPEEK_PHP_EOL=${PHPEEK_PHP_EOL} \
    PHPEEK_REMOVAL_DATE=${PHPEEK_REMOVAL_DATE} \
    PHPEEK_PREVIEW_STATUS=${PHPEEK_PREVIEW_STATUS}

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

# Copy Node.js binaries from official node image
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules

# Create npm/npx symlinks
RUN ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -sf /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

# ============================================================================
# STANDARD: Additional deps + ImageMagick/vips extensions (single layer)
# ============================================================================
RUN set -eux; \
    # Install runtime dependencies for standard tier
    apk add --no-cache \
        icu-data-full \
        libavif \
        imagemagick \
        libheif \
        ghostscript \
        librsvg \
        vips vips-tools \
        exiftool \
        netcat-openbsd; \
    \
    # Install build dependencies
    apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        imagemagick-dev \
        vips-dev \
        libavif-dev \
        libpng-dev libjpeg-turbo-dev freetype-dev libwebp-dev; \
    \
    # Reconfigure GD with AVIF support
    docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
        --with-webp \
        --with-avif; \
    docker-php-ext-install -j$(nproc) gd; \
    \
    # Install PECL extensions
    pecl install imagick-${IMAGICK_VERSION}; \
    pecl install vips-${VIPS_VERSION}; \
    docker-php-ext-enable imagick vips; \
    \
    # Cleanup
    apk del --no-network .build-deps; \
    rm -rf /tmp/* /var/cache/apk/* /var/tmp/* /root/.pearrc /root/.pear; \
    find /usr/local/lib/php/extensions -name '*.so' -exec strip --strip-all {} \; 2>/dev/null || true

# ImageMagick Security Policy
COPY php-base/common/imagemagick-policy.xml /etc/ImageMagick-7/policy.xml

# ============================================================================
# FULL BASE - Add Chromium for Browsershot/Dusk/Puppeteer
# ============================================================================
FROM standard-base AS full-base

# Chromium and dependencies for headless browser
RUN apk add --no-cache \
    chromium \
    nss \
    freetype \
    harfbuzz \
    ca-certificates \
    ttf-freefont

# Set Puppeteer to use installed Chromium
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

# ═══════════════════════════════════════════════════════════════════════════
# SLIM VARIANTS (root + rootless)
# ═══════════════════════════════════════════════════════════════════════════
FROM slim-base AS slim-root
ENV PHPEEK_ROOTLESS=false \
    PHPEEK_IMAGE_TIER=slim

FROM slim-base AS slim-rootless
RUN mkdir -p \
    /var/www/html /var/www/.composer /var/www/.npm \
    /var/lib/php/sessions /tmp/phpeek /docker-entrypoint-init.d && \
    chown -R www-data:www-data \
        /var/www /var/lib/php/sessions /tmp/phpeek /docker-entrypoint-init.d
ENV PHPEEK_ROOTLESS=true \
    PHPEEK_IMAGE_TIER=slim \
    HOME=/var/www
USER www-data
WORKDIR /var/www/html

# ═══════════════════════════════════════════════════════════════════════════
# STANDARD VARIANTS (root + rootless) - DEFAULT
# ═══════════════════════════════════════════════════════════════════════════
FROM standard-base AS root
ENV PHPEEK_ROOTLESS=false \
    PHPEEK_IMAGE_TIER=standard

FROM standard-base AS rootless
RUN mkdir -p \
    /var/www/html /var/www/.composer /var/www/.npm \
    /var/lib/php/sessions /tmp/phpeek /docker-entrypoint-init.d && \
    chown -R www-data:www-data \
        /var/www /var/lib/php/sessions /tmp/phpeek /docker-entrypoint-init.d
ENV PHPEEK_ROOTLESS=true \
    PHPEEK_IMAGE_TIER=standard \
    HOME=/var/www
USER www-data
WORKDIR /var/www/html

# ═══════════════════════════════════════════════════════════════════════════
# FULL VARIANTS (root + rootless)
# ═══════════════════════════════════════════════════════════════════════════
FROM full-base AS full-root
ENV PHPEEK_ROOTLESS=false \
    PHPEEK_IMAGE_TIER=full

FROM full-base AS full-rootless
RUN mkdir -p \
    /var/www/html /var/www/.composer /var/www/.npm \
    /var/lib/php/sessions /tmp/phpeek /docker-entrypoint-init.d && \
    chown -R www-data:www-data \
        /var/www /var/lib/php/sessions /tmp/phpeek /docker-entrypoint-init.d
ENV PHPEEK_ROOTLESS=true \
    PHPEEK_IMAGE_TIER=full \
    HOME=/var/www
USER www-data
WORKDIR /var/www/html
