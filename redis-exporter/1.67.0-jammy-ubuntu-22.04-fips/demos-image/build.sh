#!/bin/bash

# Redis Exporter FIPS Demo Image Build Script
# Builds a demo container that extends the base redis-exporter FIPS image

set -e

# Default values
IMAGE_NAME="redis-exporter-demos"
TAG="1.67.0-jammy-ubuntu-22.04-fips"
VERBOSE=false
NO_CACHE=false
BASE_IMAGE="cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips"

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

Build the Redis Exporter FIPS Demo Image

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
  $0 -b my-registry/redis-exporter:custom -v   # Custom base image with verbose output

NOTES:
  - The base redis-exporter FIPS image must be built first
  - This demo image contains configurations, scripts, and HTML dashboard
  - No additional packages are installed (uses base image tools)
  - Works with docker-compose.yml for full monitoring stack

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
echo -e "${GREEN}=== Redis Exporter FIPS Demo Image Build ===${NC}"
echo -e "${BLUE}Image Name:${NC} ${IMAGE_NAME}:${TAG}"
echo -e "${BLUE}Base Image:${NC} ${BASE_IMAGE}"
echo -e "${BLUE}Build Context:${NC} $(pwd)"
echo ""

# Check if Docker is running
echo -e "${YELLOW}Checking Docker availability...${NC}"
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running or not accessible${NC}"
    exit 1
fi
echo -e "${GREEN}Docker is running${NC}"

# Check if base image exists
echo -e "${YELLOW}Checking base image availability...${NC}"
if ! docker image inspect "${BASE_IMAGE}" > /dev/null 2>&1; then
    echo -e "${RED}Error: Base image '${BASE_IMAGE}' not found!${NC}"
    echo -e "${YELLOW}Please build the base redis-exporter FIPS image first:${NC}"
    echo "  cd .."
    echo "  ./build.sh"
    exit 1
fi
echo -e "${GREEN}Base image found${NC}"

# Verify demo files exist
echo -e "${YELLOW}Verifying demo files...${NC}"
REQUIRED_DIRS=(
    "configs"
    "scripts"
    "html"
)

MISSING_FILES=0
for dir in "${REQUIRED_DIRS[@]}"; do
    if [[ ! -d "$dir" ]]; then
        echo -e "${RED}Error: Directory '$dir' not found${NC}"
        MISSING_FILES=1
    else
        FILE_COUNT=$(find "$dir" -type f | wc -l)
        echo -e "  ${GREEN}✓${NC} $dir/ (${FILE_COUNT} files)"
    fi
done

if [[ $MISSING_FILES -eq 1 ]]; then
    echo -e "${RED}Error: Required demo files are missing${NC}"
    exit 1
fi

# Verify Dockerfile exists
if [[ ! -f "Dockerfile" ]]; then
    echo -e "${RED}Error: Dockerfile not found in current directory${NC}"
    exit 1
fi
echo -e "${GREEN}All demo files verified${NC}"

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

echo ""
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
    echo -e "${BLUE}Image Labels:${NC}"
    docker image inspect "${IMAGE_NAME}:${TAG}" --format "{{range \$k, \$v := .Config.Labels}}  {{\$k}}: {{\$v}}\n{{end}}"

    echo ""
    echo -e "${YELLOW}=== Usage Examples ===${NC}"
    echo ""
    echo -e "${BLUE}1. Run demo scripts:${NC}"
    echo "   docker run --rm ${IMAGE_NAME}:${TAG}"
    echo ""
    echo -e "${BLUE}2. Run specific demo:${NC}"
    echo "   docker run --rm ${IMAGE_NAME}:${TAG} /demo/scripts/test-fips-enforcement.sh"
    echo ""
    echo -e "${BLUE}3. Interactive shell:${NC}"
    echo "   docker run --rm -it ${IMAGE_NAME}:${TAG} /bin/bash"
    echo ""
    echo -e "${BLUE}4. Use with docker-compose:${NC}"
    echo "   # Update docker-compose.yml to use ${IMAGE_NAME}:${TAG}"
    echo "   docker-compose up -d"
    echo ""
    echo -e "${BLUE}5. Generate TLS certificates:${NC}"
    echo "   docker run --rm -v \$(pwd)/certs:/demo/certs ${IMAGE_NAME}:${TAG} /demo/scripts/setup-tls.sh"
    echo ""
    echo -e "${BLUE}6. Test metrics:${NC}"
    echo "   docker run --rm --network=host ${IMAGE_NAME}:${TAG} /demo/scripts/test-metrics.sh"
    echo ""

    echo -e "${YELLOW}=== Next Steps ===${NC}"
    echo ""
    echo "• Review demo documentation: cat README.md"
    echo "• Start full monitoring stack: docker-compose --profile monitoring up -d"
    echo "• Run FIPS validation tests: docker run --rm ${IMAGE_NAME}:${TAG} /demo/scripts/test-fips-enforcement.sh"
    echo ""

else
    echo ""
    echo -e "${RED}=== Build Failed ===${NC}"
    exit 1
fi
