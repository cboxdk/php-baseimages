# ============================================================================
# Cbox PHP-FPM + Nginx Image - Debian (Trixie)
# ============================================================================
# LAYER 4: Extends php-fpm with Nginx for single-container deployment
#          Uses Cbox Init as process manager
#
# IMAGE TIERS (inherited from php-fpm):
# - slim:     Minimal PHP + essential extensions - API/microservices
# - standard: + ImageMagick, Node.js - Most Laravel apps (DEFAULT)
# - chromium: + Chromium for Browsershot/Dusk - PDF generation, testing
#
# PARAMETERIZED: Build with --build-arg PHP_VERSION=8.2|8.3|8.4|8.5
# ============================================================================

ARG PHP_VERSION=8.5
# BASE_CHANNEL pins which channel of the upstream image this build consumes:
# CI passes "-vN" from versions.json release.channel, so a maintenance branch
# (release/v1) builds FROM the -v1 chain and can never inherit a newer major
# through the rolling tags. Empty default keeps local builds on rolling.
ARG BASE_CHANNEL=""

# ============================================================================
# Import base images for each tier from php-fpm
# ============================================================================
FROM ghcr.io/cboxdk/php-baseimages/php-fpm:${PHP_VERSION}-trixie-slim${BASE_CHANNEL} AS base-slim
FROM ghcr.io/cboxdk/php-baseimages/php-fpm:${PHP_VERSION}-trixie-slim-rootless${BASE_CHANNEL} AS base-slim-rootless
FROM ghcr.io/cboxdk/php-baseimages/php-fpm:${PHP_VERSION}-trixie${BASE_CHANNEL} AS base-standard
FROM ghcr.io/cboxdk/php-baseimages/php-fpm:${PHP_VERSION}-trixie-rootless${BASE_CHANNEL} AS base-standard-rootless
FROM ghcr.io/cboxdk/php-baseimages/php-fpm:${PHP_VERSION}-trixie-chromium${BASE_CHANNEL} AS base-chromium
FROM ghcr.io/cboxdk/php-baseimages/php-fpm:${PHP_VERSION}-trixie-chromium-rootless${BASE_CHANNEL} AS base-chromium-rootless
FROM ghcr.io/cboxdk/php-baseimages/php-fpm:${PHP_VERSION}-trixie-dev${BASE_CHANNEL} AS base-dev
FROM ghcr.io/cboxdk/php-baseimages/php-fpm:${PHP_VERSION}-trixie-dev-rootless${BASE_CHANNEL} AS base-dev-rootless

# Debian 13 packages Brotli modules against its nginx ABI. Apt upgrades the
# server and modules together; no compiler stage or stale copied modules.

# ═══════════════════════════════════════════════════════════════════════════
# SLIM-ROOT: Minimal PHP-FPM + Nginx
# ═══════════════════════════════════════════════════════════════════════════
FROM base-slim AS slim-root
# open_basedir default retired on measurement (-39% Laravel throughput via
# the disabled realpath cache); the base layer's inherited ENV must be
# overridden HERE until a php-fpm publish carries the new default.
ENV PHP_OPEN_BASEDIR=""

ARG PHP_VERSION

LABEL org.opencontainers.image.title="Cbox PHP-FPM + Nginx ${PHP_VERSION} Trixie (Slim)"
LABEL org.opencontainers.image.description="Minimal PHP-FPM + Nginx with essential extensions"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/php-baseimages"

ENV CBOX_IMAGE_TIER=slim

# ============================================================================
# Lifecycle State (set at build time via CI; drives startup banners)
# Declared here because this image COPIES from php-base rather than building
# FROM it - ENV does not survive COPY, so php-base's baked values never
# reach this image. The CI passes these build-args to every image build.
# ============================================================================
ARG CBOX_LIFECYCLE=stable
ARG CBOX_PHP_VERSION=
ARG CBOX_PHP_EOL=
ARG CBOX_REMOVAL_DATE=
ARG CBOX_PREVIEW_STATUS=
ENV CBOX_LIFECYCLE=${CBOX_LIFECYCLE} \
    CBOX_PHP_VERSION=${CBOX_PHP_VERSION} \
    CBOX_PHP_EOL=${CBOX_PHP_EOL} \
    CBOX_REMOVAL_DATE=${CBOX_REMOVAL_DATE} \
    CBOX_PREVIEW_STATUS=${CBOX_PREVIEW_STATUS}


# Weekly cache refresh (see php-base/Dockerfile) - without it, a dispatch
# without a new base digest replays cached apt layers with stale packages
ARG CACHE_REFRESH=local
RUN echo "cache-refresh=${CACHE_REFRESH}" >/dev/null && \
    apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*

# Install Nginx
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx libnginx-mod-http-headers-more-filter \
    libnginx-mod-http-brotli-filter libnginx-mod-http-brotli-static gettext-base \
    && rm -rf /var/lib/apt/lists/*


# Create nginx directories + forward access/error logs to docker log
# collector (stdout/stderr) so kubectl logs / docker logs sees them.
RUN mkdir -p /etc/nginx/conf.d /etc/nginx/server.d /var/log/nginx /run/nginx && \
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
# The shared lib must ship in the SAME layer as the entrypoint that calls it -
# inheriting it from the php-fpm base invites version skew (a repo entrypoint
# calling a function the registry base's lib does not have yet = exit 127).
COPY common/lib/entrypoint-lib.sh /usr/local/lib/cbox/entrypoint-lib.sh
COPY php-fpm-nginx/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

# Create public directory if it doesn't exist
RUN mkdir -p /var/www/html/public && \
    chown -R www-data:www-data /var/www/html

# Health check (checks both nginx and php-fpm)
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --start-interval=3s --retries=3 \
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
# open_basedir default retired on measurement (-39% Laravel throughput via
# the disabled realpath cache); the base layer's inherited ENV must be
# overridden HERE until a php-fpm publish carries the new default.
ENV PHP_OPEN_BASEDIR=""

ARG PHP_VERSION

LABEL org.opencontainers.image.title="Cbox PHP-FPM + Nginx ${PHP_VERSION} Trixie (Slim Rootless)"
LABEL org.opencontainers.image.description="Minimal PHP-FPM + Nginx with essential extensions - Rootless"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/php-baseimages"

ENV CBOX_IMAGE_TIER=slim

# ============================================================================
# Lifecycle State (set at build time via CI; drives startup banners)
# Declared here because this image COPIES from php-base rather than building
# FROM it - ENV does not survive COPY, so php-base's baked values never
# reach this image. The CI passes these build-args to every image build.
# ============================================================================
ARG CBOX_LIFECYCLE=stable
ARG CBOX_PHP_VERSION=
ARG CBOX_PHP_EOL=
ARG CBOX_REMOVAL_DATE=
ARG CBOX_PREVIEW_STATUS=
ENV CBOX_LIFECYCLE=${CBOX_LIFECYCLE} \
    CBOX_PHP_VERSION=${CBOX_PHP_VERSION} \
    CBOX_PHP_EOL=${CBOX_PHP_EOL} \
    CBOX_REMOVAL_DATE=${CBOX_REMOVAL_DATE} \
    CBOX_PREVIEW_STATUS=${CBOX_PREVIEW_STATUS}


# Switch to root temporarily for setup
USER root

# Weekly cache refresh (see php-base/Dockerfile) - without it, a dispatch
# without a new base digest replays cached apt layers with stale packages
ARG CACHE_REFRESH=local
RUN echo "cache-refresh=${CACHE_REFRESH}" >/dev/null && \
    apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*

# Install Nginx
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx libnginx-mod-http-headers-more-filter \
    libnginx-mod-http-brotli-filter libnginx-mod-http-brotli-static gettext-base \
    && rm -rf /var/lib/apt/lists/*


# Create nginx directories with www-data ownership + forward access/error
# logs to docker log collector (stdout/stderr) so kubectl logs / docker
# logs sees them.
# Note: Debian nginx uses /var/lib/nginx for tmp dirs (body, proxy, fastcgi, etc.)
RUN mkdir -p /etc/nginx/conf.d /etc/nginx/server.d /var/log/nginx /run/nginx /var/lib/nginx /var/lib/fpm-tune && \
    chown -R www-data:www-data /var/log/nginx /run/nginx /etc/nginx /var/lib/nginx /var/lib/fpm-tune && \
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
# The shared lib must ship in the SAME layer as the entrypoint that calls it -
# inheriting it from the php-fpm base invites version skew (a repo entrypoint
# calling a function the registry base's lib does not have yet = exit 127).
COPY common/lib/entrypoint-lib.sh /usr/local/lib/cbox/entrypoint-lib.sh
COPY php-fpm-nginx/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

# Create public directory with www-data ownership
RUN mkdir -p /var/www/html/public /var/www/.composer /var/www/.npm /tmp/cbox && \
    chown -R www-data:www-data /var/www /tmp/cbox /usr/local/etc/php/conf.d /usr/local/etc/php-fpm.d

# Health check (checks both nginx and php-fpm)
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --start-interval=3s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

USER www-data
WORKDIR /var/www/html

# Expose unprivileged HTTP port (ports < 1024 require root)
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["cbox-init"]

# ═══════════════════════════════════════════════════════════════════════════
# ROOT (STANDARD): Default - PHP-FPM + Nginx with ImageMagick, Node.js
# ═══════════════════════════════════════════════════════════════════════════
FROM base-standard AS root
# open_basedir default retired on measurement (-39% Laravel throughput via
# the disabled realpath cache); the base layer's inherited ENV must be
# overridden HERE until a php-fpm publish carries the new default.
ENV PHP_OPEN_BASEDIR=""

ARG PHP_VERSION

LABEL org.opencontainers.image.title="Cbox PHP-FPM + Nginx ${PHP_VERSION} Trixie"
LABEL org.opencontainers.image.description="PHP-FPM + Nginx with all extensions, Composer, Node.js, and Cbox Init"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/php-baseimages"

ENV CBOX_IMAGE_TIER=standard

# ============================================================================
# Lifecycle State (set at build time via CI; drives startup banners)
# Declared here because this image COPIES from php-base rather than building
# FROM it - ENV does not survive COPY, so php-base's baked values never
# reach this image. The CI passes these build-args to every image build.
# ============================================================================
ARG CBOX_LIFECYCLE=stable
ARG CBOX_PHP_VERSION=
ARG CBOX_PHP_EOL=
ARG CBOX_REMOVAL_DATE=
ARG CBOX_PREVIEW_STATUS=
ENV CBOX_LIFECYCLE=${CBOX_LIFECYCLE} \
    CBOX_PHP_VERSION=${CBOX_PHP_VERSION} \
    CBOX_PHP_EOL=${CBOX_PHP_EOL} \
    CBOX_REMOVAL_DATE=${CBOX_REMOVAL_DATE} \
    CBOX_PREVIEW_STATUS=${CBOX_PREVIEW_STATUS}


# Weekly cache refresh (see php-base/Dockerfile) - without it, a dispatch
# without a new base digest replays cached apt layers with stale packages
ARG CACHE_REFRESH=local
RUN echo "cache-refresh=${CACHE_REFRESH}" >/dev/null && \
    apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*

# Install Nginx
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx libnginx-mod-http-headers-more-filter \
    libnginx-mod-http-brotli-filter libnginx-mod-http-brotli-static gettext-base \
    && rm -rf /var/lib/apt/lists/*


# Create nginx directories + forward access/error logs to docker log
# collector (stdout/stderr) so kubectl logs / docker logs sees them.
RUN mkdir -p /etc/nginx/conf.d /etc/nginx/server.d /var/log/nginx /run/nginx && \
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
# The shared lib must ship in the SAME layer as the entrypoint that calls it -
# inheriting it from the php-fpm base invites version skew (a repo entrypoint
# calling a function the registry base's lib does not have yet = exit 127).
COPY common/lib/entrypoint-lib.sh /usr/local/lib/cbox/entrypoint-lib.sh
COPY php-fpm-nginx/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

# Create public directory if it doesn't exist
RUN mkdir -p /var/www/html/public && \
    chown -R www-data:www-data /var/www/html

# Health check (checks both nginx and php-fpm)
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --start-interval=3s --retries=3 \
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
# open_basedir default retired on measurement (-39% Laravel throughput via
# the disabled realpath cache); the base layer's inherited ENV must be
# overridden HERE until a php-fpm publish carries the new default.
ENV PHP_OPEN_BASEDIR=""

ARG PHP_VERSION

LABEL org.opencontainers.image.title="Cbox PHP-FPM + Nginx ${PHP_VERSION} Trixie (Rootless)"
LABEL org.opencontainers.image.description="PHP-FPM + Nginx with all extensions, Composer, Node.js, and Cbox Init - Rootless"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/php-baseimages"

ENV CBOX_IMAGE_TIER=standard

# ============================================================================
# Lifecycle State (set at build time via CI; drives startup banners)
# Declared here because this image COPIES from php-base rather than building
# FROM it - ENV does not survive COPY, so php-base's baked values never
# reach this image. The CI passes these build-args to every image build.
# ============================================================================
ARG CBOX_LIFECYCLE=stable
ARG CBOX_PHP_VERSION=
ARG CBOX_PHP_EOL=
ARG CBOX_REMOVAL_DATE=
ARG CBOX_PREVIEW_STATUS=
ENV CBOX_LIFECYCLE=${CBOX_LIFECYCLE} \
    CBOX_PHP_VERSION=${CBOX_PHP_VERSION} \
    CBOX_PHP_EOL=${CBOX_PHP_EOL} \
    CBOX_REMOVAL_DATE=${CBOX_REMOVAL_DATE} \
    CBOX_PREVIEW_STATUS=${CBOX_PREVIEW_STATUS}


# Switch to root temporarily for setup
USER root

# Weekly cache refresh (see php-base/Dockerfile) - without it, a dispatch
# without a new base digest replays cached apt layers with stale packages
ARG CACHE_REFRESH=local
RUN echo "cache-refresh=${CACHE_REFRESH}" >/dev/null && \
    apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*

# Install Nginx
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx libnginx-mod-http-headers-more-filter \
    libnginx-mod-http-brotli-filter libnginx-mod-http-brotli-static gettext-base \
    && rm -rf /var/lib/apt/lists/*


# Create nginx directories with www-data ownership + forward access/error
# logs to docker log collector (stdout/stderr) so kubectl logs / docker
# logs sees them.
# Note: Debian nginx uses /var/lib/nginx for tmp dirs (body, proxy, fastcgi, etc.)
RUN mkdir -p /etc/nginx/conf.d /etc/nginx/server.d /var/log/nginx /run/nginx /var/lib/nginx /var/lib/fpm-tune && \
    chown -R www-data:www-data /var/log/nginx /run/nginx /etc/nginx /var/lib/nginx /var/lib/fpm-tune && \
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
# The shared lib must ship in the SAME layer as the entrypoint that calls it -
# inheriting it from the php-fpm base invites version skew (a repo entrypoint
# calling a function the registry base's lib does not have yet = exit 127).
COPY common/lib/entrypoint-lib.sh /usr/local/lib/cbox/entrypoint-lib.sh
COPY php-fpm-nginx/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

# Create public directory with www-data ownership
RUN mkdir -p /var/www/html/public /var/www/.composer /var/www/.npm /tmp/cbox && \
    chown -R www-data:www-data /var/www /tmp/cbox /usr/local/etc/php/conf.d /usr/local/etc/php-fpm.d

# Health check (checks both nginx and php-fpm)
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --start-interval=3s --retries=3 \
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
# open_basedir default retired on measurement (-39% Laravel throughput via
# the disabled realpath cache); the base layer's inherited ENV must be
# overridden HERE until a php-fpm publish carries the new default.
ENV PHP_OPEN_BASEDIR=""

ARG PHP_VERSION

LABEL org.opencontainers.image.title="Cbox PHP-FPM + Nginx ${PHP_VERSION} Trixie (Chromium)"
LABEL org.opencontainers.image.description="PHP-FPM + Nginx with all features including Chromium for Browsershot/Dusk"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/php-baseimages"

ENV CBOX_IMAGE_TIER=chromium

# ============================================================================
# Lifecycle State (set at build time via CI; drives startup banners)
# Declared here because this image COPIES from php-base rather than building
# FROM it - ENV does not survive COPY, so php-base's baked values never
# reach this image. The CI passes these build-args to every image build.
# ============================================================================
ARG CBOX_LIFECYCLE=stable
ARG CBOX_PHP_VERSION=
ARG CBOX_PHP_EOL=
ARG CBOX_REMOVAL_DATE=
ARG CBOX_PREVIEW_STATUS=
ENV CBOX_LIFECYCLE=${CBOX_LIFECYCLE} \
    CBOX_PHP_VERSION=${CBOX_PHP_VERSION} \
    CBOX_PHP_EOL=${CBOX_PHP_EOL} \
    CBOX_REMOVAL_DATE=${CBOX_REMOVAL_DATE} \
    CBOX_PREVIEW_STATUS=${CBOX_PREVIEW_STATUS}


# Weekly cache refresh (see php-base/Dockerfile) - without it, a dispatch
# without a new base digest replays cached apt layers with stale packages
ARG CACHE_REFRESH=local
RUN echo "cache-refresh=${CACHE_REFRESH}" >/dev/null && \
    apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*

# Install Nginx
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx libnginx-mod-http-headers-more-filter \
    libnginx-mod-http-brotli-filter libnginx-mod-http-brotli-static gettext-base \
    && rm -rf /var/lib/apt/lists/*


# Create nginx directories + forward access/error logs to docker log
# collector (stdout/stderr) so kubectl logs / docker logs sees them.
RUN mkdir -p /etc/nginx/conf.d /etc/nginx/server.d /var/log/nginx /run/nginx && \
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
# The shared lib must ship in the SAME layer as the entrypoint that calls it -
# inheriting it from the php-fpm base invites version skew (a repo entrypoint
# calling a function the registry base's lib does not have yet = exit 127).
COPY common/lib/entrypoint-lib.sh /usr/local/lib/cbox/entrypoint-lib.sh
COPY php-fpm-nginx/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

# Create public directory if it doesn't exist
RUN mkdir -p /var/www/html/public && \
    chown -R www-data:www-data /var/www/html

# Health check (checks both nginx and php-fpm)
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --start-interval=3s --retries=3 \
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
# open_basedir default retired on measurement (-39% Laravel throughput via
# the disabled realpath cache); the base layer's inherited ENV must be
# overridden HERE until a php-fpm publish carries the new default.
ENV PHP_OPEN_BASEDIR=""

ARG PHP_VERSION

LABEL org.opencontainers.image.title="Cbox PHP-FPM + Nginx ${PHP_VERSION} Trixie (Chromium Rootless)"
LABEL org.opencontainers.image.description="PHP-FPM + Nginx with all features including Chromium - Rootless"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/php-baseimages"

ENV CBOX_IMAGE_TIER=chromium

# ============================================================================
# Lifecycle State (set at build time via CI; drives startup banners)
# Declared here because this image COPIES from php-base rather than building
# FROM it - ENV does not survive COPY, so php-base's baked values never
# reach this image. The CI passes these build-args to every image build.
# ============================================================================
ARG CBOX_LIFECYCLE=stable
ARG CBOX_PHP_VERSION=
ARG CBOX_PHP_EOL=
ARG CBOX_REMOVAL_DATE=
ARG CBOX_PREVIEW_STATUS=
ENV CBOX_LIFECYCLE=${CBOX_LIFECYCLE} \
    CBOX_PHP_VERSION=${CBOX_PHP_VERSION} \
    CBOX_PHP_EOL=${CBOX_PHP_EOL} \
    CBOX_REMOVAL_DATE=${CBOX_REMOVAL_DATE} \
    CBOX_PREVIEW_STATUS=${CBOX_PREVIEW_STATUS}


# Switch to root temporarily for setup
USER root

# Weekly cache refresh (see php-base/Dockerfile) - without it, a dispatch
# without a new base digest replays cached apt layers with stale packages
ARG CACHE_REFRESH=local
RUN echo "cache-refresh=${CACHE_REFRESH}" >/dev/null && \
    apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*

# Install Nginx
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx libnginx-mod-http-headers-more-filter \
    libnginx-mod-http-brotli-filter libnginx-mod-http-brotli-static gettext-base \
    && rm -rf /var/lib/apt/lists/*


# Create nginx directories with www-data ownership + forward access/error
# logs to docker log collector (stdout/stderr) so kubectl logs / docker
# logs sees them.
# Note: Debian nginx uses /var/lib/nginx for tmp dirs (body, proxy, fastcgi, etc.)
RUN mkdir -p /etc/nginx/conf.d /etc/nginx/server.d /var/log/nginx /run/nginx /var/lib/nginx /var/lib/fpm-tune && \
    chown -R www-data:www-data /var/log/nginx /run/nginx /etc/nginx /var/lib/nginx /var/lib/fpm-tune && \
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
# The shared lib must ship in the SAME layer as the entrypoint that calls it -
# inheriting it from the php-fpm base invites version skew (a repo entrypoint
# calling a function the registry base's lib does not have yet = exit 127).
COPY common/lib/entrypoint-lib.sh /usr/local/lib/cbox/entrypoint-lib.sh
COPY php-fpm-nginx/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

# Create public directory with www-data ownership
RUN mkdir -p /var/www/html/public /var/www/.composer /var/www/.npm /tmp/cbox && \
    chown -R www-data:www-data /var/www /tmp/cbox /usr/local/etc/php/conf.d /usr/local/etc/php-fpm.d

# Health check (checks both nginx and php-fpm)
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --start-interval=3s --retries=3 \
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
# open_basedir default retired on measurement (-39% Laravel throughput via
# the disabled realpath cache); the base layer's inherited ENV must be
# overridden HERE until a php-fpm publish carries the new default.
ENV PHP_OPEN_BASEDIR=""

ARG PHP_VERSION

LABEL org.opencontainers.image.title="Cbox PHP-FPM + Nginx ${PHP_VERSION} Trixie (Dev)"
LABEL org.opencontainers.image.description="PHP-FPM + Nginx with Xdebug, PCOV, SPX for development and testing"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/php-baseimages"

ENV CBOX_IMAGE_TIER=dev

# ============================================================================
# Lifecycle State (set at build time via CI; drives startup banners)
# Declared here because this image COPIES from php-base rather than building
# FROM it - ENV does not survive COPY, so php-base's baked values never
# reach this image. The CI passes these build-args to every image build.
# ============================================================================
ARG CBOX_LIFECYCLE=stable
ARG CBOX_PHP_VERSION=
ARG CBOX_PHP_EOL=
ARG CBOX_REMOVAL_DATE=
ARG CBOX_PREVIEW_STATUS=
ENV CBOX_LIFECYCLE=${CBOX_LIFECYCLE} \
    CBOX_PHP_VERSION=${CBOX_PHP_VERSION} \
    CBOX_PHP_EOL=${CBOX_PHP_EOL} \
    CBOX_REMOVAL_DATE=${CBOX_REMOVAL_DATE} \
    CBOX_PREVIEW_STATUS=${CBOX_PREVIEW_STATUS}


# Weekly cache refresh (see php-base/Dockerfile) - without it, a dispatch
# without a new base digest replays cached apt layers with stale packages
ARG CACHE_REFRESH=local
RUN echo "cache-refresh=${CACHE_REFRESH}" >/dev/null && \
    apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*

# Install Nginx
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx libnginx-mod-http-headers-more-filter \
    libnginx-mod-http-brotli-filter libnginx-mod-http-brotli-static gettext-base \
    && rm -rf /var/lib/apt/lists/*


# Create nginx directories + forward access/error logs to docker log
# collector (stdout/stderr) so kubectl logs / docker logs sees them.
RUN mkdir -p /etc/nginx/conf.d /etc/nginx/server.d /var/log/nginx /run/nginx && \
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
# The shared lib must ship in the SAME layer as the entrypoint that calls it -
# inheriting it from the php-fpm base invites version skew (a repo entrypoint
# calling a function the registry base's lib does not have yet = exit 127).
COPY common/lib/entrypoint-lib.sh /usr/local/lib/cbox/entrypoint-lib.sh
COPY php-fpm-nginx/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

# Create public directory if it doesn't exist
RUN mkdir -p /var/www/html/public && \
    chown -R www-data:www-data /var/www/html

# Health check (checks both nginx and php-fpm)
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --start-interval=3s --retries=3 \
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
# open_basedir default retired on measurement (-39% Laravel throughput via
# the disabled realpath cache); the base layer's inherited ENV must be
# overridden HERE until a php-fpm publish carries the new default.
ENV PHP_OPEN_BASEDIR=""

ARG PHP_VERSION

LABEL org.opencontainers.image.title="Cbox PHP-FPM + Nginx ${PHP_VERSION} Trixie (Dev Rootless)"
LABEL org.opencontainers.image.description="PHP-FPM + Nginx with Xdebug, PCOV, SPX - Rootless"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/php-baseimages"

ENV CBOX_IMAGE_TIER=dev

# ============================================================================
# Lifecycle State (set at build time via CI; drives startup banners)
# Declared here because this image COPIES from php-base rather than building
# FROM it - ENV does not survive COPY, so php-base's baked values never
# reach this image. The CI passes these build-args to every image build.
# ============================================================================
ARG CBOX_LIFECYCLE=stable
ARG CBOX_PHP_VERSION=
ARG CBOX_PHP_EOL=
ARG CBOX_REMOVAL_DATE=
ARG CBOX_PREVIEW_STATUS=
ENV CBOX_LIFECYCLE=${CBOX_LIFECYCLE} \
    CBOX_PHP_VERSION=${CBOX_PHP_VERSION} \
    CBOX_PHP_EOL=${CBOX_PHP_EOL} \
    CBOX_REMOVAL_DATE=${CBOX_REMOVAL_DATE} \
    CBOX_PREVIEW_STATUS=${CBOX_PREVIEW_STATUS}


# Switch to root temporarily for setup
USER root

# Weekly cache refresh (see php-base/Dockerfile) - without it, a dispatch
# without a new base digest replays cached apt layers with stale packages
ARG CACHE_REFRESH=local
RUN echo "cache-refresh=${CACHE_REFRESH}" >/dev/null && \
    apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*

# Install Nginx
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx libnginx-mod-http-headers-more-filter \
    libnginx-mod-http-brotli-filter libnginx-mod-http-brotli-static gettext-base \
    && rm -rf /var/lib/apt/lists/*


# Create nginx directories with www-data ownership + forward access/error
# logs to docker log collector (stdout/stderr) so kubectl logs / docker
# logs sees them.
# Note: Debian nginx uses /var/lib/nginx for tmp dirs (body, proxy, fastcgi, etc.)
RUN mkdir -p /etc/nginx/conf.d /etc/nginx/server.d /var/log/nginx /run/nginx /var/lib/nginx /var/lib/fpm-tune && \
    chown -R www-data:www-data /var/log/nginx /run/nginx /etc/nginx /var/lib/nginx /var/lib/fpm-tune && \
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
# The shared lib must ship in the SAME layer as the entrypoint that calls it -
# inheriting it from the php-fpm base invites version skew (a repo entrypoint
# calling a function the registry base's lib does not have yet = exit 127).
COPY common/lib/entrypoint-lib.sh /usr/local/lib/cbox/entrypoint-lib.sh
COPY php-fpm-nginx/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

# Create public directory with www-data ownership
RUN mkdir -p /var/www/html/public /var/www/.composer /var/www/.npm /tmp/cbox && \
    chown -R www-data:www-data /var/www /tmp/cbox /usr/local/etc/php/conf.d /usr/local/etc/php-fpm.d

# Health check (checks both nginx and php-fpm)
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --start-interval=3s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

USER www-data
WORKDIR /var/www/html

# Expose unprivileged HTTP port (ports < 1024 require root)
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["cbox-init"]
