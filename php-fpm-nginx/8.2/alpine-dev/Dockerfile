# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  PHPeek Base Image - PHP 8.2 FPM + Nginx (Alpine) - DEVELOPMENT           ║
# ║  Includes: Xdebug, SPX Profiler, development PHP settings                 ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
FROM php:8.2-fpm-alpine

# Install system dependencies (including cron for Laravel scheduler)
RUN apk add --no-cache \
    bash curl wget git unzip \
    netcat-openbsd nginx \
    dcron \
    libpng-dev libjpeg-turbo-dev freetype-dev \
    libwebp-dev libavif-dev imagemagick-dev \
    postgresql-dev icu-dev libzip-dev oniguruma-dev \
    libxml2-dev libxslt-dev openldap-dev imap-dev bzip2-dev \
    gettext-dev libmcrypt-dev readline-dev \
    gmp-dev \
    linux-headers gettext-dev \
    $PHPIZE_DEPS

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
    pcntl sockets soap xsl ldap imap bz2 \
    calendar gettext shmop sysvmsg sysvsem sysvshm \
    gmp

# Install PECL extensions (igbinary first, then others can use it)
RUN pecl install igbinary-3.2.15 && \
    docker-php-ext-enable igbinary && \
    pecl install redis-6.0.2 imagick apcu-5.1.23 msgpack-3.0.0 mongodb-1.20.1 && \
    docker-php-ext-enable redis imagick apcu msgpack mongodb

# ─────────────────────────────────────────────────────────────────────────────
# DEV TOOLS: Xdebug + SPX Profiler
# ─────────────────────────────────────────────────────────────────────────────
RUN pecl install xdebug-3.3.2 && \
    docker-php-ext-enable xdebug

# Create Xdebug directories
RUN mkdir -p /tmp/xdebug /tmp/spx && \
    chmod 777 /tmp/xdebug /tmp/spx

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Install PHPeek PM (Process Manager) with multi-arch support and integrity verification
ARG PHPEEK_PM_VERSION=1.2.0
ARG PHPEEK_PM_SHA256_AMD64=5a5b6c92374f0c15a338ca3b925884e077269664f281328c133004bfc0879cbd
ARG PHPEEK_PM_SHA256_ARM64=7139ecd6a4570414e801ad343ef02882bbdafd738f755cbef3f2a00a997a0b84
ARG TARGETPLATFORM
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
    wget -O /tmp/phpeek-pm \
        "https://github.com/phpeek/phpeek-pm/releases/download/v${PHPEEK_PM_VERSION}/phpeek-pm-linux-${PHPEEK_PM_ARCH}"; \
    echo "${PHPEEK_PM_CHECKSUM}  /tmp/phpeek-pm" | sha256sum -c -; \
    mv /tmp/phpeek-pm /usr/local/bin/phpeek-pm; \
    chmod +x /usr/local/bin/phpeek-pm; \
    /usr/local/bin/phpeek-pm --version || echo "PHPeek PM ${PHPEEK_PM_VERSION} installed"

# Copy PHP DEV configurations (with Xdebug)
COPY php-fpm/common/php-dev.ini /usr/local/etc/php/conf.d/99-custom.ini
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

# Expose HTTP port + Xdebug port
EXPOSE 80 9003

# Development labels
LABEL org.opencontainers.image.description="PHPeek PHP 8.2 FPM + Nginx (Alpine) - Development Edition with Xdebug"
LABEL org.phpeek.edition="dev"
LABEL org.phpeek.xdebug.version="3.3.2"

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
