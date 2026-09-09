FROM nginx:1.29-bookworm

# Weekly cache refresh: referencing this arg invalidates every later layer in
# the stage chain once per ISO week, so scheduled security rebuilds install
# fresh apt packages instead of replaying cached layers. Found when the CVE
# gate caught a libssh2 fix already published in bookworm-security that a
# "fresh" build did not contain. CI passes the current ISO week; local builds
# default to a static value (fast rebuilds, bust manually with --build-arg).
ARG CACHE_REFRESH=local
# The bust layer IS the security-upgrade layer: parent images ship packages
# (php:*-bookworm carries libssh2 via curl, for example) that our later
# `apt-get install <other things>` never touches - `install` does not upgrade
# unrelated already-installed packages. Upgrading here, keyed to the weekly
# bust, is what makes "rebuilt weekly with security patches" true for the
# parent's packages too, not only for the ones we install ourselves.
RUN echo "cache-refresh=${CACHE_REFRESH}" >/dev/null && \
    apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*

LABEL maintainer="Sylvester Damgaard <sn@cbox.dk>"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/php-baseimages"
LABEL org.opencontainers.image.description="Nginx 1.29 Debian Bookworm - Optimized for PHP"

ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG DEBIAN_FRONTEND=noninteractive

# Install minimal dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    wget \
    ca-certificates \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

# Copy nginx configuration
COPY nginx/debian/bookworm/nginx.conf /etc/nginx/nginx.conf
COPY nginx/debian/bookworm/conf.d/default.conf /etc/nginx/conf.d/default.conf

# Copy entrypoint and health check scripts
COPY nginx/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY nginx/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

# Create cache directories
RUN mkdir -p /var/cache/nginx/client_temp \
    /var/cache/nginx/proxy_temp \
    /var/cache/nginx/fastcgi_temp \
    /var/cache/nginx/uwsgi_temp \
    /var/cache/nginx/scgi_temp \
    && chown -R nginx:nginx /var/cache/nginx

# Create application directory
RUN mkdir -p /var/www/html/public && \
    chown -R nginx:nginx /var/www

# Forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

WORKDIR /var/www/html

EXPOSE 80 443

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --start-interval=3s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

STOPSIGNAL SIGQUIT

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
