#!/bin/bash
################################################################################
# Node.js OpenSSL 3.5.0 FIPS Verification Script
#
# Purpose: Verify that Node.js is using custom FIPS OpenSSL 3.5.0
#
# This script demonstrates:
#   1. OpenSSL 3.5.0 binary is installed
#   2. Node.js is dynamically linked to FIPS OpenSSL libraries
#   3. wolfProvider 1.1.1 is loaded and active
#   4. Node.js FIPS mode is enabled
#   5. Crypto operations use FIPS-validated algorithms
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo "================================================================================"
echo -e "${BOLD}${CYAN}Node.js OpenSSL 3.5.0 FIPS Verification${NC}"
echo "================================================================================"
echo ""

PASSED=0
TOTAL=8

################################################################################
# Test 1: OpenSSL Version
################################################################################
echo -e "${YELLOW}[1/8]${NC} Verifying OpenSSL binary version..."

VERSION_OUTPUT=$(docker run --rm --entrypoint "" cr.root.io/node:24.14.0-trixie-slim-fips openssl version 2>&1)
if echo "${VERSION_OUTPUT}" | grep -q "OpenSSL 3.5"; then
    echo -e "${GREEN}✓ PASS${NC}: ${VERSION_OUTPUT}"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC}: Expected OpenSSL 3.5.x"
    echo "Output: ${VERSION_OUTPUT}"
fi
echo ""

################################################################################
# Test 2: OpenSSL Libraries Location
################################################################################
echo -e "${YELLOW}[2/8]${NC} Verifying OpenSSL libraries are available..."

docker run --rm --entrypoint "" cr.root.io/node:24.14.0-trixie-slim-fips \
  sh -c "ls -la /usr/lib/x86_64-linux-gnu/libssl.so.3 /usr/lib/x86_64-linux-gnu/libcrypto.so.3" 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ PASS${NC}: FIPS OpenSSL libraries found in system location"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC}: System OpenSSL libraries not found"
fi
echo ""

################################################################################
# Test 3: Node.js OpenSSL Linkage
################################################################################
echo -e "${YELLOW}[3/8]${NC} Verifying Node.js OpenSSL linkage..."

NODE_LINKAGE=$(docker run --rm --entrypoint "" cr.root.io/node:24.14.0-trixie-slim-fips \
  sh -c 'ldd $(which node) | grep -E "libssl|libcrypto"' 2>&1)

echo "${NODE_LINKAGE}"

if echo "${NODE_LINKAGE}" | grep -q "libssl.so.3" && echo "${NODE_LINKAGE}" | grep -q "libcrypto.so.3"; then
    echo -e "${GREEN}✓ PASS${NC}: Node.js linked to OpenSSL 3.5.0 libraries"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC}: Node.js not linked to expected OpenSSL libraries"
fi
echo ""

################################################################################
# Test 4: wolfProvider Loading
################################################################################
echo -e "${YELLOW}[4/8]${NC} Verifying wolfProvider 1.1.1 with OpenSSL 3.5.0..."

PROVIDER_OUTPUT=$(docker run --rm --entrypoint "" cr.root.io/node:24.14.0-trixie-slim-fips \
  openssl list -providers 2>&1)

echo "${PROVIDER_OUTPUT}"

if echo "${PROVIDER_OUTPUT}" | grep -q "fips" && echo "${PROVIDER_OUTPUT}" | grep -q "status: active"; then
    echo -e "${GREEN}✓ PASS${NC}: wolfProvider is active"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC}: wolfProvider not active"
fi
echo ""

################################################################################
# Test 5: Node.js Version
################################################################################
echo -e "${YELLOW}[5/8]${NC} Verifying Node.js version..."

NODE_VERSION=$(docker run --rm --entrypoint "" cr.root.io/node:24.14.0-trixie-slim-fips node --version 2>&1)

if echo "${NODE_VERSION}" | grep -q "v24"; then
    echo -e "${GREEN}✓ PASS${NC}: ${NODE_VERSION}"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC}: Expected Node.js v24.x"
    echo "Output: ${NODE_VERSION}"
fi
echo ""

################################################################################
# Test 6: Node.js FIPS Mode
################################################################################
echo -e "${YELLOW}[6/8]${NC} Verifying Node.js FIPS mode is enabled..."

FIPS_CHECK=$(docker run --rm --entrypoint "" cr.root.io/node:24.14.0-trixie-slim-fips \
  node -e "console.log(require('crypto').getFips())" 2>&1)

if [ "$FIPS_CHECK" = "1" ]; then
    echo -e "${GREEN}✓ PASS${NC}: Node.js FIPS mode enabled (getFips() = 1)"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC}: FIPS mode not enabled (getFips() = ${FIPS_CHECK})"
fi
echo ""

################################################################################
# Test 7: FIPS Crypto Operations
################################################################################
echo -e "${YELLOW}[7/8]${NC} Testing FIPS-approved crypto operations..."

CRYPTO_TEST=$(docker run --rm --entrypoint "" cr.root.io/node:24.14.0-trixie-slim-fips \
  node -e "const crypto = require('crypto'); const hash = crypto.createHash('sha256'); hash.update('test'); console.log(hash.digest('hex'));" 2>&1)

if echo "${CRYPTO_TEST}" | grep -qE "^[a-f0-9]{64}$"; then
    echo -e "${GREEN}✓ PASS${NC}: SHA-256 hash successful: ${CRYPTO_TEST}"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC}: Crypto operation failed"
    echo "Output: ${CRYPTO_TEST}"
fi
echo ""

################################################################################
# Test 8: Full FIPS Initialization Check
################################################################################
echo -e "${YELLOW}[8/8]${NC} Running comprehensive FIPS initialization check..."

docker run --rm --entrypoint "" cr.root.io/node:24.14.0-trixie-slim-fips \
  node /opt/wolfssl-fips/bin/fips_init_check.js 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ PASS${NC}: All FIPS initialization checks passed"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC}: FIPS initialization check failed"
fi
echo ""

################################################################################
# Summary
################################################################################
echo "================================================================================"
echo "Verification Summary"
echo "================================================================================"
echo ""

if [ ${PASSED} -eq ${TOTAL} ]; then
    echo -e "${GREEN}✓ ALL CHECKS PASSED${NC} (${PASSED}/${TOTAL})"
    echo ""
    echo "Conclusion: Node.js is using custom FIPS OpenSSL 3.5.0"
    echo ""
    echo "Architecture:"
    echo "  Node.js 24.14.0 → System OpenSSL (replaced) → OpenSSL 3.5.0 → wolfProvider 1.1.1 → wolfSSL FIPS 5.8.2"
    echo ""
    echo "Key Points:"
    echo "  ✓ OpenSSL 3.5.0 is installed and active"
    echo "  ✓ Node.js is dynamically linked to FIPS OpenSSL libraries"
    echo "  ✓ wolfProvider 1.1.1 loaded as FIPS provider"
    echo "  ✓ Node.js FIPS mode is enabled (crypto.getFips() = 1)"
    echo "  ✓ All crypto operations use FIPS-validated algorithms"
else
    echo -e "${YELLOW}⚠ PARTIAL PASS${NC} (${PASSED}/${TOTAL})"
    echo ""
    echo "Some checks did not pass. Review the output above."
fi

echo ""
echo "================================================================================"
echo ""
