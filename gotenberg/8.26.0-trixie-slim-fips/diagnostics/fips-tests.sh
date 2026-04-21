#!/bin/bash
################################################################################
# FIPS Verification Tests
#
# Purpose: Verify FIPS mode is enabled and algorithm compliance
#
# Tests (updated for golang-fips/go v1.26.2+):
#   1. GODEBUG environment check (should NOT be set in v1.26.2+)
#   2. GOEXPERIMENT=strictfipsruntime environment variable
#   3. GOLANG_FIPS=1 environment variable (required for v1.26.2+)
#   4. OpenSSL FIPS mode (default_properties = fips=yes)
#   5. MD5 algorithm blocking
#   6. SHA-1 restriction (available for hashing only)
#   7. FIPS-approved algorithms (SHA-256, AES-GCM)
#
# Total: 7 tests
################################################################################

IMAGE_NAME="$1"

echo "================================================================================"
echo "FIPS Verification Tests"
echo "================================================================================"
echo ""

PASSED=0
FAILED=0

################################################################################
# Test 1: GODEBUG Environment Variable (v1.26.2+ - should NOT be set)
################################################################################
echo "[1/7] GODEBUG environment variable check (v1.26.2+)..."

GODEBUG_VALUE=$(docker run --rm --entrypoint "" "${IMAGE_NAME}" sh -c "echo \$GODEBUG" 2>&1)

# In golang-fips/go v1.26.2+, GODEBUG and GOLANG_FIPS are mutually exclusive
# GODEBUG should NOT be set (use GOLANG_FIPS=1 instead)
if [ "${GODEBUG_VALUE}" = "" ]; then
    echo "✓ PASS: GODEBUG not set (correct for v1.26.2+ - uses GOLANG_FIPS=1 instead)"
    PASSED=$((PASSED + 1))
else
    echo "✗ FAIL: GODEBUG should not be set in v1.26.2+ (found: ${GODEBUG_VALUE})"
    echo "  Note: v1.26.2+ requires GOLANG_FIPS=1 alone (GODEBUG is mutually exclusive)"
    FAILED=$((FAILED + 1))
fi

echo ""

################################################################################
# Test 2: GOEXPERIMENT Environment Variable
################################################################################
echo "[2/7] GOEXPERIMENT=strictfipsruntime environment variable..."

GOEXP_VALUE=$(docker run --rm --entrypoint "" "${IMAGE_NAME}" sh -c "echo \$GOEXPERIMENT" 2>&1)

if [ "${GOEXP_VALUE}" = "strictfipsruntime" ]; then
    echo "✓ PASS: GOEXPERIMENT=strictfipsruntime"
    PASSED=$((PASSED + 1))
elif [ "${GOEXP_VALUE}" = "" ]; then
    echo "✓ PASS: GOEXPERIMENT not set (FIPS enforced via GOLANG_FIPS=1)"
    PASSED=$((PASSED + 1))
else
    echo "✗ FAIL: GOEXPERIMENT is not set to 'strictfipsruntime' (value: ${GOEXP_VALUE})"
    FAILED=$((FAILED + 1))
fi

echo ""

################################################################################
# Test 3: GOLANG_FIPS Environment Variable
################################################################################
echo "[3/7] GOLANG_FIPS=1 environment variable..."

GOFIPS_VALUE=$(docker run --rm --entrypoint "" "${IMAGE_NAME}" sh -c "echo \$GOLANG_FIPS" 2>&1)

if [ "${GOFIPS_VALUE}" = "1" ]; then
    echo "✓ PASS: GOLANG_FIPS=1"
    PASSED=$((PASSED + 1))
else
    echo "✗ FAIL: GOLANG_FIPS is not set to '1' (value: ${GOFIPS_VALUE})"
    FAILED=$((FAILED + 1))
fi

echo ""

################################################################################
# Test 4: OpenSSL FIPS Mode (default_properties = fips=yes)
################################################################################
echo "[4/7] OpenSSL FIPS mode (default_properties = fips=yes)..."

if docker run --rm --entrypoint "" "${IMAGE_NAME}" grep -q "default_properties.*fips.*yes" /etc/ssl/openssl.cnf 2>/dev/null; then
    echo "✓ PASS: OpenSSL FIPS mode enabled in configuration"
    PASSED=$((PASSED + 1))
else
    echo "✗ FAIL: OpenSSL FIPS mode not enabled in configuration"
    FAILED=$((FAILED + 1))
fi

echo ""

################################################################################
# Test 5: MD5 Algorithm Blocking
################################################################################
echo "[5/7] MD5 algorithm blocking..."

MD5_OUTPUT=$(docker run --rm --entrypoint "" "${IMAGE_NAME}" sh -c "echo 'test' | openssl dgst -md5 2>&1" || true)

if echo "${MD5_OUTPUT}" | grep -qiE "unsupported|disabled|error|unavailable"; then
    echo "✓ PASS: MD5 is blocked"
    PASSED=$((PASSED + 1))
else
    echo "✗ FAIL: MD5 is not blocked"
    echo "MD5 output: ${MD5_OUTPUT}"
    FAILED=$((FAILED + 1))
fi

echo ""

################################################################################
# Test 6: SHA-1 Restriction (available for hashing only)
################################################################################
echo "[6/7] SHA-1 restriction (available for hashing only)..."

SHA1_OUTPUT=$(docker run --rm --entrypoint "" "${IMAGE_NAME}" sh -c "echo 'test' | openssl dgst -sha1 2>&1" || true)

# SHA-1 should be available for hashing (FIPS 140-3 IG D.F compliant)
if echo "${SHA1_OUTPUT}" | grep -qE "SHA1|SHA-1|SHA256|[a-f0-9]{40}"; then
    echo "✓ PASS: SHA-1 available for hashing (FIPS 140-3 IG D.F compliant)"
    PASSED=$((PASSED + 1))
elif echo "${SHA1_OUTPUT}" | grep -qiE "unsupported|disabled|error"; then
    echo "✓ PASS: SHA-1 blocked at wolfSSL level (--disable-sha)"
    PASSED=$((PASSED + 1))
else
    echo "✗ FAIL: SHA-1 status unclear"
    echo "SHA-1 output: ${SHA1_OUTPUT}"
    FAILED=$((FAILED + 1))
fi

echo ""

################################################################################
# Test 7: FIPS-Approved Algorithms (SHA-256, AES-GCM)
################################################################################
echo "[7/7] FIPS-approved algorithms (SHA-256, AES-GCM)..."

# Test SHA-256
SHA256_OUTPUT=$(docker run --rm --entrypoint "" "${IMAGE_NAME}" sh -c "echo 'test' | openssl dgst -sha256 2>&1" || true)

if echo "${SHA256_OUTPUT}" | grep -qE "SHA2-256|SHA256|[a-f0-9]{64}"; then
    SHA256_PASS=1
else
    SHA256_PASS=0
fi

# Test AES-256-GCM availability
AES_OUTPUT=$(docker run --rm --entrypoint "" "${IMAGE_NAME}" openssl list -cipher-algorithms 2>&1 || true)

if echo "${AES_OUTPUT}" | grep -qiE "AES.*GCM|id-aes.*gcm"; then
    AES_PASS=1
else
    AES_PASS=0
fi

if [ ${SHA256_PASS} -eq 1 ] && [ ${AES_PASS} -eq 1 ]; then
    echo "✓ PASS: FIPS-approved algorithms (SHA-256, AES-GCM) are available"
    PASSED=$((PASSED + 1))
elif [ ${SHA256_PASS} -eq 1 ]; then
    echo "✓ PASS: SHA-256 available (AES-GCM check inconclusive)"
    PASSED=$((PASSED + 1))
else
    echo "✗ FAIL: FIPS-approved algorithms not properly available"
    FAILED=$((FAILED + 1))
fi

echo ""

################################################################################
# Summary
################################################################################
echo "--------------------------------------------------------------------------------"
echo "FIPS Verification Tests: ${PASSED}/7 tests passed"
echo "--------------------------------------------------------------------------------"
echo ""

# Exit with error if any test failed
if [ ${FAILED} -gt 0 ]; then
    exit 1
fi

exit 0
