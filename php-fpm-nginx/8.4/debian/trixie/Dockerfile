# ============================================================================
# PHPeek PHP-FPM + Nginx Image - Debian 13 (Trixie) PHP 8.4
# ============================================================================
# LAYER 4: Extends php-fpm with Nginx for single-container deployment
#          Uses PHPeek PM as process manager
# ============================================================================

FROM ghcr.io/phpeek/baseimages/php-fpm:8.4-trixie

LABEL org.opencontainers.image.title="PHPeek PHP-FPM + Nginx 8.4 Trixie"
LABEL org.opencontainers.image.description="PHP-FPM + Nginx with all extensions, Composer, Node.js, and PHPeek PM"
LABEL org.opencontainers.image.vendor="PHPeek"
LABEL org.opencontainers.image.source="https://github.com/phpeek/baseimages"

# Install Nginx
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Create nginx directories
RUN mkdir -p /etc/nginx/conf.d /var/log/nginx /run/nginx && \
    chown -R www-data:www-data /var/log/nginx /run/nginx

# Debian nginx uses www-data by default, but let's ensure it
RUN sed -i 's/user nginx;/user www-data;/' /etc/nginx/nginx.conf 2>/dev/null || true

# Copy Nginx configuration
COPY php-fpm-nginx/common/default.conf /etc/nginx/conf.d/default.conf
COPY php-fpm-nginx/common/default.conf.template /etc/nginx/conf.d/default.conf.template

# Copy PHPeek PM configuration
RUN mkdir -p /etc/phpeek-pm
COPY php-fpm-nginx/common/phpeek-pm.yaml /etc/phpeek-pm/phpeek-pm.yaml

# Copy entrypoint and healthcheck (overrides php-fpm versions)
COPY php-fpm-nginx/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-fpm-nginx/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

# Create public directory if it doesn't exist
RUN mkdir -p /var/www/html/public && \
    chown -R www-data:www-data /var/www/html

# Health check (checks both nginx and php-fpm)
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

WORKDIR /var/www/html

# Expose both HTTP and HTTPS
EXPOSE 80 443

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["phpeek-pm"]
