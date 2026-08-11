# ============================================================================
# Cbox PHP-FPM Image - Debian (Bookworm)
# ============================================================================
# LAYER 3: Multi-stage build that copies extensions from php-base
#          and uses official php-fpm as base
#
# IMAGE TIERS (inherited from php-base):
# - slim:     Minimal PHP + essential extensions - API/microservices
# - standard: + ImageMagick, vips, Node.js - Most Laravel apps (DEFAULT)
# - chromium: + Chromium for Browsershot/Dusk - PDF generation, testing
#
# ARCHITECTURE: Shared dependency stages install runtime libs ONCE per tier.
# Root/rootless variants extend the shared stage (no apt-get duplication).
#
# PARAMETERIZED: Build with --build-arg PHP_VERSION=8.2|8.3|8.4|8.5
# ============================================================================

ARG PHP_VERSION=8.4

# ============================================================================
# Import base images for each tier (for extension copying)
# ============================================================================
FROM ghcr.io/cboxdk/php-baseimages/php-base:${PHP_VERSION}-bookworm-slim AS base-slim
FROM ghcr.io/cboxdk/php-baseimages/php-base:${PHP_VERSION}-bookworm AS base-standard
FROM ghcr.io/cboxdk/php-baseimages/php-base:${PHP_VERSION}-bookworm-chromium AS base-chromium
FROM ghcr.io/cboxdk/php-baseimages/php-base:${PHP_VERSION}-bookworm-dev AS base-dev

# ============================================================================
# Shared dependency stages (runtime libs installed once per tier)
# ============================================================================

# --- Slim tier: minimal runtime dependencies ---
ARG PHP_VERSION
FROM php:${PHP_VERSION}-fpm-bookworm AS fpm-slim-deps

# open_basedir: THE READ-ONLY KERNEL STATISTICS ARE IN IT, AND THE SECRETS ARE
# NOT.
#
# The default was `/var/www/html:/tmp:/var/tmp`, which is right about the
# filesystem and wrong about /proc — and it silently broke this organisation's
# own observability. `cboxdk/system-metrics`, which `cboxdk/laravel-telemetry`
# reads CPU, memory, load and cgroup limits through, got NOTHING under FPM:
# every one of those files refused, the collector degrading to empty, and
# telemetry reporting a healthy application with no metrics rather than an error
# anybody would notice. Measured through a real request on a real application.
# The CLI has no open_basedir, so a scheduler or queue worker collected fine —
# which is exactly why nobody noticed.
#
# HERE rather than in php-base, because php-fpm does not build FROM php-base: it
# copies artifacts out of it, and ENV is metadata rather than a file. Set there,
# it reached nothing.
#
# A LIST, NOT `/proc`, and that is the whole point. `/proc/1/environ` is
# deliberately absent: PID 1's environment is every secret the container holds,
# and a file-read primitive in an application that could reach it would have the
# database password. system-metrics reads it as one of several
# container-detection probes and degrades cleanly without it.
# `/proc/self/environ` and `/proc/*/cmdline` are absent for the same reason.
ENV PHP_OPEN_BASEDIR="/var/www/html:/tmp:/var/tmp:/proc/stat:/proc/loadavg:/proc/meminfo:/proc/uptime:/proc/cpuinfo:/proc/diskstats:/proc/mounts:/proc/net/:/proc/self/cgroup:/sys/fs/cgroup:/sys/class/dmi/id/"

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash curl wget git unzip procps netcat-openbsd libfcgi-bin \
    cron \
    libpng16-16 libjpeg62-turbo libfreetype6 libwebp7 \
    libpq5 libicu72 libzip4 \
    libxml2 libxslt1.1 libldap-2.5-0 \
    libbz2-1.0 libonig5 libreadline8 libgmp10 \
    && rm -rf /var/lib/apt/lists/*

# Copy FPM-specific configurations (shared across root/rootless)
COPY php-fpm/common/fpm-pool.conf /usr/local/etc/php-fpm.d/zz-custom.conf
COPY php-fpm/common/fpm-global.conf /usr/local/etc/php-fpm.d/zz-global.conf
COPY php-fpm/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-fpm/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

# --- Standard tier: adds ImageMagick, vips, Node.js runtime deps ---
FROM fpm-slim-deps AS fpm-standard-deps

RUN apt-get update && apt-get install -y --no-install-recommends \
    libavif15 libmagickwand-6.q16-6 \
    libheif1 ghostscript librsvg2-bin \
    libvips42 libvips-tools \
    libimage-exiftool-perl \
    && rm -rf /var/lib/apt/lists/*

# --- Chromium tier: adds headless browser ---
FROM fpm-standard-deps AS fpm-chromium-deps

RUN apt-get update && apt-get install -y --no-install-recommends \
    chromium fonts-liberation libnss3 \
    libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 \
    libxkbcommon0 libxcomposite1 libxdamage1 libxrandr2 libgbm1 libasound2 \
    && rm -rf /var/lib/apt/lists/*

# ═══════════════════════════════════════════════════════════════════════════
# SLIM-ROOT: Minimal PHP-FPM with essential extensions
# ═══════════════════════════════════════════════════════════════════════════
FROM fpm-slim-deps AS slim-root

ARG PHP_VERSION

LABEL org.opencontainers.image.title="Cbox PHP-FPM ${PHP_VERSION} Bookworm (Slim)"
LABEL org.opencontainers.image.description="Minimal PHP-FPM with essential extensions"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/php-baseimages"

ENV CBOX_ROOTLESS=false \
    CBOX_IMAGE_TIER=slim

# Copy PHP extensions from slim base
COPY --from=base-slim /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=base-slim /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/

# Copy Composer from base image
COPY --from=base-slim /usr/bin/composer /usr/bin/composer

# Copy Cbox Init from base image
COPY --from=base-slim /usr/local/bin/cbox-init /usr/local/bin/cbox-init

# Copy Cbox shared libraries from base image
COPY --from=base-slim /usr/local/lib/cbox/ /usr/local/lib/cbox/

# Create directories
RUN mkdir -p /var/www/html /docker-entrypoint-init.d /var/lib/php/sessions && \
    chown -R www-data:www-data /var/www /var/lib/php/sessions

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

WORKDIR /var/www/html
EXPOSE 9000
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["php-fpm"]

# ═══════════════════════════════════════════════════════════════════════════
# SLIM-ROOTLESS: Minimal PHP-FPM running as www-data
# ═══════════════════════════════════════════════════════════════════════════
FROM fpm-slim-deps AS slim-rootless

ARG PHP_VERSION

LABEL org.opencontainers.image.title="Cbox PHP-FPM ${PHP_VERSION} Bookworm (Slim Rootless)"
LABEL org.opencontainers.image.description="Minimal PHP-FPM with essential extensions - Rootless"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/php-baseimages"

ENV CBOX_ROOTLESS=true \
    CBOX_IMAGE_TIER=slim \
    HOME=/var/www

COPY --from=base-slim /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=base-slim /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/
COPY --from=base-slim /usr/bin/composer /usr/bin/composer
COPY --from=base-slim /usr/local/bin/cbox-init /usr/local/bin/cbox-init
COPY --from=base-slim /usr/local/lib/cbox/ /usr/local/lib/cbox/

RUN mkdir -p /var/www/html /var/www/.composer \
    /docker-entrypoint-init.d /var/lib/php/sessions /tmp/cbox && \
    chown -R www-data:www-data /var/www /var/lib/php/sessions \
    /docker-entrypoint-init.d /tmp/cbox && \
    chmod 755 /docker-entrypoint-init.d

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

USER www-data
WORKDIR /var/www/html
EXPOSE 9000
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["php-fpm"]

# ═══════════════════════════════════════════════════════════════════════════
# ROOT (STANDARD): Default - ImageMagick, vips, Node.js
# ═══════════════════════════════════════════════════════════════════════════
FROM fpm-standard-deps AS root

ARG PHP_VERSION

LABEL org.opencontainers.image.title="Cbox PHP-FPM ${PHP_VERSION} Bookworm"
LABEL org.opencontainers.image.description="PHP-FPM with ImageMagick, vips, Node.js, Composer, and Cbox Init"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/php-baseimages"

ENV CBOX_ROOTLESS=false \
    CBOX_IMAGE_TIER=standard

# Copy PHP extensions from standard base
COPY --from=base-standard /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=base-standard /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/

# Copy Node.js from standard base
COPY --from=base-standard /usr/local/bin/node /usr/local/bin/node
COPY --from=base-standard /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -sf /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

# Copy Composer from base image
COPY --from=base-standard /usr/bin/composer /usr/bin/composer

# Copy Cbox Init from base image
COPY --from=base-standard /usr/local/bin/cbox-init /usr/local/bin/cbox-init

# Copy ImageMagick policy from base image (Debian uses ImageMagick-6)
COPY --from=base-standard /etc/ImageMagick-6/policy.xml /etc/ImageMagick-6/policy.xml

# Copy Cbox shared libraries from base image
COPY --from=base-standard /usr/local/lib/cbox/ /usr/local/lib/cbox/

# Create directories
RUN mkdir -p /var/www/html /docker-entrypoint-init.d /var/lib/php/sessions && \
    chown -R www-data:www-data /var/www /var/lib/php/sessions

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

WORKDIR /var/www/html
EXPOSE 9000
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["php-fpm"]

# ═══════════════════════════════════════════════════════════════════════════
# ROOTLESS (STANDARD): Default rootless - ImageMagick, vips, Node.js
# ═══════════════════════════════════════════════════════════════════════════
FROM fpm-standard-deps AS rootless

ARG PHP_VERSION

LABEL org.opencontainers.image.title="Cbox PHP-FPM ${PHP_VERSION} Bookworm (Rootless)"
LABEL org.opencontainers.image.description="PHP-FPM with ImageMagick, vips, Node.js - Rootless"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/php-baseimages"

ENV CBOX_ROOTLESS=true \
    CBOX_IMAGE_TIER=standard \
    HOME=/var/www

COPY --from=base-standard /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=base-standard /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/
COPY --from=base-standard /usr/local/bin/node /usr/local/bin/node
COPY --from=base-standard /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -sf /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx
COPY --from=base-standard /usr/bin/composer /usr/bin/composer
COPY --from=base-standard /usr/local/bin/cbox-init /usr/local/bin/cbox-init
COPY --from=base-standard /etc/ImageMagick-6/policy.xml /etc/ImageMagick-6/policy.xml
COPY --from=base-standard /usr/local/lib/cbox/ /usr/local/lib/cbox/

RUN mkdir -p /var/www/html /var/www/.composer /var/www/.npm \
    /docker-entrypoint-init.d /var/lib/php/sessions /tmp/cbox && \
    chown -R www-data:www-data /var/www /var/lib/php/sessions \
    /docker-entrypoint-init.d /tmp/cbox && \
    chmod 755 /docker-entrypoint-init.d

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

USER www-data
WORKDIR /var/www/html
EXPOSE 9000
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["php-fpm"]

# ═══════════════════════════════════════════════════════════════════════════
# CHROMIUM-ROOT: Everything including Chromium for Browsershot/Dusk
# ═══════════════════════════════════════════════════════════════════════════
FROM fpm-chromium-deps AS chromium-root

ARG PHP_VERSION

LABEL org.opencontainers.image.title="Cbox PHP-FPM ${PHP_VERSION} Bookworm (Chromium)"
LABEL org.opencontainers.image.description="PHP-FPM with all features including Chromium for Browsershot/Dusk"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/php-baseimages"

ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium \
    CBOX_ROOTLESS=false \
    CBOX_IMAGE_TIER=chromium

COPY --from=base-chromium /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=base-chromium /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/
COPY --from=base-chromium /usr/local/bin/node /usr/local/bin/node
COPY --from=base-chromium /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -sf /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx
COPY --from=base-chromium /usr/bin/composer /usr/bin/composer
COPY --from=base-chromium /usr/local/bin/cbox-init /usr/local/bin/cbox-init
COPY --from=base-chromium /etc/ImageMagick-6/policy.xml /etc/ImageMagick-6/policy.xml
COPY --from=base-chromium /usr/local/lib/cbox/ /usr/local/lib/cbox/

RUN mkdir -p /var/www/html /docker-entrypoint-init.d /var/lib/php/sessions && \
    chown -R www-data:www-data /var/www /var/lib/php/sessions

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

WORKDIR /var/www/html
EXPOSE 9000
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["php-fpm"]

# ═══════════════════════════════════════════════════════════════════════════
# CHROMIUM-ROOTLESS: Everything including Chromium, running as www-data
# ═══════════════════════════════════════════════════════════════════════════
FROM fpm-chromium-deps AS chromium-rootless

ARG PHP_VERSION

LABEL org.opencontainers.image.title="Cbox PHP-FPM ${PHP_VERSION} Bookworm (Chromium Rootless)"
LABEL org.opencontainers.image.description="PHP-FPM with all features including Chromium - Rootless"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/php-baseimages"

ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium \
    CBOX_ROOTLESS=true \
    CBOX_IMAGE_TIER=chromium \
    HOME=/var/www

COPY --from=base-chromium /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=base-chromium /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/
COPY --from=base-chromium /usr/local/bin/node /usr/local/bin/node
COPY --from=base-chromium /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -sf /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx
COPY --from=base-chromium /usr/bin/composer /usr/bin/composer
COPY --from=base-chromium /usr/local/bin/cbox-init /usr/local/bin/cbox-init
COPY --from=base-chromium /etc/ImageMagick-6/policy.xml /etc/ImageMagick-6/policy.xml
COPY --from=base-chromium /usr/local/lib/cbox/ /usr/local/lib/cbox/

RUN mkdir -p /var/www/html /var/www/.composer /var/www/.npm \
    /docker-entrypoint-init.d /var/lib/php/sessions /tmp/cbox && \
    chown -R www-data:www-data /var/www /var/lib/php/sessions \
    /docker-entrypoint-init.d /tmp/cbox && \
    chmod 755 /docker-entrypoint-init.d

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

USER www-data
WORKDIR /var/www/html
EXPOSE 9000
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["php-fpm"]

# ═══════════════════════════════════════════════════════════════════════════
# DEV-ROOT: Chromium + Xdebug, PCOV, SPX for development/testing
# ═══════════════════════════════════════════════════════════════════════════
FROM fpm-chromium-deps AS dev-root

ARG PHP_VERSION

LABEL org.opencontainers.image.title="Cbox PHP-FPM ${PHP_VERSION} Bookworm (Dev)"
LABEL org.opencontainers.image.description="PHP-FPM with Xdebug, PCOV, SPX for development and testing"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/php-baseimages"

ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium \
    CBOX_ROOTLESS=false \
    CBOX_IMAGE_TIER=dev

COPY --from=base-dev /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=base-dev /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/
COPY --from=base-dev /usr/local/bin/node /usr/local/bin/node
COPY --from=base-dev /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -sf /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx
COPY --from=base-dev /usr/bin/composer /usr/bin/composer
COPY --from=base-dev /usr/local/bin/cbox-init /usr/local/bin/cbox-init
COPY --from=base-dev /etc/ImageMagick-6/policy.xml /etc/ImageMagick-6/policy.xml
COPY --from=base-dev /usr/local/lib/cbox/ /usr/local/lib/cbox/

RUN mkdir -p /var/www/html /docker-entrypoint-init.d /var/lib/php/sessions && \
    chown -R www-data:www-data /var/www /var/lib/php/sessions

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

WORKDIR /var/www/html
EXPOSE 9000
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["php-fpm"]

# ═══════════════════════════════════════════════════════════════════════════
# DEV-ROOTLESS: Chromium + Xdebug, PCOV, SPX, running as www-data
# ═══════════════════════════════════════════════════════════════════════════
FROM fpm-chromium-deps AS dev-rootless

ARG PHP_VERSION

LABEL org.opencontainers.image.title="Cbox PHP-FPM ${PHP_VERSION} Bookworm (Dev Rootless)"
LABEL org.opencontainers.image.description="PHP-FPM with Xdebug, PCOV, SPX - Rootless"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/php-baseimages"

ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium \
    CBOX_ROOTLESS=true \
    CBOX_IMAGE_TIER=dev \
    HOME=/var/www

COPY --from=base-dev /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=base-dev /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/
COPY --from=base-dev /usr/local/bin/node /usr/local/bin/node
COPY --from=base-dev /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -sf /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx
COPY --from=base-dev /usr/bin/composer /usr/bin/composer
COPY --from=base-dev /usr/local/bin/cbox-init /usr/local/bin/cbox-init
COPY --from=base-dev /etc/ImageMagick-6/policy.xml /etc/ImageMagick-6/policy.xml
COPY --from=base-dev /usr/local/lib/cbox/ /usr/local/lib/cbox/

RUN mkdir -p /var/www/html /var/www/.composer /var/www/.npm \
    /docker-entrypoint-init.d /var/lib/php/sessions /tmp/cbox && \
    chown -R www-data:www-data /var/www /var/lib/php/sessions \
    /docker-entrypoint-init.d /tmp/cbox && \
    chmod 755 /docker-entrypoint-init.d

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

USER www-data
WORKDIR /var/www/html
EXPOSE 9000
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["php-fpm"]
