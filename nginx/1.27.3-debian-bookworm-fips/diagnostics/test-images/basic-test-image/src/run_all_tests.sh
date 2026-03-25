#!/bin/bash
################################################################################
# Nginx FIPS Basic Test Image - Main Test Orchestrator
#
# This script runs all test suites and provides a comprehensive summary.
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Test results
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0
SUITE_RESULTS=()

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "================================================================================"
echo -e "${BOLD}${BLUE}Nginx wolfSSL FIPS 140-3 Basic Test Image${NC}"
echo -e "${BOLD}${BLUE}Comprehensive User Application Test Suite${NC}"
echo "================================================================================"
echo ""
echo "Base Image: cr.root.io/nginx:1.27.3-debian-bookworm-fips"
echo "wolfSSL Version: 5.8.2 FIPS 140-3 (Certificate #4718)"
echo "OpenSSL Version: 3.0.19"
echo "wolfProvider Version: 1.1.0"
echo ""

START_TIME=$(date +%s)

# Test Suite 1: TLS Protocol Tests
echo "================================================================================"
echo -e "${YELLOW}Running Test Suite 1: TLS Protocol Tests${NC}"
echo "================================================================================"
((TOTAL_SUITES++)) || true
if bash "$SCRIPT_DIR/test_tls_protocols.sh"; then
    ((PASSED_SUITES++)) || true
    SUITE_RESULTS+=("${GREEN}✓${NC} TLS Protocol Tests: PASS")
else
    ((FAILED_SUITES++)) || true
    SUITE_RESULTS+=("${RED}✗${NC} TLS Protocol Tests: FAIL")
fi
echo ""

# Test Suite 2: FIPS Cipher Tests
echo "================================================================================"
echo -e "${YELLOW}Running Test Suite 2: FIPS Cipher Tests${NC}"
echo "================================================================================"
((TOTAL_SUITES++)) || true
if bash "$SCRIPT_DIR/test_fips_ciphers.sh"; then
    ((PASSED_SUITES++)) || true
    SUITE_RESULTS+=("${GREEN}✓${NC} FIPS Cipher Tests: PASS")
else
    ((FAILED_SUITES++)) || true
    SUITE_RESULTS+=("${RED}✗${NC} FIPS Cipher Tests: FAIL")
fi
echo ""

# Test Suite 3: Certificate Validation Tests
echo "================================================================================"
echo -e "${YELLOW}Running Test Suite 3: Certificate Validation Tests${NC}"
echo "================================================================================"
((TOTAL_SUITES++)) || true
if bash "$SCRIPT_DIR/test_certificate_validation.sh"; then
    ((PASSED_SUITES++)) || true
    SUITE_RESULTS+=("${GREEN}✓${NC} Certificate Validation Tests: PASS")
else
    ((FAILED_SUITES++)) || true
    SUITE_RESULTS+=("${RED}✗${NC} Certificate Validation Tests: FAIL")
fi
echo ""

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Final Summary
echo "================================================================================"
echo -e "${BOLD}${BLUE}FINAL TEST SUMMARY${NC}"
echo "================================================================================"
echo ""
echo "Total Test Suites: $TOTAL_SUITES"
echo -e "Passed: ${GREEN}${PASSED_SUITES}${NC}"
echo -e "Failed: ${RED}${FAILED_SUITES}${NC}"
echo "Duration: ${DURATION} seconds"
echo ""

# Show individual suite results
echo "Test Suite Results:"
for result in "${SUITE_RESULTS[@]}"; do
    echo -e "  $result"
done
echo ""

# Determine exit status and final message
if [ $FAILED_SUITES -eq 0 ]; then
    echo -e "${GREEN}${BOLD}✓ ALL TESTS PASSED${NC}"
    echo -e "${GREEN}Nginx wolfSSL FIPS is production ready${NC}"
    echo ""
    echo "================================================================================"
    exit 0
elif [ $PASSED_SUITES -ge 2 ]; then
    echo -e "${YELLOW}${BOLD}⚠ PARTIAL SUCCESS (${PASSED_SUITES}/${TOTAL_SUITES} suites passed)${NC}"
    echo -e "${YELLOW}Review failed test suites above${NC}"
    echo ""
    echo "================================================================================"
    exit 1
else
    echo -e "${RED}${BOLD}✗ CRITICAL FAILURE (${FAILED_SUITES}/${TOTAL_SUITES} suites failed)${NC}"
    echo -e "${RED}Nginx wolfSSL FIPS implementation has significant issues${NC}"
    echo ""
    echo "================================================================================"
    exit 2
fi
