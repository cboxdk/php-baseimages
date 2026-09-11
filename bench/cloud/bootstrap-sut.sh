#!/usr/bin/env bash
# SUT bootstrap: build the package image from source (baseimages@main +
# cbox-init@main injected), pull competitors, then run the schedule announced
# on :8090 while serving containers on :8080. Idempotent via lock.
set -euo pipefail
# mkdir BEFORE the exec redirect: a failing exec-redirect exits the script,
# so on a virgin box the old order died before it could create the dir.
mkdir -p "$HOME/cbox-bench"
exec >>$HOME/cbox-bench/bootstrap.log 2>&1
# One full schedule per box: without this marker the cron restarts the whole
# run (rebuild included) the minute the first one finishes.
[ -f $HOME/cbox-bench/RUN_DONE ] && exit 0
exec 9>$HOME/cbox-bench/lock; flock -n 9 || exit 0
echo "== bootstrap $(date -u) =="
cd $HOME/cbox-bench
# State endpoint FIRST, so progress and failures are observable from outside
# (there is no ssh in this rig - the endpoint IS the diagnostics channel).
mkdir -p state
announce() { printf '{"name":"%s","phase":"%s","kind":"none","ts":"%s"}
' "$1" "$2" "$(date -u +%FT%TZ)" > state/state.json.tmp && mv state/state.json.tmp state/state.json; }
pgrep -f "http.server 8090" >/dev/null || ( cd state && nohup python3 -m http.server 8090 >/dev/null 2>&1 & )
announce bootstrap bootstrapping
trap 'announce bootstrap failed; cp bootstrap.log state/bootstrap.log 2>/dev/null' ERR

command -v git >/dev/null || { echo "git mangler"; exit 1; }
[ -d baseimages ] || git clone --depth 1 https://github.com/cboxdk/php-baseimages baseimages
[ -d init ] || git clone --depth 1 https://github.com/cboxdk/init init
( cd baseimages && git pull -q ); ( cd init && git pull -q )

# Go build inside a container: no sudo, no host toolchain (the ploi user has
# no passwordless sudo on Ploi docker-servers - learned the silent way)
announce building-init bootstrapping
docker run --rm -v "$HOME/cbox-bench/init:/src" -w /src -e CGO_ENABLED=0 -e GOFLAGS=-buildvcs=false golang:1.26 go build -o /src/cbox-init-built ./cmd/cbox-init
cp init/cbox-init-built "$HOME/cbox-bench/cbox-init" && chmod +x "$HOME/cbox-bench/cbox-init"
"$HOME/cbox-bench/cbox-init" --version

# Build the package image: baseimages@main with the freshly built init
cd baseimages
cp $HOME/cbox-bench/cbox-init cbox-init/binaries/cbox-init-linux-amd64
cp $HOME/cbox-bench/cbox-init cbox-init/binaries/cbox-init-linux-arm64  # unused on amd64
printf '%s' "$( (cd . && git rev-parse HEAD) )" > $HOME/cbox-bench/baseimages.sha
printf '%s' "$( (cd ../init && git rev-parse HEAD) )" > $HOME/cbox-bench/init.sha
announce building-image bootstrapping 2>/dev/null || true
docker build -q -f php-fpm-nginx/Dockerfile --target root --build-arg PHP_VERSION=8.5 -t cbox:pkg .
cd $HOME/cbox-bench

# Competitors, as shipped
announce pulling-competitors bootstrapping
for img in "serversideup/php:8.5-fpm-nginx" "webdevops/php-nginx:8.5" "trafex/php-nginx:latest" \
           "php:8.5-apache-bookworm" "dunglas/frankenphp:php8.5-bookworm" \
           "ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.5-bookworm-v1"; do
  docker pull -q "$img"
done
docker images --digests --format '{{.Repository}}:{{.Tag}}@{{.Digest}}' > $HOME/cbox-bench/digests.txt

# Fixtures live in the repo at baseimages/bench/cloud/app (run-sut points there).
# The Laravel fixture is built once via composer inside the php-cli image.
if [ ! -d $HOME/cbox-bench/lv-app/vendor ]; then
  docker pull -q ghcr.io/cboxdk/php-baseimages/php-cli:8.5-bookworm-v1
  bash baseimages/bench/cloud/build-laravel-fixture.sh
fi
bash baseimages/bench/cloud/run-sut.sh &
echo "run-sut started"
