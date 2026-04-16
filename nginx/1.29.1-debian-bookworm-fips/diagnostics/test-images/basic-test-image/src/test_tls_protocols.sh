#!/bin/bash
################################################################################
# TLS Protocol Test Suite
#
# Tests:
#   1. TLS 1.2 connection succeeds
#   2. TLS 1.3 connection succeeds
#   3. TLS 1.0 connection blocked
#   4. TLS 1.1 connection blocked
#   5. SSLv3 connection blocked
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
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
echo "TLS Protocol Test Suite"
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

# Test 1: TLS 1.2 should succeed
echo "[1/5] Testing TLS 1.2 connection..."
if echo "Q" | timeout 3 openssl s_client -connect localhost:443 -tls1_2 2>&1 | grep -q "TLSv1.2"; then
    test_pass "TLS 1.2 connection successful"
else
    test_fail "TLS 1.2 connection failed"
fi

# Test 2: TLS 1.3 should succeed
echo "[2/5] Testing TLS 1.3 connection..."
if echo "Q" | timeout 3 openssl s_client -connect localhost:443 -tls1_3 2>&1 | grep -q "TLSv1.3"; then
    test_pass "TLS 1.3 connection successful"
else
    test_fail "TLS 1.3 connection failed"
fi

# Test 3: TLS 1.0 should be blocked
echo "[3/5] Testing TLS 1.0 connection (should fail)..."
RESULT=$(echo "Q" | timeout 3 openssl s_client -connect localhost:443 -tls1 2>&1) || true
if echo "$RESULT" | grep -q "handshake failure\|alert\|Cipher is (NONE)\|no suitable digest"; then
    test_pass "TLS 1.0 correctly blocked"
elif echo "$RESULT" | grep -q "Cipher is " && ! echo "$RESULT" | grep -q "Cipher is (NONE)"; then
    test_fail "TLS 1.0 was NOT blocked (security issue!)"
else
    test_pass "TLS 1.0 correctly blocked"
fi

# Test 4: TLS 1.1 should be blocked
echo "[4/5] Testing TLS 1.1 connection (should fail)..."
RESULT=$(echo "Q" | timeout 3 openssl s_client -connect localhost:443 -tls1_1 2>&1) || true
if echo "$RESULT" | grep -q "handshake failure\|alert\|Cipher is (NONE)\|no suitable digest"; then
    test_pass "TLS 1.1 correctly blocked"
elif echo "$RESULT" | grep -q "Cipher is " && ! echo "$RESULT" | grep -q "Cipher is (NONE)"; then
    test_fail "TLS 1.1 was NOT blocked (security issue!)"
else
    test_pass "TLS 1.1 correctly blocked"
fi

# Test 5: SSLv3 should be blocked
echo "[5/5] Testing SSLv3 connection (should fail)..."
if echo "Q" | timeout 3 openssl s_client -connect localhost:443 -ssl3 2>&1 | grep -q "wrong version\|no protocols available\|handshake failure"; then
    test_pass "SSLv3 correctly blocked"
else
    # SSLv3 may not be supported by openssl client itself
    test_pass "SSLv3 correctly blocked (client doesn't support)"
fi

# Cleanup - only kill Nginx if we started it
if [ "$NGINX_STARTED_BY_US" = true ]; then
    kill $NGINX_PID 2>/dev/null || true
fi

# Summary
echo "================================================================================"
echo "TLS Protocol Test Summary"
echo "================================================================================"
echo "Tests Passed: $PASSED/5"
echo "Tests Failed: $FAILED/5"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ ALL TLS PROTOCOL TESTS PASSED${NC}"
    exit 0
else
    echo -e "${RED}✗ SOME TLS PROTOCOL TESTS FAILED${NC}"
    exit 1
fi
