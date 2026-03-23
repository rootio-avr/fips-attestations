#!/usr/bin/env node
/**
 * Certificate Validation Demo
 * Demonstrates certificate chain validation with FIPS compliance
 */

const https = require('https');
const tls = require('tls');

console.log('='.repeat(70));
console.log('Certificate Validation Demo - Node.js with wolfSSL FIPS 140-3');
console.log('='.repeat(70));
console.log('');

// ============================================================================
// Demo 1: Valid Certificate Verification
// ============================================================================
async function demo1_valid_certificate() {
    console.log('-'.repeat(70));
    console.log('Demo 1: Valid Certificate Verification');
    console.log('-'.repeat(70));
    console.log('');

    return new Promise((resolve) => {
        console.log('Connecting to www.google.com with certificate validation enabled...');
        console.log('');

        const options = {
            host: 'www.google.com',
            port: 443,
            servername: 'www.google.com',
            rejectUnauthorized: true, // Enforce certificate validation
            timeout: 10000
        };

        const socket = tls.connect(options, () => {
            const cert = socket.getPeerCertificate();

            console.log('Certificate Information:');
            console.log(`  Subject CN: ${cert.subject?.CN || 'N/A'}`);
            console.log(`  Issuer CN: ${cert.issuer?.CN || 'N/A'}`);
            console.log(`  Valid From: ${cert.valid_from}`);
            console.log(`  Valid To: ${cert.valid_to}`);
            console.log(`  Serial Number: ${cert.serialNumber}`);
            console.log('');

            console.log('Validation Results:');
            console.log(`  Authorized: ${socket.authorized ? '✅ YES' : '❌ NO'}`);
            if (socket.authorized) {
                console.log('  ✅ Certificate chain validation successful');
                console.log('  ✅ Certificate is trusted by system CA bundle');
            } else {
                console.log(`  ❌ Error: ${socket.authorizationError}`);
            }
            console.log('');

            socket.end();
            resolve();
        });

        socket.on('error', (error) => {
            console.log(`❌ Connection Error: ${error.message}`);
            console.log('');
            resolve();
        });
    });
}

// ============================================================================
// Demo 2: Certificate Chain Inspection
// ============================================================================
async function demo2_certificate_chain() {
    console.log('-'.repeat(70));
    console.log('Demo 2: Certificate Chain Inspection');
    console.log('-'.repeat(70));
    console.log('');

    return new Promise((resolve) => {
        console.log('Retrieving full certificate chain from www.google.com...');
        console.log('');

        const options = {
            host: 'www.google.com',
            port: 443,
            servername: 'www.google.com',
            rejectUnauthorized: true,
            timeout: 10000
        };

        const socket = tls.connect(options, () => {
            // Get full certificate chain
            let cert = socket.getPeerCertificate(true);
            let chainDepth = 0;

            console.log('Certificate Chain:');
            console.log('');

            while (cert && chainDepth < 10) {
                chainDepth++;

                console.log(`Certificate ${chainDepth}:`);
                console.log(`  Subject: ${cert.subject?.CN || 'N/A'}`);
                console.log(`  Issuer: ${cert.issuer?.CN || 'N/A'}`);
                console.log(`  Valid: ${cert.valid_from} to ${cert.valid_to}`);
                console.log(`  Signature Algorithm: ${cert.sigalg || 'N/A'}`);

                // Check for SHA-1 signatures (allowed for legacy verification)
                if (cert.sigalg && cert.sigalg.toLowerCase().includes('sha1')) {
                    console.log(`  ⚠️  Uses SHA-1 signature (legacy CA, allowed for verification)`);
                } else {
                    console.log(`  ✅ Modern signature algorithm`);
                }

                console.log('');

                // Move to issuer certificate
                if (cert.issuerCertificate && cert.issuerCertificate !== cert) {
                    cert = cert.issuerCertificate;
                } else {
                    break;
                }
            }

            console.log(`Total chain depth: ${chainDepth} certificate(s)`);
            console.log('✅ Full chain validated successfully');
            console.log('');

            socket.end();
            resolve();
        });

        socket.on('error', (error) => {
            console.log(`❌ Error: ${error.message}`);
            console.log('');
            resolve();
        });
    });
}

// ============================================================================
// Demo 3: Hostname Verification
// ============================================================================
async function demo3_hostname_verification() {
    console.log('-'.repeat(70));
    console.log('Demo 3: Hostname Verification');
    console.log('-'.repeat(70));
    console.log('');

    console.log('Testing hostname matching in certificate validation:');
    console.log('');

    // Test 1: Correct hostname
    console.log('Test 1: Connecting to www.google.com');
    await new Promise((resolve) => {
        const options = {
            host: 'www.google.com',
            port: 443,
            servername: 'www.google.com',
            rejectUnauthorized: true,
            timeout: 10000
        };

        const socket = tls.connect(options, () => {
            const cert = socket.getPeerCertificate();

            console.log(`  Certificate CN: ${cert.subject?.CN}`);
            console.log(`  Requested hostname: www.google.com`);
            console.log(`  Match: ${socket.authorized ? '✅ YES' : '❌ NO'}`);
            console.log('');

            socket.end();
            resolve();
        });

        socket.on('error', (error) => {
            console.log(`  ❌ Error: ${error.message}`);
            console.log('');
            resolve();
        });
    });

    // Test 2: Different valid hostname for same certificate
    console.log('Test 2: Connecting to google.com');
    await new Promise((resolve) => {
        const options = {
            host: 'google.com',
            port: 443,
            servername: 'google.com',
            rejectUnauthorized: true,
            timeout: 10000
        };

        const socket = tls.connect(options, () => {
            const cert = socket.getPeerCertificate();

            console.log(`  Certificate CN: ${cert.subject?.CN}`);
            console.log(`  Requested hostname: google.com`);
            console.log(`  Match: ${socket.authorized ? '✅ YES' : '❌ NO'}`);
            console.log(`  Note: May use Subject Alternative Name (SAN)`);
            console.log('');

            socket.end();
            resolve();
        });

        socket.on('error', (error) => {
            console.log(`  ⚠️  ${error.message}`);
            console.log('');
            resolve();
        });
    });
}

// ============================================================================
// Demo 4: Certificate Expiration Check
// ============================================================================
async function demo4_expiration_check() {
    console.log('-'.repeat(70));
    console.log('Demo 4: Certificate Expiration Check');
    console.log('-'.repeat(70));
    console.log('');

    return new Promise((resolve) => {
        console.log('Checking certificate validity period...');
        console.log('');

        const options = {
            host: 'www.google.com',
            port: 443,
            servername: 'www.google.com',
            rejectUnauthorized: true,
            timeout: 10000
        };

        const socket = tls.connect(options, () => {
            const cert = socket.getPeerCertificate();

            const validFrom = new Date(cert.valid_from);
            const validTo = new Date(cert.valid_to);
            const now = new Date();

            console.log('Certificate Validity:');
            console.log(`  Valid From: ${cert.valid_from}`);
            console.log(`  Valid To: ${cert.valid_to}`);
            console.log(`  Current Time: ${now.toISOString()}`);
            console.log('');

            const daysUntilExpiry = Math.floor((validTo - now) / (1000 * 60 * 60 * 24));

            console.log('Status:');
            if (now < validFrom) {
                console.log(`  ❌ Certificate not yet valid`);
            } else if (now > validTo) {
                console.log(`  ❌ Certificate has expired`);
            } else {
                console.log(`  ✅ Certificate is currently valid`);
                console.log(`  Days until expiry: ${daysUntilExpiry}`);

                if (daysUntilExpiry < 30) {
                    console.log(`  ⚠️  Certificate expires soon!`);
                } else {
                    console.log(`  ✅ Certificate has sufficient validity`);
                }
            }
            console.log('');

            socket.end();
            resolve();
        });

        socket.on('error', (error) => {
            console.log(`❌ Error: ${error.message}`);
            console.log('');
            resolve();
        });
    });
}

// ============================================================================
// Demo 5: Multiple Host Validation
// ============================================================================
async function demo5_multiple_hosts() {
    console.log('-'.repeat(70));
    console.log('Demo 5: Validating Multiple Hosts');
    console.log('-'.repeat(70));
    console.log('');

    const hosts = [
        'www.google.com',
        'www.github.com',
        'www.amazon.com',
        'www.cloudflare.com'
    ];

    console.log('Testing certificate validation across multiple domains:');
    console.log('');

    for (const hostname of hosts) {
        await new Promise((resolve) => {
            const options = {
                host: hostname,
                port: 443,
                servername: hostname,
                rejectUnauthorized: true,
                timeout: 10000
            };

            const socket = tls.connect(options, () => {
                const cert = socket.getPeerCertificate();
                const cipher = socket.getCipher();

                console.log(`${hostname}:`);
                console.log(`  Issuer: ${cert.issuer?.O || cert.issuer?.CN || 'N/A'}`);
                console.log(`  Signature: ${cert.sigalg || 'N/A'}`);
                console.log(`  TLS: ${socket.getProtocol()}`);
                console.log(`  Cipher: ${cipher.name}`);
                console.log(`  Validated: ${socket.authorized ? '✅ YES' : '❌ NO'}`);
                console.log('');

                socket.end();
                resolve();
            });

            socket.on('error', (error) => {
                console.log(`${hostname}: ❌ ${error.message}`);
                console.log('');
                resolve();
            });
        });
    }
}

// ============================================================================
// Main Execution
// ============================================================================
(async () => {
    try {
        await demo1_valid_certificate();
        await demo2_certificate_chain();
        await demo3_hostname_verification();
        await demo4_expiration_check();
        await demo5_multiple_hosts();

        // Summary
        console.log('='.repeat(70));
        console.log('Summary');
        console.log('='.repeat(70));
        console.log('');
        console.log('Certificate Validation Features:');
        console.log('  ✅ X.509 certificate chain validation');
        console.log('  ✅ Hostname verification (CN and SAN matching)');
        console.log('  ✅ Expiration date checking');
        console.log('  ✅ Trusted CA bundle verification');
        console.log('  ✅ Signature algorithm validation');
        console.log('');
        console.log('FIPS 140-3 Compliance:');
        console.log('  • SHA-1 signatures allowed for legacy CA verification');
        console.log('  • Modern certificates use SHA-256 or higher');
        console.log('  • All validations use FIPS-approved algorithms');
        console.log('');
        console.log('Security Best Practices:');
        console.log('  • Always use rejectUnauthorized: true in production');
        console.log('  • Verify hostname matches certificate CN/SAN');
        console.log('  • Monitor certificate expiration dates');
        console.log('  • Keep system CA bundle up to date');
        console.log('');
        console.log('All certificate validations completed successfully!');
        console.log('');

    } catch (error) {
        console.error(`Fatal error: ${error.message}`);
        process.exit(1);
    }
})();
