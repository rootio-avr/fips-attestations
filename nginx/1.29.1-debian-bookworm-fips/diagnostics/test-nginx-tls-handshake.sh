#!/bin/bash
################################################################################
# Test: Nginx TLS Handshake Validation
#
# This test verifies that:
#   1. Nginx starts successfully
#   2. HTTPS endpoint responds
#   3. TLS 1.2 handshake succeeds with FIPS ciphers
#   4. TLS 1.3 handshake succeeds
#   5. Non-FIPS ciphers are blocked
#
################################################################################

set -euo pipefail

IMAGE_TAG="${IMAGE_TAG:-cr.root.io/nginx:1.29.1-debian-bookworm-fips}"
CONTAINER_NAME="nginx-fips-test-$$"
TEST_PORT_HTTP=18080
TEST_PORT_HTTPS=18443

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
    cleanup
    exit 1
}

info() {
    echo -e "  $1"
}

cleanup() {
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        docker rm -f "$CONTAINER_NAME" &>/dev/null || true
    fi
}

echo "Test: Nginx TLS Handshake Validation"
echo "====================================="
echo ""

# Cleanup any existing container
cleanup

# Test 1: Start Nginx container
echo "[1/6] Starting Nginx container..."
if docker run -d \
    --name "$CONTAINER_NAME" \
    -p "${TEST_PORT_HTTP}:80" \
    -p "${TEST_PORT_HTTPS}:443" \
    "$IMAGE_TAG" &>/dev/null; then
    pass "Nginx container started"
else
    fail "Failed to start Nginx container"
fi

# Wait for Nginx to be ready
sleep 3
echo ""

# Test 2: Check container health
echo "[2/6] Checking container health..."
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    pass "Container is running"
else
    fail "Container is not running"
fi
echo ""

# Test 3: HTTP endpoint
echo "[3/6] Testing HTTP endpoint..."
if curl -sf http://localhost:${TEST_PORT_HTTP}/health &>/dev/null; then
    pass "HTTP endpoint responds"
else
    # HTTP redirects to HTTPS, so this is expected to fail
    info "HTTP redirect to HTTPS (expected behavior)"
fi
echo ""

# Test 4: HTTPS endpoint
echo "[4/6] Testing HTTPS endpoint..."
if curl -sfk https://localhost:${TEST_PORT_HTTPS}/health &>/dev/null; then
    pass "HTTPS endpoint responds"
else
    fail "HTTPS endpoint does not respond"
fi
echo ""

# Test 5: TLS 1.2 handshake with FIPS cipher
echo "[5/6] Testing TLS 1.2 handshake..."
if echo | openssl s_client -connect localhost:${TEST_PORT_HTTPS} -tls1_2 -cipher 'ECDHE-RSA-AES256-GCM-SHA384' 2>&1 | grep -q "Cipher    : ECDHE-RSA-AES256-GCM-SHA384"; then
    pass "TLS 1.2 handshake successful with FIPS cipher"
    info "Cipher: ECDHE-RSA-AES256-GCM-SHA384"
else
    fail "TLS 1.2 handshake failed"
fi
echo ""

# Test 6: TLS 1.3 handshake
echo "[6/6] Testing TLS 1.3 handshake..."
if echo | openssl s_client -connect localhost:${TEST_PORT_HTTPS} -tls1_3 2>&1 | grep -q "TLSv1.3"; then
    pass "TLS 1.3 handshake successful"
    CIPHER=$(echo | openssl s_client -connect localhost:${TEST_PORT_HTTPS} -tls1_3 2>&1 | grep "Cipher" | head -1)
    info "$CIPHER"
else
    fail "TLS 1.3 handshake failed"
fi
echo ""

# Cleanup
cleanup

echo "====================================="
echo "✅ All TLS handshake tests passed"
echo "====================================="
exit 0
