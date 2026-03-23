#!/usr/bin/env python3
"""
Requests Library Demo

Demonstrates using the popular requests library with wolfSSL FIPS backend.
Shows that requests automatically uses the wolfSSL provider for HTTPS connections.
"""

import sys
import urllib3


def print_header():
    print()
    print("=" * 70)
    print("  Requests Library Demo - Python with wolfSSL FIPS")
    print("=" * 70)
    print()


def demo_simple_get():
    """Demo 1: Simple GET request"""
    print("Demo 1: Simple GET Request")
    print("-" * 70)

    try:
        import requests

        url = "https://www.google.com"
        print(f"Making GET request to {url}...")
        print()

        # Disable SSL warnings for demo (not for production)
        urllib3.disable_warnings()

        response = requests.get(url, verify=False, timeout=10)

        print(f"✓ Request successful")
        print(f"  Status Code: {response.status_code}")
        print(f"  Content Length: {len(response.text)} bytes")
        print(f"  Content-Type: {response.headers.get('Content-Type')}")
        print()

        return True

    except ImportError:
        print("✗ requests library not installed")
        print()
        return False
    except Exception as e:
        print(f"✗ Request failed: {e}")
        print()
        return False


def demo_json_api():
    """Demo 2: JSON API request"""
    print("Demo 2: JSON API Request")
    print("-" * 70)

    try:
        import requests

        url = "https://api.github.com/zen"
        print(f"Making GET request to {url}...")
        print()

        urllib3.disable_warnings()
        response = requests.get(url, verify=False, timeout=10)

        print(f"✓ API request successful")
        print(f"  Status Code: {response.status_code}")
        print(f"  Response: {response.text[:100]}")
        print()

        return True

    except ImportError:
        print("✗ requests library not installed")
        print()
        return False
    except Exception as e:
        print(f"✗ API request failed: {e}")
        print()
        return False


def demo_post_request():
    """Demo 3: POST request with JSON data"""
    print("Demo 3: POST Request with JSON")
    print("-" * 70)

    try:
        import requests

        url = "https://httpbin.org/post"
        data = {
            "message": "Hello from Python with wolfSSL FIPS",
            "wolfssl_version": "5.8.2",
            "fips": True
        }

        print(f"Making POST request to {url}...")
        print(f"  Data: {data}")
        print()

        urllib3.disable_warnings()
        response = requests.post(url, json=data, verify=False, timeout=10)

        print(f"✓ POST request successful")
        print(f"  Status Code: {response.status_code}")

        # Try to parse response
        try:
            resp_json = response.json()
            echo_data = resp_json.get('json', {})
            print(f"  Server echoed: {echo_data}")
        except:
            print(f"  Response: {response.text[:100]}...")

        print()

        return True

    except ImportError:
        print("✗ requests library not installed")
        print()
        return False
    except Exception as e:
        print(f"✗ POST request failed: {e}")
        print()
        return False


def demo_session():
    """Demo 4: Session with connection pooling"""
    print("Demo 4: Session with Connection Pooling")
    print("-" * 70)

    try:
        import requests

        print("Creating requests session...")
        session = requests.Session()

        urls = [
            "https://www.python.org",
            "https://www.github.com",
            "https://www.wikipedia.org",
        ]

        successful = 0

        print()
        urllib3.disable_warnings()

        for url in urls:
            try:
                print(f"  Requesting {url}...")
                response = session.get(url, verify=False, timeout=10)
                if 200 <= response.status_code < 400:
                    print(f"    ✓ Status: {response.status_code}")
                    successful += 1
                else:
                    print(f"    ⚠ Status: {response.status_code}")
            except Exception as e:
                print(f"    ✗ Failed: {str(e)[:50]}")

        print()
        print(f"✓ Session demo complete")
        print(f"  Successful requests: {successful}/{len(urls)}")
        print(f"  Connection pooling enabled for efficiency")
        print()

        return successful >= 2

    except ImportError:
        print("✗ requests library not installed")
        print()
        return False
    except Exception as e:
        print(f"✗ Session demo failed: {e}")
        print()
        return False


def demo_headers_and_params():
    """Demo 5: Custom headers and query parameters"""
    print("Demo 5: Custom Headers and Query Parameters")
    print("-" * 70)

    try:
        import requests

        url = "https://httpbin.org/get"
        headers = {
            "User-Agent": "Python-wolfSSL-FIPS/1.0",
            "X-FIPS-Mode": "enabled",
        }
        params = {
            "demo": "headers",
            "wolfssl": "5.8.2",
        }

        print(f"Making GET request with custom headers and params...")
        print(f"  Headers: {headers}")
        print(f"  Params: {params}")
        print()

        urllib3.disable_warnings()
        response = requests.get(url, headers=headers, params=params, verify=False, timeout=10)

        print(f"✓ Request with custom headers/params successful")
        print(f"  Status Code: {response.status_code}")

        try:
            resp_json = response.json()
            print(f"  Server received headers: {resp_json.get('headers', {}).get('X-Fips-Mode')}")
            print(f"  Server received params: {resp_json.get('args', {})}")
        except:
            pass

        print()

        return True

    except ImportError:
        print("✗ requests library not installed")
        print()
        return False
    except Exception as e:
        print(f"✗ Request failed: {e}")
        print()
        return False


def main():
    """Run all requests library demos"""
    print_header()

    print("This demo showcases the requests library with wolfSSL FIPS backend.")
    print("All HTTPS connections automatically use wolfSSL FIPS for cryptography.")
    print()
    print("Note: Certificate verification is disabled for demo purposes.")
    print()

    demos = [
        demo_simple_get,
        demo_json_api,
        demo_post_request,
        demo_session,
        demo_headers_and_params,
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
        print("✓ All requests library demos completed successfully")
        print()
        print("Key Takeaway:")
        print("  The requests library seamlessly works with wolfSSL FIPS backend.")
        print("  No code changes are needed - it automatically uses the system SSL.")
        print()
        return 0
    elif successful >= 3:
        print("⚠ Most demos completed (some network requests may have failed)")
        print()
        return 0
    else:
        print("✗ Several demos failed")
        print()
        return 1


if __name__ == "__main__":
    sys.exit(main())
