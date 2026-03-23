#!/bin/bash
#
# Python FIPS Status Check
# Quick diagnostic script to verify Python FIPS configuration
#

set -e

echo ""
echo "================================================================"
echo "  Python FIPS Status Check"
echo "================================================================"
echo ""

# Check 1: Python version
echo "Python Version:"
python3 --version
echo ""

# Check 2: SSL version
echo "SSL Module Version:"
python3 -c "import ssl; print(f'  {ssl.OPENSSL_VERSION}')"
echo ""

# Check 3: wolfSSL library files
echo "wolfSSL Library Files:"
if ls -lh /usr/lib/libwolfssl.so* 2>/dev/null; then
    echo "  ✓ wolfSSL library found"
else
    echo "  ✗ wolfSSL library NOT found"
fi
echo ""

# Check 4: wolfProvider library files
echo "wolfProvider Library Files:"
if ls -lh /usr/lib/libwolfprov.so* 2>/dev/null; then
    echo "  ✓ wolfProvider library found"
else
    echo "  ✗ wolfProvider library NOT found"
fi
echo ""

# Check 5: OpenSSL configuration
echo "OpenSSL Configuration:"
echo "  OPENSSL_CONF=$OPENSSL_CONF"
if [ -f "$OPENSSL_CONF" ]; then
    echo "  ✓ Configuration file exists"
    echo "  Contents:"
    cat "$OPENSSL_CONF" | sed 's/^/    /'
else
    echo "  ✗ Configuration file NOT found"
fi
echo ""

# Check 6: FIPS test executable
echo "FIPS Test Executable:"
if [ -f /test-fips ]; then
    echo "  ✓ /test-fips exists"
    echo "  Running FIPS KATs..."
    if /test-fips; then
        echo "  ✓ FIPS KATs passed"
    else
        echo "  ✗ FIPS KATs failed"
    fi
else
    echo "  ✗ /test-fips NOT found"
fi
echo ""

# Check 7: SSL capabilities
echo "SSL Capabilities:"
python3 << 'EOF'
import ssl
caps = {
    "HAS_TLSv1_2": getattr(ssl, "HAS_TLSv1_2", False),
    "HAS_TLSv1_3": getattr(ssl, "HAS_TLSv1_3", False),
    "HAS_SNI": getattr(ssl, "HAS_SNI", False),
    "HAS_ALPN": getattr(ssl, "HAS_ALPN", False),
}
for cap, value in caps.items():
    status = "✓" if value else "✗"
    print(f"  {status} {cap}: {value}")
EOF
echo ""

# Check 8: FIPS algorithms
echo "FIPS-Approved Algorithms:"
python3 << 'EOF'
import hashlib
algorithms = ["sha256", "sha384", "sha512"]
for algo in algorithms:
    try:
        h = getattr(hashlib, algo)()
        h.update(b"test")
        print(f"  ✓ {algo.upper()}: Available")
    except:
        print(f"  ✗ {algo.upper()}: NOT Available")
EOF
echo ""

# Check 9: Cipher suites
echo "Cipher Suites:"
python3 << 'EOF'
import ssl
ctx = ssl.create_default_context()
if hasattr(ctx, 'get_ciphers'):
    ciphers = ctx.get_ciphers()
    print(f"  Total: {len(ciphers)} cipher suites")
    aes_gcm = [c for c in ciphers if 'AES' in c['name'] and 'GCM' in c['name']]
    print(f"  AES-GCM ciphers: {len(aes_gcm)}")
    if ciphers:
        print(f"  Sample:")
        for c in ciphers[:3]:
            print(f"    - {c['name']}")
else:
    print("  get_ciphers() not available")
EOF
echo ""

echo "================================================================"
echo "  FIPS Status Check Complete"
echo "================================================================"
echo ""
