#!/bin/bash
################################################################################
# Redis Exporter FIPS - FIPS Enforcement Testing Script
#
# This script validates FIPS 140-3 compliance enforcement:
# - wolfSSL FIPS POST execution
# - wolfProvider loading
# - Environment variable validation
# - Approved algorithm availability
# - Non-approved algorithm blocking
# - TLS cipher suite restrictions
#
# Usage:
#   ./test-fips-enforcement.sh [OPTIONS]
#
# Options:
#   --verbose       Show verbose output
#   --help          Show this help message
################################################################################

set -o pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
VERBOSE=false

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

################################################################################
# Parse Arguments
################################################################################

while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            head -n 25 "$0" | grep "^#" | sed 's/^# //; s/^#//'
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

################################################################################
# Helper Functions
################################################################################

run_test() {
    local test_name="$1"
    local test_command="$2"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -n "  ✓ $test_name... "

    if eval "$test_command" >/dev/null 2>&1; then
        echo -e "${GREEN}[PASS]${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}[FAIL]${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        if [ "$VERBOSE" = "true" ]; then
            eval "$test_command" || true
        fi
        return 1
    fi
}

run_block_test() {
    local test_name="$1"
    local test_command="$2"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -n "  ✓ $test_name... "

    # For blocking tests, we expect the command to FAIL
    # If it fails (blocked), that's a PASS
    # If it succeeds (not blocked), that's a FAIL (security issue!)
    if ! eval "$test_command" >/dev/null 2>&1; then
        echo -e "${GREEN}[BLOCKED]${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}[ALLOWED - FAIL]${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        if [ "$VERBOSE" = "true" ]; then
            echo "    WARNING: Non-FIPS algorithm was allowed!"
            eval "$test_command" || true
        fi
        return 1
    fi
}

################################################################################
# Setup
################################################################################

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}FIPS Enforcement Validation${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

################################################################################
# Test Suite 1: FIPS Module Validation
################################################################################

echo -e "${YELLOW}[SUITE 1/6]${NC} FIPS Module Validation"

# Test 1: FIPS POST execution
run_test "wolfSSL FIPS POST" "/usr/local/bin/fips-check"

# Test 2: wolfSSL library loaded
run_test "wolfSSL library loaded" "ldconfig -p | grep -q libwolfssl"

# Test 3: wolfProvider registered
run_test "wolfProvider registered" "openssl list -providers 2>/dev/null | grep -qi 'wolfSSL'"

# Test 4: OpenSSL version 3.x
run_test "OpenSSL 3.x" "openssl version | grep -q 'OpenSSL 3'"

echo ""

################################################################################
# Test Suite 2: Environment Variables
################################################################################

echo -e "${YELLOW}[SUITE 2/6]${NC} Environment Variable Validation"

# Test 5: GOLANG_FIPS=1
run_test "GOLANG_FIPS=1" "test \"\$GOLANG_FIPS\" = \"1\""

# Test 6: GODEBUG=fips140=only
run_test "GODEBUG=fips140=only" "echo \"\$GODEBUG\" | grep -q 'fips140=only'"

# Test 7: GOEXPERIMENT set
run_test "GOEXPERIMENT set" "test -n \"\$GOEXPERIMENT\""

echo ""

################################################################################
# Test Suite 3: Approved Algorithm Availability
################################################################################

echo -e "${YELLOW}[SUITE 3/6]${NC} Approved Algorithm Tests"

# Test 8: SHA-256 available
run_test "SHA-256 available" "echo 'test' | openssl dgst -sha256"

# Test 9: SHA-384 available
run_test "SHA-384 available" "echo 'test' | openssl dgst -sha384"

# Test 10: SHA-512 available
run_test "SHA-512 available" "echo 'test' | openssl dgst -sha512"

# Test 11: AES-256-GCM available
run_test "AES-256-GCM available" "openssl enc -aes-256-gcm -help"

# Test 12: AES-128-GCM available
run_test "AES-128-GCM available" "openssl enc -aes-128-gcm -help"

# Test 13: RSA key generation
run_test "RSA-2048 generation" "openssl genrsa 2048"

# Test 14: ECDSA P-256 available
run_test "ECDSA P-256 available" "openssl ecparam -name prime256v1 -genkey"

echo ""


################################################################################
# Test Suite 4: Random Number Generation
################################################################################

echo -e "${YELLOW}[SUITE 4/6]${NC} Random Number Generation"

# Test 15: FIPS DRBG (openssl rand)
run_test "OpenSSL rand (DRBG)" "openssl rand 32"

# Test 16: /dev/urandom available
run_test "/dev/urandom available" "dd if=/dev/urandom bs=32 count=1"

echo ""

################################################################################
# Test Suite 5: TLS Cipher Suites
################################################################################

echo -e "${YELLOW}[SUITE 5/6]${NC} TLS Cipher Suite Validation"

# Test 17: TLS 1.2 supported
run_test "TLS 1.2 supported" "openssl ciphers -v | grep -q 'TLSv1.2'"

# Test 18: TLS 1.3 supported
run_test "TLS 1.3 supported" "openssl ciphers -v | grep -q 'TLSv1.3'"

# Test 19: FIPS-approved cipher available (ECDHE-RSA-AES256-GCM-SHA384)
run_test "ECDHE-RSA-AES256-GCM-SHA384" "openssl ciphers -v | grep -q 'ECDHE-RSA-AES256-GCM-SHA384'"

# Test 20: FIPS-approved cipher available (AES256-GCM-SHA384)
run_test "AES256-GCM-SHA384" "openssl ciphers -v | grep -q 'AES256-GCM-SHA384'"

echo ""

################################################################################
# Test Suite 6: Non-Approved Algorithm Blocking
################################################################################

echo -e "${YELLOW}[SUITE 6/6]${NC} Non-Approved Algorithm Blocking"

# Test 21: MD5 blocked
run_block_test "MD5 blocked" "echo 'test' | openssl dgst -md5"

# Test 22: SHA1 blocked
run_block_test "SHA1 blocked" "echo 'test' | openssl dgst -sha1"

# Test 23: MD4 blocked
run_block_test "MD4 blocked" "echo 'test' | openssl dgst -md4"

# Test 24: DES blocked
run_block_test "DES blocked" "echo 'test' | openssl enc -des -pass pass:test -P"

# Test 25: 3DES blocked
run_block_test "3DES blocked" "echo 'test' | openssl enc -des3 -pass pass:test -P"

# Test 26: RC4 blocked
run_block_test "RC4 blocked" "echo 'test' | openssl enc -rc4 -pass pass:test -P"

# Test 27: Blowfish blocked
run_block_test "Blowfish blocked" "echo 'test' | openssl enc -bf -pass pass:test -P"

# Test 28: Weak RSA-1024 blocked
run_block_test "RSA-1024 blocked" "openssl genrsa 1024"

echo ""

################################################################################
# Summary
################################################################################

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}FIPS Enforcement Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo "Total Tests:  $TOTAL_TESTS"
echo -e "${GREEN}Passed:       $PASSED_TESTS${NC}"

if [ $FAILED_TESTS -gt 0 ]; then
    echo -e "${RED}Failed:       $FAILED_TESTS${NC}"
else
    echo "Failed:       $FAILED_TESTS"
fi

echo ""

################################################################################
# FIPS Status Report
################################################################################

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}FIPS Status Report${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo "wolfSSL FIPS:"
if /usr/local/bin/fips-check 2>/dev/null | grep -q "PASS"; then
    echo -e "  Status: ${GREEN}ENABLED${NC}"
    echo -e "  Version: wolfSSL FIPS v5.8.2"
    echo -e "  Certificate: CMVP #4718"
else
    echo -e "  Status: ${RED}FAILED${NC}"
fi

echo ""
echo "Go FIPS:"
echo -e "  GOLANG_FIPS: ${GREEN}${GOLANG_FIPS:-not set}${NC}"
echo -e "  GODEBUG: ${GREEN}${GODEBUG:-not set}${NC}"
echo -e "  GOEXPERIMENT: ${GREEN}${GOEXPERIMENT:-not set}${NC}"

echo ""
echo "OpenSSL:"
OPENSSL_VERSION=$(openssl version)
echo -e "  Version: ${GREEN}$OPENSSL_VERSION${NC}"
if openssl list -providers 2>/dev/null | grep -qi "wolfSSL"; then
    echo -e "  Provider: ${GREEN}wolfProvider (active)${NC}"
else
    echo -e "  Provider: ${YELLOW}default${NC}"
fi

echo ""
echo "Runtime Environment:"
echo -e "  User: $(whoami)"
echo -e "  PWD: $(pwd)"
echo -e "  Hostname: $(hostname)"

echo ""

################################################################################
# Exit Status
################################################################################

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}✓ ALL FIPS CHECKS PASSED${NC}"
    echo -e "${GREEN}✓ FIPS 140-3 ENFORCEMENT ACTIVE${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}✗ SOME FIPS CHECKS FAILED${NC}"
    echo -e "${RED}✗ FIPS ENFORCEMENT MAY NOT BE COMPLETE${NC}"
    echo ""
    exit 1
fi
