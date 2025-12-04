# ============================================================================
# PHPeek PHP-FPM + Nginx Image - Alpine 8.3
# ============================================================================
# LAYER 4: Extends php-fpm with Nginx for single-container deployment
#          Uses PHPeek PM as process manager
#
# IMAGE TIERS (inherited from php-fpm):
# - slim:     Minimal PHP + essential extensions - API/microservices
# - standard: + ImageMagick, vips, Node.js - Most Laravel apps (DEFAULT)
# - full:     + Chromium for Browsershot/Dusk - PDF generation, testing
# ============================================================================

# ═══════════════════════════════════════════════════════════════════════════
# SLIM-ROOT: Minimal PHP-FPM + Nginx
# ═══════════════════════════════════════════════════════════════════════════
FROM ghcr.io/gophpeek/baseimages/php-fpm:8.3-alpine-slim AS slim-root

LABEL org.opencontainers.image.title="PHPeek PHP-FPM + Nginx 8.3 Alpine (Slim)"
LABEL org.opencontainers.image.description="Minimal PHP-FPM + Nginx with essential extensions"
LABEL org.opencontainers.image.vendor="PHPeek"
LABEL org.opencontainers.image.source="https://github.com/gophpeek/baseimages"

# Install Nginx
RUN apk add --no-cache nginx gettext

# Create nginx directories
RUN mkdir -p /etc/nginx/conf.d /var/log/nginx /run/nginx && \
    chown -R www-data:www-data /var/log/nginx /run/nginx

# Fix nginx user for Alpine and conf.d include
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

# Copy entrypoint and healthcheck
COPY php-fpm-nginx/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-fpm-nginx/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

# Create public directory
RUN mkdir -p /var/www/html/public && \
    chown -R www-data:www-data /var/www/html

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

WORKDIR /var/www/html
EXPOSE 80 443
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["phpeek-pm"]

# ═══════════════════════════════════════════════════════════════════════════
# SLIM-ROOTLESS: Minimal PHP-FPM + Nginx running as www-data
# ═══════════════════════════════════════════════════════════════════════════
FROM ghcr.io/gophpeek/baseimages/php-fpm:8.3-alpine-slim-rootless AS slim-rootless

LABEL org.opencontainers.image.title="PHPeek PHP-FPM + Nginx 8.3 Alpine (Slim Rootless)"
LABEL org.opencontainers.image.description="Minimal PHP-FPM + Nginx with essential extensions - Rootless"
LABEL org.opencontainers.image.vendor="PHPeek"
LABEL org.opencontainers.image.source="https://github.com/gophpeek/baseimages"

USER root

RUN apk add --no-cache nginx gettext

RUN mkdir -p /etc/nginx/conf.d /var/log/nginx /run/nginx /var/lib/nginx/tmp && \
    chown -R www-data:www-data /var/log/nginx /run/nginx /etc/nginx /var/lib/nginx

RUN sed -i 's/user nginx;/user www-data;/' /etc/nginx/nginx.conf 2>/dev/null || true && \
    sed -i 's/^user www-data;/# user www-data;/' /etc/nginx/nginx.conf && \
    sed -i 's|pid /run/nginx.pid;|pid /run/nginx/nginx.pid;|' /etc/nginx/nginx.conf && \
    sed -i '/^include \/etc\/nginx\/conf\.d\/\*\.conf;/d' /etc/nginx/nginx.conf && \
    sed -i '/include \/etc\/nginx\/http\.d\/\*\.conf;/i\    include /etc/nginx/conf.d/*.conf;' /etc/nginx/nginx.conf && \
    rm -f /etc/nginx/http.d/default.conf

COPY --chown=www-data:www-data php-fpm-nginx/common/default-rootless.conf /etc/nginx/conf.d/default.conf
COPY --chown=www-data:www-data php-fpm-nginx/common/default.conf.template /etc/nginx/conf.d/default.conf.template

RUN mkdir -p /etc/phpeek-pm && chown -R www-data:www-data /etc/phpeek-pm
COPY php-fpm-nginx/common/phpeek-pm-rootless.yaml /etc/phpeek-pm/phpeek-pm.yaml

COPY php-fpm-nginx/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-fpm-nginx/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

RUN mkdir -p /var/www/html/public /var/www/.composer /tmp/phpeek && \
    chown -R www-data:www-data /var/www /tmp/phpeek

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

USER www-data
WORKDIR /var/www/html
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["phpeek-pm"]

# ═══════════════════════════════════════════════════════════════════════════
# ROOT (STANDARD): Default - ImageMagick, vips, Node.js
# ═══════════════════════════════════════════════════════════════════════════
FROM ghcr.io/gophpeek/baseimages/php-fpm:8.3-alpine AS root

LABEL org.opencontainers.image.title="PHPeek PHP-FPM + Nginx 8.3 Alpine"
LABEL org.opencontainers.image.description="PHP-FPM + Nginx with ImageMagick, vips, Node.js, Composer, and PHPeek PM"
LABEL org.opencontainers.image.vendor="PHPeek"
LABEL org.opencontainers.image.source="https://github.com/gophpeek/baseimages"

RUN apk add --no-cache nginx gettext

RUN mkdir -p /etc/nginx/conf.d /var/log/nginx /run/nginx && \
    chown -R www-data:www-data /var/log/nginx /run/nginx

RUN sed -i 's/user nginx;/user www-data;/' /etc/nginx/nginx.conf 2>/dev/null || true && \
    sed -i '/^include \/etc\/nginx\/conf\.d\/\*\.conf;/d' /etc/nginx/nginx.conf && \
    sed -i '/include \/etc\/nginx\/http\.d\/\*\.conf;/i\    include /etc/nginx/conf.d/*.conf;' /etc/nginx/nginx.conf && \
    rm -f /etc/nginx/http.d/default.conf

COPY php-fpm-nginx/common/default.conf /etc/nginx/conf.d/default.conf
COPY php-fpm-nginx/common/default.conf.template /etc/nginx/conf.d/default.conf.template

RUN mkdir -p /etc/phpeek-pm
COPY php-fpm-nginx/common/phpeek-pm.yaml /etc/phpeek-pm/phpeek-pm.yaml

COPY php-fpm-nginx/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-fpm-nginx/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

RUN mkdir -p /var/www/html/public && \
    chown -R www-data:www-data /var/www/html

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

WORKDIR /var/www/html
EXPOSE 80 443
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["phpeek-pm"]

# ═══════════════════════════════════════════════════════════════════════════
# ROOTLESS (STANDARD): Default rootless - ImageMagick, vips, Node.js
# ═══════════════════════════════════════════════════════════════════════════
FROM ghcr.io/gophpeek/baseimages/php-fpm:8.3-alpine-rootless AS rootless

LABEL org.opencontainers.image.title="PHPeek PHP-FPM + Nginx 8.3 Alpine (Rootless)"
LABEL org.opencontainers.image.description="PHP-FPM + Nginx with ImageMagick, vips, Node.js - Rootless"
LABEL org.opencontainers.image.vendor="PHPeek"
LABEL org.opencontainers.image.source="https://github.com/gophpeek/baseimages"

USER root

RUN apk add --no-cache nginx gettext

RUN mkdir -p /etc/nginx/conf.d /var/log/nginx /run/nginx /var/lib/nginx/tmp && \
    chown -R www-data:www-data /var/log/nginx /run/nginx /etc/nginx /var/lib/nginx

RUN sed -i 's/user nginx;/user www-data;/' /etc/nginx/nginx.conf 2>/dev/null || true && \
    sed -i 's/^user www-data;/# user www-data;/' /etc/nginx/nginx.conf && \
    sed -i 's|pid /run/nginx.pid;|pid /run/nginx/nginx.pid;|' /etc/nginx/nginx.conf && \
    sed -i '/^include \/etc\/nginx\/conf\.d\/\*\.conf;/d' /etc/nginx/nginx.conf && \
    sed -i '/include \/etc\/nginx\/http\.d\/\*\.conf;/i\    include /etc/nginx/conf.d/*.conf;' /etc/nginx/nginx.conf && \
    rm -f /etc/nginx/http.d/default.conf

COPY --chown=www-data:www-data php-fpm-nginx/common/default-rootless.conf /etc/nginx/conf.d/default.conf
COPY --chown=www-data:www-data php-fpm-nginx/common/default.conf.template /etc/nginx/conf.d/default.conf.template

RUN mkdir -p /etc/phpeek-pm && chown -R www-data:www-data /etc/phpeek-pm
COPY php-fpm-nginx/common/phpeek-pm-rootless.yaml /etc/phpeek-pm/phpeek-pm.yaml

COPY php-fpm-nginx/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-fpm-nginx/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

RUN mkdir -p /var/www/html/public /var/www/.composer /var/www/.npm /tmp/phpeek && \
    chown -R www-data:www-data /var/www /tmp/phpeek

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

USER www-data
WORKDIR /var/www/html
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["phpeek-pm"]

# ═══════════════════════════════════════════════════════════════════════════
# FULL-ROOT: Everything including Chromium
# ═══════════════════════════════════════════════════════════════════════════
FROM ghcr.io/gophpeek/baseimages/php-fpm:8.3-alpine-full AS full-root

LABEL org.opencontainers.image.title="PHPeek PHP-FPM + Nginx 8.3 Alpine (Full)"
LABEL org.opencontainers.image.description="PHP-FPM + Nginx with all features including Chromium for Browsershot/Dusk"
LABEL org.opencontainers.image.vendor="PHPeek"
LABEL org.opencontainers.image.source="https://github.com/gophpeek/baseimages"

RUN apk add --no-cache nginx gettext

RUN mkdir -p /etc/nginx/conf.d /var/log/nginx /run/nginx && \
    chown -R www-data:www-data /var/log/nginx /run/nginx

RUN sed -i 's/user nginx;/user www-data;/' /etc/nginx/nginx.conf 2>/dev/null || true && \
    sed -i '/^include \/etc\/nginx\/conf\.d\/\*\.conf;/d' /etc/nginx/nginx.conf && \
    sed -i '/include \/etc\/nginx\/http\.d\/\*\.conf;/i\    include /etc/nginx/conf.d/*.conf;' /etc/nginx/nginx.conf && \
    rm -f /etc/nginx/http.d/default.conf

COPY php-fpm-nginx/common/default.conf /etc/nginx/conf.d/default.conf
COPY php-fpm-nginx/common/default.conf.template /etc/nginx/conf.d/default.conf.template

RUN mkdir -p /etc/phpeek-pm
COPY php-fpm-nginx/common/phpeek-pm.yaml /etc/phpeek-pm/phpeek-pm.yaml

COPY php-fpm-nginx/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-fpm-nginx/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

RUN mkdir -p /var/www/html/public && \
    chown -R www-data:www-data /var/www/html

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

WORKDIR /var/www/html
EXPOSE 80 443
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["phpeek-pm"]

# ═══════════════════════════════════════════════════════════════════════════
# FULL-ROOTLESS: Everything including Chromium, running as www-data
# ═══════════════════════════════════════════════════════════════════════════
FROM ghcr.io/gophpeek/baseimages/php-fpm:8.3-alpine-full-rootless AS full-rootless

LABEL org.opencontainers.image.title="PHPeek PHP-FPM + Nginx 8.3 Alpine (Full Rootless)"
LABEL org.opencontainers.image.description="PHP-FPM + Nginx with all features including Chromium - Rootless"
LABEL org.opencontainers.image.vendor="PHPeek"
LABEL org.opencontainers.image.source="https://github.com/gophpeek/baseimages"

USER root

RUN apk add --no-cache nginx gettext

RUN mkdir -p /etc/nginx/conf.d /var/log/nginx /run/nginx /var/lib/nginx/tmp && \
    chown -R www-data:www-data /var/log/nginx /run/nginx /etc/nginx /var/lib/nginx

RUN sed -i 's/user nginx;/user www-data;/' /etc/nginx/nginx.conf 2>/dev/null || true && \
    sed -i 's/^user www-data;/# user www-data;/' /etc/nginx/nginx.conf && \
    sed -i 's|pid /run/nginx.pid;|pid /run/nginx/nginx.pid;|' /etc/nginx/nginx.conf && \
    sed -i '/^include \/etc\/nginx\/conf\.d\/\*\.conf;/d' /etc/nginx/nginx.conf && \
    sed -i '/include \/etc\/nginx\/http\.d\/\*\.conf;/i\    include /etc/nginx/conf.d/*.conf;' /etc/nginx/nginx.conf && \
    rm -f /etc/nginx/http.d/default.conf

COPY --chown=www-data:www-data php-fpm-nginx/common/default-rootless.conf /etc/nginx/conf.d/default.conf
COPY --chown=www-data:www-data php-fpm-nginx/common/default.conf.template /etc/nginx/conf.d/default.conf.template

RUN mkdir -p /etc/phpeek-pm && chown -R www-data:www-data /etc/phpeek-pm
COPY php-fpm-nginx/common/phpeek-pm-rootless.yaml /etc/phpeek-pm/phpeek-pm.yaml

COPY php-fpm-nginx/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-fpm-nginx/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

RUN mkdir -p /var/www/html/public /var/www/.composer /var/www/.npm /tmp/phpeek && \
    chown -R www-data:www-data /var/www /tmp/phpeek

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

USER www-data
WORKDIR /var/www/html
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["phpeek-pm"]
