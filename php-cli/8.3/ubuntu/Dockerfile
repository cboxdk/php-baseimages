FROM ubuntu:24.04

LABEL maintainer="Sylvester Damgaard <sn@cbox.dk>"
LABEL org.opencontainers.image.source="https://github.com/phpeek/baseimages"
LABEL org.opencontainers.image.description="PHP 8.3 CLI Ubuntu 24.04 - Production"

ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG DEBIAN_FRONTEND=noninteractive

# Add Ondrej PHP PPA for PHP 8.3
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    ca-certificates \
    && add-apt-repository ppa:ondrej/php \
    && apt-get update

# Install PHP-CLI and extensions
RUN apt-get install -y --no-install-recommends \
    php8.3-cli \
    php8.3-common \
    # Core extensions
    php8.3-opcache \
    php8.3-mysql \
    php8.3-pgsql \
    php8.3-sqlite3 \
    php8.3-redis \
    # Data formats
    php8.3-xml \
    php8.3-mbstring \
    php8.3-zip \
    # Internationalization
    php8.3-intl \
    # Math
    php8.3-bcmath \
    # Misc
    php8.3-curl \
    php8.3-apcu \
    # System utilities
    bash \
    curl \
    wget \
    git \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Copy PHP configuration
COPY php-cli/common/php.ini /etc/php/8.3/cli/conf.d/99-custom.ini

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
