#!/usr/bin/env bash
# SUT bootstrap: build the package image from source (baseimages@main +
# cbox-init@main injected), pull competitors, then run the schedule announced
# on :8090 while serving containers on :8080. Idempotent via lock.
set -euo pipefail
# mkdir BEFORE the exec redirect: a failing exec-redirect exits the script,
# so on a virgin box the old order died before it could create the dir.
sudo mkdir -p /opt/cbox-bench && sudo chown "$(id -u)" /opt/cbox-bench
exec >>/opt/cbox-bench/bootstrap.log 2>&1
# One full schedule per box: without this marker the cron restarts the whole
# run (rebuild included) the minute the first one finishes.
[ -f /opt/cbox-bench/RUN_DONE ] && exit 0
exec 9>/opt/cbox-bench/lock; flock -n 9 || exit 0
echo "== bootstrap $(date -u) =="
cd /opt/cbox-bench

command -v git >/dev/null || sudo apt-get install -y -qq git
[ -d baseimages ] || git clone --depth 1 https://github.com/cboxdk/php-baseimages baseimages
[ -d init ] || git clone --depth 1 https://github.com/cboxdk/init init
( cd baseimages && git pull -q ); ( cd init && git pull -q )

# Go toolchain for cbox-init (toolchain directive fetches the right version)
if ! command -v go >/dev/null; then sudo apt-get install -y -qq golang-go; fi
( cd init && GOTOOLCHAIN=auto CGO_ENABLED=0 go build -o /opt/cbox-bench/cbox-init ./cmd/cbox-init )
/opt/cbox-bench/cbox-init --version

# Build the package image: baseimages@main with the freshly built init
cd baseimages
cp /opt/cbox-bench/cbox-init cbox-init/binaries/cbox-init-linux-amd64
cp /opt/cbox-bench/cbox-init cbox-init/binaries/cbox-init-linux-arm64  # unused on amd64
printf '%s' "$( (cd . && git rev-parse HEAD) )" > /opt/cbox-bench/baseimages.sha
printf '%s' "$( (cd ../init && git rev-parse HEAD) )" > /opt/cbox-bench/init.sha
docker build -q -f php-fpm-nginx/Dockerfile --target root --build-arg PHP_VERSION=8.5 -t cbox:pkg .
cd /opt/cbox-bench

# Competitors, as shipped
for img in "serversideup/php:8.5-fpm-nginx" "webdevops/php-nginx:8.5" "trafex/php-nginx:latest" \
           "php:8.5-apache-bookworm" "dunglas/frankenphp:php8.5-bookworm" \
           "ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.5-bookworm-v1"; do
  docker pull -q "$img"
done
docker images --digests --format '{{.Repository}}:{{.Tag}}@{{.Digest}}' > /opt/cbox-bench/digests.txt

# Fixtures live in the repo at baseimages/bench/cloud/app (run-sut points there).
# The Laravel fixture is built once via composer inside the php-cli image.
if [ ! -d /opt/cbox-bench/lv-app/vendor ]; then
  docker pull -q ghcr.io/cboxdk/php-baseimages/php-cli:8.5-bookworm-v1
  bash baseimages/bench/cloud/build-laravel-fixture.sh
fi
bash baseimages/bench/cloud/run-sut.sh &
echo "run-sut started"
