# Fedora 44 FIPS Diagnostics Suite

Comprehensive diagnostic tools and test applications for validating FIPS 140-3 compliance in the Fedora 44 minimal base image.

## Overview

This diagnostics suite provides shell-based tools to:
- Validate FIPS compliance with comprehensive cryptographic tests
- Demonstrate FIPS-compliant cryptographic operations
- Test SSL/TLS connections in FIPS mode
- Generate detailed FIPS configuration reports
- Provide multi-stage build examples

**All tools are shell-based** - no language runtimes required!

## Quick Start

### Run All Tests

```bash
docker run --rm cr.root.io/fedora:44-fips \
    /opt/fips/diagnostics/tests/run-all-tests.sh
```

### Run Crypto Demo

```bash
docker run --rm cr.root.io/fedora:44-fips \
    /opt/fips/diagnostics/apps/crypto-demo.sh
```

### Generate FIPS Report

```bash
docker run --rm cr.root.io/fedora:44-fips \
    /opt/fips/diagnostics/apps/fips-report.sh
```

## Directory Structure

```
diagnostics/
├── README.md                          # This file
├── tests/                             # FIPS compliance test scripts
│   ├── run-all-tests.sh              # Master test runner (4 test suites)
│   ├── fips-compliance-advanced.sh   # Advanced crypto tests (44 tests)
│   ├── cipher-suite-test.sh          # TLS cipher suite tests
│   ├── key-size-validation.sh        # Minimum key size tests
│   └── openssl-engine-test.sh        # OpenSSL provider verification
├── apps/                              # Diagnostic applications
│   ├── crypto-demo.sh                # Interactive crypto demonstration
│   ├── ssl-tls-test.sh               # HTTPS/TLS connection testing
│   ├── file-encryption.sh            # File encrypt/decrypt utility
│   └── fips-report.sh                # Comprehensive FIPS report generator
└── examples/                          # Multi-stage build examples
    ├── nodejs-app/                    # Node.js application example
    │   ├── Dockerfile
    │   └── README.md
    └── python-app/                    # Python application example
        ├── Dockerfile
        └── README.md
```

## Test Scripts

### 1. Master Test Runner (`run-all-tests.sh`)

Runs all test suites in sequence and provides a comprehensive summary.

```bash
docker run --rm cr.root.io/fedora:44-fips \
    /opt/fips/diagnostics/tests/run-all-tests.sh
```

**Test Suites:**
- Advanced FIPS Compliance (44 tests)
- Cipher Suite Tests
- Key Size Validation
- OpenSSL Provider Tests

### 2. Advanced FIPS Compliance Test (`fips-compliance-advanced.sh`)

Comprehensive cryptographic algorithm testing.

```bash
docker run --rm cr.root.io/fedora:44-fips \
    /opt/fips/diagnostics/tests/fips-compliance-advanced.sh
```

**Tests (44 total):**
- Hash functions: SHA-224/256/384/512/512-224/512-256
- Non-FIPS hash blocking: MD5, SHA-1, MD4, RIPEMD-160
- Symmetric encryption: AES-128/192/256 (CBC, ECB), 3DES
- Non-FIPS cipher blocking: DES, RC4, Blowfish
- RSA key generation: 2048/3072/4096 bits
- Elliptic curve: P-256, P-384, P-521
- HMAC operations: HMAC-SHA256/384/512
- Random number generation: various sizes

### 3. Cipher Suite Test (`cipher-suite-test.sh`)

Tests TLS/SSL cipher suites for FIPS compliance.

```bash
docker run --rm cr.root.io/fedora:44-fips \
    /opt/fips/diagnostics/tests/cipher-suite-test.sh
```

**Tests:**
- TLS 1.2 FIPS-approved ciphers
- TLS 1.3 cipher suites
- Weak cipher blocking (RC4, DES, NULL)

### 4. Key Size Validation (`key-size-validation.sh`)

Validates minimum key sizes required by FIPS 140-3.

```bash
docker run --rm cr.root.io/fedora:44-fips \
    /opt/fips/diagnostics/tests/key-size-validation.sh
```

**Tests:**
- RSA-1024 rejection (too small)
- RSA-2048/3072/4096 acceptance

### 5. OpenSSL Provider Test (`openssl-engine-test.sh`)

Verifies OpenSSL FIPS provider configuration.

```bash
docker run --rm cr.root.io/fedora:44-fips \
    /opt/fips/diagnostics/tests/openssl-engine-test.sh
```

**Displays:**
- OpenSSL version and configuration
- Loaded providers (verbose)
- Crypto-policies status
- Environment variables
- Available algorithms

## Diagnostic Applications

### 1. Crypto Demo (`crypto-demo.sh`)

Interactive demonstration of FIPS-compliant cryptographic operations.

```bash
docker run --rm cr.root.io/fedora:44-fips \
    /opt/fips/diagnostics/apps/crypto-demo.sh
```

**Demonstrations:**
1. Hash functions (SHA-256/384/512)
2. Symmetric encryption/decryption (AES-256-CBC)
3. HMAC authentication
4. Random number generation
5. RSA key generation and digital signatures

### 2. SSL/TLS Test (`ssl-tls-test.sh`)

Tests HTTPS connections in FIPS mode.

```bash
docker run --rm cr.root.io/fedora:44-fips \
    /opt/fips/diagnostics/apps/ssl-tls-test.sh
```

**Tests:**
- Basic HTTPS connection
- TLS 1.2/1.3 protocol versions
- Negotiated cipher suites
- Certificate verification

### 3. File Encryption Utility (`file-encryption.sh`)

Encrypt and decrypt files using FIPS-approved algorithms.

```bash
# Encrypt a file
docker run --rm -v $(pwd):/data cr.root.io/fedora:44-fips \
    /opt/fips/diagnostics/apps/file-encryption.sh encrypt /data/file.txt /data/file.enc mypassword

# Decrypt a file
docker run --rm -v $(pwd):/data cr.root.io/fedora:44-fips \
    /opt/fips/diagnostics/apps/file-encryption.sh decrypt /data/file.enc /data/file.txt mypassword
```

**Features:**
- AES-256-CBC encryption
- PBKDF2 key derivation
- Salt for security
- Password-based encryption

### 4. FIPS Report Generator (`fips-report.sh`)

Generates comprehensive FIPS configuration report.

```bash
docker run --rm -v $(pwd):/reports cr.root.io/fedora:44-fips \
    sh -c 'cd /reports && /opt/fips/diagnostics/apps/fips-report.sh'
```

**Report Sections:**
- System information
- OpenSSL version and configuration
- Crypto-policies status
- Loaded providers (detailed)
- Environment variables
- Available algorithms
- FIPS cipher suites
- Quick validation tests

## Multi-Stage Build Examples

### Node.js Application Example

Build a FIPS-compliant Node.js application:

```bash
cd diagnostics/examples/nodejs-app
docker build -t my-nodejs-fips-app .
docker run -it --rm my-nodejs-fips-app
```

See [nodejs-app/README.md](examples/nodejs-app/README.md) for details.

### Python Application Example

Build a FIPS-compliant Python application:

```bash
cd diagnostics/examples/python-app
docker build -t my-python-fips-app .
docker run -it --rm my-python-fips-app
```

See [python-app/README.md](examples/python-app/README.md) for details.

## Usage in CI/CD

### Example: Run Tests in CI

```yaml
# .github/workflows/fips-validation.yml
name: FIPS Validation
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run FIPS Tests
        run: |
          docker run --rm cr.root.io/fedora:44-fips \
            /opt/fips/diagnostics/tests/run-all-tests.sh
```

### Example: Generate FIPS Report

```bash
#!/bin/bash
# Generate FIPS report for compliance audit
docker run --rm -v $(pwd)/reports:/reports cr.root.io/fedora:44-fips \
    sh -c 'cd /reports && /opt/fips/diagnostics/apps/fips-report.sh'

echo "FIPS report generated in ./reports/"
ls -lh ./reports/fips-report-*.txt
```

## Test Results

### Expected Test Results

When all tests pass, you should see:

```
================================================================
              MASTER TEST SUITE SUMMARY
================================================================

  Total Test Suites: 4
  Passed:            4
  Failed:            0

╔════════════════════════════════════════════════════════╗
║                                                        ║
║          ✓ ALL TEST SUITES PASSED                     ║
║                                                        ║
║   FIPS 140-3 compliance validated successfully!       ║
║                                                        ║
╚════════════════════════════════════════════════════════╝
```

### Individual Test Counts

- **Advanced FIPS Compliance**: 44 tests
- **Cipher Suite Tests**: ~20 tests
- **Key Size Validation**: 4 tests
- **OpenSSL Provider**: Informational (no pass/fail)

**Total**: ~68 automated tests

## Troubleshooting

### FIPS Provider Not Loaded

If tests fail with "FIPS provider not loaded":

```bash
# Check crypto-policies
docker run --rm cr.root.io/fedora:44-fips cat /etc/crypto-policies/config

# Check OpenSSL providers
docker run --rm cr.root.io/fedora:44-fips openssl list -providers

# Check environment
docker run --rm cr.root.io/fedora:44-fips env | grep FIPS
```

### MD5/SHA-1 Not Blocked

If non-FIPS algorithms are not blocked:

```bash
# Verify OPENSSL_FORCE_FIPS_MODE is set
docker run --rm cr.root.io/fedora:44-fips \
    sh -c 'echo $OPENSSL_FORCE_FIPS_MODE'

# Should output: 1
```

### Test Failures

If any test fails:

1. Run individual test scripts to isolate the issue
2. Generate FIPS report for detailed analysis
3. Check OpenSSL provider status
4. Verify crypto-policies configuration

## Benefits

- **Comprehensive**: 68+ automated tests covering all FIPS requirements
- **Shell-Based**: No language runtimes required - minimal dependencies
- **Easy to Use**: Single command to run all tests
- **CI/CD Ready**: Exit codes for automation
- **Informative**: Detailed output with pass/fail indicators
- **Documented**: Examples for common use cases

## See Also

- [Fedora 44 FIPS Base Image](../README.md)
- [Multi-Stage Build: Node.js](examples/nodejs-app/README.md)
- [Multi-Stage Build: Python](examples/python-app/README.md)
- [FIPS Verification Script](../src/fips_init_check.sh)

## Contributing

To add new diagnostic tests or applications:

1. Create script in `tests/` or `apps/`
2. Make it executable (`chmod +x`)
3. Add to master test runner if applicable
4. Update this README
5. Test in the container environment

## Support

For issues or questions about the diagnostics suite:
- Check the base image [README](../README.md)
- Review test output for specific errors
- Generate FIPS report for detailed analysis
