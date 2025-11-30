# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  PHPeek Base Image - PHP 8.2 FPM + Nginx (Ubuntu) - DEVELOPMENT           ║
# ║  Includes: Xdebug, SPX Profiler, development PHP settings                 ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
FROM ubuntu:24.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install PHP 8.2 from Ondrej PPA and system dependencies (including cron)
RUN apt-get update && apt-get install -y software-properties-common && \
    add-apt-repository ppa:ondrej/php -y && \
    apt-get update && apt-get install -y \
    php8.2-fpm php8.2-cli php8.2-common \
    php8.2-opcache php8.2-mysql php8.2-pgsql php8.2-redis php8.2-imagick \
    php8.2-gd php8.2-intl php8.2-bcmath php8.2-zip php8.2-xml \
    php8.2-mbstring php8.2-curl php8.2-soap php8.2-ldap php8.2-imap \
    php8.2-bz2 php8.2-readline php8.2-apcu php8.2-gmp php8.2-igbinary php8.2-msgpack php8.2-mongodb \
    php8.2-xdebug \
    curl wget git unzip netcat-openbsd \
    nginx cron \
    && rm -rf /var/lib/apt/lists/*

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
COPY php-fpm/common/php-dev.ini /etc/php/8.3/fpm/conf.d/99-custom.ini
COPY php-fpm/common/php-dev.ini /etc/php/8.3/cli/conf.d/99-custom.ini
COPY php-fpm/common/fpm-pool.conf /etc/php/8.3/fpm/pool.d/zz-custom.conf

# Copy Nginx configurations (template + static)
COPY nginx/ubuntu/nginx.conf /etc/nginx/nginx.conf
COPY php-fpm-nginx/common/default.conf.template /etc/nginx/conf.d/default.conf.template
COPY php-fpm-nginx/common/default.conf /etc/nginx/conf.d/default.conf

# Fix nginx user for Ubuntu (uses www-data not nginx)
RUN sed -i 's/user nginx;/user www-data;/' /etc/nginx/nginx.conf

# Update PHP-FPM to listen on 0.0.0.0:9000 instead of socket
RUN sed -i 's|listen = /run/php/php8.2-fpm.sock|listen = 0.0.0.0:9000|' /etc/php/8.3/fpm/pool.d/www.conf

# Copy PHPeek PM configuration template
RUN mkdir -p /etc/phpeek-pm
COPY php-fpm-nginx/common/phpeek-pm.yaml /etc/phpeek-pm/phpeek-pm.yaml

# Copy ImageMagick security policy (prevents XXE, ghostscript exploits, SSRF)
# Ubuntu uses ImageMagick-6
COPY php-fpm-nginx/common/imagemagick-policy.xml /etc/ImageMagick-6/policy.xml

# Copy entrypoint and health check
COPY php-fpm-nginx/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-fpm-nginx/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

# Create symlinks for php commands
RUN ln -sf /usr/bin/php8.2 /usr/bin/php && \
    ln -sf /usr/sbin/php-fpm8.3 /usr/sbin/php-fpm

# Create directories
RUN mkdir -p /var/www/html /run/nginx /run/php && \
    chown -R www-data:www-data /var/www

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

WORKDIR /var/www/html

# Expose HTTP port + Xdebug port
EXPOSE 80 9003

# Development labels
LABEL org.opencontainers.image.description="PHPeek PHP 8.2 FPM + Nginx (Ubuntu) - Development Edition with Xdebug"
LABEL org.phpeek.edition="dev"
LABEL org.phpeek.xdebug.version="3.3"

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
