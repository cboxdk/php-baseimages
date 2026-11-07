#!/usr/bin/env bash
# Local-only integration test; requires a source smoke image from test-php-source.sh.
set -euo pipefail
cd "$(dirname "$0")/.."
export DOCKER_CONTEXT="${DOCKER_CONTEXT:-orbstack}"
export PLATFORM="${PLATFORM:-linux/arm64}"
export DOCKER_DEFAULT_PLATFORM="$PLATFORM"
ARCH=${PLATFORM#linux/}
DEFAULT_VERSION=$(python3 scripts/php-source.py version)
BASE_IMAGE="${1:-cbox-php-source:${DEFAULT_VERSION}-${ARCH}-smoke}"
mkdir -p .build/image-patch
{
    printf 'FROM %s\n' "$BASE_IMAGE"
    cat <<'DOCKERFILE'
USER root
# A deliberately old, empty package forces a real apt upgrade without
# downloading an insecure historical base image or modifying PHP itself.
RUN mkdir -p /tmp/hello/DEBIAN \
    && printf 'Package: hello\nVersion: 0.0.0\nArchitecture: all\nMaintainer: Local Test <test@example.invalid>\nDescription: Upgrade test fixture\n' > /tmp/hello/DEBIAN/control \
    && dpkg-deb --build /tmp/hello /tmp/hello.deb \
    && dpkg -i /tmp/hello.deb && rm -rf /tmp/hello /tmp/hello.deb
USER 33:33
DOCKERFILE
} > .build/image-patch/rootless.Dockerfile
docker build -f .build/image-patch/rootless.Dockerfile -t cbox-patch-test:rootless .
BEFORE=$(docker run --rm --entrypoint sha256sum cbox-patch-test:rootless /usr/local/bin/php)
VERSION=$(docker run --rm --entrypoint php cbox-patch-test:rootless -r 'echo PHP_VERSION;')
python3 - <<'PY'
import importlib.util
import os
from pathlib import Path
import sys
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('image_patch', 'scripts/image-patch.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
assert module.probe_updates('cbox-patch-test:rootless', os.environ['PLATFORM']) is True, 'fixture must require an upgrade'
Path('.build/image-patch/patch.Dockerfile').write_text(module.patch_dockerfile('cbox-patch-test:rootless', '33:33', 'patched'))
PY
started=$(date +%s)
docker build -f .build/image-patch/patch.Dockerfile --build-arg "CACHE_REFRESH=$(date +%s)" -t cbox-patch-test:patched .
echo "OS patch build: $(( $(date +%s) - started )) seconds"
docker run --rm --entrypoint hello cbox-patch-test:patched --version
AFTER=$(docker run --rm --entrypoint sha256sum cbox-patch-test:patched /usr/local/bin/php)
test "$BEFORE" = "$AFTER"
test "$(docker run --rm --entrypoint id cbox-patch-test:patched -u)" = '33'
CONTAINER=$(docker run -d -p 127.0.0.1::9000 cbox-patch-test:patched)
trap 'docker logs "$CONTAINER"; docker rm -f "$CONTAINER" >/dev/null' EXIT
PORT=$(docker port "$CONTAINER" 9000/tcp)
python3 tests/php-source-fastcgi.py "${PORT##*:}" "$VERSION"
python3 - <<'PYTHON'
import importlib.util
import os
spec = importlib.util.spec_from_file_location('patch', 'scripts/image-patch.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
assert module.probe_updates('cbox-patch-test:patched', os.environ['PLATFORM']) is False, 'patched image should now be reusable'
PYTHON
echo 'PASS: PHP binary unchanged, rootless user restored, FPM request succeeds after OS patch'
