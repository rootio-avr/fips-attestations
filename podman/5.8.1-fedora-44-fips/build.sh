#!/bin/bash
################################################################################
# Build script for FIPS-compliant Podman 5.8.1 image
################################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="${IMAGE_NAME:-podman}"
IMAGE_TAG="${IMAGE_TAG:-5.8.1-fedora-44-fips}"
FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"
SECRETS_FILE="${SECRETS_FILE:-wolfssl_password.txt}"
BUILD_LOG="${BUILD_LOG:-build.log}"

echo -e "${BLUE}================================================================================${NC}"
echo -e "${BLUE}Building FIPS-Compliant Podman 5.8.1 Image${NC}"
echo -e "${BLUE}================================================================================${NC}"
echo ""
echo -e "${GREEN}Image:${NC} ${FULL_IMAGE_NAME}"
echo -e "${GREEN}Build Log:${NC} ${BUILD_LOG}"
echo ""

# Check for secrets file
if [ ! -f "${SECRETS_FILE}" ]; then
    echo -e "${RED}ERROR: Secrets file not found: ${SECRETS_FILE}${NC}"
    echo ""
    echo "Please create a file named '${SECRETS_FILE}' containing the wolfSSL FIPS package password."
    echo "Example:"
    echo "  echo 'your-password-here' > ${SECRETS_FILE}"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓${NC} Secrets file found: ${SECRETS_FILE}"
echo ""

# Check for required files
echo -e "${YELLOW}Checking required files...${NC}"
REQUIRED_FILES=(
    "Dockerfile"
    "test-fips.c"
    "openssl.cnf"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo -e "${RED}✗${NC} Missing required file: $file"
        exit 1
    fi
    echo -e "${GREEN}✓${NC} Found: $file"
done
echo ""

# Check Docker/Podman availability
if command -v docker &> /dev/null; then
    BUILD_CMD="docker"
elif command -v podman &> /dev/null; then
    BUILD_CMD="podman"
else
    echo -e "${RED}ERROR: Neither docker nor podman command found${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Using build command: ${BUILD_CMD}"
echo ""

# Start build
echo -e "${BLUE}================================================================================${NC}"
echo -e "${BLUE}Starting Docker build...${NC}"
echo -e "${BLUE}================================================================================${NC}"
echo ""
echo -e "${YELLOW}This build will take approximately 20-30 minutes.${NC}"
echo -e "${YELLOW}Building 5 stages:${NC}"
echo "  1. wolfssl-builder  - Build OpenSSL 3.5.0 and wolfSSL FIPS v5"
echo "  2. wolfprov-builder - Build wolfProvider"
echo "  3. go-fips-builder  - Build golang-fips/go v1.25"
echo "  4. podman-builder   - Build Podman 5.8.1 from source"
echo "  5. runtime          - Final FIPS-compliant Podman image"
echo ""

# Build with BuildKit
export DOCKER_BUILDKIT=1

${BUILD_CMD} buildx build \
    --secret id=wolfssl_password,src="${SECRETS_FILE}" \
    --progress=plain \
    -t "${FULL_IMAGE_NAME}" \
    -f Dockerfile \
    . 2>&1 | tee "${BUILD_LOG}"

BUILD_EXIT_CODE=${PIPESTATUS[0]}

echo ""
echo -e "${BLUE}================================================================================${NC}"

if [ $BUILD_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ Build completed successfully!${NC}"
    echo ""
    echo -e "${GREEN}Image:${NC} ${FULL_IMAGE_NAME}"
    echo ""

    # Show image size
    IMAGE_SIZE=$(${BUILD_CMD} images "${FULL_IMAGE_NAME}" --format "{{.Size}}" 2>/dev/null || echo "unknown")
    echo -e "${GREEN}Size:${NC} ${IMAGE_SIZE}"
    echo ""

    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. Test the image:"
    echo "     ${BUILD_CMD} run --rm ${FULL_IMAGE_NAME} podman --version"
    echo ""
    echo "  2. Run FIPS diagnostics:"
    echo "     ${BUILD_CMD} run --rm ${FULL_IMAGE_NAME} test-fips"
    echo ""
    echo "  3. Interactive shell:"
    echo "     ${BUILD_CMD} run --rm -it ${FULL_IMAGE_NAME}"
    echo ""
    echo "  4. Run diagnostic test suite:"
    echo "     cd diagnostics && ./run-diagnostics.sh"
    echo ""
else
    echo -e "${RED}✗ Build failed!${NC}"
    echo ""
    echo -e "${YELLOW}Check the build log for details:${NC}"
    echo "  tail -n 100 ${BUILD_LOG}"
    echo ""
    exit 1
fi

echo -e "${BLUE}================================================================================${NC}"
