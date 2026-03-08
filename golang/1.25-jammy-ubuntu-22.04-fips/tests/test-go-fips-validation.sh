#!/bin/bash
################################################################################
# Full Go FIPS Validation
#
# Purpose: Comprehensive FIPS environment and compliance validation
################################################################################

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "================================================================================"
echo "Test: Full Go FIPS Validation"
echo "================================================================================"
echo ""

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNING=0

echo "--- Environment Variables ---"
echo ""

echo "[Test 1] GOLANG_FIPS environment variable"
if [ "$GOLANG_FIPS" = "1" ]; then
    echo -e "${GREEN}✓ PASS${NC} - GOLANG_FIPS=1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - GOLANG_FIPS not set to 1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "[Test 2] GODEBUG environment variable"
if [ "$GODEBUG" = "fips140=only" ]; then
    echo -e "${GREEN}✓ PASS${NC} - GODEBUG=fips140=only"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ WARNING${NC} - GODEBUG not set to fips140=only"
    TESTS_WARNING=$((TESTS_WARNING + 1))
fi

echo ""
echo "[Test 3] OPENSSL_CONF environment variable"
if [ -n "$OPENSSL_CONF" ] && [ -f "$OPENSSL_CONF" ]; then
    echo -e "${GREEN}✓ PASS${NC} - OPENSSL_CONF points to valid file"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - OPENSSL_CONF not properly configured"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "--- Cryptographic Libraries ---"
echo ""

echo "[Test 4] wolfSSL FIPS library registration"
if ldconfig -p | grep -q wolfssl; then
    echo -e "${GREEN}✓ PASS${NC} - wolfSSL registered with ldconfig"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - wolfSSL not registered with ldconfig"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "[Test 5] OpenSSL version check"
if openssl version | grep -q "OpenSSL 3"; then
    echo -e "${GREEN}✓ PASS${NC} - OpenSSL 3.x detected"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - OpenSSL 3.x not found"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "--- Application Tests ---"
echo ""

echo "[Test 6] Go application exists and is executable"
if [ -x "/app/fips-go-demo" ]; then
    echo -e "${GREEN}✓ PASS${NC} - /app/fips-go-demo is executable"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - /app/fips-go-demo not executable"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "[Test 7] Run Go FIPS demo"
if /app/fips-go-demo >/dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC} - Go FIPS demo executed without errors"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    EXIT_CODE=$?
    echo -e "${RED}✗ FAIL${NC} - Go FIPS demo failed (exit code: $EXIT_CODE)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "================================================================================"
echo "Validation Summary"
echo "================================================================================"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo "Warnings: $TESTS_WARNING"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ FIPS VALIDATION PASSED${NC}"
    exit 0
else
    echo -e "${RED}✗ FIPS VALIDATION FAILED${NC}"
    exit 1
fi
