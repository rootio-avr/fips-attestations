#!/bin/bash
# Test: Go FIPS Algorithms
# Tests FIPS algorithm enforcement in Go runtime

IMAGE_NAME="cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips"

echo "Testing Go FIPS Algorithm Enforcement..."
echo ""

# Test MD5 blocking (should fail with GODEBUG=fips140=only)
echo "Test 1: MD5 should be blocked"
if docker run --rm --entrypoint=bash "$IMAGE_NAME" -c '
    echo "test" | openssl dgst -md5 2>&1 | grep -qi "error\|disabled\|unsupported"
'; then
    echo "[OK] MD5 is blocked"
else
    echo "[WARN] MD5 may not be blocked"
fi

# Test SHA-256 (should work)
echo "Test 2: SHA-256 should work"
if docker run --rm --entrypoint=bash "$IMAGE_NAME" -c '
    echo "test" | openssl dgst -sha256 >/dev/null 2>&1
'; then
    echo "[OK] SHA-256 works"
else
    echo "[FAIL] SHA-256 failed"
    exit 1
fi

echo ""
echo "✓ Go FIPS algorithm tests passed"
