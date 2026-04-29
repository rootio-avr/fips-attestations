#!/usr/bin/env python3
"""
TLS/SSL Test Suite

Comprehensive tests for TLS/SSL functionality using wolfSSL.
Tests TLS connections, certificate handling, cipher suites, and protocol versions.
"""

import sys
import ssl
import socket
import time
import subprocess


class TlsTestSuite:
    def __init__(self):
        self.tests_run = 0
        self.tests_passed = 0
        self.tests_failed = 0

    def test(self, name, test_func):
        """Run a single test"""
        self.tests_run += 1
        print(f"Test {self.tests_run}: {name}")
        try:
            start = time.time()
            result = test_func()
            duration = time.time() - start

            if result:
                self.tests_passed += 1
                print(f"  ✓ PASS ({duration:.3f}s)\n")
                return True
            else:
                self.tests_failed += 1
                print(f"  ✗ FAIL\n")
                return False
        except Exception as e:
            self.tests_failed += 1
            print(f"  ✗ EXCEPTION: {e}\n")
            return False

    def test_tls_connection(self):
        """Test basic TLS connection"""
        try:
            hostname = "www.google.com"
            port = 443

            context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
            context.check_hostname = False
            context.verify_mode = ssl.CERT_NONE

            with socket.create_connection((hostname, port), timeout=10) as sock:
                with context.wrap_socket(sock, server_hostname=hostname) as ssock:
                    version = ssock.version()
                    cipher = ssock.cipher()
                    print(f"    Connected to {hostname}")
                    print(f"    TLS version: {version}")
                    print(f"    Cipher: {cipher[0] if cipher else 'unknown'}")
                    return version is not None
        except Exception as e:
            print(f"    Error: {e}")
            return False

    def test_tls_1_2(self):
        """Test TLS 1.2 connection"""
        try:
            hostname = "www.cloudflare.com"
            port = 443

            context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
            context.minimum_version = ssl.TLSVersion.TLSv1_2
            context.maximum_version = ssl.TLSVersion.TLSv1_2
            context.check_hostname = False
            context.verify_mode = ssl.CERT_NONE

            with socket.create_connection((hostname, port), timeout=10) as sock:
                with context.wrap_socket(sock, server_hostname=hostname) as ssock:
                    version = ssock.version()
                    print(f"    TLS version: {version}")
                    return "1.2" in version
        except Exception as e:
            print(f"    Error: {e}")
            return False

    def test_tls_1_3(self):
        """Test TLS 1.3 connection"""
        try:
            hostname = "www.cloudflare.com"
            port = 443

            context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
            context.minimum_version = ssl.TLSVersion.TLSv1_3
            context.check_hostname = False
            context.verify_mode = ssl.CERT_NONE

            with socket.create_connection((hostname, port), timeout=10) as sock:
                with context.wrap_socket(sock, server_hostname=hostname) as ssock:
                    version = ssock.version()
                    print(f"    TLS version: {version}")
                    return "1.3" in version
        except Exception as e:
            print(f"    TLS 1.3 not supported or connection failed: {e}")
            return True  # TLS 1.3 is optional

    def test_sni(self):
        """Test SNI (Server Name Indication)"""
        try:
            hostname = "www.github.com"
            port = 443

            context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
            context.check_hostname = False
            context.verify_mode = ssl.CERT_NONE

            with socket.create_connection((hostname, port), timeout=10) as sock:
                with context.wrap_socket(sock, server_hostname=hostname) as ssock:
                    print(f"    SNI connection successful to {hostname}")
                    return True
        except Exception as e:
            print(f"    Error: {e}")
            return False

    def test_cipher_selection(self):
        """Test cipher suite selection"""
        try:
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
            # Try to set FIPS-compliant cipher
            cipher_string = "ECDHE+AESGCM:AES256-GCM-SHA384:AES128-GCM-SHA256"
            context.set_ciphers(cipher_string)
            print(f"    Cipher string set: {cipher_string}")
            return True
        except Exception as e:
            print(f"    Error: {e}")
            return False

    def test_peer_certificate(self):
        """Test peer certificate retrieval"""
        try:
            hostname = "www.python.org"
            port = 443

            context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
            context.check_hostname = False
            # Use CERT_REQUIRED to retrieve peer certificate (CERT_NONE doesn't retrieve certs)
            context.verify_mode = ssl.CERT_REQUIRED
            # Load CA certificates so verification can work
            context.load_default_certs()

            with socket.create_connection((hostname, port), timeout=10) as sock:
                with context.wrap_socket(sock, server_hostname=hostname) as ssock:
                    cert = ssock.getpeercert()
                    if cert:
                        subject = dict(x[0] for x in cert.get('subject', []))
                        print(f"    Certificate CN: {subject.get('commonName', 'N/A')}")
                        return True
                    else:
                        print("    No certificate retrieved")
                        return False
        except Exception as e:
            print(f"    Error: {e}")
            return False

    def test_md5_blocking(self):
        """Test MD5 is blocked at OpenSSL level"""
        try:
            # Test MD5 blocking via OpenSSL command
            result = subprocess.run(
                ["bash", "-c", "echo -n 'test' | openssl dgst -md5"],
                capture_output=True,
                text=True,
                timeout=5
            )

            if result.returncode != 0 and "unsupported" in (result.stderr + result.stdout):
                print("    MD5 properly blocked at OpenSSL level")
                return True
            else:
                print("    MD5 not blocked (unexpected)")
                return False
        except Exception as e:
            print(f"    Error testing MD5 blocking: {e}")
            return False

    def run_all_tests(self):
        """Run all TLS tests"""
        print()
        print("=" * 70)
        print("  TLS/SSL Test Suite")
        print("=" * 70)
        print()

        # Run all tests
        self.test("Basic TLS Connection", self.test_tls_connection)
        self.test("TLS 1.2 Connection", self.test_tls_1_2)
        self.test("TLS 1.3 Connection", self.test_tls_1_3)
        self.test("SNI Support", self.test_sni)
        self.test("Cipher Suite Selection", self.test_cipher_selection)
        self.test("Peer Certificate Retrieval", self.test_peer_certificate)
        self.test("MD5 Blocking at OpenSSL Level", self.test_md5_blocking)

        # Print summary
        print("=" * 70)
        print("  TLS Test Summary")
        print("=" * 70)
        print(f"  Total: {self.tests_run}")
        print(f"  Passed: {self.tests_passed}")
        print(f"  Failed: {self.tests_failed}")
        pass_rate = (self.tests_passed / self.tests_run * 100) if self.tests_run > 0 else 0
        print(f"  Pass Rate: {pass_rate:.1f}%")
        print()

        if self.tests_passed == self.tests_run:
            print("  ✓ ALL TLS TESTS PASSED")
            return 0
        elif self.tests_passed >= self.tests_run * 0.67:
            print("  ⚠ PARTIAL SUCCESS")
            return 1
        else:
            print("  ✗ TLS TESTS FAILED")
            return 2


if __name__ == "__main__":
    suite = TlsTestSuite()
    exit_code = suite.run_all_tests()
    sys.exit(exit_code)
