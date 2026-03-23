#!/bin/bash

# FIPS Demo Applications Docker Image Build Script
# Builds a demo application container that extends the base FIPS Java image

set -e

# Default values
IMAGE_NAME="java-21-jdk-jammy-ubuntu-22.04-fips-demos"
TAG="latest"
VERBOSE=false
NO_CACHE=false
BASE_IMAGE="java:21-jdk-jammy-ubuntu-22.04-fips"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print usage information
usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Build the FIPS Demo Applications Docker image

OPTIONS:
  -n, --name NAME      Set image name (default: ${IMAGE_NAME})
  -t, --tag TAG        Set image tag (default: ${TAG})
  -b, --base BASE      Set base image (default: ${BASE_IMAGE})
  -c, --no-cache       Build without using Docker cache
  -v, --verbose        Enable verbose output
  -h, --help           Show this help message

EXAMPLES:
  $0                                    # Basic build
  $0 -n my-demos -t v1.0               # Custom name and tag
  $0 -b cr.root.io/java:21-jdk-jammy-ubuntu-22.04-fips:custom -v   # Custom base image with verbose output

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            IMAGE_NAME="$2"
            shift 2
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -b|--base)
            BASE_IMAGE="$2"
            shift 2
            ;;
        -c|--no-cache)
            NO_CACHE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}"
            usage
            exit 1
            ;;
    esac
done

# Print build configuration
echo -e "${GREEN}=== FIPS Demo Applications Build ===${NC}"
echo -e "${BLUE}Image Name:${NC} ${IMAGE_NAME}:${TAG}"
echo -e "${BLUE}Base Image:${NC} ${BASE_IMAGE}"
echo -e "${BLUE}Build Context:${NC} $(pwd)"
echo ""

# Check if base image exists
echo -e "${YELLOW}Checking base image availability...${NC}"
if ! docker image inspect "${BASE_IMAGE}" > /dev/null 2>&1; then
    echo -e "${RED}Error: Base image '${BASE_IMAGE}' not found!${NC}"
    echo -e "${YELLOW}Please build the base FIPS Java image first:${NC}"
    echo "  cd .."
    echo "  ./build.sh"
    exit 1
fi
echo -e "${GREEN}Base image found${NC}"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running or not accessible${NC}"
    exit 1
fi

# Verify source files exist
echo -e "${YELLOW}Verifying demo source files...${NC}"
DEMO_FILES=(
    "src/WolfJceBlockingDemo.java"
    "src/WolfJsseBlockingDemo.java"
    "src/MD5AvailabilityDemo.java"
    "src/KeyStoreFormatDemo.java"
)

for file in "${DEMO_FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo -e "${RED}Error: $(basename $file) not found at $file${NC}"
        exit 1
    fi
done
echo -e "${GREEN}All demo source files found (${#DEMO_FILES[@]} files)${NC}"

# Build Docker arguments
DOCKER_ARGS=()
if [[ "${NO_CACHE}" == "true" ]]; then
    DOCKER_ARGS+=(--no-cache)
fi
if [[ "${VERBOSE}" == "true" ]]; then
    DOCKER_ARGS+=(--progress=plain)
fi

# Add build args
DOCKER_ARGS+=(--build-arg BASE_IMAGE="${BASE_IMAGE}")

echo -e "${YELLOW}Starting Docker build...${NC}"
echo ""

# Build the Docker image
if docker build "${DOCKER_ARGS[@]}" -t "${IMAGE_NAME}:${TAG}" .; then
    echo ""
    echo -e "${GREEN}=== Build Successful ===${NC}"
    echo -e "${GREEN}Image:${NC} ${IMAGE_NAME}:${TAG}"

    # Show image details
    echo ""
    echo -e "${BLUE}Image Details:${NC}"
    IMAGE_SIZE=$(docker image inspect "${IMAGE_NAME}:${TAG}" --format "{{.Size}}")
    IMAGE_SIZE_MB=$((IMAGE_SIZE / 1024 / 1024))
    echo "  Size: ${IMAGE_SIZE_MB} MB"
    docker image inspect "${IMAGE_NAME}:${TAG}" --format "  Created: {{.Created}}"

    echo ""
    echo -e "${YELLOW}Test the image with:${NC}"
    echo "  docker run --rm ${IMAGE_NAME}:${TAG}"
    echo ""
    echo -e "${YELLOW}Run individual demos:${NC}"
    echo "  docker run --rm ${IMAGE_NAME}:${TAG} java -cp \"/app/demos:/opt/wolfssl-fips/bin:/usr/share/java/*\" WolfJceBlockingDemo"
    echo "  docker run --rm ${IMAGE_NAME}:${TAG} java -cp \"/app/demos:/opt/wolfssl-fips/bin:/usr/share/java/*\" WolfJsseBlockingDemo"
    echo "  docker run --rm ${IMAGE_NAME}:${TAG} java -cp \"/app/demos:/opt/wolfssl-fips/bin:/usr/share/java/*\" MD5AvailabilityDemo"
    echo "  docker run --rm ${IMAGE_NAME}:${TAG} java -cp \"/app/demos:/opt/wolfssl-fips/bin:/usr/share/java/*\" KeyStoreFormatDemo"
    echo ""
    echo -e "${YELLOW}Run with debug logging:${NC}"
    echo "  docker run --rm -e WOLFJCE_DEBUG=true -e WOLFJSSE_DEBUG=true ${IMAGE_NAME}:${TAG} java -cp \"/app/demos:/opt/wolfssl-fips/bin:/usr/share/java/*\" WolfJceBlockingDemo"

else
    echo ""
    echo -e "${RED}=== Build Failed ===${NC}"
    exit 1
fi
