#!/bin/bash
################################################################################
# Podman FIPS - Diagnostic Test Runner
################################################################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="${IMAGE_NAME:-cr.root.io/podman:5.8.1-fedora-44-fips}"
EVIDENCE_DIR="./Evidence"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_FILE="${EVIDENCE_DIR}/diagnostic_results_${TIMESTAMP}.txt"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

mkdir -p "${EVIDENCE_DIR}"

# Start output redirection
exec > >(tee "${RESULTS_FILE}") 2>&1

echo "================================================================================"
echo -e "${CYAN}Podman FIPS - Diagnostic Test Runner${NC}"
echo "================================================================================"
echo ""
echo "Image: ${IMAGE_NAME}"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Note: Image existence check is performed by the calling script (diagnostic.sh)
# since this script runs inside the container and cannot check the host's Docker images
echo -e "${GREEN}✓${NC} Starting diagnostic tests"
echo ""

# Function to run a test
run_test() {
    local test_name="$1"
    local test_script="$2"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    echo -e "${CYAN}Running ${test_name}...${NC}"
    echo ""

    if bash "${test_script}" "${IMAGE_NAME}"; then
        echo ""
        echo -e "${GREEN}✓${NC} ${test_name} completed"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo ""
        echo -e "${RED}✗${NC} ${test_name} failed"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    echo ""
}

echo "================================================================================"
echo "Running diagnostic tests..."
echo "================================================================================"
echo ""

# Run test suites
run_test "FIPS test suite" "./tests/fips-test.sh"
run_test "Podman basic test suite" "./tests/podman-basic-test.sh"
run_test "Crypto test suite" "./tests/crypto-test.sh"

# Summary
echo ""
echo "================================================================================"
echo "Test Summary"
echo "================================================================================"
echo ""
echo "Total tests: ${TOTAL_TESTS}"
echo "Passed: ${PASSED_TESTS}"
echo "Failed: ${FAILED_TESTS}"
echo ""

if [ ${FAILED_TESTS} -eq 0 ]; then
    echo "Overall Status: ✓ ALL TESTS PASSED"
    EXIT_CODE=0
else
    echo "Overall Status: ✗ SOME TESTS FAILED"
    EXIT_CODE=1
fi

echo ""
echo "================================================================================"
echo ""

if [ ${EXIT_CODE} -eq 0 ]; then
    echo -e "${GREEN}✓ All diagnostic tests passed (${PASSED_TESTS}/${TOTAL_TESTS})${NC}"
else
    echo -e "${RED}✗ ${FAILED_TESTS} test(s) failed${NC}"
fi

echo "================================================================================"
echo ""
echo "Results saved to: ${RESULTS_FILE}"
echo ""

exit ${EXIT_CODE}
