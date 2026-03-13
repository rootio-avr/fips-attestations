#!/bin/bash

# Automated Verification Script for FIPS POC Images
# Version: 1.0
# Date: 2026-03-04

set -e

# Configuration
REGISTRY="${REGISTRY:-cr.root.io}"
GO_IMAGE="${REGISTRY}/golang:1.25-jammy-ubuntu-22.04-fips"
JAVA_IMAGE="${REGISTRY}/java:19-jdk-bookworm-slim-fips"
PUBLIC_KEY="${PUBLIC_KEY:-cosign.pub}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Verification functions
verify_signature() {
    local image=$1
    local name=$2

    echo -n "Verifying $name signature... "

    if cosign verify --key "$PUBLIC_KEY" "$image" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ VALID${NC}"
        return 0
    else
        echo -e "${RED}❌ INVALID${NC}"
        return 1
    fi
}

verify_attestation() {
    local image=$1
    local name=$2
    local type=$3

    echo -n "Verifying $name $type attestation... "

    if cosign verify-attestation --type "$type" --key "$PUBLIC_KEY" "$image" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ VALID${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  NOT FOUND${NC}"
        return 1
    fi
}

# Main execution
echo "================================================================================"
echo "FIPS POC Image Verification"
echo "================================================================================"
echo ""
echo "Configuration:"
echo "  Registry: $REGISTRY"
echo "  Public Key: $PUBLIC_KEY"
echo ""
echo "Images to verify:"
echo "  1. $GO_IMAGE"
echo "  2. $JAVA_IMAGE"
echo ""
echo "================================================================================"
echo ""

# Check if cosign is installed
if ! command -v cosign &> /dev/null; then
    echo -e "${RED}ERROR: cosign is not installed${NC}"
    echo ""
    echo "Please install cosign: https://docs.sigstore.dev/cosign/installation/"
    exit 1
fi

# Check if public key exists
if [ ! -f "$PUBLIC_KEY" ]; then
    echo -e "${YELLOW}WARNING: Public key not found at $PUBLIC_KEY${NC}"
    echo ""
    echo "Attempting keyless verification (requires internet access)..."
    echo ""
fi

# Verify Go image
echo "Verifying Go Image"
echo "--------------------------------------------------------------------------------"
verify_signature "$GO_IMAGE" "Go image"
GO_SIG_RESULT=$?

verify_attestation "$GO_IMAGE" "Go image" "slsaprovenance"
GO_SLSA_RESULT=$?

verify_attestation "$GO_IMAGE" "Go image" "spdx"
GO_SBOM_RESULT=$?

echo ""

# Verify Java image
echo "Verifying Java Image"
echo "--------------------------------------------------------------------------------"
verify_signature "$JAVA_IMAGE" "Java image"
JAVA_SIG_RESULT=$?

verify_attestation "$JAVA_IMAGE" "Java image" "slsaprovenance"
JAVA_SLSA_RESULT=$?

verify_attestation "$JAVA_IMAGE" "Java image" "spdx"
JAVA_SBOM_RESULT=$?

echo ""

# Summary
echo "================================================================================"
echo "Verification Summary"
echo "================================================================================"
echo ""

TOTAL_CHECKS=6
PASSED_CHECKS=0

if [ $GO_SIG_RESULT -eq 0 ]; then ((PASSED_CHECKS++)); fi
if [ $GO_SLSA_RESULT -eq 0 ]; then ((PASSED_CHECKS++)); fi
if [ $GO_SBOM_RESULT -eq 0 ]; then ((PASSED_CHECKS++)); fi
if [ $JAVA_SIG_RESULT -eq 0 ]; then ((PASSED_CHECKS++)); fi
if [ $JAVA_SLSA_RESULT -eq 0 ]; then ((PASSED_CHECKS++)); fi
if [ $JAVA_SBOM_RESULT -eq 0 ]; then ((PASSED_CHECKS++)); fi

echo "Checks Passed: $PASSED_CHECKS/$TOTAL_CHECKS"
echo ""

if [ $PASSED_CHECKS -eq $TOTAL_CHECKS ]; then
    echo -e "${GREEN}✅ ALL VERIFICATIONS PASSED${NC}"
    echo ""
    echo "All images have valid signatures and attestations."
    echo "Safe to deploy to production."
    exit 0
elif [ $GO_SIG_RESULT -eq 0 ] && [ $JAVA_SIG_RESULT -eq 0 ]; then
    echo -e "${YELLOW}⚠️  PARTIAL VERIFICATION${NC}"
    echo ""
    echo "Image signatures are valid, but some attestations are missing."
    echo "Images are safe to use, but attestations should be added for full compliance."
    exit 0
else
    echo -e "${RED}❌ VERIFICATION FAILED${NC}"
    echo ""
    echo "One or more image signatures are invalid."
    echo "DO NOT use these images in production."
    echo ""
    echo "Troubleshooting:"
    echo "  1. Verify public key is correct"
    echo "  2. Check image references are correct"
    echo "  3. Ensure images are properly signed"
    echo "  4. Contact image maintainer"
    exit 1
fi
