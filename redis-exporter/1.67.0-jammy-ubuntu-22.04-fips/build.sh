#!/bin/bash
################################################################################
# Redis Exporter FIPS Image Build Script
#
# Builds the redis_exporter v1.67.0 FIPS 140-3 compliant Docker image
#
# Usage:
#   ./build.sh                    # Build with default settings
#   ./build.sh --no-cache         # Build without cache
#   ./build.sh --verbose          # Build with verbose output
#   ./build.sh --push             # Build and push to registry
#
# Requirements:
#   - Docker with BuildKit support
#   - wolfssl_password.txt file with wolfSSL commercial password
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default configuration
IMAGE_NAME="cr.root.io/redis-exporter"
IMAGE_TAG="1.67.0-jammy-ubuntu-22.04-fips"
FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"
BUILD_ARGS=""
PUSH_IMAGE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-cache)
            BUILD_ARGS="$BUILD_ARGS --no-cache"
            shift
            ;;
        --verbose)
            BUILD_ARGS="$BUILD_ARGS --progress=plain"
            shift
            ;;
        --push)
            PUSH_IMAGE=true
            shift
            ;;
        --image-name)
            FULL_IMAGE_NAME="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --no-cache        Build without using cache"
            echo "  --verbose         Show verbose build output"
            echo "  --push            Push image to registry after build"
            echo "  --image-name NAME Use custom image name (default: $FULL_IMAGE_NAME)"
            echo "  --help            Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Run '$0 --help' for usage information"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Building Redis Exporter FIPS Image${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}[1/6]${NC} Validating prerequisites..."

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}[FAIL]${NC} Docker is not running"
    exit 1
fi
echo -e "${GREEN}[OK]${NC} Docker is running"

# Check if BuildKit is available
if ! docker buildx version >/dev/null 2>&1; then
    echo -e "${RED}[FAIL]${NC} Docker BuildKit not available"
    echo -e "${YELLOW}Tip:${NC} Ensure Docker 19.03+ is installed"
    exit 1
fi
echo -e "${GREEN}[OK]${NC} BuildKit is available"

# Check if wolfssl_password.txt exists
if [ ! -f "wolfssl_password.txt" ]; then
    echo -e "${RED}[FAIL]${NC} wolfssl_password.txt not found"
    echo -e "${YELLOW}Tip:${NC} Create wolfssl_password.txt with your wolfSSL commercial password:"
    echo -e "      echo 'your_password_here' > wolfssl_password.txt"
    echo -e "      chmod 600 wolfssl_password.txt"
    exit 1
fi
echo -e "${GREEN}[OK]${NC} wolfssl_password.txt exists"

# Check disk space (need at least 5 GB)
AVAILABLE_SPACE=$(df -BG . | tail -1 | awk '{print $4}' | sed 's/G//')
if [ "$AVAILABLE_SPACE" -lt 5 ]; then
    echo -e "${YELLOW}[WARN]${NC} Low disk space: ${AVAILABLE_SPACE}GB available (5GB+ recommended)"
else
    echo -e "${GREEN}[OK]${NC} Disk space: ${AVAILABLE_SPACE}GB available"
fi

echo ""

# Build the image
echo -e "${YELLOW}[2/6]${NC} Building Docker image..."
echo -e "${BLUE}Image:${NC} $FULL_IMAGE_NAME"
echo -e "${BLUE}Build Args:${NC} $BUILD_ARGS"
echo ""

START_TIME=$(date +%s)

# Enable BuildKit and build
export DOCKER_BUILDKIT=1
if docker build \
    --secret id=wolfssl_password,src=wolfssl_password.txt \
    -t "$FULL_IMAGE_NAME" \
    $BUILD_ARGS \
    -f Dockerfile \
    . ; then
    echo ""
    echo -e "${GREEN}[OK]${NC} Build completed successfully"
else
    echo ""
    echo -e "${RED}[FAIL]${NC} Build failed"
    exit 1
fi

END_TIME=$(date +%s)
BUILD_TIME=$((END_TIME - START_TIME))
echo -e "${BLUE}Build time:${NC} ${BUILD_TIME}s"
echo ""

# Get image size
echo -e "${YELLOW}[3/6]${NC} Checking image size..."
IMAGE_SIZE=$(docker images "$FULL_IMAGE_NAME" --format "{{.Size}}")
echo -e "${GREEN}[OK]${NC} Image size: $IMAGE_SIZE"
echo ""

# Verify image
echo -e "${YELLOW}[4/6]${NC} Verifying image..."
if docker inspect "$FULL_IMAGE_NAME" >/dev/null 2>&1; then
    echo -e "${GREEN}[OK]${NC} Image exists in local registry"
else
    echo -e "${RED}[FAIL]${NC} Image not found in local registry"
    exit 1
fi
echo ""

# Quick runtime test
echo -e "${YELLOW}[5/6]${NC} Running quick runtime test..."
if docker run --rm --entrypoint=/usr/local/bin/fips-check "$FULL_IMAGE_NAME" >/dev/null 2>&1; then
    echo -e "${GREEN}[OK]${NC} FIPS validation passed"
else
    echo -e "${RED}[FAIL]${NC} FIPS validation failed"
    echo -e "${YELLOW}Tip:${NC} Run diagnostic tests: ./diagnostic.sh"
    exit 1
fi

if docker run --rm --entrypoint=redis_exporter "$FULL_IMAGE_NAME" --version 2>&1 | grep -q "1.67.0"; then
    echo -e "${GREEN}[OK]${NC} redis_exporter version check passed"
else
    echo -e "${RED}[FAIL]${NC} redis_exporter version check failed"
    exit 1
fi
echo ""

# Push image (if requested)
if [ "$PUSH_IMAGE" = true ]; then
    echo -e "${YELLOW}[6/6]${NC} Pushing image to registry..."
    if docker push "$FULL_IMAGE_NAME"; then
        echo -e "${GREEN}[OK]${NC} Image pushed successfully"
    else
        echo -e "${RED}[FAIL]${NC} Failed to push image"
        exit 1
    fi
    echo ""
fi

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ BUILD SUCCESSFUL${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${BLUE}Image:${NC}       $FULL_IMAGE_NAME"
echo -e "${BLUE}Size:${NC}        $IMAGE_SIZE"
echo -e "${BLUE}Build Time:${NC}  ${BUILD_TIME}s"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Run the image:"
echo "     docker run -d -p 9121:9121 -e REDIS_ADDR=redis://redis:6379 $FULL_IMAGE_NAME"
echo ""
echo "  2. Test metrics endpoint:"
echo "     curl http://localhost:9121/metrics"
echo ""
echo "  3. Run diagnostics:"
echo "     ./diagnostic.sh"
echo ""
echo "  4. Run comprehensive tests:"
echo "     cd diagnostics/test-images/basic-test-image && ./build.sh && docker run --rm redis-exporter-fips-test:latest"
echo ""

if [ "$PUSH_IMAGE" = false ]; then
    echo -e "${YELLOW}Note:${NC} Image was NOT pushed to registry. Use --push flag to push."
    echo ""
fi
