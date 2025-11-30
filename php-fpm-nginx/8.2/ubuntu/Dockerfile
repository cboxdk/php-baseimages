# Stage 1: Get Node.js from official image (enables version control via build arg)
ARG NODE_VERSION=22
FROM node:${NODE_VERSION}-slim AS node

# Stage 2: Ubuntu base image
FROM ubuntu:24.04

# Copy Node.js binaries from official node image
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules

# Create npm/npx symlinks
RUN ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -sf /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

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
    curl wget git unzip netcat-openbsd \
    nginx cron \
    libimage-exiftool-perl \
    # Chromium for Browsershot/Puppeteer PDF generation
    chromium-browser \
    fonts-liberation \
    libnss3 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libgbm1 \
    libasound2t64 \
    && rm -rf /var/lib/apt/lists/*

# Set Puppeteer to use installed Chromium
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

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
COPY php-fpm/common/php.ini.template /etc/php/8.2/fpm/conf.d/99-custom.ini.template
COPY php-fpm/common/php.ini /etc/php/8.2/fpm/conf.d/99-custom.ini
COPY php-fpm/common/php.ini /etc/php/8.2/cli/conf.d/99-custom.ini
COPY php-fpm/common/fpm-pool.conf /etc/php/8.2/fpm/pool.d/zz-custom.conf

# Copy Nginx configurations (template + static)
COPY nginx/ubuntu/nginx.conf /etc/nginx/nginx.conf
COPY php-fpm-nginx/common/default.conf.template /etc/nginx/conf.d/default.conf.template
COPY php-fpm-nginx/common/default.conf /etc/nginx/conf.d/default.conf

# Fix nginx user for Ubuntu (uses www-data not nginx)
RUN sed -i 's/user nginx;/user www-data;/' /etc/nginx/nginx.conf

# Update PHP-FPM to listen on 0.0.0.0:9000 instead of socket
RUN sed -i 's|listen = /run/php/php8.2-fpm.sock|listen = 0.0.0.0:9000|' /etc/php/8.2/fpm/pool.d/www.conf

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
    ln -sf /usr/sbin/php-fpm8.2 /usr/sbin/php-fpm

# Create directories
RUN mkdir -p /var/www/html /run/nginx /run/php && \
    chown -R www-data:www-data /var/www

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

WORKDIR /var/www/html

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
