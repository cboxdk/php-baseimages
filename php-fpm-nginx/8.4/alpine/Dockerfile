# Stage 1: Get Node.js from official image (enables version control via build arg)
ARG NODE_VERSION=22
FROM node:${NODE_VERSION}-alpine AS node

# Stage 2: PHP base image
FROM php:8.4-fpm-alpine

# Copy Node.js binaries from official node image
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules

# Create npm/npx symlinks
RUN ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -sf /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

# Install system dependencies (including cron for Laravel scheduler)
RUN apk add --no-cache \
    bash curl wget git unzip \
    netcat-openbsd nginx \
    dcron \
    libpng-dev libjpeg-turbo-dev freetype-dev \
    libwebp-dev libavif-dev imagemagick-dev \
    postgresql-dev icu-dev libzip-dev oniguruma-dev \
    libxml2-dev libxslt-dev openldap-dev bzip2-dev \
    gettext-dev libmcrypt-dev readline-dev \
    gmp-dev \
    linux-headers gettext-dev \
    exiftool \
    # Chromium for Browsershot/Puppeteer PDF generation
    chromium \
    nss \
    freetype \
    harfbuzz \
    ca-certificates \
    ttf-freefont \
    $PHPIZE_DEPS

# Set Puppeteer to use installed Chromium
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

# Configure GD with WebP/AVIF support
RUN docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg \
    --with-webp \
    --with-avif

# Install PHP extensions
RUN docker-php-ext-install -j$(nproc) \
    opcache \
    pdo_mysql pdo_pgsql mysqli pgsql \
    zip intl bcmath gd exif \
    pcntl sockets soap xsl ldap bz2 \
    calendar gettext shmop sysvmsg sysvsem sysvshm \
    gmp

# Install PECL extensions (igbinary first, then others can use it)
RUN pecl install igbinary-3.2.15 && \
    docker-php-ext-enable igbinary && \
    pecl install redis-6.3.0 imagick apcu-5.1.27 msgpack-3.0.0 mongodb-1.20.1 && \
    docker-php-ext-enable redis imagick apcu msgpack mongodb

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Install PHPeek PM (Process Manager) with multi-arch support and integrity verification
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

# Copy PHP configurations (template + static)
COPY php-fpm/common/php.ini.template /usr/local/etc/php/conf.d/99-custom.ini.template
COPY php-fpm/common/php.ini /usr/local/etc/php/conf.d/99-custom.ini
COPY php-fpm/common/fpm-pool.conf /usr/local/etc/php-fpm.d/zz-custom.conf

# Copy Nginx configurations (template + static)
COPY nginx/alpine/nginx.conf /etc/nginx/nginx.conf
COPY php-fpm-nginx/common/default.conf.template /etc/nginx/conf.d/default.conf.template
COPY php-fpm-nginx/common/default.conf /etc/nginx/conf.d/default.conf

# Copy PHPeek PM configuration template
RUN mkdir -p /etc/phpeek-pm
COPY php-fpm-nginx/common/phpeek-pm.yaml /etc/phpeek-pm/phpeek-pm.yaml

# Copy ImageMagick security policy (prevents XXE, ghostscript exploits, SSRF)
COPY php-fpm-nginx/common/imagemagick-policy.xml /etc/ImageMagick-7/policy.xml

# Copy entrypoint and health check
COPY php-fpm-nginx/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-fpm-nginx/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

# Create directories
RUN mkdir -p /var/www/html /run/nginx && \
    chown -R www-data:www-data /var/www

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

WORKDIR /var/www/html

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
