#!/bin/bash
#
# Build script for Python wolfSSL FIPS Test Image
#

set -e

# Default values
BASE_IMAGE="cr.root.io/python:3.12-bookworm-slim-fips"
IMAGE_NAME="python-fips-test"
IMAGE_TAG="latest"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  Building Python wolfSSL FIPS Test Image${NC}"
echo -e "${BLUE}================================================================${NC}"
echo -e "${GREEN}Base Image:${NC} $BASE_IMAGE"
echo -e "${GREEN}Target Image:${NC} $IMAGE_NAME:$IMAGE_TAG"
echo -e "${BLUE}================================================================${NC}"
echo ""

# Build the test image
if docker build \
    --build-arg BASE_IMAGE="$BASE_IMAGE" \
    -t "${IMAGE_NAME}:${IMAGE_TAG}" \
    -f Dockerfile \
    .; then

    echo ""
    echo -e "${GREEN}================================================================${NC}"
    echo -e "${GREEN}  Test Image Build Successful!${NC}"
    echo -e "${GREEN}================================================================${NC}"
    echo -e "${GREEN}Image:${NC} ${IMAGE_NAME}:${IMAGE_TAG}"
    echo ""
    echo -e "${BLUE}To run the test image:${NC}"
    echo -e "  docker run --rm ${IMAGE_NAME}:${IMAGE_TAG}"
    echo ""

else
    echo ""
    echo -e "${RED}================================================================${NC}"
    echo -e "${RED}  Test Image Build Failed!${NC}"
    echo -e "${RED}================================================================${NC}"
    exit 1
fi
