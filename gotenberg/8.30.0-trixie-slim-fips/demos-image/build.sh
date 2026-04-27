#!/bin/bash
################################################################################
# Gotenberg FIPS Demos Image - Build Script
#
# Purpose: Build demonstration image with Gotenberg FIPS examples
#
# Usage:
#   ./build.sh                    # Build with default tag
#   ./build.sh custom-tag         # Build with custom tag
#
# Prerequisites:
#   - cr.root.io/gotenberg:8.30.0-trixie-slim-fips image must be available
#   - Docker BuildKit enabled
#
################################################################################

set -e

# Configuration
IMAGE_NAME="gotenberg-demos"
DEFAULT_TAG="8.30.0-trixie-slim-fips"
TAG="${1:-$DEFAULT_TAG}"
FULL_IMAGE="${IMAGE_NAME}:${TAG}"

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "================================================================================"
echo "Gotenberg FIPS Demos Image - Build"
echo "================================================================================"
echo ""

# Verify base image exists
echo -e "${YELLOW}[1/3]${NC} Verifying base image..."
if ! docker image inspect cr.root.io/gotenberg:8.30.0-trixie-slim-fips >/dev/null 2>&1; then
    echo -e "${RED}✗ FAILED${NC}: Base image 'cr.root.io/gotenberg:8.30.0-trixie-slim-fips' not found"
    echo ""
    echo "Please build the base image first:"
    echo "  cd ../"
    echo "  ./build.sh"
    exit 1
fi
echo -e "${GREEN}✓ PASSED${NC}: Base image found"
echo ""

# Build demos image
echo -e "${YELLOW}[2/3]${NC} Building demos image: ${FULL_IMAGE}..."
docker build -t "${FULL_IMAGE}" .
echo -e "${GREEN}✓ PASSED${NC}: Demos image built successfully"
echo ""

# Verify demos are available
echo -e "${YELLOW}[3/3]${NC} Verifying demos availability..."
if docker run --rm "${FULL_IMAGE}" sh -c "ls -1 /demos" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ PASSED${NC}: Demos are available"
else
    echo -e "${RED}✗ FAILED${NC}: Demos verification failed"
    exit 1
fi
echo ""

echo "================================================================================"
echo "Build Complete"
echo "================================================================================"
echo ""
echo "Image: ${FULL_IMAGE}"
echo ""
echo "Available demos:"
docker run --rm "${FULL_IMAGE}" sh -c "ls -1 /demos"
echo ""
echo "================================================================================"
echo "Usage Instructions"
echo "================================================================================"
echo ""
echo "1. List all available demos:"
echo "   docker run --rm ${FULL_IMAGE}"
echo ""
echo "2. Run FIPS verification demo (no Gotenberg service needed):"
echo "   docker run --rm ${FULL_IMAGE} /demos/fips-verification/run.sh"
echo ""
echo "3. Run HTML to PDF demo (requires Gotenberg service):"
echo ""
echo "   Option A: Using host network (recommended, simpler):"
echo "     # Start Gotenberg service"
echo "     docker run -d --name gotenberg-svc -p 3000:3000 cr.root.io/gotenberg:8.30.0-trixie-slim-fips"
echo "     # Run demo"
echo "     docker run --rm --network host ${FULL_IMAGE} /demos/html-to-pdf/run.sh"
echo "     # Cleanup"
echo "     docker stop gotenberg-svc && docker rm gotenberg-svc"
echo ""
echo "   Option B: Using custom network:"
echo "     # Create network"
echo "     docker network create gotenberg-demo-net"
echo "     # Start Gotenberg service"
echo "     docker run -d --name gotenberg-svc --network gotenberg-demo-net -p 3000:3000 cr.root.io/gotenberg:8.30.0-trixie-slim-fips"
echo "     # Run demo"
echo "     docker run --rm --network gotenberg-demo-net -e GOTENBERG_URL=http://gotenberg-svc:3000 ${FULL_IMAGE} /demos/html-to-pdf/run.sh"
echo "     # Cleanup"
echo "     docker stop gotenberg-svc && docker rm gotenberg-svc"
echo "     docker network rm gotenberg-demo-net"
echo ""
echo "4. Run Office to PDF demo (requires Gotenberg service):"
echo "   # Use same setup as HTML demo, then:"
echo "   docker run --rm --network host ${FULL_IMAGE} /demos/office-to-pdf/run.sh"
echo ""
echo "5. Run Webhook demo (requires Gotenberg service):"
echo "   # Use same setup as HTML demo, then:"
echo "   docker run --rm --network host ${FULL_IMAGE} /demos/webhook-demo/run.sh"
echo ""
echo "6. Interactive shell (explore demos):"
echo "   docker run -it --rm --network host ${FULL_IMAGE} /bin/bash"
echo "   # Then inside container: cd /demos/html-to-pdf && ./run.sh"
echo ""
echo "================================================================================"
echo ""
