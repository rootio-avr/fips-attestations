#!/bin/bash
#
# Advanced FIPS Compliance Test Suite
# Tests comprehensive cryptographic operations in FIPS mode
#

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test counters
tests_run=0
tests_passed=0
tests_failed=0

# Test function
test_crypto() {
    local test_name="$1"
    local test_command="$2"
    local expect_success="${3:-true}"

    tests_run=$((tests_run + 1))
    printf "  [%02d] %-60s" "$tests_run" "$test_name"

    if eval "$test_command" > /dev/null 2>&1; then
        if [ "$expect_success" = "true" ]; then
            tests_passed=$((tests_passed + 1))
            echo -e "${GREEN}✓ PASS${NC}"
            return 0
        else
            tests_failed=$((tests_failed + 1))
            echo -e "${RED}✗ FAIL${NC} (expected to fail but succeeded)"
            return 1
        fi
    else
        if [ "$expect_success" = "false" ]; then
            tests_passed=$((tests_passed + 1))
            echo -e "${GREEN}✓ PASS${NC} (correctly blocked)"
            return 0
        else
            tests_failed=$((tests_failed + 1))
            echo -e "${RED}✗ FAIL${NC}"
            return 1
        fi
    fi
}

# Header
echo ""
echo "================================================================"
echo "  Advanced FIPS Compliance Test Suite"
echo "  Fedora 44 - OpenSSL FIPS Provider"
echo "================================================================"
echo ""

# Section 1: Hash Functions (FIPS-Approved)
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Section 1: FIPS-Approved Hash Functions${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

test_crypto "SHA-224 hash" \
    'echo "test" | openssl dgst -sha224'

test_crypto "SHA-256 hash" \
    'echo "test" | openssl dgst -sha256'

test_crypto "SHA-384 hash" \
    'echo "test" | openssl dgst -sha384'

test_crypto "SHA-512 hash" \
    'echo "test" | openssl dgst -sha512'

test_crypto "SHA-512/224 hash" \
    'echo "test" | openssl dgst -sha512-224'

test_crypto "SHA-512/256 hash" \
    'echo "test" | openssl dgst -sha512-256'

echo ""

# Section 2: SHA-1 (Legacy Support in FIPS)
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Section 2: SHA-1 (Allowed for Legacy Compatibility)${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Note: SHA-1 is deprecated but allowed in FIPS for backwards compatibility${NC}"
echo -e "${YELLOW}      (HMAC, signature verification, legacy operations)${NC}"
echo ""

test_crypto "SHA-1 hash (legacy allowed)" \
    'echo "test" | openssl dgst -sha1' \
    "true"

test_crypto "SHA-1 HMAC (legacy allowed)" \
    'echo "test" | openssl dgst -sha1 -hmac "key"' \
    "true"

echo ""

# Section 3: Non-FIPS Hash Functions (Should Be Blocked)
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Section 3: Non-FIPS Hash Functions (Should Be Blocked)${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

test_crypto "MD5 hash (blocked)" \
    'echo "test" | openssl dgst -md5' \
    "false"

test_crypto "MD4 hash (blocked)" \
    'echo "test" | openssl dgst -md4' \
    "false"

test_crypto "RIPEMD-160 hash (blocked)" \
    'echo "test" | openssl dgst -ripemd160' \
    "false"

echo ""

# Section 4: Symmetric Encryption (FIPS-Approved)
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Section 4: FIPS-Approved Symmetric Encryption${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

test_crypto "AES-128-CBC encryption" \
    'echo "test" | openssl enc -aes-128-cbc -pbkdf2 -pass pass:test'

test_crypto "AES-192-CBC encryption" \
    'echo "test" | openssl enc -aes-192-cbc -pbkdf2 -pass pass:test'

test_crypto "AES-256-CBC encryption" \
    'echo "test" | openssl enc -aes-256-cbc -pbkdf2 -pass pass:test'

test_crypto "AES-128-ECB encryption" \
    'echo "test" | openssl enc -aes-128-ecb -pbkdf2 -pass pass:test'

test_crypto "AES-192-ECB encryption" \
    'echo "test" | openssl enc -aes-192-ecb -pbkdf2 -pass pass:test'

test_crypto "AES-256-ECB encryption" \
    'echo "test" | openssl enc -aes-256-ecb -pbkdf2 -pass pass:test'

echo ""

# Note about 3DES deprecation
echo -e "${YELLOW}Note: 3DES deprecated for encryption in FIPS 140-3 (NIST SP 800-131A Rev. 2)${NC}"
echo -e "${YELLOW}      Only allowed for decryption of legacy data${NC}"
echo ""

test_crypto "3DES encryption (blocked - deprecated)" \
    'echo "test" | openssl enc -des-ede3 -pbkdf2 -pass pass:test' \
    "false"

echo ""

# Section 5: Non-FIPS Symmetric Encryption (Should Fail)
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Section 5: Non-FIPS Symmetric Encryption (Should Be Blocked)${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

test_crypto "DES encryption (blocked)" \
    'echo "test" | openssl enc -des -pbkdf2 -pass pass:test' \
    "false"

test_crypto "RC4 encryption (blocked)" \
    'echo "test" | openssl enc -rc4 -pbkdf2 -pass pass:test' \
    "false"

test_crypto "Blowfish encryption (blocked)" \
    'echo "test" | openssl enc -bf -pbkdf2 -pass pass:test' \
    "false"

echo ""

# Section 6: RSA Key Generation (FIPS-Approved Sizes)
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Section 6: RSA Key Generation (FIPS-Approved Sizes)${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

test_crypto "RSA-2048 key generation" \
    'openssl genrsa 2048 2>/dev/null'

test_crypto "RSA-3072 key generation" \
    'openssl genrsa 3072 2>/dev/null'

test_crypto "RSA-4096 key generation" \
    'openssl genrsa 4096 2>/dev/null'

echo ""

# Section 7: Elliptic Curve Key Generation (FIPS-Approved Curves)
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Section 7: Elliptic Curve Crypto (FIPS-Approved Curves)${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

test_crypto "P-256 (secp256r1/prime256v1) key generation" \
    'openssl ecparam -name prime256v1 -genkey -noout'

test_crypto "P-384 (secp384r1) key generation" \
    'openssl ecparam -name secp384r1 -genkey -noout'

test_crypto "P-521 (secp521r1) key generation" \
    'openssl ecparam -name secp521r1 -genkey -noout'

echo ""

# Section 8: HMAC Operations (FIPS-Approved)
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Section 8: HMAC Operations (FIPS-Approved)${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

test_crypto "HMAC-SHA256" \
    'echo "test" | openssl dgst -sha256 -hmac "secret"'

test_crypto "HMAC-SHA384" \
    'echo "test" | openssl dgst -sha384 -hmac "secret"'

test_crypto "HMAC-SHA512" \
    'echo "test" | openssl dgst -sha512 -hmac "secret"'

echo ""

# Section 9: Random Number Generation
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Section 9: Random Number Generation${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

test_crypto "Random bytes (16 bytes)" \
    'openssl rand 16'

test_crypto "Random bytes (32 bytes)" \
    'openssl rand 32'

test_crypto "Random bytes (64 bytes)" \
    'openssl rand 64'

test_crypto "Random bytes (256 bytes)" \
    'openssl rand 256'

test_crypto "Random hex (32 bytes)" \
    'openssl rand -hex 32'

test_crypto "Random base64 (32 bytes)" \
    'openssl rand -base64 32'

echo ""

# Summary
echo "================================================================"
echo "                      Test Summary"
echo "================================================================"
echo ""
echo "  Total Tests:   $tests_run"
echo -e "  ${GREEN}Passed:        $tests_passed${NC}"
if [ $tests_failed -gt 0 ]; then
    echo -e "  ${RED}Failed:        $tests_failed${NC}"
else
    echo "  Failed:        $tests_failed"
fi
echo ""

# Success/Failure
if [ $tests_passed -eq $tests_run ]; then
    echo -e "${GREEN}✓ ALL TESTS PASSED${NC}"
    echo ""
    echo "FIPS compliance validation successful:"
    echo "  - All FIPS-approved algorithms work correctly"
    echo "  - All non-FIPS algorithms are properly blocked"
    echo "  - Crypto operations comply with FIPS 140-3"
    echo ""
    exit 0
else
    echo -e "${RED}✗ SOME TESTS FAILED${NC}"
    echo ""
    echo "FIPS compliance validation failed."
    echo "Check the output above for details."
    echo ""
    exit 1
fi
