#!/bin/bash
################################################################################
# FIPS Cipher Suite Test
#
# Tests:
#   1. FIPS-approved cipher succeeds (TLS 1.2)
#   2. FIPS-approved cipher succeeds (TLS 1.3)
#   3. Non-FIPS cipher blocked (RC4)
#   4. Non-FIPS cipher blocked (DES)
#   5. Non-FIPS cipher blocked (3DES)
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

test_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED++)) || true
}

test_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED++)) || true
}

echo "================================================================================"
echo "FIPS Cipher Suite Test"
echo "================================================================================"
echo ""

# Start Nginx if not already running
if ! pgrep -x nginx > /dev/null; then
    echo "Starting Nginx..."
    nginx &
    NGINX_PID=$!
    NGINX_STARTED_BY_US=true
    sleep 2
else
    echo "Nginx already running, using existing instance..."
    NGINX_STARTED_BY_US=false
fi

# Test 1: FIPS-approved TLS 1.2 cipher (ECDHE-RSA-AES256-GCM-SHA384)
echo "[1/5] Testing FIPS-approved cipher (TLS 1.2)..."
RESULT=$(echo "Q" | timeout 3 openssl s_client -connect localhost:443 -tls1_2 -cipher 'ECDHE-RSA-AES256-GCM-SHA384' 2>&1)
if echo "$RESULT" | grep -q "Cipher.*:.*ECDHE-RSA-AES256-GCM-SHA384"; then
    test_pass "FIPS cipher ECDHE-RSA-AES256-GCM-SHA384 accepted"
else
    test_fail "FIPS cipher ECDHE-RSA-AES256-GCM-SHA384 rejected"
fi

# Test 2: FIPS-approved TLS 1.3 cipher
echo "[2/5] Testing FIPS-approved cipher (TLS 1.3)..."
RESULT=$(echo "Q" | timeout 3 openssl s_client -connect localhost:443 -tls1_3 2>&1)
if echo "$RESULT" | grep -q "Cipher is TLS_AES_256_GCM_SHA384\|Cipher is TLS_AES_128_GCM_SHA256"; then
    CIPHER=$(echo "$RESULT" | grep "Cipher is" | head -1 | awk '{print $NF}')
    test_pass "FIPS cipher $CIPHER accepted (TLS 1.3)"
else
    test_fail "No FIPS cipher negotiated for TLS 1.3"
fi

# Test 3: Non-FIPS cipher RC4 should be blocked
echo "[3/5] Testing non-FIPS cipher RC4 (should fail)..."
RESULT=$(echo "Q" | timeout 3 openssl s_client -connect localhost:443 -cipher 'RC4-SHA' 2>&1) || true
if echo "$RESULT" | grep -q "no cipher" || echo "$RESULT" | grep -q "handshake failure"; then
    test_pass "RC4 cipher correctly blocked"
elif echo "$RESULT" | grep -q "Cipher.*:.*RC4"; then
    test_fail "RC4 cipher was NOT blocked (security issue!)"
else
    test_pass "RC4 cipher correctly blocked"
fi

# Test 4: Non-FIPS cipher DES should be blocked
echo "[4/5] Testing non-FIPS cipher DES (should fail)..."
RESULT=$(echo "Q" | timeout 3 openssl s_client -connect localhost:443 -cipher 'DES-CBC-SHA' 2>&1) || true
if echo "$RESULT" | grep -q "no cipher\|handshake failure"; then
    test_pass "DES cipher correctly blocked"
elif echo "$RESULT" | grep -q "Cipher.*:.*DES"; then
    test_fail "DES cipher was NOT blocked (security issue!)"
else
    test_pass "DES cipher correctly blocked"
fi

# Test 5: Non-FIPS cipher 3DES should be blocked
echo "[5/5] Testing non-FIPS cipher 3DES (should fail)..."
RESULT=$(echo "Q" | timeout 3 openssl s_client -connect localhost:443 -cipher 'DES-CBC3-SHA' 2>&1) || true
if echo "$RESULT" | grep -q "no cipher\|handshake failure"; then
    test_pass "3DES cipher correctly blocked"
elif echo "$RESULT" | grep -q "Cipher.*:.*3DES\|Cipher.*:.*DES-CBC3"; then
    test_fail "3DES cipher was NOT blocked (security issue!)"
else
    test_pass "3DES cipher correctly blocked"
fi

# Cleanup - only kill Nginx if we started it
if [ "$NGINX_STARTED_BY_US" = true ]; then
    kill $NGINX_PID 2>/dev/null || true
fi

# Summary
echo "================================================================================"
echo "FIPS Cipher Test Summary"
echo "================================================================================"
echo "Tests Passed: $PASSED/5"
echo "Tests Failed: $FAILED/5"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ ALL FIPS CIPHER TESTS PASSED${NC}"
    exit 0
else
    echo -e "${RED}✗ SOME FIPS CIPHER TESTS FAILED${NC}"
    exit 1
fi
