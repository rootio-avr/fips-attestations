#!/bin/bash
################################################################################
# Python 3.12 Bookworm FIPS - Diagnostic Runner
#
# Purpose: Execute FIPS validation diagnostics for Python wolfSSL integration
# Usage:
#   ./diagnostic.sh                        # Run all diagnostics
#   ./diagnostic.sh test-fips-status.sh    # Run specific shell diagnostic
#   ./diagnostic.sh test-backend-verification.py  # Run specific Python test
################################################################################

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

IMAGE_NAME="cr.root.io/python:3.12-bookworm-slim-fips"
DIAGNOSTICS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/diagnostics"

echo ""
echo "================================================================================"
echo -e "${BOLD}${CYAN}Python 3.12 Bookworm FIPS - Diagnostic Runner${NC}"
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
        --entrypoint="" \
        "$IMAGE_NAME" \
        bash -c 'cd /diagnostics && ./run-all-tests.sh'

    EXIT_CODE=$?
else
    # Run specific test
    TEST_SCRIPT="$1"

    # Check if test file exists
    if [ ! -f "$DIAGNOSTICS_DIR/$TEST_SCRIPT" ]; then
        echo -e "${RED}✗ ERROR: Test script not found: $TEST_SCRIPT${NC}"
        echo ""
        echo "Available diagnostic scripts:"
        echo ""
        echo "Shell scripts (.sh):"
        ls -1 "$DIAGNOSTICS_DIR"/*.sh 2>/dev/null || echo "  (none)"
        echo ""
        echo "Python tests (.py):"
        ls -1 "$DIAGNOSTICS_DIR"/*.py 2>/dev/null || echo "  (none)"
        echo ""
        exit 1
    fi

    echo -e "${CYAN}Running diagnostic: $TEST_SCRIPT${NC}"
    echo ""

    # Determine how to run the test based on extension
    if [[ "$TEST_SCRIPT" == *.py ]]; then
        # Python test
        docker run --rm \
            --user root \
            -v "$DIAGNOSTICS_DIR:/diagnostics" \
            --entrypoint="" \
            "$IMAGE_NAME" \
            python3 "/diagnostics/$TEST_SCRIPT"
    elif [[ "$TEST_SCRIPT" == *.sh ]]; then
        # Shell script
        docker run --rm \
            --user root \
            -v "$DIAGNOSTICS_DIR:/diagnostics" \
            --entrypoint="" \
            "$IMAGE_NAME" \
            bash "/diagnostics/$TEST_SCRIPT"
    else
        echo -e "${RED}✗ ERROR: Unknown test type: $TEST_SCRIPT${NC}"
        echo "Supported types: .py (Python), .sh (Shell)"
        exit 1
    fi

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
