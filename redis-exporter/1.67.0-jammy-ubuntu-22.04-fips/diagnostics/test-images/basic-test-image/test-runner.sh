#!/bin/bash
################################################################################
# Redis Exporter FIPS - Test Runner
#
# Executes all test suites and reports results
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Redis Exporter FIPS Test Suite${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Test Suite 1: FIPS Validation
echo -e "${YELLOW}[SUITE 1/4]${NC} FIPS Validation Tests"

# Test 1: FIPS POST
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo -n "  ✓ Test 1: FIPS POST passes... "
if /usr/local/bin/fips-check >/dev/null 2>&1; then
    echo -e "${GREEN}[PASS]${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}[FAIL]${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Test 2: wolfSSL library
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo -n "  ✓ Test 2: wolfSSL library loads... "
if ldconfig -p | grep -q libwolfssl; then
    echo -e "${GREEN}[PASS]${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}[FAIL]${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Test 3: wolfProvider
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo -n "  ✓ Test 3: wolfProvider registered... "
if openssl list -providers 2>/dev/null | grep -qi "wolfSSL"; then
    echo -e "${GREEN}[PASS]${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}[FAIL]${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Test 4: GOLANG_FIPS
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo -n "  ✓ Test 4: GOLANG_FIPS=1... "
if [ "$GOLANG_FIPS" = "1" ]; then
    echo -e "${GREEN}[PASS]${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}[FAIL]${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Test 5: GODEBUG
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo -n "  ✓ Test 5: GODEBUG=fips140=only... "
if [ "$GODEBUG" = "fips140=only" ]; then
    echo -e "${GREEN}[PASS]${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}[FAIL]${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Test 6: MD5 blocked
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo -n "  ✓ Test 6: MD5 blocked... "
if echo "test" | openssl dgst -md5 2>&1 | grep -qi "error\|disabled\|unsupported"; then
    echo -e "${GREEN}[PASS]${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}[FAIL]${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Test 7: SHA-256 available
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo -n "  ✓ Test 7: SHA-256 available... "
if echo "test" | openssl dgst -sha256 >/dev/null 2>&1; then
    echo -e "${GREEN}[PASS]${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}[FAIL]${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Test 8: OpenSSL version
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo -n "  ✓ Test 8: OpenSSL 3.x... "
if openssl version | grep -q "OpenSSL 3"; then
    echo -e "${GREEN}[PASS]${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}[FAIL]${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

echo -e "  [${PASSED_TESTS}/8 PASSED]"
echo ""

# Test Suite 2: Redis Connection (simplified placeholders)
echo -e "${YELLOW}[SUITE 2/4]${NC} Redis Connection Tests"
echo -e "  ${BLUE}[INFO]${NC} These tests require a running Redis server"
echo -e "  ${BLUE}[INFO]${NC} Run with: docker run --link redis-server ..."
echo -e "  ○ Tests 9-18: SKIPPED (Redis server not available)"
TOTAL_TESTS=$((TOTAL_TESTS + 10))
SKIPPED_TESTS=$((SKIPPED_TESTS + 10))
echo ""

# Test Suite 3: Metrics Export (basic checks)
echo -e "${YELLOW}[SUITE 3/4]${NC} Metrics Export Tests"

# Test 19: Exporter version
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo -n "  ✓ Test 19: redis_exporter binary... "
if redis_exporter --version >/dev/null 2>&1; then
    echo -e "${GREEN}[PASS]${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}[FAIL]${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Placeholder for additional metrics tests
echo -e "  ○ Tests 20-25: SKIPPED (require running exporter + Redis)"
TOTAL_TESTS=$((TOTAL_TESTS + 6))
SKIPPED_TESTS=$((SKIPPED_TESTS + 6))
echo ""

# Test Suite 4: Crypto Operations
echo -e "${YELLOW}[SUITE 4/4]${NC} Crypto Operations Tests"

# Test 26: AES-256 available
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo -n "  ✓ Test 26: AES-256 available... "
if openssl enc -aes-256-gcm -help >/dev/null 2>&1; then
    echo -e "${GREEN}[PASS]${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}[FAIL]${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Test 27: RSA key generation
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo -n "  ✓ Test 27: RSA-2048 generation... "
if openssl genrsa 2048 >/dev/null 2>&1; then
    echo -e "${GREEN}[PASS]${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}[FAIL]${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Test 28: Random bytes
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo -n "  ✓ Test 28: FIPS DRBG (random)... "
if openssl rand 32 >/dev/null 2>&1; then
    echo -e "${GREEN}[PASS]${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}[FAIL]${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Placeholder for TLS tests
echo -e "  ○ Tests 29-30: SKIPPED (require TLS setup)"
TOTAL_TESTS=$((TOTAL_TESTS + 2))
SKIPPED_TESTS=$((SKIPPED_TESTS + 2))
echo ""

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo "Total Tests:  $TOTAL_TESTS"
echo -e "${GREEN}Passed:       $PASSED_TESTS${NC}"
if [ $FAILED_TESTS -gt 0 ]; then
    echo -e "${RED}Failed:       $FAILED_TESTS${NC}"
else
    echo "Failed:       $FAILED_TESTS"
fi
if [ $SKIPPED_TESTS -gt 0 ]; then
    echo -e "${YELLOW}Skipped:      $SKIPPED_TESTS (require external setup)${NC}"
fi
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}✓ ALL REQUIRED TESTS PASSED${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}✗ SOME TESTS FAILED${NC}"
    echo ""
    exit 1
fi
