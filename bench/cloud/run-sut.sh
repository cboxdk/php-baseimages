#!/usr/bin/env bash
# SUT scheduler: run each configuration for a fixed window, announce the
# current one on :8090/state.json. The client polls and measures :8080.
set -u
B="${CBOX_BENCH_DIR:-$HOME/cbox-bench}"
ST="$B/state"; mkdir -p "$ST"
WINDOW="${BENCH_WINDOW:-240}"
cd "$B"
( cd "$ST" && python3 -m http.server 8090 >/dev/null 2>&1 9>&- & ) || true
announce() { printf '{"name":"%s","phase":"%s","kind":"%s","ts":"%s"}\n' "$1" "$2" "$3" "$(date -u +%FT%TZ)" > "$ST/state.json.tmp" && mv "$ST/state.json.tmp" "$ST/state.json"; }
cp "$B/digests.txt" "$ST/" 2>/dev/null; cp "$B"/*.sha "$ST/" 2>/dev/null

run_slot() { # name kind image cpus mem mount extra...
  name="$1"; kind="$2"; img="$3"; cpus="$4"; mem="$5"; mnt="$6"; shift 6
  echo "== slot $name =="
  docker rm -f sut >/dev/null 2>&1
  docker run -d --name sut --cpus="$cpus" --memory="$mem" -p 8080:${PORT_OVERRIDE:-80} -v "$mnt" "$@" "$img" >/dev/null || { announce "$name" error "$kind"; return; }
  probe="/hello.php"; [ "$kind" = laravel ] && probe="/items"
  for i in $(seq 1 300); do curl -sf -o /dev/null "http://127.0.0.1:8080$probe" && break; sleep 0.5; done
  announce "$name" ready "$kind"
  sleep "$WINDOW"
  announce "$name" done "$kind"
  docker rm -f sut >/dev/null 2>&1
}

APP="$B/baseimages/bench/cloud/app"
LV="$B/lv-app"
SSU=serversideup/php:8.5-fpm-nginx

# Pass 3: validate the 1.6 defaults (otel unloaded) against SSU with the
# client-side rig. The tombstone mount over the otel ini reproduces exactly
# what the entrypoint gate ships (extension present on disk, not loaded).
NOOTEL="/dev/null:/usr/local/etc/php/conf.d/docker-php-ext-opentelemetry.ini:ro"
run_slot cbox16          micro cbox:pkg 2 1g "$APP:/var/www/html/public" -v "$NOOTEL"
run_slot cbox16-keep     micro cbox:pkg 2 1g "$APP:/var/www/html/public" -v "$NOOTEL" -e NGINX_FASTCGI_KEEP_CONN=on
PORT_OVERRIDE=8080 run_slot ssu-opc        micro "$SSU" 2 1g "$APP:/var/www/html/public" -e PHP_OPCACHE_ENABLE=1
run_slot cbox16-lv       laravel cbox:pkg 2 1g "$LV:/var/www/html" -v "$NOOTEL"
run_slot cbox16-keep-lv  laravel cbox:pkg 2 1g "$LV:/var/www/html" -v "$NOOTEL" -e NGINX_FASTCGI_KEEP_CONN=on
PORT_OVERRIDE=8080 run_slot ssu-opc-lv     laravel "$SSU" 2 1g "$LV:/var/www/html" -e PHP_OPCACHE_ENABLE=1
run_slot cbox16-8c       micro cbox:pkg 8 8g "$APP:/var/www/html/public" -v "$NOOTEL"
PORT_OVERRIDE=8080 run_slot ssu-opc-8c     micro "$SSU" 8 8g "$APP:/var/www/html/public" -e PHP_OPCACHE_ENABLE=1
run_slot cbox16-lv8c     laravel cbox:pkg 8 8g "$LV:/var/www/html" -v "$NOOTEL"
PORT_OVERRIDE=8080 run_slot ssu-opc-lv8c   laravel "$SSU" 8 8g "$LV:/var/www/html" -e PHP_OPCACHE_ENABLE=1
announce finished finished none
touch "$B/RUN_DONE"
echo "SUT-SCHEDULE-DONE"
