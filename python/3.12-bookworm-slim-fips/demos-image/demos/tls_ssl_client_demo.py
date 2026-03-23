#!/usr/bin/env python3
"""
TLS/SSL Client Demo

Demonstrates TLS/SSL client connections using wolfSSL FIPS.
Shows TLS 1.2 and 1.3 connections, cipher suite selection, SNI, and ALPN.
"""

import ssl
import socket
import sys


def print_header():
    print()
    print("=" * 70)
    print("  TLS/SSL Client Demo - Python with wolfSSL FIPS")
    print("=" * 70)
    print()


def demo_basic_connection():
    """Demo 1: Basic HTTPS connection"""
    print("Demo 1: Basic TLS Connection")
    print("-" * 70)

    hostname = "www.google.com"
    port = 443

    try:
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE

        print(f"Connecting to {hostname}:{port}...")

        with socket.create_connection((hostname, port), timeout=10) as sock:
            with context.wrap_socket(sock, server_hostname=hostname) as ssock:
                version = ssock.version()
                cipher = ssock.cipher()

                print(f"✓ Connection established")
                print(f"  TLS Version: {version}")
                print(f"  Cipher Suite: {cipher[0]}")
                print(f"  Cipher Bits: {cipher[2]}")
                print()

        return True
    except Exception as e:
        print(f"✗ Connection failed: {e}")
        print()
        return False


def demo_tls_1_2():
    """Demo 2: TLS 1.2 specific connection"""
    print("Demo 2: TLS 1.2 Connection")
    print("-" * 70)

    hostname = "www.cloudflare.com"
    port = 443

    try:
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        context.minimum_version = ssl.TLSVersion.TLSv1_2
        context.maximum_version = ssl.TLSVersion.TLSv1_2
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE

        print(f"Connecting to {hostname} with TLS 1.2...")

        with socket.create_connection((hostname, port), timeout=10) as sock:
            with context.wrap_socket(sock, server_hostname=hostname) as ssock:
                version = ssock.version()
                cipher = ssock.cipher()

                print(f"✓ TLS 1.2 connection established")
                print(f"  Negotiated Version: {version}")
                print(f"  Cipher: {cipher[0]}")
                print()

        return True
    except Exception as e:
        print(f"✗ TLS 1.2 connection failed: {e}")
        print()
        return False


def demo_tls_1_3():
    """Demo 3: TLS 1.3 specific connection"""
    print("Demo 3: TLS 1.3 Connection")
    print("-" * 70)

    hostname = "www.cloudflare.com"
    port = 443

    try:
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        context.minimum_version = ssl.TLSVersion.TLSv1_3
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE

        print(f"Connecting to {hostname} with TLS 1.3...")

        with socket.create_connection((hostname, port), timeout=10) as sock:
            with context.wrap_socket(sock, server_hostname=hostname) as ssock:
                version = ssock.version()
                cipher = ssock.cipher()

                print(f"✓ TLS 1.3 connection established")
                print(f"  Negotiated Version: {version}")
                print(f"  Cipher: {cipher[0]}")
                print()

        return True
    except Exception as e:
        print(f"⚠ TLS 1.3 not supported or failed: {e}")
        print("  Note: TLS 1.3 support is optional")
        print()
        return True  # TLS 1.3 is optional


def demo_cipher_selection():
    """Demo 4: Cipher suite selection"""
    print("Demo 4: Cipher Suite Selection")
    print("-" * 70)

    hostname = "www.python.org"
    port = 443

    try:
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        # Set FIPS-compliant cipher suites
        cipher_string = "ECDHE+AESGCM:AES256-GCM-SHA384:AES128-GCM-SHA256"
        context.set_ciphers(cipher_string)
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE

        print(f"Requested ciphers: {cipher_string}")
        print(f"Connecting to {hostname}...")

        with socket.create_connection((hostname, port), timeout=10) as sock:
            with context.wrap_socket(sock, server_hostname=hostname) as ssock:
                cipher = ssock.cipher()

                print(f"✓ Connection with custom cipher selection")
                print(f"  Negotiated Cipher: {cipher[0]}")
                print(f"  Cipher Strength: {cipher[2]} bits")
                print()

        return True
    except Exception as e:
        print(f"✗ Cipher selection demo failed: {e}")
        print()
        return False


def demo_sni_alpn():
    """Demo 5: SNI and ALPN"""
    print("Demo 5: SNI (Server Name Indication) and ALPN")
    print("-" * 70)

    hostname = "www.github.com"
    port = 443

    try:
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE

        # Set ALPN protocols
        try:
            context.set_alpn_protocols(['h2', 'http/1.1'])
            alpn_set = True
        except AttributeError:
            alpn_set = False
            print("  Note: ALPN not supported in this Python/SSL version")

        print(f"Connecting to {hostname} with SNI...")
        if alpn_set:
            print(f"  ALPN protocols: ['h2', 'http/1.1']")

        with socket.create_connection((hostname, port), timeout=10) as sock:
            with context.wrap_socket(sock, server_hostname=hostname) as ssock:
                print(f"✓ SNI connection established")
                print(f"  Server Hostname: {hostname}")

                if alpn_set:
                    negotiated = ssock.selected_alpn_protocol()
                    if negotiated:
                        print(f"  ALPN Protocol: {negotiated}")
                    else:
                        print(f"  ALPN: Not negotiated (server may not support)")

                print()

        return True
    except Exception as e:
        print(f"✗ SNI/ALPN demo failed: {e}")
        print()
        return False


def main():
    """Run all TLS/SSL demos"""
    print_header()

    print("This demo showcases TLS/SSL client functionality using wolfSSL FIPS.")
    print("All cryptographic operations are performed by wolfSSL FIPS module.")
    print()

    demos = [
        demo_basic_connection,
        demo_tls_1_2,
        demo_tls_1_3,
        demo_cipher_selection,
        demo_sni_alpn,
    ]

    successful = 0
    total = len(demos)

    for demo in demos:
        if demo():
            successful += 1

    # Summary
    print("=" * 70)
    print("  Demo Summary")
    print("=" * 70)
    print(f"  Successful: {successful}/{total}")
    print()

    if successful == total:
        print("✓ All TLS/SSL demos completed successfully")
        return 0
    elif successful >= total - 1:
        print("⚠ Most demos completed (some optional features not available)")
        return 0
    else:
        print("✗ Some demos failed")
        return 1


if __name__ == "__main__":
    sys.exit(main())
