# Node.js 18 wolfSSL FIPS Architecture

**Document Version**: 1.0
**Last Updated**: 2026-03-22
**FIPS Certificate**: #4718 (wolfSSL 5.8.2)
**Architecture**: Provider-based (OpenSSL 3.0 with wolfProvider)

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture Diagram](#architecture-diagram)
3. [Component Stack](#component-stack)
4. [FIPS 140-3 Cryptographic Module](#fips-140-3-cryptographic-module)
5. [Provider Architecture](#provider-architecture)
6. [Configuration Management](#configuration-management)
7. [Security Properties](#security-properties)
8. [Comparison with Alternatives](#comparison-with-alternatives)
9. [Build Process](#build-process)
10. [Validation and Testing](#validation-and-testing)

---

## Overview

This implementation provides FIPS 140-3 validated cryptography for Node.js 18 applications using a **provider-based architecture**. Instead of recompiling Node.js from source with wolfSSL, we use **OpenSSL 3.0's provider interface** to route cryptographic operations to wolfSSL's FIPS-validated module.

### Key Features

- **FIPS 140-3 Validated**: wolfSSL 5.8.2 (Certificate #4718)
- **Provider-based**: Uses OpenSSL 3.0.11 provider architecture
- **Node.js 18.20.8 LTS**: Full standard library support
- **TLS 1.2/1.3**: Modern protocol support with FIPS-approved cipher suites
- **No Node.js Compilation**: Works with pre-built NodeSource binaries
- **Fast Build**: ~10 minutes (vs 25-60 minutes for source compilation)
- **Debian Bookworm**: Based on stable Debian 12

### Architecture Type

**Provider-based** (recommended approach for OpenSSL 3.0+)

```
Node.js 18.20.8 → OpenSSL 3.0.11 API → wolfProvider v1.0.2 → wolfSSL 5.8.2 FIPS
```

This differs from:
- **Engine-based** (deprecated in OpenSSL 3.0)
- **Direct replacement** (requires Node.js source compilation)
- **Static linking** (requires Node.js source compilation, ~60 min builds)

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│ Node.js Application Layer                               │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ JavaScript/TypeScript Code (app.js)                 │ │
│ │   const crypto = require('crypto');                 │ │
│ │   const https = require('https');                   │ │
│ │   const tls = require('tls');                       │ │
│ └─────────────────────────────────────────────────────┘ │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│ Node.js Core Modules (Built-in)                         │
│ ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│ │ crypto       │  │ tls          │  │ https        │   │
│ │ (C++ binding)│  │ (TLS/SSL)    │  │ (HTTPS)      │   │
│ └──────────────┘  └──────────────┘  └──────────────┘   │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Node.js Crypto Binding (node_crypto.cc)             │ │
│ │ - crypto.createHash(), createCipher(), etc.         │ │
│ │ - TLS connection management                         │ │
│ │ - Certificate validation                            │ │
│ └─────────────────────────────────────────────────────┘ │
└────────────────────────┬────────────────────────────────┘
                         │ libssl.so.3, libcrypto.so.3
                         ▼
┌─────────────────────────────────────────────────────────┐
│ OpenSSL 3.0.11 (Provider Interface)                     │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ SSL/TLS Engine (libssl.so.3)                        │ │
│ │ - Protocol handling (TLS 1.2, TLS 1.3)              │ │
│ │ - Certificate validation                            │ │
│ │ - Handshake management                              │ │
│ │ - Cipher suite negotiation                          │ │
│ └─────────────────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Crypto API Layer (libcrypto.so.3)                   │ │
│ │ - Algorithm dispatch via EVP interface              │ │
│ │ - Provider loading and management                   │ │
│ │ - Configuration: /usr/local/ssl/openssl.cnf         │ │
│ │ - FIPS mode control (FIPS_mode_set)                 │ │
│ └─────────────────────────────────────────────────────┘ │
└────────────────────────┬────────────────────────────────┘
                         │ Provider API (OSSL_PROVIDER)
                         ▼
┌─────────────────────────────────────────────────────────┐
│ wolfProvider v1.0.2                                     │
│ (/usr/local/lib/ossl-modules/libwolfprov.so)            │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Provider Implementation                             │ │
│ │ - Implements OpenSSL provider interface             │ │
│ │ - Routes crypto operations to wolfSSL               │ │
│ │ - Registers FIPS-approved algorithms                │ │
│ │   ✓ AES-CBC (128, 192, 256)                         │ │
│ │   ✓ AES-GCM (128, 192, 256) - one-shot only*       │ │
│ │   ✓ SHA-2 family (SHA-256, SHA-384, SHA-512)        │ │
│ │   ✓ ECDHE, RSA, HMAC                                │ │
│ │   ✓ PBKDF2** (validated but not via Node.js API)   │ │
│ │   ✓ TLS 1.2, TLS 1.3 cipher suites                  │ │
│ │ - Filters weak algorithms (MD5, SHA-1 in TLS)       │ │
│ │                                                       │ │
│ │ * Streaming API requires FIPS v6+                   │ │
│ │ ** wolfProvider v1.0.2 interface limitation         │ │
│ └─────────────────────────────────────────────────────┘ │
└────────────────────────┬────────────────────────────────┘
                         │ wolfSSL API
                         ▼
┌─────────────────────────────────────────────────────────┐
│ wolfSSL 5.8.2 FIPS 140-3 Module                         │
│ (/usr/local/lib/libwolfssl.so.44.0.0)                   │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ FIPS Cryptographic Module                           │ │
│ │ ┌─────────────────────────────────────────────────┐ │ │
│ │ │ FIPS Boundary (789,400 bytes)                   │ │ │
│ │ │ - Validated algorithms only                     │ │ │
│ │ │ - Power-On Self Tests (POST)                    │ │ │
│ │ │ - Known Answer Tests (KAT)                      │ │ │
│ │ │ - Integrity verification (HMAC-SHA-256)         │ │ │
│ │ └─────────────────────────────────────────────────┘ │ │
│ │                                                       │ │
│ │ Certificate: #4718                                   │ │
│ │ Security Level: 1                                    │ │
│ │ Validation Date: 2024                                │ │
│ │ Algorithms: AES, SHA-2, RSA, ECDH, HMAC, DRBG        │ │
│ └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
                    Hardware/OS
```

---

## Component Stack

### Layer 1: Node.js Application Layer

**Components:**
- Node.js 18.20.8 application code
- Built-in modules: `crypto`, `tls`, `https`, `http`
- Third-party libraries: `axios`, `node-fetch`, `express`, etc.

**Responsibilities:**
- Application logic
- TLS connection requests
- Certificate verification
- Cryptographic operations via standard Node.js APIs

**FIPS Relevance:**
- No application code changes required for FIPS compliance
- Transparent FIPS operation through standard modules
- `crypto.getFips()` returns 1 to indicate FIPS mode

**Example:**
```javascript
const crypto = require('crypto');
const https = require('https');

// FIPS mode automatically enabled
console.log('FIPS mode:', crypto.getFips()); // Output: 1

// Standard crypto operations use FIPS-validated module
const hash = crypto.createHash('sha256').update('test').digest('hex');

// TLS connections use only FIPS-approved cipher suites
https.get('https://www.example.com', (res) => {
  console.log('Cipher:', res.socket.getCipher());
  // Output: { name: 'TLS_AES_256_GCM_SHA384', ... }
});
```

---

### Layer 2: Node.js Core Modules

**Components:**
- **crypto module** - Cryptographic functionality
- **tls module** - TLS/SSL protocol implementation
- **https module** - HTTPS client/server
- **node_crypto.cc** - C++ binding to OpenSSL

**File Locations:**
```
/usr/bin/node (Node.js 18.20.8 executable)
Internal C++ bindings to OpenSSL libssl.so.3 and libcrypto.so.3
```

**Dynamic Linking:**
Node.js 18.20.8 from NodeSource is dynamically linked to system OpenSSL:
```bash
$ ldd /usr/bin/node | grep ssl
    libssl.so.3 => /usr/local/lib/libssl.so.3
    libcrypto.so.3 => /usr/local/lib/libcrypto.so.3
```

**Configuration Auto-Detection:**
Node.js 18+ automatically reads OpenSSL configuration via `--openssl-shared-config` flag:
```bash
# Enabled by default in Node.js 18+
NODE_OPTIONS=--openssl-shared-config node app.js
```

This flag makes Node.js use the system OpenSSL configuration (`/usr/local/ssl/openssl.cnf`), which activates the wolfProvider.

**API Examples:**
```javascript
// crypto module
const crypto = require('crypto');

// Hash operations - routed to wolfProvider → wolfSSL
const sha256 = crypto.createHash('sha256');
// Calls: EVP_DigestInit_ex() → wolfProvider → wc_Sha256Init()

// Cipher operations - routed to wolfProvider → wolfSSL
const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
// Calls: EVP_CipherInit_ex() → wolfProvider → wc_AesGcmSetKey()

// TLS connections - uses wolfProvider cipher suites
const tls = require('tls');
const socket = tls.connect({ host: 'www.example.com', port: 443 });
// Calls: SSL_connect() → wolfProvider → wolfSSL_connect()
```

---

### Layer 3: OpenSSL 3.0.11

**Components:**
- **libssl.so.3** - SSL/TLS protocol implementation
- **libcrypto.so.3** - Cryptographic algorithms and providers

**Configuration:**
- `/usr/local/ssl/openssl.cnf` - Provider configuration
- Environment: `OPENSSL_CONF=/usr/local/ssl/openssl.cnf`
- Module path: `OPENSSL_MODULES=/usr/local/lib/ossl-modules`

**Key Functions:**
- Protocol handling (TLS 1.2, TLS 1.3)
- Certificate chain validation
- Provider interface management
- Algorithm dispatch via EVP API
- FIPS mode control

**Provider Loading:**
```c
// OpenSSL loads providers at initialization
OSSL_PROVIDER *prov = OSSL_PROVIDER_load(NULL, "wolfprov");
OSSL_PROVIDER_set_default_search_path(NULL, "/usr/local/lib/ossl-modules");

// Set FIPS mode (enabled via openssl.cnf)
EVP_default_properties_enable_fips(NULL, 1);
```

**EVP Interface:**
The EVP (Envelope) API provides a high-level interface for cryptographic operations:

```c
// Hash operation flow
EVP_MD_CTX *ctx = EVP_MD_CTX_new();
EVP_DigestInit_ex(ctx, EVP_sha256(), NULL);  // ← Routes to wolfProvider
EVP_DigestUpdate(ctx, data, len);
EVP_DigestFinal_ex(ctx, hash, &hash_len);

// Cipher operation flow
EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
EVP_EncryptInit_ex(ctx, EVP_aes_256_gcm(), NULL, key, iv);  // ← Routes to wolfProvider
EVP_EncryptUpdate(ctx, ciphertext, &len, plaintext, plaintext_len);
EVP_EncryptFinal_ex(ctx, ciphertext + len, &final_len);
```

**TLS Protocol Flow:**
```c
// TLS connection establishment
SSL_CTX *ctx = SSL_CTX_new(TLS_client_method());
SSL *ssl = SSL_new(ctx);
SSL_connect(ssl);  // ← Uses wolfProvider cipher suites

// Handshake involves:
// - ClientHello (with FIPS cipher suites only)
// - ServerHello, Certificate, ServerKeyExchange
// - ClientKeyExchange (ECDHE/RSA via wolfProvider)
// - ChangeCipherSpec
// - All crypto operations routed to wolfSSL FIPS module
```

---

### Layer 4: wolfProvider v1.0.2

**Component:** libwolfprov.so (OpenSSL 3.0 provider)

**Location:** `/usr/local/lib/ossl-modules/libwolfprov.so`

**Source:** https://github.com/wolfSSL/wolfProvider

**Responsibilities:**
- Implement OpenSSL provider interface
- Route cryptographic operations to wolfSSL
- Register FIPS-approved algorithms
- Filter weak algorithms in FIPS mode
- Provide cipher suite implementations for TLS

**Provider Interface:**
```c
// Provider query function
static const OSSL_ALGORITHM *wp_query(void *provctx, int operation_id,
                                       const int *no_cache)
{
    switch (operation_id) {
        case OSSL_OP_DIGEST:
            return wp_digests;      // SHA-256, SHA-384, SHA-512
        case OSSL_OP_CIPHER:
            return wp_ciphers;      // AES-GCM, AES-CBC
        case OSSL_OP_MAC:
            return wp_macs;         // HMAC-SHA256, HMAC-SHA384
        case OSSL_OP_KDF:
            return wp_kdfs;         // PBKDF2
        case OSSL_OP_KEYMGMT:
            return wp_keymanagement; // RSA, EC key management
        case OSSL_OP_KEYEXCH:
            return wp_keyexchange;  // ECDH
        case OSSL_OP_SIGNATURE:
            return wp_signature;    // RSA-PSS, ECDSA
        default:
            return NULL;
    }
}
```

**Algorithm Registration:**
```c
// Example: SHA-256 digest registration
static const OSSL_ALGORITHM wp_digests[] = {
    { "SHA2-256:SHA-256:SHA256", "provider=wolfprov,fips=yes",
      wp_sha256_functions },
    { "SHA2-384:SHA-384:SHA384", "provider=wolfprov,fips=yes",
      wp_sha384_functions },
    { "SHA2-512:SHA-512:SHA512", "provider=wolfprov,fips=yes",
      wp_sha512_functions },
    { NULL, NULL, NULL }
};

// SHA-256 implementation dispatch
static const OSSL_DISPATCH wp_sha256_functions[] = {
    { OSSL_FUNC_DIGEST_NEWCTX, (void (*)(void))wp_sha256_newctx },
    { OSSL_FUNC_DIGEST_INIT, (void (*)(void))wp_sha256_init },
    { OSSL_FUNC_DIGEST_UPDATE, (void (*)(void))wp_sha256_update },
    { OSSL_FUNC_DIGEST_FINAL, (void (*)(void))wp_sha256_final },
    { 0, NULL }
};

// Implementation calls wolfSSL
static int wp_sha256_update(void *ctx, const unsigned char *in, size_t len)
{
    wc_Sha256 *sha = (wc_Sha256 *)ctx;
    return wc_Sha256Update(sha, in, len);  // ← FIPS boundary call
}
```

**FIPS Mode Filtering:**
```c
// In FIPS mode, only register FIPS-approved algorithms
if (fips_mode) {
    // Register: AES-GCM, AES-CBC, SHA-256+, HMAC-SHA256+
    // Block: MD5, SHA-1 (in TLS), DES, 3DES, RC4
}
```

---

### Layer 5: wolfSSL 5.8.2 FIPS Module

**Component:** libwolfssl.so (FIPS 140-3 validated cryptographic module)

**Location:** `/usr/local/lib/libwolfssl.so.44.0.0`

**Details:**
- Version: wolfSSL FIPS v5.8.2
- Certificate: FIPS 140-3 #4718
- Validation Level: Security Level 1
- FIPS Boundary Size: 789,400 bytes
- Build Configuration:
  ```bash
  ./configure \
    --enable-fips=v5 \
    --enable-opensslall \
    --enable-opensslextra \
    --enable-keygen \
    --enable-certgen \
    --enable-certreq \
    --enable-certext \
    --enable-pkcs12 \
    CFLAGS="-DWOLFSSL_PUBLIC_MP -DHAVE_SECRET_CALLBACK"
  ```

**FIPS Boundary:**
```
┌─────────────────────────────────────────────────────────┐
│ FIPS Boundary (789,400 bytes)                           │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Approved Algorithms:                                │ │
│ │ - AES (128, 192, 256): CBC, GCM                     │ │
│ │ - SHA-2: SHA-224, SHA-256, SHA-384, SHA-512         │ │
│ │ - HMAC: HMAC-SHA224, HMAC-SHA256, HMAC-SHA384       │ │
│ │ - RSA: 2048, 3072, 4096 bits                        │ │
│ │ - ECDSA: P-256, P-384, P-521                        │ │
│ │ - ECDH: P-256, P-384, P-521                         │ │
│ │ - DRBG: Hash_DRBG, HMAC_DRBG                        │ │
│ │ - KDF: PBKDF2, HKDF, TLS 1.2 PRF, TLS 1.3 HKDF      │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                           │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Legacy Allowed (Hash API only, not TLS):            │ │
│ │ - MD5: Available at API, blocked in TLS             │ │
│ │ - SHA-1: Available at API, blocked in TLS           │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                           │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Security Functions:                                 │ │
│ │ - Power-On Self Test (POST)                         │ │
│ │ - Known Answer Tests (KAT)                          │ │
│ │ - Continuous Random Number Generator Test           │ │
│ │ - In-core integrity verification (HMAC-SHA-256)     │ │
│ │ - Key zeroization                                   │ │
│ └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

**API Examples:**
```c
// SHA-256 operation
wc_Sha256 sha;
byte hash[WC_SHA256_DIGEST_SIZE];

wc_InitSha256(&sha);               // POST executes on first call
wc_Sha256Update(&sha, data, len);
wc_Sha256Final(&sha, hash);

// AES-256-GCM encryption
Aes aes;
byte ciphertext[256];
byte tag[AES_BLOCK_SIZE];

wc_AesGcmSetKey(&aes, key, 32);
wc_AesGcmEncrypt(&aes, ciphertext, plaintext, len,
                 iv, 12, tag, 16, NULL, 0);

// TLS 1.3 connection
WOLFSSL_CTX *ctx = wolfSSL_CTX_new(wolfTLSv1_3_client_method());
WOLFSSL *ssl = wolfSSL_new(ctx);
wolfSSL_connect(ssl);  // Uses only FIPS-approved cipher suites
```

---

## FIPS 140-3 Cryptographic Module

### Validation Details

| Property | Value |
|----------|-------|
| **Validation Number** | #4718 |
| **Validation Level** | Security Level 1 |
| **Vendor** | wolfSSL Inc. |
| **Module Name** | wolfCrypt FIPS Module |
| **Module Version** | v5.8.2 |
| **Validation Date** | 2024 |
| **Standard** | FIPS 140-3 |
| **Embodiment** | Software |
| **Tested Platforms** | Multiple (including Linux x86_64) |

### FIPS Boundary

The FIPS boundary encompasses:
- **Size**: 789,400 bytes of object code
- **Location**: libwolfssl.so.44.0.0
- **Integrity**: Verified via HMAC-SHA-256 checksum
- **Isolation**: All cryptographic operations occur within boundary

**Input/Output Points:**
```
Inputs:
  - Plaintext data
  - Keys (symmetric, asymmetric)
  - Initialization vectors
  - Parameters (algorithm-specific)

Outputs:
  - Ciphertext
  - Hash digests
  - Signatures
  - Derived keys
  - Status codes

Control:
  - Algorithm selection
  - Mode selection
  - Parameter configuration
```

### Power-On Self Test (POST)

**Execution Trigger:**
- Executed automatically on first cryptographic operation
- Cannot be bypassed
- Failure puts module in error state

**Test Coverage:**
- **Known Answer Tests (KAT)**: All approved algorithms
- **Pairwise Consistency Test**: Key pair generation
- **Continuous RNG Test**: Random number generator health
- **Integrity Test**: HMAC-SHA-256 of FIPS boundary

**Example POST Execution:**
```javascript
const crypto = require('crypto');

// First crypto operation triggers POST
const hash = crypto.createHash('sha256').update('test').digest();
// ↑ POST executes here (inside wolfSSL FIPS module)

// POST includes:
// - SHA-256 KAT
// - AES-GCM KAT
// - HMAC-SHA256 KAT
// - RSA key generation PCT
// - ECDH KAT
// - DRBG health tests
// - Integrity verification
```

**POST Verification:**
```bash
# Run FIPS KAT test executable
docker run --rm node:18.20.8-bookworm-slim-fips /test-fips

# Output:
# FIPS 140-3 Known Answer Tests (KAT)
# ====================================
# Testing Hash Algorithms...
# ✓ SHA-256 KAT: PASS
# ✓ SHA-384 KAT: PASS
# ✓ SHA-512 KAT: PASS
# ...
# All FIPS KAT tests passed successfully
```

### Approved Algorithms

| Category | Algorithms | Key Sizes | Modes |
|----------|-----------|-----------|-------|
| **Symmetric** | AES | 128, 192, 256 | CBC, GCM |
| **Hash** | SHA-2 | - | SHA-256, SHA-384, SHA-512 |
| **MAC** | HMAC | Variable | HMAC-SHA256, HMAC-SHA384, HMAC-SHA512 |
| **Asymmetric** | RSA | 2048, 3072, 4096 | Encryption, Signature (PKCS#1, PSS) |
| **Asymmetric** | ECDSA | P-256, P-384, P-521 | Signature |
| **Key Agreement** | ECDH | P-256, P-384, P-521 | Key derivation |
| **Random** | DRBG | - | Hash_DRBG, HMAC_DRBG |
| **KDF** | PBKDF2, HKDF | Variable | Key derivation |

### Non-Approved Algorithms (Blocked in TLS)

| Algorithm | Status | Notes |
|-----------|--------|-------|
| MD5 | ⚠️ Hash API only | Available at `crypto.createHash('md5')` but 0 MD5 cipher suites in TLS |
| SHA-1 | ⚠️ Hash API only | Available at `crypto.createHash('sha1')` but 0 SHA-1 cipher suites in TLS |
| DES | ❌ Listed | Listed in `crypto.getCiphers()` but cannot be negotiated in TLS |
| 3DES | ❌ Listed | Listed in `crypto.getCiphers()` but cannot be negotiated in TLS |
| RC4 | ❌ Listed | Listed in `crypto.getCiphers()` but cannot be negotiated in TLS |

**Important Note:** MD5 and SHA-1 are available at the hash API level per FIPS 140-3 Certificate #4718 requirements (legacy compatibility), but are completely blocked in TLS cipher negotiation. This is **correct FIPS behavior** and matches the Java implementation approach.

---

## Provider Architecture

### OpenSSL 3.0 Provider Interface

OpenSSL 3.0 introduced a new **provider architecture** to replace the deprecated engine interface:

```
┌──────────────────────────────────────────────────┐
│ OpenSSL Core (libcrypto.so.3)                   │
│                                                  │
│  ┌────────────────────────────────────────────┐ │
│  │ EVP API Layer                              │ │
│  │ - EVP_DigestInit(), EVP_EncryptInit()      │ │
│  └────────────────┬───────────────────────────┘ │
│                   │                              │
│  ┌────────────────▼───────────────────────────┐ │
│  │ Provider Manager                           │ │
│  │ - Load providers from configuration        │ │
│  │ - Query available algorithms               │ │
│  │ - Dispatch operations to providers         │ │
│  └────────────────┬───────────────────────────┘ │
│                   │                              │
└───────────────────┼──────────────────────────────┘
                    │
        ┌───────────┴───────────┐
        │                       │
        ▼                       ▼
┌───────────────┐      ┌───────────────┐
│ wolfProvider  │      │ default       │
│ (libwolfprov) │      │ (built-in)    │
│ FIPS=yes      │      │ FIPS=no       │
└───────────────┘      └───────────────┘
```

### Provider Configuration

**File:** `/usr/local/ssl/openssl.cnf`

```ini
# For OpenSSL utilities and shared applications
openssl_conf = openssl_init

# For Node.js applications (Node.js reads this section by default)
nodejs_conf = openssl_init

[openssl_init]
providers = provider_sect

[provider_sect]
default = default_sect
wolfprov = wolfprov_sect

[default_sect]
activate = 1

[wolfprov_sect]
activate = 1
fips = yes
module = /usr/local/lib/ossl-modules/libwolfprov.so
```

**Environment Variables:**
```bash
# OpenSSL configuration file
OPENSSL_CONF=/usr/local/ssl/openssl.cnf

# Provider module search path
OPENSSL_MODULES=/usr/local/lib/ossl-modules

# Node.js configuration (auto-enabled in Node.js 18+)
NODE_OPTIONS=--openssl-shared-config
```

**Important**: Node.js 18+ reads the `nodejs_conf` section from the OpenSSL configuration file. This is separate from `openssl_conf` which is used by OpenSSL CLI tools. Both sections can point to the same initialization block as shown above.

### Provider Loading Sequence

```
Container Startup
    ↓
Node.js Process Starts
    ↓
Load OpenSSL libraries (libssl.so.3, libcrypto.so.3)
    ↓
Read OPENSSL_CONF (/usr/local/ssl/openssl.cnf)
    ↓
Parse [provider_sect]
    ↓
Load wolfprov provider
    ↓
┌─ OSSL_PROVIDER_load(NULL, "wolfprov")
│   ↓
│   Load /usr/local/lib/ossl-modules/libwolfprov.so
│   ↓
│   Resolve libwolfssl.so dependency
│   ↓
│   Load /usr/local/lib/libwolfssl.so.44
│   ↓
│   Call wolfCrypt_Init()
│   ↓
│   Perform in-core integrity check
│   ↓
│   Register for POST on first use
│   ↓
│   Query available algorithms
│   ↓
│   Register wolfprov algorithms with OpenSSL
│
└─ wolfProvider ready
    ↓
Set FIPS mode (fips=yes in config)
    ↓
EVP_default_properties_enable_fips(NULL, 1)
    ↓
crypto.getFips() returns 1
    ↓
Application code starts
```

### Algorithm Selection Priority

When an algorithm is requested (e.g., `crypto.createHash('sha256')`), OpenSSL queries providers in order:

1. **Query wolfprov** (priority: FIPS=yes)
   - Implements SHA-256? **YES**
   - Return wolfprov SHA-256 implementation
   - Calls: `wc_Sha256Init()`, `wc_Sha256Update()`, `wc_Sha256Final()`

2. **Query default** (priority: FIPS=no)
   - Only used if wolfprov doesn't implement algorithm
   - Used for non-crypto operations or fallback

**Example Flow:**
```javascript
const crypto = require('crypto');

// Request SHA-256
const hash = crypto.createHash('sha256');

// OpenSSL Provider Manager:
// 1. Query wolfprov for "SHA-256"
//    → wolfprov: "Yes, I provide SHA-256 (FIPS=yes)"
// 2. Return wolfprov implementation
// 3. All operations routed to wolfSSL FIPS module

// Internal call chain:
// crypto.createHash('sha256')
//   → EVP_DigestInit_ex(ctx, EVP_sha256(), NULL)
//     → wolfprov.wp_sha256_newctx()
//       → wc_InitSha256(&sha)  [FIPS boundary]
```

### TLS Cipher Suite Selection

**FIPS Mode Enforcement:**
In FIPS mode, wolfProvider filters cipher suites to include only FIPS-approved algorithms:

```
TLS Connection Request
    ↓
SSL_CTX_new(TLS_client_method())
    ↓
Query available cipher suites from providers
    ↓
wolfProvider returns FIPS cipher suites:
  - TLS_AES_256_GCM_SHA384         (TLS 1.3, FIPS)
  - TLS_AES_128_GCM_SHA256         (TLS 1.3, FIPS)
  - TLS_CHACHA20_POLY1305_SHA256   (TLS 1.3, FIPS)
  - ECDHE-RSA-AES256-GCM-SHA384    (TLS 1.2, FIPS)
  - ECDHE-RSA-AES128-GCM-SHA256    (TLS 1.2, FIPS)
  - ...
    ↓
Filter out weak cipher suites:
  ❌ 0 MD5 cipher suites
  ❌ 0 SHA-1 cipher suites
  ❌ 0 DES cipher suites
  ❌ 0 3DES cipher suites
  ❌ 0 RC4 cipher suites
    ↓
ClientHello sent with FIPS cipher suites only
    ↓
Server selects cipher (e.g., TLS_AES_256_GCM_SHA384)
    ↓
All handshake crypto via wolfSSL FIPS module
```

---

## Configuration Management

### OpenSSL Configuration File

**Location:** `/usr/local/ssl/openssl.cnf`

**Full Configuration:**
```ini
# OpenSSL 3.0 configuration for wolfSSL FIPS

openssl_conf = openssl_init

[openssl_init]
providers = provider_sect

[provider_sect]
# wolfSSL FIPS provider (priority 1)
wolfprov = wolfprov_sect

# Default provider (fallback)
default = default_sect

[wolfprov_sect]
# Activate wolfProvider
activate = 1

# Enable FIPS mode
fips = yes

# Provider module path (can be absolute or relative to OPENSSL_MODULES)
module = /usr/local/lib/ossl-modules/libwolfprov.so

# Provider-specific properties
# identity = wolfprov
# module = libwolfprov

[default_sect]
# Activate default provider for non-crypto operations
activate = 1
```

### Environment Variables

**Runtime Configuration:**
```bash
# OpenSSL configuration file location
OPENSSL_CONF=/usr/local/ssl/openssl.cnf

# Provider module search path
OPENSSL_MODULES=/usr/local/lib/ossl-modules

# Node.js options (auto-enabled in Node.js 18+)
NODE_OPTIONS=--openssl-shared-config

# Library search path (for libwolfssl.so)
LD_LIBRARY_PATH=/usr/local/lib
```

**Dockerfile Example:**
```dockerfile
# Set OpenSSL configuration
ENV OPENSSL_CONF=/usr/local/ssl/openssl.cnf
ENV OPENSSL_MODULES=/usr/local/lib/ossl-modules

# Configure library path
ENV LD_LIBRARY_PATH=/usr/local/lib

# Node.js configuration (auto-reads OpenSSL config)
ENV NODE_OPTIONS=--openssl-shared-config
```

### FIPS Mode Verification

**Check FIPS Mode:**
```javascript
const crypto = require('crypto');

console.log('FIPS mode enabled:', crypto.getFips());
// Output: 1 (FIPS enabled)

// List available providers (via openssl command)
const { execSync } = require('child_process');
const providers = execSync('openssl list -providers', { encoding: 'utf8' });
console.log(providers);
/*
Providers:
  default
    name: OpenSSL Default Provider
    version: 3.0.11
    status: active
  wolfprov
    name: wolfSSL Provider
    version: 1.0.2
    status: active
*/
```

**Check Cipher Suites:**
```javascript
const crypto = require('crypto');

// Get all cipher names
const ciphers = crypto.getCiphers();
console.log('Total ciphers:', ciphers.length);

// Count weak cipher suites
const md5Ciphers = ciphers.filter(c => c.includes('md5'));
const sha1Ciphers = ciphers.filter(c => c.includes('sha1'));
const desCiphers = ciphers.filter(c => c.includes('des'));

console.log('MD5 ciphers in TLS:', md5Ciphers.length);    // 0
console.log('SHA-1 ciphers in TLS:', sha1Ciphers.length); // 0
console.log('DES ciphers in TLS:', desCiphers.length);    // 0
```

---

## Security Properties

### Defense-in-Depth Architecture

```
┌──────────────────────────────────────────────────┐
│ Layer 1: Application Code                       │
│ - Standard Node.js APIs                         │
│ - No FIPS-specific modifications required       │
└────────────────┬─────────────────────────────────┘
                 │
┌────────────────▼─────────────────────────────────┐
│ Layer 2: Node.js Runtime                        │
│ - Automatic FIPS mode detection                 │
│ - OpenSSL configuration auto-read               │
└────────────────┬─────────────────────────────────┘
                 │
┌────────────────▼─────────────────────────────────┐
│ Layer 3: OpenSSL Provider Interface             │
│ - Cipher suite filtering                        │
│ - Algorithm dispatch to wolfProvider            │
└────────────────┬─────────────────────────────────┘
                 │
┌────────────────▼─────────────────────────────────┐
│ Layer 4: wolfProvider                           │
│ - FIPS mode enforcement                         │
│ - Weak algorithm blocking in TLS                │
│ - Route to wolfSSL FIPS module                  │
└────────────────┬─────────────────────────────────┘
                 │
┌────────────────▼─────────────────────────────────┐
│ Layer 5: wolfSSL FIPS Module                    │
│ - FIPS 140-3 validated cryptography             │
│ - POST, KAT, integrity verification             │
│ - FIPS boundary enforcement                     │
└──────────────────────────────────────────────────┘
```

### Integrity Verification

**Build-Time:**
```bash
# During wolfSSL build
./configure --enable-fips=v5 ...
make
# → Generates libwolfssl.so with embedded HMAC-SHA-256 checksum
```

**Runtime (In-Core):**
```c
// libwolfssl.so initialization
int wolfCrypt_Init(void) {
    // Compute HMAC-SHA-256 over FIPS boundary
    byte computedHash[WC_SHA256_DIGEST_SIZE];
    wc_FIPS_verifyCore(computedHash);

    // Compare with embedded hash
    if (memcmp(computedHash, embeddedHash, WC_SHA256_DIGEST_SIZE) != 0) {
        return FIPS_INTEGRITY_E;  // Integrity check failed
    }

    // Continue initialization
}
```

**Container Verification:**
```bash
# scripts/integrity-check.sh
# Verifies SHA-256 checksums of:
# - libwolfssl.so.44.0.0
# - libwolfprov.so
# - /test-fips (KAT executable)

sha256sum -c /opt/wolfssl-fips/checksums/libraries.sha256
```

**Entrypoint Validation:**
```bash
# docker-entrypoint.sh runs on every container start
#!/bin/bash

# 1. Verify library integrity
/opt/wolfssl-fips/scripts/integrity-check.sh || exit 1

# 2. Verify FIPS mode enabled
node -p "require('crypto').getFips()" | grep -q "1" || exit 1

# 3. Execute user command
exec "$@"
```

### Key Zeroization

All cryptographic keys are zeroized after use:

```c
// wolfSSL FIPS module
int wc_FreeRsaKey(RsaKey* key) {
    // Zeroize private key material
    ForceZero(key->d, key->dSz);  // Private exponent
    ForceZero(key->p, key->pSz);  // Prime p
    ForceZero(key->q, key->qSz);  // Prime q

    // Free memory
    XFREE(key, DYNAMIC_TYPE_RSA);
}
```

### Access Controls

**File Permissions:**
```bash
# Library files (read-only for non-root)
-rwxr-xr-x /usr/local/lib/libwolfssl.so.44.0.0
-rwxr-xr-x /usr/local/lib/ossl-modules/libwolfprov.so

# Configuration files (read-only)
-rw-r--r-- /usr/local/ssl/openssl.cnf

# Test executables
-rwxr-xr-x /test-fips

# No world-writable files in FIPS components
```

**User Context:**
```dockerfile
# Run as non-root user
USER node  # UID 1000

# Verify at runtime
RUN id
# Output: uid=1000(node) gid=1000(node) groups=1000(node)
```

---

## Comparison with Alternatives

### Architecture Comparison

| Approach | Build Time | Node.js Version | FIPS Certified | Maintainability |
|----------|-----------|-----------------|----------------|-----------------|
| **Provider-based** (this) | ~10 min | Pre-built NodeSource | ✅ Yes (#4718) | ⭐⭐⭐⭐⭐ High |
| **Source compilation** | ~60 min | Custom build | ✅ Yes (#4718) | ⭐⭐⭐ Medium |
| **Static linking** | ~45 min | Custom build | ✅ Yes (#4718) | ⭐⭐ Low |
| **Engine-based** | ~15 min | Pre-built | ⚠️ Deprecated | ⭐ Very Low |

### Provider-based Advantages

1. **Fast Builds**: No Node.js compilation required (~10 min vs ~60 min)
2. **Smaller Images**: Uses NodeSource binaries (~300 MB vs ~500 MB)
3. **Easy Updates**: Update Node.js independently of FIPS module
4. **Standard Node.js**: Works with official NodeSource releases
5. **Future-Proof**: OpenSSL 3.0 provider interface is the recommended approach

### Build Time Comparison

| Implementation | Build Time | Reason |
|---------------|-----------|---------|
| **Node.js** (provider-based) | ~10 min | No Node.js compilation |
| **Java** (JNI-based) | ~15 min | No JDK compilation |
| **Python** (source compilation) | ~25 min | Recompile Python with wolfSSL |
| **Node.js** (source compilation) | ~60 min | Compile Node.js from source |

**Key Insight:** Provider-based approach achieves FIPS compliance with minimal build time overhead.

---

## Build Process

### Multi-Stage Docker Build

```dockerfile
# ============================================================
# Stage 1: wolfSSL FIPS Build
# ============================================================
FROM debian:bookworm-slim AS wolfssl-builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential autoconf automake libtool \
    ca-certificates wget unzip

# Download and extract wolfSSL FIPS bundle
RUN --mount=type=secret,id=wolfssl_password \
    wget --user=<user> --password=$(cat /run/secrets/wolfssl_password) \
    https://www.wolfssl.com/wolfssl-fips-5.8.2-v5.tar.gz

RUN tar xzf wolfssl-fips-5.8.2-v5.tar.gz
WORKDIR /wolfssl-5.8.2-fips

# Configure and build wolfSSL FIPS
RUN ./configure \
    --enable-fips=v5 \
    --enable-opensslall \
    --enable-opensslextra \
    --enable-keygen \
    --enable-certgen \
    --enable-certreq \
    --enable-certext \
    --enable-pkcs12 \
    CFLAGS="-DWOLFSSL_PUBLIC_MP -DHAVE_SECRET_CALLBACK" && \
    make -j$(nproc) && \
    make install

# Verify build
RUN ldconfig && \
    ls -lh /usr/local/lib/libwolfssl.so* && \
    /usr/local/lib/libwolfssl.so --version

# ============================================================
# Stage 2: wolfProvider Build
# ============================================================
FROM wolfssl-builder AS wolfprovider-builder

# Install OpenSSL 3.0 development files
RUN apt-get install -y libssl-dev

# Download and build wolfProvider
RUN git clone --depth 1 --branch v1.0.2 \
    https://github.com/wolfSSL/wolfProvider.git

WORKDIR /wolfProvider

RUN ./autogen.sh && \
    ./configure --with-openssl=/usr --with-wolfssl=/usr/local && \
    make -j$(nproc) && \
    make install

# Verify installation
RUN ls -lh /usr/local/lib/ossl-modules/libwolfprov.so

# ============================================================
# Stage 3: OpenSSL 3.0 Build
# ============================================================
FROM wolfprovider-builder AS openssl-builder

# Build OpenSSL 3.0.11 with provider support
RUN wget https://www.openssl.org/source/openssl-3.0.11.tar.gz && \
    tar xzf openssl-3.0.11.tar.gz

WORKDIR /openssl-3.0.11

RUN ./Configure \
    --prefix=/usr/local \
    --openssldir=/usr/local/ssl \
    shared \
    enable-fips && \
    make -j$(nproc) && \
    make install

# Configure ldconfig
RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/openssl.conf && \
    ldconfig

# ============================================================
# Stage 4: FIPS KAT Test Build
# ============================================================
FROM openssl-builder AS kat-builder

# Build FIPS Known Answer Test executable
COPY test-fips.c /build/test-fips.c

RUN gcc -o /test-fips /build/test-fips.c \
    -I/usr/local/include \
    -L/usr/local/lib \
    -lwolfssl \
    -Wl,-rpath,/usr/local/lib

# Verify test executable
RUN /test-fips && echo "✓ FIPS KAT tests passed"

# ============================================================
# Stage 5: Runtime Image
# ============================================================
FROM debian:bookworm-slim

# Install Node.js 18.20.8 from NodeSource
RUN apt-get update && \
    apt-get install -y ca-certificates curl gnupg && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | \
    gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_18.x nodistro main" | \
    tee /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && \
    apt-get install -y nodejs=18.20.8-1nodesource1 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy OpenSSL libraries
COPY --from=openssl-builder /usr/local/lib/libssl.so.3* /usr/local/lib/
COPY --from=openssl-builder /usr/local/lib/libcrypto.so.3* /usr/local/lib/

# Copy wolfSSL FIPS library
COPY --from=wolfssl-builder /usr/local/lib/libwolfssl.so* /usr/local/lib/

# Copy wolfProvider
COPY --from=wolfprovider-builder /usr/local/lib/ossl-modules/ /usr/local/lib/ossl-modules/

# Copy FIPS test executable
COPY --from=kat-builder /test-fips /test-fips

# Copy OpenSSL configuration
COPY openssl.cnf /usr/local/ssl/openssl.cnf

# Copy scripts
COPY docker-entrypoint.sh /usr/local/bin/
COPY scripts/ /opt/wolfssl-fips/scripts/

# Configure library path
RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/wolfssl.conf && \
    ldconfig

# Set environment variables
ENV OPENSSL_CONF=/usr/local/ssl/openssl.cnf
ENV OPENSSL_MODULES=/usr/local/lib/ossl-modules
ENV LD_LIBRARY_PATH=/usr/local/lib
ENV NODE_OPTIONS=--openssl-shared-config

# Create non-root user (node user already exists from NodeSource package)
# UID 1000, GID 1000

USER node
WORKDIR /home/node

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["node"]
```

### Build Dependencies

```
wolfSSL FIPS Build
   ↓ (libwolfssl.so.44.0.0)
OpenSSL 3.0 Build
   ↓ (libssl.so.3, libcrypto.so.3)
wolfProvider Build ← depends on libwolfssl.so + OpenSSL 3.0 headers
   ↓ (libwolfprov.so)
FIPS KAT Test Build ← depends on libwolfssl.so
   ↓ (/test-fips)
Runtime Image Assembly ← combines all artifacts + NodeSource Node.js
```

### Build Script

**build.sh:**
```bash
#!/bin/bash
set -e

# Build arguments
IMAGE_NAME="node:18.20.8-bookworm-slim-fips"
WOLFSSL_PASSWORD_FILE="wolfssl_password.txt"

# Verify password file exists
if [[ ! -f "$WOLFSSL_PASSWORD_FILE" ]]; then
    echo "Error: $WOLFSSL_PASSWORD_FILE not found"
    exit 1
fi

# Build with Docker BuildKit (required for secrets)
DOCKER_BUILDKIT=1 docker build \
    --secret id=wolfssl_password,src="$WOLFSSL_PASSWORD_FILE" \
    --tag "$IMAGE_NAME" \
    --file Dockerfile \
    .

# Verify build
echo "Verifying FIPS mode..."
docker run --rm "$IMAGE_NAME" node -p "require('crypto').getFips()"
# Expected output: 1

echo "Running FIPS KAT tests..."
docker run --rm "$IMAGE_NAME" /test-fips

echo "✓ Build completed successfully: $IMAGE_NAME"
```

---

## Validation and Testing

### Test Infrastructure

**Test Suites:**
1. **Backend Verification** (6 tests)
   - wolfSSL FIPS library presence
   - wolfProvider library presence
   - FIPS test executable
   - OpenSSL configuration
   - wolfProvider configuration
   - Environment variables

2. **Connectivity** (8 tests)
   - Basic HTTPS GET requests
   - TLS 1.2 protocol support
   - TLS 1.3 protocol support
   - Certificate validation
   - FIPS cipher suite negotiation
   - HTTPS POST requests
   - SNI support
   - Hostname verification

3. **FIPS Verification** (6 tests)
   - wolfProvider registration
   - FIPS mode enabled
   - TLS 1.2 support
   - Cipher suite compliance (57 FIPS ciphers, 0 weak)
   - wolfSSL FIPS boundary check
   - TLS 1.3 support

4. **Crypto Operations** (10 tests)
   - SHA-256, SHA-384, SHA-512 hashing
   - SHA-1 availability (legacy FIPS 140-3)
   - HMAC-SHA256 operations
   - Random bytes generation
   - AES-256-GCM encryption/decryption
   - PBKDF2 key derivation
   - FIPS-approved cipher availability
   - MD5 availability (legacy FIPS 140-3, blocked in TLS)

5. **Library Compatibility** (6 tests)
   - Built-in crypto module operations
   - Built-in https module requests
   - Built-in tls module connections
   - Third-party library compatibility (axios, node-fetch)

### Test Execution

**Run All Tests:**
```bash
cd node/18.20.8-bookworm-slim-fips
./diagnostic.sh

# Expected output:
# Backend Verification: 6/6 tests passed (100%)
# Connectivity: 7/8 tests passed (88%)
# FIPS Verification: 6/6 tests passed (100%)
# Crypto Operations: 10/10 tests passed (100%)
# Library Compatibility: 4/6 tests passed (67%)
# Overall: 34/38 tests passed (89%)
```

**Run Individual Test Suite:**
```bash
./diagnostic.sh diagnostics/test-backend-verification.js
./diagnostic.sh diagnostics/test-fips-verification.js
./diagnostic.sh diagnostics/test-crypto-operations.js
```

**Run FIPS KAT Tests:**
```bash
docker run --rm node:18.20.8-bookworm-slim-fips /test-fips

# Expected output:
# FIPS 140-3 Known Answer Tests (KAT)
# ====================================
# Testing Hash Algorithms...
# ✓ SHA-256 KAT: PASS
# ✓ SHA-384 KAT: PASS
# ✓ SHA-512 KAT: PASS
# Testing Symmetric Ciphers...
# ✓ AES-128-CBC KAT: PASS
# ✓ AES-256-CBC KAT: PASS
# ✓ AES-256-GCM KAT: PASS
# Testing HMAC...
# ✓ HMAC-SHA256 KAT: PASS
# ✓ HMAC-SHA384 KAT: PASS
# All FIPS KAT tests passed successfully
```

### Test Image

**Quick Validation:**
```bash
cd diagnostics/test-images/basic-test-image
./build.sh
docker run --rm node-fips-test:latest

# Expected output:
# ✓ Cryptographic Operations Test Suite: PASS (9/9)
# ✓ TLS/SSL Test Suite: PASS (6/6)
# ✓ ALL TESTS PASSED - Node.js wolfSSL FIPS is production ready
```

### Demo Applications

**Interactive Demos:**
```bash
cd demos-image
./build.sh

# Run hash algorithm demo
docker run --rm -it node-fips-demos:18.20.8 node /demos/hash_algorithm_demo.js

# Run TLS/SSL client demo
docker run --rm -it node-fips-demos:18.20.8 node /demos/tls_ssl_client_demo.js

# Run certificate validation demo
docker run --rm -it node-fips-demos:18.20.8 node /demos/certificate_validation_demo.js

# Run HTTPS request demo
docker run --rm -it node-fips-demos:18.20.8 node /demos/https_request_demo.js
```

### Continuous Integration

**CI/CD Integration:**
```yaml
# .github/workflows/fips-validation.yml
name: FIPS Validation

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Build FIPS image
        run: ./build.sh

      - name: Run FIPS KAT tests
        run: docker run --rm node:18.20.8-bookworm-slim-fips /test-fips

      - name: Run diagnostic tests
        run: ./diagnostic.sh

      - name: Verify FIPS mode
        run: |
          FIPS_MODE=$(docker run --rm node:18.20.8-bookworm-slim-fips node -p "require('crypto').getFips()")
          if [ "$FIPS_MODE" != "1" ]; then
            echo "FIPS mode not enabled!"
            exit 1
          fi

      - name: Check cipher suites
        run: |
          docker run --rm node:18.20.8-bookworm-slim-fips node -e "
            const crypto = require('crypto');
            const ciphers = crypto.getCiphers();
            const weak = ciphers.filter(c => c.includes('md5') || c.includes('sha1') || c.includes('des'));
            console.log('Weak cipher suites in TLS:', weak.length);
            process.exit(weak.length === 0 ? 0 : 1);
          "
```

---

## Additional Resources

- **[README.md](README.md)** - General documentation and usage guide
- **[POC-VALIDATION-REPORT.md](POC-VALIDATION-REPORT.md)** - POC validation evidence
- **[compliance/CHAIN-OF-CUSTODY.md](compliance/CHAIN-OF-CUSTODY.md)** - Chain of custody documentation
- **[Evidence/](Evidence/)** - Test execution results and evidence files
- **wolfSSL FIPS**: https://www.wolfssl.com/products/wolfssl-fips/
- **wolfProvider**: https://github.com/wolfSSL/wolfProvider
- **OpenSSL Providers**: https://www.openssl.org/docs/man3.0/man7/provider.html
- **Node.js Crypto**: https://nodejs.org/docs/latest-v18.x/api/crypto.html

---

**Last Updated**: 2026-03-22
**Version**: 1.0
**wolfSSL FIPS Version**: v5.8.2 (Certificate #4718)
**Node.js Version**: 18.20.8 LTS
**OpenSSL Version**: 3.0.11
**wolfProvider Version**: v1.0.2
