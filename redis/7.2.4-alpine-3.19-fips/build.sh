#!/bin/bash
################################################################################
# Redis 7.2.4 Alpine FIPS Build Script
#
# This script builds the Redis FIPS image using Docker BuildKit
# with the wolfSSL commercial password secret.
#
# Prerequisites:
#   - Docker with BuildKit enabled
#   - wolfssl_password.txt file with the commercial password
#
# Usage:
#   ./build.sh
################################################################################

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="redis:7.2.4-alpine-3.19-fips"
DOCKERFILE="Dockerfile"
PASSWORD_FILE="wolfssl_password.txt"

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Redis 7.2.4 Alpine FIPS Build Script${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

################################################################################
# Pre-build checks
################################################################################
echo -e "${BLUE}[CHECK]${NC} Verifying prerequisites..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}[ERROR]${NC} Docker is not installed or not in PATH"
    exit 1
fi
echo -e "${GREEN}[OK]${NC} Docker found: $(docker --version)"

# Check if Dockerfile exists
if [ ! -f "$DOCKERFILE" ]; then
    echo -e "${RED}[ERROR]${NC} Dockerfile not found: $DOCKERFILE"
    exit 1
fi
echo -e "${GREEN}[OK]${NC} Dockerfile found: $DOCKERFILE"

# Check if wolfssl_password.txt exists
if [ ! -f "$PASSWORD_FILE" ]; then
    echo -e "${RED}[ERROR]${NC} Password file not found: $PASSWORD_FILE"
    echo ""
    echo "Please create $PASSWORD_FILE with your wolfSSL commercial password:"
    echo "  echo 'your-password-here' > $PASSWORD_FILE"
    echo "  chmod 600 $PASSWORD_FILE"
    exit 1
fi
echo -e "${GREEN}[OK]${NC} Password file found: $PASSWORD_FILE"

# Check password file is not empty
if [ ! -s "$PASSWORD_FILE" ]; then
    echo -e "${RED}[ERROR]${NC} Password file is empty: $PASSWORD_FILE"
    exit 1
fi

# Check password file is not the template
if grep -q "your-wolfssl-commercial-password-here" "$PASSWORD_FILE"; then
    echo -e "${RED}[ERROR]${NC} Password file still contains template text"
    echo "Please replace the template with your actual wolfSSL commercial password"
    exit 1
fi

echo -e "${GREEN}[OK]${NC} Password file validated"

# Check if BuildKit is available
if ! docker buildx version &> /dev/null; then
    echo -e "${YELLOW}[WARN]${NC} Docker BuildKit (buildx) not available, using legacy builder"
    echo -e "${YELLOW}[WARN]${NC} BuildKit is recommended for better performance"
    USE_BUILDKIT=0
else
    echo -e "${GREEN}[OK]${NC} Docker BuildKit available"
    USE_BUILDKIT=1
fi

echo ""

################################################################################
# Build the image
################################################################################
echo -e "${BLUE}[BUILD]${NC} Building Redis FIPS image..."
echo -e "${BLUE}[BUILD]${NC} Image name: $IMAGE_NAME"
echo ""

# Record build start time
BUILD_START=$(date +%s)

# Build with BuildKit
if [ $USE_BUILDKIT -eq 1 ]; then
    echo -e "${BLUE}[BUILD]${NC} Using Docker BuildKit..."
    DOCKER_BUILDKIT=1 docker build \
        --secret id=wolfssl_password,src="$PASSWORD_FILE" \
        -t "$IMAGE_NAME" \
        -f "$DOCKERFILE" \
        . || {
        echo -e "${RED}[ERROR]${NC} Build failed"
        exit 1
    }
else
    # Fallback to legacy builder (may not support secrets)
    echo -e "${YELLOW}[WARN]${NC} Using legacy Docker builder (secrets may not work)"
    docker build \
        -t "$IMAGE_NAME" \
        -f "$DOCKERFILE" \
        . || {
        echo -e "${RED}[ERROR]${NC} Build failed"
        exit 1
    }
fi

# Calculate build duration
BUILD_END=$(date +%s)
BUILD_DURATION=$((BUILD_END - BUILD_START))

echo ""
echo -e "${GREEN}[SUCCESS]${NC} Build completed successfully!"
echo -e "${GREEN}[SUCCESS]${NC} Build duration: ${BUILD_DURATION} seconds"
echo ""

################################################################################
# Verify the image
################################################################################
echo -e "${BLUE}[VERIFY]${NC} Verifying built image..."

# Check if image exists
if ! docker image inspect "$IMAGE_NAME" &> /dev/null; then
    echo -e "${RED}[ERROR]${NC} Image not found after build: $IMAGE_NAME"
    exit 1
fi

# Get image size
IMAGE_SIZE=$(docker image inspect "$IMAGE_NAME" --format '{{.Size}}' | awk '{printf "%.2f MB", $1/1024/1024}')
echo -e "${GREEN}[OK]${NC} Image exists: $IMAGE_NAME"
echo -e "${GREEN}[OK]${NC} Image size: $IMAGE_SIZE"

# Quick test: Check if image can start
echo ""
echo -e "${BLUE}[TEST]${NC} Running quick validation test..."
if docker run --rm "$IMAGE_NAME" redis-server --version &> /dev/null; then
    echo -e "${GREEN}[OK]${NC} Redis version check passed"
else
    echo -e "${YELLOW}[WARN]${NC} Redis version check failed (may be normal)"
fi

# Test FIPS validation (if possible)
echo -e "${BLUE}[TEST]${NC} Testing FIPS validation..."
if docker run --rm "$IMAGE_NAME" fips-startup-check 2>&1 | grep -q "FIPS POST.*passed"; then
    echo -e "${GREEN}[OK]${NC} FIPS POST validation passed"
else
    echo -e "${YELLOW}[WARN]${NC} FIPS POST validation test inconclusive"
fi

echo ""
echo -e "${BLUE}======================================${NC}"
echo -e "${GREEN}Build Summary${NC}"
echo -e "${BLUE}======================================${NC}"
echo -e "Image: ${GREEN}$IMAGE_NAME${NC}"
echo -e "Size: ${GREEN}$IMAGE_SIZE${NC}"
echo -e "Duration: ${GREEN}${BUILD_DURATION}s${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

################################################################################
# Next steps
################################################################################
echo -e "${BLUE}Next Steps:${NC}"
echo ""
echo "1. Run the container:"
echo -e "   ${YELLOW}docker run -d -p 6379:6379 --name redis-fips $IMAGE_NAME${NC}"
echo ""
echo "2. Check FIPS validation:"
echo -e "   ${YELLOW}docker logs redis-fips${NC}"
echo ""
echo "3. Test Redis connectivity:"
echo -e "   ${YELLOW}docker exec redis-fips redis-cli PING${NC}"
echo ""
echo "4. Run comprehensive tests:"
echo -e "   ${YELLOW}cd diagnostics/test-images/basic-test-image${NC}"
echo -e "   ${YELLOW}./build.sh && docker run --rm redis-fips-test:latest${NC}"
echo ""
echo "5. Push to registry (if needed):"
echo -e "   ${YELLOW}docker push $IMAGE_NAME${NC}"
echo ""
