#!/bin/bash
set -e

# Fedora 44 FIPS Container Entrypoint
# Performs FIPS mode verification before starting applications

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo ""
echo "================================================================"
echo "  Fedora 44 with FIPS 140-3 Support"
echo "  Crypto-Policies FIPS Mode + OpenSSL FIPS Provider"
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

# Run FIPS initialization checks
if [ "${SKIP_FIPS_CHECK:-false}" != "true" ]; then
    echo -e "${YELLOW}Running FIPS mode verification...${NC}"
    echo ""

    # Check crypto-policies configuration
    echo -e "${CYAN}Crypto-Policies Status:${NC}"
    CRYPTO_POLICY=$(cat /etc/crypto-policies/config 2>/dev/null || echo "UNKNOWN")
    echo "  Configured Policy: ${CRYPTO_POLICY}"
    if [ "$CRYPTO_POLICY" = "FIPS" ]; then
        echo -e "  ${GREEN}✓ Crypto-policies set to FIPS mode${NC}"
    else
        echo -e "  ${YELLOW}⚠ WARNING: Crypto-policies not set to FIPS (got: $CRYPTO_POLICY)${NC}"
    fi
    echo ""

    # Check FIPS kernel support (may not be available in containers)
    echo -e "${CYAN}FIPS Kernel Support:${NC}"
    if [ -f /proc/sys/crypto/fips_enabled ]; then
        KERNEL_FIPS=$(cat /proc/sys/crypto/fips_enabled 2>/dev/null || echo "0")
        if [ "$KERNEL_FIPS" = "1" ]; then
            echo -e "  ${GREEN}✓ Kernel FIPS mode enabled (/proc/sys/crypto/fips_enabled = 1)${NC}"
        else
            echo -e "  ${YELLOW}⚠ Kernel FIPS mode not enabled (container without kernel FIPS support)${NC}"
            echo -e "  ${CYAN}  Using OPENSSL_FORCE_FIPS_MODE for application-level FIPS${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠ /proc/sys/crypto/fips_enabled not available${NC}"
        echo -e "  ${CYAN}  Using OPENSSL_FORCE_FIPS_MODE for application-level FIPS${NC}"
    fi
    echo ""

    # Check OpenSSL FIPS provider
    echo -e "${CYAN}OpenSSL FIPS Provider:${NC}"
    echo "  OpenSSL Version: $(openssl version)"

    FIPS_PROVIDER=$(openssl list -providers 2>/dev/null | grep -i fips || true)
    if [ -n "$FIPS_PROVIDER" ]; then
        echo -e "  ${GREEN}✓ FIPS provider loaded:${NC}"
        echo "$FIPS_PROVIDER" | sed 's/^/    /'
    else
        echo -e "  ${RED}✗ FIPS provider not loaded${NC}"
    fi
    echo ""

    # Run comprehensive FIPS checks (can be skipped)
    if [ "${SKIP_DETAILED_CHECKS:-false}" != "true" ]; then
        echo -e "${YELLOW}Running detailed FIPS verification tests...${NC}"
        echo ""

        # Run shell-based FIPS check
        if /opt/fips/bin/fips_init_check.sh; then
            echo ""
        else
            echo -e "${RED}✗ FIPS verification failed${NC}"
            exit 1
        fi
    fi

    echo -e "${GREEN}✓ FIPS mode verification complete${NC}"
    echo ""
fi

# Display environment information
echo -e "${CYAN}Environment Information:${NC}"
echo "  Fedora Version: $(cat /etc/fedora-release 2>/dev/null || echo 'Unknown')"
echo "  OpenSSL: $(openssl version)"
echo "  User: $(whoami)"
echo "  Working Directory: $(pwd)"
echo ""
echo "  Environment Variables:"
echo "    OPENSSL_FORCE_FIPS_MODE: ${OPENSSL_FORCE_FIPS_MODE:-not set}"
echo "    OPENSSL_CONF: ${OPENSSL_CONF:-not set}"
echo ""

# Display available verification tools
echo -e "${CYAN}FIPS Verification Tools:${NC}"
echo "  Run FIPS check: /opt/fips/bin/fips_init_check.sh"
echo "  Integrity check: /usr/local/bin/integrity-check.sh"
echo "  Enable FIPS: /usr/local/bin/enable-fips.sh"
echo ""

# Execute the main command
exec "$@"
