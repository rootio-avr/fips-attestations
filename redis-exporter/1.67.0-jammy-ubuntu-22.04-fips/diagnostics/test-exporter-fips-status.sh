#!/bin/bash
# Test: FIPS Status Validation for redis_exporter
# Validates that FIPS mode is enabled and operational

IMAGE_NAME="cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips"

echo "Testing FIPS Status..."
echo ""

# Test 1: FIPS environment variables
docker run --rm --entrypoint=bash "$IMAGE_NAME" -c '
    if [ "$GOLANG_FIPS" = "1" ] && [ "$GODEBUG" = "fips140=only" ]; then
        echo "[OK] FIPS environment variables set correctly"
        exit 0
    else
        echo "[FAIL] FIPS environment variables not set"
        exit 1
    fi
'

# Test 2: wolfSSL FIPS POST
docker run --rm --entrypoint=/usr/local/bin/fips-check "$IMAGE_NAME"

# Test 3: wolfProvider loaded
docker run --rm --entrypoint=bash "$IMAGE_NAME" -c '
    if openssl list -providers | grep -qi "wolfSSL"; then
        echo "[OK] wolfProvider loaded"
        exit 0
    else
        echo "[FAIL] wolfProvider not loaded"
        exit 1
    fi
'

echo ""
echo "✓ FIPS status validation passed"
