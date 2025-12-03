# ============================================================================
# PHPeek Swoole Image - Debian 8.2 (Bookworm)
# ============================================================================
# Extends php-base with Swoole extension for async/coroutine PHP
# Used with Laravel Octane, Hyperf, and other Swoole-based frameworks
# ============================================================================

FROM ghcr.io/gophpeek/baseimages/php-base:8.2-bookworm

LABEL org.opencontainers.image.title="PHPeek Swoole 8.2 Debian"
LABEL org.opencontainers.image.description="PHP with Swoole, all extensions, Composer, Node.js, and PHPeek PM"
LABEL org.opencontainers.image.vendor="PHPeek"
LABEL org.opencontainers.image.source="https://github.com/gophpeek/baseimages"

# Install Swoole build dependencies and compile
RUN apt-get update && apt-get install -y --no-install-recommends \
        $PHPIZE_DEPS \
        libssl-dev \
        libcurl4-openssl-dev \
        libc-ares-dev \
        libpq-dev \
    && pecl install swoole \
    && docker-php-ext-enable swoole \
    && apt-get purge -y $PHPIZE_DEPS \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* /tmp/pear

# Copy entrypoint and healthcheck
COPY php-swoole/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-swoole/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

# Create directories
RUN mkdir -p /var/www/html /docker-entrypoint-init.d && \
    chown -R www-data:www-data /var/www/html

# Swoole-specific PHP settings
RUN echo "swoole.use_shortname = Off" >> /usr/local/etc/php/conf.d/docker-php-ext-swoole.ini

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

WORKDIR /var/www/html

# Default port for Laravel Octane
EXPOSE 8000

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["swoole"]
