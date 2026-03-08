#!/bin/bash
################################################################################
# Test Go → OpenSSL Integration
#
# Purpose: Verify golang-fips/go calls OpenSSL via dlopen
################################################################################

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "================================================================================"
echo "Test: Go → OpenSSL Integration"
echo "================================================================================"
echo ""

TESTS_PASSED=0
TESTS_FAILED=0

echo "[Test 1] Check OpenSSL libraries exist"
if [ -f "/usr/lib/x86_64-linux-gnu/libcrypto.so.3" ] || [ -f "/usr/lib/aarch64-linux-gnu/libcrypto.so.3" ]; then
    echo -e "${GREEN}✓ PASS${NC} - OpenSSL libcrypto.so.3 found"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - OpenSSL libcrypto.so.3 not found"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "[Test 2] Check wolfProvider module exists"
if [ -f "/usr/lib/x86_64-linux-gnu/ossl-modules/libwolfprov.so" ] || [ -f "/usr/lib/aarch64-linux-gnu/ossl-modules/libwolfprov.so" ]; then
    echo -e "${GREEN}✓ PASS${NC} - wolfProvider module found"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - wolfProvider module not found"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "[Test 3] Check wolfSSL FIPS library"
if [ -f "/usr/local/lib/libwolfssl.so" ]; then
    echo -e "${GREEN}✓ PASS${NC} - wolfSSL FIPS library found"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - wolfSSL FIPS library not found"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "[Test 4] Verify OpenSSL provider configuration"
if openssl list -providers 2>/dev/null | grep -qi "fips\|wolf"; then
    echo -e "${GREEN}✓ PASS${NC} - FIPS provider is loaded"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - FIPS provider not loaded"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "[Test 5] Runtime library loading (LD_DEBUG trace)"
if command -v apt-get >/dev/null 2>&1; then
    apt-get update -qq && apt-get install -y -qq strace >/dev/null 2>&1 || true
fi

if command -v strace >/dev/null 2>&1; then
    if LD_DEBUG=libs /app/fips-go-demo 2>&1 | grep -q "libcrypto\|libwolfssl"; then
        echo -e "${GREEN}✓ PASS${NC} - Runtime loads OpenSSL/wolfSSL libraries"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC} - No evidence of OpenSSL/wolfSSL loading"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
else
    echo -e "${YELLOW}⚠ SKIP${NC} - strace not available"
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
