#!/bin/bash
set -e

# Node.js wolfSSL FIPS Container Entrypoint
# Performs integrity checks and FIPS validation before starting Node.js

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo ""
echo "================================================================"
echo "  Node.js 18 with wolfSSL FIPS 140-3"
echo "  Certificate #4718 (wolfSSL 5.8.2)"
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
echo "Environment Information:"
echo "  Node.js: $(node --version)"
echo "  npm: $(npm --version)"
echo "  OpenSSL Config: ${OPENSSL_CONF}"
echo ""

# Execute the main command
exec "$@"
