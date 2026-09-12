#!/bin/bash
# E2E Test: zero-loss docker stop under load (issue #24)
#
# Regression scenario for the v1.5.0/v1.6.0 shutdown work: cbox-init stops
# processes in reverse-dependency LEVELS (nginx fully exits before php-fpm
# is signalled), so in-flight requests finish instead of turning into 502s
# and resets.
#
# Measurement rules learned building the original stop benchmark:
# - Clients run on the CONTAINER NETWORK, never through the published-port
#   proxy: macOS docker-proxy accepts and resets connections for the whole
#   post-stop window, inflating apparent loss ~10x.
# - Outcomes classify by curl exit code + HTTP status:
#     rc=0 & 2xx            -> SERVED   (request completed)
#     rc=52/56, or 5xx      -> LOST     (severed mid-flight / error page)
#     rc=28                 -> LOST     (in-flight request never answered)
#     rc=7 or rc=6          -> REFUSED  (connect refused / name gone AFTER
#                                        close - the correct way to turn
#                                        traffic away, not a loss)
# Baselines on this classification, measured proxy-free: v1.4.0 = 2-12 lost
# per stop; v1.5.1+ (level-ordered shutdown) = 0-5. The bound asserts the
# post-fix regime with one request of slack against scheduler flake.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-utils.sh"

E2E_ROOT="$(get_e2e_root)"
FIXTURE_DIR="$E2E_ROOT/fixtures/stoploss"
IMAGE="${IMAGE:-ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.5-bookworm-v1}"

NET="e2e-stoploss-net"
SUT="e2e-stoploss-sut"
CLIENTS=12
MAX_LOST=6

do_cleanup() {
    for i in $(seq 1 $CLIENTS); do docker rm -f "e2e-stoploss-c$i" >/dev/null 2>&1 || true; done
    docker rm -f "$SUT" >/dev/null 2>&1 || true
    docker network rm "$NET" >/dev/null 2>&1 || true
    return 0
}

log_section "Zero-loss stop E2E Test"
do_cleanup

docker network create "$NET" >/dev/null

# No published port - the whole point is to measure without the proxy.
docker run -d --name "$SUT" --network "$NET" \
    -v "$FIXTURE_DIR/public:/var/www/html/public:ro" \
    "$IMAGE" >/dev/null

wait_for_healthy "$SUT" 90

# Sanity: the slow endpoint answers on the container network
code=$(docker run --rm --network "$NET" --entrypoint /usr/bin/curl "$IMAGE" \
    -s -o /dev/null -w '%{http_code}' --max-time 10 "http://$SUT/slow.php" || true)
if [ "$code" != "200" ]; then
    log_fail "slow.php not serving on the container network (got: $code)"
    do_cleanup
    exit 1
fi
log_success "slow.php serving on the container network"

log_section "Load + stop"

# 12 clients x ~200ms requests, logging "rc http_code" per request to stdout.
for i in $(seq 1 $CLIENTS); do
    docker run -d --name "e2e-stoploss-c$i" --network "$NET" \
        --entrypoint /bin/bash "$IMAGE" -c '
        end=$((SECONDS+60))
        while [ $SECONDS -lt $end ]; do
            code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://'"$SUT"'/slow.php")
            rc=$?
            echo "$rc $code"
            # after the SUT is gone, refusals come back instantly - do not
            # burn the log with thousands of them
            [ "$rc" = "7" ] || [ "$rc" = "6" ] && sleep 0.2
        done' >/dev/null
done

# Let the load reach steady state, then stop the SUT mid-flight.
sleep 4
stop_started=$SECONDS
docker stop -t 30 "$SUT" >/dev/null
stop_secs=$((SECONDS - stop_started))
log_info "docker stop completed in ${stop_secs}s"

# Give the clients a moment to observe the post-stop state, then freeze them.
sleep 2
for i in $(seq 1 $CLIENTS); do docker kill "e2e-stoploss-c$i" >/dev/null 2>&1 || true; done

log_section "Classify per-request outcomes"

served=0; lost=0; refused=0; other=0
for i in $(seq 1 $CLIENTS); do
    while read -r rc code; do
        [ -z "${rc:-}" ] && continue
        if [ "$rc" = "0" ] && [ "${code:0:1}" = "2" ]; then
            served=$((served+1))
        elif [ "$rc" = "52" ] || [ "$rc" = "56" ] || [ "$rc" = "28" ] || [ "${code:0:1}" = "5" ]; then
            lost=$((lost+1))
        elif [ "$rc" = "7" ] || [ "$rc" = "6" ]; then
            refused=$((refused+1))
        else
            other=$((other+1))
        fi
    done < <(docker logs "e2e-stoploss-c$i" 2>/dev/null || true)
done

log_info "served=$served lost=$lost refused=$refused other=$other"

# The load must have been real for the assertion to mean anything.
if [ "$served" -lt 100 ]; then
    log_fail "only $served served requests - load never reached steady state, result not meaningful"
    do_cleanup
    exit 1
fi
log_success "steady load confirmed ($served served)"

if [ "$lost" -le "$MAX_LOST" ]; then
    log_success "graceful stop: $lost lost requests (bound: $MAX_LOST)"
else
    log_fail "lossy stop: $lost requests severed mid-flight (bound: $MAX_LOST) - the level-ordered shutdown regressed"
    do_cleanup
    exit 1
fi

# Stop must be graceful, not a 30s-timeout SIGKILL escape.
if [ "$stop_secs" -lt 25 ]; then
    log_success "stop completed gracefully in ${stop_secs}s (no timeout kill)"
else
    log_fail "stop took ${stop_secs}s - processes were likely SIGKILLed at the timeout"
    do_cleanup
    exit 1
fi

do_cleanup
log_section "Zero-loss stop test PASSED"
