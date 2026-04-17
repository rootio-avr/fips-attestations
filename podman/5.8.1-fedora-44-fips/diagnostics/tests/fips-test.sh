#!/bin/bash
################################################################################
# FIPS Compliance Test Suite
################################################################################

IMAGE_NAME="$1"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_name="$1"
    local test_cmd="$2"

    echo -e "${YELLOW}[TEST]${NC} ${test_name}"

    if eval "${test_cmd}"; then
        echo -e "${GREEN}  ✓ PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}  ✗ FAIL${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

echo "FIPS Compliance Tests"
echo "=================="
echo ""

# Test 1: wolfSSL FIPS self-test
run_test "wolfSSL FIPS self-test" \
    "test-fips"

# Test 2: OpenSSL version
run_test "OpenSSL version check" \
    "openssl version | grep -q '3.5.0'"

# Test 3: wolfProvider is loaded
run_test "wolfProvider is loaded" \
    "openssl list -providers | grep -qi 'wolfSSL'"

# Test 4: FIPS mode enabled via GODEBUG
run_test "Go FIPS mode enabled (GODEBUG)" \
    "echo \$GODEBUG | grep -q 'fips140=only'"

# Test 5: GOLANG_FIPS environment variable set
run_test "GOLANG_FIPS environment variable" \
    "test \"\$GOLANG_FIPS\" = \"1\""

# Test 6: Go version (golang-fips)
run_test "Go toolchain version" \
    "go version | grep -q 'go1.25'"

# Test 7: Podman built with FIPS Go
run_test "Podman binary check" \
    "podman --version | grep -q '5.8.1'"

# Test 8: OpenSSL configuration file
run_test "OpenSSL configuration file exists" \
    "test -f /etc/ssl/openssl.cnf"

# Test 9: wolfSSL library present
run_test "wolfSSL library present" \
    "test -f /usr/local/lib/libwolfssl.so"

# Test 10: wolfProvider module present
run_test "wolfProvider module present" \
    "test -f /usr/local/openssl/lib64/ossl-modules/libwolfprov.so"

echo ""
echo "Summary: ${TESTS_PASSED} passed, ${TESTS_FAILED} failed"
echo ""

if [ ${TESTS_FAILED} -gt 0 ]; then
    exit 1
fi

exit 0
