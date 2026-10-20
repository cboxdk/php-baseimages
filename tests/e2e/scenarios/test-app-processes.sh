#!/bin/bash
# E2E Test: cbox-init app processes (queue workers, scheduler, Horizon, Reverb)
#
# What this guards, and what each one cost somebody:
#
#   #34  The workers ran as root while php-fpm ran as the PUID-mapped app user.
#        Everything a job wrote - cache files, compiled views, logs, git objects
#        from Statamic's git automation - came out root-owned, and the FPM
#        workers could not write there afterwards.
#   #35  working_dir was hardcoded to /var/www/html, so a symlink-release
#        layout (WORKDIR=/app/current) crash-looped every worker with
#        "Could not open input file: artisan".
#   #36  CBOX_INIT_PROCESS_*_SCALE=1 refused to load the config at all
#        ("cannot unmarshal !!bool true into int") - fixed in cbox-init 3.8.2.
#        Asserted here because the image is where it surfaced.
#
# No services needed: the fixture's artisan stand-in records its identity and
# then idles instead of talking to Redis, so plain `docker run` is enough.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-utils.sh"

E2E_ROOT="$(get_e2e_root)"
FIXTURE_DIR="$E2E_ROOT/fixtures/app-processes"
IMAGE="${IMAGE:-ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.5-bookworm-v1}"

# Each case gets its own release tree on the host, so the symlink layout is the
# real thing and no case reads the identity another case recorded:
#   $TMP_ROOT/<case>/releases/r1       the release
#   $TMP_ROOT/<case>/current -> releases/r1
TMP_ROOT="$(mktemp -d)"
CONTAINERS=""
IDENTITY_FILE="storage/logs/app-process-identity.txt"

do_cleanup() {
    for c in $CONTAINERS; do
        docker rm -f "$c" >/dev/null 2>&1 || true
    done
    rm -rf "$TMP_ROOT" 2>/dev/null || true
    return 0
}

# Build a release tree for one case and echo its root.
make_release_tree() {
    local root="$TMP_ROOT/$1"
    mkdir -p "$root/releases/r1/storage/logs"
    cp -R "$FIXTURE_DIR/app/." "$root/releases/r1/"
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

# ─────────────────────────────────────────────────────────────────────────────
# Probes
#
# A pattern travels in an environment variable, never on the probe's own
# command line: `sh -c "... grep -F 'artisan queue:work' ..."` puts the pattern
# into the shell's own argv, so the probe matched ITSELF and reported one
# process too many.
#
# cwd does NOT come from /proc. Reading /proc/<pid>/cwd of a process owned by
# another uid needs CAP_SYS_PTRACE, which is not in Docker's default capability
# set - so even root in the container gets EACCES. The fixture's artisan
# records its own getcwd() instead.
# ─────────────────────────────────────────────────────────────────────────────

# uid of the first process whose full command line contains $2.
process_uid() {
    docker exec -e PAT="$2" "$1" \
        sh -c 'ps -eo uid,args | grep -F "$PAT" | grep -v grep | head -1 | awk "{print \$1}"' 2>/dev/null || true
}

# How many processes match $2.
process_count() {
    docker exec -e PAT="$2" "$1" \
        sh -c 'ps -eo args | grep -F "$PAT" | grep -v grep | wc -l | tr -d " "' 2>/dev/null || echo 0
}

# The "<cwd> <uid> <user>" line the fixture's artisan recorded at startup.
recorded_identity() {
    docker exec "$1" sh -c "head -1 '$2/$IDENTITY_FILE'" 2>/dev/null || true
}

# cbox-init writes /tmp/cbox-ready once every tracked process is healthy.
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

# A worker has no health check, so cbox-init reports the container ready the
# moment the process is STARTED - before a crash-looping one has even printed
# its first error. Readiness is therefore not enough to judge a worker by: wait
# until it has recorded itself, which only a worker that got going can do.
wait_for_identity() {
    local name="$1" workdir="$2" timeout="${3:-30}" elapsed=0
    while [ "$elapsed" -lt "$timeout" ]; do
        if docker exec "$name" test -s "$workdir/$IDENTITY_FILE" 2>/dev/null; then
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done
    return 1
}

log_section "App Processes E2E Test"
echo "  Image: $IMAGE"

# ═══════════════════════════════════════════════════════════════════════════
# TEST 1 (#34): workers share the php-fpm pool's identity
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 1: worker identity matches the php-fpm pool (#34)"

start_container e2e-appproc-identity \
    -e PUID=1000 -e PGID=1001 \
    -e LARAVEL_QUEUE=true -e LARAVEL_SCHEDULER=true \
    -v "$(make_release_tree identity)/releases/r1:/var/www/html"

if wait_for_ready e2e-appproc-identity; then
    FPM_UID="$(process_uid e2e-appproc-identity 'php-fpm: pool')"
    WORKER_UID="$(process_uid e2e-appproc-identity 'artisan queue:work')"
    SCHED_UID="$(process_uid e2e-appproc-identity 'artisan schedule:work')"

    if [ -n "$FPM_UID" ] && [ "$WORKER_UID" = "$FPM_UID" ]; then
        log_success "queue worker runs as the php-fpm pool uid ($FPM_UID)"
    else
        log_fail "queue worker uid '$WORKER_UID' != php-fpm pool uid '$FPM_UID'"
    fi

    if [ -n "$FPM_UID" ] && [ "$SCHED_UID" = "$FPM_UID" ]; then
        log_success "scheduler runs as the php-fpm pool uid ($FPM_UID)"
    else
        log_fail "scheduler uid '$SCHED_UID' != php-fpm pool uid '$FPM_UID'"
    fi

    if [ "$WORKER_UID" = "0" ]; then
        log_fail "queue worker is running as root (the #34 regression)"
    else
        log_success "queue worker is not root"
    fi

    if wait_for_identity e2e-appproc-identity /var/www/html; then
        IDENTITY="$(recorded_identity e2e-appproc-identity /var/www/html)"
        if [ -n "$FPM_UID" ] && echo "$IDENTITY" | grep -q " $FPM_UID "; then
            log_success "worker recorded its own uid as the app user ($IDENTITY)"
        else
            log_fail "worker recorded '$IDENTITY', expected uid $FPM_UID"
        fi

        # The point of #34: what a job writes must still be writable by the
        # php-fpm workers that read it next.
        assert_exec_succeeds e2e-appproc-identity \
            "su -s /bin/sh -c 'echo probe >> /var/www/html/$IDENTITY_FILE' www-data" \
            "php-fpm's user can write what the worker wrote"
    else
        log_fail "worker never recorded itself in /var/www/html/$IDENTITY_FILE"
        docker logs e2e-appproc-identity 2>&1 | tail -20
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 2 (#35): app processes start in $WORKDIR, not /var/www/html
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 2: app processes honor WORKDIR (#35)"

start_container e2e-appproc-workdir \
    -e PUID=1000 -e PGID=1001 \
    -e WORKDIR=/app/current -e NGINX_WEBROOT=/app/current/public \
    -e LARAVEL_QUEUE=true \
    -p 18099:80 \
    -v "$(make_release_tree workdir):/app"

if wait_for_ready e2e-appproc-workdir; then
    if wait_for_identity e2e-appproc-workdir /app/current; then
        # PHP resolves its cwd, so /app/current shows up as the release it
        # points at - either spelling means the worker found the app.
        WORKER_CWD="$(recorded_identity e2e-appproc-workdir /app/current | awk '{print $1}' || true)"
        case "$WORKER_CWD" in
            /app/current|/app/releases/r1)
                log_success "queue worker started in WORKDIR ($WORKER_CWD)"
                ;;
            *)
                log_fail "queue worker cwd is '$WORKER_CWD', expected /app/current or its release path"
                ;;
        esac
    else
        log_fail "queue worker never got going under WORKDIR=/app/current (the #35 regression)"
    fi

    # NOT `docker logs | grep -q`: grep -q exits on the first match, docker
    # logs takes SIGPIPE, and under `set -o pipefail` a MATCH then looks like a
    # failed pipeline - so the check passed exactly when it should have failed.
    WORKDIR_LOG="$(docker logs e2e-appproc-workdir 2>&1 || true)"
    if printf '%s\n' "$WORKDIR_LOG" | grep -F "Could not open input file" | head -3; then
        log_fail "'Could not open input file' in the startup log (the #35 regression)"
    else
        log_success "no 'Could not open input file' in the startup log"
    fi

    assert_http_code "http://localhost:18099/" 200 "app served from the symlinked webroot"
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 3 (#36): a numeric env override is a number
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 3: CBOX_INIT_PROCESS_*_SCALE=1 loads (#36)"

start_container e2e-appproc-scale \
    -e LARAVEL_QUEUE=true \
    -e CBOX_INIT_PROCESS_QUEUE_DEFAULT_SCALE=1 \
    -v "$(make_release_tree scale)/releases/r1:/var/www/html"

if wait_for_ready e2e-appproc-scale; then
    SCALE_LOG="$(docker logs e2e-appproc-scale 2>&1 || true)"
    if printf '%s\n' "$SCALE_LOG" | grep -E "cannot unmarshal|Failed to load configuration" | head -3; then
        log_fail "SCALE=1 broke config loading (the #36 regression)"
    else
        log_success "config loaded with SCALE=1"
    fi

    COUNT="$(process_count e2e-appproc-scale 'artisan queue:work')"
    if [ "$COUNT" = "1" ]; then
        log_success "SCALE=1 started exactly one worker"
    else
        log_fail "SCALE=1 started $COUNT workers, expected 1"
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 4: an explicit per-process user override still wins
# ═══════════════════════════════════════════════════════════════════════════
log_section "Test 4: CBOX_INIT_PROCESS_*_USER overrides the default"

start_container e2e-appproc-override \
    -e LARAVEL_QUEUE=true \
    -e CBOX_INIT_PROCESS_QUEUE_DEFAULT_USER=root \
    -v "$(make_release_tree override)/releases/r1:/var/www/html"

if wait_for_ready e2e-appproc-override; then
    OVERRIDE_UID="$(process_uid e2e-appproc-override 'artisan queue:work')"
    if [ "$OVERRIDE_UID" = "0" ]; then
        log_success "CBOX_INIT_PROCESS_QUEUE_DEFAULT_USER=root honored"
    else
        log_fail "worker uid is '$OVERRIDE_UID', expected 0 from the explicit override"
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
