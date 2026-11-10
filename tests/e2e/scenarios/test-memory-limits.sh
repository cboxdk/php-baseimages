#!/bin/bash
# E2E Test: PHP-FPM starts under a container memory limit
#
# What this guards, and what it cost somebody:
#
#   A 512Mi Kubernetes pod crash-looped php-fpm with
#     ALERT: [pool www] pm.min_spare_servers(1) and pm.max_spare_servers(6)
#            cannot be greater than pm.max_children(4)
#   cbox-init's boot autotune sized the pool to 4 children (and valid spare
#   counts), but the entrypoint had already written the PRE-tune spare defaults
#   into zz-pm-mode.conf as literals, so only max_children took the tuned value.
#   Without a memory limit the medium profile lands above 6 children and the
#   pool is valid, which is why every smoke test (plain `docker run`) passed.
#
# The container does not exit when php-fpm fails - cbox-init keeps restarting
# it - and /healthz is answered by nginx alone, so neither "running" nor
# "healthy" says anything here. /fpm-ping goes through php-fpm and is the probe.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-utils.sh"

IMAGE="${IMAGE:-ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.5-bookworm-v1}"
CONTAINERS=""

do_cleanup() {
    for c in $CONTAINERS; do
        docker rm -f "$c" >/dev/null 2>&1 || true
    done
    return 0
}

start_container() {
    local name="$1"
    shift
    docker rm -f "$name" >/dev/null 2>&1 || true
    CONTAINERS="$CONTAINERS $name"
    docker run -d --name "$name" "$@" "$IMAGE" >/dev/null
}

# php-fpm answers "pong" through nginx. The root image listens on 80, the
# rootless one on 8080.
fpm_pong() {
    docker exec "$1" sh -c \
        'curl -sf --max-time 3 http://127.0.0.1/fpm-ping 2>/dev/null || curl -sf --max-time 3 http://127.0.0.1:8080/fpm-ping 2>/dev/null' \
        2>/dev/null | grep -qx pong
}

# Pass when php-fpm answers within the timeout AND never refused its pool
# config. The second half matters: cbox-init restarts a failed php-fpm, so a
# lucky probe between restarts must not hide a config FPM rejected.
assert_fpm_starts() {
    local name="$1" description="$2" timeout="${3:-60}" elapsed=0
    while [ "$elapsed" -lt "$timeout" ]; do
        if [ "$(docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null || true)" != "true" ]; then
            break
        fi
        if fpm_pong "$name"; then
            if docker logs "$name" 2>&1 | grep -q "FPM initialization failed"; then
                break
            fi
            log_success "$description"
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done
    log_fail "$description"
    docker logs "$name" 2>&1 | grep -E "pm\.|ALERT|ERROR|WARN" | tail -20
    return 0
}

log_section "Memory Limit E2E Test"
echo "  Image: $IMAGE"

# ═══════════════════════════════════════════════════════════════════════════
# Autotuned (default medium profile) under small limits. 256m clamps to one
# worker, 512m to four - both below the old max_spare default of 6.
# ═══════════════════════════════════════════════════════════════════════════
for mem in 256m 512m; do
    log_section "Autotune under -m $mem"
    start_container "e2e-memlimit-$mem" -m "$mem"
    assert_fpm_starts "e2e-memlimit-$mem" "php-fpm starts with the autotuned pool under -m $mem"
done

# ═══════════════════════════════════════════════════════════════════════════
# Manual sizing below the spare defaults. PHP_FPM_MAX_CHILDREN pins the count
# and turns autotune off, so the entrypoint's own clamp is what keeps the pool
# valid - the spare defaults alone (start 2, max 6) do not fit 2 children.
# ═══════════════════════════════════════════════════════════════════════════
log_section "Manual sizing: PHP_FPM_MAX_CHILDREN=2"
start_container e2e-memlimit-manual -m 256m -e PHP_FPM_MAX_CHILDREN=2
assert_fpm_starts e2e-memlimit-manual "php-fpm starts with PHP_FPM_MAX_CHILDREN=2 and default spare counts"

FINAL_FAILED=$TESTS_FAILED
print_summary 2>/dev/null || true

(
    set +euo pipefail
    do_cleanup 2>/dev/null
) || true

[ "$FINAL_FAILED" -gt 0 ] && exit 1
exit 0
