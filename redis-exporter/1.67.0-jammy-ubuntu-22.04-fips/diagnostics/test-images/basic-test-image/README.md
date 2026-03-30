# Redis Exporter FIPS - Test Image

Comprehensive test suite for validating the FIPS-compliant redis_exporter image.

## Overview

This test image validates:
- ✅ FIPS POST validation
- ✅ wolfProvider configuration
- ✅ Algorithm enforcement (MD5/SHA-1 blocked, SHA-256+ allowed)
- ✅ Redis connectivity (non-TLS, TLS, authentication)
- ✅ Metrics export (Prometheus format, expected metrics)
- ✅ Crypto operations (TLS, certificates, ciphers)

## Quick Start

```bash
# Build test image
./build.sh

# Run all tests
docker run --rm redis-exporter-1.67.0-fips-test:latest
```

## Test Suites

### 1. FIPS Validation Tests (8 tests)
- FIPS POST execution
- wolfSSL library loading
- wolfProvider registration
- Environment variables (`GOLANG_FIPS`, `GODEBUG`)
- OpenSSL configuration
- MD5 algorithm blocking
- SHA-1 algorithm blocking
- SHA-256 algorithm availability

### 2. Redis Connection Tests (10 tests)
- Basic TCP connection
- Connection with authentication
- TLS 1.2 connection
- TLS 1.3 connection
- Certificate validation
- Sentinel mode connection
- Cluster mode connection
- Connection pooling
- Reconnection handling
- Timeout handling

### 3. Metrics Export Tests (7 tests)
- /metrics endpoint availability
- Prometheus format validation
- Expected metrics presence (`redis_up`, `redis_commands_total`, etc.)
- Metric values reasonableness
- Label correctness
- TLS on metrics endpoint
- Scrape performance

### 4. Crypto Operations Tests (5 tests)
- TLS cipher suite negotiation (FIPS-approved only)
- Certificate validation
- FIPS algorithm availability (SHA-256, AES-GCM, RSA, ECDSA)
- Non-FIPS algorithm blocking (MD5, RC4, DES)
- Random number generation (FIPS DRBG)

## Test Execution

### Run All Tests

```bash
docker run --rm redis-exporter-1.67.0-fips-test:latest
```

**Expected Output:**
```
========================================
Redis Exporter FIPS Test Suite
========================================

[SUITE 1/4] FIPS Validation Tests
  ✓ Test 1: FIPS POST passes
  ✓ Test 2: wolfSSL library loads
  ✓ Test 3: wolfProvider registered
  ✓ Test 4: GOLANG_FIPS=1
  ✓ Test 5: GODEBUG=fips140=only
  ✓ Test 6: MD5 blocked
  ✓ Test 7: SHA-1 blocked
  ✓ Test 8: SHA-256 available
  [8/8 PASSED]

[SUITE 2/4] Redis Connection Tests
  ✓ Test 9: Basic TCP connection
  ✓ Test 10: Authentication
  ✓ Test 11: TLS 1.2 connection
  ✓ Test 12: TLS 1.3 connection
  ✓ Test 13: Certificate validation
  ○ Test 14: Sentinel mode (requires setup)
  ○ Test 15: Cluster mode (requires setup)
  ✓ Test 16: Connection pooling
  ✓ Test 17: Reconnection
  ✓ Test 18: Timeout handling
  [8/10 PASSED, 2 SKIPPED]

[SUITE 3/4] Metrics Export Tests
  ✓ Test 19: Endpoint availability
  ✓ Test 20: Prometheus format
  ✓ Test 21: Expected metrics
  ✓ Test 22: Metric values
  ✓ Test 23: Label correctness
  ○ Test 24: TLS endpoint (requires setup)
  ✓ Test 25: Scrape performance
  [6/7 PASSED, 1 SKIPPED]

[SUITE 4/4] Crypto Operations Tests
  ✓ Test 26: TLS cipher suites
  ✓ Test 27: Certificate validation
  ✓ Test 28: FIPS algorithms
  ✓ Test 29: Non-FIPS blocked
  ✓ Test 30: Random generation
  [5/5 PASSED]

========================================
Test Summary
========================================
Total Tests:  30
Passed:       27
Failed:       0
Skipped:      3 (require external setup)

✓ ALL REQUIRED TESTS PASSED
```

### Run with Redis Server

```bash
# Start test Redis server
docker run -d --name test-redis redis:7.2.4

# Run tests with Redis
docker run --rm --link test-redis \
  -e REDIS_ADDR=redis://test-redis:6379 \
  redis-exporter-1.67.0-fips-test:latest

# Cleanup
docker stop test-redis && docker rm test-redis
```

### Run Specific Test Suite

```bash
# Run only FIPS validation tests (TODO: implement selector)
docker run --rm redis-exporter-1.67.0-fips-test:latest --suite=fips

# Run only Redis connection tests
docker run --rm redis-exporter-1.67.0-fips-test:latest --suite=redis

# Run only metrics tests
docker run --rm redis-exporter-1.67.0-fips-test:latest --suite=metrics

# Run only crypto tests
docker run --rm redis-exporter-1.67.0-fips-test:latest --suite=crypto
```

## Test Files

```
basic-test-image/
├── Dockerfile                      # Test container image
├── build.sh                        # Build script
├── README.md                       # This file
├── test-runner.sh                  # Test execution script
└── src/
    ├── fips_validation_test.go     # FIPS validation tests (8 tests)
    ├── redis_connection_test.go    # Redis connection tests (10 tests)
    ├── metrics_export_test.go      # Metrics export tests (7 tests)
    └── crypto_operations_test.go   # Crypto operations tests (5 tests)
```

## Exit Codes

- `0` - All required tests passed
- `1` - One or more required tests failed
- `2` - Test execution error

## CI/CD Integration

```yaml
# GitHub Actions example
test-redis-exporter-fips:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v3
    - name: Build test image
      run: |
        cd diagnostics/test-images/basic-test-image
        ./build.sh
    - name: Run tests
      run: docker run --rm redis-exporter-1.67.0-fips-test:latest
```

## Test Coverage

| Category | Tests | Coverage |
|----------|-------|----------|
| **FIPS Validation** | 8 | 100% |
| **Redis Connectivity** | 10 | 80% (2 require external setup) |
| **Metrics Export** | 7 | 86% (1 requires external setup) |
| **Crypto Operations** | 5 | 100% |
| **Total** | 30 | 90% |

## Development

### Adding New Tests

1. Create test file in `src/` (e.g., `new_feature_test.go`)
2. Implement tests following existing patterns
3. Update test-runner.sh to include new suite
4. Update this README with test descriptions
5. Rebuild: `./build.sh`

### Test Format

Tests use shell scripts for simplicity and portability:

```bash
# Example test structure
test_name() {
    echo -n "  ✓ Test N: Description... "

    # Test logic here
    if [ condition ]; then
        echo "[PASS]"
        return 0
    else
        echo "[FAIL]"
        return 1
    fi
}
```

## Troubleshooting

### Build Fails

```bash
# Ensure base image is built
cd ../../..
./build.sh

# Then rebuild test image
cd diagnostics/test-images/basic-test-image
./build.sh
```

### Tests Fail

```bash
# Check FIPS validation
docker run --rm --entrypoint=/usr/local/bin/fips-check \
  cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips

# Check exporter starts
docker run --rm --entrypoint=redis_exporter \
  cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips \
  --version

# Run test image with shell for debugging
docker run --rm -it --entrypoint=bash \
  redis-exporter-1.67.0-fips-test:latest
```

## Notes

- Tests marked as "SKIPPED" require external setup (Redis Sentinel/Cluster, TLS certificates)
- These can be run manually with appropriate infrastructure
- All "REQUIRED" tests must pass for image validation
- Test execution takes ~30-60 seconds

## Related Documentation

- [ARCHITECTURE.md](../../../ARCHITECTURE.md) - Technical architecture
- [DEVELOPER-GUIDE.md](../../../DEVELOPER-GUIDE.md) - Build and development
- [README.md](../../../README.md) - User documentation

---

**Last Updated:** March 27, 2026
**Test Suite Version:** 1.0
**Image Version:** 1.67.0-jammy-ubuntu-22.04-fips
