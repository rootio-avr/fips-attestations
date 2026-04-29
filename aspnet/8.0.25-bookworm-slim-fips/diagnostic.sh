#!/bin/bash
################################################################################
# ASP.NET FIPS Diagnostic Runner
#
# Comprehensive diagnostic script for ASP.NET Core with wolfSSL FIPS compliance
# This script runs all diagnostic test suites and validates FIPS configuration
#
# Usage:
#   ./diagnostic.sh              # Run all tests
#   ./diagnostic.sh --help       # Show help
#   ./diagnostic.sh --status     # Quick status check only
#   ./diagnostic.sh --crypto     # Crypto operations only
#   ./diagnostic.sh --verbose    # Verbose output
#
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIAGNOSTICS_DIR="$SCRIPT_DIR/diagnostics"

# Check if diagnostics directory exists
if [ ! -d "$DIAGNOSTICS_DIR" ]; then
    echo -e "${RED}✗ Error: diagnostics directory not found${NC}"
    echo "  Expected: $DIAGNOSTICS_DIR"
    exit 1
fi

# Change to diagnostics directory
cd "$DIAGNOSTICS_DIR"

# Parse arguments
VERBOSE=false
STATUS_ONLY=false
CRYPTO_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            echo ""
            echo -e "${BOLD}${CYAN}ASP.NET FIPS Diagnostic Suite${NC}"
            echo -e "${CYAN}================================${NC}"
            echo ""
            echo "Comprehensive diagnostic tests for ASP.NET Core FIPS compliance"
            echo ""
            echo "Usage:"
            echo "  ./diagnostic.sh              Run all test suites (65 tests)"
            echo "  ./diagnostic.sh --status     Quick status check only (10 tests)"
            echo "  ./diagnostic.sh --crypto     Crypto operations only (20 tests)"
            echo "  ./diagnostic.sh --verbose    Enable verbose output"
            echo "  ./diagnostic.sh --help       Show this help message"
            echo ""
            echo "Test Suites:"
            echo "  1. FIPS Status Check         (10 tests)"
            echo "  2. Backend Verification      (10 tests)"
            echo "  3. FIPS Module Validation    (10 tests)"
            echo "  4. Crypto Operations         (20 tests)"
            echo "  5. TLS/HTTPS Connectivity    (15 tests)"
            echo ""
            echo "Total: 65 comprehensive FIPS compliance tests"
            echo ""
            echo "Environment:"
            echo "  - ASP.NET Core Runtime 8.0.25"
            echo "  - OpenSSL 3.3.0 (FIPS-enabled)"
            echo "  - wolfSSL FIPS v5.8.2 (Certificate #4718)"
            echo "  - wolfProvider v1.1.0"
            echo ""
            exit 0
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --status|-s)
            STATUS_ONLY=true
            shift
            ;;
        --crypto|-c)
            CRYPTO_ONLY=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Print header
echo ""
echo -e "${BOLD}${CYAN}================================================================================${NC}"
echo -e "${BOLD}${CYAN}  ASP.NET Core FIPS Diagnostic Suite${NC}"
echo -e "${BOLD}${CYAN}  wolfSSL FIPS v5.8.2 (Certificate #4718)${NC}"
echo -e "${BOLD}${CYAN}================================================================================${NC}"
echo ""

# Display environment info
echo -e "${BLUE}Environment Information:${NC}"
if command -v dotnet >/dev/null 2>&1; then
    DOTNET_VERSION=$(dotnet --version 2>/dev/null || echo "unknown")
    echo -e "  ${GREEN}✓${NC} .NET SDK/Runtime: $DOTNET_VERSION"
else
    echo -e "  ${YELLOW}⚠${NC} .NET not found in PATH"
fi

if command -v openssl >/dev/null 2>&1; then
    OPENSSL_VERSION=$(openssl version 2>/dev/null || echo "unknown")
    echo -e "  ${GREEN}✓${NC} OpenSSL: $OPENSSL_VERSION"
else
    echo -e "  ${RED}✗${NC} OpenSSL not found"
fi

if [ -n "$OPENSSL_CONF" ]; then
    echo -e "  ${GREEN}✓${NC} FIPS Config: $OPENSSL_CONF"
else
    echo -e "  ${YELLOW}⚠${NC} OPENSSL_CONF not set"
fi

echo ""
echo -e "${BLUE}Test Configuration:${NC}"
if [ "$STATUS_ONLY" = true ]; then
    echo -e "  Mode: ${YELLOW}Status Check Only${NC}"
    echo -e "  Tests: 10"
elif [ "$CRYPTO_ONLY" = true ]; then
    echo -e "  Mode: ${YELLOW}Crypto Operations Only${NC}"
    echo -e "  Tests: 20"
else
    echo -e "  Mode: ${GREEN}Full Diagnostic Suite${NC}"
    echo -e "  Tests: 65 (5 suites)"
fi

if [ "$VERBOSE" = true ]; then
    echo -e "  Verbosity: ${YELLOW}Enabled${NC}"
fi

echo ""
echo -e "${CYAN}-------------------------------------------------------------------------------${NC}"
echo ""

# Execute tests based on mode
if [ "$STATUS_ONLY" = true ]; then
    # Run status check only
    echo -e "${YELLOW}Running FIPS Status Check...${NC}"
    echo ""
    if ./test-aspnet-fips-status.sh; then
        echo ""
        echo -e "${GREEN}✓ Status check completed successfully${NC}"
        exit 0
    else
        echo ""
        echo -e "${RED}✗ Status check failed${NC}"
        exit 1
    fi

elif [ "$CRYPTO_ONLY" = true ]; then
    # Run crypto operations only
    echo -e "${YELLOW}Running Cryptographic Operations Tests...${NC}"
    echo ""
    if command -v dotnet-script >/dev/null 2>&1; then
        if dotnet-script test-crypto-operations.cs; then
            echo ""
            echo -e "${GREEN}✓ Crypto operations tests completed successfully${NC}"
            exit 0
        else
            echo ""
            echo -e "${RED}✗ Crypto operations tests failed${NC}"
            exit 1
        fi
    else
        echo -e "${RED}✗ dotnet-script not available${NC}"
        echo "  Install with: dotnet tool install -g dotnet-script"
        exit 1
    fi

else
    # Run full test suite
    if ./run-all-tests.sh; then
        echo ""
        echo -e "${GREEN}${BOLD}✓ All diagnostic tests completed successfully${NC}"
        echo ""
        echo -e "${CYAN}Results saved in JSON format:${NC}"
        if [ -f "backend-verification-results.json" ]; then
            echo -e "  ${GREEN}✓${NC} backend-verification-results.json"
        fi
        if [ -f "fips-verification-results.json" ]; then
            echo -e "  ${GREEN}✓${NC} fips-verification-results.json"
        fi
        if [ -f "crypto-operations-results.json" ]; then
            echo -e "  ${GREEN}✓${NC} crypto-operations-results.json"
        fi
        if [ -f "connectivity-results.json" ]; then
            echo -e "  ${GREEN}✓${NC} connectivity-results.json"
        fi
        echo ""
        exit 0
    else
        echo ""
        echo -e "${RED}${BOLD}✗ Some diagnostic tests failed${NC}"
        echo ""
        echo "Check individual test results for details:"
        echo "  - backend-verification-results.json"
        echo "  - fips-verification-results.json"
        echo "  - crypto-operations-results.json"
        echo "  - connectivity-results.json"
        echo ""
        exit 1
    fi
fi
