# ============================================================================
# PHPeek PHP-FPM Image - Debian 13 (Trixie) PHP 8.2
# ============================================================================
# LAYER 3: Multi-stage build that copies extensions from php-base
#          and uses official php-fpm as base
#
# IMAGE TIERS (inherited from php-base):
# - slim:     Minimal PHP + essential extensions - API/microservices
# - standard: + ImageMagick, vips, Node.js - Most Laravel apps (DEFAULT)
# - full:     + Chromium for Browsershot/Dusk - PDF generation, testing
# ============================================================================
# NOTE: Trixie uses ImageMagick-7 and packages with t64 suffix for time64 transition
# ============================================================================

# ============================================================================
# Import base images for each tier (for extension copying)
# ============================================================================
FROM ghcr.io/gophpeek/baseimages/php-base:8.2-trixie-slim AS base-slim
FROM ghcr.io/gophpeek/baseimages/php-base:8.2-trixie AS base-standard
FROM ghcr.io/gophpeek/baseimages/php-base:8.2-trixie-full AS base-full

# ═══════════════════════════════════════════════════════════════════════════
# SLIM-ROOT: Minimal PHP-FPM with essential extensions
# ═══════════════════════════════════════════════════════════════════════════
FROM php:8.2-fpm-trixie AS slim-root

LABEL org.opencontainers.image.title="PHPeek PHP-FPM 8.2 Trixie (Slim)"
LABEL org.opencontainers.image.description="Minimal PHP-FPM with essential extensions"
LABEL org.opencontainers.image.vendor="PHPeek"
LABEL org.opencontainers.image.source="https://github.com/gophpeek/baseimages"

# Slim runtime dependencies only (Trixie package names with t64 suffix)
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash curl wget git unzip procps netcat-openbsd libfcgi-bin \
    cron \
    libpng16-16t64 libjpeg62-turbo libfreetype6 libwebp7 \
    libpq5 libicu76 libzip5 \
    libxml2 libxslt1.1 libldap2 \
    libbz2-1.0 libonig5 libreadline8t64 libgmp10 \
    && rm -rf /var/lib/apt/lists/*

ENV PHPEEK_ROOTLESS=false \
    PHPEEK_IMAGE_TIER=slim

# Copy PHP extensions from slim base
COPY --from=base-slim /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=base-slim /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/

# Copy Composer from base image
COPY --from=base-slim /usr/bin/composer /usr/bin/composer

# Copy PHPeek PM from base image
COPY --from=base-slim /usr/local/bin/phpeek-pm /usr/local/bin/phpeek-pm

# Copy PHPeek shared libraries from base image
COPY --from=base-slim /usr/local/lib/phpeek/ /usr/local/lib/phpeek/

# Copy FPM-specific configurations
COPY php-fpm/common/fpm-pool.conf /usr/local/etc/php-fpm.d/zz-custom.conf
COPY php-fpm/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-fpm/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

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
FROM php:8.2-fpm-trixie AS slim-rootless

LABEL org.opencontainers.image.title="PHPeek PHP-FPM 8.2 Trixie (Slim Rootless)"
LABEL org.opencontainers.image.description="Minimal PHP-FPM with essential extensions - Rootless"
LABEL org.opencontainers.image.vendor="PHPeek"
LABEL org.opencontainers.image.source="https://github.com/gophpeek/baseimages"

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash curl wget git unzip procps netcat-openbsd libfcgi-bin \
    cron \
    libpng16-16t64 libjpeg62-turbo libfreetype6 libwebp7 \
    libpq5 libicu76 libzip5 \
    libxml2 libxslt1.1 libldap2 \
    libbz2-1.0 libonig5 libreadline8t64 libgmp10 \
    && rm -rf /var/lib/apt/lists/*

ENV PHPEEK_ROOTLESS=true \
    PHPEEK_IMAGE_TIER=slim \
    HOME=/var/www

COPY --from=base-slim /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=base-slim /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/
COPY --from=base-slim /usr/bin/composer /usr/bin/composer
COPY --from=base-slim /usr/local/bin/phpeek-pm /usr/local/bin/phpeek-pm
COPY --from=base-slim /usr/local/lib/phpeek/ /usr/local/lib/phpeek/

COPY php-fpm/common/fpm-pool.conf /usr/local/etc/php-fpm.d/zz-custom.conf
COPY php-fpm/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-fpm/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

RUN mkdir -p /var/www/html /var/www/.composer \
    /docker-entrypoint-init.d /var/lib/php/sessions /tmp/phpeek && \
    chown -R www-data:www-data /var/www /var/lib/php/sessions \
    /docker-entrypoint-init.d /tmp/phpeek && \
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
FROM php:8.2-fpm-trixie AS root

LABEL org.opencontainers.image.title="PHPeek PHP-FPM 8.2 Trixie"
LABEL org.opencontainers.image.description="PHP-FPM with ImageMagick, vips, Node.js, Composer, and PHPeek PM"
LABEL org.opencontainers.image.vendor="PHPeek"
LABEL org.opencontainers.image.source="https://github.com/gophpeek/baseimages"

# Standard runtime dependencies (Trixie packages, no Chromium)
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash curl wget git unzip procps netcat-openbsd libfcgi-bin \
    cron \
    libpng16-16t64 libjpeg62-turbo libfreetype6 \
    libwebp7 libavif16 libmagickwand-7.q16hdri-10 \
    libheif1 ghostscript librsvg2-bin \
    libvips42t64 libvips-tools \
    libpq5 libicu76 libzip5 \
    libxml2 libxslt1.1 libldap2 \
    libbz2-1.0 libonig5 libreadline8t64 libgmp10 \
    libimage-exiftool-perl \
    && rm -rf /var/lib/apt/lists/*

ENV PHPEEK_ROOTLESS=false \
    PHPEEK_IMAGE_TIER=standard

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

# Copy PHPeek PM from base image
COPY --from=base-standard /usr/local/bin/phpeek-pm /usr/local/bin/phpeek-pm

# Copy ImageMagick policy from base image (Trixie uses ImageMagick-7)
COPY --from=base-standard /etc/ImageMagick-7/policy.xml /etc/ImageMagick-7/policy.xml

# Copy PHPeek shared libraries from base image
COPY --from=base-standard /usr/local/lib/phpeek/ /usr/local/lib/phpeek/

# Copy FPM-specific configurations
COPY php-fpm/common/fpm-pool.conf /usr/local/etc/php-fpm.d/zz-custom.conf
COPY php-fpm/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-fpm/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

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
FROM php:8.2-fpm-trixie AS rootless

LABEL org.opencontainers.image.title="PHPeek PHP-FPM 8.2 Trixie (Rootless)"
LABEL org.opencontainers.image.description="PHP-FPM with ImageMagick, vips, Node.js - Rootless"
LABEL org.opencontainers.image.vendor="PHPeek"
LABEL org.opencontainers.image.source="https://github.com/gophpeek/baseimages"

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash curl wget git unzip procps netcat-openbsd libfcgi-bin \
    cron \
    libpng16-16t64 libjpeg62-turbo libfreetype6 \
    libwebp7 libavif16 libmagickwand-7.q16hdri-10 \
    libheif1 ghostscript librsvg2-bin \
    libvips42t64 libvips-tools \
    libpq5 libicu76 libzip5 \
    libxml2 libxslt1.1 libldap2 \
    libbz2-1.0 libonig5 libreadline8t64 libgmp10 \
    libimage-exiftool-perl \
    && rm -rf /var/lib/apt/lists/*

ENV PHPEEK_ROOTLESS=true \
    PHPEEK_IMAGE_TIER=standard \
    HOME=/var/www

COPY --from=base-standard /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=base-standard /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/
COPY --from=base-standard /usr/local/bin/node /usr/local/bin/node
COPY --from=base-standard /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -sf /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx
COPY --from=base-standard /usr/bin/composer /usr/bin/composer
COPY --from=base-standard /usr/local/bin/phpeek-pm /usr/local/bin/phpeek-pm
COPY --from=base-standard /etc/ImageMagick-7/policy.xml /etc/ImageMagick-7/policy.xml
COPY --from=base-standard /usr/local/lib/phpeek/ /usr/local/lib/phpeek/

COPY php-fpm/common/fpm-pool.conf /usr/local/etc/php-fpm.d/zz-custom.conf
COPY php-fpm/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-fpm/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

RUN mkdir -p /var/www/html /var/www/.composer /var/www/.npm \
    /docker-entrypoint-init.d /var/lib/php/sessions /tmp/phpeek && \
    chown -R www-data:www-data /var/www /var/lib/php/sessions \
    /docker-entrypoint-init.d /tmp/phpeek && \
    chmod 755 /docker-entrypoint-init.d

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

USER www-data
WORKDIR /var/www/html
EXPOSE 9000
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["php-fpm"]

# ═══════════════════════════════════════════════════════════════════════════
# FULL-ROOT: Everything including Chromium for Browsershot/Dusk
# ═══════════════════════════════════════════════════════════════════════════
FROM php:8.2-fpm-trixie AS full-root

LABEL org.opencontainers.image.title="PHPeek PHP-FPM 8.2 Trixie (Full)"
LABEL org.opencontainers.image.description="PHP-FPM with all features including Chromium for Browsershot/Dusk"
LABEL org.opencontainers.image.vendor="PHPeek"
LABEL org.opencontainers.image.source="https://github.com/gophpeek/baseimages"

# Full runtime dependencies including Chromium (Trixie packages)
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash curl wget git unzip procps netcat-openbsd libfcgi-bin \
    cron \
    libpng16-16t64 libjpeg62-turbo libfreetype6 \
    libwebp7 libavif16 libmagickwand-7.q16hdri-10 \
    libheif1 ghostscript librsvg2-bin \
    libvips42t64 libvips-tools \
    libpq5 libicu76 libzip5 \
    libxml2 libxslt1.1 libldap2 \
    libbz2-1.0 libonig5 libreadline8t64 libgmp10 \
    libimage-exiftool-perl \
    chromium fonts-liberation libnss3 \
    libatk1.0-0t64 libatk-bridge2.0-0t64 libcups2t64 libdrm2 \
    libxkbcommon0 libxcomposite1 libxdamage1 libxrandr2 libgbm1 libasound2t64 \
    && rm -rf /var/lib/apt/lists/*

ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium \
    PHPEEK_ROOTLESS=false \
    PHPEEK_IMAGE_TIER=full

COPY --from=base-full /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=base-full /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/
COPY --from=base-full /usr/local/bin/node /usr/local/bin/node
COPY --from=base-full /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -sf /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx
COPY --from=base-full /usr/bin/composer /usr/bin/composer
COPY --from=base-full /usr/local/bin/phpeek-pm /usr/local/bin/phpeek-pm
COPY --from=base-full /etc/ImageMagick-7/policy.xml /etc/ImageMagick-7/policy.xml
COPY --from=base-full /usr/local/lib/phpeek/ /usr/local/lib/phpeek/

COPY php-fpm/common/fpm-pool.conf /usr/local/etc/php-fpm.d/zz-custom.conf
COPY php-fpm/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-fpm/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

RUN mkdir -p /var/www/html /docker-entrypoint-init.d /var/lib/php/sessions && \
    chown -R www-data:www-data /var/www /var/lib/php/sessions

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

WORKDIR /var/www/html
EXPOSE 9000
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["php-fpm"]

# ═══════════════════════════════════════════════════════════════════════════
# FULL-ROOTLESS: Everything including Chromium, running as www-data
# ═══════════════════════════════════════════════════════════════════════════
FROM php:8.2-fpm-trixie AS full-rootless

LABEL org.opencontainers.image.title="PHPeek PHP-FPM 8.2 Trixie (Full Rootless)"
LABEL org.opencontainers.image.description="PHP-FPM with all features including Chromium - Rootless"
LABEL org.opencontainers.image.vendor="PHPeek"
LABEL org.opencontainers.image.source="https://github.com/gophpeek/baseimages"

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash curl wget git unzip procps netcat-openbsd libfcgi-bin \
    cron \
    libpng16-16t64 libjpeg62-turbo libfreetype6 \
    libwebp7 libavif16 libmagickwand-7.q16hdri-10 \
    libheif1 ghostscript librsvg2-bin \
    libvips42t64 libvips-tools \
    libpq5 libicu76 libzip5 \
    libxml2 libxslt1.1 libldap2 \
    libbz2-1.0 libonig5 libreadline8t64 libgmp10 \
    libimage-exiftool-perl \
    chromium fonts-liberation libnss3 \
    libatk1.0-0t64 libatk-bridge2.0-0t64 libcups2t64 libdrm2 \
    libxkbcommon0 libxcomposite1 libxdamage1 libxrandr2 libgbm1 libasound2t64 \
    && rm -rf /var/lib/apt/lists/*

ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium \
    PHPEEK_ROOTLESS=true \
    PHPEEK_IMAGE_TIER=full \
    HOME=/var/www

COPY --from=base-full /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=base-full /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/
COPY --from=base-full /usr/local/bin/node /usr/local/bin/node
COPY --from=base-full /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -sf /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx
COPY --from=base-full /usr/bin/composer /usr/bin/composer
COPY --from=base-full /usr/local/bin/phpeek-pm /usr/local/bin/phpeek-pm
COPY --from=base-full /etc/ImageMagick-7/policy.xml /etc/ImageMagick-7/policy.xml
COPY --from=base-full /usr/local/lib/phpeek/ /usr/local/lib/phpeek/

COPY php-fpm/common/fpm-pool.conf /usr/local/etc/php-fpm.d/zz-custom.conf
COPY php-fpm/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-fpm/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

RUN mkdir -p /var/www/html /var/www/.composer /var/www/.npm \
    /docker-entrypoint-init.d /var/lib/php/sessions /tmp/phpeek && \
    chown -R www-data:www-data /var/www /var/lib/php/sessions \
    /docker-entrypoint-init.d /tmp/phpeek && \
    chmod 755 /docker-entrypoint-init.d

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

USER www-data
WORKDIR /var/www/html
EXPOSE 9000
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["php-fpm"]
