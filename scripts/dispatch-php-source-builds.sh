#!/usr/bin/env bash
# Called only by the hourly GitHub workflow. Local tests replace gh with a stub.
set -euo pipefail
exec python3 "$(dirname "$0")/dispatch-php-source-builds.py"
