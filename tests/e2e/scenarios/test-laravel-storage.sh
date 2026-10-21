#!/bin/bash
# E2E Test: Laravel storage setup through a SYMLINK to shared storage
#
# What this guards (#54), and why it needed a test of its own:
#
# On a release layout, storage in the release is a symlink to a shared
# directory (releases/<id>/storage -> ../../shared/storage). GNU chown and
# chmod disagree about a symlink named on the command line, and the startup
# code used both:
#
#     chown -R www-data release/storage  -> does NOT traverse (-P default),
#                                           so a scaffolded storage/app/public
#                                           stayed root:root and the app user
#                                           could not write it
#     chmod -R 775     release/storage  -> DOES follow, so every file in the
#                                           SHARED tree - sessions, logs,
#                                           caches, uploads - was rewritten to
#                                           775 on every container start
#
# One did nothing, the other did too much, and both were invisible without a
# symlink in the picture. Every other Laravel test uses a plain directory,
# which is exactly why this shipped. The fix resolves the path with realpath
# first so scaffold, chown and chmod all act on the same real directory, and
# skips the recursive walk when the tree is already owned by the app user.

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

# releases/r1/storage -> ../../shared/storage, built for real so the symlink
# is a symlink and the asymmetry above can actually bite.
make_release_tree() {
    local root="$TMP_ROOT/app"
    mkdir -p "$root/releases/r1/public" "$root/releases/r1/bootstrap" "$root/shared/storage"
    printf '<?php echo "ok";' > "$root/releases/r1/public/index.php"
    printf '#!/usr/bin/env php\n<?php\n' > "$root/releases/r1/artisan"
    ln -s ../../shared/storage "$root/releases/r1/storage"
    ln -sfn releases/r1 "$root/current"
    # a pre-existing non-executable file in SHARED storage - the thing the old
    # blanket chmod -R 775 clobbered on every start
    printf 'session-data\n' > "$root/shared/storage/pre-existing.log"
    chmod 644 "$root/shared/storage/pre-existing.log"
}

run_once() {   # start, wait for readiness, then stop - we assert on the host tree
    local name="$1"
    docker rm -f "$name" >/dev/null 2>&1 || true
    CONTAINERS="$CONTAINERS $name"
    docker run -d --name "$name" \
        -e PUID=33 -e PGID=33 \
        -e WORKDIR=/app/current -e NGINX_WEBROOT=/app/current/public \
        -v "$TMP_ROOT/app:/app" \
        "$IMAGE" >/dev/null
    local elapsed=0
    while [ "$elapsed" -lt 90 ]; do
        if [ "$(docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null || true)" != "true" ]; then
            log_fail "$name exited during startup"
            docker logs "$name" 2>&1 | tail -20
            return 1
        fi
        docker exec "$name" test -f /tmp/cbox-ready 2>/dev/null && return 0
        sleep 2; elapsed=$((elapsed + 2))
    done
    log_fail "$name did not become ready"
    docker logs "$name" 2>&1 | tail -20
    return 1
}

log_section "Laravel Storage (symlinked) E2E Test"
echo "  Image: $IMAGE"
make_release_tree
SHARED="$TMP_ROOT/app/shared/storage"

log_section "Test 1: scaffolded dirs are owned by the app user, through the symlink (#54)"

if run_once e2e-lstorage-1; then
    # The decisive one: app/public is created BY the scaffold, so under the old
    # code it was the directory chown -R never reached.
    OWNER="$(docker exec e2e-lstorage-1 stat -c %u /app/shared/storage/app/public 2>/dev/null || echo "?")"
    if [ "$OWNER" = "33" ]; then
        log_success "storage/app/public is uid 33 through the symlink ($OWNER)"
    else
        log_fail "storage/app/public is uid '$OWNER', expected 33 (the #54 regression)"
    fi

    for d in framework/cache framework/sessions framework/views logs; do
        if docker exec e2e-lstorage-1 test -d "/app/shared/storage/$d" 2>/dev/null; then
            log_success "scaffolded $d exists in the SHARED tree"
        else
            log_fail "scaffolded $d missing - the scaffold did not follow the symlink"
        fi
    done

    # php-fpm's user must be able to write what the scaffold created.
    assert_exec_succeeds e2e-lstorage-1 \
        "su -s /bin/sh -c 'echo probe > /app/current/storage/app/public/.probe' www-data" \
        "the app user can write into the scaffolded directory"
fi

log_section "Test 2: an existing file in shared storage keeps its mode (#54)"

if [ -f "$SHARED/pre-existing.log" ]; then
    MODE="$(docker exec e2e-lstorage-1 stat -c %a /app/shared/storage/pre-existing.log 2>/dev/null || echo "?")"
    case "$MODE" in
        664|644)
            log_success "pre-existing file is $MODE, not executable"
            ;;
        775|755)
            log_fail "pre-existing file became $MODE - chmod -R followed the symlink again (the #54 regression)"
            ;;
        *)
            log_fail "pre-existing file has unexpected mode '$MODE'"
            ;;
    esac

    DIRMODE="$(docker exec e2e-lstorage-1 stat -c %a /app/shared/storage/logs 2>/dev/null || echo "?")"
    if [ "$DIRMODE" = "775" ]; then
        log_success "directories are 775 ($DIRMODE)"
    else
        log_fail "storage/logs is '$DIRMODE', expected 775"
    fi
fi

log_section "Test 3: a second start skips the recursive walk (#54)"

if run_once e2e-lstorage-2; then
    LOG="$(docker logs e2e-lstorage-2 2>&1 || true)"
    if printf '%s\n' "$LOG" | grep -qF "already correct - skipping recursive chown"; then
        log_success "second start skipped the recursive chown/chmod"
    else
        log_fail "second start did not skip - it re-walks shared storage every time"
    fi
fi

FINAL_FAILED=$TESTS_FAILED
print_summary 2>/dev/null || true
( set +euo pipefail; do_cleanup 2>/dev/null ) || true
[ "$FINAL_FAILED" -gt 0 ] && exit 1
exit 0
