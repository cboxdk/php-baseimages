FROM php:8.2-fpm-bookworm

LABEL maintainer="Sylvester Damgaard <sn@cbox.dk>"
LABEL org.opencontainers.image.source="https://github.com/phpeek/baseimages"
LABEL org.opencontainers.image.description="PHP 8.2 FPM Debian Bookworm Bookworm - Production"

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
    netcat-openbsd \
    fcgi \
    redis-server \
    # Image processing
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libwebp-dev \
    libavif-dev \
    libmagickwand-dev \
    imagemagick \
    libvips-dev \
    libvips-tools \
    # Database drivers
    libpq-dev \
    # Internationalization
    libicu-dev \
    # XML processing
    libxml2-dev \
    libxslt1-dev \
    # Compression
    libzip-dev \
    zlib1g-dev \
    libbz2-dev \
    # Misc
    libonig-dev \
    libsodium-dev \
    libldap2-dev \
    libc-client-dev \
    libkrb5-dev \
    libssl-dev \
    # Image metadata tools
    libimage-exiftool-perl \
    # Build essentials
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Configure GD with support for multiple formats
RUN docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg \
    --with-webp \
    --with-avif

# Configure IMAP with Kerberos
RUN docker-php-ext-configure imap \
    --with-kerberos \
    --with-imap-ssl

# Install PHP core extensions
RUN docker-php-ext-install -j$(nproc) \
    opcache \
    pdo_mysql \
    pdo_pgsql \
    mysqli \
    pgsql \
    zip \
    intl \
    bcmath \
    gd \
    exif \
    pcntl \
    soap \
    sockets \
    xsl \
    calendar \
    gettext \
    shmop \
    sysvmsg \
    sysvsem \
    sysvshm \
    bz2 \
    ldap \
    imap

# Install PECL extensions
RUN pecl install redis-6.0.2 && \
    pecl install imagick && \
    pecl install vips && \
    pecl install mongodb && \
    pecl install apcu-5.1.23 && \
    docker-php-ext-enable redis imagick vips mongodb apcu

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Clean up
RUN apt-get purge -y --auto-remove build-essential && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

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
COPY php-fpm/common/php.ini /usr/local/etc/php/conf.d/99-custom.ini
COPY php-fpm/common/fpm-pool.conf /usr/local/etc/php-fpm.d/zz-custom.conf

# Create directories
RUN mkdir -p /var/www/html && \
    chown -R www-data:www-data /var/www && \
    mkdir -p /tmp/xdebug && \
    chown -R www-data:www-data /tmp/xdebug

WORKDIR /var/www/html

EXPOSE 9000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

CMD ["php-fpm"]
