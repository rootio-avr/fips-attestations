# Redis 7.2.4 Alpine FIPS - Diagnostics

This directory contains diagnostic scripts and test images for validating Redis FIPS compliance.

## Contents

- `test-redis-fips-status.sh` - FIPS status validation script
- `test-redis-connectivity.sh` - Redis connectivity tests
- `test-images/` - Test container images for comprehensive validation

## Usage

Run basic FIPS status check:
```bash
./test-redis-fips-status.sh
```

Run connectivity tests:
```bash
./test-redis-connectivity.sh
```

Run comprehensive test suite:
```bash
cd test-images/basic-test-image
./build.sh
docker run --rm redis-fips-test:latest
```

## Test Coverage

- FIPS POST validation
- wolfProvider verification
- Redis operations (GET/SET/LPUSH/etc.)
- TLS connections (TLS 1.2/1.3)
- Persistence (RDB/AOF)
- Negative tests (non-FIPS algorithms)
