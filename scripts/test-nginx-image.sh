#!/usr/bin/env bash
set -euo pipefail
image="${1:?image reference required}"
platform="${2:-linux/amd64}"
container=$(docker run -d --platform "$platform" -p 127.0.0.1::80 "$image")
trap 'docker rm -f "$container" >/dev/null' EXIT
address=$(docker port "$container" 80/tcp)
for _ in $(seq 1 30); do
    if curl --fail --silent --max-time 2 "http://$address/health" >/dev/null; then
        docker exec "$container" nginx -t
        echo "PASS: $platform Nginx config and HTTP health"
        exit 0
    fi
    [ "$(docker inspect --format '{{.State.Running}}' "$container")" = true ] || break
    sleep 1
done
docker logs "$container"
exit 1
