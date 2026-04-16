#!/bin/bash
#
# FIPS Cipher Suite Test
# Tests TLS/SSL cipher suites in FIPS mode
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
test_cipher() {
    local cipher="$1"
    local expect_success="${2:-true}"

    tests_run=$((tests_run + 1))
    printf "  [%02d] %-50s" "$tests_run" "$cipher"

    if openssl ciphers "$cipher" > /dev/null 2>&1; then
        if [ "$expect_success" = "true" ]; then
            tests_passed=$((tests_passed + 1))
            echo -e "${GREEN}✓ PASS${NC}"
            return 0
        else
            tests_failed=$((tests_failed + 1))
            echo -e "${RED}✗ FAIL${NC} (should be blocked)"
            return 1
        fi
    else
        if [ "$expect_success" = "false" ]; then
            tests_passed=$((tests_passed + 1))
            echo -e "${GREEN}✓ PASS${NC} (blocked)"
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
echo "  FIPS Cipher Suite Test"
echo "  Fedora 44 - OpenSSL FIPS Provider"
echo "================================================================"
echo ""

# Section 1: TLS 1.2 FIPS-Approved Ciphers
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Section 1: TLS 1.2 FIPS-Approved Cipher Suites${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# ECDHE ciphers (Forward Secrecy with Elliptic Curve)
test_cipher "ECDHE-RSA-AES256-GCM-SHA384"
test_cipher "ECDHE-RSA-AES128-GCM-SHA256"
test_cipher "ECDHE-ECDSA-AES256-GCM-SHA384"
test_cipher "ECDHE-ECDSA-AES128-GCM-SHA256"

# DHE ciphers (Forward Secrecy with Diffie-Hellman)
test_cipher "DHE-RSA-AES256-GCM-SHA384"
test_cipher "DHE-RSA-AES128-GCM-SHA256"

echo ""
echo -e "${YELLOW}Note: Static RSA key exchange (no forward secrecy) blocked in FIPS mode${NC}"
echo ""

# Static RSA ciphers (Should be blocked - no forward secrecy)
test_cipher "AES256-GCM-SHA384" "false"
test_cipher "AES128-GCM-SHA256" "false"

echo ""

# Section 2: TLS 1.3 Cipher Suites (All FIPS-Approved)
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Section 2: TLS 1.3 Cipher Suites${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Note: TLS 1.3 ciphers use different API, verifying from cipher list${NC}"
echo ""

# TLS 1.3 ciphers - check if they appear in the TLS 1.3 cipher list
tls13_ciphers=$(openssl ciphers -tls1_3 2>/dev/null)

# Test TLS_AES_256_GCM_SHA384
tests_run=$((tests_run + 1))
printf "  [%02d] %-50s" "$tests_run" "TLS_AES_256_GCM_SHA384"
if echo "$tls13_ciphers" | grep -q "TLS_AES_256_GCM_SHA384"; then
    tests_passed=$((tests_passed + 1))
    echo -e "${GREEN}✓ PASS${NC}"
else
    tests_failed=$((tests_failed + 1))
    echo -e "${RED}✗ FAIL${NC}"
fi

# Test TLS_AES_128_GCM_SHA256
tests_run=$((tests_run + 1))
printf "  [%02d] %-50s" "$tests_run" "TLS_AES_128_GCM_SHA256"
if echo "$tls13_ciphers" | grep -q "TLS_AES_128_GCM_SHA256"; then
    tests_passed=$((tests_passed + 1))
    echo -e "${GREEN}✓ PASS${NC}"
else
    tests_failed=$((tests_failed + 1))
    echo -e "${RED}✗ FAIL${NC}"
fi

# Test TLS_AES_128_CCM_SHA256
tests_run=$((tests_run + 1))
printf "  [%02d] %-50s" "$tests_run" "TLS_AES_128_CCM_SHA256"
if echo "$tls13_ciphers" | grep -q "TLS_AES_128_CCM_SHA256"; then
    tests_passed=$((tests_passed + 1))
    echo -e "${GREEN}✓ PASS${NC}"
else
    tests_failed=$((tests_failed + 1))
    echo -e "${RED}✗ FAIL${NC}"
fi

echo ""

# Section 3: Weak Ciphers (Should Be Blocked)
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Section 3: Weak/Non-FIPS Ciphers (Should Be Blocked)${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

test_cipher "RC4-SHA" "false"
test_cipher "DES-CBC3-SHA" "false"
test_cipher "DES-CBC-SHA" "false"
test_cipher "EXP-RC4-MD5" "false"
test_cipher "NULL-SHA" "false"

echo ""

# Section 4: Cipher List Tests
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Section 4: Cipher List Tests${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo ""
echo "Available FIPS cipher suites:"
echo ""
openssl ciphers -v 'FIPS' | head -20

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
    echo "Cipher suite validation successful:"
    echo "  - FIPS-approved ciphers are available"
    echo "  - Weak ciphers are properly blocked"
    echo ""
    exit 0
else
    echo -e "${RED}✗ SOME TESTS FAILED${NC}"
    echo ""
    exit 1
fi
