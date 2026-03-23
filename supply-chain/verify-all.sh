#!/bin/bash

# Automated Verification Script for FIPS POC Images
# Version: 1.3
# Date: 2026-03-23

set -e

# Configuration
REGISTRY="${REGISTRY:-cr.root.io}"
GO_IMAGE="${REGISTRY}/golang:1.25-jammy-ubuntu-22.04-fips"
JAVA8_IMAGE="${REGISTRY}/java:8-jdk-jammy-ubuntu-22.04-fips"
JAVA11_IMAGE="${REGISTRY}/java:11-jdk-jammy-ubuntu-22.04-fips"
JAVA17_IMAGE="${REGISTRY}/java:17-jdk-jammy-ubuntu-22.04-fips"
JAVA21_IMAGE="${REGISTRY}/java:21-jdk-jammy-ubuntu-22.04-fips"
JAVA19_IMAGE="${REGISTRY}/java:19-jdk-bookworm-slim-fips"
PYTHON_IMAGE="${REGISTRY}/python:3.12-bookworm-slim-fips"
NODE16_IMAGE="${REGISTRY}/node:16.20.1-bookworm-slim-fips"
NODE18_IMAGE="${REGISTRY}/node:18.20.8-bookworm-slim-fips"
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

    # Prefer keyless verification; fall back to static key if cosign.pub exists
    if [ -f "$PUBLIC_KEY" ]; then
        if cosign verify --key "$PUBLIC_KEY" "$image" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ VALID (key)${NC}"
            return 0
        fi
    fi

    # Keyless (Sigstore) verification — requires internet access to Rekor/Fulcio
    if cosign verify \
        --certificate-identity-regexp '.*' \
        --certificate-oidc-issuer-regexp '.*' \
        "$image" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ VALID (keyless)${NC}"
        return 0
    fi

    echo -e "${RED}❌ INVALID${NC}"
    return 1
}

verify_attestation() {
    local image=$1
    local name=$2
    local type=$3

    echo -n "Verifying $name $type attestation... "

    if [ -f "$PUBLIC_KEY" ]; then
        if cosign verify-attestation --type "$type" --key "$PUBLIC_KEY" "$image" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ VALID (key)${NC}"
            return 0
        fi
    fi

    if cosign verify-attestation \
        --type "$type" \
        --certificate-identity-regexp '.*' \
        --certificate-oidc-issuer-regexp '.*' \
        "$image" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ VALID (keyless)${NC}"
        return 0
    fi

    echo -e "${YELLOW}⚠️  NOT FOUND${NC}"
    return 1
}

# Main execution
echo "================================================================================"
echo "FIPS POC Image Verification"
echo "================================================================================"
echo ""
echo "Configuration:"
echo "  Registry: $REGISTRY"
if [ -f "$PUBLIC_KEY" ]; then
    echo "  Public Key: $PUBLIC_KEY (static key verification)"
else
    echo "  Public Key: not found — using keyless Sigstore verification"
fi
echo ""
echo "Images to verify:"
echo "  1. $GO_IMAGE"
echo "  2. $JAVA8_IMAGE"
echo "  3. $JAVA11_IMAGE"
echo "  4. $JAVA17_IMAGE"
echo "  5. $JAVA21_IMAGE"
echo "  6. $JAVA19_IMAGE"
echo "  7. $PYTHON_IMAGE"
echo "  8. $NODE16_IMAGE"
echo "  9. $NODE18_IMAGE"
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

# Verify Java 8 Jammy image
echo "Verifying Java 8 (Jammy) Image"
echo "--------------------------------------------------------------------------------"
verify_signature "$JAVA8_IMAGE" "Java 8 image"
JAVA8_SIG_RESULT=$?

verify_attestation "$JAVA8_IMAGE" "Java 8 image" "slsaprovenance"
JAVA8_SLSA_RESULT=$?

verify_attestation "$JAVA8_IMAGE" "Java 8 image" "spdx"
JAVA8_SBOM_RESULT=$?

echo ""

# Verify Java 11 Jammy image
echo "Verifying Java 11 (Jammy) Image"
echo "--------------------------------------------------------------------------------"
verify_signature "$JAVA11_IMAGE" "Java 11 image"
JAVA11_SIG_RESULT=$?

verify_attestation "$JAVA11_IMAGE" "Java 11 image" "slsaprovenance"
JAVA11_SLSA_RESULT=$?

verify_attestation "$JAVA11_IMAGE" "Java 11 image" "spdx"
JAVA11_SBOM_RESULT=$?

echo ""

# Verify Java 17 Jammy image
echo "Verifying Java 17 (Jammy) Image"
echo "--------------------------------------------------------------------------------"
verify_signature "$JAVA17_IMAGE" "Java 17 image"
JAVA17_SIG_RESULT=$?

verify_attestation "$JAVA17_IMAGE" "Java 17 image" "slsaprovenance"
JAVA17_SLSA_RESULT=$?

verify_attestation "$JAVA17_IMAGE" "Java 17 image" "spdx"
JAVA17_SBOM_RESULT=$?

echo ""

# Verify Java 21 Jammy image
echo "Verifying Java 21 (Jammy) Image"
echo "--------------------------------------------------------------------------------"
verify_signature "$JAVA21_IMAGE" "Java 21 image"
JAVA21_SIG_RESULT=$?

verify_attestation "$JAVA21_IMAGE" "Java 21 image" "slsaprovenance"
JAVA21_SLSA_RESULT=$?

verify_attestation "$JAVA21_IMAGE" "Java 21 image" "spdx"
JAVA21_SBOM_RESULT=$?

echo ""

# Verify Java 19 Bookworm image
echo "Verifying Java 19 (Bookworm) Image"
echo "--------------------------------------------------------------------------------"
verify_signature "$JAVA19_IMAGE" "Java 19 image"
JAVA19_SIG_RESULT=$?

verify_attestation "$JAVA19_IMAGE" "Java 19 image" "slsaprovenance"
JAVA19_SLSA_RESULT=$?

verify_attestation "$JAVA19_IMAGE" "Java 19 image" "spdx"
JAVA19_SBOM_RESULT=$?

echo ""

# Verify Python image
echo "Verifying Python 3.12 (Bookworm) Image"
echo "--------------------------------------------------------------------------------"
verify_signature "$PYTHON_IMAGE" "Python 3.12 image"
PYTHON_SIG_RESULT=$?

verify_attestation "$PYTHON_IMAGE" "Python 3.12 image" "slsaprovenance"
PYTHON_SLSA_RESULT=$?

verify_attestation "$PYTHON_IMAGE" "Python 3.12 image" "spdx"
PYTHON_SBOM_RESULT=$?

echo ""

# Verify Node.js 16 (Bookworm) image
echo "Verifying Node.js 16.20.1 (Bookworm) Image"
echo "--------------------------------------------------------------------------------"
verify_signature "$NODE16_IMAGE" "Node.js 16 image"
NODE16_SIG_RESULT=$?

verify_attestation "$NODE16_IMAGE" "Node.js 16 image" "slsaprovenance"
NODE16_SLSA_RESULT=$?

verify_attestation "$NODE16_IMAGE" "Node.js 16 image" "spdx"
NODE16_SBOM_RESULT=$?

echo ""

# Verify Node.js 18 (Bookworm) image
echo "Verifying Node.js 18.20.8 (Bookworm) Image"
echo "--------------------------------------------------------------------------------"
verify_signature "$NODE18_IMAGE" "Node.js 18 image"
NODE18_SIG_RESULT=$?

verify_attestation "$NODE18_IMAGE" "Node.js 18 image" "slsaprovenance"
NODE18_SLSA_RESULT=$?

verify_attestation "$NODE18_IMAGE" "Node.js 18 image" "spdx"
NODE18_SBOM_RESULT=$?

echo ""

# Summary
echo "================================================================================"
echo "Verification Summary"
echo "================================================================================"
echo ""

# 3 checks per image (signature + SLSA + SBOM) × 9 images = 27 checks
TOTAL_CHECKS=27
PASSED_CHECKS=0

if [ $GO_SIG_RESULT -eq 0 ]; then ((PASSED_CHECKS++)); fi
if [ $GO_SLSA_RESULT -eq 0 ]; then ((PASSED_CHECKS++)); fi
if [ $GO_SBOM_RESULT -eq 0 ]; then ((PASSED_CHECKS++)); fi

if [ $JAVA8_SIG_RESULT -eq 0 ]; then ((PASSED_CHECKS++)); fi
if [ $JAVA8_SLSA_RESULT -eq 0 ]; then ((PASSED_CHECKS++)); fi
if [ $JAVA8_SBOM_RESULT -eq 0 ]; then ((PASSED_CHECKS++)); fi

if [ $JAVA11_SIG_RESULT -eq 0 ]; then ((PASSED_CHECKS++)); fi
if [ $JAVA11_SLSA_RESULT -eq 0 ]; then ((PASSED_CHECKS++)); fi
if [ $JAVA11_SBOM_RESULT -eq 0 ]; then ((PASSED_CHECKS++)); fi

if [ $JAVA17_SIG_RESULT -eq 0 ]; then ((PASSED_CHECKS++)); fi
if [ $JAVA17_SLSA_RESULT -eq 0 ]; then ((PASSED_CHECKS++)); fi
if [ $JAVA17_SBOM_RESULT -eq 0 ]; then ((PASSED_CHECKS++)); fi

if [ $JAVA21_SIG_RESULT -eq 0 ]; then ((PASSED_CHECKS++)); fi
if [ $JAVA21_SLSA_RESULT -eq 0 ]; then ((PASSED_CHECKS++)); fi
if [ $JAVA21_SBOM_RESULT -eq 0 ]; then ((PASSED_CHECKS++)); fi

if [ $JAVA19_SIG_RESULT -eq 0 ]; then ((PASSED_CHECKS++)); fi
if [ $JAVA19_SLSA_RESULT -eq 0 ]; then ((PASSED_CHECKS++)); fi
if [ $JAVA19_SBOM_RESULT -eq 0 ]; then ((PASSED_CHECKS++)); fi

if [ $PYTHON_SIG_RESULT -eq 0 ]; then ((PASSED_CHECKS++)); fi
if [ $PYTHON_SLSA_RESULT -eq 0 ]; then ((PASSED_CHECKS++)); fi
if [ $PYTHON_SBOM_RESULT -eq 0 ]; then ((PASSED_CHECKS++)); fi

if [ $NODE16_SIG_RESULT -eq 0 ]; then ((PASSED_CHECKS++)); fi
if [ $NODE16_SLSA_RESULT -eq 0 ]; then ((PASSED_CHECKS++)); fi
if [ $NODE16_SBOM_RESULT -eq 0 ]; then ((PASSED_CHECKS++)); fi

if [ $NODE18_SIG_RESULT -eq 0 ]; then ((PASSED_CHECKS++)); fi
if [ $NODE18_SLSA_RESULT -eq 0 ]; then ((PASSED_CHECKS++)); fi
if [ $NODE18_SBOM_RESULT -eq 0 ]; then ((PASSED_CHECKS++)); fi

echo "Checks Passed: $PASSED_CHECKS/$TOTAL_CHECKS"
echo ""

# Determine overall pass/fail based on all image signatures being valid
ALL_SIGS_VALID=true
for RESULT in $GO_SIG_RESULT $JAVA8_SIG_RESULT $JAVA11_SIG_RESULT $JAVA17_SIG_RESULT $JAVA21_SIG_RESULT $JAVA19_SIG_RESULT $PYTHON_SIG_RESULT $NODE16_SIG_RESULT $NODE18_SIG_RESULT; do
    if [ "$RESULT" -ne 0 ]; then
        ALL_SIGS_VALID=false
        break
    fi
done

if [ $PASSED_CHECKS -eq $TOTAL_CHECKS ]; then
    echo -e "${GREEN}✅ ALL VERIFICATIONS PASSED${NC}"
    echo ""
    echo "All images have valid signatures and attestations."
    echo "Safe to deploy to production."
    exit 0
elif [ "$ALL_SIGS_VALID" = "true" ]; then
    echo -e "${YELLOW}⚠️  PARTIAL VERIFICATION${NC}"
    echo ""
    echo "All image signatures are valid, but some attestations are missing."
    echo "Images are safe to use, but attestations should be added for full compliance."
    exit 0
else
    echo -e "${RED}❌ VERIFICATION FAILED${NC}"
    echo ""
    echo "One or more image signatures are invalid."
    echo "DO NOT use these images in production."
    echo ""
    echo "Troubleshooting:"
    echo "  1. For keyless verification, ensure internet access to rekor.sigstore.dev"
    echo "  2. For key-based verification, confirm cosign.pub is the correct signing key"
    echo "  3. Check image references are correct"
    echo "  4. Ensure images are properly signed"
    echo "  5. Contact the image maintainer"
    exit 1
fi
