#!/usr/bin/env node
/**
 * FIPS User Application - Main Test Orchestrator
 *
 * This application orchestrates comprehensive testing of Node.js wolfSSL FIPS integration.
 * It runs crypto and TLS test suites and aggregates results.
 */

const CryptoTestSuite = require('./crypto_test_suite');
const TlsTestSuite = require('./tls_test_suite');

class FipsUserApplication {
    constructor() {
        this.startTime = Date.now();
        this.results = {
            timestamp: new Date().toISOString(),
            total_suites: 0,
            passed_suites: 0,
            failed_suites: 0,
            suites: []
        };
    }

    printHeader() {
        console.log('');
        console.log('='.repeat(80));
        console.log('  Node.js wolfSSL FIPS 140-3 User Application Test');
        console.log('  Comprehensive Cryptographic and TLS Test Suite');
        console.log('='.repeat(80));
        console.log('');
    }

    async runSuite(suiteName, SuiteClass) {
        console.log('');
        console.log('='.repeat(80));
        console.log(`  Running: ${suiteName}`);
        console.log('='.repeat(80));
        console.log('');

        try {
            const suite = new SuiteClass();
            const exitCode = await suite.runAllTests();

            const suiteResult = {
                name: suiteName,
                status: exitCode === 0 ? 'PASS' : 'FAIL',
                exit_code: exitCode
            };

            this.results.suites.push(suiteResult);
            this.results.total_suites += 1;

            if (exitCode === 0) {
                this.results.passed_suites += 1;
                console.log(`✓ ${suiteName}: PASSED`);
                console.log('');
                return true;
            } else {
                this.results.failed_suites += 1;
                console.log(`✗ ${suiteName}: FAILED (exit code: ${exitCode})`);
                console.log('');
                return false;
            }
        } catch (error) {
            console.log(`✗ ${suiteName}: EXCEPTION - ${error.message}`);
            console.log('');

            this.results.suites.push({
                name: suiteName,
                status: 'EXCEPTION',
                error: error.message
            });
            this.results.total_suites += 1;
            this.results.failed_suites += 1;
            return false;
        }
    }

    printSummary() {
        const duration = (Date.now() - this.startTime) / 1000;

        console.log('');
        console.log('='.repeat(80));
        console.log('  FINAL TEST SUMMARY');
        console.log('='.repeat(80));
        console.log('');
        console.log(`  Total Test Suites: ${this.results.total_suites}`);
        console.log(`  Passed: ${this.results.passed_suites}`);
        console.log(`  Failed: ${this.results.failed_suites}`);
        console.log(`  Duration: ${duration.toFixed(2)} seconds`);
        console.log('');

        // Print suite results
        for (const suite of this.results.suites) {
            const statusSymbol = suite.status === 'PASS' ? '✓' : '✗';
            console.log(`  ${statusSymbol} ${suite.name}: ${suite.status}`);
        }

        console.log('');

        if (this.results.passed_suites === this.results.total_suites) {
            console.log('  ✓ ALL TESTS PASSED - Node.js wolfSSL FIPS is production ready');
            console.log('');
            return 0;
        } else if (this.results.passed_suites >= this.results.total_suites - 1) {
            console.log('  ⚠  PARTIAL SUCCESS - Review failed tests');
            console.log('');
            return 1;
        } else {
            console.log('  ✗ TESTS FAILED - Node.js wolfSSL FIPS has significant issues');
            console.log('');
            return 2;
        }
    }

    async run() {
        this.printHeader();

        // Run all test suites
        await this.runSuite('Cryptographic Operations Test Suite', CryptoTestSuite);
        await this.runSuite('TLS/SSL Test Suite', TlsTestSuite);

        // Print final summary and return exit code
        return this.printSummary();
    }
}

// Main application entry point
(async () => {
    const app = new FipsUserApplication();
    const exitCode = await app.run();
    process.exit(exitCode);
})();
