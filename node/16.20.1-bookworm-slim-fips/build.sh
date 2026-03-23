#!/bin/bash
################################################################################
# Node.js 16 Bookworm FIPS - Build Script
#
# Purpose: Build Node.js 16 container with wolfSSL FIPS 140-3 support
# Usage:
#   ./build.sh                    # Build with default settings
#   ./build.sh --no-cache         # Build without Docker cache
#   ./build.sh --platform linux/amd64  # Build for specific platform
#
# ⚠️  WARNING: Node.js 16.20.1 reached End-of-Life (EOL) on September 11, 2023
################################################################################

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Build configuration
IMAGE_NAME="node"
IMAGE_TAG="16.20.1-bookworm-slim-fips"
DOCKERFILE="Dockerfile"
BUILD_CONTEXT="."

# wolfSSL password file
WOLFSSL_PASSWORD_FILE="wolfssl_password.txt"

echo ""
echo "================================================================================"
echo -e "${BOLD}${CYAN}Node.js 16 with wolfSSL FIPS 140-3 - Build Script${NC}"
echo -e "${YELLOW}⚠️  Node.js 16 EOL: September 11, 2023 - Legacy Support Only${NC}"
echo "================================================================================"
echo ""

# Check if wolfSSL password file exists
if [ ! -f "$WOLFSSL_PASSWORD_FILE" ]; then
    echo -e "${RED}✗ ERROR: wolfSSL password file not found: $WOLFSSL_PASSWORD_FILE${NC}"
    echo ""
    echo "Please create the file with the wolfSSL FIPS package password:"
    echo "  echo 'YOUR_PASSWORD' > $WOLFSSL_PASSWORD_FILE"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓${NC} wolfSSL password file found"
echo ""

# Parse command-line arguments
BUILD_ARGS=""
for arg in "$@"; do
    case $arg in
        --no-cache)
            BUILD_ARGS="$BUILD_ARGS --no-cache"
            echo "Build mode: No cache"
            ;;
        --platform=*)
            PLATFORM="${arg#*=}"
            BUILD_ARGS="$BUILD_ARGS --platform=$PLATFORM"
            echo "Platform: $PLATFORM"
            ;;
        --progress=*)
            PROGRESS="${arg#*=}"
            BUILD_ARGS="$BUILD_ARGS --progress=$PROGRESS"
            ;;
        *)
            echo -e "${YELLOW}⚠ Unknown argument: $arg${NC}"
            ;;
    esac
done

echo ""
echo "Build Configuration:"
echo "  Image: $IMAGE_NAME:$IMAGE_TAG"
echo "  Dockerfile: $DOCKERFILE"
echo "  Build context: $BUILD_CONTEXT"
echo "  Build args: $BUILD_ARGS"
echo ""

# Prompt for confirmation
read -p "Proceed with build? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Build cancelled."
    exit 0
fi

echo ""
echo -e "${CYAN}Starting Docker build...${NC}"
echo ""

# Record start time
START_TIME=$(date +%s)

# Build the Docker image with wolfSSL password as build secret
if docker build \
    --secret id=wolfssl_password,src="$WOLFSSL_PASSWORD_FILE" \
    -t "$IMAGE_NAME:$IMAGE_TAG" \
    -f "$DOCKERFILE" \
    $BUILD_ARGS \
    "$BUILD_CONTEXT"; then

    # Record end time
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    MINUTES=$((DURATION / 60))
    SECONDS=$((DURATION % 60))

    echo ""
    echo "================================================================================"
    echo -e "${GREEN}✓ BUILD SUCCESSFUL${NC}"
    echo "================================================================================"
    echo ""
    echo "Image: $IMAGE_NAME:$IMAGE_TAG"
    echo "Build time: ${MINUTES}m ${SECONDS}s"
    echo ""

    # Display image info
    echo "Image details:"
    docker images "$IMAGE_NAME:$IMAGE_TAG" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
    echo ""

    # Suggest next steps
    echo -e "${CYAN}Next steps:${NC}"
    echo "  1. Run container:  docker run --rm -it $IMAGE_NAME:$IMAGE_TAG"
    echo "  2. Test FIPS:      docker run --rm $IMAGE_NAME:$IMAGE_TAG /test-fips"
    echo "  3. Run diagnostics: ./diagnostic.sh"
    echo ""

else
    # Build failed
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    MINUTES=$((DURATION / 60))
    SECONDS=$((DURATION % 60))

    echo ""
    echo "================================================================================"
    echo -e "${RED}✗ BUILD FAILED${NC}"
    echo "================================================================================"
    echo ""
    echo "Build time: ${MINUTES}m ${SECONDS}s"
    echo ""
    echo "Check the error messages above for details."
    echo ""
    exit 1
fi
