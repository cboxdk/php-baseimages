# ============================================================================
# PHPeek PHP-FPM Image - Debian 8.2 (Bookworm)
# ============================================================================
# LAYER 3: Multi-stage build that copies extensions from php-base
#          and uses official php-fpm as base
# ============================================================================

# Import both variants from php-base for extension copying
FROM ghcr.io/gophpeek/baseimages/php-base:8.2-bookworm AS base-root
FROM ghcr.io/gophpeek/baseimages/php-base:8.2-bookworm-rootless AS base-rootless

# ═══════════════════════════════════════════════════════════════════════════
# ROOT VARIANT (default) - Runs as root, PUID/PGID mapping at runtime
# ═══════════════════════════════════════════════════════════════════════════
FROM php:8.2-fpm-bookworm AS root

LABEL org.opencontainers.image.title="PHPeek PHP-FPM 8.2 Debian"
LABEL org.opencontainers.image.description="PHP-FPM with all extensions, Composer, Node.js, and PHPeek PM"
LABEL org.opencontainers.image.vendor="PHPeek"
LABEL org.opencontainers.image.source="https://github.com/gophpeek/baseimages"

# Copy runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash curl wget git unzip procps netcat-openbsd libfcgi-bin \
    cron \
    libpng16-16 libjpeg62-turbo libfreetype6 \
    libwebp7 libavif15 libmagickwand-6.q16-6 \
    libvips42 libvips-tools \
    libpq5 libicu72 libzip4 \
    libxml2 libxslt1.1 libldap-2.5-0 \
    libbz2-1.0 libonig5 libreadline8 libgmp10 \
    libimage-exiftool-perl \
    chromium fonts-liberation libnss3 \
    libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 \
    libxkbcommon0 libxcomposite1 libxdamage1 libxrandr2 libgbm1 libasound2 \
    && rm -rf /var/lib/apt/lists/*

# Set Puppeteer to use installed Chromium
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium \
    PHPEEK_ROOTLESS=false

# Copy PHP extensions from base image
COPY --from=base-root /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=base-root /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/

# Copy Node.js from base image
COPY --from=base-root /usr/local/bin/node /usr/local/bin/node
COPY --from=base-root /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -sf /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

# Copy Composer from base image
COPY --from=base-root /usr/bin/composer /usr/bin/composer

# Copy PHPeek PM from base image
COPY --from=base-root /usr/local/bin/phpeek-pm /usr/local/bin/phpeek-pm

# Copy ImageMagick policy from base image (Debian uses ImageMagick-6)
COPY --from=base-root /etc/ImageMagick-6/policy.xml /etc/ImageMagick-6/policy.xml

# Copy PHPeek shared libraries from base image
COPY --from=base-root /usr/local/lib/phpeek/ /usr/local/lib/phpeek/

# Copy FPM-specific configurations
COPY php-fpm/common/fpm-pool.conf /usr/local/etc/php-fpm.d/zz-custom.conf
COPY php-fpm/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-fpm/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

# Create directories
RUN mkdir -p /var/www/html /docker-entrypoint-init.d /var/lib/php/sessions && \
    chown -R www-data:www-data /var/www /var/lib/php/sessions

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

WORKDIR /var/www/html

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["php-fpm"]

# ═══════════════════════════════════════════════════════════════════════════
# ROOTLESS VARIANT - Runs entirely as www-data, no root privileges
# ═══════════════════════════════════════════════════════════════════════════
FROM php:8.2-fpm-bookworm AS rootless

LABEL org.opencontainers.image.title="PHPeek PHP-FPM 8.2 Debian (Rootless)"
LABEL org.opencontainers.image.description="PHP-FPM with all extensions, Composer, Node.js, and PHPeek PM - Rootless"
LABEL org.opencontainers.image.vendor="PHPeek"
LABEL org.opencontainers.image.source="https://github.com/gophpeek/baseimages"

# Copy runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash curl wget git unzip procps netcat-openbsd libfcgi-bin \
    cron \
    libpng16-16 libjpeg62-turbo libfreetype6 \
    libwebp7 libavif15 libmagickwand-6.q16-6 \
    libvips42 libvips-tools \
    libpq5 libicu72 libzip4 \
    libxml2 libxslt1.1 libldap-2.5-0 \
    libbz2-1.0 libonig5 libreadline8 libgmp10 \
    libimage-exiftool-perl \
    chromium fonts-liberation libnss3 \
    libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 \
    libxkbcommon0 libxcomposite1 libxdamage1 libxrandr2 libgbm1 libasound2 \
    && rm -rf /var/lib/apt/lists/*

# Set Puppeteer to use installed Chromium
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium \
    PHPEEK_ROOTLESS=true \
    HOME=/var/www

# Copy PHP extensions from base image (use rootless base for consistency)
COPY --from=base-rootless /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=base-rootless /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/

# Copy Node.js from base image
COPY --from=base-rootless /usr/local/bin/node /usr/local/bin/node
COPY --from=base-rootless /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -sf /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

# Copy Composer from base image
COPY --from=base-rootless /usr/bin/composer /usr/bin/composer

# Copy PHPeek PM from base image
COPY --from=base-rootless /usr/local/bin/phpeek-pm /usr/local/bin/phpeek-pm

# Copy ImageMagick policy from base image (Debian uses ImageMagick-6)
COPY --from=base-rootless /etc/ImageMagick-6/policy.xml /etc/ImageMagick-6/policy.xml

# Copy PHPeek shared libraries from base image
COPY --from=base-rootless /usr/local/lib/phpeek/ /usr/local/lib/phpeek/

# Copy FPM-specific configurations
COPY php-fpm/common/fpm-pool.conf /usr/local/etc/php-fpm.d/zz-custom.conf
COPY php-fpm/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-fpm/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

# Create directories with www-data ownership for rootless operation
RUN mkdir -p /var/www/html /var/www/.composer /var/www/.npm \
    /docker-entrypoint-init.d /var/lib/php/sessions /tmp/phpeek && \
    chown -R www-data:www-data /var/www /var/lib/php/sessions \
    /docker-entrypoint-init.d /tmp/phpeek && \
    chmod 755 /docker-entrypoint-init.d

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

USER www-data
WORKDIR /var/www/html

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["php-fpm"]
