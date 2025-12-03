# ============================================================================
# PHPeek PHP-FPM + Nginx Image - Alpine 8.3
# ============================================================================
# LAYER 4: Extends php-fpm with Nginx for single-container deployment
#          Uses PHPeek PM as process manager
# ============================================================================

# ═══════════════════════════════════════════════════════════════════════════
# ROOT VARIANT (default) - Runs as root, PUID/PGID mapping at runtime
# ═══════════════════════════════════════════════════════════════════════════
FROM ghcr.io/gophpeek/baseimages/php-fpm:8.3-alpine AS root

LABEL org.opencontainers.image.title="PHPeek PHP-FPM + Nginx 8.3 Alpine"
LABEL org.opencontainers.image.description="PHP-FPM + Nginx with all extensions, Composer, Node.js, and PHPeek PM"
LABEL org.opencontainers.image.vendor="PHPeek"
LABEL org.opencontainers.image.source="https://github.com/gophpeek/baseimages"

# Install Nginx
RUN apk add --no-cache nginx gettext

# Create nginx directories
RUN mkdir -p /etc/nginx/conf.d /var/log/nginx /run/nginx && \
    chown -R www-data:www-data /var/log/nginx /run/nginx

# Fix nginx user for Alpine (runs as nginx by default, we want www-data)
# Also fix conf.d include: Alpine nginx package includes conf.d at root context,
# but we need it inside http block for server directives to work
# Remove Alpine's default 404 server to prevent conflicts with our default_server
RUN sed -i 's/user nginx;/user www-data;/' /etc/nginx/nginx.conf 2>/dev/null || true && \
    sed -i '/^include \/etc\/nginx\/conf\.d\/\*\.conf;/d' /etc/nginx/nginx.conf && \
    sed -i '/include \/etc\/nginx\/http\.d\/\*\.conf;/i\    include /etc/nginx/conf.d/*.conf;' /etc/nginx/nginx.conf && \
    rm -f /etc/nginx/http.d/default.conf

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

# ═══════════════════════════════════════════════════════════════════════════
# ROOTLESS VARIANT - Runs entirely as www-data, no root privileges
# ═══════════════════════════════════════════════════════════════════════════
FROM ghcr.io/gophpeek/baseimages/php-fpm:8.3-alpine-rootless AS rootless

LABEL org.opencontainers.image.title="PHPeek PHP-FPM + Nginx 8.3 Alpine (Rootless)"
LABEL org.opencontainers.image.description="PHP-FPM + Nginx with all extensions, Composer, Node.js, and PHPeek PM - Rootless"
LABEL org.opencontainers.image.vendor="PHPeek"
LABEL org.opencontainers.image.source="https://github.com/gophpeek/baseimages"

# Switch to root temporarily for setup
USER root

# Install Nginx
RUN apk add --no-cache nginx gettext

# Create nginx directories with www-data ownership
# Note: Alpine nginx uses /var/lib/nginx for tmp dirs and internal logs
RUN mkdir -p /etc/nginx/conf.d /var/log/nginx /run/nginx /var/lib/nginx/tmp && \
    chown -R www-data:www-data /var/log/nginx /run/nginx /etc/nginx /var/lib/nginx

# Fix nginx user for Alpine (runs as nginx by default, we want www-data)
# Also fix conf.d include: Alpine nginx package includes conf.d at root context,
# but we need it inside http block for server directives to work
# Remove Alpine's default 404 server to prevent conflicts with our default_server
# Comment out user directive since we run as non-root (www-data can't switch users)
# Move PID file to /run/nginx/ which we own (Alpine default is /run/nginx.pid in root-owned /run/)
RUN sed -i 's/user nginx;/user www-data;/' /etc/nginx/nginx.conf 2>/dev/null || true && \
    sed -i 's/^user www-data;/# user www-data;/' /etc/nginx/nginx.conf && \
    sed -i 's|pid /run/nginx.pid;|pid /run/nginx/nginx.pid;|' /etc/nginx/nginx.conf && \
    sed -i '/^include \/etc\/nginx\/conf\.d\/\*\.conf;/d' /etc/nginx/nginx.conf && \
    sed -i '/include \/etc\/nginx\/http\.d\/\*\.conf;/i\    include /etc/nginx/conf.d/*.conf;' /etc/nginx/nginx.conf && \
    rm -f /etc/nginx/http.d/default.conf

# Copy Nginx configuration (rootless version with port 8080)
# Use --chown to set ownership atomically (avoids cache layer issues)
COPY --chown=www-data:www-data php-fpm-nginx/common/default-rootless.conf /etc/nginx/conf.d/default.conf
COPY --chown=www-data:www-data php-fpm-nginx/common/default.conf.template /etc/nginx/conf.d/default.conf.template

# Copy PHPeek PM configuration (rootless version with port 8080 health check)
RUN mkdir -p /etc/phpeek-pm && chown -R www-data:www-data /etc/phpeek-pm
COPY php-fpm-nginx/common/phpeek-pm-rootless.yaml /etc/phpeek-pm/phpeek-pm.yaml

# Copy entrypoint and healthcheck (overrides php-fpm versions)
COPY php-fpm-nginx/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-fpm-nginx/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

# Create public directory with www-data ownership
RUN mkdir -p /var/www/html/public /var/www/.composer /var/www/.npm /tmp/phpeek && \
    chown -R www-data:www-data /var/www /tmp/phpeek

# Health check (checks both nginx and php-fpm)
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

USER www-data
WORKDIR /var/www/html

# Expose unprivileged HTTP port (ports < 1024 require root)
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["phpeek-pm"]
