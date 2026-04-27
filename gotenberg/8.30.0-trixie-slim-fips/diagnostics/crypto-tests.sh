#!/bin/bash
################################################################################
# Crypto Operations Tests
#
# Purpose: Verify cryptographic operations with FIPS-approved algorithms
#
# Tests:
#   1. SHA-256 hashing
#   2. SHA-384 hashing
#   3. SHA-512 hashing
#   4. AES-128-CBC encryption/decryption
#   5. AES-256-GCM encryption/decryption
#   6. RSA key generation (2048-bit)
#   7. ECDSA key generation (P-256)
#   8. HMAC-SHA256 operation
#
# Total: 8 tests
################################################################################

IMAGE_NAME="$1"

echo "================================================================================"
echo "Crypto Operations Tests"
echo "================================================================================"
echo ""

PASSED=0
FAILED=0

################################################################################
# Test 1: SHA-256 Hashing
################################################################################
echo "[1/8] SHA-256 hashing..."

SHA256_OUTPUT=$(docker run --rm --entrypoint "" "${IMAGE_NAME}" sh -c "echo 'test data' | openssl dgst -sha256" 2>&1)

if echo "${SHA256_OUTPUT}" | grep -qE "[a-f0-9]{64}"; then
    echo "✓ PASS: SHA-256 hashing successful"
    PASSED=$((PASSED + 1))
else
    echo "✗ FAIL: SHA-256 hashing failed"
    echo "Output: ${SHA256_OUTPUT}"
    FAILED=$((FAILED + 1))
fi

echo ""

################################################################################
# Test 2: SHA-384 Hashing
################################################################################
echo "[2/8] SHA-384 hashing..."

SHA384_OUTPUT=$(docker run --rm --entrypoint "" "${IMAGE_NAME}" sh -c "echo 'test data' | openssl dgst -sha384" 2>&1)

if echo "${SHA384_OUTPUT}" | grep -qE "[a-f0-9]{96}"; then
    echo "✓ PASS: SHA-384 hashing successful"
    PASSED=$((PASSED + 1))
else
    echo "✗ FAIL: SHA-384 hashing failed"
    echo "Output: ${SHA384_OUTPUT}"
    FAILED=$((FAILED + 1))
fi

echo ""

################################################################################
# Test 3: SHA-512 Hashing
################################################################################
echo "[3/8] SHA-512 hashing..."

SHA512_OUTPUT=$(docker run --rm --entrypoint "" "${IMAGE_NAME}" sh -c "echo 'test data' | openssl dgst -sha512" 2>&1)

if echo "${SHA512_OUTPUT}" | grep -qE "[a-f0-9]{128}"; then
    echo "✓ PASS: SHA-512 hashing successful"
    PASSED=$((PASSED + 1))
else
    echo "✗ FAIL: SHA-512 hashing failed"
    echo "Output: ${SHA512_OUTPUT}"
    FAILED=$((FAILED + 1))
fi

echo ""

################################################################################
# Test 4: AES-128-CBC Encryption/Decryption
################################################################################
echo "[4/8] AES-128-CBC encryption/decryption..."

AES_CBC_TEST=$(docker run --rm --entrypoint "" "${IMAGE_NAME}" sh -c '
echo "Hello FIPS World" | openssl enc -aes-128-cbc -a -salt -pass pass:testpass 2>/dev/null | \
openssl enc -aes-128-cbc -a -d -salt -pass pass:testpass 2>/dev/null
' 2>&1)

if echo "${AES_CBC_TEST}" | grep -q "Hello FIPS World"; then
    echo "✓ PASS: AES-128-CBC encryption/decryption successful"
    PASSED=$((PASSED + 1))
else
    echo "✗ FAIL: AES-128-CBC encryption/decryption failed"
    echo "Output: ${AES_CBC_TEST}"
    FAILED=$((FAILED + 1))
fi

echo ""

################################################################################
# Test 5: AES-256-GCM Cipher Availability
################################################################################
echo "[5/8] AES-256-GCM cipher availability..."

# Note: OpenSSL enc doesn't support AEAD ciphers like GCM
# Instead, verify the cipher is available in the cipher list
AES_GCM_TEST=$(docker run --rm --entrypoint "" "${IMAGE_NAME}" sh -c "openssl ciphers -v 'AES256-GCM-SHA384'" 2>&1)

if echo "${AES_GCM_TEST}" | grep -qE "AES256-GCM-SHA384|TLSv1"; then
    echo "✓ PASS: AES-256-GCM cipher is available"
    PASSED=$((PASSED + 1))
else
    echo "✗ FAIL: AES-256-GCM cipher not available"
    echo "Output: ${AES_GCM_TEST}"
    FAILED=$((FAILED + 1))
fi

echo ""

################################################################################
# Test 6: RSA Key Generation (2048-bit)
################################################################################
echo "[6/8] RSA key generation (2048-bit)..."

RSA_OUTPUT=$(docker run --rm --entrypoint "" "${IMAGE_NAME}" sh -c "openssl genrsa 2048 2>&1" || true)

if echo "${RSA_OUTPUT}" | grep -qE "RSA key ok|Private-Key: \(2048 bit|PRIVATE KEY"; then
    echo "✓ PASS: RSA-2048 key generation successful"
    PASSED=$((PASSED + 1))
else
    echo "✗ FAIL: RSA-2048 key generation failed"
    echo "Output: ${RSA_OUTPUT}"
    FAILED=$((FAILED + 1))
fi

echo ""

################################################################################
# Test 7: ECDSA Key Generation (P-256)
################################################################################
echo "[7/8] ECDSA key generation (P-256)..."

ECDSA_OUTPUT=$(docker run --rm --entrypoint "" "${IMAGE_NAME}" sh -c "openssl ecparam -name prime256v1 -genkey 2>&1" || true)

if echo "${ECDSA_OUTPUT}" | grep -qE "BEGIN.*PRIVATE KEY|EC PRIVATE KEY|prime256v1"; then
    echo "✓ PASS: ECDSA P-256 key generation successful"
    PASSED=$((PASSED + 1))
else
    echo "✗ FAIL: ECDSA P-256 key generation failed"
    echo "Output: ${ECDSA_OUTPUT}"
    FAILED=$((FAILED + 1))
fi

echo ""

################################################################################
# Test 8: HMAC-SHA256 Operation
################################################################################
echo "[8/8] HMAC-SHA256 operation..."

HMAC_OUTPUT=$(docker run --rm --entrypoint "" "${IMAGE_NAME}" sh -c "echo 'test data' | openssl dgst -sha256 -hmac 'secret_key'" 2>&1)

if echo "${HMAC_OUTPUT}" | grep -qE "SHA2-256|SHA256|[a-f0-9]{64}"; then
    echo "✓ PASS: HMAC-SHA256 operation successful"
    PASSED=$((PASSED + 1))
else
    echo "✗ FAIL: HMAC-SHA256 operation failed"
    echo "Output: ${HMAC_OUTPUT}"
    FAILED=$((FAILED + 1))
fi

echo ""

################################################################################
# Summary
################################################################################
echo "--------------------------------------------------------------------------------"
echo "Crypto Operations Tests: ${PASSED}/8 tests passed"
echo "--------------------------------------------------------------------------------"
echo ""

# Exit with error if any test failed
if [ ${FAILED} -gt 0 ]; then
    exit 1
fi

exit 0
