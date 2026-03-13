#!/bin/bash
################################################################################
# SBOM Generator for golang (CycloneDX Format via Trivy)
#
# Purpose: Generate Software Bill of Materials in CycloneDX JSON format by
#          scanning the built container image with Trivy.
#
# Usage:
#   ./generate-sbom.sh [IMAGE_REF]
#
#   IMAGE_REF   Full image reference to scan (default: golang:1.25-jammy-ubuntu-22.04-fips)
#               Can also be set via IMAGE_REF environment variable.
#
# Output:
#   compliance/SBOM-golang-1.25-jammy-ubuntu-22.04-fips.cdx.json  (local copy)
#   supply-chain/SBOM-golang-1.25-jammy-ubuntu-22.04-fips.cdx.json (consolidated copy)
################################################################################

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────

IMAGE_NAME="golang"
IMAGE_VERSION="1.25-jammy-ubuntu-22.04-fips"
REGISTRY="cr.root.io"
IMAGE_REF="${1:-${IMAGE_REF:-${REGISTRY}/${IMAGE_NAME}:${IMAGE_VERSION}}}"

SBOM_FILENAME="SBOM-${IMAGE_NAME}-${IMAGE_VERSION}.cdx.json"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

LOCAL_OUTPUT="${SCRIPT_DIR}/${SBOM_FILENAME}"
SUPPLY_CHAIN_OUTPUT="${REPO_ROOT}/supply-chain/${SBOM_FILENAME}"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "================================================================================"
echo "Generating CycloneDX SBOM for ${IMAGE_REF}"
echo "Started: ${TIMESTAMP}"
echo "================================================================================"
echo ""

# ── Preflight checks ──────────────────────────────────────────────────────────

if ! command -v trivy >/dev/null 2>&1; then
    echo "✗ ERROR: trivy is not installed or not in PATH."
    echo "  Install: https://aquasecurity.github.io/trivy/latest/getting-started/installation/"
    exit 1
fi

TRIVY_VERSION=$(trivy --version 2>/dev/null | head -1 | awk '{print $2}')
echo "✓ Trivy version: ${TRIVY_VERSION}"

if ! command -v docker >/dev/null 2>&1; then
    echo "✗ ERROR: docker is not installed or not in PATH."
    exit 1
fi

echo "✓ Checking image: ${IMAGE_REF}"
if ! docker image inspect "${IMAGE_REF}" >/dev/null 2>&1; then
    echo "✗ ERROR: Image '${IMAGE_REF}' not found locally."
    echo "  Build the image first:"
    echo "    cd golang/1.25-jammy-ubuntu-22.04-fips && ./build.sh"
    echo "  Or pull it:"
    echo "    docker pull ${IMAGE_REF}"
    echo ""
    echo "  To scan a locally tagged image, pass it as an argument:"
    echo "    ./generate-sbom.sh golang:1.25-jammy-ubuntu-22.04-fips"
    exit 1
fi

echo "✓ Image found"
echo ""

# ── Generate SBOM ─────────────────────────────────────────────────────────────

echo "Scanning image with Trivy (format: cyclonedx, scanners: vuln,license)..."
echo ""

trivy image \
    --format cyclonedx \
    --scanners vuln,license \
    --output "${LOCAL_OUTPUT}" \
    "${IMAGE_REF}"

if [[ ! -f "${LOCAL_OUTPUT}" ]]; then
    echo "✗ ERROR: Trivy did not produce output file: ${LOCAL_OUTPUT}"
    exit 1
fi

echo ""
echo "✓ SBOM generated: ${LOCAL_OUTPUT}"

# ── Copy to supply-chain directory ────────────────────────────────────────────

if [[ -d "${REPO_ROOT}/supply-chain" ]]; then
    cp "${LOCAL_OUTPUT}" "${SUPPLY_CHAIN_OUTPUT}"
    echo "✓ Copied to:      ${SUPPLY_CHAIN_OUTPUT}"
else
    echo "⚠ supply-chain/ directory not found at ${REPO_ROOT}/supply-chain — skipping copy"
fi

echo ""

# ── Validate JSON ─────────────────────────────────────────────────────────────

if command -v python3 >/dev/null 2>&1; then
    if python3 -c "import json, sys; json.load(open('${LOCAL_OUTPUT}'))" 2>/dev/null; then
        echo "✓ JSON validation: PASSED"
    else
        echo "✗ JSON validation: FAILED — output file may be malformed"
        exit 1
    fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────

COMPONENT_COUNT=0
VULN_COUNT=0
if command -v python3 >/dev/null 2>&1; then
    COMPONENT_COUNT=$(python3 -c "
import json
data = json.load(open('${LOCAL_OUTPUT}'))
print(len(data.get('components', [])))
" 2>/dev/null || echo "0")

    VULN_COUNT=$(python3 -c "
import json
data = json.load(open('${LOCAL_OUTPUT}'))
print(len(data.get('vulnerabilities', [])))
" 2>/dev/null || echo "0")
fi

echo ""
echo "================================================================================"
echo "SBOM Summary"
echo "================================================================================"
echo "Image:       ${IMAGE_REF}"
echo "Format:      CycloneDX JSON"
echo "Generated:   ${TIMESTAMP}"
echo "Components:  ${COMPONENT_COUNT}"
echo "CVEs found:  ${VULN_COUNT}"
echo ""
echo "Output files:"
echo "  ${LOCAL_OUTPUT}"
[[ -f "${SUPPLY_CHAIN_OUTPUT}" ]] && echo "  ${SUPPLY_CHAIN_OUTPUT}"
echo ""
echo "✓ SBOM generation complete"
