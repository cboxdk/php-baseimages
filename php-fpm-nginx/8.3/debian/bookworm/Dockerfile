# ============================================================================
# Cbox PHP-FPM + Nginx Image - Debian 8.3 (Bookworm)
# ============================================================================
# LAYER 4: Extends php-fpm with Nginx for single-container deployment
#          Uses Cbox PM as process manager
#
# IMAGE TIERS (inherited from php-fpm):
# - slim:     Minimal PHP + essential extensions - API/microservices
# - standard: + ImageMagick, vips, Node.js - Most Laravel apps (DEFAULT)
# - full:     + Chromium for Browsershot/Dusk - PDF generation, testing
# ============================================================================

# ============================================================================
# Import base images for each tier from php-fpm
# ============================================================================
FROM ghcr.io/cboxdk/baseimages/php-fpm:8.3-bookworm-slim AS base-slim
FROM ghcr.io/cboxdk/baseimages/php-fpm:8.3-bookworm-slim-rootless AS base-slim-rootless
FROM ghcr.io/cboxdk/baseimages/php-fpm:8.3-bookworm AS base-standard
FROM ghcr.io/cboxdk/baseimages/php-fpm:8.3-bookworm-rootless AS base-standard-rootless
FROM ghcr.io/cboxdk/baseimages/php-fpm:8.3-bookworm-full AS base-full
FROM ghcr.io/cboxdk/baseimages/php-fpm:8.3-bookworm-full-rootless AS base-full-rootless

# ═══════════════════════════════════════════════════════════════════════════
# SLIM-ROOT: Minimal PHP-FPM + Nginx
# ═══════════════════════════════════════════════════════════════════════════
FROM base-slim AS slim-root

LABEL org.opencontainers.image.title="Cbox PHP-FPM + Nginx 8.3 Bookworm (Slim)"
LABEL org.opencontainers.image.description="Minimal PHP-FPM + Nginx with essential extensions"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/baseimages"

ENV CBOX_IMAGE_TIER=slim

# Install Nginx
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Create nginx directories
RUN mkdir -p /etc/nginx/conf.d /var/log/nginx /run/nginx && \
    chown -R www-data:www-data /var/log/nginx /run/nginx

# Debian nginx uses www-data by default, but let's ensure it
# Also remove the default site that conflicts with our configuration
RUN sed -i 's/user nginx;/user www-data;/' /etc/nginx/nginx.conf 2>/dev/null || true && \
    rm -f /etc/nginx/sites-enabled/default

# Copy Nginx configuration
COPY php-fpm-nginx/common/default.conf /etc/nginx/conf.d/default.conf
COPY php-fpm-nginx/common/default.conf.template /etc/nginx/conf.d/default.conf.template

# Copy Cbox PM configuration
RUN mkdir -p /etc/cbox-init
COPY php-fpm-nginx/common/cbox-init.yaml /etc/cbox-init/cbox-init.yaml

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
CMD ["cbox-init"]

# ═══════════════════════════════════════════════════════════════════════════
# SLIM-ROOTLESS: Minimal PHP-FPM + Nginx running as www-data
# ═══════════════════════════════════════════════════════════════════════════
FROM base-slim-rootless AS slim-rootless

LABEL org.opencontainers.image.title="Cbox PHP-FPM + Nginx 8.3 Bookworm (Slim Rootless)"
LABEL org.opencontainers.image.description="Minimal PHP-FPM + Nginx with essential extensions - Rootless"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/baseimages"

ENV CBOX_IMAGE_TIER=slim

# Switch to root temporarily for setup
USER root

# Install Nginx
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Create nginx directories with www-data ownership
# Note: Debian nginx uses /var/lib/nginx for tmp dirs (body, proxy, fastcgi, etc.)
RUN mkdir -p /etc/nginx/conf.d /var/log/nginx /run/nginx /var/lib/nginx && \
    chown -R www-data:www-data /var/log/nginx /run/nginx /etc/nginx /var/lib/nginx

# Debian nginx uses www-data by default, but let's ensure it
# Remove default site that conflicts with our configuration
# Comment out user directive since we run as non-root (www-data can't switch users)
# Move PID file to /run/nginx/ which we own (Debian default is /run/nginx.pid in root-owned /run/)
RUN sed -i 's/user nginx;/user www-data;/' /etc/nginx/nginx.conf 2>/dev/null || true && \
    sed -i 's/^user www-data;/# user www-data;/' /etc/nginx/nginx.conf && \
    sed -i 's|pid /run/nginx.pid;|pid /run/nginx/nginx.pid;|' /etc/nginx/nginx.conf && \
    rm -f /etc/nginx/sites-enabled/default

# Copy Nginx configuration (rootless version with port 8080)
# Use --chown to set ownership atomically (avoids cache layer issues)
COPY --chown=www-data:www-data php-fpm-nginx/common/default-rootless.conf /etc/nginx/conf.d/default.conf
COPY --chown=www-data:www-data php-fpm-nginx/common/default.conf.template /etc/nginx/conf.d/default.conf.template

# Copy Cbox PM configuration (rootless version with port 8080 health check)
RUN mkdir -p /etc/cbox-init && chown -R www-data:www-data /etc/cbox-init
COPY php-fpm-nginx/common/cbox-init-rootless.yaml /etc/cbox-init/cbox-init.yaml

# Copy entrypoint and healthcheck (overrides php-fpm versions)
COPY php-fpm-nginx/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-fpm-nginx/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

# Create public directory with www-data ownership
RUN mkdir -p /var/www/html/public /var/www/.composer /var/www/.npm /tmp/cbox && \
    chown -R www-data:www-data /var/www /tmp/cbox

# Health check (checks both nginx and php-fpm)
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

USER www-data
WORKDIR /var/www/html

# Expose unprivileged HTTP port (ports < 1024 require root)
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["cbox-init"]

# ═══════════════════════════════════════════════════════════════════════════
# ROOT (STANDARD): Default - PHP-FPM + Nginx with ImageMagick, vips, Node.js
# ═══════════════════════════════════════════════════════════════════════════
FROM base-standard AS root

LABEL org.opencontainers.image.title="Cbox PHP-FPM + Nginx 8.3 Bookworm"
LABEL org.opencontainers.image.description="PHP-FPM + Nginx with all extensions, Composer, Node.js, and Cbox PM"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/baseimages"

ENV CBOX_IMAGE_TIER=standard

# Install Nginx
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Create nginx directories
RUN mkdir -p /etc/nginx/conf.d /var/log/nginx /run/nginx && \
    chown -R www-data:www-data /var/log/nginx /run/nginx

# Debian nginx uses www-data by default, but let's ensure it
# Also remove the default site that conflicts with our configuration
RUN sed -i 's/user nginx;/user www-data;/' /etc/nginx/nginx.conf 2>/dev/null || true && \
    rm -f /etc/nginx/sites-enabled/default

# Copy Nginx configuration
COPY php-fpm-nginx/common/default.conf /etc/nginx/conf.d/default.conf
COPY php-fpm-nginx/common/default.conf.template /etc/nginx/conf.d/default.conf.template

# Copy Cbox PM configuration
RUN mkdir -p /etc/cbox-init
COPY php-fpm-nginx/common/cbox-init.yaml /etc/cbox-init/cbox-init.yaml

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
CMD ["cbox-init"]

# ═══════════════════════════════════════════════════════════════════════════
# ROOTLESS (STANDARD): Default rootless - PHP-FPM + Nginx
# ═══════════════════════════════════════════════════════════════════════════
FROM base-standard-rootless AS rootless

LABEL org.opencontainers.image.title="Cbox PHP-FPM + Nginx 8.3 Bookworm (Rootless)"
LABEL org.opencontainers.image.description="PHP-FPM + Nginx with all extensions, Composer, Node.js, and Cbox PM - Rootless"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/baseimages"

ENV CBOX_IMAGE_TIER=standard

# Switch to root temporarily for setup
USER root

# Install Nginx
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Create nginx directories with www-data ownership
# Note: Debian nginx uses /var/lib/nginx for tmp dirs (body, proxy, fastcgi, etc.)
RUN mkdir -p /etc/nginx/conf.d /var/log/nginx /run/nginx /var/lib/nginx && \
    chown -R www-data:www-data /var/log/nginx /run/nginx /etc/nginx /var/lib/nginx

# Debian nginx uses www-data by default, but let's ensure it
# Remove default site that conflicts with our configuration
# Comment out user directive since we run as non-root (www-data can't switch users)
# Move PID file to /run/nginx/ which we own (Debian default is /run/nginx.pid in root-owned /run/)
RUN sed -i 's/user nginx;/user www-data;/' /etc/nginx/nginx.conf 2>/dev/null || true && \
    sed -i 's/^user www-data;/# user www-data;/' /etc/nginx/nginx.conf && \
    sed -i 's|pid /run/nginx.pid;|pid /run/nginx/nginx.pid;|' /etc/nginx/nginx.conf && \
    rm -f /etc/nginx/sites-enabled/default

# Copy Nginx configuration (rootless version with port 8080)
# Use --chown to set ownership atomically (avoids cache layer issues)
COPY --chown=www-data:www-data php-fpm-nginx/common/default-rootless.conf /etc/nginx/conf.d/default.conf
COPY --chown=www-data:www-data php-fpm-nginx/common/default.conf.template /etc/nginx/conf.d/default.conf.template

# Copy Cbox PM configuration (rootless version with port 8080 health check)
RUN mkdir -p /etc/cbox-init && chown -R www-data:www-data /etc/cbox-init
COPY php-fpm-nginx/common/cbox-init-rootless.yaml /etc/cbox-init/cbox-init.yaml

# Copy entrypoint and healthcheck (overrides php-fpm versions)
COPY php-fpm-nginx/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-fpm-nginx/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

# Create public directory with www-data ownership
RUN mkdir -p /var/www/html/public /var/www/.composer /var/www/.npm /tmp/cbox && \
    chown -R www-data:www-data /var/www /tmp/cbox

# Health check (checks both nginx and php-fpm)
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

USER www-data
WORKDIR /var/www/html

# Expose unprivileged HTTP port (ports < 1024 require root)
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["cbox-init"]

# ═══════════════════════════════════════════════════════════════════════════
# FULL-ROOT: Everything including Chromium for Browsershot/Dusk
# ═══════════════════════════════════════════════════════════════════════════
FROM base-full AS full-root

LABEL org.opencontainers.image.title="Cbox PHP-FPM + Nginx 8.3 Bookworm (Full)"
LABEL org.opencontainers.image.description="PHP-FPM + Nginx with all features including Chromium for Browsershot/Dusk"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/baseimages"

ENV CBOX_IMAGE_TIER=full

# Install Nginx
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Create nginx directories
RUN mkdir -p /etc/nginx/conf.d /var/log/nginx /run/nginx && \
    chown -R www-data:www-data /var/log/nginx /run/nginx

# Debian nginx uses www-data by default, but let's ensure it
# Also remove the default site that conflicts with our configuration
RUN sed -i 's/user nginx;/user www-data;/' /etc/nginx/nginx.conf 2>/dev/null || true && \
    rm -f /etc/nginx/sites-enabled/default

# Copy Nginx configuration
COPY php-fpm-nginx/common/default.conf /etc/nginx/conf.d/default.conf
COPY php-fpm-nginx/common/default.conf.template /etc/nginx/conf.d/default.conf.template

# Copy Cbox PM configuration
RUN mkdir -p /etc/cbox-init
COPY php-fpm-nginx/common/cbox-init.yaml /etc/cbox-init/cbox-init.yaml

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
CMD ["cbox-init"]

# ═══════════════════════════════════════════════════════════════════════════
# FULL-ROOTLESS: Everything including Chromium, running as www-data
# ═══════════════════════════════════════════════════════════════════════════
FROM base-full-rootless AS full-rootless

LABEL org.opencontainers.image.title="Cbox PHP-FPM + Nginx 8.3 Bookworm (Full Rootless)"
LABEL org.opencontainers.image.description="PHP-FPM + Nginx with all features including Chromium - Rootless"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/baseimages"

ENV CBOX_IMAGE_TIER=full

# Switch to root temporarily for setup
USER root

# Install Nginx
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Create nginx directories with www-data ownership
# Note: Debian nginx uses /var/lib/nginx for tmp dirs (body, proxy, fastcgi, etc.)
RUN mkdir -p /etc/nginx/conf.d /var/log/nginx /run/nginx /var/lib/nginx && \
    chown -R www-data:www-data /var/log/nginx /run/nginx /etc/nginx /var/lib/nginx

# Debian nginx uses www-data by default, but let's ensure it
# Remove default site that conflicts with our configuration
# Comment out user directive since we run as non-root (www-data can't switch users)
# Move PID file to /run/nginx/ which we own (Debian default is /run/nginx.pid in root-owned /run/)
RUN sed -i 's/user nginx;/user www-data;/' /etc/nginx/nginx.conf 2>/dev/null || true && \
    sed -i 's/^user www-data;/# user www-data;/' /etc/nginx/nginx.conf && \
    sed -i 's|pid /run/nginx.pid;|pid /run/nginx/nginx.pid;|' /etc/nginx/nginx.conf && \
    rm -f /etc/nginx/sites-enabled/default

# Copy Nginx configuration (rootless version with port 8080)
# Use --chown to set ownership atomically (avoids cache layer issues)
COPY --chown=www-data:www-data php-fpm-nginx/common/default-rootless.conf /etc/nginx/conf.d/default.conf
COPY --chown=www-data:www-data php-fpm-nginx/common/default.conf.template /etc/nginx/conf.d/default.conf.template

# Copy Cbox PM configuration (rootless version with port 8080 health check)
RUN mkdir -p /etc/cbox-init && chown -R www-data:www-data /etc/cbox-init
COPY php-fpm-nginx/common/cbox-init-rootless.yaml /etc/cbox-init/cbox-init.yaml

# Copy entrypoint and healthcheck (overrides php-fpm versions)
COPY php-fpm-nginx/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-fpm-nginx/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

# Create public directory with www-data ownership
RUN mkdir -p /var/www/html/public /var/www/.composer /var/www/.npm /tmp/cbox && \
    chown -R www-data:www-data /var/www /tmp/cbox

# Health check (checks both nginx and php-fpm)
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

USER www-data
WORKDIR /var/www/html

# Expose unprivileged HTTP port (ports < 1024 require root)
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["cbox-init"]
