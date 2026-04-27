#!/bin/bash
################################################################################
# Gotenberg FIPS - Build Script
#
# Purpose: Build Gotenberg Docker image with wolfSSL FIPS v5.8.2
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
IMAGE_NAME="cr.root.io/gotenberg"
IMAGE_TAG="8.30.0-trixie-slim-fips"
WOLFSSL_PASSWORD_FILE="wolfssl_password.txt"
ROOTIO_API_KEY_FILE="rootio_api_key.txt"

echo ""
echo "================================================================================"
echo -e "${BOLD}${CYAN}Gotenberg FIPS - Build Script${NC}"
echo "================================================================================"
echo ""
echo "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
echo "Architecture: Full FIPS Stack (golang-fips/go + system FIPS)"
echo ""

# Check for wolfSSL password file
if [ ! -f "${WOLFSSL_PASSWORD_FILE}" ]; then
    echo -e "${RED}ERROR: wolfSSL password file not found: ${WOLFSSL_PASSWORD_FILE}${NC}"
    echo ""
    echo "Please create the password file with your wolfSSL commercial package password:"
    echo "  echo 'your-password' > ${WOLFSSL_PASSWORD_FILE}"
    echo "  chmod 600 ${WOLFSSL_PASSWORD_FILE}"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓${NC} wolfSSL password file found"

# Check for Root.io API key file
if [ ! -f "${ROOTIO_API_KEY_FILE}" ]; then
    echo -e "${RED}ERROR: Root.io API key file not found: ${ROOTIO_API_KEY_FILE}${NC}"
    echo ""
    echo "Please create the API key file with your Root.io API key:"
    echo "  echo 'your-api-key' > ${ROOTIO_API_KEY_FILE}"
    echo "  chmod 600 ${ROOTIO_API_KEY_FILE}"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓${NC} Root.io API key file found"
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
echo ""
echo "Build stages:"
echo "  1. OpenSSL 3.5.0 builder"
echo "  2. wolfSSL FIPS v5.8.2 builder"
echo "  3. wolfProvider v1.1.1 builder"
echo "  4. golang-fips/go v1.26.2 builder"
echo "  5. Gotenberg 8.30.0 builder (with golang-fips/go)"
echo "  6. PDF tools builder"
echo "  7. Hyphen data extractor (from upstream)"
echo "  8. Final runtime (Chromium snapshot + LibreOffice + FIPS)"
echo ""
echo "Estimated build time: 45-60 minutes (full build)"
echo "================================================================================"
echo ""

docker build \
    ${BUILD_ARGS} \
    --secret id=wolfssl_password,src="${WOLFSSL_PASSWORD_FILE}" \
    --secret id=rootio_api_key,src="${ROOTIO_API_KEY_FILE}" \
    -t "${IMAGE_NAME}:${IMAGE_TAG}" \
    .

BUILD_EXIT_CODE=$?

echo ""
echo "================================================================================"
if [ $BUILD_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ Build completed successfully${NC}"
    echo "================================================================================"
    echo ""
    echo "Run the service:"
    echo "  docker run --rm -p 3000:3000 ${IMAGE_NAME}:${IMAGE_TAG}"
    echo ""
    echo "Run diagnostics:"
    echo "  ./diagnostic.sh"
    echo ""
    echo "Interactive shell:"
    echo "  docker run --rm -it --entrypoint bash --user root ${IMAGE_NAME}:${IMAGE_TAG}"
    echo ""
else
    echo -e "${RED}✗ Build failed with exit code: $BUILD_EXIT_CODE${NC}"
    echo "================================================================================"
    echo ""
    exit $BUILD_EXIT_CODE
fi
