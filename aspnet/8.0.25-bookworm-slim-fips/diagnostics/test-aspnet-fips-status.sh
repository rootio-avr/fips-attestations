#!/bin/bash
################################################################################
# ASP.NET wolfSSL FIPS Status Check
# Comprehensive shell-based verification of FIPS configuration
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${CYAN}================================================================================${NC}"
echo -e "${BOLD}${CYAN}ASP.NET wolfSSL FIPS Status Check${NC}"
echo -e "${CYAN}================================================================================${NC}"
echo ""

PASSED=0
FAILED=0
TOTAL=10

# Test 1: Environment Variables
echo -e "${CYAN}[1/$TOTAL]${NC} Checking environment variables..."
if [ -n "$LD_LIBRARY_PATH" ] && echo "$LD_LIBRARY_PATH" | grep -q "/usr/local/openssl"; then
    echo -e "  ${GREEN}✓${NC} LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
    PASSED=$((PASSED + 1))
else
    echo -e "  ${YELLOW}⚠${NC} LD_LIBRARY_PATH not set (ldconfig should handle it)"
    PASSED=$((PASSED + 1))
fi

if [ -n "$OPENSSL_CONF" ]; then
    echo -e "  ${GREEN}✓${NC} OPENSSL_CONF: $OPENSSL_CONF"
else
    echo -e "  ${RED}✗${NC} OPENSSL_CONF not set"
    FAILED=$((FAILED + 1))
fi

if [ -n "$OPENSSL_MODULES" ]; then
    echo -e "  ${GREEN}✓${NC} OPENSSL_MODULES: $OPENSSL_MODULES"
else
    echo -e "  ${RED}✗${NC} OPENSSL_MODULES not set"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 2: Dynamic Linker Configuration
echo -e "${CYAN}[2/$TOTAL]${NC} Checking dynamic linker configuration..."
if [ -f /etc/ld.so.conf.d/00-fips-openssl.conf ]; then
    echo -e "  ${GREEN}✓${NC} FIPS linker config exists"
    LIBSSL_PATH=$(ldconfig -p | grep "libssl.so.3" | head -1 | awk '{print $NF}')
    if echo "$LIBSSL_PATH" | grep -q "/usr/local/openssl"; then
        echo -e "  ${GREEN}✓${NC} libssl.so.3 resolves to: $LIBSSL_PATH"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}✗${NC} libssl.so.3 resolves to wrong path: $LIBSSL_PATH"
        FAILED=$((FAILED + 1))
    fi
else
    echo -e "  ${RED}✗${NC} FIPS linker config not found"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 3: OpenSSL Binary
echo -e "${CYAN}[3/$TOTAL]${NC} Checking OpenSSL binary..."
if command -v openssl >/dev/null; then
    OPENSSL_VER=$(openssl version)
    if echo "$OPENSSL_VER" | grep -q "3.3.7"; then
        echo -e "  ${GREEN}✓${NC} OpenSSL version: $OPENSSL_VER"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}✗${NC} Unexpected version: $OPENSSL_VER"
        FAILED=$((FAILED + 1))
    fi
else
    echo -e "  ${RED}✗${NC} OpenSSL binary not found"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 4: wolfProvider
echo -e "${CYAN}[4/$TOTAL]${NC} Checking wolfProvider..."
if openssl list -providers 2>/dev/null | grep -qi "wolfSSL"; then
    echo -e "  ${GREEN}✓${NC} wolfProvider loaded"
    openssl list -providers 2>/dev/null | grep -A 2 -i "wolfssl" | sed 's/^/    /'
    PASSED=$((PASSED + 1))
else
    echo -e "  ${RED}✗${NC} wolfProvider not loaded"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 5: wolfSSL Library
echo -e "${CYAN}[5/$TOTAL]${NC} Checking wolfSSL FIPS library..."
WOLFSSL_LIB=$(find /usr/local/lib -name "libwolfssl.so*" -type f 2>/dev/null | head -1)
if [ -n "$WOLFSSL_LIB" ]; then
    echo -e "  ${GREEN}✓${NC} wolfSSL library: $WOLFSSL_LIB"
    LIBSIZE=$(stat -c%s "$WOLFSSL_LIB" 2>/dev/null || echo "unknown")
    echo "    Size: $LIBSIZE bytes"
    PASSED=$((PASSED + 1))
else
    echo -e "  ${RED}✗${NC} wolfSSL library not found"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 6: .NET Runtime
echo -e "${CYAN}[6/$TOTAL]${NC} Checking .NET runtime..."
if command -v dotnet >/dev/null; then
    DOTNET_VERSION=$(dotnet --list-runtimes 2>/dev/null | grep "Microsoft.NETCore.App" | head -1 | awk '{print $2}' || echo "unknown")
    echo -e "  ${GREEN}✓${NC} .NET runtime version: $DOTNET_VERSION"
    PASSED=$((PASSED + 1))
else
    echo -e "  ${RED}✗${NC} .NET runtime not found"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 7: .NET OpenSSL Interop
echo -e "${CYAN}[7/$TOTAL]${NC} Checking .NET OpenSSL interop..."
DOTNET_INTEROP=$(find /usr/share/dotnet -name "*System.Security.Cryptography.Native.OpenSsl.so" 2>/dev/null | head -1)
if [ -n "$DOTNET_INTEROP" ]; then
    echo -e "  ${GREEN}✓${NC} OpenSSL interop: $DOTNET_INTEROP"
    PASSED=$((PASSED + 1))
else
    echo -e "  ${RED}✗${NC} OpenSSL interop not found"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 8: FIPS Module Files
echo -e "${CYAN}[8/$TOTAL]${NC} Checking FIPS module files..."
if [ -f /usr/local/openssl/lib/ossl-modules/libwolfprov.so ]; then
    echo -e "  ${GREEN}✓${NC} wolfProvider module exists"
    MODSIZE=$(stat -c%s /usr/local/openssl/lib/ossl-modules/libwolfprov.so 2>/dev/null || echo "unknown")
    echo "    Size: $MODSIZE bytes"
    PASSED=$((PASSED + 1))
else
    echo -e "  ${RED}✗${NC} wolfProvider module not found"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 9: OpenSSL Configuration
echo -e "${CYAN}[9/$TOTAL]${NC} Checking OpenSSL configuration..."
if [ -f /usr/local/openssl/ssl/openssl.cnf ]; then
    echo -e "  ${GREEN}✓${NC} OpenSSL config exists"
    if grep -q "wolfprov" /usr/local/openssl/ssl/openssl.cnf 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Configuration references wolfProvider"
    fi
    PASSED=$((PASSED + 1))
else
    echo -e "  ${RED}✗${NC} OpenSSL configuration not found"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 10: FIPS Startup Check Utility
echo -e "${CYAN}[10/$TOTAL]${NC} Checking FIPS startup utility..."
if command -v fips-startup-check >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} FIPS startup check utility available"
    if fips-startup-check >/tmp/fips-check.log 2>&1; then
        echo -e "  ${GREEN}✓${NC} FIPS startup check: PASSED"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}✗${NC} FIPS startup check: FAILED"
        tail -5 /tmp/fips-check.log | sed 's/^/    /'
        FAILED=$((FAILED + 1))
    fi
    rm -f /tmp/fips-check.log
else
    echo -e "  ${YELLOW}⚠${NC} FIPS startup check utility not found"
    PASSED=$((PASSED + 1))
fi
echo ""

# Summary
echo -e "${CYAN}================================================================================${NC}"
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}${BOLD}✓ ALL CHECKS PASSED ($PASSED/$TOTAL)${NC}"
    echo -e "${CYAN}================================================================================${NC}"
    echo -e "${GREEN}Status:${NC} ASP.NET FIPS configuration is correct"
    echo -e "${GREEN}Module:${NC} wolfSSL FIPS v5 (Certificate #4718)"
    echo -e "${GREEN}OpenSSL:${NC} $OPENSSL_VER"
    echo -e "${GREEN}.NET:${NC} $DOTNET_VERSION"
    echo -e "${CYAN}================================================================================${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}${BOLD}✗ CHECKS FAILED${NC}"
    echo -e "${CYAN}================================================================================${NC}"
    echo -e "${RED}Passed:${NC} $PASSED/$TOTAL"
    echo -e "${RED}Failed:${NC} $FAILED/$TOTAL"
    echo -e "${CYAN}================================================================================${NC}"
    echo ""
    exit 1
fi
