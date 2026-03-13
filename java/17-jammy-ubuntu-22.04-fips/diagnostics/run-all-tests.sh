#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo "================================================================================"
echo -e "${BOLD}${CYAN}Ubuntu FIPS Java - Test Suite${NC}"
echo "================================================================================"
echo ""

TESTS_PASSED=0
TESTS_FAILED=0

# Test 1: Java Algorithm Enforcement (FIPS POC Requirement)
echo "Running Test 1/4: Java Algorithm Enforcement (POC Requirement)..."
echo "--------------------------------------------------------------------------------"
if bash test-java-algorithm-enforcement.sh; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓ Test 1 PASSED${NC}"
else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗ Test 1 FAILED${NC}"
fi
echo ""

# Test 2: Java FIPS Validation
echo "Running Test 2/4: Java FIPS Validation..."
echo "--------------------------------------------------------------------------------"
if bash test-java-fips-validation.sh; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓ Test 2 PASSED${NC}"
else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗ Test 2 FAILED${NC}"
fi
echo ""

# Test 3: Java Algorithm Enforcement (FIPS POC Requirement)
echo "Running Test 3/4: Java Algorithm Enforcement (POC Requirement)..."
echo "--------------------------------------------------------------------------------"
if bash test-java-algorithms.sh; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓ Test 3 PASSED${NC}"
else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗ Test 3 FAILED${NC}"
fi
echo ""

# Test 4: OS FIPS Status Check (FIPS POC Requirement)
echo "Running Test 4/4: OS FIPS Status Check (POC Requirement)..."
echo "--------------------------------------------------------------------------------"
if bash test-os-fips-status.sh; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓ Test 4 PASSED${NC}"
else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗ Test 4 FAILED${NC}"
fi
echo ""

echo "================================================================================"
echo "Final Test Summary"
echo "================================================================================"
echo "Test Suites Passed: $TESTS_PASSED/4"
echo "Test Suites Failed: $TESTS_FAILED/4"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo "================================================================================"
    echo -e "${GREEN}✓ ALL TESTS PASSED${NC}"
    echo "================================================================================"
    echo ""
    exit 0
else
    echo "================================================================================"
    echo -e "${RED}✗ SOME TESTS FAILED${NC}"
    echo "================================================================================"
    echo ""
    exit 1
fi
