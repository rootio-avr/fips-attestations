# ASP.NET FIPS Diagnostic Suite

Comprehensive diagnostic tests for ASP.NET Core wolfSSL FIPS 140-3 integration.

## Overview

This diagnostic suite validates that ASP.NET Core 8.0.25 correctly uses FIPS-compliant cryptography through:
- OpenSSL 3.3.7 (custom FIPS-enabled build)
- wolfProvider v1.1.0 (OpenSSL 3 provider)
- wolfSSL FIPS v5.8.2 (CMVP Certificate #4718)

**Note:** The main entry point `diagnostic.sh` is located in the parent directory (`../diagnostic.sh`) and automatically runs all test suites from this diagnostics folder. You can also run individual test scripts directly from within this directory.

## Quick Start

### Running in Docker (Recommended)

The diagnostic script is designed to run inside the FIPS-enabled ASP.NET container:

```bash
# Build the image first (if not already available)
cd aspnet/8.0.25-bookworm-slim-fips
docker build -t cr.root.io/aspnet:8.0.25-bookworm-slim-fips .

# Run full diagnostic suite (all 65 tests)
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips ./diagnostic.sh

# Run quick status check only (10 tests)
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips ./diagnostic.sh --status

# Run crypto operations only (20 tests)
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips ./diagnostic.sh --crypto

# Show help and all options
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips ./diagnostic.sh --help

# Run with verbose output
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips ./diagnostic.sh --verbose
```

### Running Inside Container

If you need to run tests interactively or debug:

```bash
# Start interactive shell in container
docker run -it --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips /bin/bash

# Inside the container, run diagnostic script (from image root)
./diagnostic.sh                  # Run all tests (65 tests)
./diagnostic.sh --status         # Quick status check only (10 tests)
./diagnostic.sh --crypto         # Crypto operations only (20 tests)

# Or navigate to diagnostics directory for individual tests
cd diagnostics
./run-all-tests.sh                              # Run all test suites
./test-aspnet-fips-status.sh                    # 10 status checks
dotnet-script test-backend-verification.cs       # 10 backend tests
dotnet-script test-fips-verification.cs          # 10 FIPS tests
dotnet-script test-crypto-operations.cs          # 20 crypto tests
dotnet-script test-connectivity.cs               # 15 connectivity tests
```

## Test Suites

### 1. test-aspnet-fips-status.sh ✅
**Shell-based FIPS status check**

**Tests (10):**
- Environment variables (LD_LIBRARY_PATH, OPENSSL_CONF, OPENSSL_MODULES)
- Dynamic linker configuration
- OpenSSL binary version
- wolfProvider module loading
- wolfSSL FIPS library presence
- .NET runtime version
- .NET OpenSSL interop layer
- FIPS module files
- OpenSSL configuration
- FIPS startup utility

**Usage:**
```bash
./test-aspnet-fips-status.sh
```

**Output:** Pass/Fail with detailed status
**Exit Code:** 0 = pass, 1 = fail

---

### 2. test-backend-verification.cs ✅
**OpenSSL backend integration tests**

**Tests (10):**
1. OpenSSL version detection
2. Library path verification (ldconfig)
3. OpenSSL provider enumeration
4. FIPS module presence
5. Dynamic linker configuration
6. Environment variable validation
7. .NET → OpenSSL interop layer
8. Certificate store access
9. Cipher suite availability
10. OpenSSL command execution

**Usage:**
```bash
# Requires dotnet-script
dotnet-script test-backend-verification.cs

# Or with installed dotnet-script
./test-backend-verification.cs
```

**Output:** JSON results + console summary
**Results File:** `backend-verification-results.json`

---

### 3. test-fips-verification.cs ✅
**FIPS module validation tests**

**Tests (10):**
1. FIPS mode detection
2. wolfSSL FIPS module version
3. CMVP certificate validation (#4718)
4. FIPS POST verification
5. FIPS-approved algorithms
6. Non-approved algorithm blocking
7. Configuration file validation
8. wolfProvider FIPS mode
9. FIPS error handling
10. Cryptographic boundary validation

**Usage:**
```bash
dotnet-script test-fips-verification.cs
```

**Output:** JSON results + console summary
**Results File:** `fips-verification-results.json`

---

### 4. test-crypto-operations.cs ✅
**Comprehensive cryptographic operations tests**

**Tests (20):**
1. SHA-256 Hashing
2. SHA-384 Hashing
3. SHA-512 Hashing
4. AES-128-GCM Encryption
5. AES-256-GCM Encrypt/Decrypt
6. AES-256-CBC Encrypt/Decrypt
7. RSA-2048 Key Generation
8. RSA-2048 Encrypt/Decrypt
9. RSA-2048 Digital Signature
10. ECDSA P-256 Key Generation
11. ECDSA P-256 Sign/Verify
12. ECDSA P-384 Sign/Verify
13. HMAC-SHA256
14. HMAC-SHA512
15. PBKDF2-SHA256 Key Derivation
16. Random Number Generation
17. ECDH P-256 Key Exchange
18. ECDH P-384 Key Exchange
19. RSA-PSS Signature
20. Multi-Algorithm Chain Test

**Usage:**
```bash
dotnet-script test-crypto-operations.cs
```

**Output:** JSON results + console summary
**Results File:** `crypto-operations-results.json`

---

### 5. test-connectivity.cs ✅
**TLS/HTTPS connectivity tests**

**Tests (15):**
1. Basic HTTPS GET Request
2. HTTPS with Custom Headers
3. HTTPS POST Request
4. TLS Protocol Detection (TLS 1.2/1.3)
5. Certificate Chain Validation
6. Concurrent HTTPS Connections
7. HTTPS Timeout Handling
8. HTTPS Redirect Following
9. HTTPS with Compression
10. HTTPS Response Headers
11. HTTPS Large Response
12. HTTPS Query Parameters
13. HTTPS Connection Reuse
14. HTTPS Content Types (JSON/HTML/XML)
15. TLS SNI Support

**Usage:**
```bash
dotnet-script test-connectivity.cs
```

**Output:** JSON results + console summary
**Results File:** `connectivity-results.json`

---

### 6. run-all-tests.sh ✅
**Master test runner**

Executes all test suites in order and generates a summary report.
Called by `../diagnostic.sh` wrapper for full test execution.

**Usage:**
```bash
./run-all-tests.sh
```

**Output:**
```
================================================================
  ASP.NET wolfSSL FIPS Diagnostic Test Suite
================================================================

Test Suite 1: ASP.NET FIPS Status
------------------------------------------------------------
✓ ASP.NET FIPS Status: PASSED

Test Suite 2: Backend Verification
------------------------------------------------------------
✓ Backend Verification: PASSED

Test Suite 3: FIPS Verification
------------------------------------------------------------
✓ FIPS Verification: PASSED

Test Suite 4: Cryptographic Operations
------------------------------------------------------------
✓ Crypto Operations: PASSED

Test Suite 5: TLS/HTTPS Connectivity
------------------------------------------------------------
✓ Connectivity: PASSED

================================================================
✓ ALL TEST SUITES PASSED (5/5)
================================================================
FIPS Compliance: VERIFIED
Certificate: #4718 (wolfSSL FIPS v5)
Total Tests: 65 (10 status + 10 backend + 10 FIPS + 20 crypto + 15 connectivity)
================================================================
```

---

## Directory Structure

```
aspnet/8.0.25-bookworm-slim-fips/
├── diagnostic.sh                      # Main diagnostic runner with options ⭐
├── Dockerfile                         # FIPS-enabled ASP.NET image
├── docker-entrypoint.sh               # Container entrypoint
└── diagnostics/
    ├── README.md                      # This file
    ├── IMPLEMENTATION-GUIDE.md        # Complete implementation guide
    ├── run-all-tests.sh               # Master test runner (5 suites)
    ├── generate-all-tests.sh          # Test generator script
    ├── test-aspnet-fips-status.sh     # Shell status check (10 tests)
    ├── test-backend-verification.cs   # Backend integration tests (10 tests)
    ├── test-fips-verification.cs      # FIPS validation tests (10 tests)
    ├── test-crypto-operations.cs      # Cryptographic operations (20 tests)
    ├── test-connectivity.cs           # TLS/HTTPS connectivity (15 tests)
    ├── *.json                         # Test result files
    └── test-images/                   # Test container images (pending)
        └── basic-test-image/
            ├── Dockerfile
            ├── build.sh
            ├── README.md
            └── src/
                ├── FipsUserApplication.cs
                ├── CryptoTestSuite.cs
                └── TlsTestSuite.cs
```

---

## Requirements

### Runtime Requirements
- ASP.NET Core Runtime 8.0.25
- OpenSSL 3.3.7 (FIPS-enabled)
- wolfSSL FIPS v5.8.2
- wolfProvider v1.1.0

### Testing Requirements
- Bash shell
- `dotnet-script` (for C# script tests)
  ```bash
  dotnet tool install -g dotnet-script
  ```
- Standard Linux utilities (ldconfig, ldd, etc.)

---

## Test Results

All tests generate JSON output following this schema:

```json
{
  "test_area": "1-backend-verification",
  "timestamp": "2026-04-22T08:30:00Z",
  "container": "cr.root.io/aspnet:8.0.25-bookworm-slim-fips",
  "total_tests": 10,
  "passed": 10,
  "failed": 0,
  "skipped": 0,
  "tests": [
    {
      "id": "1.1",
      "name": "OpenSSL Version Detection",
      "status": "pass",
      "duration_ms": 45,
      "details": "OpenSSL 3.3.7 detected"
    }
  ]
}
```

---

## Running in Container

```bash
# Run full diagnostic suite in FIPS container
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips ./diagnostic.sh

# Run quick status check only
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips ./diagnostic.sh --status

# Run crypto operations only
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips ./diagnostic.sh --crypto

# Mount local directory for custom tests
docker run --rm \
    -v $(pwd)/diagnostics:/app/diagnostics \
    cr.root.io/aspnet:8.0.25-bookworm-slim-fips \
    /app/diagnostics/run-all-tests.sh
```

---

## Troubleshooting

### Issue: dotnet-script not found
**Solution:** Install dotnet-script globally:
```bash
dotnet tool install -g dotnet-script
export PATH="$PATH:$HOME/.dotnet/tools"
```

### Issue: Permission denied
**Solution:** Make scripts executable:
```bash
chmod +x *.sh *.cs
```

### Issue: Tests fail with "OpenSSL not found"
**Solution:** Check environment variables:
```bash
echo $LD_LIBRARY_PATH
echo $OPENSSL_CONF
echo $OPENSSL_MODULES
```

Should see:
```
LD_LIBRARY_PATH=/usr/local/openssl/lib:/usr/local/lib
OPENSSL_CONF=/usr/local/openssl/ssl/openssl.cnf
OPENSSL_MODULES=/usr/local/openssl/lib/ossl-modules
```

### Issue: Tests fail with "wolfProvider not loaded"
**Solution:** Verify wolfProvider installation:
```bash
ls -la /usr/local/openssl/lib/ossl-modules/libwolfprov.so
openssl list -providers
```

---

## Extending Tests

To add new tests, follow the pattern in existing test files:

1. **Create test file** (e.g., `test-my-feature.cs`)
2. **Use common structure:**
   ```csharp
   #r "nuget: System.Text.Json, 8.0.0"
   // ... test implementation
   ```
3. **Add to run-all-tests.sh:**
   ```bash
   if dotnet-script test-my-feature.cs; then
       PASSED_TESTS=$((PASSED_TESTS + 1))
   else
       FAILED_TESTS=$((FAILED_TESTS + 1))
   fi
   ```

---

## Test Image

For comprehensive application-level testing, use the test image:

```bash
cd test-images/basic-test-image
./build.sh
docker run --rm cr.root.io/aspnet-fips-test:latest
```

See `test-images/basic-test-image/README.md` for details.

---

## CI/CD Integration

### GitLab CI
```yaml
test-fips-compliance:
  stage: test
  image: cr.root.io/aspnet:8.0.25-bookworm-slim-fips
  script:
    - ./diagnostic.sh
  artifacts:
    reports:
      junit: diagnostics/*.json
    paths:
      - diagnostics/*.json

# Quick status check (faster for PR checks)
test-fips-status:
  stage: test
  image: cr.root.io/aspnet:8.0.25-bookworm-slim-fips
  script:
    - ./diagnostic.sh --status
```

### GitHub Actions
```yaml
- name: Run Full FIPS Diagnostics
  run: ./diagnostic.sh

- name: Upload Test Results
  if: always()
  uses: actions/upload-artifact@v3
  with:
    name: fips-test-results
    path: diagnostics/*.json
```

### Jenkins
```groovy
stage('FIPS Compliance Tests') {
    agent {
        docker {
            image 'cr.root.io/aspnet:8.0.25-bookworm-slim-fips'
        }
    }
    steps {
        sh './diagnostic.sh'
    }
    post {
        always {
            archiveArtifacts artifacts: 'diagnostics/*.json'
        }
    }
}
```

---

## Support

For issues or questions:
1. Check IMPLEMENTATION-GUIDE.md for detailed documentation
2. Examine test output JSON files for specific failures
3. Check container logs for runtime errors

---

## Status

| Component | Status | Tests |
|-----------|--------|-------|
| Shell Status Check | ✅ Complete | 10/10 |
| Backend Verification | ✅ Complete | 10/10 |
| FIPS Verification | ✅ Complete | 10/10 |
| Crypto Operations | ✅ Complete | 20/20 |
| Connectivity Tests | ✅ Complete | 15/15 |
| Master Test Runner | ✅ Complete | 5 suites |
| Library Compatibility | ⏳ Pending | 10 planned |
| Test Image | ⏳ Pending | - |

**Total:** 65/65 core tests implemented
**Coverage:** Backend + FIPS + Crypto + Connectivity validation complete
**Status:** ✅ **PRODUCTION READY**

---

**Last Updated:** 2026-04-22
**Version:** 1.0.0
**Maintainer:** FIPS Team
