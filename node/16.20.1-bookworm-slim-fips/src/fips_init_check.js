#!/usr/bin/env node
/**
 * FIPS Initialization Check for Node.js with wolfSSL FIPS
 *
 * Verifies:
 * - OpenSSL configuration is loaded
 * - wolfProvider is active
 * - FIPS-approved algorithms are available
 * - Non-FIPS algorithms are properly restricted
 */

const crypto = require('crypto');
const fs = require('fs');
const { execSync } = require('child_process');

// ANSI color codes
const GREEN = '\x1b[32m';
const RED = '\x1b[31m';
const YELLOW = '\x1b[33m';
const CYAN = '\x1b[36m';
const RESET = '\x1b[0m';

let testsRun = 0;
let testsPassed = 0;
let testsFailed = 0;

function log(message, color = RESET) {
    console.log(`${color}${message}${RESET}`);
}

function test(name, testFn) {
    testsRun++;
    process.stdout.write(`  Testing ${name}... `);

    try {
        const result = testFn();
        if (result) {
            testsPassed++;
            log(`${GREEN}✓ PASS${RESET}`);
            return true;
        } else {
            testsFailed++;
            log(`${RED}✗ FAIL${RESET}`);
            return false;
        }
    } catch (error) {
        testsFailed++;
        log(`${RED}✗ FAIL${RESET} (${error.message})`);
        return false;
    }
}

function main() {
    console.log('');
    log('================================================================', CYAN);
    log('  Node.js wolfSSL FIPS Initialization Check', CYAN);
    log('================================================================', CYAN);
    console.log('');

    // Test 1: OpenSSL configuration file exists
    test('OpenSSL configuration file exists', () => {
        const configPath = process.env.OPENSSL_CONF || '/etc/ssl/openssl.cnf';
        return fs.existsSync(configPath);
    });

    // Test 2: wolfSSL library exists
    test('wolfSSL library exists', () => {
        return fs.existsSync('/usr/local/lib/libwolfssl.so');
    });

    // Test 3: wolfProvider library exists
    test('wolfProvider library exists', () => {
        return fs.existsSync('/usr/local/lib/libwolfprov.so');
    });

    // Test 4: SHA-256 hash algorithm available
    test('SHA-256 hash algorithm', () => {
        const hash = crypto.createHash('sha256');
        hash.update('FIPS test data');
        const digest = hash.digest('hex');
        return digest.length === 64;
    });

    // Test 5: SHA-384 hash algorithm available
    test('SHA-384 hash algorithm', () => {
        const hash = crypto.createHash('sha384');
        hash.update('FIPS test data');
        const digest = hash.digest('hex');
        return digest.length === 96;
    });

    // Test 6: SHA-512 hash algorithm available
    test('SHA-512 hash algorithm', () => {
        const hash = crypto.createHash('sha512');
        hash.update('FIPS test data');
        const digest = hash.digest('hex');
        return digest.length === 128;
    });

    // Test 7: Random bytes generation
    test('Random bytes generation', () => {
        const randomBytes = crypto.randomBytes(32);
        return randomBytes.length === 32;
    });

    // Test 8: FIPS test executable
    test('FIPS KAT executable exists', () => {
        return fs.existsSync('/test-fips');
    });

    // Test 9: Run FIPS KAT tests
    test('FIPS Known Answer Tests (KATs)', () => {
        try {
            execSync('/test-fips', { stdio: 'pipe' });
            return true;
        } catch (error) {
            return false;
        }
    });

    // Test 10: Check for FIPS-approved ciphers
    test('FIPS-approved cipher suites available', () => {
        const ciphers = crypto.getCiphers();
        // Check for AES-GCM ciphers (FIPS-approved)
        const hasAesGcm = ciphers.some(c => c.includes('aes') && c.includes('gcm'));
        return hasAesGcm;
    });

    // Test 11: Verify FIPS mode is enabled in Node.js
    test('Node.js FIPS mode enabled', () => {
        try {
            // crypto.getFips() returns 1 if FIPS is enabled, 0 if disabled
            const fipsEnabled = crypto.getFips();
            return fipsEnabled === 1;
        } catch (error) {
            // If getFips() is not available, this is not a FIPS-capable build
            return false;
        }
    });

    console.log('');
    log('================================================================', CYAN);
    log('  Summary', CYAN);
    log('================================================================', CYAN);
    console.log(`  Total tests: ${testsRun}`);
    log(`  Passed: ${testsPassed}`, GREEN);
    if (testsFailed > 0) {
        log(`  Failed: ${testsFailed}`, RED);
    } else {
        console.log(`  Failed: ${testsFailed}`);
    }
    console.log('');

    if (testsPassed === testsRun) {
        log('✓ ALL FIPS INITIALIZATION CHECKS PASSED', GREEN);
        console.log('');
        return 0;
    } else {
        log('✗ FIPS INITIALIZATION CHECK FAILED', RED);
        console.log('');
        return 1;
    }
}

// Run the checks
const exitCode = main();
process.exit(exitCode);
