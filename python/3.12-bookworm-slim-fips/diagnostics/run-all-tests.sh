#!/bin/bash
#
# Master test runner for Python wolfSSL FIPS diagnostics
# Runs all diagnostic test suites and generates a summary report
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

echo ""
echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  Python wolfSSL FIPS 140-3 Diagnostic Test Suite${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Test 1: Backend Verification
echo -e "${YELLOW}Running Test Suite 1: Backend Verification${NC}"
echo -e "${YELLOW}------------------------------------------------------------${NC}"
if python3 test-backend-verification.py; then
    echo -e "${GREEN}✓ Backend Verification: PASSED${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ Backend Verification: FAILED${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo ""

# Test 2: Connectivity
echo -e "${YELLOW}Running Test Suite 2: Connectivity Tests${NC}"
echo -e "${YELLOW}------------------------------------------------------------${NC}"
if python3 test-connectivity.py; then
    echo -e "${GREEN}✓ Connectivity Tests: PASSED${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ Connectivity Tests: FAILED${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo ""

# Test 3: FIPS Verification
echo -e "${YELLOW}Running Test Suite 3: FIPS Verification${NC}"
echo -e "${YELLOW}------------------------------------------------------------${NC}"
if python3 test-fips-verification.py; then
    echo -e "${GREEN}✓ FIPS Verification: PASSED${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ FIPS Verification: FAILED${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo ""

# Test 4: Crypto Operations
echo -e "${YELLOW}Running Test Suite 4: Crypto Operations${NC}"
echo -e "${YELLOW}------------------------------------------------------------${NC}"
if python3 test-crypto-operations.py; then
    echo -e "${GREEN}✓ Crypto Operations: PASSED${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ Crypto Operations: FAILED${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo ""

# Test 5: Library Compatibility
echo -e "${YELLOW}Running Test Suite 5: Library Compatibility${NC}"
echo -e "${YELLOW}------------------------------------------------------------${NC}"
if python3 test-library-compatibility.py; then
    echo -e "${GREEN}✓ Library Compatibility: PASSED${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ Library Compatibility: FAILED${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo ""

# Summary
echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  Test Summary${NC}"
echo -e "${BLUE}================================================================${NC}"
echo -e "  Total Test Suites: ${TOTAL_TESTS}"
echo -e "  ${GREEN}Passed: ${PASSED_TESTS}${NC}"
echo -e "  ${RED}Failed: ${FAILED_TESTS}${NC}"
echo ""

PASS_RATE=$((PASSED_TESTS * 100 / TOTAL_TESTS))
echo -e "  Pass Rate: ${PASS_RATE}%"
echo ""

if [ $PASSED_TESTS -eq $TOTAL_TESTS ]; then
    echo -e "${GREEN}✓ ALL TEST SUITES PASSED${NC}"
    echo -e "${GREEN}  Python wolfSSL FIPS implementation is ready for production${NC}"
    echo ""
    exit 0
elif [ $PASSED_TESTS -ge 4 ]; then
    echo -e "${YELLOW}⚠ PARTIAL SUCCESS (${PASSED_TESTS}/${TOTAL_TESTS} suites passed)${NC}"
    echo -e "${YELLOW}  Review failed test suites above${NC}"
    echo ""
    exit 1
else
    echo -e "${RED}✗ CRITICAL FAILURE (${FAILED_TESTS}/${TOTAL_TESTS} suites failed)${NC}"
    echo -e "${RED}  Python wolfSSL FIPS implementation has significant issues${NC}"
    echo ""
    exit 2
fi
