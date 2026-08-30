# ============================================================================
# Cbox PHP-FPM + Nginx Image - Debian (Bookworm)
# ============================================================================
# LAYER 4: Extends php-fpm with Nginx for single-container deployment
#          Uses Cbox Init as process manager
#
# IMAGE TIERS (inherited from php-fpm):
# - slim:     Minimal PHP + essential extensions - API/microservices
# - standard: + ImageMagick, vips, Node.js - Most Laravel apps (DEFAULT)
# - chromium: + Chromium for Browsershot/Dusk - PDF generation, testing
#
# PARAMETERIZED: Build with --build-arg PHP_VERSION=8.2|8.3|8.4|8.5
# ============================================================================

ARG PHP_VERSION=8.4

# ============================================================================
# Import base images for each tier from php-fpm
# ============================================================================
FROM ghcr.io/cboxdk/php-baseimages/php-fpm:${PHP_VERSION}-bookworm-slim AS base-slim
FROM ghcr.io/cboxdk/php-baseimages/php-fpm:${PHP_VERSION}-bookworm-slim-rootless AS base-slim-rootless
FROM ghcr.io/cboxdk/php-baseimages/php-fpm:${PHP_VERSION}-bookworm AS base-standard
FROM ghcr.io/cboxdk/php-baseimages/php-fpm:${PHP_VERSION}-bookworm-rootless AS base-standard-rootless
FROM ghcr.io/cboxdk/php-baseimages/php-fpm:${PHP_VERSION}-bookworm-chromium AS base-chromium
FROM ghcr.io/cboxdk/php-baseimages/php-fpm:${PHP_VERSION}-bookworm-chromium-rootless AS base-chromium-rootless
FROM ghcr.io/cboxdk/php-baseimages/php-fpm:${PHP_VERSION}-bookworm-dev AS base-dev
FROM ghcr.io/cboxdk/php-baseimages/php-fpm:${PHP_VERSION}-bookworm-dev-rootless AS base-dev-rootless

# ═══════════════════════════════════════════════════════════════════════════
# BROTLI-BUILDER: ngx_brotli dynamic modules for Debian's nginx
#
# Bookworm does not package ngx_brotli, so compile it against the exact nginx
# version apt installs. --with-compat makes the modules ABI-compatible with
# Debian's differently-configured binary; brotli itself is statically linked,
# so the tiers need no extra runtime library. Debian stable keeps one nginx
# version (1.22.1) for its whole lifetime, so weekly rebuilds stay stable.
# ═══════════════════════════════════════════════════════════════════════════
FROM debian:bookworm-slim AS brotli-builder

# Keep in sync with tools.ngx_brotli in versions.json
ARG NGX_BROTLI_COMMIT=a71f9312c2deb28875acc7bacfdd5695a111aa53

RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx ca-certificates curl git build-essential cmake libpcre2-dev zlib1g-dev \
    && rm -rf /var/lib/apt/lists/* \
    && NGINX_VERSION=$(nginx -v 2>&1 | sed 's|.*nginx/||') \
    && curl -fsSL "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" | tar -xz -C /usr/src \
    && git clone https://github.com/google/ngx_brotli.git /usr/src/ngx_brotli \
    && git -C /usr/src/ngx_brotli checkout "${NGX_BROTLI_COMMIT}" \
    && git -C /usr/src/ngx_brotli submodule update --init --depth 1 \
    && cmake -S /usr/src/ngx_brotli/deps/brotli -B /usr/src/ngx_brotli/deps/brotli/out \
        -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_FLAGS="-fPIC -O2" \
    && cmake --build /usr/src/ngx_brotli/deps/brotli/out --config Release --target brotlienc -- -j"$(nproc)" \
    && cd "/usr/src/nginx-${NGINX_VERSION}" \
    && ./configure --with-compat --add-dynamic-module=/usr/src/ngx_brotli \
    && make -j"$(nproc)" modules \
    && mkdir -p /out \
    && cp objs/ngx_http_brotli_filter_module.so objs/ngx_http_brotli_static_module.so /out/

# ═══════════════════════════════════════════════════════════════════════════
# SLIM-ROOT: Minimal PHP-FPM + Nginx
# ═══════════════════════════════════════════════════════════════════════════
FROM base-slim AS slim-root

ARG PHP_VERSION

LABEL org.opencontainers.image.title="Cbox PHP-FPM + Nginx ${PHP_VERSION} Bookworm (Slim)"
LABEL org.opencontainers.image.description="Minimal PHP-FPM + Nginx with essential extensions"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/php-baseimages"

ENV CBOX_IMAGE_TIER=slim

# Install Nginx
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx libnginx-mod-http-headers-more-filter gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Brotli modules (built in brotli-builder against this exact nginx version)
COPY --from=brotli-builder /out/ /usr/lib/nginx/modules/
RUN printf 'load_module modules/ngx_http_brotli_filter_module.so;\nload_module modules/ngx_http_brotli_static_module.so;\n' \
    > /etc/nginx/modules-enabled/50-mod-http-brotli.conf

# Create nginx directories + forward access/error logs to docker log
# collector (stdout/stderr) so kubectl logs / docker logs sees them.
RUN mkdir -p /etc/nginx/conf.d /var/log/nginx /run/nginx && \
    chown -R www-data:www-data /var/log/nginx /run/nginx && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

# Debian nginx uses www-data by default, but let's ensure it
# Also remove the default site that conflicts with our configuration
RUN sed -i 's/user nginx;/user www-data;/' /etc/nginx/nginx.conf 2>/dev/null || true && \
    rm -f /etc/nginx/sites-enabled/default

# Copy Nginx configuration
COPY php-fpm-nginx/common/default.conf /etc/nginx/conf.d/default.conf
COPY php-fpm-nginx/common/default.conf.template /etc/nginx/conf.d/default.conf.template

# Copy Cbox Init configuration
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
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
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

ARG PHP_VERSION

LABEL org.opencontainers.image.title="Cbox PHP-FPM + Nginx ${PHP_VERSION} Bookworm (Slim Rootless)"
LABEL org.opencontainers.image.description="Minimal PHP-FPM + Nginx with essential extensions - Rootless"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/php-baseimages"

ENV CBOX_IMAGE_TIER=slim

# Switch to root temporarily for setup
USER root

# Install Nginx
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx libnginx-mod-http-headers-more-filter gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Brotli modules (built in brotli-builder against this exact nginx version)
COPY --from=brotli-builder /out/ /usr/lib/nginx/modules/
RUN printf 'load_module modules/ngx_http_brotli_filter_module.so;\nload_module modules/ngx_http_brotli_static_module.so;\n' \
    > /etc/nginx/modules-enabled/50-mod-http-brotli.conf

# Create nginx directories with www-data ownership + forward access/error
# logs to docker log collector (stdout/stderr) so kubectl logs / docker
# logs sees them.
# Note: Debian nginx uses /var/lib/nginx for tmp dirs (body, proxy, fastcgi, etc.)
RUN mkdir -p /etc/nginx/conf.d /var/log/nginx /run/nginx /var/lib/nginx && \
    chown -R www-data:www-data /var/log/nginx /run/nginx /etc/nginx /var/lib/nginx && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

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

# Copy Cbox Init configuration (rootless version with port 8080 health check)
RUN mkdir -p /etc/cbox-init && chown -R www-data:www-data /etc/cbox-init
COPY php-fpm-nginx/common/cbox-init-rootless.yaml /etc/cbox-init/cbox-init.yaml

# Copy entrypoint and healthcheck (overrides php-fpm versions)
COPY php-fpm-nginx/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-fpm-nginx/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

# Create public directory with www-data ownership
RUN mkdir -p /var/www/html/public /var/www/.composer /var/www/.npm /tmp/cbox && \
    chown -R www-data:www-data /var/www /tmp/cbox /usr/local/etc/php/conf.d /usr/local/etc/php-fpm.d

# Health check (checks both nginx and php-fpm)
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
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

ARG PHP_VERSION

LABEL org.opencontainers.image.title="Cbox PHP-FPM + Nginx ${PHP_VERSION} Bookworm"
LABEL org.opencontainers.image.description="PHP-FPM + Nginx with all extensions, Composer, Node.js, and Cbox Init"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/php-baseimages"

ENV CBOX_IMAGE_TIER=standard

# Install Nginx
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx libnginx-mod-http-headers-more-filter gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Brotli modules (built in brotli-builder against this exact nginx version)
COPY --from=brotli-builder /out/ /usr/lib/nginx/modules/
RUN printf 'load_module modules/ngx_http_brotli_filter_module.so;\nload_module modules/ngx_http_brotli_static_module.so;\n' \
    > /etc/nginx/modules-enabled/50-mod-http-brotli.conf

# Create nginx directories + forward access/error logs to docker log
# collector (stdout/stderr) so kubectl logs / docker logs sees them.
RUN mkdir -p /etc/nginx/conf.d /var/log/nginx /run/nginx && \
    chown -R www-data:www-data /var/log/nginx /run/nginx && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

# Debian nginx uses www-data by default, but let's ensure it
# Also remove the default site that conflicts with our configuration
RUN sed -i 's/user nginx;/user www-data;/' /etc/nginx/nginx.conf 2>/dev/null || true && \
    rm -f /etc/nginx/sites-enabled/default

# Copy Nginx configuration
COPY php-fpm-nginx/common/default.conf /etc/nginx/conf.d/default.conf
COPY php-fpm-nginx/common/default.conf.template /etc/nginx/conf.d/default.conf.template

# Copy Cbox Init configuration
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
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
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

ARG PHP_VERSION

LABEL org.opencontainers.image.title="Cbox PHP-FPM + Nginx ${PHP_VERSION} Bookworm (Rootless)"
LABEL org.opencontainers.image.description="PHP-FPM + Nginx with all extensions, Composer, Node.js, and Cbox Init - Rootless"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/php-baseimages"

ENV CBOX_IMAGE_TIER=standard

# Switch to root temporarily for setup
USER root

# Install Nginx
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx libnginx-mod-http-headers-more-filter gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Brotli modules (built in brotli-builder against this exact nginx version)
COPY --from=brotli-builder /out/ /usr/lib/nginx/modules/
RUN printf 'load_module modules/ngx_http_brotli_filter_module.so;\nload_module modules/ngx_http_brotli_static_module.so;\n' \
    > /etc/nginx/modules-enabled/50-mod-http-brotli.conf

# Create nginx directories with www-data ownership + forward access/error
# logs to docker log collector (stdout/stderr) so kubectl logs / docker
# logs sees them.
# Note: Debian nginx uses /var/lib/nginx for tmp dirs (body, proxy, fastcgi, etc.)
RUN mkdir -p /etc/nginx/conf.d /var/log/nginx /run/nginx /var/lib/nginx && \
    chown -R www-data:www-data /var/log/nginx /run/nginx /etc/nginx /var/lib/nginx && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

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

# Copy Cbox Init configuration (rootless version with port 8080 health check)
RUN mkdir -p /etc/cbox-init && chown -R www-data:www-data /etc/cbox-init
COPY php-fpm-nginx/common/cbox-init-rootless.yaml /etc/cbox-init/cbox-init.yaml

# Copy entrypoint and healthcheck (overrides php-fpm versions)
COPY php-fpm-nginx/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-fpm-nginx/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

# Create public directory with www-data ownership
RUN mkdir -p /var/www/html/public /var/www/.composer /var/www/.npm /tmp/cbox && \
    chown -R www-data:www-data /var/www /tmp/cbox /usr/local/etc/php/conf.d /usr/local/etc/php-fpm.d

# Health check (checks both nginx and php-fpm)
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

USER www-data
WORKDIR /var/www/html

# Expose unprivileged HTTP port (ports < 1024 require root)
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["cbox-init"]

# ═══════════════════════════════════════════════════════════════════════════
# CHROMIUM-ROOT: Everything including Chromium for Browsershot/Dusk
# ═══════════════════════════════════════════════════════════════════════════
FROM base-chromium AS chromium-root

ARG PHP_VERSION

LABEL org.opencontainers.image.title="Cbox PHP-FPM + Nginx ${PHP_VERSION} Bookworm (Chromium)"
LABEL org.opencontainers.image.description="PHP-FPM + Nginx with all features including Chromium for Browsershot/Dusk"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/php-baseimages"

ENV CBOX_IMAGE_TIER=chromium

# Install Nginx
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx libnginx-mod-http-headers-more-filter gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Brotli modules (built in brotli-builder against this exact nginx version)
COPY --from=brotli-builder /out/ /usr/lib/nginx/modules/
RUN printf 'load_module modules/ngx_http_brotli_filter_module.so;\nload_module modules/ngx_http_brotli_static_module.so;\n' \
    > /etc/nginx/modules-enabled/50-mod-http-brotli.conf

# Create nginx directories + forward access/error logs to docker log
# collector (stdout/stderr) so kubectl logs / docker logs sees them.
RUN mkdir -p /etc/nginx/conf.d /var/log/nginx /run/nginx && \
    chown -R www-data:www-data /var/log/nginx /run/nginx && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

# Debian nginx uses www-data by default, but let's ensure it
# Also remove the default site that conflicts with our configuration
RUN sed -i 's/user nginx;/user www-data;/' /etc/nginx/nginx.conf 2>/dev/null || true && \
    rm -f /etc/nginx/sites-enabled/default

# Copy Nginx configuration
COPY php-fpm-nginx/common/default.conf /etc/nginx/conf.d/default.conf
COPY php-fpm-nginx/common/default.conf.template /etc/nginx/conf.d/default.conf.template

# Copy Cbox Init configuration
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
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

WORKDIR /var/www/html

# Expose both HTTP and HTTPS
EXPOSE 80 443

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["cbox-init"]

# ═══════════════════════════════════════════════════════════════════════════
# CHROMIUM-ROOTLESS: Everything including Chromium, running as www-data
# ═══════════════════════════════════════════════════════════════════════════
FROM base-chromium-rootless AS chromium-rootless

ARG PHP_VERSION

LABEL org.opencontainers.image.title="Cbox PHP-FPM + Nginx ${PHP_VERSION} Bookworm (Chromium Rootless)"
LABEL org.opencontainers.image.description="PHP-FPM + Nginx with all features including Chromium - Rootless"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/php-baseimages"

ENV CBOX_IMAGE_TIER=chromium

# Switch to root temporarily for setup
USER root

# Install Nginx
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx libnginx-mod-http-headers-more-filter gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Brotli modules (built in brotli-builder against this exact nginx version)
COPY --from=brotli-builder /out/ /usr/lib/nginx/modules/
RUN printf 'load_module modules/ngx_http_brotli_filter_module.so;\nload_module modules/ngx_http_brotli_static_module.so;\n' \
    > /etc/nginx/modules-enabled/50-mod-http-brotli.conf

# Create nginx directories with www-data ownership + forward access/error
# logs to docker log collector (stdout/stderr) so kubectl logs / docker
# logs sees them.
# Note: Debian nginx uses /var/lib/nginx for tmp dirs (body, proxy, fastcgi, etc.)
RUN mkdir -p /etc/nginx/conf.d /var/log/nginx /run/nginx /var/lib/nginx && \
    chown -R www-data:www-data /var/log/nginx /run/nginx /etc/nginx /var/lib/nginx && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

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

# Copy Cbox Init configuration (rootless version with port 8080 health check)
RUN mkdir -p /etc/cbox-init && chown -R www-data:www-data /etc/cbox-init
COPY php-fpm-nginx/common/cbox-init-rootless.yaml /etc/cbox-init/cbox-init.yaml

# Copy entrypoint and healthcheck (overrides php-fpm versions)
COPY php-fpm-nginx/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-fpm-nginx/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

# Create public directory with www-data ownership
RUN mkdir -p /var/www/html/public /var/www/.composer /var/www/.npm /tmp/cbox && \
    chown -R www-data:www-data /var/www /tmp/cbox /usr/local/etc/php/conf.d /usr/local/etc/php-fpm.d

# Health check (checks both nginx and php-fpm)
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

USER www-data
WORKDIR /var/www/html

# Expose unprivileged HTTP port (ports < 1024 require root)
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["cbox-init"]

# ═══════════════════════════════════════════════════════════════════════════
# DEV-ROOT: Chromium + Xdebug, PCOV, SPX for development/testing
# ═══════════════════════════════════════════════════════════════════════════
FROM base-dev AS dev-root

ARG PHP_VERSION

LABEL org.opencontainers.image.title="Cbox PHP-FPM + Nginx ${PHP_VERSION} Bookworm (Dev)"
LABEL org.opencontainers.image.description="PHP-FPM + Nginx with Xdebug, PCOV, SPX for development and testing"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/php-baseimages"

ENV CBOX_IMAGE_TIER=dev

# Install Nginx
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx libnginx-mod-http-headers-more-filter gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Brotli modules (built in brotli-builder against this exact nginx version)
COPY --from=brotli-builder /out/ /usr/lib/nginx/modules/
RUN printf 'load_module modules/ngx_http_brotli_filter_module.so;\nload_module modules/ngx_http_brotli_static_module.so;\n' \
    > /etc/nginx/modules-enabled/50-mod-http-brotli.conf

# Create nginx directories + forward access/error logs to docker log
# collector (stdout/stderr) so kubectl logs / docker logs sees them.
RUN mkdir -p /etc/nginx/conf.d /var/log/nginx /run/nginx && \
    chown -R www-data:www-data /var/log/nginx /run/nginx && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

# Debian nginx uses www-data by default, but let's ensure it
# Also remove the default site that conflicts with our configuration
RUN sed -i 's/user nginx;/user www-data;/' /etc/nginx/nginx.conf 2>/dev/null || true && \
    rm -f /etc/nginx/sites-enabled/default

# Copy Nginx configuration
COPY php-fpm-nginx/common/default.conf /etc/nginx/conf.d/default.conf
COPY php-fpm-nginx/common/default.conf.template /etc/nginx/conf.d/default.conf.template

# Copy Cbox Init configuration
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
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

WORKDIR /var/www/html

# Expose both HTTP and HTTPS
EXPOSE 80 443

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["cbox-init"]

# ═══════════════════════════════════════════════════════════════════════════
# DEV-ROOTLESS: Chromium + Xdebug, PCOV, SPX, running as www-data
# ═══════════════════════════════════════════════════════════════════════════
FROM base-dev-rootless AS dev-rootless

ARG PHP_VERSION

LABEL org.opencontainers.image.title="Cbox PHP-FPM + Nginx ${PHP_VERSION} Bookworm (Dev Rootless)"
LABEL org.opencontainers.image.description="PHP-FPM + Nginx with Xdebug, PCOV, SPX - Rootless"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/php-baseimages"

ENV CBOX_IMAGE_TIER=dev

# Switch to root temporarily for setup
USER root

# Install Nginx
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx libnginx-mod-http-headers-more-filter gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Brotli modules (built in brotli-builder against this exact nginx version)
COPY --from=brotli-builder /out/ /usr/lib/nginx/modules/
RUN printf 'load_module modules/ngx_http_brotli_filter_module.so;\nload_module modules/ngx_http_brotli_static_module.so;\n' \
    > /etc/nginx/modules-enabled/50-mod-http-brotli.conf

# Create nginx directories with www-data ownership + forward access/error
# logs to docker log collector (stdout/stderr) so kubectl logs / docker
# logs sees them.
# Note: Debian nginx uses /var/lib/nginx for tmp dirs (body, proxy, fastcgi, etc.)
RUN mkdir -p /etc/nginx/conf.d /var/log/nginx /run/nginx /var/lib/nginx && \
    chown -R www-data:www-data /var/log/nginx /run/nginx /etc/nginx /var/lib/nginx && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

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

# Copy Cbox Init configuration (rootless version with port 8080 health check)
RUN mkdir -p /etc/cbox-init && chown -R www-data:www-data /etc/cbox-init
COPY php-fpm-nginx/common/cbox-init-rootless.yaml /etc/cbox-init/cbox-init.yaml

# Copy entrypoint and healthcheck (overrides php-fpm versions)
COPY php-fpm-nginx/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-fpm-nginx/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

# Create public directory with www-data ownership
RUN mkdir -p /var/www/html/public /var/www/.composer /var/www/.npm /tmp/cbox && \
    chown -R www-data:www-data /var/www /tmp/cbox /usr/local/etc/php/conf.d /usr/local/etc/php-fpm.d

# Health check (checks both nginx and php-fpm)
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

USER www-data
WORKDIR /var/www/html

# Expose unprivileged HTTP port (ports < 1024 require root)
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["cbox-init"]
