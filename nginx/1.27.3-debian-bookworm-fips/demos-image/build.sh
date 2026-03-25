#!/bin/bash
################################################################################
# Build Script for Nginx FIPS Demo Image
################################################################################

set -e

IMAGE_NAME="nginx-fips-demos"
IMAGE_TAG="latest"
BASE_IMAGE="cr.root.io/nginx:1.27.3-debian-bookworm-fips"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "================================================================================"
echo "Building Nginx FIPS Demo Image"
echo "================================================================================"
echo ""

# Check if base image exists
if ! docker images "$BASE_IMAGE" --format "{{.Repository}}:{{.Tag}}" | grep -q "$BASE_IMAGE"; then
    echo -e "${RED}ERROR: Base image not found: $BASE_IMAGE${NC}"
    echo "Build the base image first: cd .. && ./build.sh"
    exit 1
fi

echo -e "${GREEN}✓${NC} Base image found"
echo ""

# Build demo image
docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" .

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓${NC} Demo image built successfully"
    echo ""
    echo "================================================================================"
    echo "Demo Image Ready: ${IMAGE_NAME}:${IMAGE_TAG}"
    echo "================================================================================"
    echo ""
    echo "Run demos:"
    echo "  # Reverse proxy demo (default)"
    echo "  docker run -d -p 443:443 ${IMAGE_NAME}:${IMAGE_TAG}"
    echo ""
    echo "  # Static webserver demo"
    echo "  docker run -d -p 443:443 -v \$(pwd)/configs/static-webserver.conf:/etc/nginx/nginx.conf:ro ${IMAGE_NAME}:${IMAGE_TAG}"
    echo ""
    echo "  # TLS termination demo"
    echo "  docker run -d -p 443:443 -v \$(pwd)/configs/tls-termination.conf:/etc/nginx/nginx.conf:ro ${IMAGE_NAME}:${IMAGE_TAG}"
    echo ""
    echo "  # Strict FIPS demo"
    echo "  docker run -d -p 443:443 -v \$(pwd)/configs/strict-fips.conf:/etc/nginx/nginx.conf:ro ${IMAGE_NAME}:${IMAGE_TAG}"
    echo ""
    echo "================================================================================"
else
    echo -e "${RED}✗${NC} Build failed"
    exit 1
fi
