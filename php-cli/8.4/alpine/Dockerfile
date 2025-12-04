# ============================================================================
# PHPeek PHP CLI Image - Alpine 8.4
# ============================================================================
# LAYER 3: Extends php-base with CLI-specific entrypoint and healthcheck
# ============================================================================
# Build targets:
#   - slim-root     : Minimal PHP + essential extensions (root)
#   - slim-rootless : Minimal PHP + essential extensions (rootless)
#   - root          : Standard with ImageMagick, vips, Node.js (DEFAULT)
#   - rootless      : Standard rootless variant
#   - full-root     : Full with Chromium for Browsershot/Dusk
#   - full-rootless : Full rootless variant
# ============================================================================

# Import all tier variants from php-base
FROM ghcr.io/gophpeek/baseimages/php-base:8.4-alpine-slim AS base-slim
FROM ghcr.io/gophpeek/baseimages/php-base:8.4-alpine-slim-rootless AS base-slim-rootless
FROM ghcr.io/gophpeek/baseimages/php-base:8.4-alpine AS base-standard
FROM ghcr.io/gophpeek/baseimages/php-base:8.4-alpine-rootless AS base-standard-rootless
FROM ghcr.io/gophpeek/baseimages/php-base:8.4-alpine-full AS base-full
FROM ghcr.io/gophpeek/baseimages/php-base:8.4-alpine-full-rootless AS base-full-rootless

# ═══════════════════════════════════════════════════════════════════════════
# SLIM-ROOT VARIANT - Minimal PHP with essential extensions
# ═══════════════════════════════════════════════════════════════════════════
FROM base-slim AS slim-root

LABEL org.opencontainers.image.title="PHPeek PHP CLI 8.4 Alpine (Slim)"
LABEL org.opencontainers.image.description="Minimal PHP CLI with essential extensions and Composer"
LABEL org.opencontainers.image.vendor="PHPeek"
LABEL org.opencontainers.image.source="https://github.com/gophpeek/baseimages"

COPY php-cli/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-cli/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh && \
    mkdir -p /docker-entrypoint-init.d

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# ═══════════════════════════════════════════════════════════════════════════
# SLIM-ROOTLESS VARIANT - Minimal PHP, no root privileges
# ═══════════════════════════════════════════════════════════════════════════
FROM base-slim-rootless AS slim-rootless

LABEL org.opencontainers.image.title="PHPeek PHP CLI 8.4 Alpine (Slim Rootless)"
LABEL org.opencontainers.image.description="Minimal PHP CLI with essential extensions - Rootless"
LABEL org.opencontainers.image.vendor="PHPeek"
LABEL org.opencontainers.image.source="https://github.com/gophpeek/baseimages"

USER root
COPY php-cli/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-cli/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh
USER www-data

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# ═══════════════════════════════════════════════════════════════════════════
# ROOT VARIANT (DEFAULT) - Standard with ImageMagick, vips, Node.js
# ═══════════════════════════════════════════════════════════════════════════
FROM base-standard AS root

LABEL org.opencontainers.image.title="PHPeek PHP CLI 8.4 Alpine"
LABEL org.opencontainers.image.description="PHP CLI with all extensions, Composer, Node.js, and PHPeek PM"
LABEL org.opencontainers.image.vendor="PHPeek"
LABEL org.opencontainers.image.source="https://github.com/gophpeek/baseimages"

COPY php-cli/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-cli/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh && \
    mkdir -p /docker-entrypoint-init.d

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# ═══════════════════════════════════════════════════════════════════════════
# ROOTLESS VARIANT - Standard, no root privileges
# ═══════════════════════════════════════════════════════════════════════════
FROM base-standard-rootless AS rootless

LABEL org.opencontainers.image.title="PHPeek PHP CLI 8.4 Alpine (Rootless)"
LABEL org.opencontainers.image.description="PHP CLI with all extensions, Composer, Node.js, and PHPeek PM - Rootless"
LABEL org.opencontainers.image.vendor="PHPeek"
LABEL org.opencontainers.image.source="https://github.com/gophpeek/baseimages"

USER root
COPY php-cli/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-cli/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh
USER www-data

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# ═══════════════════════════════════════════════════════════════════════════
# FULL-ROOT VARIANT - Full with Chromium for Browsershot/Dusk
# ═══════════════════════════════════════════════════════════════════════════
FROM base-full AS full-root

LABEL org.opencontainers.image.title="PHPeek PHP CLI 8.4 Alpine (Full)"
LABEL org.opencontainers.image.description="PHP CLI with all extensions including Chromium for browser testing"
LABEL org.opencontainers.image.vendor="PHPeek"
LABEL org.opencontainers.image.source="https://github.com/gophpeek/baseimages"

COPY php-cli/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-cli/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh && \
    mkdir -p /docker-entrypoint-init.d

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# ═══════════════════════════════════════════════════════════════════════════
# FULL-ROOTLESS VARIANT - Full with Chromium, no root privileges
# ═══════════════════════════════════════════════════════════════════════════
FROM base-full-rootless AS full-rootless

LABEL org.opencontainers.image.title="PHPeek PHP CLI 8.4 Alpine (Full Rootless)"
LABEL org.opencontainers.image.description="PHP CLI with all extensions including Chromium - Rootless"
LABEL org.opencontainers.image.vendor="PHPeek"
LABEL org.opencontainers.image.source="https://github.com/gophpeek/baseimages"

USER root
COPY php-cli/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-cli/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh
USER www-data

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
