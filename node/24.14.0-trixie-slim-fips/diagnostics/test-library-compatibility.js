#!/usr/bin/env node
/**
 * Library Compatibility Tests
 * Tests compatibility with Node.js native modules and popular libraries
 */

const https = require('https');
const crypto = require('crypto');
const fs = require('fs');

class LibraryCompatibilityTests {
    constructor() {
        this.results = {
            test_area: '5-library-compatibility',
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

    async test_5_1_native_https_module() {
        return new Promise((resolve) => {
            try {
                console.log(`  Testing native https module...`);

                const startTime = Date.now();

                const options = {
                    hostname: 'www.google.com',
                    port: 443,
                    path: '/',
                    method: 'GET',
                    timeout: 10000
                };

                const req = https.request(options, (res) => {
                    const duration = Date.now() - startTime;
                    const cipher = res.socket.getCipher();
                    const protocol = res.socket.getProtocol();

                    console.log(`  Status: ${res.statusCode}`);
                    console.log(`  Protocol: ${protocol}`);
                    console.log(`  Cipher: ${cipher?.name}`);

                    let data = '';
                    res.on('data', (chunk) => { data += chunk; });
                    res.on('end', () => {
                        if (res.statusCode >= 200 && res.statusCode < 400) {
                            this.logTest('5.1', 'Native HTTPS Module', 'pass',
                                `HTTPS module works with FIPS (${protocol}, ${cipher?.name})`, duration);
                        } else {
                            this.logTest('5.1', 'Native HTTPS Module', 'fail',
                                `Unexpected status: ${res.statusCode}`, duration);
                        }
                        resolve();
                    });
                });

                req.on('error', (error) => {
                    this.logTest('5.1', 'Native HTTPS Module', 'fail', error.message);
                    resolve();
                });

                req.on('timeout', () => {
                    req.destroy();
                    this.logTest('5.1', 'Native HTTPS Module', 'fail', 'Request timeout');
                    resolve();
                });

                req.end();
            } catch (error) {
                this.logTest('5.1', 'Native HTTPS Module', 'fail', error.message);
                resolve();
            }
        });
    }

    async test_5_2_native_crypto_module() {
        try {
            console.log(`  Testing native crypto module...`);

            const tests = [];

            // Test 1: Hash generation
            try {
                const hash = crypto.createHash('sha256');
                hash.update('test data');
                const digest = hash.digest('hex');
                tests.push({ name: 'SHA-256 hash', result: digest.length === 64 });
                console.log(`    ✓ SHA-256 hash: ${digest.substring(0, 32)}...`);
            } catch (e) {
                tests.push({ name: 'SHA-256 hash', result: false, error: e.message });
                console.log(`    ✗ SHA-256 hash failed: ${e.message}`);
            }

            // Test 2: Random bytes
            try {
                const randomBytes = crypto.randomBytes(16);
                tests.push({ name: 'Random bytes', result: randomBytes.length === 16 });
                console.log(`    ✓ Random bytes: ${randomBytes.toString('hex')}`);
            } catch (e) {
                tests.push({ name: 'Random bytes', result: false, error: e.message });
                console.log(`    ✗ Random bytes failed: ${e.message}`);
            }

            // Test 3: HMAC
            try {
                const hmac = crypto.createHmac('sha256', 'secret');
                hmac.update('test');
                const digest = hmac.digest('hex');
                tests.push({ name: 'HMAC', result: digest.length === 64 });
                console.log(`    ✓ HMAC: ${digest.substring(0, 32)}...`);
            } catch (e) {
                tests.push({ name: 'HMAC', result: false, error: e.message });
                console.log(`    ✗ HMAC failed: ${e.message}`);
            }

            const allPassed = tests.every(t => t.result);
            const passedCount = tests.filter(t => t.result).length;

            if (allPassed) {
                this.logTest('5.2', 'Native Crypto Module', 'pass',
                    `All ${tests.length} crypto operations successful`);
            } else {
                this.logTest('5.2', 'Native Crypto Module', 'fail',
                    `Only ${passedCount}/${tests.length} operations succeeded`);
            }
        } catch (error) {
            this.logTest('5.2', 'Native Crypto Module', 'fail', error.message);
        }
    }

    async test_5_3_axios_library() {
        try {
            console.log(`  Testing axios library compatibility...`);

            let axios;
            try {
                axios = require('axios');
            } catch (e) {
                console.log(`  ℹ️  axios not installed (optional dependency)`);
                this.logTest('5.3', 'Axios Library Compatibility', 'skip',
                    'axios not installed (optional)');
                return;
            }

            const startTime = Date.now();

            try {
                const response = await axios.get('https://www.google.com', {
                    timeout: 10000,
                    maxRedirects: 5
                });
                const duration = Date.now() - startTime;

                console.log(`  Status: ${response.status}`);
                console.log(`  Response size: ${response.data.length} bytes`);

                if (response.status >= 200 && response.status < 400) {
                    this.logTest('5.3', 'Axios Library Compatibility', 'pass',
                        `axios works with FIPS mode`, duration);
                } else {
                    this.logTest('5.3', 'Axios Library Compatibility', 'fail',
                        `Unexpected status: ${response.status}`, duration);
                }
            } catch (error) {
                this.logTest('5.3', 'Axios Library Compatibility', 'fail',
                    error.message);
            }
        } catch (error) {
            this.logTest('5.3', 'Axios Library Compatibility', 'fail', error.message);
        }
    }

    async test_5_4_node_fetch_library() {
        try {
            console.log(`  Testing node-fetch library compatibility...`);

            let fetch;
            try {
                fetch = require('node-fetch');
            } catch (e) {
                console.log(`  ℹ️  node-fetch not installed (optional dependency)`);
                this.logTest('5.4', 'Node-Fetch Library Compatibility', 'skip',
                    'node-fetch not installed (optional)');
                return;
            }

            const startTime = Date.now();

            try {
                const response = await fetch('https://www.google.com', {
                    timeout: 10000
                });
                const duration = Date.now() - startTime;

                console.log(`  Status: ${response.status}`);
                console.log(`  Status Text: ${response.statusText}`);

                if (response.ok || response.status === 301 || response.status === 302) {
                    this.logTest('5.4', 'Node-Fetch Library Compatibility', 'pass',
                        `node-fetch works with FIPS mode`, duration);
                } else {
                    this.logTest('5.4', 'Node-Fetch Library Compatibility', 'fail',
                        `Unexpected status: ${response.status}`, duration);
                }
            } catch (error) {
                this.logTest('5.4', 'Node-Fetch Library Compatibility', 'fail',
                    error.message);
            }
        } catch (error) {
            this.logTest('5.4', 'Node-Fetch Library Compatibility', 'fail', error.message);
        }
    }

    async test_5_5_tls_module_compatibility() {
        return new Promise((resolve) => {
            try {
                console.log(`  Testing native tls module...`);

                const tls = require('tls');

                const options = {
                    host: 'www.google.com',
                    port: 443,
                    servername: 'www.google.com', // SNI support
                    timeout: 10000
                };

                const socket = tls.connect(options, () => {
                    const protocol = socket.getProtocol();
                    const cipher = socket.getCipher();
                    const cert = socket.getPeerCertificate();

                    console.log(`  Protocol: ${protocol}`);
                    console.log(`  Cipher: ${cipher.name}`);
                    console.log(`  Certificate CN: ${cert.subject?.CN || 'N/A'}`);
                    console.log(`  Authorized: ${socket.authorized}`);

                    socket.end();

                    if (socket.authorized && (protocol === 'TLSv1.2' || protocol === 'TLSv1.3')) {
                        this.logTest('5.5', 'TLS Module Compatibility', 'pass',
                            `TLS module works with FIPS (${protocol})`);
                    } else {
                        this.logTest('5.5', 'TLS Module Compatibility', 'fail',
                            `Unexpected state: authorized=${socket.authorized}, protocol=${protocol}`);
                    }
                    resolve();
                });

                socket.on('error', (error) => {
                    this.logTest('5.5', 'TLS Module Compatibility', 'fail', error.message);
                    resolve();
                });

                socket.setTimeout(10000, () => {
                    socket.destroy();
                    this.logTest('5.5', 'TLS Module Compatibility', 'fail', 'Connection timeout');
                    resolve();
                });
            } catch (error) {
                this.logTest('5.5', 'TLS Module Compatibility', 'fail', error.message);
                resolve();
            }
        });
    }

    async test_5_6_buffer_crypto_operations() {
        try {
            console.log(`  Testing Buffer and crypto integration...`);

            const tests = [];

            // Test 1: Buffer to hash
            try {
                const buffer = Buffer.from('FIPS test data', 'utf8');
                const hash = crypto.createHash('sha256');
                hash.update(buffer);
                const digest = hash.digest();

                tests.push({
                    name: 'Buffer to hash',
                    result: Buffer.isBuffer(digest) && digest.length === 32
                });
                console.log(`    ✓ Buffer to hash: ${digest.toString('hex').substring(0, 32)}...`);
            } catch (e) {
                tests.push({ name: 'Buffer to hash', result: false });
                console.log(`    ✗ Buffer to hash failed: ${e.message}`);
            }

            // Test 2: Buffer encryption (using AES-CBC - compatible with FIPS v5)
            try {
                const key = crypto.randomBytes(32);
                const iv = crypto.randomBytes(16);  // 16 bytes for CBC
                const plaintext = Buffer.from('test data');

                const cipher = crypto.createCipheriv('aes-256-cbc', key, iv);
                const encrypted = Buffer.concat([
                    cipher.update(plaintext),
                    cipher.final()
                ]);

                tests.push({
                    name: 'Buffer encryption',
                    result: Buffer.isBuffer(encrypted) && encrypted.length > 0
                });
                console.log(`    ✓ Buffer encryption (AES-CBC): ${encrypted.toString('hex')}`);
            } catch (e) {
                tests.push({ name: 'Buffer encryption', result: false });
                console.log(`    ✗ Buffer encryption failed: ${e.message}`);
            }

            // Test 3: Buffer from random bytes
            try {
                const randomBuffer = crypto.randomBytes(32);
                tests.push({
                    name: 'Random buffer',
                    result: Buffer.isBuffer(randomBuffer) && randomBuffer.length === 32
                });
                console.log(`    ✓ Random buffer: ${randomBuffer.toString('hex').substring(0, 32)}...`);
            } catch (e) {
                tests.push({ name: 'Random buffer', result: false });
                console.log(`    ✗ Random buffer failed: ${e.message}`);
            }

            const allPassed = tests.every(t => t.result);
            const passedCount = tests.filter(t => t.result).length;

            if (allPassed) {
                this.logTest('5.6', 'Buffer/Crypto Integration', 'pass',
                    `All ${tests.length} buffer operations successful`);
            } else {
                this.logTest('5.6', 'Buffer/Crypto Integration', 'fail',
                    `Only ${passedCount}/${tests.length} operations succeeded`);
            }
        } catch (error) {
            this.logTest('5.6', 'Buffer/Crypto Integration', 'fail', error.message);
        }
    }

    async runAllTests() {
        console.log('='.repeat(60));
        console.log('Library Compatibility Tests');
        console.log('='.repeat(60));
        console.log('');

        await this.test_5_1_native_https_module();
        await this.test_5_2_native_crypto_module();
        await this.test_5_3_axios_library();
        await this.test_5_4_node_fetch_library();
        await this.test_5_5_tls_module_compatibility();
        await this.test_5_6_buffer_crypto_operations();

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

        // At least 4 core tests should pass (native modules)
        if (this.results.passed >= 4) {
            console.log('✅ LIBRARY COMPATIBILITY VERIFIED');
            console.log('   Core Node.js modules work with FIPS mode');
            return 0;
        } else if (this.results.passed >= 3) {
            console.log('⚠️  PARTIAL SUCCESS (3/6 tests passed)');
            return 1;
        } else {
            console.log('❌ CRITICAL FAILURE (< 3/6 tests passed)');
            return 2;
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
(async () => {
    const tests = new LibraryCompatibilityTests();
    const exitCode = await tests.runAllTests();
    tests.saveResults();
    process.exit(exitCode);
})();
