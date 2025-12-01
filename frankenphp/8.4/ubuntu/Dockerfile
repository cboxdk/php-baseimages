# ============================================================================
# PHPeek FrankenPHP Image - Ubuntu 8.4 (24.04 Noble)
# ============================================================================
# FrankenPHP is a modern PHP application server built on Caddy
# Supports HTTP/3, automatic HTTPS, and worker mode for performance
# ============================================================================

FROM ghcr.io/phpeek/baseimages/php-base:8.4-ubuntu

LABEL org.opencontainers.image.title="PHPeek FrankenPHP 8.4 Ubuntu"
LABEL org.opencontainers.image.description="FrankenPHP with all extensions, Composer, Node.js, and PHPeek PM"
LABEL org.opencontainers.image.vendor="PHPeek"
LABEL org.opencontainers.image.source="https://github.com/phpeek/baseimages"

# Install FrankenPHP dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        libcap2-bin \
    && rm -rf /var/lib/apt/lists/*

# Download and install FrankenPHP binary
ARG FRANKENPHP_VERSION=1.3.6
ARG TARGETARCH
RUN set -eux; \
    case "${TARGETARCH:-amd64}" in \
        amd64) ARCH='x86_64' ;; \
        arm64) ARCH='aarch64' ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/dunglas/frankenphp/releases/download/v${FRANKENPHP_VERSION}/frankenphp-linux-${ARCH}" -o /usr/local/bin/frankenphp \
    && chmod +x /usr/local/bin/frankenphp \
    && setcap cap_net_bind_service=+ep /usr/local/bin/frankenphp \
    && frankenphp version

# Create directories
RUN mkdir -p /var/www/html /docker-entrypoint-init.d /etc/caddy /data/caddy /config/caddy \
    && chown -R www-data:www-data /var/www/html /data/caddy /config/caddy

# Copy entrypoint and healthcheck
COPY frankenphp/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY frankenphp/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

# Environment variables
ENV XDG_CONFIG_HOME=/config
ENV XDG_DATA_HOME=/data

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

WORKDIR /var/www/html
EXPOSE 80 443 443/udp 2019

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["frankenphp"]
