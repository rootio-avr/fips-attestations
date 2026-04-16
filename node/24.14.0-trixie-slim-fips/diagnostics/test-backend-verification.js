#!/usr/bin/env node
/**
 * Backend Verification Tests
 * Tests Node.js SSL module backend integration with wolfSSL FIPS
 */

const crypto = require('crypto');
const fs = require('fs');
const { execSync } = require('child_process');
const os = require('os');

class BackendVerificationTests {
    constructor() {
        this.results = {
            test_area: '1-backend-verification',
            timestamp: new Date().toISOString(),
            container: 'node:24.14.0-trixie-slim-fips',
            total_tests: 6,
            passed: 0,
            failed: 0,
            skipped: 0,
            tests: []
        };
    }

    logTest(testId, name, status, details = '', durationMs = 0) {
        const testResult = {
            id: testId,
            name: name,
            status: status,
            duration_ms: durationMs,
            details: details
        };
        this.results.tests.push(testResult);

        const symbols = { pass: '✅', fail: '❌', skip: '⏭️' };
        console.log(`${symbols[status]} ${testId} ${name}: ${status.toUpperCase()}`);
        if (details) {
            console.log(`   Details: ${details}`);
        }
        console.log('');

        if (status === 'pass') this.results.passed++;
        else if (status === 'fail') this.results.failed++;
        else this.results.skipped++;
    }

    test_1_1_node_version() {
        try {
            const version = process.version;
            const expected = 'v24.14';

            console.log(`  Node.js version: ${version}`);

            if (version.startsWith(expected)) {
                this.logTest('1.1', 'Node.js Version Reporting', 'pass',
                    `Node.js ${version}`);
            } else {
                this.logTest('1.1', 'Node.js Version Reporting', 'fail',
                    `Expected ${expected}.x, got ${version}`);
            }
        } catch (error) {
            this.logTest('1.1', 'Node.js Version Reporting', 'fail', error.message);
        }
    }

    test_1_2_wolfssl_libraries() {
        try {
            const libraries = [
                '/usr/local/lib/libwolfssl.so',
                '/usr/local/openssl/lib64/ossl-modules/libwolfprov.so'
            ];

            const found = [];
            const missing = [];

            for (const lib of libraries) {
                if (fs.existsSync(lib)) {
                    found.push(lib);
                    // Get file size
                    const stats = fs.statSync(lib);
                    console.log(`  ✓ ${lib} (${(stats.size / 1024).toFixed(0)} KB)`);
                } else {
                    missing.push(lib);
                    console.log(`  ✗ ${lib} not found`);
                }
            }

            if (missing.length === 0) {
                this.logTest('1.2', 'wolfSSL Libraries Present', 'pass',
                    `All libraries found: ${found.join(', ')}`);
            } else {
                this.logTest('1.2', 'wolfSSL Libraries Present', 'fail',
                    `Missing libraries: ${missing.join(', ')}`);
            }
        } catch (error) {
            this.logTest('1.2', 'wolfSSL Libraries Present', 'fail', error.message);
        }
    }

    test_1_3_openssl_configuration() {
        try {
            const configPath = process.env.OPENSSL_CONF || '/etc/ssl/openssl.cnf';

            console.log(`  Config path: ${configPath}`);

            if (!fs.existsSync(configPath)) {
                this.logTest('1.3', 'OpenSSL Configuration', 'fail',
                    `Config file not found: ${configPath}`);
                return;
            }

            const config = fs.readFileSync(configPath, 'utf-8');

            const checks = {
                hasWolfProvider: config.includes('libwolfprov'),
                hasFipsProperty: config.includes('fips=yes'),
                hasProviderSection: config.includes('[provider_sect]')
            };

            console.log(`  ✓ wolfProvider configured: ${checks.hasWolfProvider}`);
            console.log(`  ✓ FIPS property set: ${checks.hasFipsProperty}`);
            console.log(`  ✓ Provider section: ${checks.hasProviderSection}`);

            if (checks.hasWolfProvider && checks.hasFipsProperty && checks.hasProviderSection) {
                this.logTest('1.3', 'OpenSSL Configuration', 'pass',
                    'wolfProvider and FIPS mode configured correctly');
            } else {
                this.logTest('1.3', 'OpenSSL Configuration', 'fail',
                    `Missing configuration: ${JSON.stringify(checks)}`);
            }
        } catch (error) {
            this.logTest('1.3', 'OpenSSL Configuration', 'fail', error.message);
        }
    }

    test_1_4_crypto_module_capabilities() {
        try {
            const capabilities = {
                hashes: crypto.getHashes().length,
                ciphers: crypto.getCiphers().length
            };

            console.log(`  Available hashes: ${capabilities.hashes}`);
            console.log(`  Available ciphers: ${capabilities.ciphers}`);

            // Check for specific FIPS-approved algorithms
            const hashes = crypto.getHashes();
            const hasSHA256 = hashes.includes('sha256');
            const hasSHA384 = hashes.includes('sha384');
            const hasSHA512 = hashes.includes('sha512');

            console.log(`  ✓ SHA-256: ${hasSHA256}`);
            console.log(`  ✓ SHA-384: ${hasSHA384}`);
            console.log(`  ✓ SHA-512: ${hasSHA512}`);

            if (hasSHA256 && hasSHA384 && hasSHA512) {
                this.logTest('1.4', 'Crypto Module Capabilities', 'pass',
                    `FIPS-approved algorithms available: ${capabilities.hashes} hashes, ${capabilities.ciphers} ciphers`);
            } else {
                this.logTest('1.4', 'Crypto Module Capabilities', 'fail',
                    'Missing FIPS-approved hash algorithms');
            }
        } catch (error) {
            this.logTest('1.4', 'Crypto Module Capabilities', 'fail', error.message);
        }
    }

    test_1_5_available_ciphers() {
        try {
            const ciphers = crypto.getCiphers();

            // Check for FIPS-approved ciphers
            const aesGcmCiphers = ciphers.filter(c =>
                c.includes('aes') && c.includes('gcm')
            );

            console.log(`  Total cipher suites: ${ciphers.length}`);
            console.log(`  AES-GCM ciphers: ${aesGcmCiphers.length}`);

            if (aesGcmCiphers.length > 0) {
                console.log(`  Sample ciphers: ${aesGcmCiphers.slice(0, 3).join(', ')}`);
            }

            if (aesGcmCiphers.length >= 3) {
                this.logTest('1.5', 'Available Ciphers', 'pass',
                    `${aesGcmCiphers.length} AES-GCM cipher variants available`);
            } else {
                this.logTest('1.5', 'Available Ciphers', 'fail',
                    `Only ${aesGcmCiphers.length} AES-GCM ciphers found`);
            }
        } catch (error) {
            this.logTest('1.5', 'Available Ciphers', 'fail', error.message);
        }
    }

    test_1_6_environment_variables() {
        try {
            const requiredEnvVars = {
                'OPENSSL_CONF': process.env.OPENSSL_CONF,
                'OPENSSL_MODULES': process.env.OPENSSL_MODULES
            };

            console.log(`  OPENSSL_CONF: ${requiredEnvVars.OPENSSL_CONF || '(not set)'}`);
            console.log(`  OPENSSL_MODULES: ${requiredEnvVars.OPENSSL_MODULES || '(not set)'}`);

            const allSet = Object.values(requiredEnvVars).every(v => v);

            if (allSet) {
                this.logTest('1.6', 'Environment Variables', 'pass',
                    'All required environment variables set correctly');
            } else {
                this.logTest('1.6', 'Environment Variables', 'fail',
                    'Missing required environment variables');
            }
        } catch (error) {
            this.logTest('1.6', 'Environment Variables', 'fail', error.message);
        }
    }

    runAllTests() {
        console.log('='.repeat(60));
        console.log('Backend Verification Tests');
        console.log('Architecture: Provider-based (wolfProvider)');
        console.log('='.repeat(60));
        console.log('');

        this.test_1_1_node_version();
        this.test_1_2_wolfssl_libraries();
        this.test_1_3_openssl_configuration();
        this.test_1_4_crypto_module_capabilities();
        this.test_1_5_available_ciphers();
        this.test_1_6_environment_variables();

        console.log('='.repeat(60));
        console.log('Test Summary');
        console.log('='.repeat(60));
        console.log(`Total Tests: ${this.results.total_tests}`);
        console.log(`Passed: ${this.results.passed}`);
        console.log(`Failed: ${this.results.failed}`);
        console.log(`Skipped: ${this.results.skipped}`);

        const passRate = (this.results.passed / this.results.total_tests * 100).toFixed(1);
        console.log(`Pass Rate: ${passRate}%`);
        console.log('');

        if (this.results.passed === this.results.total_tests) {
            console.log('✅ ALL TESTS PASSED');
            console.log('   Provider-based architecture verified successfully');
            return 0;
        } else {
            console.log('❌ SOME TESTS FAILED');
            return 1;
        }
    }

    saveResults(filename = 'results.json') {
        try {
            fs.writeFileSync(filename, JSON.stringify(this.results, null, 2));
            console.log(`Results saved to: ${filename}`);
        } catch (error) {
            console.error(`Failed to save results: ${error.message}`);
        }
    }
}

// Run the tests
const tests = new BackendVerificationTests();
const exitCode = tests.runAllTests();
tests.saveResults();
process.exit(exitCode);
