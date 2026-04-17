#!/bin/bash
# Build script for Node.js 24.14.0 with wolfSSL FIPS 140-3 container on Debian Trixie

set -e

# Default values
IMAGE_NAME="cr.root.io/node"
IMAGE_TAG="24.14.0-trixie-slim-fips"
BUILD_ARGS=""
export DOCKER_BUILDKIT=1
: "${BUILDKIT_PROGRESS:=auto}"
VERBOSE_MODE=false

# wolfSSL password file
WOLFSSL_PASSWORD_FILE="wolfssl_password.txt"

# Root.io API key file
ROOTIO_API_KEY_FILE="rootio_api_key.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -n, --name NAME              Docker image name (default: cr.root.io/node)"
    echo "  -t, --tag TAG                Docker image tag (default: 24.14.0-trixie-slim-fips)"
    echo "  --no-cache                   Disable Docker build cache"
    echo "  --cache-from IMAGE           Use cache from existing image"
    echo "  -v, --verbose                Verbose Docker build output"
    echo "  -h, --help                   Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                           # Build with default settings"
    echo "  $0 --no-cache                # Build without cache"
    echo "  $0 -v                        # Verbose build output"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            IMAGE_NAME="$2"
            shift 2
            ;;
        -t|--tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        --no-cache)
            BUILD_ARGS="$BUILD_ARGS --no-cache"
            shift
            ;;
        --cache-from)
            BUILD_ARGS="$BUILD_ARGS --cache-from=$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE_MODE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option: $1${NC}"
            usage
            exit 1
            ;;
    esac
done

# Set verbose mode
if [ "$VERBOSE_MODE" = true ]; then
    BUILD_ARGS="$BUILD_ARGS --progress=plain"
    echo -e "${BLUE}Verbose mode enabled${NC}"
fi

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

# Check if Root.io API key file exists
if [ ! -f "$ROOTIO_API_KEY_FILE" ]; then
    echo -e "${RED}✗ ERROR: Root.io API key file not found: $ROOTIO_API_KEY_FILE${NC}"
    echo ""
    echo "Please create the file with your Root.io API key:"
    echo "  echo 'YOUR_API_KEY' > $ROOTIO_API_KEY_FILE"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓${NC} Root.io API key file found"
echo ""

# Display build information
echo ""
echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  Building Node.js 24.14.0 with wolfSSL FIPS 140-3${NC}"
echo -e "${BLUE}  Debian Trixie Base${NC}"
echo -e "${BLUE}================================================================${NC}"
echo -e "${GREEN}Image Name:${NC} $IMAGE_NAME:$IMAGE_TAG"
echo -e "${GREEN}Build Args:${NC} $BUILD_ARGS"
echo -e "${GREEN}Docker BuildKit:${NC} $DOCKER_BUILDKIT"
echo -e "${BLUE}================================================================${NC}"
echo ""

# Build the Docker image
echo -e "${YELLOW}Starting Docker build...${NC}"
echo ""

# Run docker build with wolfSSL password and Root.io API key as build secrets
if docker build \
    --secret id=wolfssl_password,src="$WOLFSSL_PASSWORD_FILE" \
    --secret id=rootio_api_key,src="$ROOTIO_API_KEY_FILE" \
    $BUILD_ARGS \
    -t "${IMAGE_NAME}:${IMAGE_TAG}" \
    -f Dockerfile \
    .; then

    echo ""
    echo -e "${GREEN}================================================================${NC}"
    echo -e "${GREEN}  Build Successful!${NC}"
    echo -e "${GREEN}================================================================${NC}"
    echo -e "${GREEN}Image:${NC} ${IMAGE_NAME}:${IMAGE_TAG}"
    echo ""

    # Run post-build verification
    echo -e "${YELLOW}Running post-build verification tests...${NC}"
    echo ""

    # Test 1: Verify Node.js version (skip FIPS checks for speed)
    echo -e "${BLUE}Test 1: Checking Node.js version...${NC}"
    if docker run --rm -e SKIP_INTEGRITY_CHECK=true -e SKIP_FIPS_CHECK=true "${IMAGE_NAME}:${IMAGE_TAG}" node --version; then
        echo -e "${GREEN}✓ Node.js version check passed${NC}"
    else
        echo -e "${RED}✗ Node.js version check failed${NC}"
        exit 1
    fi
    echo ""

    # Test 2: Verify npm version (skip FIPS checks for speed)
    echo -e "${BLUE}Test 2: Checking npm version...${NC}"
    if docker run --rm -e SKIP_INTEGRITY_CHECK=true -e SKIP_FIPS_CHECK=true "${IMAGE_NAME}:${IMAGE_TAG}" npm --version; then
        echo -e "${GREEN}✓ npm version check passed${NC}"
    else
        echo -e "${RED}✗ npm version check failed${NC}"
        exit 1
    fi
    echo ""

    # Test 3: Run FIPS validation script (skip entrypoint checks to avoid duplication)
    echo -e "${BLUE}Test 3: Running FIPS validation...${NC}"
    if docker run --rm -e SKIP_INTEGRITY_CHECK=true -e SKIP_FIPS_CHECK=true "${IMAGE_NAME}:${IMAGE_TAG}" node /opt/wolfssl-fips/bin/fips_init_check.js; then
        echo -e "${GREEN}✓ FIPS validation passed${NC}"
    else
        echo -e "${RED}✗ FIPS validation failed${NC}"
        exit 1
    fi
    echo ""

    echo -e "${GREEN}================================================================${NC}"
    echo -e "${GREEN}  All Post-Build Tests Passed!${NC}"
    echo -e "${GREEN}================================================================${NC}"
    echo ""
    echo -e "${BLUE}Image ready to use:${NC}"
    echo -e "  docker run -it ${IMAGE_NAME}:${IMAGE_TAG}"
    echo ""
    echo -e "${BLUE}To run with FIPS verification:${NC}"
    echo -e "  docker run -it ${IMAGE_NAME}:${IMAGE_TAG} node"
    echo ""
    echo -e "${BLUE}To skip FIPS verification (development only):${NC}"
    echo -e "  docker run -it -e SKIP_FIPS_CHECK=true ${IMAGE_NAME}:${IMAGE_TAG} node"
    echo ""
    echo -e "${BLUE}To run your Node.js application:${NC}"
    echo -e "  docker run -v \$(pwd):/app ${IMAGE_NAME}:${IMAGE_TAG} node your-app.js"
    echo ""

else
    echo ""
    echo -e "${RED}================================================================${NC}"
    echo -e "${RED}  Build Failed!${NC}"
    echo -e "${RED}================================================================${NC}"
    exit 1
fi
