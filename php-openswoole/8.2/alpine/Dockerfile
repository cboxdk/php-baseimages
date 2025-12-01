# ============================================================================
# PHPeek OpenSwoole Image - Alpine 8.2
# ============================================================================
# Extends php-base with OpenSwoole extension for async/coroutine PHP
# ============================================================================

FROM ghcr.io/phpeek/baseimages/php-base:8.2-alpine

LABEL org.opencontainers.image.title="PHPeek OpenSwoole 8.2 Alpine"
LABEL org.opencontainers.image.description="PHP with OpenSwoole, all extensions, Composer, Node.js, and PHPeek PM"
LABEL org.opencontainers.image.vendor="PHPeek"
LABEL org.opencontainers.image.source="https://github.com/phpeek/baseimages"

RUN apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS openssl-dev curl-dev c-ares-dev postgresql-dev linux-headers \
    && pecl install openswoole \
    && docker-php-ext-enable openswoole \
    && apk del .build-deps \
    && rm -rf /tmp/pear

RUN apk add --no-cache c-ares openssl

COPY php-openswoole/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-openswoole/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

RUN mkdir -p /var/www/html /docker-entrypoint-init.d && \
    chown -R www-data:www-data /var/www/html

RUN echo "openswoole.use_shortname = Off" >> /usr/local/etc/php/conf.d/docker-php-ext-openswoole.ini

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

WORKDIR /var/www/html
EXPOSE 8000
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["openswoole"]
