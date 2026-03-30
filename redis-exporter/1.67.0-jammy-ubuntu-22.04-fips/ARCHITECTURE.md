# Redis Exporter v1.67.0 FIPS 140-3 - Architecture

## Table of Contents

- [Overview](#overview)
- [System Architecture](#system-architecture)
- [Cryptographic Stack](#cryptographic-stack)
- [Build Architecture](#build-architecture)
- [Runtime Architecture](#runtime-architecture)
- [FIPS Compliance Implementation](#fips-compliance-implementation)
- [Security Architecture](#security-architecture)
- [Performance Considerations](#performance-considerations)
- [Design Decisions](#design-decisions)
- [Limitations and Trade-offs](#limitations-and-trade-offs)

## Overview

This document describes the technical architecture of the Redis Exporter v1.67.0 FIPS 140-3 image, focusing on how FIPS compliance is achieved while maintaining Prometheus metrics export functionality and performance.

### High-Level Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│              redis_exporter v1.67.0 Application Layer            │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐     │
│  │  Redis Client  │  │  HTTP Server   │  │  Prometheus    │     │
│  │  (TLS support) │  │  (Metrics API) │  │  Metrics       │     │
│  └───────┬────────┘  └───────┬────────┘  └───────┬────────┘     │
└──────────┼───────────────────┼───────────────────┼──────────────┘
           │                   │                   │
           │    ┌──────────────┴──────────────┐    │
           │    │                             │    │
           ▼    ▼                             ▼    ▼
┌──────────────────────────────────────────────────────────────────┐
│               golang-fips/go v1.25 Runtime Layer                 │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  FIPS-enabled Go runtime (GOEXPERIMENT=strictfipsruntime)  │  │
│  │  GODEBUG=fips140=only (blocks non-FIPS algorithms)         │  │
│  └────────────────────┬───────────────────────────────────────┘  │
└───────────────────────┼──────────────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────────────┐
│               OpenSSL 3.0.19 EVP API Layer                       │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  EVP_DigestInit(), SSL_connect(), TLS_client_method(), etc.│  │
│  └────────────────────┬───────────────────────────────────────┘  │
└───────────────────────┼──────────────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────────────┐
│                  wolfProvider v1.1.0                             │
│         OpenSSL 3.x Provider → wolfSSL FIPS Bridge               │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  Provider dispatch table, algorithm implementations        │  │
│  └────────────────────┬───────────────────────────────────────┘  │
└───────────────────────┼──────────────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────────────┐
│            wolfSSL FIPS v5.8.2 (CMVP #4718)                      │
│              FIPS 140-3 Validated Crypto Module                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  AES, SHA-256, HMAC, RSA, ECDSA, DRBG (all FIPS-approved) │  │
│  │  POST (Power-On Self Test), Continuous Tests              │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────────────┐
│                  Hardware / Operating System                     │
│                   Ubuntu 22.04 LTS (glibc)                       │
└──────────────────────────────────────────────────────────────────┘
```

## System Architecture

### Component Layers

The system is organized into distinct layers, each with specific responsibilities:

#### 1. Application Layer (redis_exporter v1.67.0)
- **Purpose:** Prometheus metrics exporter for Redis
- **Language:** Go (compiled with golang-fips/go)
- **Key Functions:**
  - Connect to Redis servers (single, cluster, sentinel)
  - Collect Redis metrics (INFO command, KEY commands, etc.)
  - Expose metrics via HTTP `/metrics` endpoint
  - Support TLS connections to Redis
  - Support TLS on metrics HTTP server (optional)
- **Dependencies:**
  - golang-fips/go runtime (for FIPS crypto)
  - Redis client libraries (github.com/redis/go-redis)
  - Prometheus client libraries (github.com/prometheus/client_golang)

#### 2. Go Runtime Layer (golang-fips/go v1.25)
- **Purpose:** FIPS-enabled Go runtime
- **Role:** Routes all cryptographic operations through OpenSSL
- **FIPS Enforcement:**
  - `GOEXPERIMENT=strictfipsruntime` - Strict FIPS mode at compile time
  - `GODEBUG=fips140=only` - Runtime enforcement (blocks non-FIPS algorithms)
  - `GOLANG_FIPS=1` - Enable FIPS mode
- **Benefits:**
  - Application code remains unchanged
  - Standard Go crypto packages work transparently
  - All crypto delegated to OpenSSL (and thus wolfSSL via provider)

#### 3. Cryptographic API Layer (OpenSSL 3.0.19)
- **Purpose:** Standard cryptographic API
- **Role:** Abstraction layer between Go runtime and FIPS module
- **Benefits:**
  - Industry-standard API
  - Provider architecture allows pluggable crypto implementations
  - Maintains compatibility with existing code

#### 4. Provider Layer (wolfProvider v1.1.0)
- **Purpose:** Bridge OpenSSL 3.x to wolfSSL FIPS
- **Implementation:** OpenSSL provider plugin
- **Function:** Dispatches crypto operations from OpenSSL to wolfSSL FIPS module
- **Provider Configuration:** `/etc/ssl/openssl.cnf` configured to load wolfProvider

#### 5. FIPS Module Layer (wolfSSL FIPS v5.8.2)
- **Purpose:** FIPS 140-3 validated cryptographic operations
- **Certification:** CMVP Certificate #4718
- **Guarantee:** All crypto uses validated algorithms
- **Features:**
  - Power-On Self Test (POST) on initialization
  - Continuous self-tests during operation
  - Algorithm-level FIPS compliance

#### 6. Operating System Layer (Ubuntu 22.04 LTS)
- **Purpose:** Base operating system
- **C Library:** glibc (required for golang-fips/go)
- **Benefits:**
  - Long-term support (LTS)
  - golang-fips/go compatibility
  - Established security patching

### Data Flow

#### Example 1: TLS Connection to Redis

```
1. redis_exporter calls redis.Dial("rediss://redis:6380")
   ↓
2. Go net/tls package (in golang-fips) handles TLS
   ↓
3. golang-fips/go routes crypto to OpenSSL via CGO
   ↓
4. OpenSSL EVP API called (SSL_connect, TLS_client_method)
   ↓
5. wolfProvider intercepts and routes to wolfSSL
   ↓
6. wolfSSL FIPS v5.8.2 performs:
   - TLS handshake with FIPS-approved cipher suites
   - Certificate validation with FIPS-approved signature algorithms
   - Session key derivation with FIPS-approved KDF
   ↓
7. Encrypted connection established (all crypto FIPS-validated)
```

#### Example 2: Serving Metrics via HTTPS

```
1. Prometheus scrapes https://redis-exporter:9121/metrics
   ↓
2. redis_exporter's HTTP server (net/http) handles TLS
   ↓
3. golang-fips/go routes TLS crypto to OpenSSL
   ↓
4. OpenSSL EVP API handles TLS server
   ↓
5. wolfProvider routes to wolfSSL FIPS
   ↓
6. wolfSSL FIPS performs TLS handshake (server-side)
   ↓
7. Metrics served over FIPS-compliant TLS connection
```

#### Example 3: Hash-based Operations (if any)

```
1. Application needs to hash data (e.g., for caching keys)
   ↓
2. Go crypto/sha256 package used
   ↓
3. golang-fips/go routes to OpenSSL EVP_Digest*
   ↓
4. wolfProvider routes to wolfSSL
   ↓
5. wolfSSL FIPS computes SHA-256 (FIPS-approved)
   ↓
6. Hash returned through the stack
```

## Cryptographic Stack

### Detailed Component Interaction

```
┌─────────────────────────────────────────────────────────────┐
│  redis_exporter Application Code                            │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ import "crypto/tls"                                    │ │
│  │ import "github.com/redis/go-redis/v9"                 │ │
│  │                                                        │ │
│  │ tls.Config{...}  // Configured for Redis TLS         │ │
│  │ redis.NewClient(...) // Redis client with TLS         │ │
│  └────────────────────────────────────────────────────────┘ │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  golang-fips/go v1.25 Standard Library (FIPS-enabled)       │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ crypto/tls    → OpenSSL (via CGO)                     │ │
│  │ crypto/sha256 → OpenSSL (via CGO)                     │ │
│  │ crypto/rand   → OpenSSL (via CGO)                     │ │
│  │ crypto/rsa    → OpenSSL (via CGO)                     │ │
│  │ crypto/ecdsa  → OpenSSL (via CGO)                     │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                             │
│  GOEXPERIMENT=strictfipsruntime (compile-time)              │
│  GODEBUG=fips140=only (runtime enforcement)                 │
└───────────────────────┬─────────────────────────────────────┘
                        │ CGO calls to libcrypto.so.3
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  OpenSSL 3.0.19 EVP API (libcrypto.so.3)                    │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ EVP_DigestInit_ex() → wolfProvider                    │ │
│  │ EVP_CipherInit_ex() → wolfProvider                    │ │
│  │ SSL_CTX_new()       → wolfProvider                    │ │
│  │ SSL_connect()       → wolfProvider                    │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                             │
│  Provider: fips (wolfProvider)                              │
│  Config: /etc/ssl/openssl.cnf                               │
└───────────────────────┬─────────────────────────────────────┘
                        │ Provider dispatch
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  wolfProvider v1.1.0 (libwolfprov.so)                       │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ OpenSSL Provider Implementation                        │ │
│  │ - Digest operations → wolfSSL_EVP_*                   │ │
│  │ - Cipher operations → wolfSSL cipher functions        │ │
│  │ - TLS operations    → wolfSSL_connect/accept          │ │
│  │ - Random generation → wolfSSL RNG                     │ │
│  └────────────────────────────────────────────────────────┘ │
└───────────────────────┬─────────────────────────────────────┘
                        │ wolfSSL API calls
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  wolfSSL FIPS v5.8.2 (libwolfssl.so)                        │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ FIPS 140-3 Validated Cryptographic Module             │ │
│  │                                                        │ │
│  │ Initialization:                                        │ │
│  │ - wolfCrypt_GetStatus_fips() → POST validation        │ │
│  │ - All KATs (Known Answer Tests) must pass             │ │
│  │                                                        │ │
│  │ Operations (FIPS-approved only):                       │ │
│  │ - AES encryption/decryption                           │ │
│  │ - SHA-256/384/512 hashing                             │ │
│  │ - HMAC operations                                     │ │
│  │ - RSA sign/verify/encrypt/decrypt                     │ │
│  │ - ECDSA sign/verify                                   │ │
│  │ - ECDH key agreement                                  │ │
│  │ - DRBG random number generation                       │ │
│  │                                                        │ │
│  │ Continuous Tests:                                      │ │
│  │ - Continuous RNG tests                                │ │
│  │ - Pairwise consistency tests                          │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                             │
│  CMVP Certificate: #4718                                    │
│  Validation Level: FIPS 140-3                               │
└─────────────────────────────────────────────────────────────┘
```

### Algorithm Mapping

| Operation | Application API | golang-fips Routes To | OpenSSL API | wolfSSL FIPS Function |
|-----------|----------------|----------------------|-------------|----------------------|
| **TLS Client** | `tls.Dial()` | OpenSSL TLS | `SSL_connect()` | `wolfSSL_connect()` |
| **TLS Server** | `http.ListenAndServeTLS()` | OpenSSL TLS | `SSL_accept()` | `wolfSSL_accept()` |
| **SHA-256** | `sha256.Sum256()` | OpenSSL Digest | `EVP_DigestInit_ex(EVP_sha256())` | `wc_Sha256Hash()` |
| **AES-GCM** | `cipher.NewGCM()` | OpenSSL Cipher | `EVP_CipherInit_ex(EVP_aes_256_gcm())` | `wc_AesGcmEncrypt()` |
| **RSA** | `rsa.SignPSS()` | OpenSSL RSA | `EVP_PKEY_sign()` | `wc_RsaSSL_Sign()` |
| **ECDSA** | `ecdsa.Sign()` | OpenSSL ECDSA | `EVP_PKEY_sign()` | `wc_ecc_sign_hash()` |
| **Random** | `rand.Read()` | OpenSSL RAND | `RAND_bytes()` | `wc_RNG_GenerateBlock()` |

## Build Architecture

### Multi-Stage Docker Build

The Dockerfile uses a 4-stage build process to create a minimal, secure runtime image:

```
┌───────────────────────────────────────────────────────┐
│ Stage 1: wolfssl-builder                              │
│ Base: ubuntu:22.04                                     │
│ Purpose: Build wolfSSL FIPS v5.8.2 from source        │
│ Output: /usr/local/lib/libwolfssl.so                  │
│         /usr/local/include/wolfssl/                    │
│         /usr/lib/x86_64-linux-gnu/libssl.so.3          │
│         /usr/lib/x86_64-linux-gnu/libcrypto.so.3       │
│ Duration: ~15-20 minutes                               │
└───────────────────────────────────────────────────────┘
                        │
                        ▼
┌───────────────────────────────────────────────────────┐
│ Stage 2: wolfprov-builder                             │
│ Base: ubuntu:22.04                                     │
│ Purpose: Build wolfProvider v1.1.0                    │
│ Input: wolfSSL from stage 1, OpenSSL from stage 1     │
│ Output: /usr/lib/x86_64-linux-gnu/ossl-modules/       │
│         libwolfprov.so                                 │
│ Duration: ~5-10 minutes                                │
└───────────────────────────────────────────────────────┘
                        │
                        ▼
┌───────────────────────────────────────────────────────┐
│ Stage 3: go-builder                                    │
│ Base: ubuntu:22.04                                     │
│ Purpose: Build golang-fips/go + redis_exporter        │
│ Steps:                                                 │
│   1. Install Go 1.22.6 bootstrap compiler             │
│   2. Clone golang-fips/go v1.25-fips-release          │
│   3. Build golang-fips/go from source                 │
│   4. Clone redis_exporter v1.67.0                     │
│   5. Build redis_exporter with golang-fips/go         │
│   6. Compile test-fips.c → fips-check binary          │
│ Output: /usr/local/bin/redis_exporter                 │
│         /usr/local/bin/fips-check                     │
│         /usr/local/go-fips/                            │
│ Duration: ~10-15 minutes                               │
└───────────────────────────────────────────────────────┘
                        │
                        ▼
┌───────────────────────────────────────────────────────┐
│ Stage 4: runtime (FINAL)                               │
│ Base: ubuntu:22.04                                     │
│ Purpose: Minimal runtime-only image                   │
│ Copies from previous stages:                           │
│   - OpenSSL 3.0.19 libraries (stage 1)                │
│   - wolfSSL FIPS library (stage 1)                    │
│   - wolfProvider module (stage 2)                     │
│   - redis_exporter binary (stage 3)                   │
│   - fips-check binary (stage 3)                       │
│ Installed packages: ca-certificates only              │
│ User: redis-exporter (UID 1001, non-root)             │
│ Final Size: ~180 MB                                    │
└───────────────────────────────────────────────────────┘
```

### Build Process Flow

```
wolfssl_password.txt (secret)
        │
        ▼
[Download wolfSSL FIPS v5.8.2 commercial package]
        │
        ▼
[Extract and configure with --enable-fips=v5 --disable-sha]
        │
        ▼
[Run fips-hash.sh (generates FIPS hash)]
        │
        ▼
[Compile wolfSSL → libwolfssl.so]
        │
        ├──────────────────────────────┐
        │                              │
        ▼                              ▼
[Build OpenSSL 3.0.19]      [Build wolfProvider]
        │                              │
        └──────────────┬───────────────┘
                       │
                       ▼
        [Build golang-fips/go compiler]
                       │
                       ▼
        [Build redis_exporter with golang-fips]
                       │
                       ▼
        [Copy to final runtime image]
                       │
                       ▼
        [Configure wolfProvider in openssl.cnf]
                       │
                       ▼
        [Verify FIPS validation passes]
                       │
                       ▼
              [Final Image Ready]
```

### Build Configuration Details

**wolfSSL FIPS Configuration:**
```bash
./configure \
    --prefix=/usr/local \
    --enable-fips=v5 \
    --enable-opensslcoexist \
    --disable-sha \         # Strict: blocks SHA-1 at library level
    --enable-cmac \
    --enable-keygen \
    --enable-aesctr \
    # ... additional features
```

**golang-fips/go Build:**
```bash
# Removed ChaCha20-Poly1305 (non-FIPS)
sed -i '/TLS_CHACHA20_POLY1305_SHA256/d' src/crypto/tls/*.go

# Build with FIPS support
CGO_ENABLED=1 \
CGO_CFLAGS="-I/usr/include -I/usr/local/include" \
CGO_LDFLAGS="-L/usr/lib/x86_64-linux-gnu -L/usr/local/lib" \
./make.bash
```

**redis_exporter Build:**
```bash
GOEXPERIMENT=strictfipsruntime \
go build \
    -ldflags="-s -w -X main.BuildVersion=v1.67.0" \
    -o redis_exporter \
    .
```

## Runtime Architecture

### Container Initialization Flow

```
[Container Start]
        │
        ▼
[docker-entrypoint.sh executes]
        │
        ├─── FIPS_CHECK=true ? ────┐
        │                          │
        │ Yes                       │ No (skip to start)
        ▼                          │
[Check 1/5: Environment Variables] │
        │                          │
        ▼                          │
[Check 2/5: wolfSSL FIPS POST]     │
        │ (runs fips-check binary) │
        ▼                          │
[Check 3/5: OpenSSL Version]       │
        │                          │
        ▼                          │
[Check 4/5: wolfProvider Loaded]   │
        │ (openssl list -providers)│
        ▼                          │
[Check 5/5: FIPS Enforcement]      │
        │ (MD5 should be blocked)  │
        ▼                          │
[All checks passed?] ──No─→ [EXIT 1]
        │                          │
       Yes                         │
        ├──────────────────────────┘
        ▼
[Start redis_exporter]
        │
        ▼
[Listen on :9121/metrics]
        │
        ▼
[Ready to accept requests]
```

### Runtime File Locations

```
/usr/local/bin/
├── redis_exporter           # Main exporter binary (FIPS-enabled)
├── fips-check                # FIPS validation utility
└── docker-entrypoint.sh      # Container entrypoint

/usr/local/lib/
└── libwolfssl.so.44         # wolfSSL FIPS library

/usr/lib/x86_64-linux-gnu/
├── libssl.so.3              # OpenSSL 3.0.19 TLS library
├── libcrypto.so.3           # OpenSSL 3.0.19 crypto library
└── ossl-modules/
    └── libwolfprov.so       # wolfProvider module

/etc/ssl/
└── openssl.cnf              # OpenSSL config (loads wolfProvider)

/etc/ld.so.conf.d/
└── wolfssl.conf             # Dynamic linker config for wolfSSL
```

### Environment Variables

**FIPS-related:**
```bash
GOLANG_FIPS=1                      # Enable FIPS in golang-fips/go
GODEBUG=fips140=only               # Block non-FIPS algorithms at runtime
GOEXPERIMENT=strictfipsruntime     # Compile-time FIPS enforcement
OPENSSL_CONF=/etc/ssl/openssl.cnf  # OpenSSL configuration
LD_LIBRARY_PATH=/usr/local/lib:/usr/lib/x86_64-linux-gnu:/usr/lib
```

**redis_exporter-related:**
```bash
REDIS_ADDR=redis://localhost:6379
REDIS_EXPORTER_WEB_LISTEN_ADDRESS=:9121
REDIS_EXPORTER_WEB_TELEMETRY_PATH=/metrics
REDIS_EXPORTER_LOG_FORMAT=txt
REDIS_EXPORTER_DEBUG=false
```

### Network Architecture

```
┌─────────────────────────────────────────────────────────┐
│  External Network                                        │
│                                                          │
│  Prometheus     ──→ HTTPS (TLS 1.2/1.3, FIPS ciphers)  │
│  (Scraper)          Port 9121                           │
│                     /metrics endpoint                    │
└────────────────────────────┬────────────────────────────┘
                             │
                             ▼
              ┌──────────────────────────┐
              │  redis_exporter          │
              │  (FIPS-compliant)        │
              │                          │
              │  HTTP Server (TLS)       │
              │  Metrics Collection      │
              └───────────┬──────────────┘
                          │
                          ▼
              ┌──────────────────────────┐
              │  Redis Server            │
              │  (single/cluster/        │
              │   sentinel)              │
              │                          │
              │  TLS 1.2/1.3 (FIPS)     │
              │  Port 6379/6380          │
              └──────────────────────────┘
```

## FIPS Compliance Implementation

### FIPS Mode Enforcement Layers

1. **Library Level (wolfSSL)**
   - Built with `--disable-sha` → SHA-1 blocked at source
   - FIPS POST runs on initialization
   - Only FIPS-approved algorithms compiled in

2. **Provider Level (wolfProvider)**
   - Routes all OpenSSL calls to wolfSSL FIPS
   - Configured as default provider in `openssl.cnf`
   - Non-FIPS providers disabled

3. **Runtime Level (golang-fips/go)**
   - `GODEBUG=fips140=only` → Runtime checks
   - `GOEXPERIMENT=strictfipsruntime` → Compile-time enforcement
   - All crypto delegated to OpenSSL (via CGO)

4. **Startup Level (docker-entrypoint.sh)**
   - Validates FIPS POST passed
   - Checks wolfProvider loaded
   - Tests algorithm blocking (MD5/SHA-1)

### FIPS Validation Flow

```
Container Start
    │
    ▼
wolfSSL Library Load
    │
    ▼
wolfCrypt_GetStatus_fips()
    │
    ├─ Run Power-On Self Test (POST)
    │  ├─ AES KAT (Known Answer Test)
    │  ├─ SHA-256 KAT
    │  ├─ HMAC KAT
    │  ├─ RSA KAT
    │  ├─ ECDSA KAT
    │  └─ DRBG KAT
    │
    ▼
POST Result
    │
    ├─ PASS → Continue
    │
    └─ FAIL → Exit with error
        │
        ▼
wolfProvider Initialization
    │
    ▼
OpenSSL Provider Registration
    │
    ▼
golang-fips/go Initialization
    │
    ▼
redis_exporter Start
    │
    ▼
FIPS-Compliant Operation
```

### Algorithm Availability Matrix

| Algorithm | FIPS Approved | Available | Blocked By |
|-----------|--------------|-----------|------------|
| **MD5** | ❌ No | ❌ Blocked | GODEBUG=fips140=only |
| **SHA-1** | ⚠️ Legacy only | ❌ Blocked | wolfSSL --disable-sha |
| **SHA-224** | ✅ Yes | ✅ Available | - |
| **SHA-256** | ✅ Yes | ✅ Available | - |
| **SHA-384** | ✅ Yes | ✅ Available | - |
| **SHA-512** | ✅ Yes | ✅ Available | - |
| **AES-128** | ✅ Yes | ✅ Available | - |
| **AES-192** | ✅ Yes | ✅ Available | - |
| **AES-256** | ✅ Yes | ✅ Available | - |
| **AES-GCM** | ✅ Yes | ✅ Available | - |
| **RSA-2048** | ✅ Yes | ✅ Available | - |
| **RSA-3072** | ✅ Yes | ✅ Available | - |
| **RSA-4096** | ✅ Yes | ✅ Available | - |
| **ECDSA P-256** | ✅ Yes | ✅ Available | - |
| **ECDSA P-384** | ✅ Yes | ✅ Available | - |
| **ECDSA P-521** | ✅ Yes | ✅ Available | - |
| **ChaCha20-Poly1305** | ❌ No | ❌ Blocked | Removed from TLS 1.3 |
| **RC4** | ❌ No | ❌ Blocked | Not compiled in wolfSSL |
| **DES/3DES** | ❌ Deprecated | ❌ Blocked | Not compiled in wolfSSL |

## Security Architecture

### Defense in Depth

```
┌────────────────────────────────────────────────────────┐
│ Layer 1: Container Isolation                           │
│ - Non-root user (redis-exporter, UID 1001)            │
│ - Read-only filesystem support                         │
│ - Minimal packages (ca-certificates only)              │
└────────────────────────────────────────────────────────┘
                        │
┌────────────────────────────────────────────────────────┐
│ Layer 2: Network Security                              │
│ - TLS 1.2+ only (TLS 1.0/1.1 disabled)                │
│ - FIPS-approved cipher suites only                    │
│ - Certificate validation enforced                      │
└────────────────────────────────────────────────────────┘
                        │
┌────────────────────────────────────────────────────────┐
│ Layer 3: Cryptographic Security                        │
│ - wolfSSL FIPS v5.8.2 (validated module)              │
│ - Continuous self-tests                                │
│ - Non-FIPS algorithms blocked                         │
└────────────────────────────────────────────────────────┘
                        │
┌────────────────────────────────────────────────────────┐
│ Layer 4: Runtime Security                              │
│ - GODEBUG=fips140=only enforcement                    │
│ - Startup FIPS validation                             │
│ - Algorithm blocking tests                            │
└────────────────────────────────────────────────────────┘
```

### Attack Surface Reduction

**Minimized:**
- Only 1 runtime package installed: `ca-certificates`
- No compiler/build tools in final image
- No shell utilities beyond bash (for entrypoint)
- No package manager in final image

**Network Exposure:**
- Single port: 9121 (metrics endpoint)
- Optional TLS on metrics endpoint
- No SSH/management interfaces

**User Privileges:**
- Non-root user: `redis-exporter` (UID 1001)
- No sudo/privilege escalation
- Limited filesystem access

## Performance Considerations

### FIPS Overhead

**Expected Performance Impact:**
- **TLS Handshake:** 5-10% slower (FIPS POST + validation)
- **Bulk Encryption:** 2-5% slower (validated crypto ops)
- **Hashing:** 1-3% slower (minimal impact)
- **Overall:** <10% total overhead

**Metrics Collection:**
- Redis command execution: No FIPS overhead (native Redis performance)
- Metrics formatting: No FIPS overhead (string operations)
- HTTP serving: Minor TLS overhead if TLS enabled

### Optimization Strategies

1. **Connection Pooling:**
   - redis_exporter maintains persistent connections to Redis
   - Amortizes TLS handshake cost

2. **Efficient Metrics Export:**
   - Binary format available (reduces parsing overhead)
   - Compression supported

3. **Caching:**
   - Internal caching of certain metrics
   - Reduces Redis query frequency

### Scalability

**Vertical Scaling:**
- CPU: FIPS crypto operations are CPU-bound
- Memory: Minimal (<100MB typical)
- Network: Bandwidth for metrics export

**Horizontal Scaling:**
- Multiple redis_exporter instances supported
- Each instance monitors different Redis servers
- Prometheus federation for aggregation

## Design Decisions

### Why Ubuntu 22.04 Instead of Alpine?

**Decision:** Use Ubuntu 22.04 LTS base image

**Rationale:**
1. **golang-fips/go Compatibility:** Tested and proven on glibc (Ubuntu), not musl (Alpine)
2. **Library Compatibility:** Better CGO/dynamic linking support
3. **Lower Build Complexity:** Established build patterns
4. **LTS Support:** 5 years of security updates

**Trade-off:** Larger image size (~180MB vs ~120MB)

### Why golang-fips/go Instead of Native Go?

**Decision:** Use golang-fips/go v1.25 fork

**Rationale:**
1. **FIPS Compliance:** Routes all crypto through OpenSSL (and thus wolfSSL FIPS)
2. **Standard Library:** Application code uses standard `crypto/*` packages
3. **Runtime Enforcement:** `GODEBUG=fips140=only` blocks non-FIPS algorithms
4. **Proven Approach:** Used by Red Hat, other FIPS-compliant distributions

**Trade-off:** Separate Go toolchain to maintain

### Why Multi-Stage Build?

**Decision:** 4-stage Docker build process

**Rationale:**
1. **Minimal Runtime Image:** Only copy necessary artifacts
2. **Build Reproducibility:** Each stage is independent
3. **Layer Caching:** Faster rebuilds
4. **Security:** No build tools in final image

**Trade-off:** Longer initial build time (~30-45 minutes)

### Why Compile test-fips.c in Build Stage?

**Decision:** Compile FIPS validation utility in go-builder stage

**Rationale:**
1. **Avoid Runtime Dependencies:** No gcc needed in final image
2. **Smaller Image:** Don't install build tools
3. **Faster Startup:** Pre-compiled binary ready to run

**Trade-off:** None (strictly better)

## Limitations and Trade-offs

### Known Limitations

1. **Build Time:**
   - Initial build: 30-45 minutes
   - Rebuilds: 10-15 minutes (with cache)
   - Mitigation: Use CI/CD caching, pre-built base images

2. **Image Size:**
   - ~180 MB (vs ~20 MB for standard redis_exporter)
   - Includes full OpenSSL, wolfSSL, golang-fips runtime
   - Mitigation: Acceptable for FIPS requirements

3. **TLS Performance:**
   - 5-10% overhead for TLS handshakes
   - Minimal for long-lived connections
   - Mitigation: Connection pooling, TLS session resumption

4. **SHA-1 Blocking:**
   - SHA-1 disabled at library level (`--disable-sha`)
   - May break compatibility with very old systems requiring SHA-1
   - Mitigation: Use SHA-256 for all new deployments

5. **ChaCha20-Poly1305 Unavailable:**
   - Removed from TLS 1.3 (not FIPS-approved)
   - TLS 1.3 still works (uses AES-GCM)
   - Mitigation: AES-GCM provides equivalent security

### Compatibility Considerations

**Compatible:**
- ✅ Redis 2.x - 7.x (all versions)
- ✅ Redis Cluster
- ✅ Redis Sentinel
- ✅ Prometheus (all versions)
- ✅ Prometheus Operator
- ✅ Grafana (all versions)

**Potential Issues:**
- ⚠️ Very old TLS implementations requiring SHA-1
- ⚠️ Systems expecting ChaCha20-Poly1305 cipher suites
- ⚠️ Clients not supporting TLS 1.2+

### Trade-off Summary

| Aspect | Standard Image | FIPS Image | Worth It? |
|--------|---------------|------------|-----------|
| **Image Size** | ~20 MB | ~180 MB | ✅ Yes (FIPS requirement) |
| **Build Time** | ~2 min | ~35 min | ✅ Yes (one-time cost) |
| **TLS Performance** | Baseline | -5-10% | ✅ Yes (minimal impact) |
| **Algorithm Choice** | All | FIPS only | ✅ Yes (security/compliance) |
| **Maintenance** | Easy | Moderate | ✅ Yes (well-documented) |

---

## Conclusion

This architecture provides a robust, FIPS 140-3 compliant implementation of redis_exporter while maintaining compatibility, performance, and security. The multi-layered approach ensures cryptographic compliance at every level, from the validated wolfSSL FIPS module through the golang-fips runtime to the application layer.

The design prioritizes:
1. **Compliance:** FIPS 140-3 validation through wolfSSL FIPS v5.8.2
2. **Security:** Defense in depth with multiple enforcement layers
3. **Performance:** Minimal overhead through optimization
4. **Maintainability:** Clear separation of concerns, standard tools
5. **Compatibility:** Support for all Redis versions and Prometheus ecosystem

**Last Updated:** March 27, 2026
**Architecture Version:** 1.0
**Image Version:** 1.67.0-jammy-ubuntu-22.04-fips
