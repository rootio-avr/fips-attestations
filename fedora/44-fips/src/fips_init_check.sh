#!/bin/bash
#
# FIPS Initialization Check for Fedora 44
# Shell-based verification using native OpenSSL and crypto-policies
#
# This script verifies FIPS mode is properly enabled without requiring
# any language runtimes (Node.js, Python, etc.)
#

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
tests_run=0
tests_passed=0

# Test function
test_fips() {
    local test_name="$1"
    local test_command="$2"
    local expect_success="${3:-true}"

    tests_run=$((tests_run + 1))
    printf "  [%d] Testing %s... " "$tests_run" "$test_name"

    if eval "$test_command" > /dev/null 2>&1; then
        if [ "$expect_success" = "true" ]; then
            tests_passed=$((tests_passed + 1))
            echo -e "${GREEN}✓ PASS${NC}"
            return 0
        else
            echo -e "${RED}✗ FAIL${NC} (expected to fail but succeeded)"
            return 1
        fi
    else
        if [ "$expect_success" = "false" ]; then
            tests_passed=$((tests_passed + 1))
            echo -e "${GREEN}✓ PASS${NC} (correctly blocked)"
            return 0
        else
            echo -e "${RED}✗ FAIL${NC}"
            return 1
        fi
    fi
}

# Header
echo ""
echo "========================================"
echo "Fedora 44 FIPS Initialization Check"
echo "========================================"
echo ""
echo "Verifying FIPS mode using native tools"
echo ""

# Test 1: Crypto-policies configuration
test_fips "Crypto-policies set to FIPS" \
    '[ "$(cat /etc/crypto-policies/config 2>/dev/null | tr -d \"[:space:]\")" = "FIPS" ]'

# Test 2: OpenSSL FIPS provider loaded
test_fips "OpenSSL FIPS provider loaded" \
    'openssl list -providers 2>/dev/null | grep -qi fips'

# Test 3: OPENSSL_FORCE_FIPS_MODE environment variable
test_fips "OPENSSL_FORCE_FIPS_MODE=1 set" \
    '[ "$OPENSSL_FORCE_FIPS_MODE" = "1" ]'

# Test 4: OpenSSL version check
test_fips "OpenSSL version 3.x available" \
    'openssl version 2>/dev/null | grep -q "OpenSSL 3\."'

# Test 5: SHA-256 hashing (FIPS-approved algorithm)
test_fips "SHA-256 hash algorithm" \
    'echo "test" | openssl dgst -sha256'

# Test 6: SHA-384 hashing (FIPS-approved algorithm)
test_fips "SHA-384 hash algorithm" \
    'echo "test" | openssl dgst -sha384'

# Test 7: SHA-512 hashing (FIPS-approved algorithm)
test_fips "SHA-512 hash algorithm" \
    'echo "test" | openssl dgst -sha512'

# Test 8: MD5 hashing (non-FIPS algorithm - should FAIL in FIPS mode)
test_fips "MD5 hash blocked (non-FIPS)" \
    'echo "test" | openssl dgst -md5' \
    "false"

# Test 9: Random bytes generation
test_fips "Random bytes generation (32 bytes)" \
    'openssl rand -hex 32'

# Test 10: Random bytes generation (larger)
test_fips "Random bytes generation (256 bytes)" \
    'openssl rand -hex 256'

# Test 11: AES-256-CBC encryption (FIPS-approved)
test_fips "AES-256-CBC encryption" \
    'echo "test data" | openssl enc -aes-256-cbc -pbkdf2 -pass pass:testpassword'

# Test 12: AES-128-CBC encryption (FIPS-approved)
test_fips "AES-128-CBC encryption" \
    'echo "test data" | openssl enc -aes-128-cbc -pbkdf2 -pass pass:testpassword'

# Test 13: RSA key generation (2048-bit, FIPS minimum)
test_fips "RSA-2048 key generation" \
    'openssl genrsa 2048 2>/dev/null'

# Test 14: EC key generation (P-256 curve, FIPS-approved)
test_fips "EC P-256 key generation" \
    'openssl ecparam -name prime256v1 -genkey -noout'

# Summary
echo ""
echo "========================================"
echo "Summary: $tests_passed/$tests_run tests passed"
echo "========================================"
echo ""

if [ $tests_passed -eq $tests_run ]; then
    echo -e "${GREEN}✓ ALL TESTS PASSED${NC}"
    echo ""
    echo "FIPS mode is properly enabled:"
    echo "  - Crypto-policies: $(cat /etc/crypto-policies/config 2>/dev/null)"
    echo "  - OpenSSL version: $(openssl version 2>/dev/null | awk '{print $2}')"
    echo "  - FIPS provider: Active"
    echo "  - Non-FIPS algorithms: Blocked"
    echo ""
    exit 0
else
    echo -e "${RED}✗ SOME TESTS FAILED${NC}"
    echo ""
    echo "FIPS mode may not be properly configured."
    echo "Check the following:"
    echo "  1. /etc/crypto-policies/config should contain 'FIPS'"
    echo "  2. OPENSSL_FORCE_FIPS_MODE should be set to '1'"
    echo "  3. OpenSSL FIPS provider should be loaded"
    echo ""
    exit 1
fi
