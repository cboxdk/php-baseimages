# ============================================================================
# PHPeek OpenSwoole Image - Alpine 8.4
# ============================================================================
# Extends php-base with OpenSwoole extension for async/coroutine PHP
# OpenSwoole is a fork of Swoole with some different features
# Used with Laravel Octane, Hyperf, and other async frameworks
# ============================================================================

FROM ghcr.io/phpeek/baseimages/php-base:8.4-alpine

LABEL org.opencontainers.image.title="PHPeek OpenSwoole 8.4 Alpine"
LABEL org.opencontainers.image.description="PHP with OpenSwoole, all extensions, Composer, Node.js, and PHPeek PM"
LABEL org.opencontainers.image.vendor="PHPeek"
LABEL org.opencontainers.image.source="https://github.com/phpeek/baseimages"

# Install OpenSwoole build dependencies and compile
RUN apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        openssl-dev \
        curl-dev \
        c-ares-dev \
        postgresql-dev \
        linux-headers \
    && pecl install openswoole \
    && docker-php-ext-enable openswoole \
    && apk del .build-deps \
    && rm -rf /tmp/pear

# Runtime dependencies for OpenSwoole
RUN apk add --no-cache \
    c-ares \
    openssl

# Copy entrypoint and healthcheck
COPY php-openswoole/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-openswoole/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

# Create directories
RUN mkdir -p /var/www/html /docker-entrypoint-init.d && \
    chown -R www-data:www-data /var/www/html

# OpenSwoole-specific PHP settings
RUN echo "openswoole.use_shortname = Off" >> /usr/local/etc/php/conf.d/docker-php-ext-openswoole.ini

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

WORKDIR /var/www/html

# Default port for Laravel Octane
EXPOSE 8000

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["openswoole"]
