FROM nginx:1.29-trixie

# CI passes the run ID so every requested security rebuild refreshes APT,
# including multiple fixes in the same week. Local builds retain cache unless
# CACHE_REFRESH is supplied explicitly.
ARG CACHE_REFRESH=local
# Upgrade inherited packages too; installing our own tools is insufficient.
RUN echo "cache-refresh=${CACHE_REFRESH}" >/dev/null && \
    apt-get -o APT::Update::Error-Mode=any update && apt-get upgrade --with-new-pkgs -y && rm -rf /var/lib/apt/lists/*

LABEL maintainer="Sylvester Damgaard <sn@cbox.dk>"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/php-baseimages"
LABEL org.opencontainers.image.description="Nginx 1.29 Debian Trixie - Optimized for PHP"

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
COPY nginx/debian/trixie/nginx.conf /etc/nginx/nginx.conf
COPY nginx/debian/trixie/conf.d/default.conf /etc/nginx/conf.d/default.conf

# Copy entrypoint and health check scripts
COPY nginx/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY nginx/common/healthcheck.sh /usr/local/bin/healthcheck.sh
# The shared lib must ship in the SAME layer as the entrypoint that calls it -
# the same rule the PHP images follow, so a repo entrypoint can never call a
# function an older baked lib does not have.
COPY common/lib/entrypoint-lib.sh /usr/local/lib/cbox/entrypoint-lib.sh
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
