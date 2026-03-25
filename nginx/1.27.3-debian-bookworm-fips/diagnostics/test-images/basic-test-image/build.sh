#!/bin/bash
################################################################################
# Build Script for Nginx FIPS Basic Test Image
#
# This script builds a comprehensive test image that validates FIPS compliance
# in a user application context.
################################################################################

set -e

# Configuration
IMAGE_NAME="nginx-fips-test"
IMAGE_TAG="latest"
BASE_IMAGE="cr.root.io/nginx:1.27.3-debian-bookworm-fips"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "================================================================================"
echo "Building Nginx FIPS Basic Test Image"
echo "================================================================================"
echo ""

# Check if base image exists
if ! docker images "$BASE_IMAGE" --format "{{.Repository}}:{{.Tag}}" | grep -q "$BASE_IMAGE"; then
    echo -e "${RED}ERROR: Base image not found: $BASE_IMAGE${NC}"
    echo ""
    echo "Build the base image first:"
    echo "  cd ../../.."
    echo "  ./build.sh"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓${NC} Base image found: $BASE_IMAGE"
echo ""

# Build the test image
echo "Building test image..."
docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" .

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓${NC} Test image built successfully"
    echo ""
    echo "================================================================================"
    echo "Test Image Ready"
    echo "================================================================================"
    echo ""
    echo "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
    echo ""
    echo "Run tests:"
    echo "  docker run --rm ${IMAGE_NAME}:${IMAGE_TAG}"
    echo ""
    echo "Interactive shell:"
    echo "  docker run --rm -it ${IMAGE_NAME}:${IMAGE_TAG} /bin/bash"
    echo ""
    echo "================================================================================"
else
    echo ""
    echo -e "${RED}✗${NC} Build failed"
    exit 1
fi
