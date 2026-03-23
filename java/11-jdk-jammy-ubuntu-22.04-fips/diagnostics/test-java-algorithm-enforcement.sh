#!/bin/bash
################################################################################
# Test Java FIPS Algorithm Enforcement
#
# Purpose: Verify FIPS-approved algorithms are available
#          POC Requirement: Java Cryptographic Validation
################################################################################

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "================================================================================"
echo "Test: Java FIPS Algorithm Enforcement (FIPS POC Requirement)"
echo "================================================================================"
echo ""
echo "POC Validation: Java Cryptographic Validation"
echo "Requirement: FIPS-approved algorithms (SHA-256+) must succeed via wolfJCE"
echo ""

TESTS_PASSED=0
TESTS_FAILED=0

echo "[Test 1] Running Java FipsInitCheck Application"
echo "--------------------------------------------------------------------------------"
if java -cp /opt/wolfssl-fips/bin:/usr/share/java/* FipsInitCheck > /tmp/java-output.log 2>&1; then
    echo -e "${GREEN}✓ PASS${NC} - Java FipsInitCheck executed successfully"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo ""
    echo "Application Output (first 50 lines):"
    head -50 /tmp/java-output.log
    echo ""
    echo "... (output truncated, full output in /tmp/java-output.log)"
    echo ""
else
    echo -e "${RED}✗ FAIL${NC} - Java FipsInitCheck failed to execute"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "Error output:"
    cat /tmp/java-output.log
    echo ""
fi

echo ""
echo "[Test 2] Verify SHA-256 is available via wolfJCE"
if grep -q "MessageDigest: SHA-256 -> wolfJCE" /tmp/java-output.log; then
    echo -e "${GREEN}✓ PASS${NC} - SHA-256 is available via wolfJCE (FIPS approved)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - SHA-256 should be available via wolfJCE"
    echo "Expected: 'MessageDigest: SHA-256 -> wolfJCE'"
    echo "Actual SHA-256 output:"
    grep -i "SHA-256" /tmp/java-output.log || echo "  (no SHA-256 output found)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "[Test 3] Verify FIPS POST completed successfully"
if grep -q "FIPS POST test completed successfully" /tmp/java-output.log; then
    echo -e "${GREEN}✓ PASS${NC} - FIPS Power-On Self Test (POST) completed"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - FIPS POST should complete successfully"
    echo "Expected: 'FIPS POST test completed successfully'"
    echo "Actual POST output:"
    grep -i "POST\|power-on" /tmp/java-output.log || echo "  (no POST output found)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "[Test 4] Verify wolfJCE and wolfJSSE providers at correct priority"
if grep -q "wolfJCE provider verified at position 1" /tmp/java-output.log && \
   grep -q "wolfJSSE provider verified at position 2" /tmp/java-output.log; then
    echo -e "${GREEN}✓ PASS${NC} - wolfJCE at position 1, wolfJSSE at position 2"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - wolfSSL providers not at correct priority"
    echo "Expected: 'wolfJCE provider verified at position 1' and 'wolfJSSE provider verified at position 2'"
    echo "Actual provider output:"
    grep -i "provider verified at position" /tmp/java-output.log || echo "  (no provider position output found)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "[Test 5] Verify CA certificates in WKS format"
if grep -q "Successfully loaded .* certificates from WKS format cacerts" /tmp/java-output.log; then
    echo -e "${GREEN}✓ PASS${NC} - CA certificates verified in WKS format"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - CA certificates should be in WKS format"
    echo "Expected: 'Successfully loaded ... certificates from WKS format cacerts'"
    echo "Actual WKS output:"
    grep -i "WKS\|cacerts" /tmp/java-output.log || echo "  (no WKS output found)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "================================================================================"
echo "Test Summary: Java FIPS Algorithm Enforcement"
echo "================================================================================"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ ALL TESTS PASSED${NC}"
    echo ""
    echo "FIPS POC Requirement: VERIFIED"
    echo "  ✓ Java Cryptographic Validation via JNI"
    echo "  ✓ SHA-256: AVAILABLE via wolfJCE (FIPS approved)"
    echo "  ✓ FIPS POST: Completed successfully"
    echo "  ✓ Provider Priority: wolfJCE=1, wolfJSSE=2"
    echo "  ✓ CA Certificates: WKS format verified"
    echo ""
    exit 0
else
    echo -e "${RED}✗ SOME TESTS FAILED${NC}"
    echo ""
    echo "FIPS POC Requirement: PARTIAL"
    echo "  Review failed tests above"
    echo ""
    exit 1
fi
