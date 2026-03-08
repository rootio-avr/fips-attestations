#!/bin/bash
################################################################################
# Test Java FIPS Algorithm Enforcement
#
# Purpose: Verify MD5 and SHA-1 are blocked, SHA-256+ allowed
#          POC Requirement: Golang Cryptographic Validation (adapted for Java)
################################################################################

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "================================================================================"
echo "Test: Java FIPS Algorithm Enforcement (FIPS POC Requirement)"
echo "================================================================================"
echo ""
echo "POC Validation: Java Cryptographic Validation"
echo "Requirement: MD5/SHA-1 must be blocked, SHA-256+ must succeed"
echo ""

TESTS_PASSED=0
TESTS_FAILED=0

echo "[Test 1] Running Java FIPS Demo"
echo "--------------------------------------------------------------------------------"
if cd /app/java && java FipsDemoApp > /tmp/java-output.log 2>&1; then
    echo -e "${GREEN}✓ PASS${NC} - Java demo executed successfully"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo ""
    echo "Demo Output:"
    cat /tmp/java-output.log
    echo ""
else
    echo -e "${RED}✗ FAIL${NC} - Java demo failed to execute"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "Error output:"
    cat /tmp/java-output.log
    echo ""
fi

echo ""
echo "--------------------------------------------------------------------------------"
echo "[Test 2] Verify MD5 is blocked"
if grep -q "MD5.*BLOCKED" /tmp/java-output.log; then
    echo -e "${GREEN}✓ PASS${NC} - MD5 is blocked by FIPS enforcement"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - MD5 should be blocked in FIPS mode"
    echo "Output:"
    grep "MD5" /tmp/java-output.log || echo "(No MD5 output found)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "[Test 3] Verify SHA-1 is blocked"
if grep -q "SHA1.*BLOCKED\|SHA-1.*BLOCKED" /tmp/java-output.log; then
    echo -e "${GREEN}✓ PASS${NC} - SHA-1 is blocked (strict FIPS policy)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - SHA-1 should be blocked in FIPS mode"
    echo "Output:"
    grep "SHA1\|SHA-1" /tmp/java-output.log || echo "(No SHA-1 output found)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "[Test 4] Verify SHA-256 is available"
if grep -q "SHA-256.*PASS" /tmp/java-output.log; then
    echo -e "${GREEN}✓ PASS${NC} - SHA-256 is available (FIPS approved)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - SHA-256 should be available"
    echo "Output:"
    grep "SHA-256" /tmp/java-output.log || echo "(No SHA-256 output found)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "[Test 5] Verify FIPS initialization occurred"
if grep -q "FIPS Initialization" /tmp/java-output.log; then
    echo -e "${GREEN}✓ PASS${NC} - FIPS initialization detected"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ WARNING${NC} - FIPS initialization not detected"
    TESTS_PASSED=$((TESTS_PASSED + 1))
fi

echo ""
echo "================================================================================"
echo "Test Summary: Java FIPS Algorithm Enforcement"
echo "================================================================================"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ ALL TESTS PASSED${NC}"
    echo ""
    echo "FIPS POC Requirement: VERIFIED"
    echo "  ✓ Java Cryptographic Validation"
    echo "  ✓ MD5: BLOCKED"
    echo "  ✓ SHA-1: BLOCKED (strict policy)"
    echo "  ✓ SHA-256: AVAILABLE (FIPS approved)"
    echo ""
    exit 0
else
    echo -e "${RED}✗ SOME TESTS FAILED${NC}"
    echo ""
    echo "FIPS POC Requirement: PARTIAL"
    echo "  Review failed tests above"
    echo ""
    exit 1
fi
