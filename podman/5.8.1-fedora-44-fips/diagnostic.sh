#!/bin/bash
################################################################################
# Podman 5.8.1 Fedora 44 FIPS - Diagnostic Runner
#
# Purpose: Execute FIPS validation diagnostics for Podman with wolfSSL integration
# Usage:
#   ./diagnostic.sh                    # Run all diagnostics
#   ./diagnostic.sh fips-test.sh       # Run specific test from tests/ directory
################################################################################

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

IMAGE_NAME="cr.root.io/podman:5.8.1-fedora-44-fips"
DIAGNOSTICS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/diagnostics"

echo ""
echo "================================================================================"
echo -e "${BOLD}${CYAN}Podman 5.8.1 Fedora 44 FIPS - Diagnostic Runner${NC}"
echo "================================================================================"
echo ""

# Check if image exists
if ! docker image inspect "$IMAGE_NAME" &> /dev/null; then
    echo -e "${RED}✗ ERROR: Image not found: $IMAGE_NAME${NC}"
    echo ""
    echo "Please build the image first:"
    echo "  ./build.sh"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓${NC} Image found: $IMAGE_NAME"

# Check if diagnostics directory exists
if [ ! -d "$DIAGNOSTICS_DIR" ]; then
    echo -e "${RED}✗ ERROR: Diagnostics directory not found: $DIAGNOSTICS_DIR${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Diagnostics directory: $DIAGNOSTICS_DIR"
echo ""

# Determine which test to run
if [ -z "$1" ]; then
    # Run all tests
    echo -e "${CYAN}Running all diagnostics...${NC}"
    echo ""

    docker run --rm \
        --user root \
        -v "$DIAGNOSTICS_DIR:/diagnostics" \
        -w /diagnostics \
        "$IMAGE_NAME" \
        bash -c './run-diagnostics.sh'

    EXIT_CODE=$?
else
    # Run specific test
    TEST_SCRIPT="$1"

    # Check in tests/ subdirectory first
    if [ -f "$DIAGNOSTICS_DIR/tests/$TEST_SCRIPT" ]; then
        TEST_PATH="tests/$TEST_SCRIPT"
    elif [ -f "$DIAGNOSTICS_DIR/$TEST_SCRIPT" ]; then
        TEST_PATH="$TEST_SCRIPT"
    else
        echo -e "${RED}✗ ERROR: Test script not found: $TEST_SCRIPT${NC}"
        echo ""
        echo "Available diagnostic scripts:"
        echo ""
        echo "Test scripts (tests/):"
        ls -1 "$DIAGNOSTICS_DIR/tests"/*.sh 2>/dev/null | xargs -n1 basename || echo "  (none)"
        echo ""
        echo "Root scripts:"
        ls -1 "$DIAGNOSTICS_DIR"/*.sh 2>/dev/null | xargs -n1 basename || echo "  (none)"
        echo ""
        exit 1
    fi

    echo -e "${CYAN}Running diagnostic: $TEST_PATH${NC}"
    echo ""

    # Run the specific test
    docker run --rm \
        --user root \
        -v "$DIAGNOSTICS_DIR:/diagnostics" \
        -w /diagnostics \
        "$IMAGE_NAME" \
        bash "$TEST_PATH" "$IMAGE_NAME"

    EXIT_CODE=$?
fi

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ Diagnostics completed successfully${NC}"
else
    echo -e "${RED}✗ Diagnostics failed with exit code: $EXIT_CODE${NC}"
fi
echo ""

exit $EXIT_CODE
