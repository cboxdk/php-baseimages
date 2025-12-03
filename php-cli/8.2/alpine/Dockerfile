# ============================================================================
# PHPeek PHP CLI Image - Alpine 8.2
# ============================================================================
# LAYER 3: Extends php-base with CLI-specific entrypoint and healthcheck
# ============================================================================

# Import both variants from php-base
FROM ghcr.io/gophpeek/baseimages/php-base:8.2-alpine AS base-root
FROM ghcr.io/gophpeek/baseimages/php-base:8.2-alpine-rootless AS base-rootless

# ═══════════════════════════════════════════════════════════════════════════
# ROOT VARIANT (default) - Runs as root, PUID/PGID mapping at runtime
# ═══════════════════════════════════════════════════════════════════════════
FROM base-root AS root

LABEL org.opencontainers.image.title="PHPeek PHP CLI 8.2 Alpine"
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
# ROOTLESS VARIANT - Runs entirely as www-data, no root privileges
# ═══════════════════════════════════════════════════════════════════════════
FROM base-rootless AS rootless

LABEL org.opencontainers.image.title="PHPeek PHP CLI 8.2 Alpine (Rootless)"
LABEL org.opencontainers.image.description="PHP CLI with all extensions, Composer, Node.js, and PHPeek PM - Rootless"
LABEL org.opencontainers.image.vendor="PHPeek"
LABEL org.opencontainers.image.source="https://github.com/gophpeek/baseimages"

# Copy as root temporarily for permissions
USER root
COPY php-cli/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-cli/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh
USER www-data

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
