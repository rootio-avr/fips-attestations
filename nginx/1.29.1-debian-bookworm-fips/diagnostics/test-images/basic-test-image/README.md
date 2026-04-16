# Nginx FIPS Basic Test Image

Comprehensive test image for validating Nginx 1.29.1 with wolfSSL FIPS 140-3 integration.

## Overview

This test image extends the base `cr.root.io/nginx:1.29.1-debian-bookworm-fips` image with comprehensive test suites to validate FIPS compliance in a user application context.

## Test Suites

### 1. TLS Protocol Test Suite
**File**: `test_tls_protocols.sh` (5 tests)

Tests:
- TLS 1.2 protocol support ✅
- TLS 1.3 protocol support ✅
- TLS 1.0 blocked ❌
- TLS 1.1 blocked ❌
- SSLv3 blocked ❌

### 2. FIPS Cipher Test Suite
**File**: `test_fips_ciphers.sh` (5 tests)

Tests:
- FIPS-approved cipher (TLS 1.2): ECDHE-RSA-AES256-GCM-SHA384 ✅
- FIPS-approved cipher (TLS 1.3): TLS_AES_256_GCM_SHA384 ✅
- RC4 cipher blocked ❌
- DES cipher blocked ❌
- 3DES cipher blocked ❌

### 3. Certificate Validation Test Suite
**File**: `test_certificate_validation.sh` (4 tests)

Tests:
- Self-signed certificate loaded ✅
- RSA 2048-bit key (FIPS minimum) ✅
- OpenSSL provider verification (wolfSSL Provider FIPS) ✅
- FIPS POST validation ✅

### 4. Main Orchestrator
**File**: `run_all_tests.sh`

Main orchestrator that:
- Runs all test suites sequentially
- Aggregates results
- Provides comprehensive summary
- Returns appropriate exit codes

## Building the Image

```bash
./build.sh
```

This creates the `nginx-fips-test:latest` image.

## Running Tests

### Run All Tests (Default)

```bash
docker run --rm nginx-fips-test:latest
```

Expected output:
```
===============================================================================
  Nginx wolfSSL FIPS 140-3 Basic Test Image
  Comprehensive User Application Test Suite
===============================================================================

Running Test Suite 1: TLS Protocol Tests
...
Tests Passed: 5/5

Running Test Suite 2: FIPS Cipher Tests
...
Tests Passed: 5/5

Running Test Suite 3: Certificate Validation Tests
...
Tests Passed: 4/4

===============================================================================
  FINAL TEST SUMMARY
===============================================================================
  Total Test Suites: 3
  Passed: 3
  Failed: 0
  Duration: X seconds

  ✓ TLS Protocol Tests: PASS
  ✓ FIPS Cipher Tests: PASS
  ✓ Certificate Validation Tests: PASS

  ✓ ALL TESTS PASSED - Nginx wolfSSL FIPS is production ready
```

### Run Individual Test Suites

**TLS Protocol tests only:**
```bash
docker run --rm nginx-fips-test:latest ./test_tls_protocols.sh
```

**FIPS Cipher tests only:**
```bash
docker run --rm nginx-fips-test:latest ./test_fips_ciphers.sh
```

**Certificate validation tests only:**
```bash
docker run --rm nginx-fips-test:latest ./test_certificate_validation.sh
```

### Interactive Shell

```bash
docker run --rm -it nginx-fips-test:latest /bin/bash
```

Then run:
```bash
./run_all_tests.sh
# or
./test_tls_protocols.sh
./test_fips_ciphers.sh
./test_certificate_validation.sh
```

## Exit Codes

- **0**: All tests passed
- **1**: Partial success (1-2 suites passed)
- **2**: Critical failure (0-1 suites passed)

## Expected Results

In a properly configured FIPS environment:
- **TLS Protocol Tests**: 5/5 passed (TLS 1.2/1.3 work, older protocols blocked)
- **FIPS Cipher Tests**: 5/5 passed (FIPS ciphers work, non-FIPS blocked)
- **Certificate Validation**: 4/4 passed (cert loaded, provider active, FIPS POST passes)
- **Overall**: Production ready status

## Integration with CI/CD

Use in automated testing:

```bash
# Run tests and capture exit code
docker run --rm nginx-fips-test:latest
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

**TLS tests fail**: Check Nginx startup
```bash
docker run --rm nginx-fips-test:latest nginx -t
```

**Cipher tests fail**: Check wolfProvider
```bash
docker run --rm nginx-fips-test:latest openssl list -providers
```

**Certificate tests fail**: Check FIPS POST
```bash
docker run --rm nginx-fips-test:latest fips-startup-check
```

## Comparison with Full Diagnostics

This test image provides:
- ✅ Fast execution (~5-15 seconds)
- ✅ Essential FIPS validation (14 tests)
- ✅ User application context
- ✅ CI/CD friendly

Full diagnostics (`../../diagnostic.sh`) provide:
- 2 comprehensive test scripts
- External connectivity tests
- Detailed TLS handshake validation
- More scenarios

Both are valuable:
- Use **test image** for quick validation and CI/CD
- Use **full diagnostics** for comprehensive analysis

## See Also

- [Full Diagnostic Suite](../../diagnostic.sh)
- [Base Image README](../../../README.md)
- [FIPS Architecture](../../../ARCHITECTURE.md) (to be created)
- [Developer Guide](../../../DEVELOPER-GUIDE.md) (to be created)

## Version Information

- **Nginx Version**: 1.29.1
- **wolfSSL Version**: 5.8.2 FIPS 140-3
- **FIPS Certificate**: #4718
- **OpenSSL Version**: 3.0.19
- **wolfProvider Version**: 1.1.0
- **Base Image**: debian:bookworm-slim
