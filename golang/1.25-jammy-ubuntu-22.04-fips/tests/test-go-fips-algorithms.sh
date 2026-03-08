#!/bin/bash
################################################################################
# Test Go FIPS Algorithm Enforcement
#
# Purpose: Verify MD5 and SHA-1 are blocked, SHA-256+ allowed
################################################################################

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "================================================================================"
echo "Test: Go FIPS Algorithm Enforcement"
echo "================================================================================"
echo ""

TESTS_PASSED=0
TESTS_FAILED=0

echo "[Test 1] Running Go FIPS Demo"
echo "--------------------------------------------------------------------------------"
if /app/fips-go-demo > /tmp/go-output.log 2>&1; then
    echo -e "${GREEN}✓ PASS${NC} - Go demo executed successfully"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo ""
    echo "Demo Output:"
    cat /tmp/go-output.log
    echo ""
else
    echo -e "${RED}✗ FAIL${NC} - Go demo failed to execute"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "Error output:"
    cat /tmp/go-output.log
    echo ""
fi

echo ""
echo "--------------------------------------------------------------------------------"
echo "[Test 2] Verify MD5 is blocked"
if grep -q "MD5.*BLOCKED\|MD5.*panic" /tmp/go-output.log; then
    echo -e "${GREEN}✓ PASS${NC} - MD5 is blocked by FIPS runtime"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ WARNING${NC} - MD5 blocking not confirmed"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "[Test 3] Verify SHA-1 is blocked"
if grep -q "SHA1.*BLOCKED\|SHA1.*panic" /tmp/go-output.log; then
    echo -e "${GREEN}✓ PASS${NC} - SHA-1 is blocked (strict policy)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ WARNING${NC} - SHA-1 blocking not confirmed"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "[Test 4] Verify SHA-256 is available"
if grep -q "SHA-256.*PASS" /tmp/go-output.log; then
    echo -e "${GREEN}✓ PASS${NC} - SHA-256 is available (FIPS approved)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - SHA-256 should be available"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "================================================================================"
echo "Test Summary"
echo "================================================================================"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ ALL TESTS PASSED${NC}"
    exit 0
else
    echo -e "${RED}✗ SOME TESTS FAILED${NC}"
    exit 1
fi
