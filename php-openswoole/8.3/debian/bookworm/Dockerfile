# ============================================================================
# Cbox OpenSwoole Image - Debian 8.3 (Bookworm)
# ============================================================================

FROM ghcr.io/cboxdk/baseimages/php-base:8.3-bookworm

LABEL org.opencontainers.image.title="Cbox OpenSwoole 8.3 Debian"
LABEL org.opencontainers.image.description="PHP with OpenSwoole, all extensions, Composer, Node.js, and Cbox Init"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/baseimages"

RUN apt-get update && apt-get install -y --no-install-recommends \
        $PHPIZE_DEPS libssl-dev libcurl4-openssl-dev libc-ares-dev libpq-dev \
    && pecl install openswoole \
    && docker-php-ext-enable openswoole \
    && apt-get purge -y $PHPIZE_DEPS && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* /tmp/pear

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
