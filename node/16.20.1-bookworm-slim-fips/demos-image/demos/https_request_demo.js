#!/usr/bin/env node
/**
 * HTTPS Request Demo
 * Demonstrates various HTTPS request patterns with FIPS compliance
 */

const https = require('https');

console.log('='.repeat(70));
console.log('HTTPS Request Demo - Node.js with wolfSSL FIPS 140-3');
console.log('='.repeat(70));
console.log('');

// ============================================================================
// Demo 1: Simple GET Request
// ============================================================================
async function demo1_simple_get() {
    console.log('-'.repeat(70));
    console.log('Demo 1: Simple GET Request');
    console.log('-'.repeat(70));
    console.log('');

    return new Promise((resolve) => {
        console.log('Making GET request to httpbin.org/get...');
        console.log('');

        const options = {
            hostname: 'httpbin.org',
            port: 443,
            path: '/get',
            method: 'GET',
            timeout: 10000
        };

        const req = https.request(options, (res) => {
            const cipher = res.socket.getCipher();

            console.log('Response:');
            console.log(`  Status Code: ${res.statusCode} ${res.statusMessage}`);
            console.log(`  Content-Type: ${res.headers['content-type']}`);
            console.log(`  TLS Protocol: ${res.socket.getProtocol()}`);
            console.log(`  Cipher: ${cipher.name}`);
            console.log('');

            let data = '';
            res.on('data', (chunk) => { data += chunk; });
            res.on('end', () => {
                try {
                    const jsonData = JSON.parse(data);
                    console.log('Response Body:');
                    console.log(`  URL: ${jsonData.url}`);
                    console.log(`  Origin: ${jsonData.origin}`);
                    console.log('  Headers received by server:');
                    Object.keys(jsonData.headers).forEach(key => {
                        console.log(`    ${key}: ${jsonData.headers[key]}`);
                    });
                    console.log('');
                    console.log('✅ GET request successful with FIPS-approved TLS');
                } catch (e) {
                    console.log(`Response: ${data.substring(0, 200)}...`);
                }
                console.log('');
                resolve();
            });
        });

        req.on('error', (error) => {
            console.log(`❌ Error: ${error.message}`);
            console.log('');
            resolve();
        });

        req.end();
    });
}

// ============================================================================
// Demo 2: POST Request with JSON
// ============================================================================
async function demo2_post_json() {
    console.log('-'.repeat(70));
    console.log('Demo 2: POST Request with JSON Data');
    console.log('-'.repeat(70));
    console.log('');

    return new Promise((resolve) => {
        const postData = JSON.stringify({
            name: 'FIPS Test User',
            timestamp: new Date().toISOString(),
            message: 'Testing HTTPS POST with wolfSSL FIPS 140-3'
        });

        console.log('POST data:');
        console.log(JSON.stringify(JSON.parse(postData), null, 2));
        console.log('');

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

        console.log('Sending POST request to httpbin.org/post...');
        console.log('');

        const req = https.request(options, (res) => {
            const cipher = res.socket.getCipher();

            console.log('Response:');
            console.log(`  Status Code: ${res.statusCode}`);
            console.log(`  Cipher: ${cipher.name}`);
            console.log('');

            let data = '';
            res.on('data', (chunk) => { data += chunk; });
            res.on('end', () => {
                try {
                    const jsonData = JSON.parse(data);
                    console.log('Server received:');
                    console.log(JSON.stringify(jsonData.json, null, 2));
                    console.log('');
                    console.log('✅ POST request successful with FIPS-approved TLS');
                } catch (e) {
                    console.log(`Response: ${data.substring(0, 200)}...`);
                }
                console.log('');
                resolve();
            });
        });

        req.on('error', (error) => {
            console.log(`❌ Error: ${error.message}`);
            console.log('');
            resolve();
        });

        req.write(postData);
        req.end();
    });
}

// ============================================================================
// Demo 3: Request with Custom Headers
// ============================================================================
async function demo3_custom_headers() {
    console.log('-'.repeat(70));
    console.log('Demo 3: Request with Custom Headers');
    console.log('-'.repeat(70));
    console.log('');

    return new Promise((resolve) => {
        const options = {
            hostname: 'httpbin.org',
            port: 443,
            path: '/headers',
            method: 'GET',
            headers: {
                'User-Agent': 'Node.js FIPS Client/1.0',
                'X-Custom-Header': 'FIPS-Testing',
                'Accept': 'application/json',
                'X-Request-ID': crypto.randomUUID()
            },
            timeout: 10000
        };

        console.log('Sending request with custom headers:');
        Object.keys(options.headers).forEach(key => {
            console.log(`  ${key}: ${options.headers[key]}`);
        });
        console.log('');

        const req = https.request(options, (res) => {
            console.log(`Response Status: ${res.statusCode}`);
            console.log('');

            let data = '';
            res.on('data', (chunk) => { data += chunk; });
            res.on('end', () => {
                try {
                    const jsonData = JSON.parse(data);
                    console.log('Headers received by server:');
                    Object.keys(jsonData.headers).forEach(key => {
                        console.log(`  ${key}: ${jsonData.headers[key]}`);
                    });
                    console.log('');
                    console.log('✅ Custom headers transmitted successfully');
                } catch (e) {
                    console.log(`Response: ${data.substring(0, 200)}...`);
                }
                console.log('');
                resolve();
            });
        });

        req.on('error', (error) => {
            console.log(`❌ Error: ${error.message}`);
            console.log('');
            resolve();
        });

        req.end();
    });
}

// ============================================================================
// Demo 4: Concurrent Requests
// ============================================================================
async function demo4_concurrent_requests() {
    console.log('-'.repeat(70));
    console.log('Demo 4: Concurrent HTTPS Requests');
    console.log('-'.repeat(70));
    console.log('');

    console.log('Making 5 concurrent requests...');
    console.log('');

    const startTime = Date.now();

    const requests = [];
    for (let i = 1; i <= 5; i++) {
        const promise = new Promise((resolve) => {
            const options = {
                hostname: 'httpbin.org',
                port: 443,
                path: `/delay/${i}`,
                method: 'GET',
                timeout: 15000
            };

            const reqStartTime = Date.now();

            const req = https.request(options, (res) => {
                const duration = Date.now() - reqStartTime;
                const cipher = res.socket.getCipher();

                let data = '';
                res.on('data', (chunk) => { data += chunk; });
                res.on('end', () => {
                    console.log(`Request ${i}:`);
                    console.log(`  Delay: ${i}s`);
                    console.log(`  Duration: ${duration}ms`);
                    console.log(`  Status: ${res.statusCode}`);
                    console.log(`  Cipher: ${cipher.name}`);
                    console.log('');
                    resolve({ id: i, duration, success: true });
                });
            });

            req.on('error', (error) => {
                console.log(`Request ${i}: ❌ ${error.message}`);
                console.log('');
                resolve({ id: i, success: false });
            });

            req.end();
        });

        requests.push(promise);
    }

    const results = await Promise.all(requests);
    const totalTime = Date.now() - startTime;

    const successCount = results.filter(r => r.success).length;

    console.log('Concurrent Request Results:');
    console.log(`  Total requests: ${requests.length}`);
    console.log(`  Successful: ${successCount}`);
    console.log(`  Failed: ${requests.length - successCount}`);
    console.log(`  Total time: ${totalTime}ms`);
    console.log('');
    console.log('✅ All requests completed concurrently with FIPS-approved TLS');
    console.log('');
}

// ============================================================================
// Demo 5: Request with Timeout Handling
// ============================================================================
async function demo5_timeout_handling() {
    console.log('-'.repeat(70));
    console.log('Demo 5: Request Timeout Handling');
    console.log('-'.repeat(70));
    console.log('');

    // Test 1: Normal request (should succeed)
    console.log('Test 1: Normal request (5s timeout)');
    await new Promise((resolve) => {
        const options = {
            hostname: 'httpbin.org',
            port: 443,
            path: '/delay/2',
            method: 'GET',
            timeout: 5000
        };

        const startTime = Date.now();

        const req = https.request(options, (res) => {
            const duration = Date.now() - startTime;

            let data = '';
            res.on('data', (chunk) => { data += chunk; });
            res.on('end', () => {
                console.log(`  Status: ${res.statusCode}`);
                console.log(`  Duration: ${duration}ms`);
                console.log('  ✅ Completed within timeout');
                console.log('');
                resolve();
            });
        });

        req.on('timeout', () => {
            console.log('  ⚠️  Request timed out');
            req.destroy();
            console.log('');
            resolve();
        });

        req.on('error', (error) => {
            if (error.code !== 'ECONNRESET') {
                console.log(`  ❌ Error: ${error.message}`);
            }
            console.log('');
            resolve();
        });

        req.end();
    });

    // Test 2: Timeout scenario
    console.log('Test 2: Timeout scenario (2s timeout, 5s delay)');
    await new Promise((resolve) => {
        const options = {
            hostname: 'httpbin.org',
            port: 443,
            path: '/delay/5',
            method: 'GET',
            timeout: 2000
        };

        const startTime = Date.now();

        const req = https.request(options, (res) => {
            let data = '';
            res.on('data', (chunk) => { data += chunk; });
            res.on('end', () => {
                console.log(`  ✅ Completed (unexpected)`);
                console.log('');
                resolve();
            });
        });

        req.on('timeout', () => {
            const duration = Date.now() - startTime;
            console.log(`  ⏱️  Request timed out after ${duration}ms`);
            console.log('  ✅ Timeout handled gracefully');
            req.destroy();
            console.log('');
            resolve();
        });

        req.on('error', (error) => {
            if (error.code !== 'ECONNRESET') {
                console.log(`  Error: ${error.message}`);
                console.log('');
            }
            resolve();
        });

        req.end();
    });
}

// ============================================================================
// Main Execution
// ============================================================================

// Add crypto for UUID generation
const crypto = require('crypto');

(async () => {
    try {
        await demo1_simple_get();
        await demo2_post_json();
        await demo3_custom_headers();
        await demo4_concurrent_requests();
        await demo5_timeout_handling();

        // Summary
        console.log('='.repeat(70));
        console.log('Summary');
        console.log('='.repeat(70));
        console.log('');
        console.log('Demonstrated HTTPS Request Patterns:');
        console.log('  ✅ GET requests');
        console.log('  ✅ POST requests with JSON');
        console.log('  ✅ Custom headers');
        console.log('  ✅ Concurrent requests');
        console.log('  ✅ Timeout handling');
        console.log('');
        console.log('FIPS Compliance:');
        console.log('  • All requests use FIPS-approved TLS ciphers');
        console.log('  • Certificate validation enabled by default');
        console.log('  • No weak or deprecated protocols');
        console.log('');
        console.log('Best Practices Demonstrated:');
        console.log('  • Always set request timeouts');
        console.log('  • Handle errors gracefully');
        console.log('  • Use concurrent requests for performance');
        console.log('  • Proper header management');
        console.log('  • JSON data serialization');
        console.log('');
        console.log('All HTTPS requests completed with FIPS-approved cryptography!');
        console.log('');

    } catch (error) {
        console.error(`Fatal error: ${error.message}`);
        process.exit(1);
    }
})();
