#!/usr/bin/env node
/**
 * Hash Algorithm Demo
 * Demonstrates FIPS-approved and non-FIPS hash algorithms
 */

const crypto = require('crypto');

console.log('='.repeat(70));
console.log('Hash Algorithm Demo - Node.js with wolfSSL FIPS 140-3');
console.log('='.repeat(70));
console.log('');

// Test data
const testData = 'The quick brown fox jumps over the lazy dog';
console.log(`Test Data: "${testData}"`);
console.log('');

// ============================================================================
// Demo 1: FIPS-Approved Hash Algorithms
// ============================================================================
console.log('-'.repeat(70));
console.log('Demo 1: FIPS-Approved Hash Algorithms');
console.log('-'.repeat(70));
console.log('');

// SHA-256
console.log('1. SHA-256 (FIPS-Approved)');
console.log('   Use: General-purpose hashing, digital signatures');
try {
    const hash256 = crypto.createHash('sha256');
    hash256.update(testData);
    const digest256 = hash256.digest('hex');
    console.log(`   Digest: ${digest256}`);
    console.log(`   Length: ${digest256.length} characters (64 hex = 256 bits)`);
    console.log('   ✅ FIPS-approved for all uses');
} catch (error) {
    console.log(`   ❌ Error: ${error.message}`);
}
console.log('');

// SHA-384
console.log('2. SHA-384 (FIPS-Approved)');
console.log('   Use: Higher security applications, certificates');
try {
    const hash384 = crypto.createHash('sha384');
    hash384.update(testData);
    const digest384 = hash384.digest('hex');
    console.log(`   Digest: ${digest384}`);
    console.log(`   Length: ${digest384.length} characters (96 hex = 384 bits)`);
    console.log('   ✅ FIPS-approved for all uses');
} catch (error) {
    console.log(`   ❌ Error: ${error.message}`);
}
console.log('');

// SHA-512
console.log('3. SHA-512 (FIPS-Approved)');
console.log('   Use: Maximum security applications, long-term integrity');
try {
    const hash512 = crypto.createHash('sha512');
    hash512.update(testData);
    const digest512 = hash512.digest('hex');
    console.log(`   Digest: ${digest512}`);
    console.log(`   Length: ${digest512.length} characters (128 hex = 512 bits)`);
    console.log('   ✅ FIPS-approved for all uses');
} catch (error) {
    console.log(`   ❌ Error: ${error.message}`);
}
console.log('');

// ============================================================================
// Demo 2: Non-FIPS Hash Algorithms (Legacy Support)
// ============================================================================
console.log('-'.repeat(70));
console.log('Demo 2: Non-FIPS Hash Algorithms (Legacy Support)');
console.log('-'.repeat(70));
console.log('');

// MD5
console.log('4. MD5 (Non-FIPS)');
console.log('   Status: Cryptographically broken, not FIPS-approved');
try {
    const hashMd5 = crypto.createHash('md5');
    hashMd5.update(testData);
    const digestMd5 = hashMd5.digest('hex');
    console.log(`   Digest: ${digestMd5}`);
    console.log(`   Length: ${digestMd5.length} characters (32 hex = 128 bits)`);
    console.log('   ⚠️  Available in Node.js but NOT FIPS-approved');
    console.log('   ⚠️  Should not be used for security purposes');
} catch (error) {
    console.log(`   ✅ Blocked: ${error.message}`);
}
console.log('');

// SHA-1
console.log('5. SHA-1 (Non-FIPS for new operations)');
console.log('   Status: FIPS allows for legacy verification only');
try {
    const hashSha1 = crypto.createHash('sha1');
    hashSha1.update(testData);
    const digestSha1 = hashSha1.digest('hex');
    console.log(`   Digest: ${digestSha1}`);
    console.log(`   Length: ${digestSha1.length} characters (40 hex = 160 bits)`);
    console.log('   ℹ️  Available for legacy certificate verification (FIPS 140-3 IG D.F)');
    console.log('   ⚠️  Not approved for new signatures or certificates');
} catch (error) {
    console.log(`   ✅ Blocked: ${error.message}`);
}
console.log('');

// ============================================================================
// Demo 3: Hash Streaming (Large Data)
// ============================================================================
console.log('-'.repeat(70));
console.log('Demo 3: Hash Streaming for Large Data');
console.log('-'.repeat(70));
console.log('');

console.log('Demonstrating incremental hashing (useful for large files):');
try {
    const hash = crypto.createHash('sha256');

    // Simulate processing data in chunks
    const chunks = [
        'First chunk of data. ',
        'Second chunk of data. ',
        'Third chunk of data.'
    ];

    console.log('Processing chunks:');
    chunks.forEach((chunk, index) => {
        hash.update(chunk);
        console.log(`  Chunk ${index + 1}: "${chunk}"`);
    });

    const finalDigest = hash.digest('hex');
    console.log('');
    console.log(`Final Digest: ${finalDigest}`);
    console.log('✅ Streaming allows memory-efficient hashing of large files');
} catch (error) {
    console.log(`❌ Error: ${error.message}`);
}
console.log('');

// ============================================================================
// Demo 4: Hash Comparison (Verify Data Integrity)
// ============================================================================
console.log('-'.repeat(70));
console.log('Demo 4: Data Integrity Verification');
console.log('-'.repeat(70));
console.log('');

console.log('Use Case: Verify downloaded file integrity');
try {
    const originalData = 'Important document content';
    const receivedData = 'Important document content';
    const tamperedData = 'Important document content TAMPERED';

    const hashOriginal = crypto.createHash('sha256').update(originalData).digest('hex');
    const hashReceived = crypto.createHash('sha256').update(receivedData).digest('hex');
    const hashTampered = crypto.createHash('sha256').update(tamperedData).digest('hex');

    console.log('Original Data Hash:');
    console.log(`  ${hashOriginal}`);
    console.log('');

    console.log('Received Data Hash:');
    console.log(`  ${hashReceived}`);
    console.log(`  Match: ${hashOriginal === hashReceived ? '✅ YES' : '❌ NO'}`);
    console.log('');

    console.log('Tampered Data Hash:');
    console.log(`  ${hashTampered}`);
    console.log(`  Match: ${hashOriginal === hashTampered ? '✅ YES' : '❌ NO'}`);
    console.log('');

    console.log('Result: Hash verification can detect even minor changes');
} catch (error) {
    console.log(`❌ Error: ${error.message}`);
}
console.log('');

// ============================================================================
// Demo 5: Binary vs Hex vs Base64 Output
// ============================================================================
console.log('-'.repeat(70));
console.log('Demo 5: Different Hash Output Formats');
console.log('-'.repeat(70));
console.log('');

console.log('Same hash, different encodings:');
try {
    const data = 'Example data';

    const hashHex = crypto.createHash('sha256').update(data).digest('hex');
    const hashBase64 = crypto.createHash('sha256').update(data).digest('base64');
    const hashBuffer = crypto.createHash('sha256').update(data).digest();

    console.log('Hexadecimal (64 chars):');
    console.log(`  ${hashHex}`);
    console.log('');

    console.log('Base64 (44 chars):');
    console.log(`  ${hashBase64}`);
    console.log('');

    console.log('Binary Buffer (32 bytes):');
    console.log(`  <Buffer ${hashBuffer.toString('hex', 0, 16)}...>`);
    console.log('');

    console.log('All three represent the same 256-bit hash value');
} catch (error) {
    console.log(`❌ Error: ${error.message}`);
}
console.log('');

// ============================================================================
// Summary
// ============================================================================
console.log('='.repeat(70));
console.log('Summary');
console.log('='.repeat(70));
console.log('');
console.log('FIPS-Approved Hash Algorithms:');
console.log('  ✅ SHA-256: General-purpose, widely used');
console.log('  ✅ SHA-384: Higher security, TLS cipher suites');
console.log('  ✅ SHA-512: Maximum security, long-term integrity');
console.log('');
console.log('Non-FIPS Algorithms:');
console.log('  ❌ MD5: Broken, not FIPS-approved (but available in Node.js)');
console.log('  ⚠️  SHA-1: Legacy verification only (FIPS 140-3 IG D.F)');
console.log('');
console.log('Best Practices:');
console.log('  • Use SHA-256 for general-purpose hashing');
console.log('  • Use SHA-384/512 for higher security requirements');
console.log('  • Avoid MD5 and SHA-1 for new implementations');
console.log('  • Use streaming for large files (memory efficient)');
console.log('');
