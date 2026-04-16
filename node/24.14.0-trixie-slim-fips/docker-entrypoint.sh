#!/bin/bash
set -e

# Node.js wolfSSL FIPS Container Entrypoint
# Performs integrity checks and FIPS validation before starting Node.js

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo ""
echo "================================================================"
echo "  Node.js 24 with wolfSSL FIPS 140-3"
echo "  Certificate #4718 (wolfSSL 5.8.2)"
echo "  Debian Trixie Base"
echo "================================================================"
echo ""

# Run integrity check if enabled
if [ "${SKIP_INTEGRITY_CHECK:-false}" != "true" ]; then
    echo -e "${YELLOW}Running integrity verification...${NC}"
    if /usr/local/bin/integrity-check.sh; then
        echo -e "${GREEN}✓ Integrity check passed${NC}"
    else
        echo -e "${RED}✗ Integrity check failed${NC}"
        exit 1
    fi
    echo ""
fi

# Run FIPS initialization check
if [ "${SKIP_FIPS_CHECK:-false}" != "true" ]; then
    echo -e "${YELLOW}Running FIPS initialization check...${NC}"
    if node /opt/wolfssl-fips/bin/fips_init_check.js; then
        echo -e "${GREEN}✓ FIPS initialization successful${NC}"
    else
        echo -e "${RED}✗ FIPS initialization failed${NC}"
        exit 1
    fi
    echo ""
fi

# Display Node.js and OpenSSL information
echo -e "${CYAN}Environment Information:${NC}"
echo "  Node.js: $(node --version)"
echo "  npm: $(npm --version)"
echo "  OpenSSL: $(openssl version)"
echo "  OpenSSL Config: ${OPENSSL_CONF}"
echo "  OpenSSL Modules: ${OPENSSL_MODULES}"
echo ""

# Verify Node.js is using custom FIPS OpenSSL 3.5.0
echo -e "${CYAN}OpenSSL Linkage Verification:${NC}"
echo -e "${YELLOW}Checking Node.js OpenSSL linkage...${NC}"
NODE_SSL_LIBS=$(ldd $(which node) 2>/dev/null | grep -E 'libssl|libcrypto' || true)
if [ -n "$NODE_SSL_LIBS" ]; then
    echo "$NODE_SSL_LIBS"
    OPENSSL_VER=$(openssl version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if [[ "$OPENSSL_VER" == "3.5.0" ]]; then
        echo -e "${GREEN}✓ Node.js is using custom FIPS OpenSSL 3.5.0${NC}"
    else
        echo -e "${RED}✗ WARNING: OpenSSL version mismatch (expected 3.5.0, got ${OPENSSL_VER})${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Node.js OpenSSL linkage not visible in ldd${NC}"
    echo -e "${YELLOW}  This is expected if Node.js uses dlopen() for OpenSSL${NC}"
    OPENSSL_VER=$(openssl version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if [[ "$OPENSSL_VER" == "3.5.0" ]]; then
        echo -e "${GREEN}✓ System OpenSSL 3.5.0 is available${NC}"
    fi
fi
echo ""

# Execute the main command
exec "$@"
