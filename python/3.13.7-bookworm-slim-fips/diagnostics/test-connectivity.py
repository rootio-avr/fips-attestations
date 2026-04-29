#!/usr/bin/env python3
"""
Connectivity Tests
Tests basic SSL/TLS connectivity to real-world servers
"""

import ssl
import sys
import json
import os
import socket
import urllib.request
import urllib.error
from datetime import datetime, timezone
from concurrent.futures import ThreadPoolExecutor, as_completed
import time

class ConnectivityTests:
    def __init__(self):
        self.results = {
            "test_area": "2-connectivity",
            "timestamp": datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
            "container": "root-io-python-osp:latest",
            "total_tests": 8,
            "passed": 0,
            "failed": 0,
            "skipped": 0,
            "tests": []
        }
    
    def log_test(self, test_id, name, status, details="", duration_ms=0):
        """Log test result"""
        test_result = {
            "id": test_id,
            "name": name,
            "status": status,
            "duration_ms": duration_ms,
            "details": details
        }
        self.results["tests"].append(test_result)
        
        if status == "pass":
            self.results["passed"] += 1
            print(f"✅ {test_id} {name}: PASS")
        elif status == "fail":
            self.results["failed"] += 1
            print(f"❌ {test_id} {name}: FAIL")
        else:
            self.results["skipped"] += 1
            print(f"⏭️  {test_id} {name}: SKIP")
        
        if details:
            print(f"   Details: {details}")
        print()
    
    def https_get(self, url, timeout=10):
        """Perform HTTPS GET request"""
        try:
            # Create SSL context with explicit CA bundle
            context = ssl.create_default_context()
            context.load_verify_locations(cafile="/etc/ssl/certs/ca-certificates.crt")
            
            start = time.time()
            with urllib.request.urlopen(url, timeout=timeout, context=context) as response:
                status = response.status
                content_length = len(response.read())
                duration = int((time.time() - start) * 1000)
                return {
                    "success": True,
                    "status": status,
                    "content_length": content_length,
                    "duration_ms": duration
                }
        except urllib.error.HTTPError as e:
            return {
                "success": e.code < 500,  # 4xx is still a successful connection
                "status": e.code,
                "error": str(e),
                "duration_ms": 0
            }
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "duration_ms": 0
            }
    
    def test_2_1_https_google(self):
        """Test 2.1: HTTPS GET - Google"""
        try:
            result = self.https_get("https://www.google.com")
            
            if result["success"] and 200 <= result.get("status", 0) < 400:
                details = f"Status: {result['status']}, Size: {result['content_length']} bytes, Time: {result['duration_ms']}ms"
                self.log_test("2.1", "HTTPS GET - Google", "pass", details, result['duration_ms'])
            else:
                error = result.get("error", f"Status: {result.get('status', 'unknown')}")
                self.log_test("2.1", "HTTPS GET - Google", "fail", f"Error: {error}")
        except Exception as e:
            self.log_test("2.1", "HTTPS GET - Google", "fail", f"Exception: {str(e)}")
    
    def test_2_2_https_github(self):
        """Test 2.2: HTTPS GET - GitHub"""
        try:
            result = self.https_get("https://www.github.com")
            
            if result["success"] and 200 <= result.get("status", 0) < 400:
                details = f"Status: {result['status']}, Size: {result['content_length']} bytes, Time: {result['duration_ms']}ms"
                self.log_test("2.2", "HTTPS GET - GitHub", "pass", details, result['duration_ms'])
            else:
                error = result.get("error", f"Status: {result.get('status', 'unknown')}")
                self.log_test("2.2", "HTTPS GET - GitHub", "fail", f"Error: {error}")
        except Exception as e:
            self.log_test("2.2", "HTTPS GET - GitHub", "fail", f"Exception: {str(e)}")
    
    def test_2_3_https_python(self):
        """Test 2.3: HTTPS GET - Python.org"""
        try:
            result = self.https_get("https://www.python.org")
            
            if result["success"] and 200 <= result.get("status", 0) < 400:
                details = f"Status: {result['status']}, Size: {result['content_length']} bytes, Time: {result['duration_ms']}ms"
                self.log_test("2.3", "HTTPS GET - Python.org", "pass", details, result['duration_ms'])
            else:
                error = result.get("error", f"Status: {result.get('status', 'unknown')}")
                self.log_test("2.3", "HTTPS GET - Python.org", "fail", f"Error: {error}")
        except Exception as e:
            self.log_test("2.3", "HTTPS GET - Python.org", "fail", f"Exception: {str(e)}")
    
    def test_2_4_https_api(self):
        """Test 2.4: HTTPS GET - API Endpoint"""
        try:
            result = self.https_get("https://api.github.com")
            
            if result["success"] and 200 <= result.get("status", 0) < 400:
                details = f"Status: {result['status']}, JSON API response, Time: {result['duration_ms']}ms"
                self.log_test("2.4", "HTTPS GET - API Endpoint", "pass", details, result['duration_ms'])
            else:
                error = result.get("error", f"Status: {result.get('status', 'unknown')}")
                self.log_test("2.4", "HTTPS GET - API Endpoint", "fail", f"Error: {error}")
        except Exception as e:
            self.log_test("2.4", "HTTPS GET - API Endpoint", "fail", f"Exception: {str(e)}")
    
    def test_2_5_tls_1_2_connection(self):
        """Test 2.5: TLS 1.2 Connection"""
        try:
            hostname = "www.google.com"
            port = 443
            
            # Create TLS 1.2 context
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
            context.minimum_version = ssl.TLSVersion.TLSv1_2
            context.maximum_version = ssl.TLSVersion.TLSv1_2
            context.check_hostname = True
            context.verify_mode = ssl.CERT_REQUIRED
            context.load_verify_locations(cafile="/etc/ssl/certs/ca-certificates.crt")
            
            start = time.time()
            with socket.create_connection((hostname, port), timeout=10) as sock:
                with context.wrap_socket(sock, server_hostname=hostname) as ssock:
                    version = ssock.version()
                    cipher = ssock.cipher()
                    duration = int((time.time() - start) * 1000)
                    
                    print(f"  TLS Version: {version}")
                    print(f"  Cipher: {cipher[0] if cipher else 'unknown'}")
                    
                    if version and "1.2" in version:
                        details = f"TLS {version}, Cipher: {cipher[0]}, Time: {duration}ms"
                        self.log_test("2.5", "TLS 1.2 Connection", "pass", details, duration)
                    else:
                        self.log_test("2.5", "TLS 1.2 Connection", "fail",
                                    f"Expected TLS 1.2, got: {version}")
        except Exception as e:
            self.log_test("2.5", "TLS 1.2 Connection", "fail", f"Exception: {str(e)}")
    
    def test_2_6_tls_1_3_connection(self):
        """Test 2.6: TLS 1.3 Connection"""
        try:
            hostname = "www.cloudflare.com"  # Known to support TLS 1.3
            port = 443
            
            # Create TLS 1.3 context
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
            context.minimum_version = ssl.TLSVersion.TLSv1_3
            context.check_hostname = True
            context.verify_mode = ssl.CERT_REQUIRED
            context.load_verify_locations(cafile="/etc/ssl/certs/ca-certificates.crt")
            
            start = time.time()
            with socket.create_connection((hostname, port), timeout=10) as sock:
                with context.wrap_socket(sock, server_hostname=hostname) as ssock:
                    version = ssock.version()
                    cipher = ssock.cipher()
                    duration = int((time.time() - start) * 1000)
                    
                    print(f"  TLS Version: {version}")
                    print(f"  Cipher: {cipher[0] if cipher else 'unknown'}")
                    
                    if version and "1.3" in version:
                        details = f"TLS {version}, Cipher: {cipher[0]}, Time: {duration}ms"
                        self.log_test("2.6", "TLS 1.3 Connection", "pass", details, duration)
                    else:
                        self.log_test("2.6", "TLS 1.3 Connection", "fail",
                                    f"Expected TLS 1.3, got: {version}")
        except Exception as e:
            # TLS 1.3 might not be supported everywhere, so log but don't fail hard
            self.log_test("2.6", "TLS 1.3 Connection", "fail", f"Exception: {str(e)}")
    
    def test_2_7_certificate_chain(self):
        """Test 2.7: Certificate Chain Validation"""
        try:
            hostname = "www.github.com"
            port = 443
            
            context = ssl.create_default_context()
            context.load_verify_locations(cafile="/etc/ssl/certs/ca-certificates.crt")
            
            start = time.time()
            with socket.create_connection((hostname, port), timeout=10) as sock:
                with context.wrap_socket(sock, server_hostname=hostname) as ssock:
                    cert = ssock.getpeercert()
                    duration = int((time.time() - start) * 1000)
                    
                    # Extract certificate details
                    subject = dict(x[0] for x in cert.get('subject', []))
                    issuer = dict(x[0] for x in cert.get('issuer', []))
                    
                    print(f"  Subject: {subject.get('commonName', 'unknown')}")
                    print(f"  Issuer: {issuer.get('commonName', 'unknown')}")
                    print(f"  Valid from: {cert.get('notBefore', 'unknown')}")
                    print(f"  Valid until: {cert.get('notAfter', 'unknown')}")
                    
                    if cert and subject:
                        details = f"Valid cert chain, CN: {subject.get('commonName')}, Time: {duration}ms"
                        self.log_test("2.7", "Certificate Chain Validation", "pass", details, duration)
                    else:
                        self.log_test("2.7", "Certificate Chain Validation", "fail",
                                    "No certificate retrieved")
        except Exception as e:
            self.log_test("2.7", "Certificate Chain Validation", "fail", f"Exception: {str(e)}")
    
    def test_2_8_concurrent_connections(self):
        """Test 2.8: Concurrent Connections"""
        try:
            urls = [
                "https://www.google.com",
                "https://www.github.com",
                "https://www.python.org",
                "https://www.cloudflare.com",
                "https://www.microsoft.com",
                "https://www.amazon.com",
                "https://www.apple.com",
                "https://www.netflix.com",
                "https://www.wikipedia.org",
                "https://www.reddit.com"
            ]
            
            successful = 0
            failed = 0
            results_list = []
            
            start = time.time()
            with ThreadPoolExecutor(max_workers=10) as executor:
                future_to_url = {executor.submit(self.https_get, url, 15): url for url in urls}
                
                for future in as_completed(future_to_url):
                    url = future_to_url[future]
                    try:
                        result = future.result()
                        if result["success"]:
                            successful += 1
                        else:
                            failed += 1
                        results_list.append((url, result["success"]))
                    except Exception as e:
                        failed += 1
                        results_list.append((url, False))
            
            total_duration = int((time.time() - start) * 1000)
            
            print(f"  Successful connections: {successful}/{len(urls)}")
            print(f"  Failed connections: {failed}/{len(urls)}")
            
            if successful >= 9:  # 9/10 or better
                details = f"{successful}/{len(urls)} connections successful, Total time: {total_duration}ms"
                self.log_test("2.8", "Concurrent Connections", "pass", details, total_duration)
            elif successful >= 7:  # 7-8/10
                details = f"{successful}/{len(urls)} connections successful (acceptable), Total time: {total_duration}ms"
                self.log_test("2.8", "Concurrent Connections", "pass", details, total_duration)
            else:
                details = f"Only {successful}/{len(urls)} connections successful"
                self.log_test("2.8", "Concurrent Connections", "fail", details)
        except Exception as e:
            self.log_test("2.8", "Concurrent Connections", "fail", f"Exception: {str(e)}")
    
    def run_all_tests(self):
        """Run all connectivity tests"""
        print("=" * 60)
        print("Connectivity Tests")
        print("=" * 60)
        print()
        
        self.test_2_1_https_google()
        self.test_2_2_https_github()
        self.test_2_3_https_python()
        self.test_2_4_https_api()
        self.test_2_5_tls_1_2_connection()
        self.test_2_6_tls_1_3_connection()
        self.test_2_7_certificate_chain()
        self.test_2_8_concurrent_connections()
        
        print("=" * 60)
        print("Test Summary")
        print("=" * 60)
        print(f"Total Tests: {self.results['total_tests']}")
        print(f"Passed: {self.results['passed']}")
        print(f"Failed: {self.results['failed']}")
        print(f"Skipped: {self.results['skipped']}")
        
        pass_rate = (self.results['passed'] / self.results['total_tests']) * 100
        print(f"Pass Rate: {pass_rate:.1f}%")
        print()
        
        if self.results['passed'] >= 7:
            print("✅ CONNECTIVITY TESTS PASSED")
            return 0
        elif self.results['passed'] >= 5:
            print("⚠️  PARTIAL SUCCESS (5-6/8 tests passed)")
            return 1
        else:
            print("❌ CRITICAL FAILURE (< 5/8 tests passed)")
            return 2
    
    def save_results(self, filename="results.json"):
        """Save results to JSON file"""
        output_path = os.path.join(os.path.dirname(__file__), filename)
        with open(output_path, 'w') as f:
            json.dump(self.results, f, indent=2)
        print(f"Results saved to: {output_path}")

if __name__ == "__main__":
    tests = ConnectivityTests()
    exit_code = tests.run_all_tests()
    tests.save_results()
    sys.exit(exit_code)

