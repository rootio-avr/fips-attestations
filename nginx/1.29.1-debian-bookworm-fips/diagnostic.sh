#!/bin/bash
################################################################################
# Nginx FIPS Diagnostic Test Runner
#
# This script runs all diagnostic tests for the Nginx FIPS image.
#
# Usage:
#   ./diagnostic.sh [TEST_NAME]
#
# Examples:
#   ./diagnostic.sh                    # Run all tests
#   ./diagnostic.sh test-nginx-fips-status.sh    # Run specific test
#
################################################################################

set -euo pipefail

# Configuration
IMAGE_TAG="${IMAGE_TAG:-cr.root.io/nginx:1.29.1-debian-bookworm-fips}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test tracking
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_section() {
    echo -e "\n${BLUE}==>${NC} ${1}"
}

# Check if image exists
check_image() {
    if ! docker images "$IMAGE_TAG" --format "{{.Repository}}:{{.Tag}}" | grep -q "$IMAGE_TAG"; then
        log_error "Image not found: $IMAGE_TAG"
        echo ""
        echo "Build the image first:"
        echo "  cd .. && ./build.sh"
        exit 1
    fi
    log_info "Using image: $IMAGE_TAG"
}

# Run a single test
run_test() {
    local test_file=$1
    local test_name=$(basename "$test_file" .sh)

    echo "================================================================================"
    echo "Running Test: $test_name"
    echo "================================================================================"

    if bash "$test_file"; then
        ((TESTS_PASSED++)) || true
        log_info "✅ $test_name PASSED"
    else
        ((TESTS_FAILED++)) || true
        FAILED_TESTS+=("$test_name")
        log_error "❌ $test_name FAILED"
    fi
    echo ""
}

# Run all tests
run_all_tests() {
    log_section "Starting Nginx FIPS Diagnostic Test Suite"

    check_image

    # Find all test files in diagnostics directory
    local test_files=($(find "$SCRIPT_DIR/diagnostics" -name "test-*.sh" -type f | sort))

    if [ ${#test_files[@]} -eq 0 ]; then
        log_warn "No test files found in $SCRIPT_DIR/diagnostics"
        exit 1
    fi

    log_info "Found ${#test_files[@]} test(s)"
    echo ""

    # Run each test
    for test_file in "${test_files[@]}"; do
        run_test "$test_file"
    done

    # Summary
    echo "================================================================================"
    echo "TEST SUMMARY"
    echo "================================================================================"
    echo "Total Tests:  $((TESTS_PASSED + TESTS_FAILED))"
    echo -e "Tests Passed: ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Tests Failed: ${RED}${TESTS_FAILED}${NC}"
    echo ""

    if [ $TESTS_FAILED -eq 0 ]; then
        log_info "✅ ALL TESTS PASSED"
        echo "================================================================================"
        exit 0
    else
        log_error "❌ SOME TESTS FAILED"
        echo ""
        echo "Failed tests:"
        for test in "${FAILED_TESTS[@]}"; do
            echo "  - $test"
        done
        echo "================================================================================"
        exit 1
    fi
}

# Main execution
main() {
    if [ $# -eq 0 ]; then
        # No arguments - run all tests
        run_all_tests
    else
        # Argument provided - run specific test
        local test_name=$1
        local test_file

        # Try to find the test file (support both full path and just filename)
        if [ -f "$SCRIPT_DIR/$test_name" ]; then
            test_file="$SCRIPT_DIR/$test_name"
        elif [ -f "$SCRIPT_DIR/diagnostics/$test_name" ]; then
            test_file="$SCRIPT_DIR/diagnostics/$test_name"
        else
            log_error "Test file not found: $test_name"
            log_error "Looked in: $SCRIPT_DIR and $SCRIPT_DIR/diagnostics"
            exit 1
        fi

        check_image
        run_test "$test_file"
        exit $?
    fi
}

main "$@"
