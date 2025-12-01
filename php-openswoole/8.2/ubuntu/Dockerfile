# ============================================================================
# PHPeek OpenSwoole Image - Ubuntu 8.2 (24.04 Noble)
# ============================================================================

FROM ghcr.io/phpeek/baseimages/php-base:8.2-ubuntu

LABEL org.opencontainers.image.title="PHPeek OpenSwoole 8.2 Ubuntu"
LABEL org.opencontainers.image.description="PHP with OpenSwoole, all extensions, Composer, Node.js, and PHPeek PM"
LABEL org.opencontainers.image.vendor="PHPeek"
LABEL org.opencontainers.image.source="https://github.com/phpeek/baseimages"

RUN apt-get update && \
    if apt-cache show php8.2-openswoole >/dev/null 2>&1; then \
        apt-get install -y --no-install-recommends php8.2-openswoole; \
    else \
        apt-get install -y --no-install-recommends php8.2-dev libssl-dev libcurl4-openssl-dev libc-ares-dev libpq-dev && \
        pecl install openswoole && \
        echo "extension=openswoole.so" > /etc/php/8.2/cli/conf.d/20-openswoole.ini && \
        apt-get purge -y php8.2-dev && apt-get autoremove -y; \
    fi && rm -rf /var/lib/apt/lists/*

COPY php-openswoole/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-openswoole/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

RUN mkdir -p /var/www/html /docker-entrypoint-init.d && \
    chown -R www-data:www-data /var/www/html

RUN echo "openswoole.use_shortname = Off" >> /etc/php/8.2/cli/conf.d/99-openswoole-settings.ini

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

WORKDIR /var/www/html
EXPOSE 8000
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["openswoole"]
