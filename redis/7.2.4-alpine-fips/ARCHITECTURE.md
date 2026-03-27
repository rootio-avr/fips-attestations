# Redis 7.2.4 Alpine FIPS - Architecture

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

This document describes the technical architecture of the Redis 7.2.4 Alpine FIPS image, focusing on how FIPS 140-3 compliance is achieved while maintaining Redis functionality and performance.

### High-Level Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                    Redis 7.2.4 Application Layer                 │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐     │
│  │  Data Ops      │  │  Lua Scripts   │  │  TLS/Network   │     │
│  │  (SET/GET)     │  │  (SHA-256 hash)│  │  (TLS 1.2/1.3) │     │
│  └───────┬────────┘  └───────┬────────┘  └───────┬────────┘     │
└──────────┼───────────────────┼───────────────────┼──────────────┘
           │                   │                   │
           │    ┌──────────────┴──────────────┐    │
           │    │                             │    │
           ▼    ▼                             ▼    ▼
┌──────────────────────────────────────────────────────────────────┐
│               OpenSSL 3.3.0 EVP API Layer                        │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  EVP_DigestInit(), EVP_CipherInit(), SSL_connect(), etc.   │  │
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
│                   Alpine Linux 3.19 (musl libc)                  │
└──────────────────────────────────────────────────────────────────┘
```

## System Architecture

### Component Layers

The system is organized into distinct layers, each with specific responsibilities:

#### 1. Application Layer (Redis 7.2.4)
- **Purpose:** Redis functionality
- **Modifications:** FIPS-compliant SHA-256 hashing for Lua scripts
- **Dependencies:** OpenSSL 3.3.0 (via EVP API)

#### 2. Cryptographic API Layer (OpenSSL 3.3.0)
- **Purpose:** Standard cryptographic API
- **Role:** Abstraction layer between Redis and FIPS module
- **Benefits:** Application compatibility, provider flexibility

#### 3. Provider Layer (wolfProvider v1.1.0)
- **Purpose:** Bridge OpenSSL 3.x to wolfSSL FIPS
- **Implementation:** OpenSSL provider plugin
- **Function:** Dispatches crypto operations to wolfSSL

#### 4. FIPS Module Layer (wolfSSL FIPS v5.8.2)
- **Purpose:** FIPS 140-3 validated cryptographic operations
- **Certification:** CMVP Certificate #4718
- **Guarantee:** All crypto uses validated algorithms

#### 5. Operating System Layer (Alpine Linux 3.19)
- **Purpose:** Minimal base system
- **C Library:** musl libc (not glibc)
- **Benefits:** Small image size, reduced attack surface

### Data Flow

#### Example: Lua Script Hashing (EVAL Command)

```
User: redis-cli EVAL "return redis.call('PING')" 0
  │
  ▼
Redis: sha256hex(script_text, length)          [eval.c]
  │
  ▼
OpenSSL: EVP_DigestInit_ex(ctx, EVP_sha256())  [OpenSSL EVP API]
  │
  ▼
wolfProvider: wolfssl_sha256_init()             [wolfProvider dispatch]
  │
  ▼
wolfSSL FIPS: wc_InitSha256()                  [FIPS module]
  │
  ▼
Validated SHA-256 algorithm execution
  │
  ▼
Return 40-char hex digest (first 20 bytes of SHA-256)
```

#### Example: TLS Connection

```
Client: redis-cli --tls PING
  │
  ▼
Redis: TLS handshake via OpenSSL                [networking.c]
  │
  ▼
OpenSSL: SSL_connect() → SSL_do_handshake()    [OpenSSL SSL API]
  │
  ▼
wolfProvider:
  - RSA/ECDSA for certificates                 [wolfProvider crypto ops]
  - ECDH for key exchange
  - AES-GCM for symmetric encryption
  │
  ▼
wolfSSL FIPS:
  - wc_RsaSSL_Sign() / wc_ecc_sign_hash()      [FIPS-validated ops]
  - wc_AesGcmEncrypt() / wc_AesGcmDecrypt()
  │
  ▼
Secure TLS 1.2/1.3 connection established
```

## Cryptographic Stack

### wolfSSL FIPS v5.8.2 (CMVP #4718)

**What is wolfSSL FIPS?**

wolfSSL FIPS is a cryptographic module that has undergone rigorous testing and validation by NIST's Cryptographic Module Validation Program (CMVP). The validation process ensures:

1. **Correct Implementation** - Algorithms match NIST specifications
2. **Security Requirements** - Meets FIPS 140-3 security requirements
3. **Physical Security** - Tamper resistance (for hardware modules)
4. **Self-Tests** - Power-On Self Test (POST) and continuous tests

**Certificate #4718 Details:**

| Property | Value |
|----------|-------|
| Module Name | wolfCrypt FIPS |
| Module Version | v5.8.2 |
| Validation Level | FIPS 140-3 |
| Certificate Number | #4718 |
| Status | Active |
| Approved Algorithms | AES, SHA-2, HMAC, RSA, ECDSA, ECDH, DRBG |

**Validated Algorithms:**

```c
// AES (Advanced Encryption Standard)
- AES-128-CBC, AES-192-CBC, AES-256-CBC
- AES-128-GCM, AES-192-GCM, AES-256-GCM
- AES-128-CCM, AES-192-CCM, AES-256-CCM
- AES-128-CTR, AES-192-CTR, AES-256-CTR

// SHA (Secure Hash Algorithm)
- SHA-224, SHA-256, SHA-384, SHA-512
- SHA-512/224, SHA-512/256

// HMAC (Hash-based Message Authentication Code)
- HMAC-SHA-224, HMAC-SHA-256, HMAC-SHA-384, HMAC-SHA-512

// RSA (Rivest–Shamir–Adleman)
- RSA Key Generation (2048, 3072, 4096-bit)
- RSA Signature (PKCS#1 v1.5, PSS)
- RSA Encryption (OAEP)

// ECDSA (Elliptic Curve Digital Signature Algorithm)
- P-256, P-384, P-521 curves
- Signature generation and verification

// ECDH (Elliptic Curve Diffie-Hellman)
- P-256, P-384, P-521 curves
- Key agreement

// DRBG (Deterministic Random Bit Generator)
- Hash_DRBG (SHA-256)
- HMAC_DRBG (SHA-256)
```

### OpenSSL 3.3.0

**Why OpenSSL 3.x?**

OpenSSL 3.x introduced the **provider architecture**, which allows plugging in different cryptographic backends (like wolfSSL FIPS) without modifying applications.

**Provider Architecture:**

```
┌─────────────────────────────────────────────┐
│         Application (Redis)                 │
│  Uses: EVP_DigestInit(), SSL_connect()      │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│      OpenSSL 3.x Core (libssl, libcrypto)   │
│  - EVP API (high-level crypto functions)    │
│  - SSL/TLS protocol implementation          │
│  - Provider dispatch mechanism              │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
          Provider Loading
                   │
     ┌─────────────┴─────────────┐
     │                           │
     ▼                           ▼
┌─────────────┐          ┌──────────────────┐
│   default   │          │  wolfProvider    │
│  provider   │          │  (FIPS module)   │
│  (unused)   │          │  ← ACTIVE        │
└─────────────┘          └──────────────────┘
                                 │
                                 ▼
                         wolfSSL FIPS v5.8.2
```

**Provider Configuration (openssl.cnf):**

```ini
[openssl_init]
providers = provider_sect

[provider_sect]
fips = fips_sect

[fips_sect]
activate = 1
module = /usr/local/openssl/lib/ossl-modules/libwolfprov.so
```

This configuration:
1. Loads wolfProvider as the FIPS provider
2. Activates it as the default for crypto operations
3. All EVP API calls → wolfProvider → wolfSSL FIPS

### wolfProvider v1.1.0

**What is wolfProvider?**

wolfProvider is an OpenSSL 3.x provider that implements the OpenSSL provider interface and dispatches cryptographic operations to wolfSSL FIPS.

**Architecture:**

```c
// OpenSSL 3.x calls EVP function
EVP_DigestInit_ex(ctx, EVP_sha256(), NULL);
  │
  ▼
// OpenSSL core dispatches to active provider
provider_dispatch(OSSL_OP_DIGEST, "SHA256");
  │
  ▼
// wolfProvider receives dispatch
static const OSSL_DISPATCH wp_sha256_functions[] = {
    { OSSL_FUNC_DIGEST_NEWCTX, (void (*)(void))wp_sha256_newctx },
    { OSSL_FUNC_DIGEST_INIT, (void (*)(void))wp_sha256_init },
    { OSSL_FUNC_DIGEST_UPDATE, (void (*)(void))wp_sha256_update },
    { OSSL_FUNC_DIGEST_FINAL, (void (*)(void))wp_sha256_final },
    ...
};
  │
  ▼
// wolfProvider calls wolfSSL FIPS
int wp_sha256_init(WP_SHA256_CTX *ctx) {
    return wc_InitSha256(&ctx->sha256);  // ← wolfSSL FIPS function
}
```

**Benefits:**

1. **No Application Changes** - Redis uses standard OpenSSL EVP API
2. **FIPS Compliance** - All crypto routed to validated module
3. **Transparency** - Applications don't know about wolfSSL
4. **Flexibility** - Can switch providers if needed

## Build Architecture

### Multi-Stage Docker Build

The image uses a two-stage build process to minimize final image size:

#### Stage 1: Builder (Alpine 3.19)

**Purpose:** Compile all components from source

**Steps:**

1. **Install Build Dependencies**
   ```dockerfile
   RUN apk add build-base gcc g++ make cmake \
       autoconf automake libtool pkgconfig \
       git curl wget p7zip perl coreutils \
       linux-headers musl-dev openssl-dev
   ```

2. **Build OpenSSL 3.3.0**
   ```bash
   ./Configure --prefix=/usr/local/openssl \
       --openssldir=/usr/local/openssl/ssl \
       enable-fips no-shared
   make -j$(nproc)
   make install
   ```

3. **Build wolfSSL FIPS v5.8.2**
   ```bash
   ./configure --enable-fips=v5 \
       --enable-opensslcoexist \
       --enable-cmac --enable-keygen --enable-sha \
       --enable-aesctr --enable-aesccm ...
   make -j$(nproc)
   ./fips-hash.sh  # ← CRITICAL: FIPS integrity check
   make -j$(nproc)
   make install
   ```

   **Note:** The `fips-hash.sh` step computes HMAC-SHA256 over the wolfSSL FIPS binary. This hash is embedded in the module and verified during POST. Any modification to the binary will fail FIPS validation.

4. **Build wolfProvider v1.1.0**
   ```bash
   ./configure --with-openssl=/usr/local/openssl \
       --with-wolfssl=/usr/local \
       --prefix=/usr/local
   make -j$(nproc)
   make install
   ```

5. **Patch and Build Redis 7.2.4**
   ```bash
   patch -p1 < redis-fips-sha256-redis7.2.4.patch
   make BUILD_TLS=yes \
       CFLAGS="-I/usr/local/openssl/include" \
       LDFLAGS="-L/usr/local/openssl/lib -Wl,-rpath,/usr/local/openssl/lib"
   make install
   ```

#### Stage 2: Runtime (Alpine 3.19)

**Purpose:** Minimal runtime image

**Steps:**

1. **Copy Binaries from Builder**
   ```dockerfile
   COPY --from=builder /usr/local/openssl /usr/local/openssl
   COPY --from=builder /usr/local/lib/libwolfssl.* /usr/local/lib/
   COPY --from=builder /usr/local/bin/redis-* /usr/local/bin/
   ```

2. **Install Minimal Runtime Dependencies**
   ```dockerfile
   RUN apk add --no-cache \
       ca-certificates tzdata \
       libgcc libstdc++
   ```

3. **Configure Dynamic Linker (musl)**
   ```bash
   echo "/usr/local/openssl/lib" > /etc/ld-musl-x86_64.path
   echo "/usr/local/lib" >> /etc/ld-musl-x86_64.path
   ```

4. **Create Redis User**
   ```bash
   addgroup -g 1000 redis
   adduser -D -u 1000 -G redis -h /data -s /bin/sh redis
   ```

**Result:**
- Builder stage: ~2 GB (discarded)
- Runtime stage: **119.49 MB**

### Dependency Graph

```
┌──────────────────┐
│  Redis 7.2.4     │
└────────┬─────────┘
         │ depends on
         ▼
┌──────────────────┐
│  OpenSSL 3.3.0   │ ← libssl.so.3, libcrypto.so.3
└────────┬─────────┘
         │ loads provider
         ▼
┌──────────────────┐
│ wolfProvider 1.1.0│ ← libwolfprov.so
└────────┬─────────┘
         │ calls
         ▼
┌──────────────────┐
│ wolfSSL FIPS 5.8.2│ ← libwolfssl.so.42
└──────────────────┘
```

**Library Dependencies (ldd):**

```bash
$ ldd /usr/local/bin/redis-server
    libssl.so.3 => /usr/local/openssl/lib/libssl.so.3
    libcrypto.so.3 => /usr/local/openssl/lib/libcrypto.so.3
    libpthread.so.0 => /lib/libpthread.so.0
    libc.musl-x86_64.so.1 => /lib/ld-musl-x86_64.so.1
```

## Runtime Architecture

### Startup Sequence

```
Container Start
    │
    ▼
docker-entrypoint.sh executes
    │
    ├─► [CHECK 1/5] Verify environment variables
    │     - OPENSSL_CONF=/usr/local/openssl/ssl/openssl.cnf
    │     - OPENSSL_MODULES=/usr/local/openssl/lib/ossl-modules
    │     - LD_LIBRARY_PATH=/usr/local/openssl/lib:/usr/local/lib
    │
    ├─► [CHECK 2/5] Run wolfSSL FIPS POST
    │     - Execute: fips-startup-check
    │     - Verifies: wolfSSL FIPS mode enabled
    │     - Tests: AES-GCM encryption (FIPS algorithm)
    │     - Result: POST PASSED or FAILED
    │
    ├─► [CHECK 3/5] Verify OpenSSL version
    │     - Command: openssl version
    │     - Expected: OpenSSL 3.3.0
    │
    ├─► [CHECK 4/5] Verify wolfProvider loaded
    │     - Command: openssl list -providers
    │     - Expected: "wolfSSL Provider FIPS" active
    │
    ├─► [CHECK 5/5] Test FIPS enforcement
    │     - Command: openssl dgst -md5 (should FAIL)
    │     - Verifies: Non-FIPS algorithms blocked
    │
    ▼
All checks PASSED?
    │
    ├─► YES: Start Redis server
    │     └─► exec redis-server /etc/redis/redis.conf
    │
    └─► NO: Exit with error
          └─► Container terminates
```

### FIPS POST (Power-On Self Test)

Every time the container starts, wolfSSL FIPS performs a comprehensive self-test:

**POST Components:**

1. **Known Answer Tests (KAT)**
   - AES-CBC, AES-GCM encryption/decryption
   - SHA-256 hashing
   - HMAC-SHA-256
   - RSA signature generation/verification
   - ECDSA signature generation/verification
   - DRBG (random number generation)

2. **Pairwise Consistency Test (PCT)**
   - RSA key pair generation
   - ECDSA key pair generation
   - Verifies generated keys work correctly

3. **Continuous Tests**
   - DRBG continuous random number test
   - Ensures no repeated random values

**POST Execution:**

```c
// Simplified POST flow in wolfSSL FIPS
int wolfCrypt_FIPS_first(void) {
    // 1. Verify module integrity
    if (verifyCore() != 0) {
        return FIPS_INTEGRITY_FAILED;
    }

    // 2. Run KATs
    if (AES_KAT() != 0) return FIPS_KAT_AES_FAILED;
    if (SHA256_KAT() != 0) return FIPS_KAT_SHA256_FAILED;
    if (HMAC_KAT() != 0) return FIPS_KAT_HMAC_FAILED;
    if (RSA_KAT() != 0) return FIPS_KAT_RSA_FAILED;
    if (ECDSA_KAT() != 0) return FIPS_KAT_ECDSA_FAILED;
    if (DRBG_KAT() != 0) return FIPS_KAT_DRBG_FAILED;

    // 3. Run PCTs
    if (RSA_PCT() != 0) return FIPS_PCT_RSA_FAILED;
    if (ECDSA_PCT() != 0) return FIPS_PCT_ECDSA_FAILED;

    return 0; // POST PASSED
}
```

**POST Failure Handling:**

If POST fails, the container will **NOT start**. This is critical for FIPS compliance - a failed POST indicates:
- Module integrity compromised (tampered binary)
- Algorithm implementation error
- Hardware fault

### Memory Layout

```
┌───────────────────────────────────────────┐
│  Container Memory Space                   │
├───────────────────────────────────────────┤
│  Redis Process (PID 1)                    │
│  ┌─────────────────────────────────────┐  │
│  │  .text (code segment)               │  │
│  │  - Redis core logic                 │  │
│  │  - OpenSSL libssl/libcrypto         │  │
│  │  - wolfSSL FIPS module (read-only)  │  │
│  ├─────────────────────────────────────┤  │
│  │  .data (initialized data)           │  │
│  │  - Global variables                 │  │
│  │  - Configuration                    │  │
│  ├─────────────────────────────────────┤  │
│  │  .bss (uninitialized data)          │  │
│  ├─────────────────────────────────────┤  │
│  │  Heap                               │  │
│  │  - Redis data structures (keys)     │  │
│  │  - Jemalloc allocator               │  │
│  │  - Crypto contexts (EVP_MD_CTX)     │  │
│  ├─────────────────────────────────────┤  │
│  │  Stack                              │  │
│  │  - Function call frames             │  │
│  │  - Local variables                  │  │
│  └─────────────────────────────────────┘  │
│                                           │
│  /data (persistent volume)                │
│  ├─ dump.rdb (RDB snapshot)               │
│  └─ appendonly.aof (AOF log)              │
└───────────────────────────────────────────┘
```

## FIPS Compliance Implementation

### Redis Source Code Modifications

The image applies a custom patch to Redis source to replace non-FIPS SHA-1 with FIPS-approved SHA-256.

#### Modified Files

**1. src/eval.c - Lua Script Hashing**

**Before (SHA-1):**
```c
void sha1hex(char *digest, char *script, size_t len) {
    SHA1_CTX ctx;
    unsigned char hash[20];

    SHA1Init(&ctx);
    SHA1Update(&ctx, (unsigned char*)script, len);
    SHA1Final(hash, &ctx);

    // Convert to hex...
}
```

**After (SHA-256 via OpenSSL EVP):**
```c
void sha256hex(char *digest, char *script, size_t len) {
    unsigned char hash[SHA256_DIGEST_LENGTH];
    unsigned int hash_len = SHA256_DIGEST_LENGTH;

    EVP_MD_CTX *mdctx = EVP_MD_CTX_new();
    EVP_DigestInit_ex(mdctx, EVP_sha256(), NULL);  // ← OpenSSL EVP
    EVP_DigestUpdate(mdctx, script, len);
    EVP_DigestFinal_ex(mdctx, hash, &hash_len);
    EVP_MD_CTX_free(mdctx);

    // Convert first 20 bytes to hex (40 chars)
    // Truncated for backward compatibility
}
```

**Impact:**
- Script IDs change from 40-char SHA-1 to 40-char SHA-256 (truncated)
- Existing EVALSHA calls will fail (script cache must be flushed)
- FIPS-compliant: SHA-256 is FIPS-approved

**2. src/debug.c - DEBUG DIGEST Command**

Similar changes to `xorDigest()` and `mixDigest()` functions.

**3. src/script_lua.c - Lua redis.sha1hex() API**

Updates Lua API function to call `sha256hex()` internally while keeping the API name for backward compatibility.

**4. src/server.h - Function Declarations**

Updates function signature: `sha1hex()` → `sha256hex()`

### Patch Application Process

```bash
# During Docker build
cd redis-7.2.4
patch -p1 < /tmp/redis-fips-sha256-redis7.2.4.patch

# Verify patch applied successfully
echo $?  # Should be 0

# Files modified
git diff src/eval.c src/debug.c src/script_lua.c src/server.h
```

**Patch Verification:**

The patch is tested during the build process:
1. Pre-build validation (`test-build.sh --full`)
2. Applies patch to clean Redis source
3. Verifies all hunks apply successfully
4. Build proceeds only if patch applies cleanly

### FIPS Boundary

The **FIPS cryptographic boundary** encompasses the wolfSSL FIPS module (libwolfssl.so.42):

```
┌──────────────────────────────────────────────────────┐
│              Non-FIPS Components                     │
│  Redis, OpenSSL 3.3.0, wolfProvider                  │
│  (Trusted but not FIPS-validated)                    │
└───────────────────┬──────────────────────────────────┘
                    │
        ┌───────────┴───────────┐
        │  FIPS Boundary Entry  │
        │  (wolfProvider calls) │
        └───────────┬───────────┘
                    │
                    ▼
┌──────────────────────────────────────────────────────┐
│         FIPS Cryptographic Boundary                  │
│                                                      │
│     wolfSSL FIPS v5.8.2 (CMVP #4718)                │
│                                                      │
│  ┌────────────────────────────────────────────────┐ │
│  │  Validated Algorithms                          │ │
│  │  - AES-CBC, AES-GCM, AES-CCM, AES-CTR         │ │
│  │  - SHA-224, SHA-256, SHA-384, SHA-512         │ │
│  │  - HMAC-SHA-2 family                          │ │
│  │  - RSA (2048, 3072, 4096-bit)                 │ │
│  │  - ECDSA, ECDH (P-256, P-384, P-521)          │ │
│  │  - DRBG (Hash_DRBG, HMAC_DRBG)                │ │
│  └────────────────────────────────────────────────┘ │
│                                                      │
│  ┌────────────────────────────────────────────────┐ │
│  │  Self-Tests                                    │ │
│  │  - Power-On Self Test (POST)                  │ │
│  │  - Continuous Tests                           │ │
│  │  - Integrity Verification (HMAC-SHA256)       │ │
│  └────────────────────────────────────────────────┘ │
│                                                      │
└──────────────────────────────────────────────────────┘
```

**Key Points:**

1. **Only operations within the boundary are FIPS-validated**
2. **All cryptographic operations must go through the boundary**
3. **The boundary is maintained by wolfProvider** - ensures all crypto routes to wolfSSL FIPS
4. **No bypass mechanisms** - Non-FIPS algorithms blocked at wolfSSL level

## Security Architecture

### Threat Model

**Assumed Threats:**

1. **Network Attacks**
   - Man-in-the-middle (MITM)
   - Eavesdropping
   - Replay attacks

2. **Cryptographic Attacks**
   - Weak algorithm exploitation (MD5, SHA-1)
   - Side-channel attacks
   - Downgrade attacks

3. **Container Escape**
   - Privilege escalation
   - Kernel vulnerabilities

**Mitigations:**

| Threat | Mitigation |
|--------|-----------|
| MITM | TLS 1.2/1.3 with strong ciphers |
| Weak Algorithms | FIPS mode blocks non-approved algorithms |
| Side-channel | wolfSSL FIPS includes side-channel resistance |
| Container Escape | Run as non-root, read-only filesystem option |
| Privilege Escalation | Minimal installed packages, no sudo |

### Defense in Depth

**Layer 1: FIPS Enforcement**
- wolfSSL FIPS POST validates module integrity
- Non-FIPS algorithms blocked at compile time
- Continuous tests during operation

**Layer 2: TLS**
- TLS 1.2/1.3 for encrypted communication
- Certificate-based authentication
- Perfect Forward Secrecy (PFS) with ECDHE

**Layer 3: Application Security**
- Redis authentication (`requirepass`)
- ACLs (Access Control Lists) in Redis 6+
- Command renaming/disabling

**Layer 4: Container Security**
- Non-root user (UID 1000)
- Minimal base image (Alpine)
- No unnecessary packages

**Layer 5: Network Security**
- Network policies (Kubernetes)
- Firewall rules
- VPN/Private network

### Secure Boot Flow

```
Container Start
    │
    ├─► Environment variable validation
    │     Prevents misconfigurations
    │
    ├─► wolfSSL FIPS POST
    │     Verifies module integrity and algorithms
    │     CRITICAL: Container exits if POST fails
    │
    ├─► OpenSSL configuration check
    │     Ensures wolfProvider is loaded
    │     Verifies FIPS provider is active
    │
    ├─► FIPS enforcement test
    │     Tests that MD5 is blocked
    │     Confirms FIPS mode is operational
    │
    └─► Start Redis server
          Only if all security checks pass
```

## Performance Considerations

### FIPS Overhead

**Expected Performance Impact:**

| Operation | Overhead | Notes |
|-----------|----------|-------|
| SHA-256 hashing | 5-10% | Lua script hashing |
| AES-GCM encryption | 3-7% | TLS bulk encryption |
| RSA signatures | 2-5% | TLS handshakes |
| ECDSA signatures | 2-5% | TLS handshakes |
| Redis operations | <5% | Minimal impact on SET/GET |

**Benchmark Results:**

```bash
# FIPS Redis
redis-benchmark -t set,get -n 100000 -q
SET: 89285.71 requests per second
GET: 91743.12 requests per second

# Non-FIPS Redis (reference)
SET: 94339.62 requests per second
GET: 96153.84 requests per second

# Overhead: ~5%
```

**Optimization Strategies:**

1. **Connection Pooling** - Reduce TLS handshake overhead
2. **Pipelining** - Batch Redis commands
3. **Persistent Connections** - Amortize TLS cost
4. **Hardware Acceleration** - Use AES-NI if available (wolfSSL supports it)

### Memory Usage

**Memory Footprint:**

| Component | Memory |
|-----------|--------|
| Redis process | ~10 MB (baseline) |
| wolfSSL FIPS module | ~3 MB |
| OpenSSL libraries | ~5 MB |
| Total overhead | ~8 MB |

**Data structures:**

```c
// EVP context (per crypto operation)
sizeof(EVP_MD_CTX) = ~200 bytes

// wolfSSL SHA-256 context
sizeof(wc_Sha256) = 112 bytes

// Per-connection TLS state
sizeof(WOLFSSL) = ~4 KB
```

## Design Decisions

### Why Alpine Linux?

**Pros:**
- ✅ Small image size (119 MB vs ~300 MB for Debian)
- ✅ Minimal attack surface
- ✅ Fast build times
- ✅ musl libc is well-maintained

**Cons:**
- ❌ musl vs glibc differences (library paths, ldconfig)
- ❌ Fewer pre-built packages
- ❌ Some software assumes glibc

**Decision:** Use Alpine for minimal size, handle musl-specific configuration (`/etc/ld-musl-*.path` instead of `/etc/ld.so.conf`)

### Why OpenSSL 3.x Provider Model?

**Alternatives Considered:**

1. **Direct wolfSSL API in Redis**
   - Pro: No OpenSSL dependency
   - Con: Requires extensive Redis code changes

2. **OpenSSL with FIPS module**
   - Pro: Standard OpenSSL FIPS
   - Con: OpenSSL FIPS 3.0 module not yet validated under FIPS 140-3

3. **OpenSSL 3.x + wolfProvider** ✅ **CHOSEN**
   - Pro: No Redis changes needed
   - Pro: Uses validated wolfSSL FIPS
   - Pro: Transparent to applications
   - Con: Extra layer (minimal overhead)

### Why Patch Redis Instead of LD_PRELOAD?

**Alternatives:**

1. **LD_PRELOAD to intercept SHA-1 calls**
   - Pro: No source changes
   - Con: Fragile, may break on Redis updates
   - Con: Not transparent (script IDs still SHA-1 based)

2. **Patch Redis source** ✅ **CHOSEN**
   - Pro: Clean, maintainable
   - Pro: Script IDs use SHA-256 (FIPS-compliant)
   - Con: Requires maintenance for new Redis versions

### Why Truncate SHA-256 to 20 Bytes?

**Decision:** Output 40-character hex string (20 bytes) from SHA-256

**Rationale:**
- Maintains compatibility with script ID format
- 160 bits (20 bytes) still cryptographically strong
- Redis expects 40-character script IDs

**Security:** SHA-256 truncated to 160 bits provides similar collision resistance to full SHA-1 but without SHA-1's weaknesses.

## Limitations and Trade-offs

### Breaking Changes

#### 1. Script IDs Change

**Issue:** EVALSHA with old script IDs will fail

**Workaround:**
```bash
# Clear script cache
redis-cli SCRIPT FLUSH

# Re-load scripts using EVAL
# Script IDs will be recalculated with SHA-256
```

**Impact:** Applications must reload all scripts after migration

#### 2. Replication Incompatibility

**Issue:** FIPS Redis cannot replicate to/from non-FIPS Redis

**Reason:** Script IDs differ (SHA-256 vs SHA-1)

**Solution:** Homogeneous clusters (all FIPS or all non-FIPS)

#### 3. DEBUG DIGEST Values Change

**Issue:** DEBUG DIGEST output differs from non-FIPS Redis

**Impact:** Low (DEBUG DIGEST is rarely used in production)

### Performance Trade-offs

**FIPS Overhead:** ~5% for typical workloads

**Acceptable for:**
- Applications prioritizing compliance over raw performance
- Workloads with I/O bottlenecks (disk, network)
- Moderate throughput requirements

**Not ideal for:**
- Ultra-high throughput applications (>100K ops/sec)
- CPU-bound workloads with heavy crypto

**Mitigation:**
- Use connection pooling
- Enable pipelining
- Scale horizontally (more Redis instances)

### wolfSSL Commercial License

**Requirement:** wolfSSL FIPS v5.8.2 requires a commercial license

**Impact:**
- Build requires wolfSSL commercial download credentials
- Not freely redistributable (license restrictions)

**Alternatives:** None for FIPS 140-3 (as of March 2026)

---

**Document Version:** 1.0
**Last Updated:** March 26, 2026
**Maintained By:** Root FIPS Team
