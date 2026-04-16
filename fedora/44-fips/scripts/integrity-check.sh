#!/bin/bash
# FIPS Integrity Check Script for Fedora 44

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "Running FIPS integrity checks..."

# Check checksums exist
if [ ! -d /opt/fips/checksums ]; then
    echo -e "${RED}✗ Checksums directory not found${NC}"
    exit 1
fi

# Verify verification scripts
if [ -f /opt/fips/checksums/verification-scripts.sha256 ]; then
    if sha256sum -c /opt/fips/checksums/verification-scripts.sha256 > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Verification scripts integrity OK${NC}"
    else
        echo -e "${RED}✗ Verification scripts integrity FAILED${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✓ All integrity checks passed${NC}"
exit 0
