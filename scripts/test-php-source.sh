#!/usr/bin/env bash
# Local only: no registry login, push, remote builder, or workflow dispatch.
set -euo pipefail
cd "$(dirname "$0")/.."
DOCKER_CONTEXT="${DOCKER_CONTEXT:-orbstack}"
PLATFORM="${PLATFORM:-linux/arm64}"
SERIES="${1:-8.5}"
VERSION=$(python3 scripts/php-source.py --series "$SERIES" version)
ARCH=${PLATFORM#linux/}
BUILD_DIR=".build/php-source/${SERIES}/${ARCH}"
PREFIX="cbox-php-source:${VERSION}-${ARCH}"
mkdir -p "$BUILD_DIR"
for variant in cli fpm; do
    python3 scripts/php-source.py --series "$SERIES" render "$variant" --output "${BUILD_DIR}/${variant}.Dockerfile"
    docker --context "$DOCKER_CONTEXT" build --platform "$PLATFORM" \
        -f "${BUILD_DIR}/${variant}.Dockerfile" -t "${PREFIX}-${variant}" .
    actual=$(docker --context "$DOCKER_CONTEXT" run --rm --platform "$PLATFORM" "${PREFIX}-${variant}" php -r 'echo PHP_VERSION;')
    test "$actual" = "$VERSION"
done
# Compile using CLI headers, then load the exact module in FPM, like production.
cat > "${BUILD_DIR}/smoke.Dockerfile" <<'DOCKERFILE'
ARG CLI_IMAGE=cbox-php-source:local-cli
ARG FPM_IMAGE=cbox-php-source:local-fpm
FROM ${CLI_IMAGE} AS extension
RUN docker-php-ext-install bcmath && php -r 'exit(bcadd("1", "2") === "3" ? 0 : 1);'
FROM ${FPM_IMAGE}
COPY --from=extension /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
RUN docker-php-ext-enable bcmath && php-fpm -tt
RUN printf '%s\n' '<?php echo PHP_VERSION, ":", bcadd("1", "2");' > /var/www/html/source-smoke.php
DOCKERFILE
docker --context "$DOCKER_CONTEXT" build --platform "$PLATFORM" \
    --build-arg "CLI_IMAGE=${PREFIX}-cli" --build-arg "FPM_IMAGE=${PREFIX}-fpm" \
    -f "${BUILD_DIR}/smoke.Dockerfile" -t "${PREFIX}-smoke" .
CONTAINER=$(docker --context "$DOCKER_CONTEXT" run -d --platform "$PLATFORM" -p 127.0.0.1::9000 "${PREFIX}-smoke")
trap 'docker --context "$DOCKER_CONTEXT" rm -f "$CONTAINER" >/dev/null' EXIT
PORT=$(docker --context "$DOCKER_CONTEXT" port "$CONTAINER" 9000/tcp)
python3 tests/php-source-fastcgi.py "${PORT##*:}" "$VERSION"
