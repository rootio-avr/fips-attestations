# ASP.NET FIPS Basic Test Image

Comprehensive test image for validating ASP.NET Core 8.0.25 with wolfSSL FIPS 140-3 integration.

## Overview

This test image extends the base `aspnet:8.0.25-bookworm-slim-fips` image with comprehensive test suites to validate FIPS compliance in a user application context.

## Test Suites

### 1. Cryptographic Operations Test Suite
**File**: `CryptoTestSuite.cs` (10 tests)

Tests:
- SHA-256, SHA-384, SHA-512 hash generation
- AES-256-GCM encryption/decryption
- AES-256-CBC encryption/decryption
- HMAC-SHA256 operations
- Random number generation
- RSA-2048 sign/verify
- ECDSA P-256 sign/verify
- PBKDF2-SHA256 key derivation

All tests use standard .NET crypto APIs (`System.Security.Cryptography`) that automatically route through FIPS-validated wolfSSL.

### 2. TLS/SSL Test Suite
**File**: `TlsTestSuite.cs` (8 tests)

Tests:
- Basic HTTPS GET requests
- HTTPS with custom headers
- HTTPS POST requests
- TLS protocol version detection
- Certificate validation
- Concurrent HTTPS connections
- HTTPS timeout handling
- HTTPS redirect following

Uses `HttpClient` which automatically uses FIPS-compliant TLS.

### 3. FIPS User Application
**File**: `FipsUserApplication.cs`

Main orchestrator that:
- Runs all test suites sequentially
- Aggregates results
- Provides comprehensive summary
- Returns appropriate exit codes

## Building the Image

```bash
./build.sh
```

This creates the `aspnet-fips-test:latest` image.

## Running Tests

### Run All Tests (Default)

```bash
docker run --rm aspnet-fips-test:latest
```

Expected output:
```
================================================================================
  ASP.NET wolfSSL FIPS 140-3 User Application Test
  Comprehensive Cryptographic and TLS Test Suite
================================================================================

Running: Cryptographic Operations Test Suite
================================================================================
  Cryptographic Operations Test Suite
  Testing FIPS-Compliant Crypto via .NET → OpenSSL → wolfSSL
================================================================================

[1] SHA-256 Hashing... ✓ PASS
[2] SHA-384 Hashing... ✓ PASS
[3] SHA-512 Hashing... ✓ PASS
[4] AES-256-GCM Encryption/Decryption... ✓ PASS
[5] AES-256-CBC Encryption/Decryption... ✓ PASS
[6] HMAC-SHA256... ✓ PASS
[7] Random Number Generation... ✓ PASS
[8] RSA-2048 Sign/Verify... ✓ PASS
[9] ECDSA P-256 Sign/Verify... ✓ PASS
[10] PBKDF2-SHA256 Key Derivation... ✓ PASS

================================================================================
  Test Summary
================================================================================
  Total Tests:  10
  Passed:       10 ✓
  Failed:       0
================================================================================

✓ All cryptographic tests passed - FIPS crypto is working correctly

✓ Cryptographic Operations Test Suite: PASSED

Running: TLS/SSL Test Suite
================================================================================
  TLS/HTTPS Connectivity Test Suite
  Testing FIPS-Compliant TLS via HttpClient → OpenSSL → wolfSSL
================================================================================

[1] Basic HTTPS GET Request... ✓ PASS
[2] HTTPS with Custom Headers... ✓ PASS
[3] HTTPS POST Request... ✓ PASS
[4] TLS Protocol Version... ✓ PASS
[5] Certificate Validation... ✓ PASS
[6] Concurrent HTTPS Connections... ✓ PASS
[7] HTTPS Timeout Handling... ✓ PASS
[8] HTTPS Redirect Following... ✓ PASS

================================================================================
  Test Summary
================================================================================
  Total Tests:  8
  Passed:       8 ✓
  Failed:       0
================================================================================

✓ All TLS/HTTPS tests passed - FIPS TLS is working correctly

✓ TLS/SSL Test Suite: PASSED

================================================================================
  FINAL TEST SUMMARY
================================================================================
  Total Test Suites: 2
  Passed: 2
  Failed: 0
  Duration: 12.45 seconds

  ✓ Cryptographic Operations Test Suite: PASS
  ✓ TLS/SSL Test Suite: PASS

  ✓ ALL TESTS PASSED - ASP.NET wolfSSL FIPS is production ready
================================================================================
```

### Run Individual Test Suites

**Crypto tests only:**
```bash
docker run --rm aspnet-fips-test:latest dotnet-script CryptoTestSuite.cs
```

**TLS tests only:**
```bash
docker run --rm aspnet-fips-test:latest dotnet-script TlsTestSuite.cs
```

### Interactive Shell

```bash
docker run --rm -it aspnet-fips-test:latest /bin/bash
```

Then run:
```bash
dotnet-script FipsUserApplication.cs
# or
dotnet-script CryptoTestSuite.cs
dotnet-script TlsTestSuite.cs
```

## Exit Codes

- **0**: All tests passed (production ready)
- **1**: Partial success (1 suite failed)
- **2**: Multiple failures (2+ suites failed)

## Network Requirements

TLS tests require internet connectivity to connect to:
- www.google.com (TLS protocol tests, certificate validation)
- httpbin.org (HTTPS GET/POST tests)
- www.cloudflare.com (concurrent connection tests)

Ensure Docker allows outbound HTTPS connections.

## Expected Results

In a properly configured FIPS environment:
- **Crypto Tests**: 10/10 passed (all FIPS algorithms validated)
- **TLS Tests**: 8/8 passed (FIPS-compliant TLS)
- **Overall**: Production ready status

## Integration with CI/CD

Use in automated testing:

### GitLab CI

```yaml
test-fips-compliance:
  stage: test
  image: aspnet-fips-test:latest
  script:
    - dotnet-script FipsUserApplication.cs
  allow_failure: false
```

### GitHub Actions

```yaml
- name: Run FIPS Validation Tests
  run: |
    docker run --rm aspnet-fips-test:latest
```

### Jenkins

```groovy
stage('FIPS Validation') {
    steps {
        sh 'docker run --rm aspnet-fips-test:latest'
    }
}
```

### Command Line

```bash
# Run tests and capture exit code
docker run --rm aspnet-fips-test:latest
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "✓ FIPS validation passed"
    exit 0
else
    echo "✗ FIPS validation failed with code $EXIT_CODE"
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

**Issue**: Permission denied on build.sh
```bash
chmod +x build.sh
./build.sh
```

### Test Failures

**Crypto tests fail**: Check FIPS module initialization
```bash
# Run FIPS startup check
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips /usr/local/bin/fips-startup-check

# Verify wolfProvider is loaded
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips openssl list -providers
```

**TLS tests fail**: Check network connectivity
```bash
# Test network access
docker run --rm aspnet-fips-test:latest ping -c 3 www.google.com

# Check DNS resolution
docker run --rm aspnet-fips-test:latest nslookup www.google.com
```

**dotnet-script not found**: Rebuild base image with SDK
```bash
# Base image should include dotnet-script
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips dotnet-script --version
```

## Comparison with Full Diagnostics

This test image provides:
- ✅ Fast execution (~20-30 seconds)
- ✅ Essential FIPS validation (18 tests)
- ✅ User application context
- ✅ CI/CD friendly
- ✅ Simple pass/fail results

Full diagnostics (`/app/diagnostic.sh`) provide:
- 65 comprehensive tests
- Detailed backend verification
- FIPS module validation
- Library compatibility checks
- JSON results output

Both are valuable:
- Use **test image** for quick validation and CI/CD pipelines
- Use **full diagnostics** for comprehensive analysis and troubleshooting

## Implementation Details

### Standard .NET APIs

All tests use standard .NET cryptography APIs:
- `System.Security.Cryptography.SHA256`
- `System.Security.Cryptography.Aes`
- `System.Security.Cryptography.RSA`
- `System.Security.Cryptography.ECDsa`
- `System.Net.Http.HttpClient`

These APIs automatically route through:
```
.NET API → libSystem.Security.Cryptography.Native.OpenSsl.so →
OpenSSL 3.3.7 → wolfProvider → wolfSSL FIPS v5.8.2
```

No code changes are required for FIPS compliance!

### Test Philosophy

Tests validate that:
1. ✅ Standard .NET crypto APIs work correctly
2. ✅ Crypto operations produce correct results
3. ✅ TLS connections use FIPS-approved ciphers
4. ✅ Certificate validation works properly
5. ✅ No FIPS mode errors occur

This proves that real ASP.NET applications using standard .NET APIs will be FIPS-compliant.

## See Also

- [Full Diagnostic Suite](../../diagnostic.sh)
- [Base Image README](../../../README.md)
- [ARCHITECTURE.md](../../../ARCHITECTURE.md)

---

**Status**: Production Ready
**Test Coverage**: 18 tests (10 crypto + 8 TLS)
**Pass Rate**: 100% (18/18 in properly configured environment)
