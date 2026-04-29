#!/bin/bash
#
# Build script for Python wolfSSL FIPS Demos Image
#

set -e

# Default values
BASE_IMAGE="cr.root.io/python:3.13.7-bookworm-slim-fips"
IMAGE_NAME="python-fips-demos"
IMAGE_TAG="latest"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  Building Python wolfSSL FIPS Demos Image${NC}"
echo -e "${BLUE}================================================================${NC}"
echo -e "${GREEN}Base Image:${NC} $BASE_IMAGE"
echo -e "${GREEN}Target Image:${NC} $IMAGE_NAME:$IMAGE_TAG"
echo -e "${BLUE}================================================================${NC}"
echo ""

# Build the demos image
if docker build \
    --build-arg BASE_IMAGE="$BASE_IMAGE" \
    -t "${IMAGE_NAME}:${IMAGE_TAG}" \
    -f Dockerfile \
    .; then

    echo ""
    echo -e "${GREEN}================================================================${NC}"
    echo -e "${GREEN}  Demos Image Build Successful!${NC}"
    echo -e "${GREEN}================================================================${NC}"
    echo -e "${GREEN}Image:${NC} ${IMAGE_NAME}:${IMAGE_TAG}"
    echo ""
    echo -e "${BLUE}Available demos:${NC}"
    echo -e "  1. TLS/SSL Client Demo:"
    echo -e "     docker run --rm ${IMAGE_NAME}:${IMAGE_TAG} python3 tls_ssl_client_demo.py"
    echo ""
    echo -e "  2. Hash Algorithm Demo:"
    echo -e "     docker run --rm ${IMAGE_NAME}:${IMAGE_TAG} python3 hash_algorithm_demo.py"
    echo ""
    echo -e "  3. Requests Library Demo:"
    echo -e "     docker run --rm ${IMAGE_NAME}:${IMAGE_TAG} python3 requests_library_demo.py"
    echo ""
    echo -e "  4. Certificate Validation Demo:"
    echo -e "     docker run --rm ${IMAGE_NAME}:${IMAGE_TAG} python3 certificate_validation_demo.py"
    echo ""

else
    echo ""
    echo -e "${RED}================================================================${NC}"
    echo -e "${RED}  Demos Image Build Failed!${NC}"
    echo -e "${RED}================================================================${NC}"
    exit 1
fi
