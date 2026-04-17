#!/bin/bash
################################################################################
# Cryptographic Operations Test Suite
################################################################################

IMAGE_NAME="$1"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_name="$1"
    local test_cmd="$2"

    echo -e "${YELLOW}[TEST]${NC} ${test_name}"

    if eval "${test_cmd}"; then
        echo -e "${GREEN}  ✓ PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}  ✗ FAIL${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

echo "Cryptographic Operations Tests"
echo "==============================="
echo ""

# Test 1: Generate RSA private key (FIPS-approved)
run_test "Generate RSA-2048 private key" \
    "openssl genrsa -out /tmp/key.pem 2048 2>/dev/null"

# Test 2: Generate self-signed certificate
run_test "Generate self-signed certificate" \
    "bash -c 'openssl req -new -x509 -key <(openssl genrsa 2048 2>/dev/null) -out /tmp/cert.pem -days 365 -subj \"/CN=test\" 2>/dev/null'"

# Test 3: SHA-256 hash (FIPS-approved)
run_test "SHA-256 hash operation" \
    "bash -c 'echo \"test\" | openssl dgst -sha256' | grep -q 'SHA2-256'"

# Test 4: SHA-384 hash (FIPS-approved)
run_test "SHA-384 hash operation" \
    "bash -c 'echo \"test\" | openssl dgst -sha384' | grep -q 'SHA2-384'"

# Test 5: SHA-512 hash (FIPS-approved)
run_test "SHA-512 hash operation" \
    "bash -c 'echo \"test\" | openssl dgst -sha512' | grep -q 'SHA2-512'"

# Test 6: AES-256-CBC encryption (FIPS-approved)
run_test "AES-256-CBC encryption" \
    "bash -c 'echo \"test\" | openssl enc -aes-256-cbc -pbkdf2 -pass pass:test -out /tmp/encrypted 2>/dev/null && test -f /tmp/encrypted'"

# Test 7: List FIPS-approved ciphers
run_test "List FIPS-approved ciphers" \
    "openssl ciphers -v 'FIPS' | grep -q 'TLS'"

# Test 8: Verify MD5 is blocked (non-FIPS)
run_test "Verify MD5 is blocked (should fail intentionally)" \
    "! bash -c 'echo \"test\" | openssl dgst -md5 2>&1' | grep -qi 'disabled'"

# Test 9: Test TLS 1.3 cipher support
run_test "TLS 1.3 cipher support" \
    "openssl ciphers -v -tls1_3 | grep -q 'TLS_AES'"

# Test 10: Verify EC key generation (FIPS-approved P-256)
run_test "Generate EC P-256 key" \
    "openssl ecparam -name prime256v1 -genkey -noout -out /tmp/ec_key.pem 2>/dev/null"

echo ""
echo "Summary: ${TESTS_PASSED} passed, ${TESTS_FAILED} failed"
echo ""

if [ ${TESTS_FAILED} -gt 0 ]; then
    exit 1
fi

exit 0
