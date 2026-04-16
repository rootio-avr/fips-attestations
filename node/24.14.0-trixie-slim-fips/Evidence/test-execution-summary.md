# Test Execution Summary - Node.js

**Image:** node:24.14.0-trixie-slim-fips
**Test Date:** 2026-04-15
**Execution Environment:** Docker on Linux (linux/amd64 image)

---

## Overview

This document summarizes all test executions performed against the Node.js container image
to validate FIPS compliance and security requirements.

---

## Test Suite Results

### Master Test Runner

**Script:** `diagnostics/run-all-tests.sh` (via `diagnostic.sh`)
**Total Suites:** 5
**Status:** ✅ **32/32 CORE TESTS PASSED (100%)**

| # | Test Suite | Script | Status | Sub-tests | Pass Rate |
|---|------------|--------|--------|-----------|-----------|
| 1 | Backend Verification | `test-backend-verification.js` | ✅ PASS | 6/6 | 100% |
| 2 | Connectivity | `test-connectivity.js` | ✅ PASS | 8/8 | 100% |
| 3 | FIPS Verification | `test-fips-verification.js` | ✅ PASS | 6/6 | 100% |
| 4 | Crypto Operations | `test-crypto-operations.js` | ✅ PASS | 8/8 | 100% |
| 5 | Library Compatibility | `test-library-compatibility.js` | ✅ PASS | 4/4 core | 100% |

**Total Execution Time:** ~30-60 seconds

**Additional Test Artifacts:**
- FIPS KAT Tests: `/test-fips` executable (all KAT tests pass)
- Test Image: `node-fips-test:latest` (15/15 tests, 100% pass rate)
- Demo Applications: 4 interactive demos (all functional)

---

## Detailed Test Results

### Test 1: Backend Verification (`test-backend-verification.js`)

**Purpose:** Verify all wolfSSL FIPS components are present, libraries are accessible, OpenSSL configuration is correct, and environment variables are properly set.

**Execution:**
```bash
./diagnostic.sh test-backend-verification.js
```

**Results (6/6 sub-tests passed):**
- ✅ Node.js version reporting (v24.14.1)
- ✅ wolfSSL FIPS library found at `/usr/local/lib/libwolfssl.so` (779 KB)
- ✅ wolfProvider library found at `/usr/local/openssl/lib64/ossl-modules/libwolfprov.so` (1027 KB)
- ✅ OpenSSL configuration found at `/etc/ssl/openssl.cnf`
- ✅ wolfProvider configured in `openssl.cnf` (provider activation and FIPS mode)
- ✅ All required environment variables set (`OPENSSL_CONF`, `OPENSSL_MODULES`)

**Provider stack confirmed:** wolfProvider v1.1.1 for OpenSSL 3.5.0, Node.js 24.14.1 dynamically linked

---

### Test 2: Connectivity (`test-connectivity.js`)

**Purpose:** Validate TLS/SSL connections use only FIPS-approved protocols and cipher suites, with proper certificate validation.

**Execution:**
```bash
./diagnostic.sh test-connectivity.js
```

**Results (8/8 sub-tests passed):**
- ✅ Basic HTTPS GET request successful (www.google.com)
- ✅ TLS protocol support confirmed (TLSv1.3, TLS_AES_256_GCM_SHA384)
- ✅ TLS 1.2 protocol support confirmed (cipher: ECDHE-RSA-AES128-GCM-SHA256)
- ✅ TLS 1.3 protocol support confirmed (cipher: TLS_AES_256_GCM_SHA384)
- ✅ Certificate validation working (chain validation successful)
- ✅ FIPS cipher suite negotiation verified (TLS_AES_256_GCM_SHA384)
- ✅ Concurrent connections (3/3 successful)
- ✅ HTTPS POST request successful (httpbin.org)

**Key Finding:** All TLS connections use FIPS-approved cipher suites; 0 weak cipher suites negotiated.

---

### Test 3: FIPS Verification (`test-fips-verification.js`)

**Purpose:** Confirm FIPS provider registration, FIPS mode enabled, protocol support, and cipher compliance.

**Execution:**
```bash
./diagnostic.sh test-fips-verification.js
```

**Results (6/6 sub-tests passed):**
- ✅ FIPS mode status: 4 indicators found (wolfSSL, wolfProvider, FIPS test, config)
- ✅ FIPS self-test execution: KATs passed successfully
- ✅ FIPS-approved algorithms: SHA256, SHA384, SHA512, 3 AES-GCM ciphers
- ✅ Cipher suite FIPS compliance: 30 FIPS-approved ciphers available
- ✅ FIPS boundary check: wolfSSL 5.8.2 (Certificate #4718) validated
- ✅ Non-FIPS algorithm rejection: MD5 blocked, SHA-1 available for legacy

**FIPS Evidence:**
- wolfProvider active in OpenSSL 3.5
- FIPS mode enabled at runtime (`crypto.getFips()` returns 1)
- All TLS protocols use FIPS-approved cipher suites

---

### Test 4: Crypto Operations (`test-crypto-operations.js`)

**Purpose:** Verify FIPS-approved cryptographic operations (hash, HMAC, cipher, random) work correctly via wolfProvider.

**Execution:**
```bash
./diagnostic.sh test-crypto-operations.js
```

**Results (8/8 sub-tests passed):**
- ✅ SHA-256 hash generation: PASS
- ✅ SHA-384 hash generation: PASS
- ✅ SHA-512 hash generation: PASS
- ✅ HMAC-SHA256 operations: PASS
- ✅ Random bytes generation: PASS (32 bytes generated)
- ✅ AES-256-GCM encryption/decryption: PASS
- ✅ FIPS-approved cipher availability: PASS (AES-256-GCM available)
- ✅ MD5 rejection: PASS (properly blocked with error)

**Algorithm Evidence:**
- SHA-256/384/512: Fully functional (FIPS-approved)
- AES-256-GCM: Encryption/decryption successful (FIPS-approved)
- HMAC-SHA256: Operational (FIPS-approved)
- MD5: Blocked at crypto level (correct FIPS 140-3 behavior)

---

### Test 5: Library Compatibility (`test-library-compatibility.js`)

**Purpose:** Confirm Node.js applications using built-in libraries work correctly with FIPS-enabled Node.js.

**Execution:**
```bash
./diagnostic.sh test-library-compatibility.js
```

**Results (4/4 core tests passed):**
- ✅ Built-in https module: HTTPS requests work correctly
- ✅ Built-in crypto module: All operations work correctly
- ✅ Built-in tls module: TLS connections work correctly
- ✅ Buffer/crypto integration: All buffer operations work correctly

**Note:** Core crypto functionality always passes. Optional third-party library tests (axios, node-fetch) were skipped as they are not installed in the base image.

---

## Integration Tests

### FIPS KAT Test

**Execution:**
```bash
docker run --rm cr.root.io/node:24.14.0-trixie-slim-fips /test-fips
```

**Results:** ✅ PASS
- All FIPS Known Answer Tests (KAT) passed successfully
- Hash algorithms (SHA-256, SHA-384, SHA-512): PASS
- Symmetric ciphers (AES-128-CBC, AES-256-CBC, AES-256-GCM): PASS
- HMAC operations (HMAC-SHA256, HMAC-SHA384): PASS
- Asymmetric algorithms (RSA 2048, ECDSA P-256): PASS

---

### Test Image Validation

**Execution:**
```bash
cd diagnostics/test-images/basic-test-image
./build.sh
docker run --rm node-fips-test:latest
```

**Results:** ✅ 15/15 TESTS PASSED (100%)
- Cryptographic Operations Test Suite: 9/9 passed
- TLS/SSL Test Suite: 6/6 passed
- Overall: Production ready status confirmed

**Test Image Output:**
```
================================================================================
  Node.js wolfSSL FIPS 140-3 User Application Test
================================================================================

Running: Cryptographic Operations Test Suite
  ✓ SHA-256 Hash Generation: PASS
  ✓ SHA-384 Hash Generation: PASS
  ✓ SHA-512 Hash Generation: PASS
  ✓ HMAC-SHA256 Operations: PASS
  ✓ AES-256-GCM Encryption: PASS
  ✓ Random Bytes Generation: PASS
  ✓ PBKDF2 Key Derivation: PASS
  ✓ FIPS Cipher Availability: PASS
  ✓ Hash Algorithm Variety: PASS
Crypto Tests: 9/9 passed

Running: TLS/SSL Test Suite
  ✓ HTTPS Connection: PASS
  ✓ TLS 1.2 Protocol: PASS
  ✓ TLS 1.3 Protocol: PASS
  ✓ Certificate Validation: PASS
  ✓ FIPS Cipher Negotiation: PASS (TLS_AES_256_GCM_SHA384)
  ✓ HTTPS POST Request: PASS
TLS Tests: 6/6 passed

================================================================================
  FINAL TEST SUMMARY
================================================================================
  Total Test Suites: 2
  Passed: 2
  Failed: 0

  ✓ ALL TESTS PASSED - Node.js wolfSSL FIPS is production ready
```

---

### Demo Applications

**Build:**
```bash
cd demos-image
./build.sh
```

**Demo 1: Hash Algorithm Demo**
```bash
docker run --rm node-fips-demos:24.14.0 node /opt/demos/hash_algorithm_demo.js
```
**Results:** ✅ PASS - All hash algorithms (SHA-256/384/512, MD5 rejection) demonstrated

**Demo 2: TLS/SSL Client Demo**
```bash
docker run --rm node-fips-demos:24.14.0 node /opt/demos/tls_ssl_client_demo.js
```
**Results:** ✅ PASS - TLS 1.2/1.3 connections, cipher suite negotiation demonstrated

**Demo 3: Certificate Validation Demo**
```bash
docker run --rm node-fips-demos:24.14.0 node /opt/demos/certificate_validation_demo.js
```
**Results:** ✅ PASS - Certificate chain validation, hostname verification demonstrated

**Demo 4: HTTPS Request Demo**
```bash
docker run --rm node-fips-demos:24.14.0 node /opt/demos/https_request_demo.js
```
**Results:** ✅ PASS - HTTPS GET/POST requests with FIPS-approved ciphers demonstrated

---

## Performance Metrics

| Metric | Value | Notes |
|--------|-------|-------|
| Image Size | ~320 MB | Includes Node.js 24.14.1 + wolfSSL FIPS + wolfProvider (linux/amd64) |
| Build Time | ~12 minutes | Multi-stage Docker build (no Node.js compilation) |
| Cold Start Time | <2s | Container startup to application ready |
| FIPS Validation Time | <1s | wolfProvider initialization and KAT tests |
| Test Suite Duration | ~30-60 sec | All 5 diagnostic test suites |

**Performance Comparison:**
- **Fastest FIPS Build**: Node.js (~12 min) < Java (~15 min) < Python (~25 min)
- **Smallest Image**: Node.js (~320 MB) < Java (~350 MB) < Python (~400 MB)
- **Key Advantage**: Provider-based architecture eliminates Node.js source compilation

---

## Evidence Files Generated

| File | Purpose | Location |
|------|---------|----------|
| **diagnostic_results.txt** | Complete raw test outputs | `Evidence/` |
| **contrast-test-results.md** | FIPS on/off comparison | `Evidence/` |
| **test-execution-summary.md** | This document | `Evidence/` |

---

## Compliance Mapping

### POC Requirements

| Requirement | Test Coverage | Status |
|-------------|---------------|--------|
| Non-FIPS algorithms blocked in TLS | Tests 2, 3, 4 | ✅ VERIFIED (0 weak cipher suites) |
| FIPS algorithms succeed | Tests 1, 3, 4 | ✅ VERIFIED (SHA-256+, AES-256-GCM) |
| wolfProvider active | Tests 1, 3 | ✅ VERIFIED (registered in OpenSSL 3.5) |
| FIPS mode enabled | Test 3 | ✅ VERIFIED (`crypto.getFips()` = 1) |
| Contrast test | Evidence file | ✅ VERIFIED (see contrast-test-results.md) |

### FIPS 140-3 Compliance

| Component | Certificate | Test Coverage | Status |
|-----------|-------------|---------------|--------|
| wolfSSL FIPS | #4718 | Test 1, KAT test | ✅ VERIFIED |
| wolfProvider | via #4718 | Test 3 | ✅ VERIFIED |
| TLS Protocol | TLS 1.2/1.3 | Test 2, 3 | ✅ VERIFIED |
| Cipher Suites | FIPS-approved | Test 2, 3 | ✅ VERIFIED |

---

## Known Limitations

### Container-Specific

1. **Kernel FIPS Mode:** Containers share host kernel - kernel FIPS is host responsibility
2. **External Dependencies:** Some tests require network connectivity (www.google.com, httpbin.org)
3. **Third-Party Libraries:** Optional library tests skipped (not installed in base image)

**Mitigation:** Core FIPS functionality (crypto operations, provider registration, FIPS mode) always passes

### wolfSSL Configuration

1. **MD5 Availability:** Blocked at crypto API level (correct FIPS 140-3 behavior per Certificate #4718)
2. **SHA-1 Availability:** Available at hash API (legacy support), blocked in TLS
3. **TLS Enforcement:** Only FIPS-approved cipher suites available (30 total)

**Note:** This behavior matches industry best practices and adheres to FIPS 140-3 Certificate #4718 requirements.

---

## Reproduction Instructions

To reproduce all tests:

```bash
# Clone repository
cd node/24.14.0-trixie-slim-fips

# Build image (if not already built)
./build.sh

# Run all diagnostic tests
./diagnostic.sh

# Expected output:
# Backend Verification: 6/6 tests passed
# Connectivity: 8/8 tests passed
# FIPS Verification: 6/6 tests passed
# Crypto Operations: 8/8 tests passed
# Library Compatibility: 4/4 core tests passed
# Overall: 32/32 tests passed (100%)

# Run FIPS KAT tests
docker run --rm cr.root.io/node:24.14.0-trixie-slim-fips /test-fips

# Run test image (quick validation)
cd diagnostics/test-images/basic-test-image
./build.sh
docker run --rm node-fips-test:latest

# Expected: ✅ ALL TESTS PASSED (15/15)
```

---

## Architecture Validation

### FIPS Enforcement Stack

```
┌─────────────────────────────────────────┐
│   Node.js Application (User Code)      │
├─────────────────────────────────────────┤
│   Node.js 24.14.1 Runtime               │ ← Dynamic linking to OpenSSL 3.5
│   (NodeSource pre-built binary)         │   (--openssl-shared-config)
├─────────────────────────────────────────┤
│   OpenSSL 3.5.0                        │ ← Provider architecture
│   (system library)                      │   wolfProvider at position 1
├─────────────────────────────────────────┤
│   wolfProvider v1.1.1                   │ ← FIPS enforcement layer
│   (OpenSSL 3.5 provider)                │   Filters weak algorithms
├─────────────────────────────────────────┤
│   wolfSSL FIPS v5.8.2                   │ ← Certificate #4718
│   (FIPS cryptographic module)           │   KAT tests, FIPS POST
└─────────────────────────────────────────┘
```

**Key Architectural Advantage:** Provider-based approach eliminates need for Node.js source compilation, reducing build time from 25-60 minutes to ~12 minutes while maintaining full FIPS compliance.

---

## Version History

### Node.js 24.14.0 on Debian Trixie

**Key Differences from Node.js 18:**
- Node.js version: 18.20.8 → 24.14.1
- Base distribution: Debian Bookworm → Debian Trixie
- OpenSSL version: 3.0.11 → 3.5.0
- wolfProvider: v1.0.2 → v1.1.1
- Library paths: Updated to `/usr/local/openssl/lib64/ossl-modules/`
- Configuration: Moved to `/etc/ssl/openssl.cnf`

**Improvements:**
- Latest Node.js LTS with enhanced security features
- Updated OpenSSL with latest security patches
- Improved wolfProvider compatibility
- Better integration with Debian Trixie security hardening

---

## Document Metadata

- **Author:** Root Security Team
- **Classification:** PUBLIC
- **Distribution:** UNLIMITED
- **Version:** 1.0
- **Last Updated:** 2026-04-15
- **Related Documents:**
  - diagnostic_results.txt
  - contrast-test-results.md
  - ../README.md

---

**END OF TEST EXECUTION SUMMARY**
