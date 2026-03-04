#!/bin/bash
################################################################################
# Ubuntu FIPS Go - Test Runner
#
# Purpose: Run all FIPS validation tests
################################################################################

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo "================================================================================"
echo -e "${BOLD}${CYAN}Ubuntu FIPS Go - Test Suite${NC}"
echo "================================================================================"
echo ""

TESTS_PASSED=0
TESTS_FAILED=0

# Test 1: Algorithm Enforcement
echo "Running Test 1/3: Algorithm Enforcement..."
echo "--------------------------------------------------------------------------------"
if bash test-go-fips-algorithms.sh; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓ Test 1 PASSED${NC}"
else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗ Test 1 FAILED${NC}"
fi
echo ""

# Test 2: OpenSSL Integration
echo "Running Test 2/3: OpenSSL Integration..."
echo "--------------------------------------------------------------------------------"
if bash test-go-openssl-integration.sh; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓ Test 2 PASSED${NC}"
else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗ Test 2 FAILED${NC}"
fi
echo ""

# Test 3: Full FIPS Validation
echo "Running Test 3/4: Full FIPS Validation..."
echo "--------------------------------------------------------------------------------"
if bash test-go-fips-validation.sh; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓ Test 3 PASSED${NC}"
else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗ Test 3 FAILED${NC}"
fi
echo ""

# Test 4: In-Container Go Compilation
echo "Running Test 4/6: In-Container Go Compilation..."
echo "--------------------------------------------------------------------------------"
if bash test-go-in-container-compilation.sh; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓ Test 4 PASSED${NC}"
else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗ Test 4 FAILED${NC}"
fi
echo ""

# Test 5: CLI Algorithm Enforcement (FIPS POC Requirement)
echo "Running Test 5/6: CLI Algorithm Enforcement (POC Requirement)..."
echo "--------------------------------------------------------------------------------"
if bash test-openssl-cli-algorithms.sh; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓ Test 5 PASSED${NC}"
else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗ Test 5 FAILED${NC}"
fi
echo ""

# Test 6: OS FIPS Status Check (FIPS POC Requirement)
echo "Running Test 6/6: OS FIPS Status Check (POC Requirement)..."
echo "--------------------------------------------------------------------------------"
if bash test-os-fips-status.sh; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓ Test 6 PASSED${NC}"
else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗ Test 6 FAILED${NC}"
fi
echo ""

echo "================================================================================"
echo "Final Test Summary"
echo "================================================================================"
echo "Test Suites Passed: $TESTS_PASSED/6"
echo "Test Suites Failed: $TESTS_FAILED/6"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ ALL TEST SUITES PASSED${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}✗ SOME TEST SUITES FAILED${NC}"
    echo ""
    exit 1
fi
