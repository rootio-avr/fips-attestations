#!/bin/bash
################################################################################
# Gotenberg FIPS - Diagnostic Test Runner
#
# Purpose: Run all FIPS diagnostic tests on the Gotenberg Docker image
#
# Test Suites:
#   1. Backend Verification (6 tests) - wolfSSL/wolfProvider/CGO integration
#   2. Connectivity Tests (8 tests) - HTTPS connections, TLS protocols
#   3. FIPS Verification (7 tests) - FIPS mode, algorithm compliance
#   4. Crypto Operations (8 tests) - Hash algorithms, encryption
#   5. Gotenberg API Tests (6 tests) - PDF conversion functionality
#   [Optional] TLS Server Tests (5 tests) - TLS 1.3 server mode validation
#
# Total: 35 tests (40 with TLS server tests)
#
# Usage:
#   ./diagnostic.sh                # Run core diagnostics (35 tests)
#   ./diagnostic.sh backend        # Run specific test suite
#   ./diagnostic.sh --with-tls     # Run all tests including TLS server mode
#   ./diagnostic.sh tls-server     # Run only TLS server tests
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
IMAGE_NAME="cr.root.io/gotenberg:8.26.0-trixie-slim-fips"
RESULTS_DIR="Evidence"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_FILE="${RESULTS_DIR}/diagnostic_results_${TIMESTAMP}.txt"

echo ""
echo "================================================================================"
echo -e "${BOLD}${CYAN}Gotenberg FIPS - Diagnostic Test Runner${NC}"
echo "================================================================================"
echo ""
echo "Image: ${IMAGE_NAME}"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Check if Docker image exists
if ! docker image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
    echo -e "${RED}ERROR: Docker image not found: ${IMAGE_NAME}${NC}"
    echo ""
    echo "Please build the image first:"
    echo "  ./build.sh"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓${NC} Docker image found"
echo ""

# Create results directory if it doesn't exist
mkdir -p "${RESULTS_DIR}"

# Determine which test suites to run
TEST_SUITE="$1"

if [ -z "${TEST_SUITE}" ]; then
    # Run core diagnostic test suites (default)
    TEST_SUITES=("backend" "connectivity" "fips" "crypto" "gotenberg" "tls-server")
elif [ "${TEST_SUITE}" = "--with-tls" ]; then
    # Run all test suites including TLS server tests
    TEST_SUITES=("backend" "connectivity" "fips" "crypto" "gotenberg" "tls-server")
else
    # Run specific test suite
    TEST_SUITES=("${TEST_SUITE}")
fi

echo "================================================================================"
echo "Running diagnostic tests..."
echo "================================================================================"
echo ""

# Initialize counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Start results file
{
    echo "================================================================================";
    echo "Gotenberg FIPS - Diagnostic Test Results";
    echo "================================================================================";
    echo "";
    echo "Image: ${IMAGE_NAME}";
    echo "Date: $(date '+%Y-%m-%d %H:%M:%S')";
    echo "";
    echo "================================================================================";
    echo "";
} > "${RESULTS_FILE}"

# Run each test suite
for suite in "${TEST_SUITES[@]}"; do
    SUITE_SCRIPT="diagnostics/${suite}-tests.sh"

    if [ ! -f "${SUITE_SCRIPT}" ]; then
        echo -e "${YELLOW}⚠ WARNING: Test suite not found: ${SUITE_SCRIPT}${NC}"
        continue
    fi

    echo -e "${CYAN}Running ${suite} test suite...${NC}"
    echo ""

    # Make script executable
    chmod +x "${SUITE_SCRIPT}"

    # Run test suite and capture output
    if SUITE_OUTPUT=$("${SUITE_SCRIPT}" "${IMAGE_NAME}" 2>&1); then
        echo -e "${GREEN}✓${NC} ${suite} tests completed"

        # Append to results file
        echo "${SUITE_OUTPUT}" >> "${RESULTS_FILE}"

        # Parse test results
        SUITE_PASSED=$(echo "${SUITE_OUTPUT}" | grep -c "✓" || true)
        SUITE_FAILED=$(echo "${SUITE_OUTPUT}" | grep -c "✗" || true)

        PASSED_TESTS=$((PASSED_TESTS + SUITE_PASSED))
        FAILED_TESTS=$((FAILED_TESTS + SUITE_FAILED))
        TOTAL_TESTS=$((TOTAL_TESTS + SUITE_PASSED + SUITE_FAILED))
    else
        echo -e "${RED}✗${NC} ${suite} tests failed"
        echo "${SUITE_OUTPUT}" >> "${RESULTS_FILE}"

        # Try to parse partial results
        SUITE_PASSED=$(echo "${SUITE_OUTPUT}" | grep -c "✓" || true)
        SUITE_FAILED=$(echo "${SUITE_OUTPUT}" | grep -c "✗" || true)

        PASSED_TESTS=$((PASSED_TESTS + SUITE_PASSED))
        FAILED_TESTS=$((FAILED_TESTS + SUITE_FAILED))
        TOTAL_TESTS=$((TOTAL_TESTS + SUITE_PASSED + SUITE_FAILED))
    fi

    echo ""
done

# Summary
{
    echo "";
    echo "================================================================================";
    echo "Test Summary";
    echo "================================================================================";
    echo "";
    echo "Total tests: ${TOTAL_TESTS}";
    echo "Passed: ${PASSED_TESTS}";
    echo "Failed: ${FAILED_TESTS}";
    echo "";

    if [ ${FAILED_TESTS} -eq 0 ]; then
        echo "Overall Status: ✓ ALL TESTS PASSED";
    else
        echo "Overall Status: ✗ SOME TESTS FAILED";
    fi

    echo "";
    echo "================================================================================";
} | tee -a "${RESULTS_FILE}"

echo ""
echo "================================================================================"
if [ ${FAILED_TESTS} -eq 0 ]; then
    echo -e "${GREEN}✓ All diagnostic tests passed (${PASSED_TESTS}/${TOTAL_TESTS})${NC}"
else
    echo -e "${RED}✗ Some tests failed (${PASSED_TESTS}/${TOTAL_TESTS} passed, ${FAILED_TESTS} failed)${NC}"
fi
echo "================================================================================"
echo ""
echo "Results saved to: ${RESULTS_FILE}"
echo ""

# Show note about TLS server tests if not included
if [ "${TEST_SUITE}" != "--with-tls" ] && [ "${TEST_SUITE}" != "tls-server" ]; then
    echo -e "${CYAN}Note:${NC} TLS server mode tests not run (validates TLS 1.3 session tickets)"
    echo "      Run with: ./diagnostic.sh --with-tls"
    echo "      Or standalone: ./diagnostics/tls-server-tests.sh"
    echo ""
fi

# Exit with appropriate code
if [ ${FAILED_TESTS} -eq 0 ]; then
    exit 0
else
    exit 1
fi
