#!/bin/bash
# E2E Test: git integration plumbing (Statamic git, composer VCS installs)
#
# The image promises three things a git-backed CMS needs:
# 1. git present AND trusted on bind-mounts: git 2.35+ refuses repos owned
#    by another UID ("dubious ownership") - the normal state for a mounted
#    app dir. The image bakes `safe.directory=*` into /etc/gitconfig.
# 2. openssh-client (ssh + ssh-keyscan) for SSH remotes and known_hosts.
# 3. The runtime user (www-data) can commit and push - not just root.
#
# All local (file:// remote), no network, so it can gate every build.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-utils.sh"

IMAGE="${IMAGE:-ghcr.io/cboxdk/php-baseimages/php-fpm-nginx:8.5-bookworm-v1}"
C="e2e-gitint"

do_cleanup() {
    docker rm -f "$C" >/dev/null 2>&1 || true
    return 0
}

log_section "Git integration plumbing E2E Test"
do_cleanup

docker run -d --name "$C" --entrypoint /bin/bash "$IMAGE" -c 'sleep 300' >/dev/null

log_section "Tooling"
assert_exec_succeeds "$C" "git --version" "git is installed"
assert_exec_succeeds "$C" "ssh -V" "openssh client is installed"
assert_exec_succeeds "$C" "command -v ssh-keyscan" "ssh-keyscan is installed"

log_section "safe.directory on foreign-owned repos"
# Repo created by root (simulates a bind-mount owned by the host user)...
docker exec "$C" bash -c '
    set -e
    mkdir -p /var/www/html/site && cd /var/www/html/site
    git init -q -b main .
    git config user.email e2e@cbox.dk && git config user.name e2e
    echo one > content.md && git add . && git commit -qm initial
' >/dev/null
# ...must be readable AND writable by the runtime user without any config.
assert_exec_succeeds "$C" "su -s /bin/bash www-data -c 'git -C /var/www/html/site status --porcelain'" \
    "www-data can run git status in a root-owned repo (safe.directory)"

log_section "Commit and push as the runtime user"
docker exec "$C" bash -c '
    set -e
    git init -q --bare /tmp/remote.git
    git -C /var/www/html/site remote add origin file:///tmp/remote.git
    chown -R www-data:www-data /var/www/html/site /tmp/remote.git
' >/dev/null
assert_exec_succeeds "$C" "su -s /bin/bash www-data -c '
    cd /var/www/html/site &&
    echo two > content.md &&
    git add -A &&
    git -c user.email=cms@cbox.dk -c user.name=cms commit -qm \"content change\" &&
    git push -q origin main'" \
    "www-data can commit and push (the Statamic git flow)"

count=$(docker exec "$C" su -s /bin/bash www-data -c "git -C /tmp/remote.git rev-list --count main" 2>/dev/null || echo 0)
if [ "$count" = "2" ]; then
    log_success "bare remote received both commits (rev-list count: $count)"
else
    log_fail "expected 2 commits on the remote, got: $count"
    do_cleanup
    exit 1
fi

FINAL_FAILED=$TESTS_FAILED
if [ "$FINAL_FAILED" -gt 0 ]; then TEST_EXIT_CODE=1; else TEST_EXIT_CODE=0; fi
print_summary 2>/dev/null || true
( set +euo pipefail; do_cleanup 2>/dev/null ) || true
exit "$TEST_EXIT_CODE"
