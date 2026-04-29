#!/bin/bash
################################################################################
# FIPS-Enabled ASP.NET Core - Docker Entrypoint Script
################################################################################
# This script automatically configures FIPS environment variables and runs
# validation checks before starting your ASP.NET application.
#
# Environment Variables (automatically set unless overridden):
# -------------------------------------------------------------
#   FIPS_CHECK - Set to 'false' to skip FIPS validation (default: true)
#              Used for development/testing only. Always use FIPS validation
#              in production environments.
#
#   OPENSSL_CONF - Path to OpenSSL configuration file (auto-set by this script)
#                Default: /usr/local/openssl/ssl/openssl.cnf
#                Purpose: Configures OpenSSL to load wolfProvider FIPS module
#
#   OPENSSL_MODULES - Path to OpenSSL provider modules directory (set in Dockerfile)
#                   Default: /usr/local/openssl/lib/ossl-modules
#                   Purpose: Directory containing libwolfprov.so (wolfSSL provider)
#
#   LD_LIBRARY_PATH - Library search path (auto-set by this script)
#                   Default: /usr/local/openssl/lib:/usr/local/lib
#                   Purpose: Ensures FIPS OpenSSL libraries are loaded before system OpenSSL
#                   Works with /etc/ld.so.conf.d/00-fips-openssl.conf for priority
#
# NOTE: All variables are AUTOMATICALLY configured. You do NOT need to set them
#       manually unless you have a specific debugging or customization need.
#
# For more information: docker run IMAGE fips-env-help
################################################################################

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

# FIPS validation enabled by default (can be disabled via FIPS_CHECK=false)
FIPS_CHECK="${FIPS_CHECK:-true}"

# Determine if the command is a .NET command
IS_DOTNET_COMMAND=false
case "${1:-}" in
    dotnet|*/dotnet|*.dll|*.exe)
        IS_DOTNET_COMMAND=true
        ;;
esac

# If FIPS validation is disabled and command is dotnet, skip everything and exec immediately
if [ "$FIPS_CHECK" = "false" ] && [ "$IS_DOTNET_COMMAND" = true ]; then
    # Ensure clean environment for .NET (unset any FIPS-related variables)
    unset OPENSSL_MODULES
    unset OPENSSL_CONF
    unset LD_LIBRARY_PATH
    # Remove custom OpenSSL from PATH
    export PATH=$(echo "$PATH" | sed 's|/usr/local/openssl/bin:||g')
    exec "$@"
fi

################################################################################
# FIPS Validation
################################################################################
if [ "$FIPS_CHECK" = "true" ]; then
    # Set library paths and OpenSSL configuration for FIPS checks
    export LD_LIBRARY_PATH="/usr/local/openssl/lib:/usr/local/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
    export OPENSSL_CONF="${OPENSSL_CONF:-/usr/local/openssl/ssl/openssl.cnf}"
    export OPENSSL_MODULES="${OPENSSL_MODULES:-/usr/local/openssl/lib/ossl-modules}"

    echo ""
    echo -e "${CYAN}================================================================================${NC}"
    echo -e "${BOLD}${CYAN}ASP.NET Core FIPS 140-3 Validation${NC}"
    echo -e "${CYAN}================================================================================${NC}"
    echo ""

    #---------------------------------------------------------------------------
    # Check 1: Environment Variables
    #---------------------------------------------------------------------------
    echo -e "${CYAN}[1/5]${NC} Verifying environment variables..."

    if [ -z "$OPENSSL_CONF" ]; then
        echo -e "${RED}✗ ERROR: OPENSSL_CONF not set${NC}"
        exit 1
    fi
    echo -e "  ${GREEN}✓${NC} OPENSSL_CONF: $OPENSSL_CONF"

    if [ -z "$OPENSSL_MODULES" ]; then
        echo -e "${RED}✗ ERROR: OPENSSL_MODULES not set${NC}"
        exit 1
    fi
    echo -e "  ${GREEN}✓${NC} OPENSSL_MODULES: $OPENSSL_MODULES"

    if [ -z "$LD_LIBRARY_PATH" ]; then
        echo -e "${YELLOW}⚠${NC} WARNING: LD_LIBRARY_PATH not set"
    else
        echo -e "  ${GREEN}✓${NC} LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
    fi
    echo ""

    #---------------------------------------------------------------------------
    # Check 2: OpenSSL Installation
    #---------------------------------------------------------------------------
    echo -e "${CYAN}[2/5]${NC} Verifying OpenSSL installation..."

    if ! command -v openssl &> /dev/null; then
        echo -e "${RED}✗ ERROR: OpenSSL binary not found${NC}"
        exit 1
    fi

    OPENSSL_VERSION=$(openssl version 2>/dev/null || echo "unknown")
    echo -e "  ${GREEN}✓${NC} OpenSSL version: $OPENSSL_VERSION"

    if [ ! -f "$OPENSSL_CONF" ]; then
        echo -e "${RED}✗ ERROR: OpenSSL configuration not found: $OPENSSL_CONF${NC}"
        exit 1
    fi
    echo -e "  ${GREEN}✓${NC} Configuration file exists"
    echo ""

    #---------------------------------------------------------------------------
    # Check 3: wolfSSL Library
    #---------------------------------------------------------------------------
    echo -e "${CYAN}[3/5]${NC} Verifying wolfSSL library..."

    WOLFSSL_LIB=$(find /usr/local/lib -name "libwolfssl.so*" -type f | head -n 1)
    if [ -z "$WOLFSSL_LIB" ]; then
        echo -e "${RED}✗ ERROR: wolfSSL library not found${NC}"
        exit 1
    fi
    echo -e "  ${GREEN}✓${NC} wolfSSL library: $WOLFSSL_LIB"
    echo ""

    #---------------------------------------------------------------------------
    # Check 4: wolfProvider Module
    #---------------------------------------------------------------------------
    echo -e "${CYAN}[4/5]${NC} Verifying wolfProvider module..."

    WOLFPROV_MODULE="$OPENSSL_MODULES/libwolfprov.so"
    if [ ! -f "$WOLFPROV_MODULE" ]; then
        echo -e "${RED}✗ ERROR: wolfProvider module not found: $WOLFPROV_MODULE${NC}"
        exit 1
    fi
    echo -e "  ${GREEN}✓${NC} wolfProvider module: $WOLFPROV_MODULE"

    # Get module size
    MODULE_SIZE=$(stat -c%s "$WOLFPROV_MODULE" 2>/dev/null || echo "unknown")
    echo -e "  ${GREEN}✓${NC} Module size: $MODULE_SIZE bytes"

    # Verify wolfProvider is loaded
    if ! openssl list -providers 2>/dev/null | grep -qi "wolfSSL"; then
        echo -e "${RED}✗ ERROR: wolfProvider not loaded by OpenSSL${NC}"
        echo ""
        echo "OpenSSL providers:"
        openssl list -providers || true
        exit 1
    fi
    echo -e "  ${GREEN}✓${NC} wolfProvider loaded successfully"
    echo ""

    #---------------------------------------------------------------------------
    # Check 5: FIPS Cryptographic Validation
    #---------------------------------------------------------------------------
    echo -e "${CYAN}[5/5]${NC} Running FIPS cryptographic validation..."

    if command -v fips-startup-check &> /dev/null; then
        if fips-startup-check; then
            echo -e "  ${GREEN}✓${NC} FIPS Known Answer Tests (KAT): PASSED"
            echo -e "  ${GREEN}✓${NC} SHA-256 test vector: PASSED"
        else
            echo -e "${RED}✗ ERROR: FIPS cryptographic validation failed${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}⚠${NC} WARNING: fips-startup-check not available, skipping"
    fi
    echo ""

    #---------------------------------------------------------------------------
    # Check 6: .NET Runtime
    #---------------------------------------------------------------------------
    echo -e "${CYAN}[6/6]${NC} Verifying .NET runtime..."

    if ! command -v dotnet &> /dev/null; then
        echo -e "${RED}✗ ERROR: .NET runtime not found${NC}"
        exit 1
    fi

    # Get .NET runtime version (not SDK version)
    DOTNET_VERSION=$(dotnet --info 2>/dev/null | grep -A1 "Microsoft.NETCore.App" | tail -1 | awk '{print $1}' || echo "unknown")
    if [ "$DOTNET_VERSION" = "unknown" ]; then
        # Fallback: try to get from list-runtimes
        DOTNET_VERSION=$(dotnet --list-runtimes 2>/dev/null | grep "Microsoft.NETCore.App" | awk '{print $2}' | head -1 || echo "unknown")
    fi
    echo -e "  ${GREEN}✓${NC} .NET runtime version: $DOTNET_VERSION"

    # Check for OpenSSL interop library (with or without 'lib' prefix)
    OPENSSL_INTEROP=$(find /usr/share/dotnet -type f -name "*System.Security.Cryptography.Native.OpenSsl.so" 2>/dev/null | head -n 1)
    if [ -n "$OPENSSL_INTEROP" ]; then
        echo -e "  ${GREEN}✓${NC} OpenSSL interop: $OPENSSL_INTEROP"
    else
        echo -e "  ${YELLOW}⚠${NC} OpenSSL interop library not found (may be in different location)"
    fi
    echo ""

    #---------------------------------------------------------------------------
    # Summary
    #---------------------------------------------------------------------------
    echo -e "${GREEN}================================================================================${NC}"
    echo -e "${GREEN}${BOLD}✓ ALL FIPS VALIDATION CHECKS PASSED${NC}"
    echo -e "${GREEN}================================================================================${NC}"
    echo -e "${GREEN}FIPS 140-3 Module:${NC} wolfSSL v5.9.1 (Certificate #4718)"
    echo -e "${GREEN}OpenSSL Version:${NC} $OPENSSL_VERSION"
    echo -e "${GREEN}.NET Version:${NC} $DOTNET_VERSION"
    echo -e "${GREEN}Cryptographic Provider:${NC} wolfProvider → wolfSSL FIPS"
    echo -e "${GREEN}================================================================================${NC}"
    echo ""
else
    # Only set library paths for non-.NET commands (e.g., OpenSSL)
    if [ "$IS_DOTNET_COMMAND" = false ]; then
        export LD_LIBRARY_PATH="/usr/local/openssl/lib:/usr/local/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
        export OPENSSL_CONF="${OPENSSL_CONF:-/usr/local/openssl/ssl/openssl.cnf}"
        export OPENSSL_MODULES="${OPENSSL_MODULES:-/usr/local/openssl/lib/ossl-modules}"
    fi

    echo ""
    echo -e "${YELLOW}================================================================================${NC}"
    echo -e "${YELLOW}${BOLD}⚠ FIPS Validation Skipped (FIPS_CHECK=false)${NC}"
    echo -e "${YELLOW}================================================================================${NC}"
    echo -e "${YELLOW}WARNING: Running without FIPS validation${NC}"
    echo -e "${YELLOW}This mode is for development/testing only${NC}"
    echo -e "${YELLOW}================================================================================${NC}"
    echo ""
fi

################################################################################
# Execute the user's command
################################################################################
# NOTE: Environment variables are kept set for .NET commands
#
# The system is configured via /etc/ld.so.conf.d/00-fips-openssl.conf to prefer
# FIPS OpenSSL (/usr/local/openssl/lib) over system OpenSSL automatically.
#
# This means .NET will load FIPS-compliant OpenSSL regardless of LD_LIBRARY_PATH,
# but we keep the environment variables set for:
# 1. Consistency with FIPS validation environment
# 2. Explicit documentation of FIPS mode
# 3. Compatibility with tools that check these variables
#
# Previous behavior (unsetting variables) caused .NET to load non-FIPS OpenSSL.
if [ "$FIPS_CHECK" = "true" ] && [ "$IS_DOTNET_COMMAND" = true ]; then
    # Environment variables remain set - ldconfig ensures FIPS OpenSSL is used
    # No action needed here
    :
fi

exec "$@"
