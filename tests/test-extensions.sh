#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

IMAGE=$1

if [ -z "$IMAGE" ]; then
    echo -e "${RED}Error: No image specified${NC}"
    echo "Usage: $0 <image-name>"
    exit 1
fi

echo -e "${YELLOW}Testing PHP extensions in: $IMAGE${NC}"

# Required core extensions
REQUIRED_EXTENSIONS=(
    "opcache"
    "pdo_mysql"
    "pdo_pgsql"
    "mysqli"
    "pgsql"
    "zip"
    "intl"
    "bcmath"
    "redis"
    "apcu"
)

# Optional extensions (check but don't fail)
OPTIONAL_EXTENSIONS=(
    "gd"
    "imagick"
    "exif"
    "soap"
    "sockets"
    "pcntl"
    "xsl"
)

echo -e "\n${YELLOW}Checking required extensions...${NC}"
for ext in "${REQUIRED_EXTENSIONS[@]}"; do
    if docker run --rm "$IMAGE" php -m | grep -q "^$ext$"; then
        echo -e "${GREEN}✓${NC} $ext"
    else
        echo -e "${RED}✗${NC} $ext (MISSING - REQUIRED)"
        exit 1
    fi
done

echo -e "\n${YELLOW}Checking optional extensions...${NC}"
for ext in "${OPTIONAL_EXTENSIONS[@]}"; do
    if docker run --rm "$IMAGE" php -m | grep -q "^$ext$"; then
        echo -e "${GREEN}✓${NC} $ext"
    else
        echo -e "${YELLOW}○${NC} $ext (missing - optional)"
    fi
done

echo -e "\n${YELLOW}Checking Composer...${NC}"
if docker run --rm "$IMAGE" composer --version > /dev/null 2>&1; then
    COMPOSER_VERSION=$(docker run --rm "$IMAGE" composer --version)
    echo -e "${GREEN}✓${NC} $COMPOSER_VERSION"
else
    echo -e "${RED}✗${NC} Composer not found"
    exit 1
fi

echo -e "\n${YELLOW}Checking PHP version...${NC}"
PHP_VERSION=$(docker run --rm "$IMAGE" php -r "echo PHP_VERSION;")
echo -e "${GREEN}✓${NC} PHP $PHP_VERSION"

echo -e "\n${GREEN}All required extensions are present!${NC}"
