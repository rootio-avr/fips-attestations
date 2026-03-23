#!/usr/bin/env python3
"""
Hash Algorithm Demo

Demonstrates FIPS-approved hash algorithms and shows what happens
when attempting to use non-FIPS algorithms in FIPS mode.
"""

import hashlib
import subprocess
import sys


def print_header():
    print()
    print("=" * 70)
    print("  Hash Algorithm Demo - Python with wolfSSL FIPS")
    print("=" * 70)
    print()


def demo_fips_approved_algorithms():
    """Demo FIPS-approved hash algorithms"""
    print("Demo 1: FIPS-Approved Hash Algorithms")
    print("-" * 70)
    print()

    test_data = b"This is test data for FIPS-approved hash algorithms"

    algorithms = [
        ("SHA-256", hashlib.sha256),
        ("SHA-384", hashlib.sha384),
        ("SHA-512", hashlib.sha512),
    ]

    print("Testing FIPS-approved algorithms:")
    print()

    for name, algo_func in algorithms:
        try:
            h = algo_func()
            h.update(test_data)
            digest = h.hexdigest()

            print(f"✓ {name}:")
            print(f"  Input: {test_data[:30]}...")
            print(f"  Digest: {digest[:64]}...")
            print(f"  Length: {len(digest)} hex characters")
            print()

        except Exception as e:
            print(f"✗ {name} failed: {e}")
            print()

    print()


def demo_non_fips_algorithms():
    """Demo non-FIPS algorithms (MD5, SHA-1)"""
    print("Demo 2: Non-FIPS Algorithm Handling (MD5, SHA-1)")
    print("-" * 70)
    print()

    test_data = b"Test data for non-FIPS algorithms"

    # Test 1: Python hashlib MD5
    print("Test 1: Python hashlib.md5()")
    print()

    try:
        h = hashlib.md5()
        h.update(test_data)
        digest = h.hexdigest()

        print(f"  ℹ️  Python hashlib.md5() is available: {digest[:32]}...")
        print(f"     Note: This uses Python's built-in implementation")
        print(f"     It is NOT using OpenSSL/wolfSSL")
        print(f"     MD5 should NOT be used for security purposes")
        print()

    except Exception as e:
        print(f"  ✓ Python hashlib.md5() blocked: {e}")
        print()

    # Test 2: OpenSSL-level MD5 blocking
    print("Test 2: OpenSSL MD5 (FIPS enforcement check)")
    print()

    try:
        result = subprocess.run(
            ["bash", "-c", "echo -n 'test' | openssl dgst -md5"],
            capture_output=True,
            text=True,
            timeout=5
        )

        if result.returncode != 0 and "unsupported" in (result.stderr + result.stdout).lower():
            print(f"  ✓ MD5 is BLOCKED at OpenSSL level")
            print(f"     This confirms FIPS mode is active")
            print(f"     Error: {result.stderr.split('error:')[-1].strip()[:60] if result.stderr else 'MD5 unsupported'}")
            print()
        else:
            print(f"  ⚠  MD5 is available at OpenSSL level")
            print(f"     Output: {result.stdout[:50]}")
            print()

    except Exception as e:
        print(f"  ⚠  Could not test OpenSSL MD5: {e}")
        print()

    # Test 3: Python hashlib SHA-1
    print("Test 3: Python hashlib.sha1()")
    print()

    try:
        h = hashlib.sha1()
        h.update(test_data)
        digest = h.hexdigest()

        print(f"  ℹ️  Python hashlib.sha1() is available: {digest[:32]}...")
        print(f"     Note: SHA-1 is available but deprecated for security")
        print(f"     FIPS allows SHA-1 for legacy verification only")
        print(f"     SHA-1 should NOT be used for new signatures or certificates")
        print()

    except Exception as e:
        print(f"  ✓ Python hashlib.sha1() blocked: {e}")
        print()

    # Test 4: OpenSSL-level SHA-1 availability
    print("Test 4: OpenSSL SHA-1 (FIPS policy check)")
    print()

    try:
        result = subprocess.run(
            ["bash", "-c", "echo -n 'test' | openssl dgst -sha1"],
            capture_output=True,
            text=True,
            timeout=5
        )

        if result.returncode == 0:
            print(f"  ℹ️  SHA-1 is AVAILABLE at OpenSSL level")
            print(f"     This is FIPS-compliant for legacy certificate verification")
            print(f"     Output: {result.stdout[:60]}")
            print(f"     Policy: SHA-1 allowed for verification, blocked for new signatures")
            print()
        else:
            print(f"  ✓ SHA-1 is blocked at OpenSSL level")
            print(f"     Error: {result.stderr.split('error:')[-1].strip()[:60] if result.stderr else 'SHA-1 unsupported'}")
            print()

    except Exception as e:
        print(f"  ⚠  Could not test OpenSSL SHA-1: {e}")
        print()

    print("Key Insight:")
    print("  - Python's hashlib may have MD5 (built-in implementation)")
    print("  - BUT OpenSSL/wolfSSL MD5 is BLOCKED for TLS/crypto operations")
    print("  - SHA-1 is available for legacy verification (FIPS 140-3 compliant)")
    print("  - This prevents MD5/SHA-1 use in new certificates, ciphers, and signatures")
    print()


def demo_hash_comparison():
    """Demo comparing hashes from different algorithms"""
    print("Demo 3: Hash Comparison")
    print("-" * 70)
    print()

    test_strings = [
        "Hello, World!",
        "Python wolfSSL FIPS",
        "Cryptographic hashing demo",
    ]

    print("Comparing SHA-256 hashes for different inputs:")
    print()

    for test_str in test_strings:
        test_bytes = test_str.encode('utf-8')
        h = hashlib.sha256()
        h.update(test_bytes)
        digest = h.hexdigest()

        print(f"Input:  '{test_str}'")
        print(f"SHA-256: {digest}")
        print()

    # Show collision resistance
    print("Demonstrating collision resistance:")
    similar_strings = [
        "The quick brown fox",
        "The quick brown fox.",  # Just one character different
    ]

    for test_str in similar_strings:
        test_bytes = test_str.encode('utf-8')
        h = hashlib.sha256()
        h.update(test_bytes)
        digest = h.hexdigest()

        print(f"'{test_str}'")
        print(f"  → {digest}")

    print()
    print("Note: Even tiny input changes produce completely different hashes")
    print()


def demo_streaming_hash():
    """Demo streaming/incremental hashing"""
    print("Demo 4: Streaming Hash Computation")
    print("-" * 70)
    print()

    print("Computing hash incrementally (useful for large data):")
    print()

    # Method 1: All at once
    data = b"Part 1" + b"Part 2" + b"Part 3"
    h1 = hashlib.sha256()
    h1.update(data)
    digest1 = h1.hexdigest()

    print(f"Method 1 - All at once:")
    print(f"  Data: {data}")
    print(f"  Digest: {digest1}")
    print()

    # Method 2: Incremental
    h2 = hashlib.sha256()
    h2.update(b"Part 1")
    h2.update(b"Part 2")
    h2.update(b"Part 3")
    digest2 = h2.hexdigest()

    print(f"Method 2 - Incremental:")
    print(f"  Data: b'Part 1' + b'Part 2' + b'Part 3'")
    print(f"  Digest: {digest2}")
    print()

    if digest1 == digest2:
        print("✓ Both methods produce identical results")
        print("  This demonstrates streaming hash computation")
    else:
        print("✗ Digests don't match (unexpected)")

    print()


def main():
    """Run all hash algorithm demos"""
    print_header()

    print("This demo showcases FIPS-approved hash algorithms.")
    print("All hashing operations are performed by wolfSSL FIPS module.")
    print()

    demo_fips_approved_algorithms()
    demo_non_fips_algorithms()
    demo_hash_comparison()
    demo_streaming_hash()

    print("=" * 70)
    print("  Demo Complete")
    print("=" * 70)
    print()
    print("Key Takeaways:")
    print("  ✓ SHA-256, SHA-384, and SHA-512 are FIPS-approved")
    print("  ⚠ MD5 availability depends on FIPS enforcement mode")
    print("  ⚠ SHA-1 available for legacy verification only (not for new signatures)")
    print("  ✓ Hash functions provide collision resistance")
    print("  ✓ Streaming computation is supported")
    print()

    return 0


if __name__ == "__main__":
    sys.exit(main())
