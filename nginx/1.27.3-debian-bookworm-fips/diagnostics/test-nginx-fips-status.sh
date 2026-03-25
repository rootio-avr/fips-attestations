#!/bin/bash
################################################################################
# Test: Nginx FIPS Status Verification
#
# This test verifies that:
#   1. Nginx is installed and operational
#   2. OpenSSL provider (wolfProvider) is loaded and active
#   3. FIPS mode is enabled
#   4. wolfSSL FIPS POST passes
#
################################################################################

set -euo pipefail

IMAGE_TAG="${IMAGE_TAG:-cr.root.io/nginx:1.27.3-debian-bookworm-fips}"
TEST_NAME="nginx-fips-status"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() {
    echo -e "${GREEN}✓${NC} $1"
}

fail() {
    echo -e "${RED}✗${NC} $1"
    exit 1
}

info() {
    echo -e "  $1"
}

echo "Test: Nginx FIPS Status Verification"
echo "======================================"
echo ""

# Test 1: Nginx version
echo "[1/5] Checking Nginx version..."
NGINX_VERSION=$(docker run --rm --entrypoint="" "$IMAGE_TAG" nginx -v 2>&1)
if echo "$NGINX_VERSION" | grep -q "1.27.3"; then
    pass "Nginx 1.27.3 installed"
    info "$NGINX_VERSION"
else
    fail "Nginx version check failed: $NGINX_VERSION"
fi
echo ""

# Test 2: OpenSSL version
echo "[2/5] Checking OpenSSL version..."
OPENSSL_VERSION=$(docker run --rm --entrypoint="" "$IMAGE_TAG" openssl version)
if echo "$OPENSSL_VERSION" | grep -q "OpenSSL 3"; then
    pass "OpenSSL 3.x installed"
    info "$OPENSSL_VERSION"
else
    fail "OpenSSL version check failed: $OPENSSL_VERSION"
fi
echo ""

# Test 3: wolfProvider loaded
echo "[3/5] Checking OpenSSL providers..."
PROVIDERS=$(docker run --rm --entrypoint="" "$IMAGE_TAG" openssl list -providers)
if echo "$PROVIDERS" | grep -qi "wolfSSL"; then
    pass "wolfProvider loaded and active"
    info "$(echo "$PROVIDERS" | grep -A 3 -i "wolfSSL" | head -4)"
else
    fail "wolfProvider not found in OpenSSL providers"
    info "$PROVIDERS"
fi
echo ""

# Test 4: FIPS mode configuration
echo "[4/5] Checking FIPS mode configuration..."
FIPS_CONFIG=$(docker run --rm --entrypoint="" "$IMAGE_TAG" cat /etc/ssl/fips_properties.cnf 2>/dev/null || echo "")
if echo "$FIPS_CONFIG" | grep -q "fips=yes"; then
    pass "FIPS mode enabled (fips=yes)"
    info "Configuration: /etc/ssl/fips_properties.cnf"
else
    fail "FIPS mode not properly configured"
    info "$FIPS_CONFIG"
fi
echo ""

# Test 5: wolfSSL FIPS POST
echo "[5/5] Running wolfSSL FIPS POST..."
if docker run --rm --entrypoint="" "$IMAGE_TAG" fips-startup-check 2>&1 | grep -q "FIPS 140-3 Validation: PASS"; then
    pass "wolfSSL FIPS POST completed successfully"
else
    fail "wolfSSL FIPS POST failed"
fi
echo ""

echo "======================================"
echo "✅ All FIPS status checks passed"
echo "======================================"
exit 0
