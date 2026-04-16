#!/bin/bash
#
# OpenSSL FIPS Provider Test
# Tests OpenSSL provider configuration and status
#

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "================================================================"
echo "  OpenSSL FIPS Provider Test"
echo "  Fedora 44 - Provider Configuration & Status"
echo "================================================================"
echo ""

# Test 1: Check OpenSSL version
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}OpenSSL Version${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
openssl version
openssl version -a | head -10
echo ""

# Test 2: List all providers
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Loaded Providers${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
openssl list -providers -verbose
echo ""

# Test 3: Check FIPS provider specifically
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}FIPS Provider Status${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if openssl list -providers | grep -qi "fips"; then
    echo -e "${GREEN}✓ FIPS provider is loaded${NC}"
    echo ""
    echo "FIPS Provider Details:"
    openssl list -providers | grep -A 2 -i "fips"
else
    echo -e "${RED}✗ FIPS provider is NOT loaded${NC}"
    exit 1
fi

echo ""

# Test 4: List available algorithms
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Available Digest Algorithms${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
openssl list -digest-algorithms | head -20
echo ""

# Test 5: Check crypto-policies
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Crypto-Policies Configuration${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

CRYPTO_POLICY=$(cat /etc/crypto-policies/config 2>/dev/null || echo "NOT FOUND")
echo "Current Policy: $CRYPTO_POLICY"

if [ "$CRYPTO_POLICY" = "FIPS" ]; then
    echo -e "${GREEN}✓ Crypto-policies set to FIPS mode${NC}"
else
    echo -e "${YELLOW}⚠ Crypto-policies not set to FIPS mode${NC}"
fi

echo ""

# Test 6: Check environment variables
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}FIPS Environment Variables${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "OPENSSL_FORCE_FIPS_MODE: ${OPENSSL_FORCE_FIPS_MODE:-not set}"
echo "OPENSSL_CONF: ${OPENSSL_CONF:-not set}"
echo ""

# Summary
echo "================================================================"
echo "                      Summary"
echo "================================================================"
echo ""
echo -e "${GREEN}✓ OpenSSL provider test complete${NC}"
echo ""
echo "Provider Configuration:"
echo "  - FIPS provider: Loaded"
echo "  - Crypto-policies: $CRYPTO_POLICY"
echo "  - OPENSSL_FORCE_FIPS_MODE: ${OPENSSL_FORCE_FIPS_MODE:-not set}"
echo ""

exit 0
