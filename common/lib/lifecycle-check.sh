#!/bin/sh
# ============================================================================
# Cbox Base Images - Lifecycle Check (Runtime)
# ============================================================================
# Displays deprecation/preview warnings at container startup
# Sourced by entrypoint scripts
#
# Environment variables (set at build time via labels):
#   CBOX_LIFECYCLE       - stable|deprecated|eol|preview
#   CBOX_WARNING_MESSAGE - Warning text to display
#   CBOX_PHP_EOL        - PHP EOL date
#   CBOX_REMOVAL_DATE   - Image removal date
#
# To suppress warnings:
#   CBOX_SUPPRESS_WARNINGS=true
# ============================================================================
# shellcheck shell=sh

# Colors (only if terminal supports it)
# Use POSIX [ -t 1 ] instead of bash [[ -t 1 ]]
if [ -t 1 ]; then
    RED='\033[0;31m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''
    YELLOW=''
    BLUE=''
    NC=''
fi

cbox_lifecycle_check() {
    # Skip if warnings are suppressed (POSIX compatible string comparison)
    [ "${CBOX_SUPPRESS_WARNINGS:-false}" = "true" ] && return 0

    lifecycle="${CBOX_LIFECYCLE:-stable}"

    case "$lifecycle" in
        stable)
            # No warning needed
            return 0
            ;;

        deprecated)
            echo -e "${YELLOW}"
            echo "╔══════════════════════════════════════════════════════════════════╗"
            echo "║  ⚠️   DEPRECATION WARNING                                         ║"
            echo "╠══════════════════════════════════════════════════════════════════╣"
            echo "║                                                                  ║"
            printf "║  %-64s ║\n" "PHP ${CBOX_PHP_VERSION:-} reaches End-of-Life on ${CBOX_PHP_EOL:-unknown}"
            printf "║  %-64s ║\n" "This image will be removed on ${CBOX_REMOVAL_DATE:-unknown}"
            echo "║                                                                  ║"
            printf "║  %-64s ║\n" "Please upgrade to PHP 8.4 or 8.5"
            printf "║  %-64s ║\n" "Migration guide: https://cbox.com/docs/migration"
            echo "║                                                                  ║"
            printf "║  %-64s ║\n" "Suppress: CBOX_SUPPRESS_WARNINGS=true"
            echo "╚══════════════════════════════════════════════════════════════════╝"
            echo -e "${NC}"
            ;;

        eol)
            echo -e "${RED}"
            echo "╔══════════════════════════════════════════════════════════════════╗"
            echo "║  🚨  END-OF-LIFE WARNING                                         ║"
            echo "╠══════════════════════════════════════════════════════════════════╣"
            echo "║                                                                  ║"
            printf "║  %-64s ║\n" "PHP ${CBOX_PHP_VERSION:-} has reached End-of-Life!"
            printf "║  %-64s ║\n" "EOL Date: ${CBOX_PHP_EOL:-unknown}"
            echo "║                                                                  ║"
            printf "║  %-64s ║\n" "⚠️  No security updates are being provided"
            printf "║  %-64s ║\n" "This image will be REMOVED on ${CBOX_REMOVAL_DATE:-unknown}"
            echo "║                                                                  ║"
            printf "║  %-64s ║\n" "URGENT: Upgrade to PHP 8.4 or 8.5 immediately"
            printf "║  %-64s ║\n" "Migration guide: https://cbox.com/docs/migration"
            echo "║                                                                  ║"
            printf "║  %-64s ║\n" "Suppress: CBOX_SUPPRESS_WARNINGS=true"
            echo "╚══════════════════════════════════════════════════════════════════╝"
            echo -e "${NC}"
            ;;

        preview)
            echo -e "${BLUE}"
            echo "╔══════════════════════════════════════════════════════════════════╗"
            echo "║  🧪  PREVIEW RELEASE                                             ║"
            echo "╠══════════════════════════════════════════════════════════════════╣"
            echo "║                                                                  ║"
            printf "║  %-64s ║\n" "PHP ${CBOX_PHP_VERSION:-} ${CBOX_PREVIEW_STATUS:-beta}"
            echo "║                                                                  ║"
            printf "║  %-64s ║\n" "⚠️  This is a preview release for testing only"
            printf "║  %-64s ║\n" "NOT RECOMMENDED FOR PRODUCTION USE"
            echo "║                                                                  ║"
            printf "║  %-64s ║\n" "Report issues: https://github.com/cboxdk/php-baseimages/issues"
            echo "║                                                                  ║"
            printf "║  %-64s ║\n" "Suppress: CBOX_SUPPRESS_WARNINGS=true"
            echo "╚══════════════════════════════════════════════════════════════════╝"
            echo -e "${NC}"
            ;;

        removed)
            echo -e "${RED}"
            echo "╔══════════════════════════════════════════════════════════════════╗"
            echo "║  🛑  UNSUPPORTED IMAGE                                           ║"
            echo "╠══════════════════════════════════════════════════════════════════╣"
            echo "║                                                                  ║"
            printf "║  %-64s ║\n" "This PHP version is no longer supported!"
            printf "║  %-64s ║\n" "You are running an outdated, insecure image."
            echo "║                                                                  ║"
            printf "║  %-64s ║\n" "IMMEDIATE ACTION REQUIRED: Upgrade to PHP 8.4 or 8.5"
            echo "║                                                                  ║"
            echo "╚══════════════════════════════════════════════════════════════════╝"
            echo -e "${NC}"
            # Don't exit - let the container run but warn loudly
            ;;
    esac
}

# Note: Functions defined in sourced scripts are available to the sourcing script
# No need to export functions in POSIX sh - the function is available after sourcing
