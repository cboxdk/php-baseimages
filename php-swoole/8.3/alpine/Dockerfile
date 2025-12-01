# ============================================================================
# PHPeek Swoole Image - Alpine 8.3
# ============================================================================
# Extends php-base with Swoole extension for async/coroutine PHP
# Used with Laravel Octane, Hyperf, and other Swoole-based frameworks
# ============================================================================

FROM ghcr.io/phpeek/baseimages/php-base:8.3-alpine

LABEL org.opencontainers.image.title="PHPeek Swoole 8.3 Alpine"
LABEL org.opencontainers.image.description="PHP with Swoole, all extensions, Composer, Node.js, and PHPeek PM"
LABEL org.opencontainers.image.vendor="PHPeek"
LABEL org.opencontainers.image.source="https://github.com/phpeek/baseimages"

# Install Swoole build dependencies and compile
RUN apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        openssl-dev \
        curl-dev \
        c-ares-dev \
        postgresql-dev \
        linux-headers \
    && pecl install swoole \
    && docker-php-ext-enable swoole \
    && apk del .build-deps \
    && rm -rf /tmp/pear

# Runtime dependencies for Swoole
RUN apk add --no-cache \
    c-ares \
    openssl

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
