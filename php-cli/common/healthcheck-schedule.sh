#!/bin/sh
# Health check for a container running the Laravel scheduler
# (php artisan schedule:work).
set -eu

if pgrep -f 'artisan schedule:work' >/dev/null 2>&1; then
    exit 0
fi
echo "no scheduler process found (artisan schedule:work)"
exit 1
