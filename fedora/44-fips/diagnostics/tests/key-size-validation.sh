#!/bin/bash
#
# FIPS Key Size Validation Test
# Tests minimum key sizes required by FIPS 140-3
#

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

tests_run=0
tests_passed=0
tests_failed=0

test_key_size() {
    local test_name="$1"
    local test_command="$2"
    local expect_success="${3:-true}"

    tests_run=$((tests_run + 1))
    printf "  [%02d] %-55s" "$tests_run" "$test_name"

    if eval "$test_command" > /dev/null 2>&1; then
        if [ "$expect_success" = "true" ]; then
            tests_passed=$((tests_passed + 1))
            echo -e "${GREEN}✓ PASS${NC}"
        else
            tests_failed=$((tests_failed + 1))
            echo -e "${RED}✗ FAIL${NC} (should fail)"
        fi
    else
        if [ "$expect_success" = "false" ]; then
            tests_passed=$((tests_passed + 1))
            echo -e "${GREEN}✓ PASS${NC} (blocked)"
        else
            tests_failed=$((tests_failed + 1))
            echo -e "${RED}✗ FAIL${NC}"
        fi
    fi
}

echo ""
echo "================================================================"
echo "  FIPS Key Size Validation Test"
echo "  Minimum Key Sizes Required by FIPS 140-3"
echo "================================================================"
echo ""

# RSA Minimum 2048 bits
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}RSA Key Size Requirements (Minimum: 2048 bits)${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

test_key_size "RSA-1024 (blocked - too small)" \
    'openssl genrsa 1024 2>/dev/null' \
    "false"

test_key_size "RSA-2048 (minimum FIPS)" \
    'openssl genrsa 2048 2>/dev/null'

test_key_size "RSA-3072 (FIPS approved)" \
    'openssl genrsa 3072 2>/dev/null'

test_key_size "RSA-4096 (FIPS approved)" \
    'openssl genrsa 4096 2>/dev/null'

echo ""
echo "================================================================"
echo "                      Test Summary"
echo "================================================================"
echo ""
echo "  Total Tests:   $tests_run"
echo -e "  ${GREEN}Passed:        $tests_passed${NC}"
[ $tests_failed -gt 0 ] && echo -e "  ${RED}Failed:        $tests_failed${NC}" || echo "  Failed:        $tests_failed"
echo ""

if [ $tests_passed -eq $tests_run ]; then
    echo -e "${GREEN}✓ ALL TESTS PASSED${NC}"
    echo ""
    echo "Key size validation successful:"
    echo "  - Minimum FIPS key sizes enforced"
    echo "  - Weak keys properly blocked"
    echo ""
    exit 0
else
    echo -e "${RED}✗ SOME TESTS FAILED${NC}"
    exit 1
fi
