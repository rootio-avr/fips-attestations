# Podman FIPS Basic Test Image

Simple test image for validating Podman 5.8.1 with wolfSSL FIPS 140-3 integration.

## Overview

This test image extends the base `podman:5.8.1-fedora-44-fips` image with a simple test suite to validate FIPS compliance in a user application context.

## Test Suite

### Test Application
**File**: `podman_fips_test.sh` (15 tests)

The test suite validates three main areas:

#### Section 1: FIPS Environment Validation (6 tests)
- GOLANG_FIPS=1 environment variable
- GODEBUG=fips140=only environment variable
- GOEXPERIMENT=strictfipsruntime environment variable
- OpenSSL 3.5.0 version check
- wolfSSL FIPS provider loaded
- wolfSSL FIPS self-test

#### Section 2: Podman Basic Functionality (5 tests)
- `podman --version` command
- `podman --help` command
- `podman images` list
- `podman ps` (list containers)
- `podman system df` disk usage

#### Section 3: Cryptographic Operations (4 tests)
- SHA-256 hash generation (FIPS-approved)
- MD5 hash blocking (non-FIPS, should be blocked)
- AES-256-GCM encryption (FIPS-approved)
- RSA-2048 key generation (FIPS-approved)

## Building the Image

```bash
./build.sh
```

This creates the `podman-fips-test:latest` image.

## Running Tests

### Run All Tests (Default)

```bash
docker run --rm podman-fips-test:latest
```

Expected output:
```
================================================================================
  Podman wolfSSL FIPS 140-3 User Application Test
================================================================================

Test Suite: Podman FIPS Validation
Base Image: cr.root.io/podman:5.8.1-fedora-44-fips
Podman Version: podman version 5.8.1

================================================================================
  Section 1: FIPS Environment Validation (6 tests)
================================================================================

[TEST 1] GOLANG_FIPS environment variable
  ✓ PASS GOLANG_FIPS=1 (FIPS mode enabled)

[TEST 2] GODEBUG environment variable
  ✓ PASS GODEBUG contains fips140=only

[TEST 3] GOEXPERIMENT environment variable
  ✓ PASS GOEXPERIMENT contains strictfipsruntime

[TEST 4] OpenSSL version (3.5.0)
  ✓ PASS OpenSSL version (3.5.0)

[TEST 5] wolfSSL FIPS provider loaded
  ✓ PASS wolfSSL FIPS provider loaded

[TEST 6] wolfSSL FIPS self-test
  ✓ PASS wolfSSL FIPS self-test

================================================================================
  Section 2: Podman Basic Functionality (5 tests)
================================================================================

[TEST 7] Podman version command
  ✓ PASS Podman version command

[TEST 8] Podman help command
  ✓ PASS Podman help command

[TEST 9] Podman images list
  ✓ PASS Podman images list

[TEST 10] Podman ps command
  ✓ PASS Podman ps command

[TEST 11] Podman system df command
  ✓ PASS Podman system df command

================================================================================
  Section 3: Cryptographic Operations (4 tests)
================================================================================

[TEST 12] SHA-256 hash (FIPS-approved)
  ✓ PASS SHA-256 working correctly

[TEST 13] MD5 hash blocking (non-FIPS)
  ✓ PASS MD5 correctly blocked (FIPS enforcement working)

[TEST 14] AES-256-GCM encryption (FIPS-approved)
  ✓ PASS AES-256-GCM working correctly

[TEST 15] RSA-2048 key generation (FIPS-approved)
  ✓ PASS RSA-2048 key generation working

================================================================================
  TEST SUMMARY
================================================================================

Total Tests: 15
Passed: 15
Failed: 0
Duration: 2s

Pass Rate: 100%

Test Results by Section:
  Section 1: FIPS Environment Validation (6 tests)
  Section 2: Podman Basic Functionality (5 tests)
  Section 3: Cryptographic Operations (4 tests)

================================================================================
  ✓ ALL TESTS PASSED - Podman wolfSSL FIPS is production ready
================================================================================
```

## What This Test Validates

### FIPS Compliance
- ✅ **FIPS 140-3 Module**: wolfSSL FIPS v5.8.2 (Certificate #4718)
- ✅ **Go FIPS Runtime**: golang-fips/go v1.25 with strict enforcement
- ✅ **OpenSSL Configuration**: 3.5.0 with FIPS providers (fips, wolfssl, base)
- ✅ **Multi-Layer Enforcement**: 4 independent layers of FIPS validation

### Podman Functionality
- ✅ **Core Commands**: version, help, images, ps, system df
- ✅ **FIPS Integration**: Podman works correctly with FIPS enforcement enabled
- ✅ **No Panics**: golang-fips/go runtime initializes OpenSSL FIPS provider successfully

### Cryptographic Validation
- ✅ **FIPS Algorithms Work**: SHA-256, AES-256-GCM, RSA-2048 functional
- ✅ **Non-FIPS Algorithms Blocked**: MD5 correctly blocked by OpenSSL configuration
- ✅ **Defense-in-Depth**: Multi-layer enforcement prevents non-FIPS crypto

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Podman Application                       │
│              (container management operations)              │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│   Layer 1: golang-fips/go Runtime                          │
│   Enforcement: GODEBUG=fips140=only, GOLANG_FIPS=1        │
└────────────────────────┬────────────────────────────────────┘
                         │ (CGO bridge)
                         ▼
┌─────────────────────────────────────────────────────────────┐
│   Layer 2: OpenSSL Configuration                           │
│   Enforcement: default_properties = fips=yes               │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│   Layer 3: OpenSSL 3.5.0 + Providers                       │
│   Providers: fips, wolfssl, base                           │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│   Layer 4: wolfProvider v1.1.1                             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│   FIPS Boundary: wolfSSL FIPS v5.8.2 (Certificate #4718)  │
└─────────────────────────────────────────────────────────────┘
```

## Use Cases

This test image demonstrates:

1. **Podman with FIPS Enforcement**
   - Podman 5.8.1 runs successfully with golang-fips/go v1.25
   - All cryptographic operations use FIPS-approved algorithms
   - Multi-layer enforcement ensures FIPS compliance

2. **Container Management**
   - Basic Podman commands work correctly
   - No FIPS-related panics or errors
   - Ready for CI/CD and container orchestration

3. **Cryptographic Validation**
   - FIPS-approved algorithms (SHA-256, AES-GCM, RSA) functional
   - Non-FIPS algorithms (MD5) correctly blocked
   - Defense-in-depth strategy validated

## Integration with Base Image

This test image:
- **Extends**: `cr.root.io/podman:5.8.1-fedora-44-fips`
- **Adds**: Simple validation test suite
- **Validates**: FIPS compliance in user application context
- **Demonstrates**: Podman functionality with FIPS enforcement

## Requirements

- Docker 24.0.7+
- Base image: `cr.root.io/podman:5.8.1-fedora-44-fips`

## Building from Source

```bash
# 1. Build base Podman FIPS image first
cd /path/to/podman/5.8.1-fedora-44-fips
./build.sh

# 2. Build test image
cd diagnostics/test-images/basic-test-image
./build.sh

# 3. Run tests
docker run --rm podman-fips-test:latest
```

## Exit Codes

- **0**: All tests passed
- **1**: One or more tests failed

## Troubleshooting

### Test Failures

If tests fail, check:
1. Base image is built correctly
2. FIPS environment variables are set (GOLANG_FIPS, GODEBUG, GOEXPERIMENT)
3. OpenSSL 3.5.0 is present
4. wolfSSL FIPS provider is loaded
5. wolfSSL FIPS self-test passes

### Common Issues

**Issue**: Podman commands fail
- **Solution**: Ensure base image is built with golang-fips/go v1.25 and CGO_ENABLED=1

**Issue**: MD5 not blocked
- **Solution**: Check OpenSSL configuration (/etc/ssl/openssl.cnf) has default_properties = fips=yes

**Issue**: FIPS panic on startup
- **Solution**: Ensure fipsmodule.cnf is generated and OpenSSL FIPS provider is properly configured

## Documentation

For complete documentation, see:
- **Architecture**: `../../../ARCHITECTURE.md`
- **Attestation**: `../../../ATTESTATION.md`
- **POC Validation**: `../../../POC-VALIDATION-REPORT.md`
- **Chain of Custody**: `../../../compliance/CHAIN-OF-CUSTODY.md`

## License

This test image is provided as-is for validation purposes.

## Support

For issues related to:
- **Base image**: See main repository documentation
- **FIPS compliance**: Review ATTESTATION.md and ARCHITECTURE.md
- **Test failures**: Check troubleshooting section above
