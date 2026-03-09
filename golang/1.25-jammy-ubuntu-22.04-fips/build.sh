#!/bin/bash
################################################################################
# Ubuntu FIPS Go - Build Script
#
# Purpose: Build golang Docker image with wolfSSL FIPS v5.8.2
#
# Usage:
#   ./build.sh           # Standard build with cache
#   ./build.sh --no-cache # Clean build without Docker cache
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
IMAGE_NAME="golang"
IMAGE_TAG="1.25-jammy-ubuntu-22.04-fips"
WOLFSSL_PASSWORD_FILE="wolfssl_password.txt"

echo ""
echo "================================================================================"
echo -e "${BOLD}${CYAN}Ubuntu FIPS Go - Build Script${NC}"
echo "================================================================================"
echo ""
echo "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
echo ""

# Check for wolfSSL password file
if [ ! -f "${WOLFSSL_PASSWORD_FILE}" ]; then
    echo -e "${RED}ERROR: Wolf SSL password file not found: ${WOLFSSL_PASSWORD_FILE}${NC}"
    echo ""
    echo "Please create the password file with your wolfSSL commercial package password:"
    echo "  echo 'your-password' > ${WOLFSSL_PASSWORD_FILE}"
    echo "  chmod 600 ${WOLFSSL_PASSWORD_FILE}"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓${NC} wolfSSL password file found"
echo ""

# Parse arguments
BUILD_ARGS=""
if [ "$1" = "--no-cache" ]; then
    BUILD_ARGS="--no-cache"
    echo -e "${YELLOW}Building with --no-cache (clean build)${NC}"
    echo ""
fi

# Build command
echo "================================================================================"
echo "Building Docker image..."
echo "================================================================================"
echo ""

docker build \
    ${BUILD_ARGS} \
    --secret id=wolfssl_password,src="${WOLFSSL_PASSWORD_FILE}" \
    -t "${IMAGE_NAME}:${IMAGE_TAG}" \
    .

BUILD_EXIT_CODE=$?

echo ""
echo "================================================================================"
if [ $BUILD_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ Build completed successfully${NC}"
    echo "================================================================================"
    echo ""
    echo "Run the image:"
    echo "  docker run --rm ${IMAGE_NAME}:${IMAGE_TAG}"
    echo ""
    echo "Run tests:"
    echo "  docker run --rm --entrypoint='' -v \$(pwd)/tests:/tests ${IMAGE_NAME}:${IMAGE_TAG} bash -c 'cd /tests && ./run-all-tests.sh'"
    echo ""
    echo "Interactive shell:"
    echo "  docker run --rm -it --entrypoint bash ${IMAGE_NAME}:${IMAGE_TAG}"
    echo ""
else
    echo -e "${RED}✗ Build failed with exit code: $BUILD_EXIT_CODE${NC}"
    echo "================================================================================"
    echo ""
    exit $BUILD_EXIT_CODE
fi
