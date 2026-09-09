#!/bin/sh
# Health check for a container running Laravel Horizon.
#
# Asks Horizon itself rather than pgrep'ing: horizon:status returns non-zero
# when the master supervisor is paused or not running, which is the state an
# orchestrator should act on.
set -eu

cd "${WORKDIR:-/var/www/html}" 2>/dev/null || cd /var/www/html

status=$(php artisan horizon:status 2>&1) || {
    echo "horizon:status failed: $status"
    exit 1
}
case "$status" in
    *running*) exit 0 ;;
    *) echo "horizon not running: $status"; exit 1 ;;
esac
