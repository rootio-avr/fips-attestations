#!/bin/bash
#
# Master Test Runner for FIPS Compliance Tests
# Executes all diagnostic tests in sequence
#

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Test results
total_tests=0
passed_tests=0
failed_tests=0

# Test function
run_test_suite() {
    local test_name="$1"
    local test_script="$2"

    total_tests=$((total_tests + 1))

    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}Running Test Suite: ${test_name}${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo ""

    if [ ! -f "$test_script" ]; then
        echo -e "${RED}✗ Test script not found: $test_script${NC}"
        failed_tests=$((failed_tests + 1))
        return 1
    fi

    if bash "$test_script"; then
        passed_tests=$((passed_tests + 1))
        echo -e "${GREEN}✓ Test suite passed: ${test_name}${NC}"
        return 0
    else
        failed_tests=$((failed_tests + 1))
        echo -e "${RED}✗ Test suite failed: ${test_name}${NC}"
        return 1
    fi
}

# Header
# clear screen (portable version for minimal environments)
command -v clear >/dev/null 2>&1 && clear || printf '\033[2J\033[H'
echo ""
echo "================================================================"
echo "  FIPS Compliance Master Test Runner"
echo "  Fedora 44 - Complete Diagnostic Suite"
echo "================================================================"
echo ""
echo "This will run all FIPS compliance tests:"
echo "  1. Advanced FIPS compliance tests"
echo "  2. Cipher suite tests"
echo "  3. Key size validation tests"
echo "  4. OpenSSL provider tests"
echo ""

# Only prompt if running interactively (stdin is a terminal)
if [[ -t 0 ]]; then
    echo "Press Enter to start, or Ctrl+C to cancel..."
    read -r
else
    echo "Running in non-interactive mode..."
    echo ""
fi

# Run all test suites
run_test_suite "Advanced FIPS Compliance" "$SCRIPT_DIR/fips-compliance-advanced.sh"
run_test_suite "Cipher Suite Tests" "$SCRIPT_DIR/cipher-suite-test.sh"
run_test_suite "Key Size Validation" "$SCRIPT_DIR/key-size-validation.sh"
run_test_suite "OpenSSL Provider Tests" "$SCRIPT_DIR/openssl-engine-test.sh"

# Final Summary
echo ""
echo "================================================================"
echo "              MASTER TEST SUITE SUMMARY"
echo "================================================================"
echo ""
echo "  Total Test Suites: $total_tests"
echo -e "  ${GREEN}Passed:            $passed_tests${NC}"
if [ $failed_tests -gt 0 ]; then
    echo -e "  ${RED}Failed:            $failed_tests${NC}"
else
    echo "  Failed:            $failed_tests"
fi
echo ""

if [ $passed_tests -eq $total_tests ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                        ║${NC}"
    echo -e "${GREEN}║          ✓ ALL TEST SUITES PASSED                     ║${NC}"
    echo -e "${GREEN}║                                                        ║${NC}"
    echo -e "${GREEN}║   FIPS 140-3 compliance validated successfully!       ║${NC}"
    echo -e "${GREEN}║                                                        ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                                                        ║${NC}"
    echo -e "${RED}║          ✗ SOME TEST SUITES FAILED                    ║${NC}"
    echo -e "${RED}║                                                        ║${NC}"
    echo -e "${RED}║   Review the output above for details.                ║${NC}"
    echo -e "${RED}║                                                        ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    exit 1
fi
