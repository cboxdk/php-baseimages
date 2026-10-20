#!/bin/bash
# E2E Test: nginx template contract for release-based deploys and app hooks
#
# What this guards:
#
#   #38  SCRIPT_FILENAME/DOCUMENT_ROOT came from $document_root, so on a
#        symlink-release layout PHP resolved every include through the symlink
#        and opcache (validate_timestamps=0 in production) kept serving the
#        PREVIOUS release after a swap until FPM was reloaded. The decisive
#        case is below: swap the symlink, change nothing else, and the next
#        request must come from the new release.
#   #40  Apps needed locations in front of PHP - a full-page cache, a redirect
#        map - and the only way to get them was to replace the whole template.
#        /etc/nginx/server.d/*.conf is the hook, and STATAMIC_STATIC_CACHING
#        is the preset for the case that drove the request.
#
# The #37 vendor/ rules live in test-security.sh, next to the other deny rules.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-utils.sh"

E2E_ROOT="$(get_e2e_root)"
FIXTURE_DIR="$E2E_ROOT/fixtures/nginx-template"
IMAGE="${IMAGE:-ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.5-bookworm-v1}"

TMP_ROOT="$(mktemp -d)"
CONTAINERS=""

do_cleanup() {
    for c in $CONTAINERS; do
        docker rm -f "$c" >/dev/null 2>&1 || true
    done
    rm -rf "$TMP_ROOT" 2>/dev/null || true
    return 0
}

# Two releases and a `current` symlink pointing at the first - the
# Envoyer/Forge/Deployer layout, built for real so the symlink is a symlink.
make_release_tree() {
    local root="$TMP_ROOT/$1"
    for r in r1 r2; do
        mkdir -p "$root/releases/$r/public/static" "$root/releases/$r/storage/logs"
        cp "$FIXTURE_DIR/app/artisan" "$root/releases/$r/artisan"
        sed "s/@@RELEASE@@/$r/g" "$FIXTURE_DIR/app/public/index.php" \
            > "$root/releases/$r/public/index.php"
        printf '<html>static %s home</html>' "$r" > "$root/releases/$r/public/static/_.html"
        printf '<html>static %s about</html>' "$r" > "$root/releases/$r/public/static/about_.html"
    done
    ln -sfn releases/r1 "$root/current"
    echo "$root"
}

start_container() {
    local name="$1"
    shift
    docker rm -f "$name" >/dev/null 2>&1 || true
    CONTAINERS="$CONTAINERS $name"
    docker run -d --name "$name" "$@" "$IMAGE" >/dev/null
}

wait_for_ready() {
    local name="$1" timeout="${2:-90}" elapsed=0
    while [ "$elapsed" -lt "$timeout" ]; do
        if [ "$(docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null || true)" != "true" ]; then
            log_fail "$name exited before becoming ready"
            docker logs "$name" 2>&1 | tail -30
            return 1
        fi
        if docker exec "$name" test -f /tmp/cbox-ready 2>/dev/null; then
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done
    log_fail "$name did not become ready within ${timeout}s"
    docker logs "$name" 2>&1 | tail -30
    return 1
}

# One JSON field out of the fixture's index.php. json_encode escapes forward
# slashes, so every path comes back as \/app\/... - unescape it.
probe() {
    curl -fsS "$1" 2>/dev/null \
        | sed -n "s/.*\"$2\":\"\([^\"]*\)\".*/\1/p" \
        | sed 's#\\/#/#g' || true
}

log_section "Nginx Template E2E Test"
echo "  Image: $IMAGE"

# ═══════════════════════════════════════════════════════════════════════════
# TEST 1 (#38): the fastcgi root is the release, not the symlink
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 1: \$realpath_root by default (#38)"

TREE1="$(make_release_tree realpath)"
start_container e2e-nginxtpl-realpath \
    -e WORKDIR=/app/current -e NGINX_WEBROOT=/app/current/public \
    -e PHP_OPCACHE_VALIDATE_TIMESTAMPS=0 \
    -p 18110:80 \
    -v "$TREE1:/app"

if wait_for_ready e2e-nginxtpl-realpath; then
    DOCROOT="$(probe http://localhost:18110/ document_root)"
    if [ "$DOCROOT" = "/app/releases/r1/public" ]; then
        log_success "DOCUMENT_ROOT is the release path ($DOCROOT)"
    else
        log_fail "DOCUMENT_ROOT is '$DOCROOT', expected /app/releases/r1/public"
    fi

    SCRIPT="$(probe http://localhost:18110/ script_filename)"
    case "$SCRIPT" in
        /app/releases/r1/public/index.php)
            log_success "SCRIPT_FILENAME is the release path ($SCRIPT)"
            ;;
        *)
            log_fail "SCRIPT_FILENAME is '$SCRIPT', expected /app/releases/r1/public/index.php"
            ;;
    esac

    # fastcgi_params also defines DOCUMENT_ROOT; of two definitions of one
    # param the LAST reaches PHP, which is why the override sits after the
    # include. Getting that order wrong is silent, so assert HTTP_HOST too -
    # it is overridden the same way and would break with it.
    HOST="$(curl -fsS -H 'Host: app.cbox.test' -H 'X-Forwarded-Proto: https' \
        -H 'X-Forwarded-Port: 18443' http://localhost:18110/ 2>/dev/null \
        | sed -n 's/.*"http_host":"\([^"]*\)".*/\1/p' || true)"
    if [ "$HOST" = "app.cbox.test:18443" ]; then
        log_success "HTTP_HOST still carries the forwarded port ($HOST)"
    else
        log_fail "HTTP_HOST is '$HOST', expected app.cbox.test:18443"
    fi

    # THE case. No FPM reload, no cache flush: just the swap.
    ln -sfn releases/r2 "$TREE1/current"
    sleep 1
    RELEASE="$(probe http://localhost:18110/ release)"
    if [ "$RELEASE" = "r2" ]; then
        log_success "a release swap takes effect on the next request (served $RELEASE)"
    else
        log_fail "still serving '$RELEASE' after the swap, expected r2 (the #38 regression)"
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 2 (#38): the switch still turns it off
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 2: NGINX_USE_REALPATH_ROOT=false restores \$document_root (#38)"

start_container e2e-nginxtpl-docroot \
    -e WORKDIR=/app/current -e NGINX_WEBROOT=/app/current/public \
    -e NGINX_USE_REALPATH_ROOT=false \
    -p 18111:80 \
    -v "$(make_release_tree docroot):/app"

if wait_for_ready e2e-nginxtpl-docroot; then
    DOCROOT="$(probe http://localhost:18111/ document_root)"
    if [ "$DOCROOT" = "/app/current/public" ]; then
        log_success "DOCUMENT_ROOT is the symlinked root again ($DOCROOT)"
    else
        log_fail "DOCUMENT_ROOT is '$DOCROOT', expected /app/current/public"
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 3 (#40): the server-level include hook
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 3: /etc/nginx/server.d/*.conf is included (#40)"

SERVERD="$TMP_ROOT/server.d"
mkdir -p "$SERVERD"
cat > "$SERVERD/extra.conf" <<'EOF'
location = /from-server-d {
    default_type text/plain;
    return 200 "server.d works\n";
}
EOF

start_container e2e-nginxtpl-serverd \
    -p 18112:80 \
    -v "$(make_release_tree serverd)/releases/r1:/var/www/html" \
    -v "$SERVERD:/etc/nginx/server.d:ro"

if wait_for_ready e2e-nginxtpl-serverd; then
    assert_http_contains "http://localhost:18112/from-server-d" "server.d works" \
        "a location from server.d is served"
    assert_http_code "http://localhost:18112/" 200 "the app still answers alongside it"
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 4 (#40): Statamic full static caching
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 4: STATAMIC_STATIC_CACHING=full serves .html before PHP (#40)"

start_container e2e-nginxtpl-static \
    -e STATAMIC_STATIC_CACHING=full \
    -e STATAMIC_STATIC_IGNORE_QUERY_STRINGS=true \
    -p 18113:80 \
    -v "$(make_release_tree static)/releases/r1:/var/www/html"

if wait_for_ready e2e-nginxtpl-static; then
    assert_http_contains "http://localhost:18113/" "static r1 home" \
        "the home page comes from the static cache"
    assert_http_contains "http://localhost:18113/about" "static r1 about" \
        "a cached page comes from the static cache"

    # A POST must never be answered from a page cache.
    POSTED="$(curl -fsS -X POST http://localhost:18113/ 2>/dev/null || true)"
    if printf '%s' "$POSTED" | grep -q '"release"'; then
        log_success "a POST bypasses the static cache and reaches PHP"
    else
        log_fail "a POST was answered from the static cache: ${POSTED:0:80}"
    fi

    # So must a live preview.
    PREVIEW="$(curl -fsS 'http://localhost:18113/?live-preview=abc' 2>/dev/null || true)"
    if printf '%s' "$PREVIEW" | grep -q '"release"'; then
        log_success "a live-preview request bypasses the static cache"
    else
        log_fail "a live-preview request was answered from the static cache: ${PREVIEW:0:80}"
    fi

    # A page with no cache file must still render.
    assert_http_code "http://localhost:18113/not-cached" 200 \
        "an uncached path falls through to PHP"
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 5 (#40): off is the default and changes nothing
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 5: static caching is off by default"

start_container e2e-nginxtpl-off \
    -p 18114:80 \
    -v "$(make_release_tree off)/releases/r1:/var/www/html"

if wait_for_ready e2e-nginxtpl-off; then
    # The static file exists, but nothing should look for it.
    BODY="$(curl -fsS http://localhost:18114/ 2>/dev/null || true)"
    if printf '%s' "$BODY" | grep -q '"release"'; then
        log_success "the home page is rendered by PHP, not read from static/"
    else
        log_fail "static caching appears to be on by default: ${BODY:0:80}"
    fi
fi

FINAL_FAILED=$TESTS_FAILED
print_summary 2>/dev/null || true

(
    set +euo pipefail
    do_cleanup 2>/dev/null
) || true

[ "$FINAL_FAILED" -gt 0 ] && exit 1
exit 0
