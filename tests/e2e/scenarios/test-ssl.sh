#!/bin/bash
# E2E Test: SSL_MODE actually boots, and serves over TLS
#
# What this guards:
#
#   #55  SSL_MODE=on made the container fail to start outright. The generated
#        HTTPS server used the standalone `http2 on;` directive, which nginx
#        only learned in 1.25.1, while the image ships Debian bookworm's 1.22.1:
#
#            [emerg] unknown directive "http2" in .../default.conf:432
#
#        Nothing booted with TLS enabled, on any tier, and no test covered it -
#        every other scenario runs plain HTTP. The entrypoint now picks the form
#        from `nginx -v`, so bookworm gets `listen ... ssl http2` and a future
#        trixie base (nginx 1.26+, where the listen parameter is deprecated)
#        gets the directive. This test is the thing that would have caught it:
#        it boots with TLS and fetches a page over it.
#
# Deliberately asserts the BOOT, not just the config text. A config-only check
# would have passed the broken version too, because the template is rendered at
# startup and only nginx itself rejects the directive.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-utils.sh"

IMAGE="${IMAGE:-ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.5-bookworm-v1}"
TMP_ROOT="$(mktemp -d)"
CONTAINERS=""

do_cleanup() {
    for c in $CONTAINERS; do docker rm -f "$c" >/dev/null 2>&1 || true; done
    rm -rf "$TMP_ROOT" 2>/dev/null || true
    return 0
}

make_cert() {
    openssl req -x509 -newkey rsa:2048 -nodes -days 2 \
        -subj /CN=localhost \
        -keyout "$TMP_ROOT/key.pem" -out "$TMP_ROOT/cert.pem" >/dev/null 2>&1
    chmod 644 "$TMP_ROOT/key.pem" "$TMP_ROOT/cert.pem"
}

make_app() {
    mkdir -p "$TMP_ROOT/app/public"
    printf '<?php echo "tls-ok";' > "$TMP_ROOT/app/public/index.php"
}

start_container() {
    local name="$1"; shift
    docker rm -f "$name" >/dev/null 2>&1 || true
    CONTAINERS="$CONTAINERS $name"
    docker run -d --name "$name" "$@" "$IMAGE" >/dev/null
}

# A container that dies on a bad directive never writes /tmp/cbox-ready, so
# readiness IS the assertion here. Report the nginx error when it fails, since
# that is the whole point of the test.
wait_for_ready() {
    local name="$1" timeout="${2:-90}" elapsed=0
    while [ "$elapsed" -lt "$timeout" ]; do
        if [ "$(docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null || true)" != "true" ]; then
            log_fail "$name exited instead of starting with TLS"
            docker logs "$name" 2>&1 | grep -iE "emerg|unknown directive|invalid|error" | head -5
            return 1
        fi
        if docker exec "$name" test -f /tmp/cbox-ready 2>/dev/null; then return 0; fi
        sleep 2; elapsed=$((elapsed + 2))
    done
    log_fail "$name did not become ready within ${timeout}s"
    docker logs "$name" 2>&1 | tail -20
    return 1
}

log_section "SSL / TLS E2E Test"
echo "  Image: $IMAGE"
make_cert
make_app

# ═══════════════════════════════════════════════════════════════════════════
# TEST 1 (#55): SSL_MODE=on boots and serves HTTPS
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 1: SSL_MODE=on starts and serves over TLS (#55)"

start_container e2e-ssl-on \
    -e SSL_MODE=on \
    -e SSL_CERTIFICATE_FILE=/certs/cert.pem \
    -e SSL_PRIVATE_KEY_FILE=/certs/key.pem \
    -p 18443:443 -p 18080:80 \
    -v "$TMP_ROOT/app:/var/www/html" \
    -v "$TMP_ROOT:/certs:ro"

if wait_for_ready e2e-ssl-on; then
    log_success "container started with SSL_MODE=on (the #55 regression)"

    BODY="$(curl -fsSk --max-time 15 https://localhost:18443/ 2>/dev/null || true)"
    if [ "$BODY" = "tls-ok" ]; then
        log_success "served the app over TLS"
    else
        log_fail "TLS fetch returned '${BODY:0:60}', expected tls-ok"
    fi

    # nginx must not merely have started - the directive it chose has to be the
    # one this nginx understands. Assert the rendered config matches the binary.
    NGV="$(docker exec e2e-ssl-on nginx -v 2>&1 | sed -n 's|.*nginx/\([0-9][0-9.]*\).*|\1|p')"
    CONF="$(docker exec e2e-ssl-on cat /etc/nginx/conf.d/default.conf 2>/dev/null || true)"
    if [ "$(printf '%s\n' "1.25.1" "$NGV" | sort -V | head -1)" = "1.25.1" ]; then
        if printf '%s' "$CONF" | grep -qE '^\s*http2 on;'; then
            log_success "nginx $NGV uses the standalone http2 directive"
        else
            log_fail "nginx $NGV should use 'http2 on;' but the config does not"
        fi
    else
        if printf '%s' "$CONF" | grep -qE 'listen .*ssl .*http2'; then
            log_success "nginx $NGV uses the listen http2 parameter"
        else
            log_fail "nginx $NGV needs 'listen ... ssl http2' but the config does not have it"
        fi
        if printf '%s' "$CONF" | grep -qE '^\s*http2 on;'; then
            log_fail "nginx $NGV cannot parse a standalone 'http2 on;' - it is in the config"
        else
            log_success "no standalone http2 directive emitted for nginx $NGV"
        fi
    fi

    assert_http_code "http://localhost:18080/" 200 "plain HTTP still answers alongside TLS"
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 2 (#55): SSL_MODE=full boots too, and redirects HTTP
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 2: SSL_MODE=full starts and redirects HTTP to HTTPS (#55)"

start_container e2e-ssl-full \
    -e SSL_MODE=full \
    -e SSL_CERTIFICATE_FILE=/certs/cert.pem \
    -e SSL_PRIVATE_KEY_FILE=/certs/key.pem \
    -p 18444:443 -p 18081:80 \
    -v "$TMP_ROOT/app:/var/www/html" \
    -v "$TMP_ROOT:/certs:ro"

if wait_for_ready e2e-ssl-full; then
    log_success "container started with SSL_MODE=full"

    BODY="$(curl -fsSk --max-time 15 https://localhost:18444/ 2>/dev/null || true)"
    if [ "$BODY" = "tls-ok" ]; then
        log_success "served the app over TLS"
    else
        log_fail "TLS fetch returned '${BODY:0:60}', expected tls-ok"
    fi

    CODE="$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 http://localhost:18081/ 2>/dev/null || true)"
    case "$CODE" in
        30[1278]) log_success "plain HTTP redirects ($CODE)" ;;
        *)        log_fail "plain HTTP returned $CODE, expected a 3xx redirect" ;;
    esac
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 3: SSL_MODE=off is the default and emits no TLS server
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 3: no TLS server when SSL_MODE is unset"

start_container e2e-ssl-off \
    -p 18082:80 \
    -v "$TMP_ROOT/app:/var/www/html"

if wait_for_ready e2e-ssl-off; then
    CONF="$(docker exec e2e-ssl-off cat /etc/nginx/conf.d/default.conf 2>/dev/null || true)"
    if printf '%s' "$CONF" | grep -qE 'ssl_certificate '; then
        log_fail "a TLS server was rendered without SSL_MODE"
    else
        log_success "no TLS server rendered by default"
    fi
    assert_http_code "http://localhost:18082/" 200 "plain HTTP serves the app"
fi

FINAL_FAILED=$TESTS_FAILED
print_summary 2>/dev/null || true
( set +euo pipefail; do_cleanup 2>/dev/null ) || true
[ "$FINAL_FAILED" -gt 0 ] && exit 1
exit 0
