# ============================================================================
# PHPeek PHP CLI Image - Debian 8.3
# ============================================================================
# LAYER 3: Extends php-base with CLI-specific entrypoint and healthcheck
# ============================================================================

FROM ghcr.io/phpeek/baseimages/php-base:8.3-debian

LABEL org.opencontainers.image.title="PHPeek PHP CLI 8.3 Debian"
LABEL org.opencontainers.image.description="PHP CLI with all extensions, Composer, Node.js, and PHPeek PM"
LABEL org.opencontainers.image.vendor="PHPeek"
LABEL org.opencontainers.image.source="https://github.com/phpeek/baseimages"

COPY php-cli/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-cli/common/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh && \
    mkdir -p /docker-entrypoint-init.d

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
