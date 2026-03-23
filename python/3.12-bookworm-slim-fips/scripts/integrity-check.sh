#!/bin/bash
#
# Library Integrity Verification Script
# Verifies SHA-256 checksums of FIPS libraries to detect tampering
#

set -e

CHECKSUM_DIR="/opt/wolfssl-fips/checksums"
FAILED=0

echo "Verifying FIPS library integrity..."
echo ""

# Function to verify checksum
verify_checksum() {
    local checksum_file="$1"
    local description="$2"

    if [ ! -f "$checksum_file" ]; then
        echo "⚠  WARNING: Checksum file not found: $checksum_file"
        return 1
    fi

    echo "Checking $description..."

    # Read the checksum file and verify
    while IFS= read -r line; do
        # Parse checksum and file path
        expected_sum=$(echo "$line" | awk '{print $1}')
        file_path=$(echo "$line" | awk '{print $2}')

        if [ ! -f "$file_path" ]; then
            echo "  ✗ FAIL: File not found: $file_path"
            FAILED=1
            continue
        fi

        # Calculate current checksum
        current_sum=$(sha256sum "$file_path" | awk '{print $1}')

        if [ "$expected_sum" = "$current_sum" ]; then
            echo "  ✓ OK: $file_path"
        else
            echo "  ✗ FAIL: Checksum mismatch for $file_path"
            echo "    Expected: $expected_sum"
            echo "    Got:      $current_sum"
            FAILED=1
        fi
    done < "$checksum_file"

    echo ""
}

# Verify wolfSSL library
if [ -f "$CHECKSUM_DIR/libwolfssl.sha256" ]; then
    verify_checksum "$CHECKSUM_DIR/libwolfssl.sha256" "wolfSSL library"
fi

# Verify wolfProvider library
if [ -f "$CHECKSUM_DIR/libwolfprov.sha256" ]; then
    verify_checksum "$CHECKSUM_DIR/libwolfprov.sha256" "wolfProvider library"
fi

# Verify test-fips executable
if [ -f "$CHECKSUM_DIR/test-fips.sha256" ]; then
    verify_checksum "$CHECKSUM_DIR/test-fips.sha256" "FIPS test executable"
fi

# Final result
if [ $FAILED -eq 0 ]; then
    echo "✓ All integrity checks passed"
    echo ""
    exit 0
else
    echo "✗ Integrity check failed - libraries may have been tampered with"
    echo ""
    exit 1
fi
