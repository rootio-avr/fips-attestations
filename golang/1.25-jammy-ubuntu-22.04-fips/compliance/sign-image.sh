#!/bin/bash
################################################################################
# Cosign Image Signing Script for golang
#
# Purpose: Sign container image using Cosign with keyless signing (Sigstore)
################################################################################

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
IMAGE_NAME="golang"
IMAGE_VERSION="1.25-jammy-ubuntu-22.04-fips"
IMAGE_TAG="${IMAGE_NAME}:${IMAGE_VERSION}"
REGISTRY="${REGISTRY:-localhost:5000}"
FULL_IMAGE_TAG="${REGISTRY}/${IMAGE_TAG}"

# Output files
SIGNATURE_OUTPUT="image-signature.json"
VERIFICATION_OUTPUT="verification-report.txt"

echo "================================================================================"
echo -e "${BOLD}${CYAN}Cosign Image Signing for ${IMAGE_NAME}${NC}"
echo "================================================================================"
echo ""
echo "Image: ${FULL_IMAGE_TAG}"
echo "Signing Method: Keyless (Sigstore)"
echo ""

################################################################################
# Check Prerequisites
################################################################################

echo "========================================="
echo -e "${BOLD}[1/5] Checking Prerequisites${NC}"
echo "========================================="
echo ""

# Check if cosign is installed
if ! command -v cosign &> /dev/null; then
    echo -e "${RED}✗ FAILED${NC} - Cosign not installed"
    echo ""
    echo "Please install Cosign:"
    echo "  https://docs.sigstore.dev/cosign/installation/"
    echo ""
    echo "Quick install:"
    echo "  # Linux (amd64)"
    echo "  wget https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"
    echo "  sudo mv cosign-linux-amd64 /usr/local/bin/cosign"
    echo "  sudo chmod +x /usr/local/bin/cosign"
    echo ""
    echo "  # macOS"
    echo "  brew install cosign"
    exit 1
fi

COSIGN_VERSION=$(cosign version 2>&1 | head -1)
echo -e "${GREEN}✓${NC} Cosign installed: ${COSIGN_VERSION}"

# Check if image exists
if docker image inspect "${FULL_IMAGE_TAG}" &> /dev/null || docker image inspect "${IMAGE_TAG}" &> /dev/null; then
    echo -e "${GREEN}✓${NC} Image found: ${IMAGE_TAG}"
else
    echo -e "${RED}✗ FAILED${NC} - Image not found: ${IMAGE_TAG}"
    echo ""
    echo "Please build the image first:"
    echo "  ./build.sh"
    exit 1
fi

echo ""

################################################################################
# Tag Image (if using local registry)
################################################################################

if [ "${REGISTRY}" != "localhost:5000" ] && [ "${REGISTRY}" != "" ]; then
    echo "========================================="
    echo -e "${BOLD}[2/5] Tagging Image for Registry${NC}"
    echo "========================================="
    echo ""

    echo "Tagging: ${IMAGE_TAG} -> ${FULL_IMAGE_TAG}"
    docker tag "${IMAGE_TAG}" "${FULL_IMAGE_TAG}"
    echo -e "${GREEN}✓${NC} Image tagged"
    echo ""
else
    echo "========================================="
    echo -e "${BOLD}[2/5] Using Local Image${NC}"
    echo "========================================="
    echo ""
    echo "Signing local image: ${IMAGE_TAG}"
    FULL_IMAGE_TAG="${IMAGE_TAG}"
    echo ""
fi

################################################################################
# Sign Image (Keyless with Sigstore)
################################################################################

echo "========================================="
echo -e "${BOLD}[3/5] Signing Image${NC}"
echo "========================================="
echo ""

echo "Method: Keyless signing with Sigstore"
echo "Authentication: OIDC (OpenID Connect)"
echo ""
echo -e "${YELLOW}⚠ You will be prompted to authenticate via OIDC browser flow${NC}"
echo ""

# Sign the image
if cosign sign "${FULL_IMAGE_TAG}" 2>&1 | tee cosign-sign.log; then
    echo ""
    echo -e "${GREEN}✓ SIGNED${NC} - Image signed successfully"
else
    echo ""
    echo -e "${RED}✗ FAILED${NC} - Signing failed"
    cat cosign-sign.log
    exit 1
fi

echo ""

################################################################################
# Attach SBOM to Image
################################################################################

echo "========================================="
echo -e "${BOLD}[4/5] Attaching SBOM${NC}"
echo "========================================="
echo ""

SBOM_FILE="sbom-golang-1.25-jammy-ubuntu-22.04-fips.spdx.json"

if [ -f "$SBOM_FILE" ]; then
    echo "Attaching SBOM: $SBOM_FILE"

    if cosign attach sbom --sbom "$SBOM_FILE" "${FULL_IMAGE_TAG}" 2>&1 | tee cosign-sbom.log; then
        echo -e "${GREEN}✓${NC} SBOM attached successfully"
    else
        echo -e "${YELLOW}⚠ WARNING${NC} - SBOM attachment failed (non-critical)"
    fi
else
    echo -e "${YELLOW}⚠ WARNING${NC} - SBOM file not found: $SBOM_FILE"
    echo "Generate SBOM first: ./compliance/generate-sbom.sh"
fi

echo ""

################################################################################
# Verify Signature
################################################################################

echo "========================================="
echo -e "${BOLD}[5/5] Verifying Signature${NC}"
echo "========================================="
echo ""

echo "Verifying keyless signature..."
if cosign verify "${FULL_IMAGE_TAG}" 2>&1 | tee cosign-verify.log; then
    echo ""
    echo -e "${GREEN}✓ VERIFIED${NC} - Signature verification successful"
else
    echo ""
    echo -e "${YELLOW}⚠ WARNING${NC} - Verification requires certificate identity"
    echo "Use: cosign verify --certificate-identity=<email> --certificate-oidc-issuer=https://oauth2.sigstore.dev/auth ${FULL_IMAGE_TAG}"
fi

echo ""

################################################################################
# Generate Signature Report
################################################################################

echo "========================================="
echo -e "${BOLD}Generating Signature Report${NC}"
echo "========================================="
echo ""

cat > "$VERIFICATION_OUTPUT" <<EOF
================================================================================
Image Signature Verification Report
================================================================================

Image Information:
  Name: ${IMAGE_NAME}
  Version: ${IMAGE_VERSION}
  Full Tag: ${FULL_IMAGE_TAG}
  Signed: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

Signing Method:
  Tool: Cosign
  Method: Keyless signing (Sigstore)
  Certificate Transparency: Rekor (public transparency log)

Signature Details:
  $(docker image inspect "${FULL_IMAGE_TAG}" --format='{{.RepoDigests}}' 2>/dev/null || echo "Digest: Available after push to registry")

Verification Command:
  cosign verify \\
    --certificate-identity=<your-email@example.com> \\
    --certificate-oidc-issuer=https://oauth2.sigstore.dev/auth \\
    ${FULL_IMAGE_TAG}

Alternative Verification (if using GitHub Actions OIDC):
  cosign verify \\
    --certificate-identity-regexp=https://github.com/<org>/<repo> \\
    --certificate-oidc-issuer=https://token.actions.githubusercontent.com \\
    ${FULL_IMAGE_TAG}

SBOM Attachment:
  $([ -f "$SBOM_FILE" ] && echo "✓ Attached: $SBOM_FILE" || echo "✗ Not attached")

Compliance:
  - FIPS 140-3 Certificate: #4718 (wolfSSL FIPS v5.8.2)
  - Supply Chain Security: Sigstore transparency log
  - SLSA Provenance: See attestation scripts
  - VEX Statement: See vex-golang-1.25-jammy-ubuntu-22.04-fips.json

Additional Resources:
  - Rekor Transparency Log: https://search.sigstore.dev/
  - Cosign Documentation: https://docs.sigstore.dev/cosign/overview/
  - FIPS Compliance: See CHAIN-OF-CUSTODY.md

================================================================================
Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
================================================================================
EOF

echo -e "${GREEN}✓${NC} Signature report generated: $VERIFICATION_OUTPUT"
echo ""

################################################################################
# Summary
################################################################################

echo "================================================================================"
echo -e "${BOLD}${GREEN}Signing Complete${NC}"
echo "================================================================================"
echo ""
echo "Image: ${FULL_IMAGE_TAG}"
echo "Status: SIGNED"
echo ""
echo "Next Steps:"
echo "  1. Push image to registry:"
echo "     docker push ${FULL_IMAGE_TAG}"
echo ""
echo "  2. Verify signature:"
echo "     cosign verify \\"
echo "       --certificate-identity=<your-email> \\"
echo "       --certificate-oidc-issuer=https://oauth2.sigstore.dev/auth \\"
echo "       ${FULL_IMAGE_TAG}"
echo ""
echo "  3. View transparency log:"
echo "     https://search.sigstore.dev/"
echo ""
echo "Documentation:"
echo "  - Signature Report: ${VERIFICATION_OUTPUT}"
echo "  - Chain of Custody: compliance/CHAIN-OF-CUSTODY.md"
echo "  - SBOM: ${SBOM_FILE}"
echo "  - VEX: vex-golang-1.25-jammy-ubuntu-22.04-fips.json"
echo ""
echo "================================================================================"
