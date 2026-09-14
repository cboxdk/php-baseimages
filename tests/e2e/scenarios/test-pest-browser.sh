#!/bin/bash
# E2E Test: Pest v4 browser-testing readiness (Playwright)
# requires: chromium
#
# The chromium tier promises: Playwright's Chromium baked at
# PLAYWRIGHT_BROWSERS_PATH, revision-matched to playwright@latest (weekly
# rebuild), plus chromium-driver for Dusk and the screenshot fonts. The
# launch smoke installs playwright@latest from npm (packages only - the
# browser download is what the bake exists to avoid) and drives the BAKED
# browser, which is exactly what pest-plugin-browser does at runtime.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-utils.sh"

IMAGE="${IMAGE:-ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.5-bookworm-chromium-v1}"
C="e2e-pest-browser"

do_cleanup() {
    docker rm -f "$C" >/dev/null 2>&1 || true
    return 0
}

log_section "Pest browser-testing readiness E2E Test"
do_cleanup

docker run -d --name "$C" --entrypoint /bin/bash "$IMAGE" -c 'sleep 600' >/dev/null

log_section "Baked components"
assert_exec_contains "$C" "env" "PLAYWRIGHT_BROWSERS_PATH=/ms-playwright" "PLAYWRIGHT_BROWSERS_PATH is set"
assert_exec_succeeds "$C" "ls /ms-playwright | grep -q chromium" "Playwright Chromium build is baked"
assert_exec_succeeds "$C" "command -v chromedriver" "chromedriver is installed (Dusk)"
assert_exec_succeeds "$C" "command -v node && command -v npm" "Node.js and npm are present"
assert_exec_succeeds "$C" "fc-list 2>/dev/null | grep -qi 'noto color emoji'" "emoji font installed (screenshot fidelity)"

# chromium and chromedriver must agree on their major version (apt pairs them)
maj_c=$(docker exec "$C" sh -c "chromium --version 2>/dev/null" | grep -oE '[0-9]+' | head -1 || echo 0)
maj_d=$(docker exec "$C" sh -c "chromedriver --version 2>/dev/null" | grep -oE '[0-9]+' | head -1 || echo 1)
if [ "$maj_c" = "$maj_d" ] && [ "$maj_c" != "0" ]; then
    log_success "chromium ($maj_c) and chromedriver ($maj_d) majors match"
else
    log_fail "chromium major ($maj_c) != chromedriver major ($maj_d)"
fi

log_section "Playwright launch smoke against the baked browser"
# playwright@latest npm package (~no browser download - that is the point);
# ESM resolves from the file's directory, hence the global-lib placement.
assert_exec_succeeds "$C" '
    npm install -g playwright@latest >/dev/null 2>&1 &&
    D=$(dirname $(npm root -g)) &&
    printf "%s" "import { chromium } from \"playwright\";
const b = await chromium.launch();
const p = await b.newPage();
await p.setContent(\"<h1>pest-smoke</h1>\");
if (await p.textContent(\"h1\") !== \"pest-smoke\") process.exit(1);
await b.close();" > $D/smoke.mjs &&
    node $D/smoke.mjs' \
    "playwright@latest launches the baked Chromium and renders (no browser download)"

FINAL_FAILED=$TESTS_FAILED
if [ "$FINAL_FAILED" -gt 0 ]; then TEST_EXIT_CODE=1; else TEST_EXIT_CODE=0; fi
print_summary 2>/dev/null || true
( set +euo pipefail; do_cleanup 2>/dev/null ) || true
exit "$TEST_EXIT_CODE"
