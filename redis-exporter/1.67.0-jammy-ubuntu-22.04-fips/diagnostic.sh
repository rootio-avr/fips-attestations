#!/bin/bash
################################################################################
# Redis Exporter FIPS Diagnostic Script
#
# Performs comprehensive diagnostics on redis_exporter FIPS image
# Usage: ./diagnostic.sh [test-name]
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

IMAGE_NAME="cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips"
DIAGNOSTICS_DIR="./diagnostics"

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Redis Exporter FIPS Diagnostics${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Check if image exists
if ! docker inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    echo -e "${RED}[ERROR]${NC} Image not found: $IMAGE_NAME"
    echo -e "${YELLOW}Tip:${NC} Build the image first: ./build.sh"
    exit 1
fi

# If specific test is requested, run it
if [ -n "$1" ]; then
    TEST_SCRIPT="$DIAGNOSTICS_DIR/$1"
    if [ -f "$TEST_SCRIPT" ]; then
        echo -e "${BLUE}Running specific test:${NC} $1"
        echo ""
        bash "$TEST_SCRIPT"
        exit $?
    else
        echo -e "${RED}[ERROR]${NC} Test script not found: $TEST_SCRIPT"
        echo -e "${YELLOW}Available tests:${NC}"
        ls -1 "$DIAGNOSTICS_DIR"/*.sh 2>/dev/null | xargs -n 1 basename || echo "  (none)"
        exit 1
    fi
fi

# Run all tests
echo -e "${BLUE}Running all diagnostic tests...${NC}"
echo ""

cd "$DIAGNOSTICS_DIR"

if [ -f "run-all-tests.sh" ]; then
    bash run-all-tests.sh
else
    echo -e "${RED}[ERROR]${NC} run-all-tests.sh not found in diagnostics/"
    exit 1
fi
