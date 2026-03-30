#!/bin/bash
################################################################################
# Redis Exporter FIPS Test Image - Build Script
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

IMAGE_NAME="redis-exporter-1.67.0-fips-test"
IMAGE_TAG="latest"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Building Redis Exporter FIPS Test Image${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if base image exists
echo -e "${YELLOW}[1/3]${NC} Checking base image..."
if ! docker inspect cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips >/dev/null 2>&1; then
    echo -e "${RED}[FAIL]${NC} Base image not found"
    echo -e "${YELLOW}Tip:${NC} Build the base image first:"
    echo -e "      cd ../../.. && ./build.sh"
    exit 1
fi
echo -e "${GREEN}[OK]${NC} Base image found"
echo ""

# Build test image
echo -e "${YELLOW}[2/3]${NC} Building test image..."
if docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" .; then
    echo -e "${GREEN}[OK]${NC} Test image built successfully"
else
    echo -e "${RED}[FAIL]${NC} Build failed"
    exit 1
fi
echo ""

# Quick validation
echo -e "${YELLOW}[3/3]${NC} Validating test image..."
IMAGE_SIZE=$(docker images "${IMAGE_NAME}:${IMAGE_TAG}" --format "{{.Size}}")
echo -e "${GREEN}[OK]${NC} Image size: $IMAGE_SIZE"
echo ""

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ BUILD SUCCESSFUL${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Run tests:${NC}"
echo "  docker run --rm ${IMAGE_NAME}:${IMAGE_TAG}"
echo ""
echo -e "${YELLOW}Run with Redis server:${NC}"
echo "  docker run -d --name test-redis redis:7.2.4"
echo "  docker run --rm --link test-redis ${IMAGE_NAME}:${IMAGE_TAG}"
echo "  docker stop test-redis && docker rm test-redis"
echo ""
