# Gotenberg FIPS Test Image

**Purpose**: Test application image to validate Gotenberg FIPS functionality in real-world scenarios.

## Overview

This test image contains a comprehensive test suite that validates:

- OpenSSL 3.0.19 with wolfSSL FIPS provider verification
- HTML → PDF conversion via Gotenberg API
- Office document → PDF conversion (DOCX, XLSX, PPTX)
- FIPS-approved TLS cipher validation
- PDF manipulation operations (merge, convert)
- Runtime FIPS mode enforcement

## Architecture

```
┌─────────────────────────────────────────┐
│  Test Application (Go)                  │
│  - FIPS provider verification           │
│  - API connectivity tests                │
│  - PDF conversion tests                  │
│  - TLS cipher validation                 │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│  Gotenberg FIPS Service                 │
│  - OpenSSL 3.0.19                       │
│  - wolfSSL FIPS v5.8.2                  │
│  - golang-fips/go v1.26.2               │
└─────────────────────────────────────────┘
```

## Building

### Prerequisites

1. Build the base Gotenberg FIPS image first:
   ```bash
   cd ../../../
   ./build.sh
   ```

2. Ensure Docker BuildKit is enabled:
   ```bash
   export DOCKER_BUILDKIT=1
   ```

### Build Test Image

```bash
./build.sh
```

This creates: `gotenberg-test:8.26.0-trixie-slim-fips`

## Usage

### 1. Standalone Tests (FIPS Verification Only)

Run FIPS provider verification without Gotenberg service:

```bash
docker run --rm gotenberg-test:8.26.0-trixie-slim-fips --fips-only
```

Expected output:
```
✓ PASS: OpenSSL 3.0.19 detected
✓ PASS: wolfSSL FIPS provider active
✓ PASS: FIPS mode enforced (fips=yes)
✓ PASS: CGO_ENABLED=1
✓ PASS: GOLANG_FIPS=1
```

### 2. Full Test Suite (With Gotenberg Service)

#### Step 1: Create Docker network
```bash
docker network create gotenberg-test-net
```

#### Step 2: Start Gotenberg FIPS service
```bash
docker run -d \
  --name gotenberg-svc \
  --network gotenberg-test-net \
  -p 3000:3000 \
  gotenberg:8.26.0-trixie-slim-fips
```

#### Step 3: Run test suite
```bash
docker run --rm \
  --network gotenberg-test-net \
  gotenberg-test:8.26.0-trixie-slim-fips \
  --gotenberg-url http://gotenberg-svc:3000 \
  --all
```

#### Step 4: Cleanup
```bash
docker stop gotenberg-svc
docker rm gotenberg-svc
docker network rm gotenberg-test-net
```

### 3. Individual Test Categories

Run specific test categories:

```bash
# FIPS verification only
docker run --rm gotenberg-test:8.26.0-trixie-slim-fips --test=fips

# HTML to PDF conversion
docker run --rm --network gotenberg-test-net \
  gotenberg-test:8.26.0-trixie-slim-fips \
  --gotenberg-url http://gotenberg-svc:3000 \
  --test=html-pdf

# Office to PDF conversion
docker run --rm --network gotenberg-test-net \
  gotenberg-test:8.26.0-trixie-slim-fips \
  --gotenberg-url http://gotenberg-svc:3000 \
  --test=office-pdf

# TLS cipher validation
docker run --rm --network gotenberg-test-net \
  gotenberg-test:8.26.0-trixie-slim-fips \
  --gotenberg-url http://gotenberg-svc:3000 \
  --test=tls

# PDF operations (merge, convert)
docker run --rm --network gotenberg-test-net \
  gotenberg-test:8.26.0-trixie-slim-fips \
  --gotenberg-url http://gotenberg-svc:3000 \
  --test=pdf-ops
```

## Test Coverage

### FIPS Verification Tests (5 tests)
- ✓ OpenSSL version 3.0.19
- ✓ wolfSSL FIPS provider loaded
- ✓ FIPS mode enforced (default_properties = fips=yes)
- ✓ CGO_ENABLED=1
- ✓ GOLANG_FIPS=1

### Connectivity Tests (3 tests)
- ✓ Health endpoint accessibility
- ✓ Version endpoint validation
- ✓ Service readiness check

### HTML to PDF Tests (4 tests)
- ✓ Simple HTML → PDF conversion
- ✓ HTML with CSS → PDF conversion
- ✓ HTML with images → PDF conversion
- ✓ URL → PDF conversion

### Office to PDF Tests (3 tests)
- ✓ DOCX → PDF conversion
- ✓ XLSX → PDF conversion
- ✓ PPTX → PDF conversion

### TLS Cipher Tests (3 tests)
- ✓ TLS 1.2 with FIPS ciphers
- ✓ TLS 1.3 with FIPS ciphers
- ✓ Non-FIPS cipher rejection

### PDF Operations Tests (3 tests)
- ✓ PDF merge operation
- ✓ PDF metadata extraction
- ✓ PDF format validation

**Total: 21 tests**

## Expected Results

```
================================================================================
Gotenberg FIPS Test Suite
================================================================================

FIPS Verification:       5/5 ✓
Connectivity:            3/3 ✓
HTML to PDF:             4/4 ✓
Office to PDF:           3/3 ✓
TLS Cipher Validation:   3/3 ✓
PDF Operations:          3/3 ✓

--------------------------------------------------------------------------------
Total: 21/21 tests passed
Status: ✓ ALL TESTS PASSED
================================================================================
```

## Troubleshooting

### Base image not found
```
Error: Base image 'gotenberg:8.26.0-trixie-slim-fips' not found
```

**Solution**: Build the base image first:
```bash
cd ../../../
./build.sh
```

### Test failures
If tests fail, check:

1. Gotenberg service is running:
   ```bash
   docker ps | grep gotenberg-svc
   ```

2. Network connectivity:
   ```bash
   docker network inspect gotenberg-test-net
   ```

3. Service health:
   ```bash
   curl http://localhost:3000/health
   ```

## FIPS Compliance

This test image validates FIPS 140-3 compliance using:

- **OpenSSL 3.0.19** - Custom build with FIPS support
- **wolfSSL FIPS v5.8.2** - NIST Certificate #4718
- **wolfProvider v1.1.0** - OpenSSL 3.0 provider interface
- **golang-fips/go v1.26.2** - FIPS-enabled Go compiler

All cryptographic operations route through the FIPS 140-3 validated wolfSSL module.

## Related Documentation

- [OPENSSL-VERIFICATION.md](../../../OPENSSL-VERIFICATION.md) - Runtime OpenSSL verification
- [POC-VALIDATION-REPORT.md](../../../POC-VALIDATION-REPORT.md) - Comprehensive validation report
- [SLSA-ATTESTATION.md](../../../SLSA-ATTESTATION.md) - Supply chain attestation

## License

This test suite is part of the Gotenberg FIPS attestation project.
