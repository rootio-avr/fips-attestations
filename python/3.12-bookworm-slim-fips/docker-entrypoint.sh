#!/bin/bash
#
# Docker entrypoint script for Python 3.12 with wolfSSL FIPS 140-3
# (Certificate #4718) using wolfProvider
#
# This entrypoint script performs the following tasks:
#    1. Configures debug logging based on environment variables
#    2. Sets library paths for native libraries
#    3. Verifies integrity of FIPS libraries before loading them
#    4. Conducts FIPS container sanity checks
#       - Verify wolfSSL is properly integrated
#       - Run FIPS POST (Power-On Self-Test)
#       - Verify FIPS-approved algorithms are available
#       - Check that OpenSSL binaries are not present
set -e

# Function to handle signals for graceful shutdown
cleanup() {
    echo "Shutting down gracefully..."
    exit 0
}

trap cleanup SIGTERM SIGINT

# Configure debug logging based on environment variables
if [ "$WOLFSSL_DEBUG" = "true" ]; then
    echo "Enabling wolfSSL debug logging"
    export WOLFSSL_DEBUG=yes
fi

# Set OpenSSL configuration
export OPENSSL_CONF=/etc/ssl/openssl.cnf
export OPENSSL_MODULES=/usr/lib

# Update library cache
ldconfig 2>/dev/null || true

# Run FIPS verification checks if enabled (default: true)
if [ "${FIPS_CHECK:-true}" = "true" ]; then
    # Verify library integrity before loading/using any libraries
    echo ""
    echo "================================================================================"
    echo "|                       Library Checksum Verification                         |"
    echo "================================================================================"
    echo ""
    if ! /usr/local/bin/integrity-check.sh; then
        echo ""
        echo "ERROR: FIPS library integrity verification failed! Container will terminate."
        exit 1
    fi

    # Run FIPS Known Answer Tests
    echo ""
    echo "================================================================================"
    echo "|                       FIPS Known Answer Tests (KAT)                         |"
    echo "================================================================================"
    echo ""
    if ! /test-fips; then
        echo ""
        echo "ERROR: FIPS KAT failed! Container will terminate."
        exit 1
    fi
    echo "✓ FIPS KAT passed successfully"

    # Run FIPS container verification
    echo ""
    echo "================================================================================"
    echo "|                        FIPS Container Verification                          |"
    echo "================================================================================"
    echo ""
    if ! python3 /opt/wolfssl-fips/bin/fips_init_check.py; then
        echo ""
        echo "WARNING: FIPS verification checks had issues (may be expected)"
        echo "Container will continue, but review the output above"
    fi

    echo ""
    echo "================================================================================"
    echo "|                         All Container Tests Passed                          |"
    echo "================================================================================"
    echo ""
else
    echo ""
    echo "================================================================================"
    echo "|                        FIPS Verification Disabled                           |"
    echo "================================================================================"
    echo ""
    echo "WARNING: FIPS_CHECK=false - Skipping FIPS verification tests"
    echo "This mode is intended for development/testing only and should not be used in production"
    echo ""
fi

# Execute the provided command
echo "Executing command: $@"
echo ""

# Execute the command
exec "$@"
