#!/bin/bash
################################################################################
# Fedora 44 FIPS - Diagnostic Test Runner
#
# Purpose: Execute FIPS validation diagnostics and demo applications
#
# Test Suites:
#   1. Advanced FIPS Compliance (44 tests) - Hash, encryption, keys, HMAC, RNG
#   2. Cipher Suite Tests (~20 tests) - TLS 1.2/1.3 cipher validation
#   3. Key Size Validation (4 tests) - Minimum key size enforcement
#   4. OpenSSL Provider Tests - Provider configuration verification
#
# Demo Applications:
#   - crypto-demo: Interactive cryptography demonstration
#   - ssl-tls-test: HTTPS/TLS connection testing
#   - file-encryption: File encrypt/decrypt utility
#   - fips-report: Comprehensive FIPS configuration report
#
# Total: ~68 automated tests + 4 demo applications
#
# Usage:
#   ./diagnostic.sh                              # Run all test suites
#   ./diagnostic.sh fips-compliance-advanced.sh  # Run specific test
#   ./diagnostic.sh crypto-demo                  # Run demo app
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
IMAGE_NAME="cr.root.io/fedora:44-fips"
RESULTS_DIR="Evidence"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_FILE="${RESULTS_DIR}/diagnostic_results_${TIMESTAMP}.txt"

# Diagnostics paths (inside container)
TESTS_PATH="/opt/fips/diagnostics/tests"
APPS_PATH="/opt/fips/diagnostics/apps"

echo ""
echo "================================================================================"
echo -e "${BOLD}${CYAN}Fedora 44 FIPS - Diagnostic Test Runner${NC}"
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

# Create results directory
mkdir -p "${RESULTS_DIR}"

# Determine what to run
TARGET="$1"

# Available test suites
declare -A TEST_SUITES
TEST_SUITES=(
    ["fips-compliance-advanced.sh"]="Advanced FIPS Compliance (44 tests)"
    ["cipher-suite-test.sh"]="TLS Cipher Suite Tests"
    ["key-size-validation.sh"]="Key Size Validation (4 tests)"
    ["openssl-engine-test.sh"]="OpenSSL Provider Verification"
    ["run-all-tests.sh"]="All Test Suites (Master Runner)"
)

# Available demo applications
declare -A DEMO_APPS
DEMO_APPS=(
    ["crypto-demo"]="Interactive Cryptography Demonstration"
    ["ssl-tls-test"]="HTTPS/TLS Connection Testing"
    ["file-encryption"]="File Encryption/Decryption Utility"
    ["fips-report"]="FIPS Configuration Report Generator"
)

# Function to show available options
show_usage() {
    echo "Usage: $0 [test-suite|demo-app]"
    echo ""
    echo "Test Suites:"
    for key in "${!TEST_SUITES[@]}"; do
        printf "  %-35s %s\n" "$key" "${TEST_SUITES[$key]}"
    done | sort
    echo ""
    echo "Demo Applications:"
    for key in "${!DEMO_APPS[@]}"; do
        printf "  %-35s %s\n" "$key" "${DEMO_APPS[$key]}"
    done | sort
    echo ""
    echo "Examples:"
    echo "  $0                              # Run all test suites"
    echo "  $0 fips-compliance-advanced.sh  # Run specific test"
    echo "  $0 crypto-demo                  # Run demo app"
    echo ""
}

# Function to run test suite
run_test_suite() {
    local test_script="$1"
    local test_path="${TESTS_PATH}/${test_script}"

    echo -e "${CYAN}Running test suite: ${test_script}${NC}"
    echo ""

    # Run test in container and save output
    if docker run --rm \
        --entrypoint="" \
        "${IMAGE_NAME}" \
        bash "${test_path}" | tee -a "${RESULTS_FILE}"; then

        echo ""
        echo -e "${GREEN}✓ Test suite completed${NC}"
        return 0
    else
        echo ""
        echo -e "${RED}✗ Test suite failed${NC}"
        return 1
    fi
}

# Function to run demo app
run_demo_app() {
    local app_name="$1"
    local app_path="${APPS_PATH}/${app_name}.sh"

    echo -e "${CYAN}Running demo application: ${app_name}${NC}"
    echo ""

    # Run app in container
    if docker run --rm -it \
        --entrypoint="" \
        "${IMAGE_NAME}" \
        bash "${app_path}"; then

        echo ""
        echo -e "${GREEN}✓ Demo application completed${NC}"
        return 0
    else
        echo ""
        echo -e "${RED}✗ Demo application failed${NC}"
        return 1
    fi
}

# Start results file
{
    echo "================================================================================";
    echo "Fedora 44 FIPS - Diagnostic Test Results";
    echo "================================================================================";
    echo "";
    echo "Image: ${IMAGE_NAME}";
    echo "Date: $(date '+%Y-%m-%d %H:%M:%S')";
    echo "";
    echo "================================================================================";
    echo "";
} > "${RESULTS_FILE}"

# Main execution logic
if [ -z "${TARGET}" ]; then
    # No argument - run all test suites
    echo "================================================================================"
    echo "Running all test suites..."
    echo "================================================================================"
    echo ""

    # Run the master test runner
    run_test_suite "run-all-tests.sh"
    EXIT_CODE=$?

elif [ -n "${TEST_SUITES[$TARGET]}" ]; then
    # Specific test suite
    echo "================================================================================"
    echo "Running: ${TEST_SUITES[$TARGET]}"
    echo "================================================================================"
    echo ""

    run_test_suite "${TARGET}"
    EXIT_CODE=$?

elif [ -n "${DEMO_APPS[$TARGET]}" ]; then
    # Demo application
    echo "================================================================================"
    echo "Running: ${DEMO_APPS[$TARGET]}"
    echo "================================================================================"
    echo ""

    run_demo_app "${TARGET}"
    EXIT_CODE=$?

elif [ "$TARGET" = "help" ] || [ "$TARGET" = "-h" ] || [ "$TARGET" = "--help" ]; then
    # Show usage
    show_usage
    exit 0

else
    # Unknown target
    echo -e "${RED}ERROR: Unknown test suite or demo app: ${TARGET}${NC}"
    echo ""
    show_usage
    exit 1
fi

# Final summary
echo ""
echo "================================================================================"
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ Diagnostics completed successfully${NC}"
else
    echo -e "${RED}✗ Diagnostics failed with exit code: $EXIT_CODE${NC}"
fi
echo "================================================================================"
echo ""

# Show results file location if tests were run (not for demo apps)
if [ -n "${TARGET}" ] && [ -z "${DEMO_APPS[$TARGET]}" ]; then
    echo "Results saved to: ${RESULTS_FILE}"
    echo ""
elif [ -z "${TARGET}" ]; then
    echo "Results saved to: ${RESULTS_FILE}"
    echo ""
fi

exit $EXIT_CODE
