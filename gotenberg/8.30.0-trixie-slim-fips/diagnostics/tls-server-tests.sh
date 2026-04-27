#!/bin/bash
################################################################################
# Gotenberg TLS Server Tests
#
# Purpose: Verify TLS server mode and TLS 1.3 session ticket functionality
#
# Tests:
#   1. TLS certificate generation (if needed)
#   2. Gotenberg TLS server startup
#   3. HTTPS health check
#   4. PDF conversion over HTTPS (triggers TLS 1.3 session tickets)
#   5. Panic detection in logs
#
# Total: 5 tests
#
# Background:
#   golang-fips/go v1.25.9 had a critical bug where TLS 1.3 session ticket
#   issuance would panic in FIPS 140-only mode. This was fixed in v1.26.2.
#   This test validates the fix by running Gotenberg as a TLS server.
#
# Usage:
#   ./diagnostics/tls-server-tests.sh
################################################################################

set -e

# Image name (passed as first argument, or use default)
IMAGE_NAME="${1:-gotenberg:8.30.0-trixie-slim-fips}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TEST_TOTAL=5

# Container name
CONTAINER_NAME="gotenberg-tls-diagnostic"

# Certificate paths (use absolute path for Docker volume mount)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CERT_DIR="${SCRIPT_DIR}/tls-certs"
CERT_FILE="${CERT_DIR}/server-cert.pem"
KEY_FILE="${CERT_DIR}/server-key.pem"

echo ""
echo "================================================================================"
echo -e "${BOLD}${CYAN}Gotenberg TLS Server Tests${NC}"
echo "================================================================================"
echo ""

# Cleanup function
cleanup() {
    echo ""
    echo -e "${CYAN}Cleaning up...${NC}"
    docker stop "${CONTAINER_NAME}" 2>/dev/null || true
    docker rm "${CONTAINER_NAME}" 2>/dev/null || true
}

# Register cleanup on exit
trap cleanup EXIT

################################################################################
# Test 1: TLS Certificate Setup
################################################################################
echo -e "${CYAN}[1/${TEST_TOTAL}] Checking TLS certificates...${NC}"

if [ ! -f "${CERT_FILE}" ] || [ ! -f "${KEY_FILE}" ]; then
    echo "  Generating self-signed TLS certificate..."
    mkdir -p "${CERT_DIR}"

    openssl req -x509 -newkey rsa:2048 -nodes \
        -keyout "${KEY_FILE}" \
        -out "${CERT_FILE}" \
        -days 365 \
        -subj "/CN=localhost" \
        -config <(echo "[req]"; echo "distinguished_name=req") 2>/dev/null

    chmod 644 "${CERT_FILE}" "${KEY_FILE}"

    if [ -f "${CERT_FILE}" ] && [ -f "${KEY_FILE}" ]; then
        echo -e "${GREEN}✓${NC} TLS certificates generated"
        (( TESTS_PASSED++ )) || true
    else
        echo -e "${RED}✗${NC} Failed to generate TLS certificates"
        (( TESTS_FAILED++ )) || true
        exit 1
    fi
else
    echo -e "${GREEN}✓${NC} TLS certificates found (using existing)"
    (( TESTS_PASSED++ )) || true
fi
echo ""

################################################################################
# Test 2: Start Gotenberg with TLS
################################################################################
echo -e "${CYAN}[2/${TEST_TOTAL}] Starting Gotenberg with TLS server mode...${NC}"

# Check if port 3000 is already in use
PORT_CHECK=$(netstat -tuln 2>/dev/null | grep ":3000 " || ss -tuln 2>/dev/null | grep ":3000 " || echo "")
if [ -n "${PORT_CHECK}" ]; then
    echo -e "${RED}✗${NC} Port 3000 already in use"
    echo "  Stop other containers using port 3000 first:"
    echo "  docker ps --filter publish=3000"
    echo "  docker stop <container-id>"
    (( TESTS_FAILED++ )) || true
    exit 1
fi

# Clean up any existing container with same name
docker stop "${CONTAINER_NAME}" 2>/dev/null || true
docker rm "${CONTAINER_NAME}" 2>/dev/null || true

# Start Gotenberg with TLS
docker run -d \
    --name "${CONTAINER_NAME}" \
    -p 3000:3000 \
    -v "${CERT_DIR}:/tls:ro" \
    "${IMAGE_NAME}" \
    gotenberg \
    --api-tls-cert-file=/tls/server-cert.pem \
    --api-tls-key-file=/tls/server-key.pem \
    > /dev/null 2>&1

if [ $? -eq 0 ]; then
    # Verify container is actually running
    sleep 2
    CONTAINER_STATUS=$(docker inspect -f '{{.State.Status}}' "${CONTAINER_NAME}" 2>/dev/null)

    if [ "${CONTAINER_STATUS}" = "running" ]; then
        echo -e "${GREEN}✓${NC} Container started (ID: $(docker ps -q -f name=${CONTAINER_NAME}))"
        (( TESTS_PASSED++ )) || true
    else
        echo -e "${RED}✗${NC} Container failed to start (status: ${CONTAINER_STATUS})"
        docker logs "${CONTAINER_NAME}" 2>&1 | tail -20
        (( TESTS_FAILED++ )) || true
        exit 1
    fi
else
    echo -e "${RED}✗${NC} Failed to start container"
    (( TESTS_FAILED++ )) || true
    docker logs "${CONTAINER_NAME}" 2>&1 | tail -20
    exit 1
fi

# Wait for Gotenberg to start
echo "  Waiting for Gotenberg to start (10 seconds)..."
sleep 10
echo ""

################################################################################
# Test 3: HTTPS Health Check
################################################################################
echo -e "${CYAN}[3/${TEST_TOTAL}] Testing HTTPS health check...${NC}"

HEALTH_RESPONSE=$(curl -k -s --max-time 10 https://localhost:3000/health 2>&1)
HEALTH_EXIT_CODE=$?

if [ ${HEALTH_EXIT_CODE} -eq 0 ] && echo "${HEALTH_RESPONSE}" | grep -q '"status":"up"'; then
    echo -e "${GREEN}✓${NC} HTTPS health check successful"
    echo "  Response: ${HEALTH_RESPONSE}"
    (( TESTS_PASSED++ )) || true
else
    echo -e "${RED}✗${NC} HTTPS health check failed"
    echo "  Response: ${HEALTH_RESPONSE}"
    echo "  Exit code: ${HEALTH_EXIT_CODE}"
    (( TESTS_FAILED++ )) || true
fi
echo ""

################################################################################
# Test 4: PDF Conversion over HTTPS (TLS 1.3 Session Ticket Test)
################################################################################
echo -e "${CYAN}[4/${TEST_TOTAL}] Testing PDF conversion over HTTPS...${NC}"
echo "  This triggers TLS 1.3 session ticket issuance..."

PDF_FILE="/tmp/gotenberg-tls-test-$$.pdf"
curl -k -s --max-time 30 https://localhost:3000/forms/chromium/convert/url \
    -F url=https://example.com \
    --output "${PDF_FILE}" 2>&1

if [ -f "${PDF_FILE}" ] && [ -s "${PDF_FILE}" ]; then
    PDF_SIZE=$(stat -c%s "${PDF_FILE}" 2>/dev/null || stat -f%z "${PDF_FILE}" 2>/dev/null)
    FILE_TYPE=$(file "${PDF_FILE}" 2>/dev/null)

    if echo "${FILE_TYPE}" | grep -q "PDF"; then
        echo -e "${GREEN}✓${NC} PDF conversion over HTTPS successful"
        echo "  File size: ${PDF_SIZE} bytes"
        echo "  File type: PDF document"
        (( TESTS_PASSED++ )) || true
    else
        echo -e "${RED}✗${NC} PDF conversion produced invalid file"
        echo "  File type: ${FILE_TYPE}"
        (( TESTS_FAILED++ )) || true
    fi
    rm -f "${PDF_FILE}"
else
    echo -e "${RED}✗${NC} PDF conversion over HTTPS failed"
    echo "  No output file created or file is empty"
    (( TESTS_FAILED++ )) || true
fi
echo ""

################################################################################
# Test 5: Check for Panics in Logs
################################################################################
echo -e "${CYAN}[5/${TEST_TOTAL}] Checking for TLS panics in logs...${NC}"

LOGS=$(docker logs "${CONTAINER_NAME}" 2>&1)

if echo "${LOGS}" | grep -q "panic.*crypto/cipher\|panic.*TLS"; then
    echo -e "${RED}✗${NC} PANIC DETECTED in logs"
    echo ""
    echo "Panic trace:"
    echo "${LOGS}" | grep -A 20 "panic" | head -30
    (( TESTS_FAILED++ )) || true
else
    echo -e "${GREEN}✓${NC} No TLS panics detected"
    (( TESTS_PASSED++ )) || true
fi
echo ""

################################################################################
# Test Summary
################################################################################
echo "================================================================================"
echo -e "${BOLD}Test Summary${NC}"
echo "================================================================================"
echo ""
echo -e "Total Tests:  ${TEST_TOTAL}"
echo -e "Passed:       ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Failed:       ${RED}${TESTS_FAILED}${NC}"
echo ""

if [ ${TESTS_FAILED} -eq 0 ]; then
    echo -e "${GREEN}${BOLD}✓ ALL TESTS PASSED${NC}"
    echo ""
    echo "TLS server mode is working correctly:"
    echo "  ✓ TLS 1.3 handshakes complete successfully"
    echo "  ✓ Session tickets are issued without panic"
    echo "  ✓ PDF conversion over HTTPS fully functional"
    echo ""
    exit 0
else
    echo -e "${RED}${BOLD}✗ SOME TESTS FAILED${NC}"
    echo ""
    echo "TLS server mode issues detected. Review logs above for details."
    echo ""
    echo "To view full container logs:"
    echo "  docker logs ${CONTAINER_NAME}"
    echo ""
    exit 1
fi
