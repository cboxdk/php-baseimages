# ============================================================================
# Cbox PHP CLI Image - Debian 8.4 (Bookworm)
# ============================================================================
# LAYER 3: Extends php-base with CLI-specific entrypoint and healthcheck
#
# IMAGE TIERS (inherited from php-base):
# - slim:     Minimal PHP + essential extensions - API/microservices
# - standard: + ImageMagick, vips, Node.js - Most Laravel apps (DEFAULT)
# - full:     + Chromium for Browsershot/Dusk - PDF generation, testing
# ============================================================================

# ============================================================================
# Import base images for each tier
# ============================================================================
FROM ghcr.io/cboxdk/baseimages/php-base:8.4-bookworm-slim AS base-slim
FROM ghcr.io/cboxdk/baseimages/php-base:8.4-bookworm-slim-rootless AS base-slim-rootless
FROM ghcr.io/cboxdk/baseimages/php-base:8.4-bookworm AS base-standard
FROM ghcr.io/cboxdk/baseimages/php-base:8.4-bookworm-rootless AS base-standard-rootless
FROM ghcr.io/cboxdk/baseimages/php-base:8.4-bookworm-full AS base-full
FROM ghcr.io/cboxdk/baseimages/php-base:8.4-bookworm-full-rootless AS base-full-rootless

# ═══════════════════════════════════════════════════════════════════════════
# SLIM-ROOT: Minimal PHP CLI with essential extensions
# ═══════════════════════════════════════════════════════════════════════════
FROM base-slim AS slim-root

LABEL org.opencontainers.image.title="Cbox PHP CLI 8.4 Bookworm (Slim)"
LABEL org.opencontainers.image.description="Minimal PHP CLI with essential extensions"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/baseimages"

ENV CBOX_IMAGE_TIER=slim

COPY php-cli/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-cli/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh && \
    mkdir -p /docker-entrypoint-init.d

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# ═══════════════════════════════════════════════════════════════════════════
# SLIM-ROOTLESS: Minimal PHP CLI running as www-data
# ═══════════════════════════════════════════════════════════════════════════
FROM base-slim-rootless AS slim-rootless

LABEL org.opencontainers.image.title="Cbox PHP CLI 8.4 Bookworm (Slim Rootless)"
LABEL org.opencontainers.image.description="Minimal PHP CLI with essential extensions - Rootless"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/baseimages"

ENV CBOX_IMAGE_TIER=slim

USER root
COPY php-cli/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-cli/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh && \
    mkdir -p /docker-entrypoint-init.d && \
    chown -R www-data:www-data /docker-entrypoint-init.d
USER www-data

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# ═══════════════════════════════════════════════════════════════════════════
# ROOT (STANDARD): Default - ImageMagick, vips, Node.js
# ═══════════════════════════════════════════════════════════════════════════
FROM base-standard AS root

LABEL org.opencontainers.image.title="Cbox PHP CLI 8.4 Bookworm"
LABEL org.opencontainers.image.description="PHP CLI with ImageMagick, vips, Node.js, Composer, and Cbox PM"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/baseimages"

ENV CBOX_IMAGE_TIER=standard

COPY php-cli/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-cli/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh && \
    mkdir -p /docker-entrypoint-init.d

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# ═══════════════════════════════════════════════════════════════════════════
# ROOTLESS (STANDARD): Default rootless - ImageMagick, vips, Node.js
# ═══════════════════════════════════════════════════════════════════════════
FROM base-standard-rootless AS rootless

LABEL org.opencontainers.image.title="Cbox PHP CLI 8.4 Bookworm (Rootless)"
LABEL org.opencontainers.image.description="PHP CLI with ImageMagick, vips, Node.js - Rootless"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/baseimages"

ENV CBOX_IMAGE_TIER=standard

USER root
COPY php-cli/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-cli/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh && \
    mkdir -p /docker-entrypoint-init.d && \
    chown -R www-data:www-data /docker-entrypoint-init.d
USER www-data

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# ═══════════════════════════════════════════════════════════════════════════
# FULL-ROOT: Everything including Chromium for Browsershot/Dusk
# ═══════════════════════════════════════════════════════════════════════════
FROM base-full AS full-root

LABEL org.opencontainers.image.title="Cbox PHP CLI 8.4 Bookworm (Full)"
LABEL org.opencontainers.image.description="PHP CLI with all features including Chromium for Browsershot/Dusk"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/baseimages"

ENV CBOX_IMAGE_TIER=full

COPY php-cli/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-cli/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh && \
    mkdir -p /docker-entrypoint-init.d

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# ═══════════════════════════════════════════════════════════════════════════
# FULL-ROOTLESS: Everything including Chromium, running as www-data
# ═══════════════════════════════════════════════════════════════════════════
FROM base-full-rootless AS full-rootless

LABEL org.opencontainers.image.title="Cbox PHP CLI 8.4 Bookworm (Full Rootless)"
LABEL org.opencontainers.image.description="PHP CLI with all features including Chromium - Rootless"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/baseimages"

ENV CBOX_IMAGE_TIER=full

USER root
COPY php-cli/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-cli/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh && \
    mkdir -p /docker-entrypoint-init.d && \
    chown -R www-data:www-data /docker-entrypoint-init.d
USER www-data

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
