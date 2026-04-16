#!/bin/bash
#
# FIPS Configuration Report Generator
# Generates comprehensive FIPS status report
#

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Output file
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="fips-report-${TIMESTAMP}.txt"

echo "================================================================"
echo "  FIPS Configuration Report Generator"
echo "================================================================"
echo ""
echo "Generating comprehensive FIPS status report..."
echo ""

# Start report
{
    echo "================================================================"
    echo "  FIPS 140-3 Configuration Report"
    echo "  Generated: $(date)"
    echo "================================================================"
    echo ""

    # System Information
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "SYSTEM INFORMATION"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Hostname: $(hostname)"
    echo "OS: $(cat /etc/fedora-release 2>/dev/null || echo 'Unknown')"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo ""

    # OpenSSL Information
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "OPENSSL INFORMATION"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    openssl version -a
    echo ""

    # Crypto-Policies
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "CRYPTO-POLICIES CONFIGURATION"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Current Policy: $(cat /etc/crypto-policies/config 2>/dev/null || echo 'NOT FOUND')"
    echo ""

    # Providers
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "OPENSSL PROVIDERS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    openssl list -providers -verbose 2>/dev/null || echo "Could not list providers"
    echo ""

    # Environment Variables
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "FIPS ENVIRONMENT VARIABLES"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "OPENSSL_FORCE_FIPS_MODE: ${OPENSSL_FORCE_FIPS_MODE:-not set}"
    echo "OPENSSL_CONF: ${OPENSSL_CONF:-not set}"
    echo ""

    # Available Algorithms
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "AVAILABLE DIGEST ALGORITHMS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    openssl list -digest-algorithms 2>/dev/null || echo "Could not list algorithms"
    echo ""

    # Cipher Suites
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "FIPS CIPHER SUITES"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    openssl ciphers -v 'FIPS' 2>/dev/null || echo "Could not list FIPS ciphers"
    echo ""

    # Quick Tests
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "QUICK FIPS VALIDATION TESTS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Test SHA-256
    echo -n "SHA-256 test: "
    if echo "test" | openssl dgst -sha256 > /dev/null 2>&1; then
        echo "✓ PASS"
    else
        echo "✗ FAIL"
    fi

    # Test MD5 (should fail)
    echo -n "MD5 block test: "
    if echo "test" | openssl dgst -md5 > /dev/null 2>&1; then
        echo "✗ FAIL (MD5 should be blocked)"
    else
        echo "✓ PASS (MD5 correctly blocked)"
    fi

    # Test AES encryption
    echo -n "AES-256 encryption: "
    if echo "test" | openssl enc -aes-256-cbc -pbkdf2 -pass pass:test > /dev/null 2>&1; then
        echo "✓ PASS"
    else
        echo "✗ FAIL"
    fi

    # Test RSA key generation
    echo -n "RSA-2048 key gen: "
    if openssl genrsa 2048 > /dev/null 2>&1; then
        echo "✓ PASS"
    else
        echo "✗ FAIL"
    fi

    echo ""

    # Summary
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "SUMMARY"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    FIPS_PROVIDER=$(openssl list -providers 2>/dev/null | grep -i fips || echo "NOT FOUND")
    CRYPTO_POLICY=$(cat /etc/crypto-policies/config 2>/dev/null || echo "NOT FOUND")

    if echo "$FIPS_PROVIDER" | grep -qi "fips" && [ "$CRYPTO_POLICY" = "FIPS" ]; then
        echo "FIPS MODE STATUS: ✓ ENABLED"
    else
        echo "FIPS MODE STATUS: ✗ NOT FULLY CONFIGURED"
    fi

    echo ""
    echo "Report generated: $(date)"
    echo "================================================================"

} > "$REPORT_FILE"

# Display summary
echo -e "${GREEN}✓ Report generated successfully${NC}"
echo ""
echo "Report saved to: $REPORT_FILE"
echo ""
echo "To view the report:"
echo "  cat $REPORT_FILE"
echo ""
echo "Quick summary:"
openssl list -providers 2>/dev/null | grep -i fips && echo -e "${GREEN}✓ FIPS provider loaded${NC}" || echo -e "${RED}✗ FIPS provider not found${NC}"
POLICY=$(cat /etc/crypto-policies/config 2>/dev/null)
[ "$POLICY" = "FIPS" ] && echo -e "${GREEN}✓ Crypto-policies set to FIPS${NC}" || echo -e "${YELLOW}⚠ Crypto-policies: $POLICY${NC}"
echo ""

exit 0
