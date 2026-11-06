#!/usr/bin/env bash
# Run on each native architecture before its digest can be promoted.
set -euo pipefail
image="${1:?image reference required}"
expected="${2:?expected PHP patch required}"
tier="${3:?tier required}"
image_type="${4:?image type required}"
case "$tier" in slim|standard|chromium|dev) ;; *) exit 2;; esac
docker run --rm --entrypoint php "$image" -r '
    if (PHP_VERSION !== $argv[1]) { fwrite(STDERR, "Wrong PHP version: ".PHP_VERSION); exit(1); }
    $required = ["Zend OPcache", "redis", "apcu", "msgpack", "pdo_mysql", "pdo_pgsql", "mysqli", "pgsql", "zip", "intl", "bcmath", "gd", "exif", "pcntl", "sockets", "bz2", "gmp", "mbstring"];
    if ($argv[2] !== "slim") $required = array_merge($required, ["imagick", "mongodb", "soap", "ldap", "xsl"]);
    if ($argv[2] === "dev") $required = array_merge($required, ["xdebug", "pcov", "spx"]);
    foreach ($required as $extension) {
        if (!extension_loaded($extension)) { fwrite(STDERR, "Missing extension: ".$extension); exit(1); }
    }
    if ($argv[2] !== "slim") {
        foreach (["png", "jpeg", "webp", "avif", "heic"] as $format) {
            $image = new Imagick(); $image->newImage(8, 8, "white"); $image->setImageFormat($format);
            $decoded = new Imagick(); $decoded->readImageBlob($image->getImageBlob());
            if ($decoded->getImageWidth() !== 8) { fwrite(STDERR, "Invalid ".$format." roundtrip"); exit(1); }
        }
    }
    echo "PASS: PHP ".PHP_VERSION." with all ".$argv[2]." extensions\n";
' "$expected" "$tier"
case "$image_type" in
    php-fpm|php-fpm-nginx)
        container=$(docker run -d --memory 512m --cpus 1 -e HEALTHCHECK_MAX_FAILURES=1 "$image")
        trap 'docker rm -f "$container" >/dev/null' EXIT
        healthy=false
        for _ in $(seq 1 30); do
            if docker exec "$container" /usr/local/bin/healthcheck.sh >/dev/null 2>&1; then
                healthy=true
                break
            fi
            [ "$(docker inspect --format '{{.State.Running}}' "$container")" = true ] || break
            sleep 1
        done
        if [ "$healthy" != true ]; then
            docker logs "$container"
            docker exec "$container" /usr/local/bin/healthcheck.sh || true
            exit 1
        fi
        echo "PASS: running $image_type healthcheck"
        ;;
esac
