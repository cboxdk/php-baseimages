#!/usr/bin/env bash
# Contract test: no build stage may purge a package that slim-base installs as
# a RUNTIME dependency.
#
# Why: the dev tier listed `git` in its own build-deps install and then ran
# `apt-get purge -y --auto-remove $PHPIZE_DEPS git`. git is a runtime tool in
# every tier (composer VCS installs, `git status` in a bind-mounted app,
# Statamic git integration, and the baked `safe.directory = *` that exists
# only to make it work) - so the ONE tier meant for CI and local development
# was the only one shipping without it, and --auto-remove took git-man,
# liberror-perl and patch along for the ride.
#
# It shipped that way because nothing compared a tier against the tier it
# extends. This does, statically, on every push.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

DOCKERFILE="php-base/Dockerfile"

# The runtime-dep block in slim-base, by its own header comment. Everything
# from there to the apt-lists cleanup is what every tier must keep.
runtime_pkgs=$(awk '
    /SLIM: System Dependencies \(Runtime only/ { grab = 1 }
    grab && /rm -rf \/var\/lib\/apt\/lists/  { grab = 0 }
    grab { print }
' "$DOCKERFILE" \
    | grep -vE '^\s*#|apt-get|RUN|^\s*$' \
    | tr ' \\' '\n\n' \
    | grep -E '^[a-z0-9][a-z0-9.+-]+$' \
    | sort -u)

if [ -z "$runtime_pkgs" ]; then
    echo "Could not parse the slim-base runtime dependency block in $DOCKERFILE"
    echo "(the header comment it keys off may have been reworded)"
    exit 1
fi

fail=0
while IFS= read -r line; do
    case "$line" in *apt-get\ purge*|*apt-get\ remove*) ;; *) continue ;; esac
    for pkg in $runtime_pkgs; do
        # Word-boundary match so `libzip4` never matches `zip`.
        if echo "$line" | grep -qE "(^|[[:space:]])${pkg}([[:space:]]|\\\\|$)"; then
            echo "RUNTIME DEP PURGED: '$pkg' is a slim-base runtime dependency but a later stage removes it:"
            echo "    $(echo "$line" | sed 's/^[[:space:]]*//')"
            fail=1
        fi
    done
done < "$DOCKERFILE"

if [ "$fail" = "1" ]; then
    echo ""
    echo "A tier must not drop a tool the tiers below it ship. If the package"
    echo "genuinely is build-only, move it out of the slim-base runtime block"
    echo "instead of purging it downstream."
    exit 1
fi

echo "runtime deps OK: no stage purges a slim-base runtime package"
echo "  (checked $(echo "$runtime_pkgs" | wc -l | tr -d ' ') packages)"
