#!/bin/bash
################################################################################
# Backend Verification Tests
#
# Purpose: Verify wolfSSL FIPS, wolfProvider, and CGO integration
#
# Tests:
#   1. OpenSSL version verification
#   2. wolfProvider loading verification
#   3. wolfSSL FIPS library availability
#   4. CGO_ENABLED environment variable
#   5. OpenSSL configuration file
#   6. Provider status and activation
#
# Total: 6 tests
################################################################################

IMAGE_NAME="$1"

echo "================================================================================"
echo "Backend Verification Tests"
echo "================================================================================"
echo ""

PASSED=0
FAILED=0

################################################################################
# Test 1: OpenSSL Version Verification
################################################################################
echo "[1/6] OpenSSL version verification..."

if docker run --rm --entrypoint "" "${IMAGE_NAME}" openssl version 2>&1 | grep -q "OpenSSL 3.5"; then
    echo "✓ PASS: OpenSSL 3.5.x is installed"
    PASSED=$((PASSED + 1))
else
    echo "✗ FAIL: OpenSSL 3.5.x not found"
    FAILED=$((FAILED + 1))
fi

echo ""

################################################################################
# Test 2: wolfProvider Loading Verification
################################################################################
echo "[2/6] wolfProvider loading verification..."

PROVIDER_OUTPUT=$(docker run --rm --entrypoint "" "${IMAGE_NAME}" openssl list -providers 2>&1)

if echo "${PROVIDER_OUTPUT}" | grep -qE "wolfSSL Provider|fips.*active"; then
    echo "✓ PASS: wolfProvider is loaded"
    PASSED=$((PASSED + 1))
else
    echo "✗ FAIL: wolfProvider is not loaded"
    echo "Provider output: ${PROVIDER_OUTPUT}"
    FAILED=$((FAILED + 1))
fi

echo ""

################################################################################
# Test 3: wolfSSL FIPS Library Availability
################################################################################
echo "[3/6] wolfSSL FIPS library availability..."

if docker run --rm --entrypoint "" "${IMAGE_NAME}" sh -c "ls /usr/local/lib/libwolfssl.so* >/dev/null 2>&1"; then
    echo "✓ PASS: wolfSSL FIPS library is available"
    PASSED=$((PASSED + 1))
else
    echo "✗ FAIL: wolfSSL FIPS library not found"
    FAILED=$((FAILED + 1))
fi

echo ""

################################################################################
# Test 4: CGO_ENABLED Environment Variable
################################################################################
echo "[4/6] CGO_ENABLED environment variable..."

CGO_VALUE=$(docker run --rm --entrypoint "" "${IMAGE_NAME}" sh -c "echo \$CGO_ENABLED" 2>&1)

if [ "${CGO_VALUE}" = "1" ]; then
    echo "✓ PASS: CGO_ENABLED=1"
    PASSED=$((PASSED + 1))
else
    echo "✗ FAIL: CGO_ENABLED is not set to 1 (value: ${CGO_VALUE})"
    FAILED=$((FAILED + 1))
fi

echo ""

################################################################################
# Test 5: OpenSSL Configuration File
################################################################################
echo "[5/6] OpenSSL configuration file..."

if docker run --rm --entrypoint "" "${IMAGE_NAME}" test -f /etc/ssl/openssl.cnf; then
    if docker run --rm --entrypoint "" "${IMAGE_NAME}" grep -q "libwolfprov" /etc/ssl/openssl.cnf 2>/dev/null; then
        echo "✓ PASS: OpenSSL configuration file contains wolfProvider settings"
        PASSED=$((PASSED + 1))
    else
        echo "✗ FAIL: OpenSSL configuration does not contain wolfProvider settings"
        FAILED=$((FAILED + 1))
    fi
else
    echo "✗ FAIL: OpenSSL configuration file not found"
    FAILED=$((FAILED + 1))
fi

echo ""

################################################################################
# Test 6: Provider Status and Activation
################################################################################
echo "[6/6] Provider status and activation..."

if echo "${PROVIDER_OUTPUT}" | grep -q "status: active"; then
    echo "✓ PASS: wolfProvider is active"
    PASSED=$((PASSED + 1))
else
    echo "✗ FAIL: wolfProvider is not active"
    FAILED=$((FAILED + 1))
fi

echo ""

################################################################################
# Summary
################################################################################
echo "--------------------------------------------------------------------------------"
echo "Backend Verification: ${PASSED}/${6} tests passed"
echo "--------------------------------------------------------------------------------"
echo ""

# Exit with error if any test failed
if [ ${FAILED} -gt 0 ]; then
    exit 1
fi

exit 0
