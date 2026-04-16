#!/bin/bash
# Build script for Fedora 44 with FIPS 140-3 support

set -e

# Configuration
IMAGE_NAME="cr.root.io/fedora"
IMAGE_TAG="44-fips"
export DOCKER_BUILDKIT=1

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  Building Fedora 44 with FIPS 140-3${NC}"
echo -e "${BLUE}  Crypto-Policies + OpenSSL FIPS Provider${NC}"
echo -e "${BLUE}================================================================${NC}"
echo -e "${GREEN}Image Name:${NC} $IMAGE_NAME:$IMAGE_TAG"
echo -e "${BLUE}================================================================${NC}"
echo ""

# Build the Docker image
echo -e "${YELLOW}Starting Docker build...${NC}"
echo ""

if docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" -f Dockerfile .; then
    echo ""
    echo -e "${GREEN}================================================================${NC}"
    echo -e "${GREEN}  Build Successful!${NC}"
    echo -e "${GREEN}================================================================${NC}"
    echo -e "${GREEN}Image:${NC} ${IMAGE_NAME}:${IMAGE_TAG}"
    echo ""

    # Run post-build verification
    echo -e "${YELLOW}Running post-build verification tests...${NC}"
    echo ""

    # Test 1: Check crypto-policies
    echo -e "${BLUE}Test 1: Checking crypto-policies configuration...${NC}"
    if docker run --rm "${IMAGE_NAME}:${IMAGE_TAG}" cat /etc/crypto-policies/config | grep -q "FIPS"; then
        echo -e "${GREEN}✓ Crypto-policies set to FIPS mode${NC}"
    else
        echo -e "${RED}✗ Crypto-policies check failed${NC}"
    fi
    echo ""

    # Test 2: Check OpenSSL FIPS provider
    echo -e "${BLUE}Test 2: Checking OpenSSL FIPS provider...${NC}"
    if docker run --rm "${IMAGE_NAME}:${IMAGE_TAG}" openssl list -providers | grep -qi fips; then
        echo -e "${GREEN}✓ OpenSSL FIPS provider available${NC}"
    else
        echo -e "${RED}✗ OpenSSL FIPS provider check failed${NC}"
    fi
    echo ""

    # Test 3: Run shell-based FIPS check
    echo -e "${BLUE}Test 3: Running comprehensive FIPS verification...${NC}"
    if docker run --rm -e SKIP_INTEGRITY_CHECK=true -e SKIP_DETAILED_CHECKS=true "${IMAGE_NAME}:${IMAGE_TAG}" /opt/fips/bin/fips_init_check.sh; then
        echo -e "${GREEN}✓ Shell-based FIPS verification passed${NC}"
    else
        echo -e "${RED}✗ Shell-based FIPS verification failed${NC}"
    fi
    echo ""

    echo -e "${GREEN}================================================================${NC}"
    echo -e "${GREEN}  All Post-Build Tests Completed!${NC}"
    echo -e "${GREEN}================================================================${NC}"
    echo ""
    echo -e "${BLUE}Image ready to use:${NC}"
    echo -e "  docker run -it ${IMAGE_NAME}:${IMAGE_TAG}"
    echo ""
    echo -e "${BLUE}Verify FIPS mode:${NC}"
    echo -e "  docker run --rm ${IMAGE_NAME}:${IMAGE_TAG} /opt/fips/bin/fips_init_check.sh"
    echo -e "  docker run --rm ${IMAGE_NAME}:${IMAGE_TAG} openssl list -providers"
    echo ""

else
    echo ""
    echo -e "${RED}================================================================${NC}"
    echo -e "${RED}  Build Failed!${NC}"
    echo -e "${RED}================================================================${NC}"
    exit 1
fi
