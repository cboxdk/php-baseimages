# ============================================================================
# PHPeek PHP-FPM Image - Alpine 8.2
# ============================================================================
# LAYER 3: Multi-stage build that copies extensions from php-base
#          and uses official php-fpm as base
# ============================================================================

# Import both variants from php-base for extension copying
FROM ghcr.io/gophpeek/baseimages/php-base:8.2-alpine AS base-root
FROM ghcr.io/gophpeek/baseimages/php-base:8.2-alpine-rootless AS base-rootless

# ═══════════════════════════════════════════════════════════════════════════
# ROOT VARIANT (default) - Runs as root, PUID/PGID mapping at runtime
# ═══════════════════════════════════════════════════════════════════════════
FROM php:8.2-fpm-alpine AS root

LABEL org.opencontainers.image.title="PHPeek PHP-FPM 8.2 Alpine"
LABEL org.opencontainers.image.description="PHP-FPM with all extensions, Composer, Node.js, and PHPeek PM"
LABEL org.opencontainers.image.vendor="PHPeek"
LABEL org.opencontainers.image.source="https://github.com/gophpeek/baseimages"

# Copy runtime dependencies from base
RUN apk add --no-cache \
    bash curl wget git unzip procps netcat-openbsd \
    dcron \
    icu-libs icu-data-full libpq libzip \
    libpng libjpeg-turbo freetype libwebp libavif \
    imagemagick \
    # HEIC/HEIF support for ImageMagick
    libheif \
    # PDF support for ImageMagick (Ghostscript)
    ghostscript \
    # SVG support for ImageMagick
    librsvg \
    vips vips-tools \
    libxml2 libxslt libsodium oniguruma \
    c-ares openldap bzip2 gmp readline gettext \
    exiftool chromium nss freetype harfbuzz ca-certificates ttf-freefont

# Set Puppeteer to use installed Chromium
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser \
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

# Copy ImageMagick policy from base image
COPY --from=base-root /etc/ImageMagick-7/policy.xml /etc/ImageMagick-7/policy.xml

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
FROM php:8.2-fpm-alpine AS rootless

LABEL org.opencontainers.image.title="PHPeek PHP-FPM 8.2 Alpine (Rootless)"
LABEL org.opencontainers.image.description="PHP-FPM with all extensions, Composer, Node.js, and PHPeek PM - Rootless"
LABEL org.opencontainers.image.vendor="PHPeek"
LABEL org.opencontainers.image.source="https://github.com/gophpeek/baseimages"

# Copy runtime dependencies from base
RUN apk add --no-cache \
    bash curl wget git unzip procps netcat-openbsd \
    dcron \
    icu-libs icu-data-full libpq libzip \
    libpng libjpeg-turbo freetype libwebp libavif \
    imagemagick \
    # HEIC/HEIF support for ImageMagick
    libheif \
    # PDF support for ImageMagick (Ghostscript)
    ghostscript \
    # SVG support for ImageMagick
    librsvg \
    vips vips-tools \
    libxml2 libxslt libsodium oniguruma \
    c-ares openldap bzip2 gmp readline gettext \
    exiftool chromium nss freetype harfbuzz ca-certificates ttf-freefont

# Set Puppeteer to use installed Chromium
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser \
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

# Copy ImageMagick policy from base image
COPY --from=base-rootless /etc/ImageMagick-7/policy.xml /etc/ImageMagick-7/policy.xml

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
