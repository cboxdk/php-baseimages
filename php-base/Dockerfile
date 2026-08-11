# ============================================================================
# Cbox PHP Base Image - Debian (Bookworm)
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
#
# PARAMETERIZED: Build with --build-arg PHP_VERSION=8.2|8.3|8.4|8.5
# ============================================================================

# ============================================================================
# PHP Version (parameterized - pass via --build-arg)
# ============================================================================
ARG PHP_VERSION=8.4

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
# SPX is not on PECL; pin the git tag for reproducible dev builds.
ARG SPX_VERSION=v0.4.22

# JS runtimes are installed via RUN (official tarball/zip), not `COPY --from`,
# because copying from an external image stage triggers a buildx blob-mount
# failure on our self-hosted runner (the layer gets dropped on push to ghcr).
ARG NODE_VERSION=22.23.1
ARG BUN_VERSION=1.3.14

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
ARG PHP_VERSION
FROM php:${PHP_VERSION}-cli-bookworm AS slim-base

ARG PHP_VERSION

LABEL org.opencontainers.image.title="Cbox PHP Base ${PHP_VERSION} Debian"
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
ARG PHP_VERSION
RUN docker-php-ext-install -j$(nproc) \
    pdo_mysql pdo_pgsql mysqli pgsql \
    zip intl bcmath gd exif \
    pcntl sockets bz2 \
    gmp \
    && if echo "$PHP_VERSION" | grep -qvE '^8\.[5-9]|^[9]'; then \
        docker-php-ext-install opcache; \
    fi

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
ARG CBOX_INIT_VERSION=2.1.0

COPY --from=cbox-init-bin /cbox-init /usr/local/bin/cbox-init

# Checksum verification happens in CI before build (see _build-image.yml)
# Here we just ensure the binary is executable and runs
RUN chmod +x /usr/local/bin/cbox-init && \
    /usr/local/bin/cbox-init --version

# ============================================================================
# Base PHP Configuration
# ============================================================================
COPY php-base/common/php.ini /usr/local/etc/php/conf.d/99-cbox.ini

# open_basedir: THE READ-ONLY KERNEL STATISTICS ARE IN IT, AND THE SECRETS ARE
# NOT.
#
# The default was `/var/www/html:/tmp:/var/tmp`, which is right about the
# filesystem and wrong about /proc — and it silently broke this organisation's
# own observability. `cboxdk/system-metrics`, which `cboxdk/laravel-telemetry`
# reads CPU, memory, load and cgroup limits through, gets NOTHING under FPM:
# every one of those files is refused, the collector degrades to empty, and
# telemetry reports a healthy application with no metrics rather than an error
# anybody would notice. Measured through a real request on a real application.
#
# So the specific files are allowed, and only those. What is deliberately NOT
# here is the reason this is a list rather than `/proc`:
#
#   /proc/1/environ  — PID 1's environment is every secret the container has.
#                      system-metrics reads it as one of several
#                      container-detection probes and degrades cleanly without
#                      it; a file-read primitive in an application that could
#                      reach it would have the database password.
#   /proc/self/environ, /proc/*/cmdline — the same, for this process.
#
# `/proc/self/cgroup` and `/proc/net/` are prefixes, and both are prefixes of
# nothing sensitive. An application that genuinely needs more sets
# PHP_OPEN_BASEDIR itself, deliberately.
ENV PHP_OPEN_BASEDIR="/var/www/html:/tmp:/var/tmp:/proc/stat:/proc/loadavg:/proc/meminfo:/proc/uptime:/proc/cpuinfo:/proc/diskstats:/proc/mounts:/proc/net/:/proc/self/cgroup:/sys/fs/cgroup:/sys/class/dmi/id/"

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
ARG CBOX_PHP_VERSION=${PHP_VERSION}
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
ARG NODE_VERSION
ARG BUN_VERSION

# JS runtimes: Node.js (+ npm/npx) and Bun. Installed from official release
# artifacts via RUN (checksum-verified, arch-aware) rather than `COPY --from=`
# an external image — the latter is dropped on push by buildx on our runner.
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
        amd64) node_arch='x64';    bun_arch='x64' ;; \
        arm64) node_arch='arm64';  bun_arch='aarch64' ;; \
        *) echo "unsupported architecture: $arch" >&2; exit 1 ;; \
    esac; \
    cd /tmp; \
    # --- Node.js (official binary tarball) ---
    curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${node_arch}.tar.gz"; \
    curl -fsSL  "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt" -o node-SHASUMS256.txt; \
    node_sum="$(grep " node-v${NODE_VERSION}-linux-${node_arch}.tar.gz\$" node-SHASUMS256.txt)"; \
    [ -n "$node_sum" ] || { echo "no checksum found for node asset" >&2; exit 1; }; \
    echo "$node_sum" | sha256sum -c -; \
    tar -xzf "node-v${NODE_VERSION}-linux-${node_arch}.tar.gz" -C /usr/local --strip-components=1 --no-same-owner \
        --exclude='*/CHANGELOG.md' --exclude='*/LICENSE' --exclude='*/README.md'; \
    # --- Bun (official release zip) ---
    curl -fsSLO "https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/bun-linux-${bun_arch}.zip"; \
    curl -fsSL  "https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/SHASUMS256.txt" -o bun-SHASUMS256.txt; \
    bun_sum="$(grep " bun-linux-${bun_arch}.zip\$" bun-SHASUMS256.txt)"; \
    [ -n "$bun_sum" ] || { echo "no checksum found for bun asset" >&2; exit 1; }; \
    echo "$bun_sum" | sha256sum -c -; \
    unzip -q "bun-linux-${bun_arch}.zip"; \
    install -m 0755 "bun-linux-${bun_arch}/bun" /usr/local/bin/bun; \
    ln -sf /usr/local/bin/bun /usr/local/bin/bunx; \
    # --- cleanup + smoke test ---
    rm -rf /tmp/node-v* /tmp/node-SHASUMS256.txt /tmp/bun-linux-* /tmp/bun-SHASUMS256.txt; \
    node --version; npm --version; npx --version; bun --version

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
    libxml2-dev libxslt1-dev libldap2-dev libffi-dev \
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

# FFI: BUILT IN, AND OFF.
#
# Real applications need it — an H3 geospatial binding, a libsodium wrapper, any
# library that exists in C and not in PHP — and without it they cannot even pass
# `composer install`'s platform check, let alone run. Compiling it in later is
# not something an application can do for itself.
#
# But FFI loads arbitrary shared libraries and calls into them, so an image that
# shipped it ENABLED would hand every request in every application on it a way
# out of PHP. `ffi.enable=preload` is upstream's own default and the right one:
# code loaded through `opcache.preload` may use FFI, ordinary request code may
# not.
#
# An application that needs it at request time overrides this the way any other
# ini is overridden — its own file in conf.d, sorted after `zz-`. That is
# deliberately a decision somebody makes in writing rather than a flag, and it
# is NOT wired to a `PHP_*` environment variable: those are generated by
# cbox-init, and claiming one that does not exist would be worse than the extra
# step.
RUN docker-php-ext-install -j$(nproc) ffi && \
    printf '[ffi]\nffi.enable=preload\n' > /usr/local/etc/php/conf.d/zz-ffi.ini

# Install ImageMagick, vips, and mongodb PECL extensions
RUN pecl install imagick-${IMAGICK_VERSION} && \
    pecl install vips-${VIPS_VERSION} && \
    pecl install mongodb-${MONGODB_VERSION} && \
    docker-php-ext-enable imagick vips mongodb

# Cleanup build deps
RUN apt-get purge -y --auto-remove $PHPIZE_DEPS \
    libavif-dev libmagickwand-dev libvips-dev \
    libpng-dev libjpeg62-turbo-dev libfreetype6-dev libwebp-dev \
    libxml2-dev libxslt1-dev libldap2-dev libffi-dev && \
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
# Re-declare so the global default (v0.4.22) is visible in this stage's RUN;
# without this SPX_VERSION expands empty and `git clone --branch ""` fails.
ARG SPX_VERSION

# Install dev extensions (Xdebug, PCOV, SPX)
RUN apt-get update && apt-get install -y --no-install-recommends \
    $PHPIZE_DEPS git zlib1g-dev \
    && pecl install xdebug-${XDEBUG_VERSION} \
    && pecl install pcov-${PCOV_VERSION} \
    && docker-php-ext-enable xdebug pcov \
    # SPX from GitHub (not on PECL) — pinned to a tag for reproducibility
    && git clone --depth=1 --branch "${SPX_VERSION}" https://github.com/NoiseByNorthwest/php-spx.git /tmp/php-spx \
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
