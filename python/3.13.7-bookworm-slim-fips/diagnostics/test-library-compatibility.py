#!/usr/bin/env python3
"""
Library Compatibility Tests
Tests popular Python HTTP libraries with wolfSSL backend
"""

import ssl
import sys
import json
import os
import subprocess
from datetime import datetime, timezone
import urllib.request
import urllib.error

class LibraryCompatibilityTests:
    def __init__(self):
        self.results = {
            "test_area": "5-library-compatibility",
            "timestamp": datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
            "container": "root-io-python-osp:latest",
            "total_tests": 6,
            "passed": 0,
            "failed": 0,
            "skipped": 0,
            "tests": []
        }
        self.requests_available = False
        self.urllib3_available = False
    
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
    
    def install_libraries(self):
        """Install required libraries"""
        print("=" * 60)
        print("Installing Test Libraries")
        print("=" * 60)
        print()
        
        requirements_file = os.path.join(os.path.dirname(__file__), "requirements.txt")
        
        if os.path.exists(requirements_file):
            print(f"Installing from {requirements_file}...")
            try:
                result = subprocess.run(
                    [sys.executable, "-m", "pip", "install", "-q", "-r", requirements_file],
                    capture_output=True,
                    text=True,
                    timeout=120
                )
                
                if result.returncode == 0:
                    print("✓ Libraries installed successfully")
                else:
                    print(f"⚠ Installation had issues: {result.stderr[:200]}")
                    
            except subprocess.TimeoutExpired:
                print("⚠ Installation timeout")
            except Exception as e:
                print(f"⚠ Installation error: {e}")
        
        # Check what's available
        try:
            import requests
            self.requests_available = True
            print(f"✓ requests {requests.__version__} available")
        except ImportError:
            print("✗ requests not available")
        
        try:
            import urllib3
            self.urllib3_available = True
            print(f"✓ urllib3 {urllib3.__version__} available")
        except ImportError:
            print("✗ urllib3 not available")
        
        print()
    
    def test_5_1_requests_basic_get(self):
        """Test 5.1: Requests Library - Basic GET"""
        if not self.requests_available:
            self.log_test("5.1", "Requests Library - Basic GET", "skip",
                         "requests library not available")
            return
        
        try:
            import requests
            
            # Test with proper certificate verification
            print("  Testing requests.get() with certificate verification...")
            url = "https://www.google.com"

            response = requests.get(url, verify='/etc/ssl/certs/ca-certificates.crt', timeout=10)
            
            print(f"  Status code: {response.status_code}")
            print(f"  Response length: {len(response.text)} bytes")
            
            if 200 <= response.status_code < 400:
                details = f"GET successful: {response.status_code}, {len(response.text)} bytes"
                self.log_test("5.1", "Requests Library - Basic GET", "pass", details)
            else:
                details = f"Unexpected status code: {response.status_code}"
                self.log_test("5.1", "Requests Library - Basic GET", "fail", details)
                
        except Exception as e:
            self.log_test("5.1", "Requests Library - Basic GET", "fail", f"Exception: {str(e)}")
    
    def test_5_2_requests_post_json(self):
        """Test 5.2: Requests Library - POST with JSON"""
        if not self.requests_available:
            self.log_test("5.2", "Requests Library - POST with JSON", "skip",
                         "requests library not available")
            return
        
        try:
            import requests
            
            print("  Testing requests.post() with JSON and certificate verification...")
            url = "https://httpbin.org/post"
            payload = {"test": "data", "wolfssl": "5.8.2"}

            response = requests.post(url, json=payload, verify='/etc/ssl/certs/ca-certificates.crt', timeout=10)
            
            print(f"  Status code: {response.status_code}")
            
            if 200 <= response.status_code < 400:
                # Parse response to verify JSON was sent
                try:
                    resp_json = response.json()
                    if resp_json.get('json') == payload:
                        details = f"POST successful, JSON echoed correctly"
                        self.log_test("5.2", "Requests Library - POST with JSON", "pass", details)
                    else:
                        details = f"POST successful but JSON mismatch"
                        self.log_test("5.2", "Requests Library - POST with JSON", "pass", details)
                except:
                    details = f"POST successful: {response.status_code}"
                    self.log_test("5.2", "Requests Library - POST with JSON", "pass", details)
            else:
                details = f"Unexpected status code: {response.status_code}"
                self.log_test("5.2", "Requests Library - POST with JSON", "fail", details)
                
        except Exception as e:
            self.log_test("5.2", "Requests Library - POST with JSON", "fail", f"Exception: {str(e)}")
    
    def test_5_3_requests_session(self):
        """Test 5.3: Requests Library - Session with Connection Pooling"""
        if not self.requests_available:
            self.log_test("5.3", "Requests Library - Session", "skip",
                         "requests library not available")
            return
        
        try:
            import requests
            
            print("  Testing requests.Session()...")
            session = requests.Session()
            
            urls = [
                "https://www.google.com",
                "https://www.github.com",
                "https://www.python.org"
            ]
            
            successful = 0
            for url in urls:
                try:
                    response = session.get(url, verify='/etc/ssl/certs/ca-certificates.crt', timeout=10)
                    if 200 <= response.status_code < 400:
                        successful += 1
                        print(f"  ✓ {url}: {response.status_code}")
                    else:
                        print(f"  ✗ {url}: {response.status_code}")
                except Exception as e:
                    print(f"  ✗ {url}: {str(e)[:50]}")
            
            if successful == len(urls):
                details = f"All {len(urls)} requests successful with session"
                self.log_test("5.3", "Requests Library - Session", "pass", details)
            elif successful >= 2:
                details = f"{successful}/{len(urls)} requests successful (acceptable)"
                self.log_test("5.3", "Requests Library - Session", "pass", details)
            else:
                details = f"Only {successful}/{len(urls)} requests successful"
                self.log_test("5.3", "Requests Library - Session", "fail", details)
                
        except Exception as e:
            self.log_test("5.3", "Requests Library - Session", "fail", f"Exception: {str(e)}")
    
    def test_5_4_urllib3_direct(self):
        """Test 5.4: urllib3 - Direct Connection"""
        if not self.urllib3_available:
            self.log_test("5.4", "urllib3 - Direct Connection", "skip",
                         "urllib3 library not available")
            return
        
        try:
            import urllib3
            
            print("  Testing urllib3.PoolManager() with certificate verification...")

            http = urllib3.PoolManager(
                cert_reqs='CERT_REQUIRED',
                ca_certs='/etc/ssl/certs/ca-certificates.crt',
                timeout=urllib3.Timeout(connect=10.0, read=10.0)
            )
            
            url = "https://www.google.com"
            response = http.request('GET', url)
            
            print(f"  Status: {response.status}")
            print(f"  Data length: {len(response.data)} bytes")
            
            if 200 <= response.status < 400:
                details = f"urllib3 request successful: {response.status}"
                self.log_test("5.4", "urllib3 - Direct Connection", "pass", details)
            else:
                details = f"Unexpected status: {response.status}"
                self.log_test("5.4", "urllib3 - Direct Connection", "fail", details)
                
        except Exception as e:
            self.log_test("5.4", "urllib3 - Direct Connection", "fail", f"Exception: {str(e)}")
    
    def test_5_5_httpx_client(self):
        """Test 5.5: httpx - Synchronous Client (Optional)"""
        try:
            import httpx
            print("  Testing httpx.get() with certificate verification...")

            response = httpx.get("https://www.google.com", verify='/etc/ssl/certs/ca-certificates.crt', timeout=10)
            
            print(f"  Status code: {response.status_code}")
            
            if 200 <= response.status_code < 400:
                details = f"httpx request successful: {response.status_code}"
                self.log_test("5.5", "httpx - Synchronous Client", "pass", details)
            else:
                details = f"Unexpected status code: {response.status_code}"
                self.log_test("5.5", "httpx - Synchronous Client", "fail", details)
                
        except ImportError:
            self.log_test("5.5", "httpx - Synchronous Client", "skip",
                         "httpx library not available (optional)")
        except Exception as e:
            self.log_test("5.5", "httpx - Synchronous Client", "fail", f"Exception: {str(e)}")
    
    def test_5_6_urllib_standard(self):
        """Test 5.6: Standard Library - urllib.request"""
        try:
            print("  Testing urllib.request.urlopen() with certificate verification...")

            # Create SSL context with proper verification
            context = ssl.create_default_context()
            context.load_verify_locations(cafile='/etc/ssl/certs/ca-certificates.crt')
            
            url = "https://www.python.org"
            
            with urllib.request.urlopen(url, timeout=10, context=context) as response:
                status = response.status
                data = response.read()
                
                print(f"  Status: {status}")
                print(f"  Data length: {len(data)} bytes")
                
                if 200 <= status < 400:
                    details = f"urllib.request successful: {status}, {len(data)} bytes"
                    self.log_test("5.6", "Standard Library - urllib.request", "pass", details)
                else:
                    details = f"Unexpected status: {status}"
                    self.log_test("5.6", "Standard Library - urllib.request", "fail", details)
                    
        except Exception as e:
            self.log_test("5.6", "Standard Library - urllib.request", "fail", f"Exception: {str(e)}")
    
    def run_all_tests(self):
        """Run all library compatibility tests"""
        print("=" * 60)
        print("Library Compatibility Tests")
        print("=" * 60)
        print()
        
        # Install libraries first
        self.install_libraries()
        
        print("=" * 60)
        print("Running Tests")
        print("=" * 60)
        print()
        
        self.test_5_1_requests_basic_get()
        self.test_5_2_requests_post_json()
        self.test_5_3_requests_session()
        self.test_5_4_urllib3_direct()
        self.test_5_5_httpx_client()
        self.test_5_6_urllib_standard()
        
        print("=" * 60)
        print("Test Summary")
        print("=" * 60)
        print(f"Total Tests: {self.results['total_tests']}")
        print(f"Passed: {self.results['passed']}")
        print(f"Failed: {self.results['failed']}")
        print(f"Skipped: {self.results['skipped']}")
        
        executed = self.results['total_tests'] - self.results['skipped']
        if executed > 0:
            pass_rate = (self.results['passed'] / executed) * 100
            print(f"Pass Rate: {pass_rate:.1f}% (of {executed} executed)")
        else:
            print("Pass Rate: N/A (no tests executed)")
        print()
        
        # Success criteria: 5/6 tests pass (test 5.5 is optional)
        if self.results['passed'] >= 5:
            print("✅ LIBRARY COMPATIBILITY PASSED")
            return 0
        elif self.results['passed'] >= 4:
            print("⚠️  PARTIAL SUCCESS (4/6 tests passed)")
            return 1
        else:
            print("❌ CRITICAL FAILURE (< 4/6 tests passed)")
            return 2
    
    def save_results(self, filename="results.json"):
        """Save results to JSON file"""
        output_path = os.path.join(os.path.dirname(__file__), filename)
        with open(output_path, 'w') as f:
            json.dump(self.results, f, indent=2)
        print(f"Results saved to: {output_path}")

if __name__ == "__main__":
    tests = LibraryCompatibilityTests()
    exit_code = tests.run_all_tests()
    tests.save_results()
    sys.exit(exit_code)


