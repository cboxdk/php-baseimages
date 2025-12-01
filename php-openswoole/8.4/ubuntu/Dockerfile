# ============================================================================
# PHPeek OpenSwoole Image - Ubuntu 8.4 (24.04 Noble)
# ============================================================================
# Extends php-base with OpenSwoole extension for async/coroutine PHP
# OpenSwoole is a fork of Swoole with some different features
# Used with Laravel Octane, Hyperf, and other async frameworks
# NOTE: Ubuntu uses Ondrej PPA which may have php-openswoole package
# ============================================================================

FROM ghcr.io/phpeek/baseimages/php-base:8.4-ubuntu

LABEL org.opencontainers.image.title="PHPeek OpenSwoole 8.4 Ubuntu"
LABEL org.opencontainers.image.description="PHP with OpenSwoole, all extensions, Composer, Node.js, and PHPeek PM"
LABEL org.opencontainers.image.vendor="PHPeek"
LABEL org.opencontainers.image.source="https://github.com/phpeek/baseimages"

# Install OpenSwoole from Ondrej PPA (if available) or compile
RUN apt-get update && \
    if apt-cache show php8.4-openswoole >/dev/null 2>&1; then \
        apt-get install -y --no-install-recommends php8.4-openswoole; \
    else \
        apt-get install -y --no-install-recommends \
            php8.4-dev \
            libssl-dev \
            libcurl4-openssl-dev \
            libc-ares-dev \
            libpq-dev && \
        pecl install openswoole && \
        echo "extension=openswoole.so" > /etc/php/8.4/cli/conf.d/20-openswoole.ini && \
        apt-get purge -y php8.4-dev && \
        apt-get autoremove -y; \
    fi && \
    rm -rf /var/lib/apt/lists/*

# Copy entrypoint and healthcheck
COPY php-openswoole/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-openswoole/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

# Create directories
RUN mkdir -p /var/www/html /docker-entrypoint-init.d && \
    chown -R www-data:www-data /var/www/html

# OpenSwoole-specific PHP settings
RUN echo "openswoole.use_shortname = Off" >> /etc/php/8.4/cli/conf.d/99-openswoole-settings.ini

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

WORKDIR /var/www/html

# Default port for Laravel Octane
EXPOSE 8000

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["openswoole"]
