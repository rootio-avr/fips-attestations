#!/bin/bash
################################################################################
# Gotenberg FIPS Test Image - Build Script
#
# Purpose: Build test application image for Gotenberg FIPS validation
#
# Usage:
#   ./build.sh                    # Build with default tag
#   ./build.sh custom-tag         # Build with custom tag
#
# Prerequisites:
#   - cr.root.io/gotenberg:8.30.0-trixie-slim-fips image must be available
#   - Docker BuildKit enabled
#
################################################################################

set -e

# Configuration
IMAGE_NAME="gotenberg-test"
DEFAULT_TAG="8.30.0-trixie-slim-fips"
TAG="${1:-$DEFAULT_TAG}"
FULL_IMAGE="${IMAGE_NAME}:${TAG}"

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "================================================================================"
echo "Gotenberg FIPS Test Image - Build"
echo "================================================================================"
echo ""

# Verify base image exists
echo -e "${YELLOW}[1/3]${NC} Verifying base image..."
if ! docker image inspect cr.root.io/gotenberg:8.30.0-trixie-slim-fips >/dev/null 2>&1; then
    echo -e "${RED}✗ FAILED${NC}: Base image 'cr.root.io/gotenberg:8.30.0-trixie-slim-fips' not found"
    echo ""
    echo "Please build the base image first:"
    echo "  cd ../../../"
    echo "  ./build.sh"
    exit 1
fi
echo -e "${GREEN}✓ PASSED${NC}: Base image found"
echo ""

# Build test image
echo -e "${YELLOW}[2/3]${NC} Building test image: ${FULL_IMAGE}..."
docker build -t "${FULL_IMAGE}" .
echo -e "${GREEN}✓ PASSED${NC}: Test image built successfully"
echo ""

# Verify test binary
echo -e "${YELLOW}[3/3]${NC} Verifying test binary..."
if docker run --rm "${FULL_IMAGE}" --version 2>/dev/null; then
    echo -e "${GREEN}✓ PASSED${NC}: Test binary is functional"
else
    echo -e "${RED}✗ FAILED${NC}: Test binary verification failed"
    exit 1
fi
echo ""

echo "================================================================================"
echo "Build Complete"
echo "================================================================================"
echo ""
echo "Image: ${FULL_IMAGE}"
echo ""
echo "Run FIPS-only tests (no Gotenberg service needed):"
echo "  docker run --rm ${FULL_IMAGE} --fips-only"
echo ""
echo "Run ALL tests (requires running Gotenberg service):"
echo ""
echo "  Option 1: Using host network (recommended, simpler):"
echo "    # Start Gotenberg service"
echo "    docker run -d --name gotenberg-svc -p 3000:3000 cr.root.io/gotenberg:8.30.0-trixie-slim-fips"
echo "    # Run tests"
echo "    docker run --rm --network host ${FULL_IMAGE} --all"
echo "    # Cleanup"
echo "    docker stop gotenberg-svc && docker rm gotenberg-svc"
echo ""
echo "  Option 2: Using custom network:"
echo "    docker network create gotenberg-test-net"
echo "    docker run -d --name gotenberg-svc --network gotenberg-test-net -p 3000:3000 cr.root.io/gotenberg:8.30.0-trixie-slim-fips"
echo "    docker run --rm --network gotenberg-test-net ${FULL_IMAGE} --gotenberg-url http://gotenberg-svc:3000 --all"
echo "    docker stop gotenberg-svc && docker rm gotenberg-svc"
echo "    docker network rm gotenberg-test-net"
echo ""
