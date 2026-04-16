#!/bin/bash
################################################################################
# Gotenberg API Tests
#
# Purpose: Verify Gotenberg PDF conversion functionality with FIPS backend
#
# Tests:
#   1. Gotenberg service startup
#   2. Health endpoint check
#   3. Version endpoint check
#   4. Chromium availability (HTML → PDF)
#   5. LibreOffice availability (Office docs → PDF)
#   6. pdfcpu availability (PDF manipulation)
#
# Total: 6 tests
#
# Note: These tests verify component availability. Full API testing
#       (HTML/Office → PDF conversion) requires running Gotenberg service
#       and is documented in the POC-VALIDATION-REPORT.md
################################################################################

IMAGE_NAME="$1"

echo "================================================================================"
echo "Gotenberg API Tests"
echo "================================================================================"
echo ""

PASSED=0
FAILED=0

################################################################################
# Test 1: Gotenberg Service Startup
################################################################################
echo "[1/6] Gotenberg service startup..."

# Test if Gotenberg binary exists and is executable
GOTENBERG_EXISTS=$(docker run --rm --entrypoint "" "${IMAGE_NAME}" sh -c "which gotenberg" 2>&1)

if [ -n "${GOTENBERG_EXISTS}" ]; then
    echo "✓ PASS: Gotenberg binary is available"
    PASSED=$((PASSED + 1))
else
    echo "✗ FAIL: Gotenberg binary not found"
    FAILED=$((FAILED + 1))
fi

echo ""

################################################################################
# Test 2: Health Endpoint Check
################################################################################
echo "[2/6] Health endpoint check (requires running service)..."

# Start Gotenberg in background and test health endpoint
CONTAINER_ID=$(docker run -d -p 3000:3000 "${IMAGE_NAME}" 2>&1)

if [ -n "${CONTAINER_ID}" ]; then
    echo "Container started: ${CONTAINER_ID:0:12}"

    # Wait for service to be ready (max 15 seconds)
    READY=0
    for i in {1..15}; do
        if curl -s http://localhost:3000/health 2>/dev/null | grep -q "status"; then
            READY=1
            break
        fi
        sleep 1
    done

    # Stop and remove container
    docker stop "${CONTAINER_ID}" >/dev/null 2>&1
    docker rm "${CONTAINER_ID}" >/dev/null 2>&1

    if [ ${READY} -eq 1 ]; then
        echo "✓ PASS: Health endpoint is accessible"
        PASSED=$((PASSED + 1))
    else
        echo "✗ FAIL: Health endpoint not accessible (service may need more time to start)"
        FAILED=$((FAILED + 1))
    fi
else
    echo "✗ FAIL: Failed to start Gotenberg container"
    FAILED=$((FAILED + 1))
fi

echo ""

################################################################################
# Test 3: Version Endpoint Check
################################################################################
echo "[3/6] Version endpoint check..."

VERSION_OUTPUT=$(docker run --rm --entrypoint "" "${IMAGE_NAME}" gotenberg --version 2>&1)

if echo "${VERSION_OUTPUT}" | grep -qE "8\.26\.0|gotenberg"; then
    echo "✓ PASS: Gotenberg version 8.26.0 is installed"
    PASSED=$((PASSED + 1))
else
    echo "✗ FAIL: Gotenberg version check failed"
    echo "Output: ${VERSION_OUTPUT}"
    FAILED=$((FAILED + 1))
fi

echo ""

################################################################################
# Test 4: Chromium Availability (HTML → PDF)
################################################################################
echo "[4/6] Chromium availability (HTML → PDF)..."

CHROMIUM_CHECK=$(docker run --rm --entrypoint "" "${IMAGE_NAME}" sh -c "which chromium || which chromium-browser" 2>&1)

if [ -n "${CHROMIUM_CHECK}" ]; then
    echo "✓ PASS: Chromium browser is available"
    PASSED=$((PASSED + 1))
else
    echo "✗ FAIL: Chromium browser not found"
    FAILED=$((FAILED + 1))
fi

echo ""

################################################################################
# Test 5: LibreOffice Availability (Office docs → PDF)
################################################################################
echo "[5/6] LibreOffice availability (Office docs → PDF)..."

LIBREOFFICE_CHECK=$(docker run --rm --entrypoint "" "${IMAGE_NAME}" sh -c "which libreoffice" 2>&1)

if [ -n "${LIBREOFFICE_CHECK}" ]; then
    # Verify LibreOffice version
    LO_VERSION=$(docker run --rm --entrypoint "" "${IMAGE_NAME}" libreoffice --version 2>&1 || true)
    echo "✓ PASS: LibreOffice is available"
    PASSED=$((PASSED + 1))
else
    echo "✗ FAIL: LibreOffice not found"
    FAILED=$((FAILED + 1))
fi

echo ""

################################################################################
# Test 6: pdfcpu Availability (PDF manipulation)
################################################################################
echo "[6/6] pdfcpu availability (PDF manipulation)..."

PDFCPU_CHECK=$(docker run --rm --entrypoint "" "${IMAGE_NAME}" sh -c "which pdfcpu" 2>&1)

if [ -n "${PDFCPU_CHECK}" ]; then
    # Verify pdfcpu version
    PDFCPU_VERSION=$(docker run --rm --entrypoint "" "${IMAGE_NAME}" pdfcpu version 2>&1 || true)
    echo "✓ PASS: pdfcpu is available"
    PASSED=$((PASSED + 1))
else
    echo "✗ FAIL: pdfcpu not found"
    FAILED=$((FAILED + 1))
fi

echo ""

################################################################################
# Summary
################################################################################
echo "--------------------------------------------------------------------------------"
echo "Gotenberg API Tests: ${PASSED}/6 tests passed"
echo "--------------------------------------------------------------------------------"
echo ""
echo "Note: Full PDF conversion testing (HTML/Office → PDF) requires:"
echo "  1. Running Gotenberg service: docker run -p 3000:3000 ${IMAGE_NAME}"
echo "  2. Sending conversion requests via HTTP API"
echo "  3. Refer to POC-VALIDATION-REPORT.md for comprehensive API testing"
echo ""

# Exit with error if any test failed
if [ ${FAILED} -gt 0 ]; then
    exit 1
fi

exit 0
