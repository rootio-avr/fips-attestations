#!/bin/bash
################################################################################
# Build Script for Redis FIPS Demo Image
################################################################################

set -e

IMAGE_NAME="redis-fips-demos"
IMAGE_TAG="latest"
BASE_IMAGE="cr.root.io/redis:7.2.4-alpine-fips"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo "================================================================================"
echo -e "${BLUE}Building Redis FIPS Demo Image${NC}"
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
echo "Building demo image..."
docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" .

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓${NC} Demo image built successfully"
    echo ""
    echo "================================================================================"
    echo -e "${GREEN}Demo Image Ready: ${IMAGE_NAME}:${IMAGE_TAG}${NC}"
    echo "================================================================================"
    echo ""
    echo "Run demos:"
    echo ""
    echo -e "${YELLOW}1. Persistence Demo (default)${NC}"
    echo "   docker run -d -p 6379:6379 --name redis-persistence \\"
    echo "     -v \$(pwd)/configs/persistence-demo.conf:/etc/redis/redis.conf:ro \\"
    echo "     ${IMAGE_NAME}:${IMAGE_TAG} redis-server /etc/redis/redis.conf"
    echo ""
    echo -e "${YELLOW}2. Pub/Sub Demo${NC}"
    echo "   docker run -d -p 6379:6379 --name redis-pubsub \\"
    echo "     -v \$(pwd)/configs/pubsub-demo.conf:/etc/redis/redis.conf:ro \\"
    echo "     ${IMAGE_NAME}:${IMAGE_TAG} redis-server /etc/redis/redis.conf"
    echo ""
    echo -e "${YELLOW}3. Memory Optimization Demo${NC}"
    echo "   docker run -d -p 6379:6379 --name redis-memory \\"
    echo "     -v \$(pwd)/configs/memory-optimization.conf:/etc/redis/redis.conf:ro \\"
    echo "     ${IMAGE_NAME}:${IMAGE_TAG} redis-server /etc/redis/redis.conf"
    echo ""
    echo -e "${YELLOW}4. Strict FIPS Demo${NC}"
    echo "   docker run -d -p 6379:6379 --name redis-strict \\"
    echo "     -v \$(pwd)/configs/strict-fips.conf:/etc/redis/redis.conf:ro \\"
    echo "     ${IMAGE_NAME}:${IMAGE_TAG} redis-server /etc/redis/redis.conf"
    echo ""
    echo -e "${YELLOW}5. TLS Demo${NC}"
    echo "   docker run -d -p 6379:6379 -p 6380:6380 --name redis-tls \\"
    echo "     -v \$(pwd)/configs/tls-demo.conf:/etc/redis/redis.conf:ro \\"
    echo "     ${IMAGE_NAME}:${IMAGE_TAG} redis-server /etc/redis/redis.conf"
    echo ""
    echo "================================================================================"
    echo "Test all demos interactively:"
    echo "  ./test-demos.sh"
    echo ""
    echo "Or test specific demo:"
    echo "  ./test-demos.sh persistence-demo"
    echo "  ./test-demos.sh pubsub-demo"
    echo "  ./test-demos.sh memory-optimization"
    echo "  ./test-demos.sh strict-fips"
    echo "  ./test-demos.sh tls-demo"
    echo "================================================================================"
else
    echo -e "${RED}✗${NC} Build failed"
    exit 1
fi
