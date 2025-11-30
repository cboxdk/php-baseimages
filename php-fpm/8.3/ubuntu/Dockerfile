FROM ubuntu:24.04

LABEL maintainer="Sylvester Damgaard <sn@cbox.dk>"
LABEL org.opencontainers.image.source="https://github.com/phpeek/baseimages"
LABEL org.opencontainers.image.description="PHP 8.3 FPM Ubuntu 24.04 24.04 - Production"

ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG DEBIAN_FRONTEND=noninteractive

# Add Ondrej PHP PPA for PHP 8.3
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    ca-certificates \
    && add-apt-repository ppa:ondrej/php \
    && apt-get update

# Install PHP-FPM and extensions
RUN apt-get install -y --no-install-recommends \
    php8.3-fpm \
    php8.3-cli \
    php8.3-common \
    # Core extensions
    php8.3-opcache \
    php8.3-mysql \
    php8.3-pgsql \
    php8.3-sqlite3 \
    php8.3-redis \
    php8.3-memcached \
    # Image processing
    php8.3-gd \
    php8.3-imagick \
    # Data formats
    php8.3-xml \
    php8.3-xsl \
    php8.3-soap \
    php8.3-mbstring \
    php8.3-zip \
    php8.3-bz2 \
    # Internationalization
    php8.3-intl \
    # Math
    php8.3-bcmath \
    php8.3-gmp \
    # Misc
    php8.3-curl \
    php8.3-ldap \
    php8.3-imap \
    php8.3-apcu \
    # System utilities
    bash \
    curl \
    wget \
    git \
    unzip \
    netcat-openbsd \
    fcgi \
    redis-server \
    # Image metadata tools
    libimage-exiftool-perl \
    && rm -rf /var/lib/apt/lists/*

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Configure PHP-FPM to run in foreground
RUN sed -i 's/;daemonize = yes/daemonize = no/g' /etc/php/8.3/fpm/php-fpm.conf

# Create ImageMagick security policy
RUN mkdir -p /etc/ImageMagick-6 && \
    cat > /etc/ImageMagick-6/policy.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<policymap>
  <!-- Disable dangerous coders -->
  <policy domain="coder" rights="none" pattern="EPHEMERAL" />
  <policy domain="coder" rights="none" pattern="URL" />
  <policy domain="coder" rights="none" pattern="HTTPS" />
  <policy domain="coder" rights="none" pattern="MVG" />
  <policy domain="coder" rights="none" pattern="MSL" />

  <!-- Resource limits -->
  <policy domain="resource" name="memory" value="512MiB"/>
  <policy domain="resource" name="map" value="1GiB"/>
  <policy domain="resource" name="width" value="16KP"/>
  <policy domain="resource" name="height" value="16KP"/>
  <policy domain="resource" name="area" value="128MP"/>
  <policy domain="resource" name="disk" value="1GiB"/>
</policymap>
EOF


# Copy PHP configuration
COPY php-fpm/common/php.ini /etc/php/8.3/fpm/conf.d/99-custom.ini
COPY php-fpm/common/fpm-pool.conf /etc/php/8.3/fpm/pool.d/zz-custom.conf

# Create directories
RUN mkdir -p /var/www/html && \
    chown -R www-data:www-data /var/www && \
    mkdir -p /tmp/xdebug && \
    chown -R www-data:www-data /tmp/xdebug && \
    mkdir -p /run/php && \
    chown -R www-data:www-data /run/php

# Update FPM pool to listen on port 9000 instead of socket
RUN sed -i 's#listen = /run/php/php8.3-fpm.sock#listen = 9000#g' /etc/php/8.3/fpm/pool.d/www.conf

WORKDIR /var/www/html

EXPOSE 9000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD php-fpm8.3 -t || exit 1

CMD ["php-fpm8.3"]
