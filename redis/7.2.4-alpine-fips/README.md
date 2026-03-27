# Redis 7.2.4 Alpine FIPS Image

[![FIPS 140-3](https://img.shields.io/badge/FIPS%20140--3-Compliant-green.svg)](https://csrc.nist.gov/projects/cryptographic-module-validation-program)
[![wolfSSL](https://img.shields.io/badge/wolfSSL-5.8.2-blue.svg)](https://www.wolfssl.com/)
[![Redis](https://img.shields.io/badge/Redis-7.2.4-red.svg)](https://redis.io/)
[![Alpine](https://img.shields.io/badge/Alpine-3.19-blue.svg)](https://alpinelinux.org/)

A FIPS 140-3 compliant Redis 7.2.4 container image built on Alpine Linux 3.19 with wolfSSL FIPS cryptographic module.

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Quick Start](#quick-start)
- [FIPS Compliance](#fips-compliance)
- [Architecture](#architecture)
- [Configuration](#configuration)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [Documentation](#documentation)
- [Security](#security)
- [License](#license)

## 🎯 Overview

This image provides a production-ready, FIPS 140-3 compliant Redis server suitable for government and enterprise environments requiring validated cryptography.

**Key Components:**
- **Redis 7.2.4** - Built with TLS support and FIPS-compliant hashing
- **wolfSSL FIPS v5.8.2** - CMVP Certificate #4718
- **OpenSSL 3.3.0** - FIPS module support
- **wolfProvider v1.1.0** - OpenSSL 3.x provider for wolfSSL integration
- **Alpine Linux 3.19** - Minimal base image (musl libc)

**Image Size:** 119.49 MB

## ✨ Features

### FIPS 140-3 Compliance
- ✅ wolfSSL FIPS v5.8.2 (CMVP Certificate #4718)
- ✅ Automatic FIPS POST (Power-On Self Test) on startup
- ✅ FIPS-approved cryptographic algorithms only
- ✅ Non-FIPS algorithms blocked (MD5, SHA-1 for hashing)
- ✅ SHA-256 used for Lua script hashing (FIPS-compliant)

### Security Features
- ✅ TLS 1.2/1.3 support
- ✅ Secure cryptographic operations
- ✅ Minimal attack surface (Alpine base)
- ✅ Non-root user execution
- ✅ Read-only filesystem support

### Redis Features
- ✅ Full Redis 7.2.4 functionality
- ✅ Persistence (RDB, AOF)
- ✅ Replication support
- ✅ Pub/Sub messaging
- ✅ Lua scripting (with FIPS SHA-256 hashing)
- ✅ Cluster mode compatible

## 🚀 Quick Start

### Pull and Run

```bash
# Pull the image
docker pull cr.root.io/redis:7.2.4-alpine-fips

# Run with default configuration
docker run -d -p 6379:6379 --name redis-fips \
  cr.root.io/redis:7.2.4-alpine-fips

# Check FIPS validation logs
docker logs redis-fips

# Test connectivity
docker exec redis-fips redis-cli PING
```

### Expected Output

The container performs automatic FIPS validation on startup:

```
Redis 7.2.4 with wolfSSL FIPS 140-3
Starting container...

======================================
Redis FIPS 140-3 Validation
======================================

[CHECK 1/5] Verifying environment variables...
[OK] OPENSSL_CONF=/usr/local/openssl/ssl/openssl.cnf
[OK] OpenSSL config file exists
[OK] OPENSSL_MODULES=/usr/local/openssl/lib/ossl-modules
[OK] LD_LIBRARY_PATH=/usr/local/openssl/lib:/usr/local/lib

[CHECK 2/5] Running wolfSSL FIPS POST (Power-On Self Test)...
  ✓ FIPS POST completed successfully
  All Known Answer Tests (KAT) passed

[CHECK 3/5] Verifying OpenSSL version...
[OK] OpenSSL version: OpenSSL 3.3.0 9 Apr 2024

[CHECK 4/5] Verifying wolfProvider is loaded...
[OK] wolfProvider (wolfSSL Provider FIPS) is loaded and active

[CHECK 5/5] Testing FIPS enforcement (MD5 should be blocked)...
[OK] MD5 is blocked (FIPS enforcement active)

======================================
✓ ALL FIPS CHECKS PASSED
======================================

FIPS Components:
  - wolfSSL FIPS: v5.8.2 (Certificate #4718)
  - wolfProvider: v1.1.0
  - OpenSSL: OpenSSL 3.3.0
  - Redis: 7.2.4

[STARTING] Redis server...

* Ready to accept connections tcp
```

### Basic Operations

```bash
# Set a key
docker exec redis-fips redis-cli SET mykey "Hello FIPS Redis"

# Get a key
docker exec redis-fips redis-cli GET mykey

# Check server info
docker exec redis-fips redis-cli INFO server

# Run Lua script (uses FIPS SHA-256 internally)
docker exec redis-fips redis-cli EVAL "return redis.call('PING')" 0
```

## 🔒 FIPS Compliance

### CMVP Certificate #4718

This image uses **wolfSSL FIPS v5.8.2**, validated under FIPS 140-3:

- **Certificate:** #4718
- **Validation:** NIST CMVP FIPS 140-3
- **Module:** wolfCrypt FIPS v5.8.2
- **Algorithms:** AES, SHA-256, HMAC, RSA, ECDSA, ECDH, DRBG

**Status:** ✅ **ACTIVE** (as of March 2026)

### FIPS Mode Enforcement

The container enforces FIPS mode through multiple layers:

1. **wolfSSL FIPS Module** - All crypto operations use validated module
2. **OpenSSL Provider** - wolfProvider bridges OpenSSL → wolfSSL
3. **Redis Patches** - SHA-1 replaced with SHA-256 for Lua script hashing
4. **Startup Validation** - Automatic FIPS POST and algorithm tests

### Non-FIPS Algorithms Blocked

The following non-FIPS algorithms are blocked:
- ❌ MD5 hashing
- ❌ SHA-1 for new applications (replaced with SHA-256)
- ❌ RC4 encryption
- ❌ DES/3DES (deprecated)

### FIPS-Approved Algorithms

Available FIPS-approved algorithms:
- ✅ AES-128, AES-192, AES-256 (CBC, GCM, CCM)
- ✅ SHA-224, SHA-256, SHA-384, SHA-512
- ✅ HMAC (with SHA-2)
- ✅ RSA (2048, 3072, 4096-bit)
- ✅ ECDSA, ECDH (P-256, P-384, P-521)
- ✅ DRBG (Deterministic Random Bit Generator)

## 🏗️ Architecture

### Image Layers

```
┌─────────────────────────────────────┐
│   Redis 7.2.4 (FIPS-patched)       │
│   - TLS support enabled             │
│   - SHA-256 Lua script hashing      │
├─────────────────────────────────────┤
│   OpenSSL 3.3.0 + wolfProvider      │
│   - wolfSSL Provider FIPS active    │
├─────────────────────────────────────┤
│   wolfSSL FIPS v5.8.2               │
│   - CMVP Certificate #4718          │
├─────────────────────────────────────┤
│   Alpine Linux 3.19 (musl libc)     │
│   - Minimal base image              │
└─────────────────────────────────────┘
```

### FIPS Cryptographic Stack

```
┌─────────────────────────────────────┐
│         Redis Application           │
│  (Lua scripts, TLS, operations)     │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│         OpenSSL 3.3.0 EVP API       │
│    (Application-level crypto API)   │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│      wolfProvider v1.1.0            │
│   (OpenSSL 3 → wolfSSL bridge)      │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│    wolfSSL FIPS v5.8.2              │
│  CMVP Certificate #4718             │
│  (FIPS-validated crypto module)     │
└─────────────────────────────────────┘
```

### Key Modifications for FIPS

**Redis Source Patches:**

The image applies a custom patch (`redis-fips-sha256-redis7.2.4.patch`) that modifies Redis source code:

1. **src/eval.c** - Replace SHA-1 with SHA-256 for Lua script hashing
   - Function: `sha1hex()` → `sha256hex()`
   - Uses: OpenSSL EVP interface with SHA-256
   - Impact: Script IDs change (incompatible with non-FIPS Redis)

2. **src/debug.c** - Replace SHA-1 with SHA-256 for DEBUG DIGEST
   - Functions: `xorDigest()`, `mixDigest()`
   - Uses: OpenSSL EVP SHA-256
   - Impact: DEBUG DIGEST values change

3. **src/script_lua.c** - Update Lua API to use SHA-256
   - Function: `luaRedisSha1hexCommand()`
   - API: `redis.sha1hex()` still available but uses SHA-256 internally
   - Impact: Maintains backward compatibility in Lua scripts

4. **src/server.h** - Update function declarations
   - Declaration: `sha1hex()` → `sha256hex()`

**Why These Changes?**

SHA-1 is **not FIPS 140-3 approved** for new applications. The patch ensures all hashing operations use FIPS-approved SHA-256.

## ⚙️ Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OPENSSL_CONF` | `/usr/local/openssl/ssl/openssl.cnf` | OpenSSL configuration file |
| `OPENSSL_MODULES` | `/usr/local/openssl/lib/ossl-modules` | OpenSSL provider modules directory |
| `LD_LIBRARY_PATH` | `/usr/local/openssl/lib:/usr/local/lib` | Library search path |
| `FIPS_CHECK` | `true` | Enable FIPS validation on startup |

### Disable FIPS Validation (Debugging Only)

**⚠️ NOT RECOMMENDED FOR PRODUCTION**

```bash
docker run -d -p 6379:6379 \
  -e FIPS_CHECK=false \
  --name redis-fips \
  cr.root.io/redis:7.2.4-alpine-fips
```

This bypasses FIPS validation checks but **does not disable FIPS mode** - cryptographic operations still use wolfSSL FIPS.

### Custom Redis Configuration

```bash
# Create custom redis.conf
cat > redis.conf << 'EOF'
# Enable TLS
port 0
tls-port 6379
tls-cert-file /etc/redis/redis.crt
tls-key-file /etc/redis/redis.key
tls-ca-cert-file /etc/redis/ca.crt

# Persistence
save 900 1
save 300 10
save 60 10000

# Security
requirepass yourpassword
EOF

# Run with custom config
docker run -d -p 6379:6379 \
  -v $(pwd)/redis.conf:/etc/redis/redis.conf \
  --name redis-fips \
  cr.root.io/redis:7.2.4-alpine-fips \
  redis-server /etc/redis/redis.conf
```

### TLS Configuration

**Generate TLS Certificates:**

```bash
# Generate CA
openssl req -x509 -nodes -newkey rsa:4096 \
  -keyout ca.key -out ca.crt -days 3650 \
  -subj "/CN=Redis-CA"

# Generate server certificate
openssl req -newkey rsa:4096 -nodes \
  -keyout redis.key -out redis.csr \
  -subj "/CN=redis-server"

openssl x509 -req -in redis.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out redis.crt -days 365

# Run with TLS
docker run -d -p 6379:6379 \
  -v $(pwd)/ca.crt:/etc/redis/ca.crt:ro \
  -v $(pwd)/redis.crt:/etc/redis/redis.crt:ro \
  -v $(pwd)/redis.key:/etc/redis/redis.key:ro \
  -v $(pwd)/redis-tls.conf:/etc/redis/redis.conf:ro \
  --name redis-fips-tls \
  cr.root.io/redis:7.2.4-alpine-fips \
  redis-server /etc/redis/redis.conf

# Connect with TLS
docker exec redis-fips-tls redis-cli \
  --tls \
  --cert /etc/redis/redis.crt \
  --key /etc/redis/redis.key \
  --cacert /etc/redis/ca.crt \
  PING
```

### Persistence

**RDB Snapshots:**

```bash
docker run -d -p 6379:6379 \
  -v redis-data:/data \
  --name redis-fips \
  cr.root.io/redis:7.2.4-alpine-fips
```

**AOF (Append-Only File):**

```bash
# Create config with AOF enabled
cat > redis-aof.conf << 'EOF'
appendonly yes
appendfilename "appendonly.aof"
appendfsync everysec
EOF

docker run -d -p 6379:6379 \
  -v redis-data:/data \
  -v $(pwd)/redis-aof.conf:/etc/redis/redis.conf \
  --name redis-fips-aof \
  cr.root.io/redis:7.2.4-alpine-fips \
  redis-server /etc/redis/redis.conf
```

## 🧪 Testing

### Quick Validation Test

```bash
# Run container
docker run -d -p 6379:6379 --name redis-fips \
  cr.root.io/redis:7.2.4-alpine-fips

# Wait for startup
sleep 3

# Check FIPS validation passed
docker logs redis-fips | grep "ALL FIPS CHECKS PASSED"

# Test Redis operations
docker exec redis-fips redis-cli SET test "FIPS Redis"
docker exec redis-fips redis-cli GET test
docker exec redis-fips redis-cli DEL test

# Cleanup
docker stop redis-fips && docker rm redis-fips
```

### Comprehensive Test Suite

```bash
# Run from project root/test-images/basic-test-image
./build.sh
docker run --rm redis-fips-test:latest
```

**Tests included:**
- ✅ FIPS POST validation
- ✅ Redis connectivity
- ✅ Basic operations (SET, GET, DEL)
- ✅ Persistence (RDB, AOF)
- ✅ Lua scripting (SHA-256 hashing)
- ✅ TLS connections
- ✅ FIPS algorithm enforcement
- ✅ Negative tests (non-FIPS algorithms blocked)

### Manual FIPS Verification

```bash
# Check wolfSSL FIPS status
docker exec redis-fips fips-startup-check

# Verify wolfProvider loaded
docker exec redis-fips openssl list -providers

# Test FIPS enforcement (MD5 should fail)
docker exec redis-fips openssl dgst -md5 /etc/redis/redis.conf
# Expected: Error setting digest (FIPS mode blocks MD5)

# Test FIPS-approved algorithm (SHA-256 should work)
docker exec redis-fips openssl dgst -sha256 /etc/redis/redis.conf
# Expected: SHA256(...)= <hash>
```

## 🔧 Troubleshooting

### FIPS Validation Fails on Startup

**Symptom:** Container exits with "FIPS VALIDATION FAILED"

**Solution:**

```bash
# Check detailed logs
docker logs redis-fips

# Run FIPS diagnostic
docker run --rm cr.root.io/redis:7.2.4-alpine-fips \
  fips-startup-check

# Bypass validation for debugging (NOT for production)
docker run -e FIPS_CHECK=false -d -p 6379:6379 \
  --name redis-fips cr.root.io/redis:7.2.4-alpine-fips
```

### Redis Won't Start

**Check logs:**
```bash
docker logs redis-fips --tail 50
```

**Common issues:**
1. Port already in use: Change `-p 6380:6379`
2. Permission denied: Ensure `/data` is writable
3. Config error: Validate `redis.conf` syntax

### Lua Script Errors

**Issue:** Existing scripts with EVALSHA fail

**Cause:** Script IDs changed from SHA-1 to SHA-256

**Solution:**

```bash
# Clear script cache
docker exec redis-fips redis-cli SCRIPT FLUSH

# Re-load scripts using EVAL
# Script IDs will be recalculated with SHA-256
```

### TLS Connection Issues

**Verify TLS configuration:**

```bash
# Check Redis TLS config
docker exec redis-fips redis-cli CONFIG GET tls-*

# Test TLS connection
docker exec redis-fips redis-cli \
  --tls \
  --cert /etc/redis/redis.crt \
  --key /etc/redis/redis.key \
  --cacert /etc/redis/ca.crt \
  PING
```

### Performance Issues

**Check FIPS overhead:**

```bash
# Benchmark standard operations
docker exec redis-fips redis-benchmark -t set,get -n 100000 -q

# Compare with non-FIPS Redis (expect 5-10% overhead)
```

**FIPS overhead is minimal (<10%) for most operations.**

### Diagnostic Scripts

```bash
# Run comprehensive diagnostics
# Run from project root
./diagnostic.sh

# Check FIPS status only
./test-redis-fips-status.sh

# Test connectivity
./test-redis-connectivity.sh
```

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [README.md](README.md) | This file - Quick start and overview |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Technical architecture and design decisions |
| [DEVELOPER-GUIDE.md](DEVELOPER-GUIDE.md) | Build, test, and development workflows |
| [ATTESTATION.md](ATTESTATION.md) | FIPS compliance attestation and evidence |
| [BUILD-TEST-RESULTS.md](BUILD-TEST-RESULTS.md) | Build validation test results |
| [patches/README.md](patches/README.md) | Redis FIPS patch documentation |
| [patches/PATCH-DETAILS.md](patches/PATCH-DETAILS.md) | Detailed patch technical information |

## 🔐 Security

### Vulnerability Reporting

Report security vulnerabilities to: [security contact email]

### Security Best Practices

1. **Always use TLS** for production deployments
2. **Enable authentication** (`requirepass`)
3. **Limit network exposure** (bind to specific IPs)
4. **Use read-only filesystem** where possible
5. **Run as non-root user** (default: `redis` user, UID 1000)
6. **Keep image updated** (subscribe to security advisories)
7. **Verify FIPS validation** passes on every startup

### SBOM and Compliance

- **SBOM:** See [compliance/SBOM-redis-7.2.4-alpine-fips.spdx.json](compliance/SBOM-redis-7.2.4-alpine-fips.spdx.json)
- **SLSA Provenance:** See [compliance/slsa-provenance-redis-7.2.4-alpine-fips.json](compliance/slsa-provenance-redis-7.2.4-alpine-fips.json)
- **VEX:** See [compliance/vex-redis-7.2.4-alpine-fips.json](compliance/vex-redis-7.2.4-alpine-fips.json)

## 🎓 Additional Resources

- **Redis Documentation:** https://redis.io/docs/
- **wolfSSL FIPS:** https://www.wolfssl.com/products/wolfssl-fips/
- **NIST CMVP:** https://csrc.nist.gov/projects/cryptographic-module-validation-program
- **FIPS 140-3:** https://csrc.nist.gov/publications/detail/fips/140/3/final
- **OpenSSL Providers:** https://www.openssl.org/docs/man3.0/man7/provider.html

## 📄 License

- **Redis:** BSD 3-Clause License
- **wolfSSL FIPS:** Commercial license required (included in this build)
- **OpenSSL:** Apache 2.0 License
- **Alpine Linux:** Various (mostly MIT, GPL)

## 🙏 Acknowledgments

- Redis Labs for Redis
- wolfSSL Inc. for wolfSSL FIPS module and wolfProvider
- OpenSSL Project for OpenSSL
- Alpine Linux team

---

**Built with ❤️ for FIPS 140-3 compliance**

*Last updated: March 26, 2026*
*Image version: 7.2.4-alpine-fips*
