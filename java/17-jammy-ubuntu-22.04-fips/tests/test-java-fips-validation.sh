#!/bin/bash
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "================================================================================"
echo "Test: Java FIPS Validation"
echo "================================================================================"
echo ""

TESTS_PASSED=0
TESTS_FAILED=0

echo "[Test 1] Java runtime exists"
if command -v java >/dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC} - Java runtime available"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - Java runtime not found"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "[Test 2] wolfSSL library exists"
if [ -f "/usr/local/lib/libwolfssl.so" ]; then
    echo -e "${GREEN}✓ PASS${NC} - wolfSSL FIPS library found"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - wolfSSL library not found"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "[Test 3] wolfProvider module exists"
if [ -f "/usr/lib/x86_64-linux-gnu/ossl-modules/libwolfprov.so" ] || [ -f "/usr/lib/aarch64-linux-gnu/ossl-modules/libwolfprov.so" ]; then
    echo -e "${GREEN}✓ PASS${NC} - wolfProvider module found"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - wolfProvider module not found"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "[Test 4] OpenSSL provider configuration"
if openssl list -providers 2>/dev/null | grep -qi "fips\|wolf"; then
    echo -e "${GREEN}✓ PASS${NC} - FIPS provider loaded"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - FIPS provider not loaded"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "[Test 5] Java demo application exists"
if [ -f "/app/java/FipsDemoApp.class" ]; then
    echo -e "${GREEN}✓ PASS${NC} - Java demo compiled"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - Java demo not found"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "[Test 6] Run Java FIPS demo"
echo "--------------------------------------------------------------------------------"
if cd /app/java && java FipsDemoApp >/tmp/java-output.log 2>&1; then
    echo -e "${GREEN}✓ PASS${NC} - Java demo executed successfully"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo ""
    echo "Demo Output:"
    cat /tmp/java-output.log
    echo ""
else
    echo -e "${RED}✗ FAIL${NC} - Java demo execution failed"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "Error output:"
    cat /tmp/java-output.log
    echo ""
fi

echo ""
echo "--------------------------------------------------------------------------------"
echo "[Test 7] Verify MD5 blocked"
if grep -qi "MD5.*BLOCKED\|MD5.*UNAVAILABLE" /tmp/java-output.log 2>/dev/null; then
    echo -e "${GREEN}✓ PASS${NC} - MD5 is blocked"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ WARNING${NC} - MD5 blocking not confirmed"
fi

echo ""
echo "[Test 8] Verify SHA-256 available"
if grep -qi "SHA-256.*AVAILABLE\|SHA-256.*SUCCESS\|SHA-256.*PASS" /tmp/java-output.log 2>/dev/null; then
    echo -e "${GREEN}✓ PASS${NC} - SHA-256 is available"
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
