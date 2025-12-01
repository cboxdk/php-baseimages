# ============================================================================
# PHPeek Swoole Image - Ubuntu 8.4 (24.04 Noble)
# ============================================================================
# Extends php-base with Swoole extension for async/coroutine PHP
# Used with Laravel Octane, Hyperf, and other Swoole-based frameworks
# NOTE: Ubuntu uses Ondrej PPA which may have php-swoole package
# ============================================================================

FROM ghcr.io/phpeek/baseimages/php-base:8.4-ubuntu

LABEL org.opencontainers.image.title="PHPeek Swoole 8.4 Ubuntu"
LABEL org.opencontainers.image.description="PHP with Swoole, all extensions, Composer, Node.js, and PHPeek PM"
LABEL org.opencontainers.image.vendor="PHPeek"
LABEL org.opencontainers.image.source="https://github.com/phpeek/baseimages"

# Install Swoole from Ondrej PPA (if available) or compile
RUN apt-get update && \
    if apt-cache show php8.4-swoole >/dev/null 2>&1; then \
        apt-get install -y --no-install-recommends php8.4-swoole; \
    else \
        apt-get install -y --no-install-recommends \
            php8.4-dev \
            libssl-dev \
            libcurl4-openssl-dev \
            libc-ares-dev \
            libpq-dev && \
        pecl install swoole && \
        echo "extension=swoole.so" > /etc/php/8.4/cli/conf.d/20-swoole.ini && \
        apt-get purge -y php8.4-dev && \
        apt-get autoremove -y; \
    fi && \
    rm -rf /var/lib/apt/lists/*

# Copy entrypoint and healthcheck
COPY php-swoole/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-swoole/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

# Create directories
RUN mkdir -p /var/www/html /docker-entrypoint-init.d && \
    chown -R www-data:www-data /var/www/html

# Swoole-specific PHP settings
RUN echo "swoole.use_shortname = Off" >> /etc/php/8.4/cli/conf.d/99-swoole-settings.ini

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

WORKDIR /var/www/html

# Default port for Laravel Octane
EXPOSE 8000

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["swoole"]
