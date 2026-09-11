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

# Pass 2: variance repeats of the key pairs + variants that isolate WHY the
# lv slots lost pass 1 (JIT? fastcgi TCP connect? worker count?). Field images
# (webdevops/trafex/apache/frankenphp/v151) keep their pass-1 numbers.
NOJIT="$B/baseimages/bench/cloud/overrides/zz-nojit.ini:/usr/local/etc/php/conf.d/zz-nojit.ini:ro"
# ── micro @2c ──
run_slot cbox-pkg        micro cbox:pkg 2 1g "$APP:/var/www/html/public"
run_slot cbox-pkg-keep   micro cbox:pkg 2 1g "$APP:/var/www/html/public" -e NGINX_FASTCGI_KEEP_CONN=on
PORT_OVERRIDE=8080 run_slot ssu-opc        micro "$SSU" 2 1g "$APP:/var/www/html/public" -e PHP_OPCACHE_ENABLE=1
# ── laravel @2c: the diagnostic block ──
run_slot cbox-pkg-lv     laravel cbox:pkg 2 1g "$LV:/var/www/html"
run_slot cbox-keep-lv    laravel cbox:pkg 2 1g "$LV:/var/www/html" -e NGINX_FASTCGI_KEEP_CONN=on
run_slot cbox-w20-lv     laravel cbox:pkg 2 1g "$LV:/var/www/html" -e PHP_FPM_MAX_CHILDREN=20
run_slot cbox-nojit-lv   laravel cbox:pkg 2 1g "$LV:/var/www/html" -v "$NOJIT"
run_slot cbox-all-lv     laravel cbox:pkg 2 1g "$LV:/var/www/html" -e NGINX_FASTCGI_KEEP_CONN=on -e PHP_FPM_MAX_CHILDREN=20 -v "$NOJIT"
PORT_OVERRIDE=8080 run_slot ssu-opc-lv     laravel "$SSU" 2 1g "$LV:/var/www/html" -e PHP_OPCACHE_ENABLE=1
# ── 8c round ──
run_slot cbox-pkg-8c     micro cbox:pkg 8 8g "$APP:/var/www/html/public"
run_slot cbox-keep-8c    micro cbox:pkg 8 8g "$APP:/var/www/html/public" -e NGINX_FASTCGI_KEEP_CONN=on
PORT_OVERRIDE=8080 run_slot ssu-opc-8c     micro "$SSU" 8 8g "$APP:/var/www/html/public" -e PHP_OPCACHE_ENABLE=1
# ── laravel @8c (both have 20 workers here, so w20 is moot; JIT and connect are not) ──
run_slot cbox-pkg-lv8c   laravel cbox:pkg 8 8g "$LV:/var/www/html"
run_slot cbox-nojit-lv8c laravel cbox:pkg 8 8g "$LV:/var/www/html" -v "$NOJIT"
run_slot cbox-keep-lv8c  laravel cbox:pkg 8 8g "$LV:/var/www/html" -e NGINX_FASTCGI_KEEP_CONN=on
run_slot cbox-kn-lv8c    laravel cbox:pkg 8 8g "$LV:/var/www/html" -e NGINX_FASTCGI_KEEP_CONN=on -v "$NOJIT"
PORT_OVERRIDE=8080 run_slot ssu-opc-lv8c   laravel "$SSU" 8 8g "$LV:/var/www/html" -e PHP_OPCACHE_ENABLE=1
announce finished finished none
touch "$B/RUN_DONE"
echo "SUT-SCHEDULE-DONE"
