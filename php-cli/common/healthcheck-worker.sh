#!/bin/sh
# Health check for a container running a Laravel queue worker.
#
# The default healthcheck.sh answers "is PHP alive" - reusing a web image's
# check for a worker container makes the orchestrator kill healthy workers
# (or keep dead ones). This one checks the actual worker process.
#
# Usage (compose):  healthcheck: { test: ["CMD", "healthcheck-worker.sh"] }
# Works for queue:work, queue:listen and horizon-managed workers.
set -eu

if pgrep -f 'artisan (queue:work|queue:listen|horizon:work)' >/dev/null 2>&1; then
    exit 0
fi
echo "no queue worker process found (artisan queue:work/queue:listen/horizon:work)"
exit 1
