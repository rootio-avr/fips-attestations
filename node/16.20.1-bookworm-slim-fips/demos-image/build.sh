#!/bin/bash
#
# Build script for Node.js FIPS demos image
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Image configuration
IMAGE_NAME="node-fips-demos"
IMAGE_TAG="16.20.1"
BASE_IMAGE="cr.root.io/node:16.20.1-bookworm-slim-fips"

echo ""
echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  Building Node.js FIPS Demos Image${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""

# Check if base image exists
echo -e "${YELLOW}Checking for base image...${NC}"
if ! docker image inspect "${BASE_IMAGE}" &> /dev/null; then
    echo -e "${RED}❌ Base image '${BASE_IMAGE}' not found${NC}"
    echo ""
    echo "Please build the base image first:"
    echo "  cd ../16.20.1-bookworm-slim-fips"
    echo "  ./build.sh"
    echo ""
    exit 1
fi
echo -e "${GREEN}✓ Base image found${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Build the image
echo -e "${YELLOW}Building demos image...${NC}"
echo ""

docker build \
    --tag "${IMAGE_NAME}:${IMAGE_TAG}" \
    --tag "${IMAGE_NAME}:latest" \
    .

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}================================================================${NC}"
    echo -e "${GREEN}✓ Build Successful${NC}"
    echo -e "${GREEN}================================================================${NC}"
    echo ""
    echo "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
    echo ""
    echo "Run the demos:"
    echo "  docker run --rm -it ${IMAGE_NAME}:${IMAGE_TAG}"
    echo ""
    echo "Run a specific demo:"
    echo "  docker run --rm node-fips-demos:${IMAGE_TAG} node /opt/demos/hash_algorithm_demo.js"
    echo ""
else
    echo ""
    echo -e "${RED}================================================================${NC}"
    echo -e "${RED}❌ Build Failed${NC}"
    echo -e "${RED}================================================================${NC}"
    echo ""
    exit 1
fi
