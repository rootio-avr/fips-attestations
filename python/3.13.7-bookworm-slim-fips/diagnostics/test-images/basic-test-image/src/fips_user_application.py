#!/usr/bin/env python3
"""
FIPS User Application - Main Test Orchestrator

This application orchestrates comprehensive testing of Python wolfSSL FIPS integration.
It runs crypto and TLS test suites and aggregates results.
"""

import sys
import time
from datetime import datetime, timezone
from crypto_test_suite import CryptoTestSuite
from tls_test_suite import TlsTestSuite


class FipsUserApplication:
    def __init__(self):
        self.start_time = time.time()
        self.results = {
            "timestamp": datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
            "total_suites": 0,
            "passed_suites": 0,
            "failed_suites": 0,
            "suites": []
        }

    def print_header(self):
        """Print application header"""
        print()
        print("=" * 80)
        print("  Python wolfSSL FIPS 140-3 User Application Test")
        print("  Comprehensive Cryptographic and TLS Test Suite")
        print("=" * 80)
        print()

    def run_suite(self, suite_name, suite_class):
        """Run a test suite and record results"""
        print()
        print("=" * 80)
        print(f"  Running: {suite_name}")
        print("=" * 80)
        print()

        try:
            suite = suite_class()
            exit_code = suite.run_all_tests()

            suite_result = {
                "name": suite_name,
                "status": "PASS" if exit_code == 0 else "FAIL",
                "exit_code": exit_code
            }

            self.results["suites"].append(suite_result)
            self.results["total_suites"] += 1

            if exit_code == 0:
                self.results["passed_suites"] += 1
                print(f"\n✓ {suite_name}: PASSED\n")
                return True
            else:
                self.results["failed_suites"] += 1
                print(f"\n✗ {suite_name}: FAILED (exit code: {exit_code})\n")
                return False

        except Exception as e:
            print(f"\n✗ {suite_name}: EXCEPTION - {e}\n")
            self.results["suites"].append({
                "name": suite_name,
                "status": "EXCEPTION",
                "error": str(e)
            })
            self.results["total_suites"] += 1
            self.results["failed_suites"] += 1
            return False

    def print_summary(self):
        """Print final summary"""
        duration = time.time() - self.start_time

        print()
        print("=" * 80)
        print("  FINAL TEST SUMMARY")
        print("=" * 80)
        print()
        print(f"  Total Test Suites: {self.results['total_suites']}")
        print(f"  Passed: {self.results['passed_suites']}")
        print(f"  Failed: {self.results['failed_suites']}")
        print(f"  Duration: {duration:.2f} seconds")
        print()

        # Print suite results
        for suite in self.results["suites"]:
            status_symbol = "✓" if suite["status"] == "PASS" else "✗"
            print(f"  {status_symbol} {suite['name']}: {suite['status']}")

        print()

        if self.results["passed_suites"] == self.results["total_suites"]:
            print("  ✓ ALL TESTS PASSED - Python wolfSSL FIPS is production ready")
            print()
            return 0
        elif self.results["passed_suites"] >= self.results["total_suites"] - 1:
            print("  ⚠ PARTIAL SUCCESS - Review failed tests")
            print()
            return 1
        else:
            print("  ✗ TESTS FAILED - Python wolfSSL FIPS has significant issues")
            print()
            return 2

    def run(self):
        """Main application entry point"""
        self.print_header()

        # Run all test suites
        self.run_suite("Cryptographic Operations Test Suite", CryptoTestSuite)
        self.run_suite("TLS/SSL Test Suite", TlsTestSuite)

        # Print final summary and return exit code
        return self.print_summary()


if __name__ == "__main__":
    app = FipsUserApplication()
    exit_code = app.run()
    sys.exit(exit_code)
