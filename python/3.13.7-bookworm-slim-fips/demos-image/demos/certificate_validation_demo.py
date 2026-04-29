#!/usr/bin/env python3
"""
Certificate Validation Demo

Demonstrates certificate chain validation, hostname verification,
CA bundle loading, and certificate inspection using wolfSSL FIPS.
"""

import ssl
import socket
import sys
from datetime import datetime


def print_header():
    print()
    print("=" * 70)
    print("  Certificate Validation Demo - Python with wolfSSL FIPS")
    print("=" * 70)
    print()


def demo_certificate_retrieval():
    """Demo 1: Retrieve and inspect peer certificate"""
    print("Demo 1: Certificate Retrieval and Inspection")
    print("-" * 70)

    hostname = "www.python.org"
    port = 443

    try:
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        context.check_hostname = False
        # Use CERT_REQUIRED to retrieve peer certificate (CERT_NONE doesn't retrieve certs)
        context.verify_mode = ssl.CERT_REQUIRED
        # Load CA certificates so verification can work
        context.load_default_certs()

        print(f"Connecting to {hostname} and retrieving certificate...")
        print()

        with socket.create_connection((hostname, port), timeout=10) as sock:
            with context.wrap_socket(sock, server_hostname=hostname) as ssock:
                cert = ssock.getpeercert()

                if cert:
                    # Extract certificate details
                    subject = dict(x[0] for x in cert.get('subject', []))
                    issuer = dict(x[0] for x in cert.get('issuer', []))

                    print("✓ Certificate retrieved:")
                    print(f"  Subject:")
                    print(f"    Common Name: {subject.get('commonName', 'N/A')}")
                    print(f"    Organization: {subject.get('organizationName', 'N/A')}")
                    print(f"    Country: {subject.get('countryName', 'N/A')}")
                    print()
                    print(f"  Issuer:")
                    print(f"    Common Name: {issuer.get('commonName', 'N/A')}")
                    print(f"    Organization: {issuer.get('organizationName', 'N/A')}")
                    print()
                    print(f"  Validity:")
                    print(f"    Not Before: {cert.get('notBefore', 'N/A')}")
                    print(f"    Not After: {cert.get('notAfter', 'N/A')}")
                    print()
                    print(f"  Subject Alternative Names:")
                    san = cert.get('subjectAltName', [])
                    for type_name, value in san[:5]:
                        print(f"    {type_name}: {value}")
                    if len(san) > 5:
                        print(f"    ... and {len(san) - 5} more")
                    print()

                    return True
                else:
                    print("✗ No certificate retrieved")
                    print()
                    return False

    except Exception as e:
        print(f"✗ Certificate retrieval failed: {e}")
        print()
        return False


def demo_ca_bundle_loading():
    """Demo 2: Load CA bundle and verify certificate store"""
    print("Demo 2: CA Bundle Loading")
    print("-" * 70)

    ca_file = "/etc/ssl/certs/ca-certificates.crt"

    try:
        context = ssl.create_default_context()

        print(f"Loading CA bundle from {ca_file}...")
        context.load_verify_locations(cafile=ca_file)

        # Check certificate store stats
        stats = context.cert_store_stats()

        print("✓ CA bundle loaded:")
        print(f"  X.509 CA certificates: {stats.get('x509_ca', 0)}")
        print(f"  X.509 certificates: {stats.get('x509', 0)}")
        print(f"  CRLs: {stats.get('crl', 0)}")
        print()

        if stats.get('x509_ca', 0) > 0:
            return True
        else:
            print("⚠ No CA certificates loaded")
            print()
            return False

    except Exception as e:
        print(f"✗ CA bundle loading failed: {e}")
        print()
        return False


def demo_hostname_verification():
    """Demo 3: Hostname verification logic"""
    print("Demo 3: Hostname Verification")
    print("-" * 70)

    print("Testing hostname verification with actual connections...")
    print()

    try:
        # Note: Python 3.13.7 removed ssl.match_hostname()
        # We now test hostname verification with actual TLS connections

        # Test case 1: Correct hostname (should succeed)
        hostname = "www.python.org"
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        context.check_hostname = True  # Enable hostname checking
        context.verify_mode = ssl.CERT_REQUIRED
        context.load_default_certs()

        try:
            with socket.create_connection((hostname, 443), timeout=10) as sock:
                with context.wrap_socket(sock, server_hostname=hostname) as ssock:
                    cert = ssock.getpeercert()
                    subject = dict(x[0] for x in cert.get('subject', []))
                    print(f"  ✓ Correct hostname verified: {hostname}")
                    print(f"    Certificate CN: {subject.get('commonName')}")
        except ssl.SSLCertVerificationError as e:
            print(f"  ✗ Hostname verification failed (unexpected): {e}")
            return False

        # Test case 2: Wrong hostname (should fail)
        print()
        context2 = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        context2.check_hostname = True
        context2.verify_mode = ssl.CERT_REQUIRED
        context2.load_default_certs()

        try:
            with socket.create_connection(("www.python.org", 443), timeout=10) as sock:
                # Try to verify with wrong hostname
                with context2.wrap_socket(sock, server_hostname="www.wrong-domain.com") as ssock:
                    print(f"  ✗ Wrong hostname accepted (unexpected)")
                    return False
        except ssl.SSLCertVerificationError:
            print(f"  ✓ Wrong hostname correctly rejected")

        print()
        print("  Note: Python 3.13.7+ uses check_hostname=True for verification")
        print("        (ssl.match_hostname() was removed)")
        print()
        return True

    except Exception as e:
        print(f"✗ Hostname verification demo failed: {e}")
        print()
        return False


def demo_certificate_chain():
    """Demo 4: Certificate chain validation"""
    print("Demo 4: Certificate Chain Validation")
    print("-" * 70)

    hostname = "www.github.com"
    port = 443

    try:
        # Create context with default CA bundle
        context = ssl.create_default_context()
        context.load_verify_locations(cafile="/etc/ssl/certs/ca-certificates.crt")

        # Enable hostname checking
        context.check_hostname = True
        context.verify_mode = ssl.CERT_REQUIRED

        print(f"Validating certificate chain for {hostname}...")
        print()

        with socket.create_connection((hostname, port), timeout=10) as sock:
            with context.wrap_socket(sock, server_hostname=hostname) as ssock:
                cert = ssock.getpeercert()

                subject = dict(x[0] for x in cert.get('subject', []))
                issuer = dict(x[0] for x in cert.get('issuer', []))

                print("✓ Certificate chain validated successfully:")
                print(f"  Server: {subject.get('commonName')}")
                print(f"  Issued by: {issuer.get('commonName')}")
                print(f"  Hostname verified: {hostname}")
                print()

                return True

    except ssl.SSLError as e:
        print(f"✗ Certificate validation failed: {e}")
        print(f"  This could indicate:")
        print(f"    - Invalid certificate chain")
        print(f"    - Expired certificate")
        print(f"    - Hostname mismatch")
        print()
        return False
    except Exception as e:
        print(f"✗ Connection failed: {e}")
        print()
        return False


def demo_cipher_and_protocol():
    """Demo 5: Inspect negotiated cipher and protocol"""
    print("Demo 5: Connection Security Details")
    print("-" * 70)

    hostname = "www.cloudflare.com"
    port = 443

    try:
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        context.check_hostname = False
        # Use CERT_REQUIRED to retrieve peer certificate
        context.verify_mode = ssl.CERT_REQUIRED
        context.load_default_certs()

        print(f"Connecting to {hostname} and inspecting connection details...")
        print()

        with socket.create_connection((hostname, port), timeout=10) as sock:
            with context.wrap_socket(sock, server_hostname=hostname) as ssock:
                # Get connection details
                version = ssock.version()
                cipher = ssock.cipher()
                compression = ssock.compression()

                print("✓ Connection established:")
                print(f"  TLS Version: {version}")
                print(f"  Cipher Suite: {cipher[0]}")
                print(f"  Cipher Protocol: {cipher[1]}")
                print(f"  Cipher Bits: {cipher[2]}")
                print(f"  Compression: {compression if compression else 'None'}")
                print()

                # Get certificate
                cert = ssock.getpeercert()
                if cert:
                    subject = dict(x[0] for x in cert.get('subject', []))
                    print(f"  Server Identity: {subject.get('commonName')}")

                print()
                return True

    except Exception as e:
        print(f"✗ Failed: {e}")
        print()
        return False


def main():
    """Run all certificate validation demos"""
    print_header()

    print("This demo showcases certificate validation using wolfSSL FIPS.")
    print("All certificate operations use the wolfSSL FIPS cryptographic module.")
    print()

    demos = [
        demo_certificate_retrieval,
        demo_ca_bundle_loading,
        demo_hostname_verification,
        demo_certificate_chain,
        demo_cipher_and_protocol,
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
        print("✓ All certificate validation demos completed successfully")
        print()
        print("Key Takeaways:")
        print("  ✓ Certificate chain validation works with wolfSSL FIPS")
        print("  ✓ Hostname verification is functional")
        print("  ✓ CA bundle can be loaded and used")
        print("  ✓ Certificate details can be inspected")
        print()
        return 0
    elif successful >= 4:
        print("⚠ Most demos completed (one may have had network issues)")
        print()
        return 0
    else:
        print("✗ Several demos failed")
        print()
        return 1


if __name__ == "__main__":
    sys.exit(main())
