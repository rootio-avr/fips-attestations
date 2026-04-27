#!/bin/bash
################################################################################
# FIPS Verification Demo
#
# Purpose: Demonstrate runtime FIPS provider verification
#
# Requirements: None (standalone demo)
#
# Output: FIPS configuration and provider status
################################################################################

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "================================================================================"
echo "Gotenberg FIPS Verification Demo"
echo "================================================================================"
echo ""

PASSED=0
TOTAL=5

################################################################################
# Test 1: OpenSSL Version
################################################################################
echo -e "${YELLOW}[1/5]${NC} Checking OpenSSL version..."

VERSION_OUTPUT=$(openssl version 2>&1)
if echo "${VERSION_OUTPUT}" | grep -q "OpenSSL 3.5"; then
    echo -e "${GREEN}✓ PASS${NC}: ${VERSION_OUTPUT}"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC}: Expected OpenSSL 3.5.x"
    echo "Output: ${VERSION_OUTPUT}"
fi
echo ""

################################################################################
# Test 2: FIPS Provider
################################################################################
echo -e "${YELLOW}[2/5]${NC} Checking FIPS provider..."

PROVIDER_OUTPUT=$(openssl list -providers 2>&1)
# Check if both "fips" provider and "status: active" are present
if echo "${PROVIDER_OUTPUT}" | grep -q "fips" && echo "${PROVIDER_OUTPUT}" | grep -q "status: active"; then
    echo -e "${GREEN}✓ PASS${NC}: wolfSSL FIPS provider is active"
    echo "${PROVIDER_OUTPUT}"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC}: FIPS provider not active"
    echo "Output: ${PROVIDER_OUTPUT}"
fi
echo ""

################################################################################
# Test 3: FIPS Mode Configuration
################################################################################
echo -e "${YELLOW}[3/5]${NC} Verifying FIPS mode configuration..."

if grep -q "fips=yes" /etc/ssl/openssl.cnf 2>/dev/null; then
    echo -e "${GREEN}✓ PASS${NC}: FIPS mode enabled (default_properties = fips=yes)"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC}: FIPS mode not configured"
fi
echo ""

################################################################################
# Test 4: FIPS Algorithms Available
################################################################################
echo -e "${YELLOW}[4/5]${NC} Testing FIPS-approved algorithms..."

# Test SHA-256
SHA256_TEST=$(echo "test" | openssl dgst -sha256 2>&1)
if echo "${SHA256_TEST}" | grep -qE "[a-f0-9]{64}"; then
    echo -e "${GREEN}✓ PASS${NC}: SHA-256 is available"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC}: SHA-256 test failed"
fi

# Test AES-GCM cipher availability
AES_GCM_TEST=$(openssl ciphers -v 'AES256-GCM-SHA384' 2>&1)
if echo "${AES_GCM_TEST}" | grep -qE "AES256-GCM|TLSv1"; then
    echo -e "${GREEN}✓ INFO${NC}: AES-256-GCM cipher is available"
else
    echo -e "${YELLOW}⚠ WARN${NC}: AES-256-GCM cipher not listed"
fi
echo ""

################################################################################
# Test 5: Non-FIPS Algorithm Blocking
################################################################################
echo -e "${YELLOW}[5/5]${NC} Testing non-FIPS algorithm rejection..."

# Test MD5 (should be blocked in FIPS mode)
MD5_TEST=$(echo "test" | openssl dgst -md5 2>&1 || true)
if echo "${MD5_TEST}" | grep -qE "disabled for FIPS|not supported|unsupported"; then
    echo -e "${GREEN}✓ PASS${NC}: MD5 is correctly blocked in FIPS mode"
    PASSED=$((PASSED + 1))
else
    echo -e "${YELLOW}⚠ WARN${NC}: MD5 may not be blocked (output: ${MD5_TEST})"
fi
echo ""

################################################################################
# Summary
################################################################################
echo "================================================================================"
echo "FIPS Verification Summary"
echo "================================================================================"
echo ""

if [ ${PASSED} -eq ${TOTAL} ]; then
    echo -e "${GREEN}✓ ALL CHECKS PASSED${NC} (${PASSED}/${TOTAL})"
    echo ""
    echo "Your Gotenberg FIPS installation is correctly configured:"
    echo "  - OpenSSL 3.5.0 with wolfSSL FIPS provider"
    echo "  - FIPS mode enforced (fips=yes)"
    echo "  - FIPS-approved algorithms available"
    echo "  - Non-FIPS algorithms blocked"
else
    echo -e "${YELLOW}⚠ PARTIAL PASS${NC} (${PASSED}/${TOTAL})"
    echo ""
    echo "Some checks did not pass. Review the output above."
fi

echo ""
echo "================================================================================"
echo "Additional Information"
echo "================================================================================"
echo ""

echo "OpenSSL Configuration:"
echo "  OPENSSLDIR: $(openssl version -d | cut -d'"' -f2)"
echo "  MODULESDIR: $(openssl version -a 2>&1 | grep MODULESDIR | cut -d'"' -f2)"
echo ""

echo "Environment Variables:"
echo "  CGO_ENABLED: ${CGO_ENABLED:-not set}"
echo "  GOLANG_FIPS: ${GOLANG_FIPS:-not set}"
echo "  GODEBUG: ${GODEBUG:-not set}"
echo ""

echo "FIPS Libraries:"
if [ -f "/usr/local/lib/libwolfssl.so.44" ]; then
    echo -e "  ${GREEN}✓${NC} /usr/local/lib/libwolfssl.so.44"
else
    echo -e "  ${RED}✗${NC} /usr/local/lib/libwolfssl.so.44 not found"
fi

if [ -f "/usr/local/openssl/lib64/ossl-modules/libwolfprov.so" ]; then
    echo -e "  ${GREEN}✓${NC} /usr/local/openssl/lib64/ossl-modules/libwolfprov.so"
else
    echo -e "  ${RED}✗${NC} /usr/local/openssl/lib64/ossl-modules/libwolfprov.so not found"
fi

echo ""
echo "================================================================================"
