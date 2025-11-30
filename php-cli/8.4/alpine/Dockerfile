FROM php:8.4-cli-alpine

LABEL maintainer="Sylvester Damgaard <sn@cbox.dk>"
LABEL org.opencontainers.image.source="https://github.com/phpeek/baseimages"
LABEL org.opencontainers.image.description="PHP 8.4 CLI Alpine - Production"

ARG TARGETPLATFORM
ARG BUILDPLATFORM

# Install system dependencies (lighter than FPM)
RUN apk add --no-cache \
    bash \
    curl \
    wget \
    git \
    unzip \
    # Database drivers
    postgresql-dev \
    # Internationalization
    icu-dev \
    icu-data-full \
    # Compression
    libzip-dev \
    zlib-dev \
    # Misc
    oniguruma-dev \
    libsodium-dev \
    linux-headers \
    gettext-dev \
    # Build tools (will be removed later)
    $PHPIZE_DEPS

# Install PHP core extensions (subset relevant for CLI)
RUN docker-php-ext-install -j$(nproc) \
    opcache \
    pdo_mysql \
    pdo_pgsql \
    zip \
    intl \
    bcmath \
    pcntl \
    sockets \
    calendar \
    gettext \
    shmop \
    sysvmsg \
    sysvsem \
    sysvshm

# Install PECL extensions
RUN pecl install redis-6.0.2 && \
    pecl install apcu-5.1.23 && \
    docker-php-ext-enable redis apcu

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Remove build dependencies to reduce image size
RUN apk del $PHPIZE_DEPS

# Copy PHP configuration
COPY php-cli/common/php.ini /usr/local/etc/php/conf.d/99-custom.ini

# Copy entrypoint and health check scripts
COPY php-cli/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-cli/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

# Create directories
RUN mkdir -p /var/www/html && \
    chown -R www-data:www-data /var/www

WORKDIR /var/www/html

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["php", "-a"]
