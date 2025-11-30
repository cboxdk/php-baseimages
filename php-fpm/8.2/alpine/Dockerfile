FROM php:8.2-fpm-alpine

LABEL maintainer="Sylvester Damgaard <sn@cbox.dk>"
LABEL org.opencontainers.image.source="https://github.com/phpeek/baseimages"
LABEL org.opencontainers.image.description="PHP 8.2 FPM Alpine - Production"

ARG TARGETPLATFORM
ARG BUILDPLATFORM

# Install system dependencies
RUN apk add --no-cache \
    bash \
    curl \
    wget \
    git \
    unzip \
    netcat-openbsd \
    fcgi \
    redis \
    # Image processing
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libwebp-dev \
    libavif-dev \
    imagemagick-dev \
    imagemagick \
    vips-dev \
    vips-tools \
    # Database drivers
    postgresql-dev \
    # Internationalization
    icu-dev \
    icu-data-full \
    # XML processing
    libxml2-dev \
    libxslt-dev \
    # Compression
    libzip-dev \
    zlib-dev \
    bzip2-dev \
    # Misc
    oniguruma-dev \
    libsodium-dev \
    linux-headers \
    gettext-dev \
    openldap-dev \
    imap-dev \
    krb5-dev \
    openssl-dev \
    # Image metadata tools
    exiftool \
    # Build tools (will be removed later)
    $PHPIZE_DEPS

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

# Remove build dependencies to reduce image size
RUN apk del $PHPIZE_DEPS

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

# Copy entrypoint and health check scripts
COPY php-fpm/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-fpm/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

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

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["php-fpm"]
