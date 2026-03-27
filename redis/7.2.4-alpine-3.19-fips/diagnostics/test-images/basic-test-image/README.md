# Redis FIPS Basic Test Image

Comprehensive test image for validating Redis 7.2.4 with wolfSSL FIPS 140-3 integration on Alpine.

## Overview

This test image extends the base `cr.root.io/redis:7.2.4-alpine-3.19-fips` image with comprehensive test suites to validate FIPS compliance in a user application context.

## Test Suites

### 1. FIPS Compliance Test Suite
**File**: `test_fips_compliance.sh`

Tests:
- FIPS POST validation ✅
- wolfProvider loaded and active ✅
- OpenSSL version verification ✅
- MD5 blocked (FIPS enforcement) ❌
- Non-FIPS algorithms rejected ❌

### 2. Redis Operations Test Suite
**File**: `test_redis_operations.sh`

Tests:
- Basic operations (GET/SET/DEL) ✅
- Data structures (LIST/SET/HASH/ZSET) ✅
- Persistence (RDB/AOF) ✅
- Pub/Sub messaging ✅
- Key expiration ✅

### 3. TLS Connection Test Suite
**File**: `test_tls_connections.sh`

Tests:
- TLS 1.2 protocol support ✅
- TLS 1.3 protocol support ✅
- TLS 1.0/1.1 blocked ❌
- FIPS-approved ciphers ✅
- Non-FIPS ciphers blocked ❌

### 4. Persistence Test Suite
**File**: `test_persistence.sh`

Tests:
- RDB snapshots ✅
- AOF logs ✅
- Data recovery after restart ✅
- Data integrity ✅

### 5. Negative Test Suite
**File**: `test_negative_cases.sh`

Tests:
- MD5 digest fails ❌
- SHA-1 digest fails ❌
- RC4 cipher fails ❌
- Weak key sizes rejected ❌

## Building the Image

```bash
./build.sh
```

This creates the `redis-fips-test:latest` image.

## Running Tests

### Run All Tests (Default)

```bash
docker run --rm redis-fips-test:latest
```

Expected output:
```
===============================================================================
  Redis wolfSSL FIPS 140-3 Alpine Basic Test Image
  Comprehensive User Application Test Suite
===============================================================================

Running Test Suite 1: FIPS Compliance Tests
...
Tests Passed: 5/5

Running Test Suite 2: Redis Operations Tests
...
Tests Passed: 10/10

Running Test Suite 3: TLS Connection Tests
...
Tests Passed: 5/5

Running Test Suite 4: Persistence Tests
...
Tests Passed: 4/4

Running Test Suite 5: Negative Test Cases
...
Tests Passed: 5/5

===============================================================================
  FINAL TEST SUMMARY
===============================================================================
  Total Test Suites: 5
  Passed: 5
  Failed: 0
  Duration: X seconds

  ✓ FIPS Compliance Tests: PASS
  ✓ Redis Operations Tests: PASS
  ✓ TLS Connection Tests: PASS
  ✓ Persistence Tests: PASS
  ✓ Negative Test Cases: PASS

  ✓ ALL TESTS PASSED - Redis wolfSSL FIPS on Alpine is production ready
```

## Exit Codes

- **0**: All tests passed
- **1**: Partial success
- **2**: Critical failure

## Version Information

- **Redis Version**: 7.2.4
- **Base Image**: alpine:3.19
- **wolfSSL Version**: 5.8.2 FIPS 140-3
- **FIPS Certificate**: #4718
- **OpenSSL Version**: 3.x
- **wolfProvider Version**: 1.1.0
