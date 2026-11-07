#!/usr/bin/env bash
set -euo pipefail
image="${1:?image reference required}"
platform="${2:-linux/amd64}"
# Classic Docker image stores cannot load two architectures under the same
# index digest. Resolve the selected platform to its own immutable manifest.
manifest=$(docker buildx imagetools inspect "$image" --raw)
if jq -e '.manifests' >/dev/null <<< "$manifest"; then
    digest=$(jq -er --arg arch "${platform#linux/}"         '[.manifests[] | select(.platform.os == "linux" and .platform.architecture == $arch)] | if length == 1 then .[0].digest else error("Expected one platform manifest") end' <<< "$manifest")
    repository="${image%@*}"
    repository="${repository%:*}"
    image="$repository@$digest"
fi
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
