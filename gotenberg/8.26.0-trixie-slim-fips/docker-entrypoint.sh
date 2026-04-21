#!/bin/bash
################################################################################
# Gotenberg FIPS - Docker Entrypoint Script
#
# Purpose: Validate FIPS configuration on container startup
#
# Checks performed:
#   1. CGO_ENABLED=1 environment variable
#   2. OpenSSL provider loading (wolfProvider)
#   3. FIPS mode enforcement (GODEBUG=fips140=only)
#   4. Library availability (OpenSSL, wolfSSL, wolfProvider)
#
# Environment variables:
#   SKIP_FIPS_CHECK - Set to 'true' to skip FIPS validation (debugging only)
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo "================================================================================"
echo -e "${BOLD}${CYAN}Gotenberg FIPS - Container Startup${NC}"
echo "================================================================================"
echo ""

# Skip FIPS checks if requested (for debugging only)
if [ "${SKIP_FIPS_CHECK}" = "true" ]; then
    echo -e "${YELLOW}⚠ SKIP_FIPS_CHECK=true: Skipping FIPS validation checks${NC}"
    echo ""
    exec "$@"
    exit 0
fi

################################################################################
# Check 1: CGO_ENABLED
################################################################################
echo -e "${CYAN}[1/5] Checking CGO configuration...${NC}"

if [ "${CGO_ENABLED}" != "1" ]; then
    echo -e "${RED}✗ ERROR: CGO_ENABLED is not set to 1${NC}"
    echo "  Current value: ${CGO_ENABLED:-<not set>}"
    echo "  golang-fips/go requires CGO_ENABLED=1 to interface with OpenSSL"
    exit 1
fi

echo -e "${GREEN}✓${NC} CGO_ENABLED=1"
echo ""

################################################################################
# Check 2: FIPS Environment Variables
################################################################################
echo -e "${CYAN}[2/5] Checking FIPS environment variables...${NC}"

# Check GOLANG_FIPS
if [ "${GOLANG_FIPS}" != "1" ]; then
    echo -e "${RED}✗ ERROR: GOLANG_FIPS is not set to '1'${NC}"
    echo "  Current value: ${GOLANG_FIPS:-<not set>}"
    echo "  golang-fips/go requires GOLANG_FIPS=1 for OpenSSL-backed FIPS mode"
    exit 1
fi
echo -e "${GREEN}✓${NC} GOLANG_FIPS=1 (OpenSSL-backed FIPS mode)"

# Check GODEBUG is NOT set (mutually exclusive with GOLANG_FIPS in v1.26.2+)
if [ -n "${GODEBUG}" ]; then
    echo -e "${YELLOW}⚠ WARNING: GODEBUG is set to '${GODEBUG}'${NC}"
    echo "  Note: golang-fips/go v1.26.2+ requires GOLANG_FIPS=1 alone"
    echo "  GODEBUG=fips140 is mutually exclusive with GOLANG_FIPS=1"
else
    echo -e "${GREEN}✓${NC} GODEBUG not set (correct for OpenSSL-backed FIPS)"
fi

# Check GOEXPERIMENT (optional, not required for v1.26.2)
if [ -n "${GOEXPERIMENT}" ]; then
    echo -e "${YELLOW}⚠ NOTE: GOEXPERIMENT is set to '${GOEXPERIMENT}'${NC}"
    echo "  This is not required for OpenSSL-backed FIPS mode"
else
    echo -e "${GREEN}✓${NC} GOEXPERIMENT not set (optional for OpenSSL-backed FIPS)"
fi

echo ""

################################################################################
# Check 3: OpenSSL Configuration
################################################################################
echo -e "${CYAN}[3/5] Checking OpenSSL configuration...${NC}"

# Check OPENSSL_CONF
if [ ! -f "${OPENSSL_CONF}" ]; then
    echo -e "${RED}✗ ERROR: OpenSSL configuration file not found: ${OPENSSL_CONF}${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} OpenSSL configuration file exists: ${OPENSSL_CONF}"

# Verify OpenSSL version
if ! openssl version >/dev/null 2>&1; then
    echo -e "${RED}✗ ERROR: OpenSSL command not found or failed to execute${NC}"
    exit 1
fi

OPENSSL_VERSION=$(openssl version 2>/dev/null)
echo -e "${GREEN}✓${NC} OpenSSL version: ${OPENSSL_VERSION}"

echo ""

################################################################################
# Check 4: wolfProvider Loading
################################################################################
echo -e "${CYAN}[4/5] Checking wolfProvider loading...${NC}"

# Check if wolfProvider library exists
WOLFPROV_PATH="/usr/local/openssl/lib64/ossl-modules/libwolfprov.so"
if [ ! -f "${WOLFPROV_PATH}" ]; then
    echo -e "${RED}✗ ERROR: wolfProvider library not found: ${WOLFPROV_PATH}${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} wolfProvider library exists: ${WOLFPROV_PATH}"

# Test OpenSSL provider loading
# CRITICAL: Provider is named "fips" for golang-fips/go compatibility
if openssl list -providers 2>&1 | grep -qE "fips|wolfSSL Provider FIPS"; then
    echo -e "${GREEN}✓${NC} FIPS provider (wolfProvider) is loaded and active"
else
    echo -e "${RED}✗ ERROR: FIPS provider is not loaded${NC}"
    echo "  Run 'openssl list -providers' to see available providers"
    exit 1
fi

echo ""

################################################################################
# Check 5: Library Dependencies
################################################################################
echo -e "${CYAN}[5/5] Checking library dependencies...${NC}"

# Check wolfSSL library
if [ -f "/usr/local/lib/libwolfssl.so" ] || [ -f "/usr/local/lib/libwolfssl.so.42" ]; then
    echo -e "${GREEN}✓${NC} wolfSSL library found"
else
    echo -e "${YELLOW}⚠ WARNING: wolfSSL library not found in /usr/local/lib${NC}"
fi

# Check OpenSSL libraries in system location
if [ -f "/usr/lib/x86_64-linux-gnu/libssl.so.3" ]; then
    echo -e "${GREEN}✓${NC} System OpenSSL library (libssl.so.3) found"
else
    echo -e "${YELLOW}⚠ WARNING: System OpenSSL library not found${NC}"
fi

if [ -f "/usr/lib/x86_64-linux-gnu/libcrypto.so.3" ]; then
    echo -e "${GREEN}✓${NC} System OpenSSL library (libcrypto.so.3) found"
else
    echo -e "${YELLOW}⚠ WARNING: System OpenSSL library not found${NC}"
fi

echo ""

################################################################################
# FIPS Validation Complete
################################################################################
echo "================================================================================"
echo -e "${GREEN}✓ FIPS validation checks passed${NC}"
echo "================================================================================"
echo ""
echo "Starting Gotenberg service..."
echo ""

# Execute the command passed to the entrypoint
exec "$@"
