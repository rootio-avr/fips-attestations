#!/bin/bash
################################################################################
# Certificate Validation Test
#
# Tests:
#   1. Self-signed certificate loaded
#   2. Certificate is valid RSA 2048-bit
#   3. OpenSSL provider verification
#   4. FIPS POST validation
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
echo "Certificate Validation Test"
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

# Test 1: Certificate is served
echo "[1/4] Testing certificate availability..."
CERT=$(echo "Q" | timeout 3 openssl s_client -connect localhost:443 2>&1 | openssl x509 -noout -text 2>/dev/null || echo "")
if [ -n "$CERT" ]; then
    test_pass "Certificate successfully retrieved"
else
    test_fail "Failed to retrieve certificate"
fi

# Test 2: Certificate uses RSA 2048-bit (FIPS minimum)
echo "[2/4] Testing certificate key size..."
if echo "Q" | timeout 3 openssl s_client -connect localhost:443 2>&1 | openssl x509 -noout -text 2>/dev/null | grep -q "Public-Key: (2048 bit)"; then
    test_pass "Certificate uses RSA 2048-bit (FIPS compliant)"
else
    # Check for 4096-bit (also FIPS compliant)
    if echo "Q" | timeout 3 openssl s_client -connect localhost:443 2>&1 | openssl x509 -noout -text 2>/dev/null | grep -q "Public-Key: (4096 bit)"; then
        test_pass "Certificate uses RSA 4096-bit (FIPS compliant)"
    else
        test_fail "Certificate does not use FIPS-compliant key size"
    fi
fi

# Test 3: OpenSSL provider verification
echo "[3/4] Testing OpenSSL provider..."
if openssl list -providers | grep -qi "wolfSSL"; then
    PROVIDER=$(openssl list -providers | grep -A 2 -i "wolfSSL" | grep "name:" | awk '{print $2" "$3" "$4}')
    test_pass "wolfSSL Provider active: $PROVIDER"
else
    test_fail "wolfSSL Provider not found"
fi
echo ""

# Test 4: FIPS POST validation
echo "[4/4] Testing FIPS POST..."
if fips-startup-check 2>&1 | grep -q "FIPS 140-3 Validation: PASS"; then
    test_pass "FIPS POST completed successfully"
else
    test_fail "FIPS POST failed"
fi
echo ""

# Cleanup - only kill Nginx if we started it
if [ "$NGINX_STARTED_BY_US" = true ]; then
    kill $NGINX_PID 2>/dev/null || true
fi

# Summary
echo "================================================================================"
echo "Certificate Validation Test Summary"
echo "================================================================================"
echo "Tests Passed: $PASSED/4"
echo "Tests Failed: $FAILED/4"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ ALL CERTIFICATE VALIDATION TESTS PASSED${NC}"
    exit 0
else
    echo -e "${RED}✗ SOME CERTIFICATE VALIDATION TESTS FAILED${NC}"
    exit 1
fi
