# Node.js FIPS Basic Test Image

Comprehensive test image for validating Node.js 18 with wolfSSL FIPS 140-3 integration.

## Overview

This test image extends the base `node:18.20.8-bookworm-slim-fips` image with comprehensive test suites to validate FIPS compliance in a user application context.

## Test Suites

### 1. Cryptographic Operations Test Suite
**File**: `crypto_test_suite.js` (8 tests)

Tests:
- SHA-256, SHA-384, SHA-512 hash generation
- SHA-1 availability (for legacy verification)
- HMAC-SHA256 operations
- Random bytes generation
- AES-256-CBC encryption/decryption
- FIPS-approved cipher availability

*Note: PBKDF2 skipped (not accessible via Node.js crypto API with wolfProvider v1.0.2)*

### 2. TLS/SSL Test Suite
**File**: `tls_test_suite.js` (6 tests)

Tests:
- HTTPS connections
- TLS 1.2 protocol support
- TLS 1.3 protocol support
- Certificate validation
- FIPS-approved cipher negotiation
- HTTPS POST requests

### 3. FIPS User Application
**File**: `fips_user_application.js`

Main orchestrator that:
- Runs all test suites sequentially
- Aggregates results
- Provides comprehensive summary
- Returns appropriate exit codes

## Building the Image

```bash
./build.sh
```

This creates the `node-fips-test:latest` image.

## Running Tests

### Run All Tests (Default)

```bash
docker run --rm node-fips-test:latest
```

Expected output:
```
================================================================================
  Node.js wolfSSL FIPS 140-3 User Application Test
  Comprehensive Cryptographic and TLS Test Suite
================================================================================

Running: Cryptographic Operations Test Suite
...
Crypto Tests: 8/8 passed

Running: TLS/SSL Test Suite
...
TLS Tests: 6/6 passed

================================================================================
  FINAL TEST SUMMARY
================================================================================
  Total Test Suites: 2
  Passed: 2
  Failed: 0
  Duration: X.XX seconds

  ✓ Cryptographic Operations Test Suite: PASS
  ✓ TLS/SSL Test Suite: PASS

  ✓ ALL TESTS PASSED - Node.js wolfSSL FIPS is production ready
```

### Run Individual Test Suites

**Crypto tests only:**
```bash
docker run --rm node-fips-test:latest node crypto_test_suite.js
```

**TLS tests only:**
```bash
docker run --rm node-fips-test:latest node tls_test_suite.js
```

### Interactive Shell

```bash
docker run --rm -it node-fips-test:latest /bin/bash
```

Then run:
```bash
node fips_user_application.js
# or
node crypto_test_suite.js
node tls_test_suite.js
```

## Exit Codes

- **0**: All tests passed
- **1**: Partial success (1 suite failed)
- **2**: Multiple failures

## Network Requirements

TLS tests require internet connectivity to connect to:
- www.google.com (TLS protocol tests)
- httpbin.org (HTTPS POST tests)

Ensure Docker allows outbound HTTPS connections.

## Expected Results

In a properly configured FIPS environment:
- **Crypto Tests**: 8/8 passed (all accessible FIPS algorithms validated)
- **TLS Tests**: 5/6 or 6/6 passed
- **Overall**: Production ready status

*Note: PBKDF2 skipped due to wolfProvider v1.0.2 interface limitation (algorithm is FIPS-validated but not accessible via Node.js crypto API)*

## Integration with CI/CD

Use in automated testing:

```bash
# Run tests and capture exit code
docker run --rm node-fips-test:latest
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "FIPS validation passed"
    exit 0
else
    echo "FIPS validation failed with code $EXIT_CODE"
    exit $EXIT_CODE
fi
```

## Troubleshooting

### Build Failures

**Issue**: Base image not found
```bash
# Build base image first
cd ../../..
./build.sh
```

### Test Failures

**Crypto tests fail**: Check FIPS module initialization
```bash
docker run --rm node:18.20.8-bookworm-slim-fips /test-fips
```

**TLS tests fail**: Check network connectivity
```bash
docker run --rm node-fips-test:latest ping -c 3 www.google.com
```

## Comparison with Full Diagnostics

This test image provides:
- ✅ Fast execution (~10-30 seconds)
- ✅ Essential FIPS validation
- ✅ User application context
- ✅ CI/CD friendly

Full diagnostics (`../run-all-tests.sh`) provide:
- 36 comprehensive tests
- Detailed backend verification
- Library compatibility checks
- Performance metrics

Both are valuable:
- Use **test image** for quick validation and CI/CD
- Use **full diagnostics** for comprehensive analysis

## See Also

- [Full Diagnostic Suite](../../run-all-tests.sh)
- [Base Image README](../../../README.md)
- [Implementation Status](../../../IMPLEMENTATION-STATUS.md)
