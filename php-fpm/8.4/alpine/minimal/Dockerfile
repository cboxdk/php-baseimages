FROM php:8.4-fpm-alpine

LABEL maintainer="Sylvester Damgaard <sn@cbox.dk>"
LABEL org.opencontainers.image.source="https://github.com/phpeek/baseimages"
LABEL org.opencontainers.image.description="PHP 8.4 FPM Alpine - Minimal Edition (Laravel-Optimized)"

ARG TARGETPLATFORM
ARG BUILDPLATFORM

# Install minimal system dependencies
RUN apk add --no-cache \
    bash \
    curl \
    wget \
    git \
    unzip \
    netcat-openbsd \
    fcgi \
    # Image processing (GD)
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libwebp-dev \
    # Database drivers
    postgresql-dev \
    # Internationalization
    icu-dev \
    icu-data-full \
    # Compression
    libzip-dev \
    # Build tools
    $PHPIZE_DEPS

# Configure GD with modern format support
RUN docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg \
    --with-webp

# Install PHP core extensions (Minimal - Laravel optimized)
RUN docker-php-ext-install -j$(nproc) \
    opcache \
    pdo_mysql \
    pdo_pgsql \
    mysqli \
    zip \
    intl \
    bcmath \
    gd \
    exif \
    pcntl

# Install Redis (PECL)
RUN pecl install redis-6.0.2 && \
    docker-php-ext-enable redis

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Remove build dependencies to reduce image size
RUN apk del $PHPIZE_DEPS

# Copy PHP configuration (minimal)
COPY php-fpm/common/php-minimal.ini /usr/local/etc/php/conf.d/99-custom.ini
COPY php-fpm/common/fpm-pool.conf /usr/local/etc/php-fpm.d/zz-custom.conf

# Create directories
RUN mkdir -p /var/www/html && \
    chown -R www-data:www-data /var/www

WORKDIR /var/www/html

EXPOSE 9000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD SCRIPT_NAME=/ping SCRIPT_FILENAME=/ping REQUEST_METHOD=GET cgi-fcgi -bind -connect 127.0.0.1:9000 || exit 1

CMD ["php-fpm"]
