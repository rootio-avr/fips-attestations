#!/bin/bash
################################################################################
# wolfSSL FIPS Integrity Verification Script
#
# Purpose: Verify integrity of critical FIPS components
# - wolfSSL library checksums
# - wolfProvider library checksums
# - FIPS test executable checksum
################################################################################

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

CHECKSUM_DIR="/opt/wolfssl-fips/checksums"
FAILURES=0

echo "Verifying wolfSSL FIPS component integrity..."
echo ""

# Function to verify checksum
verify_checksum() {
    local checksum_file="$1"
    local component_name="$2"

    if [ ! -f "$checksum_file" ]; then
        echo -e "${RED}✗ Checksum file not found: $checksum_file${NC}"
        FAILURES=$((FAILURES + 1))
        return 1
    fi

    # Verify checksum
    if sha256sum -c "$checksum_file" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $component_name integrity verified"
        return 0
    else
        echo -e "${RED}✗${NC} $component_name integrity check FAILED"
        FAILURES=$((FAILURES + 1))
        return 1
    fi
}

# Verify wolfSSL library
verify_checksum "$CHECKSUM_DIR/libwolfssl.sha256" "wolfSSL library"

# Verify wolfProvider library
verify_checksum "$CHECKSUM_DIR/libwolfprov.sha256" "wolfProvider library"

# Verify FIPS test executable
verify_checksum "$CHECKSUM_DIR/test-fips.sha256" "FIPS KAT executable"

echo ""

# Summary
if [ $FAILURES -eq 0 ]; then
    echo -e "${GREEN}✓ All integrity checks passed${NC}"
    exit 0
else
    echo -e "${RED}✗ $FAILURES integrity check(s) failed${NC}"
    echo -e "${YELLOW}⚠ WARNING: FIPS component integrity compromised${NC}"
    exit 1
fi
