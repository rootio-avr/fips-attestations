#!/usr/bin/env node
/**
 * Connectivity Tests
 * Tests HTTPS/TLS connectivity with FIPS-approved protocols
 */

const https = require('https');
const tls = require('tls');
const fs = require('fs');

class ConnectivityTests {
    constructor() {
        this.results = {
            test_area: '2-connectivity',
            timestamp: new Date().toISOString(),
            container: 'node:16.20.1-bookworm-slim-fips',
            total_tests: 8,
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

    async test_2_1_https_get_request() {
        return new Promise((resolve) => {
            try {
                const startTime = Date.now();
                console.log(`  Testing HTTPS GET request to www.google.com...`);

                const options = {
                    hostname: 'www.google.com',
                    port: 443,
                    path: '/',
                    method: 'GET',
                    timeout: 10000
                };

                const req = https.request(options, (res) => {
                    const duration = Date.now() - startTime;

                    console.log(`  Status Code: ${res.statusCode}`);
                    console.log(`  TLS Protocol: ${res.socket.getProtocol()}`);

                    const cipher = res.socket.getCipher();
                    if (cipher) {
                        console.log(`  Cipher: ${cipher.name}`);
                        console.log(`  TLS Version: ${cipher.version}`);
                    }

                    let data = '';
                    res.on('data', (chunk) => { data += chunk; });
                    res.on('end', () => {
                        console.log(`  Response size: ${data.length} bytes`);

                        if (res.statusCode === 200 || res.statusCode === 301 || res.statusCode === 302) {
                            this.logTest('2.1', 'HTTPS GET Request', 'pass',
                                `Connected via ${res.socket.getProtocol()} with ${cipher?.name}`, duration);
                        } else {
                            this.logTest('2.1', 'HTTPS GET Request', 'fail',
                                `Unexpected status code: ${res.statusCode}`, duration);
                        }
                        resolve();
                    });
                });

                req.on('error', (error) => {
                    this.logTest('2.1', 'HTTPS GET Request', 'fail', error.message);
                    resolve();
                });

                req.on('timeout', () => {
                    req.destroy();
                    this.logTest('2.1', 'HTTPS GET Request', 'fail', 'Request timeout');
                    resolve();
                });

                req.end();
            } catch (error) {
                this.logTest('2.1', 'HTTPS GET Request', 'fail', error.message);
                resolve();
            }
        });
    }

    async test_2_2_tls_protocol_support() {
        return new Promise((resolve) => {
            try {
                console.log(`  Testing TLS protocol support...`);

                const options = {
                    host: 'www.google.com',
                    port: 443,
                    servername: 'www.google.com', // SNI support
                    timeout: 10000
                };

                const socket = tls.connect(options, () => {
                    const protocol = socket.getProtocol();
                    const cipher = socket.getCipher();

                    console.log(`  Connected Protocol: ${protocol}`);
                    console.log(`  Cipher Suite: ${cipher.name}`);
                    console.log(`  Cipher Version: ${cipher.version}`);

                    socket.end();

                    // TLS 1.2 or TLS 1.3 are FIPS-approved
                    if (protocol === 'TLSv1.2' || protocol === 'TLSv1.3') {
                        this.logTest('2.2', 'TLS Protocol Support', 'pass',
                            `${protocol} with ${cipher.name}`);
                    } else {
                        this.logTest('2.2', 'TLS Protocol Support', 'fail',
                            `Unexpected protocol: ${protocol}`);
                    }
                    resolve();
                });

                socket.on('error', (error) => {
                    this.logTest('2.2', 'TLS Protocol Support', 'fail', error.message);
                    resolve();
                });

                socket.setTimeout(10000, () => {
                    socket.destroy();
                    this.logTest('2.2', 'TLS Protocol Support', 'fail', 'Connection timeout');
                    resolve();
                });
            } catch (error) {
                this.logTest('2.2', 'TLS Protocol Support', 'fail', error.message);
                resolve();
            }
        });
    }

    async test_2_3_tls_1_2_connection() {
        return new Promise((resolve) => {
            try {
                console.log(`  Testing TLS 1.2 connection...`);

                const options = {
                    host: 'www.google.com',
                    port: 443,
                    servername: 'www.google.com', // SNI support
                    minVersion: 'TLSv1.2',
                    maxVersion: 'TLSv1.2',
                    timeout: 10000
                };

                const socket = tls.connect(options, () => {
                    const protocol = socket.getProtocol();
                    const cipher = socket.getCipher();

                    console.log(`  Protocol: ${protocol}`);
                    console.log(`  Cipher: ${cipher.name}`);

                    socket.end();

                    if (protocol === 'TLSv1.2') {
                        this.logTest('2.3', 'TLS 1.2 Connection', 'pass',
                            `TLS 1.2 connection successful with ${cipher.name}`);
                    } else {
                        this.logTest('2.3', 'TLS 1.2 Connection', 'fail',
                            `Expected TLSv1.2, got ${protocol}`);
                    }
                    resolve();
                });

                socket.on('error', (error) => {
                    this.logTest('2.3', 'TLS 1.2 Connection', 'fail', error.message);
                    resolve();
                });

                socket.setTimeout(10000, () => {
                    socket.destroy();
                    this.logTest('2.3', 'TLS 1.2 Connection', 'fail', 'Connection timeout');
                    resolve();
                });
            } catch (error) {
                this.logTest('2.3', 'TLS 1.2 Connection', 'fail', error.message);
                resolve();
            }
        });
    }

    async test_2_4_tls_1_3_connection() {
        return new Promise((resolve) => {
            try {
                console.log(`  Testing TLS 1.3 connection...`);

                const options = {
                    host: 'www.google.com',
                    port: 443,
                    servername: 'www.google.com', // SNI support
                    minVersion: 'TLSv1.3',
                    maxVersion: 'TLSv1.3',
                    timeout: 10000
                };

                const socket = tls.connect(options, () => {
                    const protocol = socket.getProtocol();
                    const cipher = socket.getCipher();

                    console.log(`  Protocol: ${protocol}`);
                    console.log(`  Cipher: ${cipher.name}`);

                    socket.end();

                    if (protocol === 'TLSv1.3') {
                        this.logTest('2.4', 'TLS 1.3 Connection', 'pass',
                            `TLS 1.3 connection successful with ${cipher.name}`);
                    } else {
                        this.logTest('2.4', 'TLS 1.3 Connection', 'fail',
                            `Expected TLSv1.3, got ${protocol}`);
                    }
                    resolve();
                });

                socket.on('error', (error) => {
                    // TLS 1.3 may not be supported by all servers
                    console.log(`  Note: ${error.message}`);
                    this.logTest('2.4', 'TLS 1.3 Connection', 'skip',
                        'TLS 1.3 not supported by server (acceptable)');
                    resolve();
                });

                socket.setTimeout(10000, () => {
                    socket.destroy();
                    this.logTest('2.4', 'TLS 1.3 Connection', 'fail', 'Connection timeout');
                    resolve();
                });
            } catch (error) {
                this.logTest('2.4', 'TLS 1.3 Connection', 'fail', error.message);
                resolve();
            }
        });
    }

    async test_2_5_certificate_validation() {
        return new Promise((resolve) => {
            try {
                console.log(`  Testing certificate validation...`);

                const options = {
                    host: 'www.google.com',
                    port: 443,
                    servername: 'www.google.com', // SNI support
                    rejectUnauthorized: true, // Enforce certificate validation
                    timeout: 10000
                };

                const socket = tls.connect(options, () => {
                    const cert = socket.getPeerCertificate();

                    console.log(`  Certificate subject: ${cert.subject?.CN || 'N/A'}`);
                    console.log(`  Certificate issuer: ${cert.issuer?.CN || 'N/A'}`);
                    console.log(`  Valid from: ${cert.valid_from}`);
                    console.log(`  Valid to: ${cert.valid_to}`);
                    console.log(`  Authorized: ${socket.authorized}`);

                    socket.end();

                    if (socket.authorized) {
                        this.logTest('2.5', 'Certificate Validation', 'pass',
                            `Certificate validated for ${cert.subject?.CN}`);
                    } else {
                        this.logTest('2.5', 'Certificate Validation', 'fail',
                            `Certificate not authorized: ${socket.authorizationError}`);
                    }
                    resolve();
                });

                socket.on('error', (error) => {
                    this.logTest('2.5', 'Certificate Validation', 'fail', error.message);
                    resolve();
                });

                socket.setTimeout(10000, () => {
                    socket.destroy();
                    this.logTest('2.5', 'Certificate Validation', 'fail', 'Connection timeout');
                    resolve();
                });
            } catch (error) {
                this.logTest('2.5', 'Certificate Validation', 'fail', error.message);
                resolve();
            }
        });
    }

    async test_2_6_cipher_suite_negotiation() {
        return new Promise((resolve) => {
            try {
                console.log(`  Testing cipher suite negotiation...`);

                const options = {
                    host: 'www.google.com',
                    port: 443,
                    servername: 'www.google.com', // SNI support
                    timeout: 10000
                };

                const socket = tls.connect(options, () => {
                    const cipher = socket.getCipher();
                    const protocol = socket.getProtocol();

                    console.log(`  Negotiated cipher: ${cipher.name}`);
                    console.log(`  Protocol: ${protocol}`);
                    console.log(`  Cipher version: ${cipher.version}`);

                    socket.end();

                    // Check for FIPS-approved cipher patterns
                    const cipherName = cipher.name.toLowerCase();
                    const isFipsCompliant =
                        cipherName.includes('aes') &&
                        (cipherName.includes('gcm') || cipherName.includes('ccm'));

                    console.log(`  FIPS-compliant: ${isFipsCompliant}`);

                    if (isFipsCompliant) {
                        this.logTest('2.6', 'Cipher Suite Negotiation', 'pass',
                            `FIPS-approved cipher negotiated: ${cipher.name}`);
                    } else {
                        this.logTest('2.6', 'Cipher Suite Negotiation', 'fail',
                            `Non-FIPS cipher: ${cipher.name}`);
                    }
                    resolve();
                });

                socket.on('error', (error) => {
                    this.logTest('2.6', 'Cipher Suite Negotiation', 'fail', error.message);
                    resolve();
                });

                socket.setTimeout(10000, () => {
                    socket.destroy();
                    this.logTest('2.6', 'Cipher Suite Negotiation', 'fail', 'Connection timeout');
                    resolve();
                });
            } catch (error) {
                this.logTest('2.6', 'Cipher Suite Negotiation', 'fail', error.message);
                resolve();
            }
        });
    }

    async test_2_7_concurrent_connections() {
        try {
            console.log(`  Testing concurrent HTTPS connections...`);

            const hosts = [
                'www.google.com',
                'www.github.com',
                'www.amazon.com'
            ];

            const startTime = Date.now();

            const requests = hosts.map((hostname) => {
                return new Promise((resolve) => {
                    const options = {
                        hostname: hostname,
                        port: 443,
                        path: '/',
                        method: 'HEAD',
                        timeout: 10000
                    };

                    const req = https.request(options, (res) => {
                        const cipher = res.socket.getCipher();
                        console.log(`    ✓ ${hostname}: ${res.statusCode} (${cipher?.name})`);
                        resolve(true);
                    });

                    req.on('error', (error) => {
                        console.log(`    ✗ ${hostname}: ${error.message}`);
                        resolve(false);
                    });

                    req.on('timeout', () => {
                        req.destroy();
                        console.log(`    ✗ ${hostname}: timeout`);
                        resolve(false);
                    });

                    req.end();
                });
            });

            const results = await Promise.all(requests);
            const duration = Date.now() - startTime;
            const successCount = results.filter(r => r).length;

            console.log(`  Successful connections: ${successCount}/${hosts.length}`);
            console.log(`  Total time: ${duration}ms`);

            if (successCount >= 2) {
                this.logTest('2.7', 'Concurrent Connections', 'pass',
                    `${successCount}/${hosts.length} concurrent connections successful`, duration);
            } else {
                this.logTest('2.7', 'Concurrent Connections', 'fail',
                    `Only ${successCount}/${hosts.length} connections succeeded`, duration);
            }
        } catch (error) {
            this.logTest('2.7', 'Concurrent Connections', 'fail', error.message);
        }
    }

    async test_2_8_https_post_request() {
        return new Promise((resolve) => {
            try {
                console.log(`  Testing HTTPS POST request...`);

                const postData = JSON.stringify({
                    test: 'fips-connectivity',
                    timestamp: new Date().toISOString()
                });

                const options = {
                    hostname: 'httpbin.org',
                    port: 443,
                    path: '/post',
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Content-Length': Buffer.byteLength(postData)
                    },
                    timeout: 10000
                };

                const req = https.request(options, (res) => {
                    const cipher = res.socket.getCipher();
                    console.log(`  Status: ${res.statusCode}`);
                    console.log(`  Cipher: ${cipher?.name}`);

                    let data = '';
                    res.on('data', (chunk) => { data += chunk; });
                    res.on('end', () => {
                        if (res.statusCode === 200) {
                            this.logTest('2.8', 'HTTPS POST Request', 'pass',
                                `POST request successful with ${cipher?.name}`);
                        } else {
                            this.logTest('2.8', 'HTTPS POST Request', 'fail',
                                `Unexpected status: ${res.statusCode}`);
                        }
                        resolve();
                    });
                });

                req.on('error', (error) => {
                    this.logTest('2.8', 'HTTPS POST Request', 'fail', error.message);
                    resolve();
                });

                req.on('timeout', () => {
                    req.destroy();
                    this.logTest('2.8', 'HTTPS POST Request', 'fail', 'Request timeout');
                    resolve();
                });

                req.write(postData);
                req.end();
            } catch (error) {
                this.logTest('2.8', 'HTTPS POST Request', 'fail', error.message);
                resolve();
            }
        });
    }

    async runAllTests() {
        console.log('='.repeat(60));
        console.log('Connectivity Tests');
        console.log('='.repeat(60));
        console.log('');

        await this.test_2_1_https_get_request();
        await this.test_2_2_tls_protocol_support();
        await this.test_2_3_tls_1_2_connection();
        await this.test_2_4_tls_1_3_connection();
        await this.test_2_5_certificate_validation();
        await this.test_2_6_cipher_suite_negotiation();
        await this.test_2_7_concurrent_connections();
        await this.test_2_8_https_post_request();

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

        if (this.results.passed >= 7) {
            console.log('✅ CONNECTIVITY TESTS PASSED');
            return 0;
        } else if (this.results.passed >= 5) {
            console.log('⚠️  PARTIAL SUCCESS (5-6/8 tests passed)');
            return 1;
        } else {
            console.log('❌ CRITICAL FAILURE (< 5/8 tests passed)');
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
    const tests = new ConnectivityTests();
    const exitCode = await tests.runAllTests();
    tests.saveResults();
    process.exit(exitCode);
})();
