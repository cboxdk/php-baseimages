# ============================================================================
# Cbox PHP CLI Image - Debian (Bookworm)
# ============================================================================
# LAYER 3: Extends php-base with CLI-specific entrypoint and healthcheck
#
# IMAGE TIERS (inherited from php-base):
# - slim:     Minimal PHP + essential extensions - API/microservices
# - standard: + ImageMagick, vips, Node.js - Most Laravel apps (DEFAULT)
# - chromium: + Chromium for Browsershot/Dusk - PDF generation, testing
# - dev:      + Xdebug, PCOV, SPX for development/testing
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
# Import base images for each tier
# ============================================================================
FROM ghcr.io/cboxdk/php-baseimages/php-base:${PHP_VERSION}-bookworm-slim${BASE_CHANNEL} AS base-slim
FROM ghcr.io/cboxdk/php-baseimages/php-base:${PHP_VERSION}-bookworm-slim-rootless${BASE_CHANNEL} AS base-slim-rootless
FROM ghcr.io/cboxdk/php-baseimages/php-base:${PHP_VERSION}-bookworm${BASE_CHANNEL} AS base-standard
FROM ghcr.io/cboxdk/php-baseimages/php-base:${PHP_VERSION}-bookworm-rootless${BASE_CHANNEL} AS base-standard-rootless
FROM ghcr.io/cboxdk/php-baseimages/php-base:${PHP_VERSION}-bookworm-chromium${BASE_CHANNEL} AS base-chromium
FROM ghcr.io/cboxdk/php-baseimages/php-base:${PHP_VERSION}-bookworm-chromium-rootless${BASE_CHANNEL} AS base-chromium-rootless
FROM ghcr.io/cboxdk/php-baseimages/php-base:${PHP_VERSION}-bookworm-dev${BASE_CHANNEL} AS base-dev
FROM ghcr.io/cboxdk/php-baseimages/php-base:${PHP_VERSION}-bookworm-dev-rootless${BASE_CHANNEL} AS base-dev-rootless

# ═══════════════════════════════════════════════════════════════════════════
# SLIM-ROOT: Minimal PHP CLI with essential extensions
# ═══════════════════════════════════════════════════════════════════════════
FROM base-slim AS slim-root

ARG PHP_VERSION

LABEL org.opencontainers.image.title="Cbox PHP CLI ${PHP_VERSION} Bookworm (Slim)"
LABEL org.opencontainers.image.description="Minimal PHP CLI with essential extensions"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/php-baseimages"

ENV CBOX_IMAGE_TIER=slim

COPY php-cli/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
# Keep the shared lib in lockstep with the entrypoint that sources it
# (inheriting it from an older base layer = calling functions it lacks).
COPY common/lib/entrypoint-lib.sh /usr/local/lib/cbox/entrypoint-lib.sh
COPY php-cli/common/healthcheck.sh /usr/local/bin/healthcheck.sh
COPY php-cli/common/healthcheck-worker.sh /usr/local/bin/healthcheck-worker.sh
COPY php-cli/common/healthcheck-schedule.sh /usr/local/bin/healthcheck-schedule.sh
COPY php-cli/common/healthcheck-horizon.sh /usr/local/bin/healthcheck-horizon.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh /usr/local/bin/healthcheck-worker.sh /usr/local/bin/healthcheck-schedule.sh /usr/local/bin/healthcheck-horizon.sh && \
    mkdir -p /docker-entrypoint-init.d

RUN mkdir -p /etc/cbox-init
COPY php-cli/common/cbox-init.yaml /etc/cbox-init/cbox-init.yaml

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --start-interval=3s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# ═══════════════════════════════════════════════════════════════════════════
# SLIM-ROOTLESS: Minimal PHP CLI running as www-data
# ═══════════════════════════════════════════════════════════════════════════
FROM base-slim-rootless AS slim-rootless

ARG PHP_VERSION

LABEL org.opencontainers.image.title="Cbox PHP CLI ${PHP_VERSION} Bookworm (Slim Rootless)"
LABEL org.opencontainers.image.description="Minimal PHP CLI with essential extensions - Rootless"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/php-baseimages"

ENV CBOX_IMAGE_TIER=slim

USER root
COPY php-cli/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
# Keep the shared lib in lockstep with the entrypoint that sources it
# (inheriting it from an older base layer = calling functions it lacks).
COPY common/lib/entrypoint-lib.sh /usr/local/lib/cbox/entrypoint-lib.sh
COPY php-cli/common/healthcheck.sh /usr/local/bin/healthcheck.sh
COPY php-cli/common/healthcheck-worker.sh /usr/local/bin/healthcheck-worker.sh
COPY php-cli/common/healthcheck-schedule.sh /usr/local/bin/healthcheck-schedule.sh
COPY php-cli/common/healthcheck-horizon.sh /usr/local/bin/healthcheck-horizon.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh /usr/local/bin/healthcheck-worker.sh /usr/local/bin/healthcheck-schedule.sh /usr/local/bin/healthcheck-horizon.sh && \
    mkdir -p /docker-entrypoint-init.d && \
    chown -R www-data:www-data /docker-entrypoint-init.d
RUN mkdir -p /etc/cbox-init && chown -R www-data:www-data /etc/cbox-init
COPY php-cli/common/cbox-init-rootless.yaml /etc/cbox-init/cbox-init.yaml
USER www-data

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --start-interval=3s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# ═══════════════════════════════════════════════════════════════════════════
# ROOT (STANDARD): Default - ImageMagick, vips, Node.js
# ═══════════════════════════════════════════════════════════════════════════
FROM base-standard AS root

ARG PHP_VERSION

LABEL org.opencontainers.image.title="Cbox PHP CLI ${PHP_VERSION} Bookworm"
LABEL org.opencontainers.image.description="PHP CLI with ImageMagick, vips, Node.js, Composer, and Cbox Init"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/php-baseimages"

ENV CBOX_IMAGE_TIER=standard

COPY php-cli/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
# Keep the shared lib in lockstep with the entrypoint that sources it
# (inheriting it from an older base layer = calling functions it lacks).
COPY common/lib/entrypoint-lib.sh /usr/local/lib/cbox/entrypoint-lib.sh
COPY php-cli/common/healthcheck.sh /usr/local/bin/healthcheck.sh
COPY php-cli/common/healthcheck-worker.sh /usr/local/bin/healthcheck-worker.sh
COPY php-cli/common/healthcheck-schedule.sh /usr/local/bin/healthcheck-schedule.sh
COPY php-cli/common/healthcheck-horizon.sh /usr/local/bin/healthcheck-horizon.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh /usr/local/bin/healthcheck-worker.sh /usr/local/bin/healthcheck-schedule.sh /usr/local/bin/healthcheck-horizon.sh && \
    mkdir -p /docker-entrypoint-init.d

RUN mkdir -p /etc/cbox-init
COPY php-cli/common/cbox-init.yaml /etc/cbox-init/cbox-init.yaml

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --start-interval=3s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# ═══════════════════════════════════════════════════════════════════════════
# ROOTLESS (STANDARD): Default rootless - ImageMagick, vips, Node.js
# ═══════════════════════════════════════════════════════════════════════════
FROM base-standard-rootless AS rootless

ARG PHP_VERSION

LABEL org.opencontainers.image.title="Cbox PHP CLI ${PHP_VERSION} Bookworm (Rootless)"
LABEL org.opencontainers.image.description="PHP CLI with ImageMagick, vips, Node.js - Rootless"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/php-baseimages"

ENV CBOX_IMAGE_TIER=standard

USER root
COPY php-cli/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
# Keep the shared lib in lockstep with the entrypoint that sources it
# (inheriting it from an older base layer = calling functions it lacks).
COPY common/lib/entrypoint-lib.sh /usr/local/lib/cbox/entrypoint-lib.sh
COPY php-cli/common/healthcheck.sh /usr/local/bin/healthcheck.sh
COPY php-cli/common/healthcheck-worker.sh /usr/local/bin/healthcheck-worker.sh
COPY php-cli/common/healthcheck-schedule.sh /usr/local/bin/healthcheck-schedule.sh
COPY php-cli/common/healthcheck-horizon.sh /usr/local/bin/healthcheck-horizon.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh /usr/local/bin/healthcheck-worker.sh /usr/local/bin/healthcheck-schedule.sh /usr/local/bin/healthcheck-horizon.sh && \
    mkdir -p /docker-entrypoint-init.d && \
    chown -R www-data:www-data /docker-entrypoint-init.d
RUN mkdir -p /etc/cbox-init && chown -R www-data:www-data /etc/cbox-init
COPY php-cli/common/cbox-init-rootless.yaml /etc/cbox-init/cbox-init.yaml
USER www-data

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --start-interval=3s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# ═══════════════════════════════════════════════════════════════════════════
# CHROMIUM-ROOT: Everything including Chromium for Browsershot/Dusk
# ═══════════════════════════════════════════════════════════════════════════
FROM base-chromium AS chromium-root

ARG PHP_VERSION

LABEL org.opencontainers.image.title="Cbox PHP CLI ${PHP_VERSION} Bookworm (Chromium)"
LABEL org.opencontainers.image.description="PHP CLI with all features including Chromium for Browsershot/Dusk"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/php-baseimages"

ENV CBOX_IMAGE_TIER=chromium

COPY php-cli/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
# Keep the shared lib in lockstep with the entrypoint that sources it
# (inheriting it from an older base layer = calling functions it lacks).
COPY common/lib/entrypoint-lib.sh /usr/local/lib/cbox/entrypoint-lib.sh
COPY php-cli/common/healthcheck.sh /usr/local/bin/healthcheck.sh
COPY php-cli/common/healthcheck-worker.sh /usr/local/bin/healthcheck-worker.sh
COPY php-cli/common/healthcheck-schedule.sh /usr/local/bin/healthcheck-schedule.sh
COPY php-cli/common/healthcheck-horizon.sh /usr/local/bin/healthcheck-horizon.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh /usr/local/bin/healthcheck-worker.sh /usr/local/bin/healthcheck-schedule.sh /usr/local/bin/healthcheck-horizon.sh && \
    mkdir -p /docker-entrypoint-init.d

RUN mkdir -p /etc/cbox-init
COPY php-cli/common/cbox-init.yaml /etc/cbox-init/cbox-init.yaml

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --start-interval=3s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# ═══════════════════════════════════════════════════════════════════════════
# CHROMIUM-ROOTLESS: Everything including Chromium, running as www-data
# ═══════════════════════════════════════════════════════════════════════════
FROM base-chromium-rootless AS chromium-rootless

ARG PHP_VERSION

LABEL org.opencontainers.image.title="Cbox PHP CLI ${PHP_VERSION} Bookworm (Chromium Rootless)"
LABEL org.opencontainers.image.description="PHP CLI with all features including Chromium - Rootless"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/php-baseimages"

ENV CBOX_IMAGE_TIER=chromium

USER root
COPY php-cli/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
# Keep the shared lib in lockstep with the entrypoint that sources it
# (inheriting it from an older base layer = calling functions it lacks).
COPY common/lib/entrypoint-lib.sh /usr/local/lib/cbox/entrypoint-lib.sh
COPY php-cli/common/healthcheck.sh /usr/local/bin/healthcheck.sh
COPY php-cli/common/healthcheck-worker.sh /usr/local/bin/healthcheck-worker.sh
COPY php-cli/common/healthcheck-schedule.sh /usr/local/bin/healthcheck-schedule.sh
COPY php-cli/common/healthcheck-horizon.sh /usr/local/bin/healthcheck-horizon.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh /usr/local/bin/healthcheck-worker.sh /usr/local/bin/healthcheck-schedule.sh /usr/local/bin/healthcheck-horizon.sh && \
    mkdir -p /docker-entrypoint-init.d && \
    chown -R www-data:www-data /docker-entrypoint-init.d
RUN mkdir -p /etc/cbox-init && chown -R www-data:www-data /etc/cbox-init
COPY php-cli/common/cbox-init-rootless.yaml /etc/cbox-init/cbox-init.yaml
USER www-data

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --start-interval=3s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# ═══════════════════════════════════════════════════════════════════════════
# DEV-ROOT: Chromium + Xdebug, PCOV, SPX for development/testing
# ═══════════════════════════════════════════════════════════════════════════
FROM base-dev AS dev-root

ARG PHP_VERSION

LABEL org.opencontainers.image.title="Cbox PHP CLI ${PHP_VERSION} Bookworm (Dev)"
LABEL org.opencontainers.image.description="PHP CLI with Xdebug, PCOV, SPX for development and testing"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/php-baseimages"

ENV CBOX_IMAGE_TIER=dev

COPY php-cli/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
# Keep the shared lib in lockstep with the entrypoint that sources it
# (inheriting it from an older base layer = calling functions it lacks).
COPY common/lib/entrypoint-lib.sh /usr/local/lib/cbox/entrypoint-lib.sh
COPY php-cli/common/healthcheck.sh /usr/local/bin/healthcheck.sh
COPY php-cli/common/healthcheck-worker.sh /usr/local/bin/healthcheck-worker.sh
COPY php-cli/common/healthcheck-schedule.sh /usr/local/bin/healthcheck-schedule.sh
COPY php-cli/common/healthcheck-horizon.sh /usr/local/bin/healthcheck-horizon.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh /usr/local/bin/healthcheck-worker.sh /usr/local/bin/healthcheck-schedule.sh /usr/local/bin/healthcheck-horizon.sh && \
    mkdir -p /docker-entrypoint-init.d

RUN mkdir -p /etc/cbox-init
COPY php-cli/common/cbox-init.yaml /etc/cbox-init/cbox-init.yaml

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --start-interval=3s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# ═══════════════════════════════════════════════════════════════════════════
# DEV-ROOTLESS: Chromium + Xdebug, PCOV, SPX, running as www-data
# ═══════════════════════════════════════════════════════════════════════════
FROM base-dev-rootless AS dev-rootless

ARG PHP_VERSION

LABEL org.opencontainers.image.title="Cbox PHP CLI ${PHP_VERSION} Bookworm (Dev Rootless)"
LABEL org.opencontainers.image.description="PHP CLI with Xdebug, PCOV, SPX - Rootless"
LABEL org.opencontainers.image.vendor="Cbox"
LABEL org.opencontainers.image.source="https://github.com/cboxdk/php-baseimages"

ENV CBOX_IMAGE_TIER=dev

USER root
COPY php-cli/common/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
# Keep the shared lib in lockstep with the entrypoint that sources it
# (inheriting it from an older base layer = calling functions it lacks).
COPY common/lib/entrypoint-lib.sh /usr/local/lib/cbox/entrypoint-lib.sh
COPY php-cli/common/healthcheck.sh /usr/local/bin/healthcheck.sh
COPY php-cli/common/healthcheck-worker.sh /usr/local/bin/healthcheck-worker.sh
COPY php-cli/common/healthcheck-schedule.sh /usr/local/bin/healthcheck-schedule.sh
COPY php-cli/common/healthcheck-horizon.sh /usr/local/bin/healthcheck-horizon.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh /usr/local/bin/healthcheck-worker.sh /usr/local/bin/healthcheck-schedule.sh /usr/local/bin/healthcheck-horizon.sh && \
    mkdir -p /docker-entrypoint-init.d && \
    chown -R www-data:www-data /docker-entrypoint-init.d
RUN mkdir -p /etc/cbox-init && chown -R www-data:www-data /etc/cbox-init
COPY php-cli/common/cbox-init-rootless.yaml /etc/cbox-init/cbox-init.yaml
USER www-data

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --start-interval=3s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
