# syntax=docker/dockerfile:1
# Template Dockerfile for a PHP/Laravel/Statamic site on the cbox base image.
# Copy into a site's app repo (or build context) and adjust PHP version/tier.

# ---- build stage: composer + frontend (vite) ----
# Runs on the BUILD host's native arch (e.g. arm64 on Apple Silicon) so composer
# and vite aren't emulated. vendor/ and public/build are arch-independent, so the
# amd64 runtime image below just COPYs them — no cross-emulation needed.
FROM --platform=$BUILDPLATFORM ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.5-bookworm-audit1 AS build
WORKDIR /var/www/html

# PHP deps first (better layer caching). auth.json (Statamic license / private
# repos) is injected as a build secret, not baked into the image.
COPY composer.json composer.lock ./
RUN --mount=type=secret,id=composer_auth,target=/var/www/html/auth.json \
    composer install --no-dev --no-scripts --prefer-dist --no-interaction --no-progress --optimize-autoloader

# Frontend build (Node 22 ships in the standard tier).
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
# Only the frontend build here — do NOT run artisan/composer scripts at build time
# (no app env yet). The base image entrypoint runs package:discover + caching at
# container start. Autoloader was already optimised in the composer install above.
RUN npm run build && rm -rf node_modules auth.json

# ---- runtime image ----
FROM ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.5-bookworm-audit1
WORKDIR /var/www/html
COPY --from=build --chown=www-data:www-data /var/www/html /var/www/html

# Runtime-mutable dirs are mounted from the PVC at deploy time (content,
# public/assets, storage/forms, storage/app). Everything else is immutable.
ENV APP_ENV=production \
    PHP_OPCACHE_ENABLE=1
