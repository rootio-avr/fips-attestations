#!/bin/bash
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "================================================================================"
echo "Test: Java FIPS Validation"
echo "================================================================================"
echo ""

TESTS_PASSED=0
TESTS_FAILED=0

echo "[Test 1] Java runtime exists"
if command -v java >/dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC} - Java runtime available"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - Java runtime not found"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "[Test 2] wolfSSL library exists"
if [ -f "/usr/local/lib/libwolfssl.so" ]; then
    echo -e "${GREEN}✓ PASS${NC} - wolfSSL FIPS library found"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - wolfSSL library not found"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "[Test 3] wolfCrypt JNI library exists"
if [ -f "/usr/lib/jni/libwolfcryptjni.so" ]; then
    echo -e "${GREEN}✓ PASS${NC} - wolfCrypt JNI library found"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - wolfCrypt JNI library not found at /usr/lib/jni/libwolfcryptjni.so"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "[Test 4] wolfSSL JNI library exists"
if [ -f "/usr/lib/jni/libwolfssljni.so" ]; then
    echo -e "${GREEN}✓ PASS${NC} - wolfSSL JNI library found"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - wolfSSL JNI library not found at /usr/lib/jni/libwolfssljni.so"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "[Test 5] wolfCrypt JNI JAR file exists"
if [ -f "/usr/share/java/wolfcrypt-jni.jar" ]; then
    echo -e "${GREEN}✓ PASS${NC} - wolfCrypt JNI JAR found"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - wolfCrypt JNI JAR not found at /usr/share/java/wolfcrypt-jni.jar"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "[Test 6] wolfSSL JSSE JAR file exists"
if [ -f "/usr/share/java/wolfssl-jsse.jar" ]; then
    echo -e "${GREEN}✓ PASS${NC} - wolfSSL JSSE JAR found"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - wolfSSL JSSE JAR not found at /usr/share/java/wolfssl-jsse.jar"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "[Test 7] Filtered providers JAR file exists"
if [ -f "/usr/share/java/filtered-providers.jar" ]; then
    echo -e "${GREEN}✓ PASS${NC} - Filtered providers JAR found"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - Filtered providers JAR not found at /usr/share/java/filtered-providers.jar"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "[Test 8] FipsInitCheck application exists"
if [ -f "/opt/wolfssl-fips/bin/FipsInitCheck.class" ]; then
    echo -e "${GREEN}✓ PASS${NC} - FipsInitCheck application found"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - FipsInitCheck not found at /opt/wolfssl-fips/bin/FipsInitCheck.class"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "[Test 9] Run Java FipsInitCheck application"
echo "--------------------------------------------------------------------------------"
if java -cp /opt/wolfssl-fips/bin:/usr/share/java/* FipsInitCheck >/tmp/java-output.log 2>&1; then
    echo -e "${GREEN}✓ PASS${NC} - FipsInitCheck executed successfully"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo ""
    echo "Application Output (first 30 lines):"
    head -30 /tmp/java-output.log
    echo ""
    echo "... (output truncated, full output in /tmp/java-output.log)"
    echo ""
else
    echo -e "${RED}✗ FAIL${NC} - FipsInitCheck execution failed"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "Error output:"
    cat /tmp/java-output.log
    echo ""
fi

echo ""
echo "--------------------------------------------------------------------------------"
echo "[Test 10] Verify SHA-256 available via wolfJCE"
if grep -q "MessageDigest: SHA-256 -> wolfJCE" /tmp/java-output.log 2>/dev/null; then
    echo -e "${GREEN}✓ PASS${NC} - SHA-256 is available via wolfJCE"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - SHA-256 should be available via wolfJCE"
    echo "Expected: 'MessageDigest: SHA-256 -> wolfJCE'"
    grep -i "SHA-256" /tmp/java-output.log || echo "  (no SHA-256 output found)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "[Test 11] Verify wolfJCE provider at position 1"
if grep -q "wolfJCE provider verified at position 1" /tmp/java-output.log 2>/dev/null; then
    echo -e "${GREEN}✓ PASS${NC} - wolfJCE provider at position 1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - wolfJCE should be at position 1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "[Test 12] Verify wolfJSSE provider at position 2"
if grep -q "wolfJSSE provider verified at position 2" /tmp/java-output.log 2>/dev/null; then
    echo -e "${GREEN}✓ PASS${NC} - wolfJSSE provider at position 2"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - wolfJSSE should be at position 2"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "================================================================================"
echo "Test Summary"
echo "================================================================================"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ ALL TESTS PASSED${NC}"
    exit 0
else
    echo -e "${RED}✗ SOME TESTS FAILED${NC}"
    exit 1
fi
