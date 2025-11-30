FROM php:8.3-cli-bookworm

LABEL maintainer="Sylvester Damgaard <sn@cbox.dk>"
LABEL org.opencontainers.image.source="https://github.com/phpeek/baseimages"
LABEL org.opencontainers.image.description="PHP 8.3 CLI Debian Bookworm - Production"

ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    wget \
    git \
    unzip \
    # Database drivers
    libpq-dev \
    # Internationalization
    libicu-dev \
    # Compression
    libzip-dev \
    zlib1g-dev \
    # Misc
    libonig-dev \
    libsodium-dev \
    # Build essentials
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install PHP core extensions
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

# Clean up
RUN apt-get purge -y --auto-remove build-essential && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

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
