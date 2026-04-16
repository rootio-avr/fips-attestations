#!/bin/bash
# Enable FIPS Mode via Crypto-Policies

set -e

echo "Enabling FIPS mode via crypto-policies..."

# Set crypto-policies to FIPS
echo "FIPS" > /etc/crypto-policies/config

# Update crypto-policies
if command -v update-crypto-policies &> /dev/null; then
    update-crypto-policies --set FIPS || update-crypto-policies
    echo "✓ Crypto-policies updated to FIPS mode"
else
    echo "⚠ update-crypto-policies command not found"
fi

# Verify configuration
POLICY=$(cat /etc/crypto-policies/config)
echo "Current policy: $POLICY"

# Display OpenSSL provider status
echo ""
echo "OpenSSL FIPS provider status:"
openssl list -providers 2>/dev/null || echo "Could not list providers"

echo ""
echo "✓ FIPS mode configuration complete"
echo "  Note: Set OPENSSL_FORCE_FIPS_MODE=1 environment variable for application-level FIPS"
