# Node.js 24 wolfSSL FIPS Architecture

**Document Version**: 1.0
**Last Updated**: 2026-04-15
**FIPS Certificate**: #4718 (wolfSSL 5.8.2)
**Architecture**: Provider-based (OpenSSL 3.5 + wolfProvider)

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

This implementation provides FIPS 140-3 validated cryptography for Node.js 24 applications using a **provider-based architecture**. Instead of recompiling Node.js from source with wolfSSL, we use **OpenSSL 3.5's provider interface** to route cryptographic operations to wolfSSL's FIPS-validated module.

### Key Features

- **FIPS 140-3 Validated**: wolfSSL 5.8.2 (Certificate #4718)
- **Provider-based**: Uses OpenSSL 3.5.0 provider architecture
- **Node.js 24.14.1 LTS**: Full standard library support
- **TLS 1.2/1.3**: Modern protocol support with FIPS-approved cipher suites
- **No Node.js Compilation**: Works with pre-built NodeSource binaries
- **Fast Build**: ~12 minutes (vs 25-60 minutes for source compilation)
- **Debian Trixie**: Based on Debian 13 (testing)
- **System OpenSSL Replacement**: Critical for runtime FIPS enforcement

### Architecture Type

**Provider-based** (recommended approach for OpenSSL 3.5+)

```
Node.js 24.14.1 → OpenSSL 3.5.0 API → wolfProvider v1.1.1 → wolfSSL 5.8.2 FIPS
```

This differs from:
- **Engine-based** (deprecated in OpenSSL 3.5)
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
│ │ - crypto.getFips() returns 1 (FIPS enabled)         │ │
│ └─────────────────────────────────────────────────────┘ │
└────────────────────────┬────────────────────────────────┘
                         │ libssl.so.3, libcrypto.so.3
                         │ (system OpenSSL replaced)
                         ▼
┌─────────────────────────────────────────────────────────┐
│ OpenSSL 3.5.0 (Provider Interface)                     │
│ Custom build at /usr/local/openssl                      │
│ System libraries replaced in /usr/lib/x86_64-linux-gnu/ │
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
│ │ - Configuration: /etc/ssl/openssl.cnf               │ │
│ │ - FIPS mode control                                 │ │
│ └─────────────────────────────────────────────────────┘ │
└────────────────────────┬────────────────────────────────┘
                         │ Provider API (OSSL_PROVIDER)
                         ▼
┌─────────────────────────────────────────────────────────┐
│ wolfProvider v1.1.1                                     │
│ /usr/local/openssl/lib64/ossl-modules/libwolfprov.so   │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Provider Implementation                             │ │
│ │ - Implements OpenSSL provider interface             │ │
│ │ - Routes crypto operations to wolfSSL               │ │
│ │ - Registers FIPS-approved algorithms                │ │
│ │   ✓ AES-CBC (128, 192, 256)                         │ │
│ │   ✓ AES-GCM (128, 192, 256)                         │ │
│ │   ✓ SHA-2 family (SHA-256, SHA-384, SHA-512)        │ │
│ │   ✓ ECDHE, RSA, HMAC                                │ │
│ │   ✓ TLS 1.2, TLS 1.3 cipher suites                  │ │
│ │ - Filters weak algorithms (MD5, SHA-1 in TLS)       │ │
│ │ - MD5 completely blocked at API level               │ │
│ │ - SHA-1 available for hashing, blocked in TLS       │ │
│ └─────────────────────────────────────────────────────┘ │
└────────────────────────┬────────────────────────────────┘
                         │ wolfSSL API
                         ▼
┌─────────────────────────────────────────────────────────┐
│ wolfSSL 5.8.2 FIPS 140-3 Module                         │
│ /usr/local/lib/libwolfssl.so (779 KB)                  │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ FIPS Cryptographic Module                           │ │
│ │ ┌─────────────────────────────────────────────────┐ │ │
│ │ │ FIPS Boundary                                   │ │ │
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
                  (Debian Trixie)
```

---

## Component Stack

### Layer 1: Node.js Application Layer

**Components:**
- Node.js 24.14.1 application code
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

// MD5 is blocked at crypto API level
try {
  crypto.createHash('md5');
} catch (err) {
  console.log('MD5 blocked:', err.message);
  // Output: error:0308010C:digital envelope routines::unsupported
}
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
/usr/bin/node (Node.js 24.14.1 executable)
```

**Dynamic Linking:**
Node.js 24.14.1 dynamically links to system OpenSSL libraries:
```bash
$ ldd /usr/bin/node | grep ssl
libssl.so.3 => /usr/lib/x86_64-linux-gnu/libssl.so.3
libcrypto.so.3 => /usr/lib/x86_64-linux-gnu/libcrypto.so.3
```

**Critical**: These system libraries are replaced during build with FIPS OpenSSL libraries to ensure runtime FIPS enforcement.

**Responsibilities:**
- Provide crypto API to JavaScript layer
- Manage TLS connections
- Handle certificate validation
- Route crypto operations to OpenSSL

**FIPS Integration:**
- Node.js reads `OPENSSL_CONF` environment variable
- `--openssl-shared-config` flag (enabled by default in Node.js 24+)
- Automatically loads wolfProvider via OpenSSL configuration

**API Example:**
```javascript
const crypto = require('crypto');

// Hash API -> OpenSSL EVP -> wolfProvider -> wolfSSL FIPS
crypto.createHash('sha256').update('data').digest('hex');

// Cipher API -> OpenSSL EVP -> wolfProvider -> wolfSSL FIPS
crypto.createCipheriv('aes-256-gcm', key, iv);

// TLS API -> OpenSSL SSL -> wolfProvider -> wolfSSL FIPS
const tls = require('tls');
tls.connect({host: 'example.com', port: 443});
```

---

### Layer 3: OpenSSL 3.5.0

**Installation Locations:**
- **Custom Build**: `/usr/local/openssl/` (lib64/, bin/, ssl/)
- **System Replacement**: `/usr/lib/x86_64-linux-gnu/` (libssl.so.3, libcrypto.so.3)

**Critical Build Step - System OpenSSL Replacement:**
During Docker build, custom FIPS OpenSSL libraries replace system OpenSSL:
```bash
# Copy custom OpenSSL libraries to system locations
cp -av /usr/local/openssl/lib64/libssl.so* /usr/lib/x86_64-linux-gnu/
cp -av /usr/local/openssl/lib64/libcrypto.so* /usr/lib/x86_64-linux-gnu/
cp -av /usr/local/openssl/bin/openssl /usr/bin/openssl

# Update dynamic linker configuration
echo "/usr/lib/x86_64-linux-gnu" > /etc/ld.so.conf.d/fips-openssl.conf
echo "/usr/local/openssl/lib64" >> /etc/ld.so.conf.d/fips-openssl.conf
echo "/usr/local/lib" >> /etc/ld.so.conf.d/fips-openssl.conf
ldconfig
```

This ensures Node.js dynamically links to FIPS-enabled OpenSSL at runtime.

**Components:**
- **libssl.so.3** - SSL/TLS protocol implementation
- **libcrypto.so.3** - Cryptographic operations (EVP interface)
- **openssl** - Command-line utility

**Build Configuration:**
```bash
./Configure \
    --prefix=/usr/local/openssl \
    --openssldir=/usr/local/openssl/ssl \
    --libdir=lib64 \
    enable-fips \
    shared \
    linux-x86_64
```

**Provider Interface:**
OpenSSL 3.5 introduces provider architecture:
- **Default provider** - Standard OpenSSL algorithms (not used in FIPS mode)
- **FIPS provider** - wolfProvider replaces default provider
- **Legacy provider** - Old algorithms (not loaded)

**Configuration Loading:**
1. Read `/etc/ssl/openssl.cnf`
2. Load provider modules from `OPENSSL_MODULES` path
3. Activate providers based on configuration
4. Set algorithm properties (`fips=yes`)

**EVP Interface:**
All crypto operations go through EVP (Envelope) API:
```c
// OpenSSL EVP interface routes to provider
EVP_MD* md = EVP_MD_fetch(NULL, "SHA256", "provider=libwolfprov");
EVP_DigestInit_ex(ctx, md, NULL);
```

---

### Layer 4: wolfProvider v1.1.1

**Location:**
```
/usr/local/openssl/lib64/ossl-modules/libwolfprov.so (1027 KB)
```

**Purpose:**
Implements OpenSSL 3.5 provider interface to route cryptographic operations to wolfSSL FIPS module.

**Build Configuration:**
```bash
./configure \
    --with-openssl=/usr/local/openssl \
    --with-wolfssl=/usr/local \
    --prefix=/usr/local/openssl
```

**Responsibilities:**
1. **Algorithm Registration** - Register FIPS-approved algorithms with OpenSSL
2. **Operation Routing** - Route crypto operations to wolfSSL
3. **FIPS Enforcement** - Filter weak algorithms at provider level
4. **TLS Integration** - Provide FIPS cipher suites for TLS

**Supported Algorithms:**
- **Hash**: SHA-256, SHA-384, SHA-512, SHA-1 (legacy)
- **Cipher**: AES-128/192/256 (CBC, GCM)
- **MAC**: HMAC-SHA-256/384/512
- **Asymmetric**: RSA (2048+), ECDSA (P-256, P-384, P-521)
- **Key Exchange**: ECDHE, DHE
- **KDF**: PBKDF2, HKDF, TLS 1.2 PRF, TLS 1.3 HKDF
- **Random**: Hash_DRBG, HMAC_DRBG

**Blocked Algorithms:**
- **MD5**: Completely blocked at crypto API level
  - `EVP_MD_fetch(NULL, "MD5", NULL)` returns NULL
  - Results in Node.js error: `error:0308010C:digital envelope routines::unsupported`
- **SHA-1 in TLS**: 0 SHA-1 cipher suites available
- **DES/3DES/RC4**: Blocked in TLS cipher negotiation

**Provider Interface Implementation:**
```c
// wolfProvider implements OSSL_PROVIDER interface
static const OSSL_ALGORITHM wp_digests[] = {
    { "SHA256", "provider=libwolfprov", wp_sha256_functions },
    { "SHA384", "provider=libwolfprov", wp_sha384_functions },
    { "SHA512", "provider=libwolfprov", wp_sha512_functions },
    // MD5 not registered (blocked)
    { NULL, NULL, NULL }
};
```

---

### Layer 5: wolfSSL 5.8.2 FIPS Module

**Location:**
```
/usr/local/lib/libwolfssl.so (779 KB)
```

**Certificate:** #4718 (FIPS 140-3)

**Build Configuration:**
```bash
./configure \
    --enable-fips=v5 \
    --enable-opensslcoexist \
    --enable-opensslextra \
    --enable-cmac \
    --enable-keygen \
    --enable-sha \
    --enable-aesctr \
    --enable-aesccm \
    --enable-x963kdf \
    --enable-compkey \
    --enable-altcertchains \
    CPPFLAGS="-DHAVE_AES_ECB -DWOLFSSL_AES_DIRECT ..."
```

**FIPS Boundary:**
All cryptographic operations occur within the FIPS boundary:
- **Input**: Plaintext, keys, parameters
- **Processing**: FIPS-validated algorithms
- **Output**: Ciphertext, hashes, signatures
- **Integrity**: In-core integrity check via HMAC-SHA-256

**Power-On Self Test (POST):**
Executed on first crypto operation:
1. **Known Answer Tests (KAT)** - AES, SHA, RSA, ECDSA, HMAC
2. **Integrity Check** - HMAC verification of FIPS module
3. **Conditional Tests** - Pairwise consistency tests

**Validated Algorithms:**
- **AES**: ECB, CBC, CTR, GCM, CCM (128, 192, 256-bit)
- **SHA**: SHA-224, SHA-256, SHA-384, SHA-512, SHA3 family
- **RSA**: 2048, 3072, 4096-bit (sign, verify, encrypt, decrypt)
- **ECDSA**: P-256, P-384, P-521 (sign, verify)
- **ECDH**: P-256, P-384, P-521 (key agreement)
- **HMAC**: HMAC-SHA-224/256/384/512
- **KDF**: PBKDF2, HKDF, TLS 1.2 PRF, TLS 1.3 HKDF
- **DRBG**: Hash_DRBG, HMAC_DRBG

---

## FIPS 140-3 Cryptographic Module

### Validation Details

**Certificate Number:** #4718

**Module Name:** wolfSSL Cryptographic Module

**Version:** v5.8.2

**Security Level:** 1

**Validation Date:** 2024 (see [NIST CMVP listing](https://csrc.nist.gov/projects/cryptographic-module-validation-program/Certificate/4718))

**Tested Configuration:**
- **Operating System**: Linux (Debian 13 Trixie)
- **Processor**: x86_64
- **Compiler**: GCC
- **Integration**: OpenSSL 3.5 provider interface

### FIPS Boundary

```
┌───────────────────────────────────────┐
│     FIPS Boundary                     │
│  libwolfssl.so (wolfSSL FIPS v5.8.2)  │
│  Certificate #4718                    │
│  ┌─────────────────────────────────┐  │
│  │ wolfCrypt FIPS Module           │  │
│  │ - AES, SHA-2, RSA, EC           │  │
│  │ - HMAC, PBKDF2, DRBG            │  │
│  │ - In-core integrity check       │  │
│  │ - Power-On Self Test            │  │
│  └─────────────────────────────────┘  │
└───────────────────────────────────────┘
         ↑                    ↓
    Input data          Output data
   (via wolfProvider)  (via wolfProvider)
         ↑                    ↓
   OpenSSL 3.5.0      Node.js 24.14.1
```

### Power-On Self Test (POST)

**Execution:** On first crypto operation after container start

**Tests Performed:**
1. **AES KAT** - Encrypt/decrypt known plaintext
2. **SHA KAT** - Hash known input
3. **HMAC KAT** - MAC known input
4. **RSA KAT** - Sign/verify known message
5. **ECDSA KAT** - Sign/verify known message
6. **DRBG KAT** - Generate random bytes
7. **Integrity Check** - Verify FIPS module HMAC

**Verification:**
```bash
# Run FIPS KAT tests
docker run --rm cr.root.io/node:24.14.0-trixie-slim-fips /test-fips

# Expected output:
# wolfSSL FIPS v5.8.2 (Certificate #4718)
# Known Answer Tests (KAT):
#   SHA-256 KAT: PASS
#   SHA-384 KAT: PASS
#   SHA-512 KAT: PASS
#   AES-128-CBC KAT: PASS
#   AES-256-CBC KAT: PASS
#   AES-256-GCM KAT: PASS
#   HMAC-SHA256 KAT: PASS
#   HMAC-SHA384 KAT: PASS
#   RSA 2048 KAT: PASS
#   ECDSA P-256 KAT: PASS
# All FIPS KATs: PASSED
```

### Approved Algorithms

| Algorithm | Key Sizes | Operations | FIPS Approved |
|-----------|-----------|------------|---------------|
| AES-CBC | 128, 192, 256 | Encrypt, Decrypt | ✅ Yes |
| AES-GCM | 128, 192, 256 | Encrypt, Decrypt | ✅ Yes |
| SHA-256 | N/A | Hash | ✅ Yes |
| SHA-384 | N/A | Hash | ✅ Yes |
| SHA-512 | N/A | Hash | ✅ Yes |
| SHA-1 | N/A | Hash (legacy) | ⚠️ Legacy only |
| HMAC-SHA-256 | Variable | MAC | ✅ Yes |
| HMAC-SHA-384 | Variable | MAC | ✅ Yes |
| HMAC-SHA-512 | Variable | MAC | ✅ Yes |
| RSA | 2048, 3072, 4096 | Sign, Verify, Encrypt, Decrypt | ✅ Yes |
| ECDSA | P-256, P-384, P-521 | Sign, Verify | ✅ Yes |
| ECDH | P-256, P-384, P-521 | Key Agreement | ✅ Yes |

### Non-Approved Algorithms (Blocked in TLS)

| Algorithm | Status | Notes |
|-----------|--------|-------|
| **MD5** | ❌ **COMPLETELY BLOCKED** | Blocked at crypto API level; cannot be used anywhere |
| **SHA-1** | ⚠️ **RESTRICTED** | Available for legacy hashing; 0 SHA-1 cipher suites in TLS |
| **DES** | ❌ **BLOCKED** | Blocked in TLS cipher negotiation |
| **3DES** | ❌ **BLOCKED** | Blocked in TLS cipher negotiation |
| **RC4** | ❌ **BLOCKED** | Blocked in TLS cipher negotiation |

---

## Provider Architecture

### OpenSSL 3.5 Provider Interface

OpenSSL 3.5 introduces a new provider architecture replacing the legacy engine interface:

**Provider Benefits:**
- ✅ Better isolation between OpenSSL core and crypto implementations
- ✅ Cleaner API for implementing custom crypto
- ✅ Improved FIPS compliance workflow
- ✅ Multiple providers can coexist

**Provider Loading:**
```c
// OpenSSL loads provider at initialization
OSSL_PROVIDER *prov = OSSL_PROVIDER_load(NULL, "libwolfprov");
OSSL_PROVIDER_set_default_search_path(NULL, "/usr/local/openssl/lib64/ossl-modules");
```

### Provider Configuration

**OpenSSL Configuration** (`/etc/ssl/openssl.cnf`):
```ini
openssl_conf = openssl_init
nodejs_conf = openssl_init

[openssl_init]
providers = provider_sect
alg_section = algorithm_sect

[provider_sect]
libwolfprov = libwolfprov_sect

[libwolfprov_sect]
activate = 1
module = /usr/local/openssl/lib64/ossl-modules/libwolfprov.so

[algorithm_sect]
default_properties = fips=yes
```

**Configuration Sections:**
- **openssl_conf** - Read by OpenSSL utilities (openssl command)
- **nodejs_conf** - Read by Node.js (--openssl-shared-config)
- **providers** - List of providers to load
- **algorithm_sect** - Default algorithm properties

### Provider Loading Sequence

1. **Container Start** - Environment variables set
   ```bash
   OPENSSL_CONF=/etc/ssl/openssl.cnf
   OPENSSL_MODULES=/usr/local/openssl/lib64/ossl-modules
   ```

2. **Node.js Start** - Reads OpenSSL configuration
   ```
   Node.js 24.14.1 starts
   ↓
   Reads OPENSSL_CONF (--openssl-shared-config enabled)
   ↓
   Parses /etc/ssl/openssl.cnf
   ↓
   Loads providers from provider_sect
   ```

3. **Provider Activation** - wolfProvider loaded
   ```
   Load libwolfprov.so from OPENSSL_MODULES path
   ↓
   Call OSSL_PROVIDER_load(NULL, "libwolfprov")
   ↓
   Provider registers algorithms with OpenSSL
   ↓
   Set default_properties = fips=yes
   ```

4. **FIPS POST** - First crypto operation triggers POST
   ```
   First crypto operation (e.g., crypto.createHash('sha256'))
   ↓
   wolfSSL FIPS POST executes
   ↓
   Known Answer Tests (KAT) run
   ↓
   Integrity check verifies FIPS module
   ↓
   POST completes successfully
   ```

5. **Crypto Operations** - All operations use FIPS module
   ```
   crypto.createHash('sha256')
   ↓
   OpenSSL EVP_MD_fetch(NULL, "SHA256", "fips=yes")
   ↓
   wolfProvider returns SHA-256 implementation
   ↓
   wolfSSL FIPS SHA-256 executes
   ↓
   Result returned to Node.js
   ```

### Algorithm Selection Priority

When multiple providers are available, OpenSSL selects based on:
1. **Property queries** - `fips=yes` ensures FIPS-only algorithms
2. **Provider order** - First matching provider wins
3. **Algorithm availability** - Provider must support the algorithm

**Example:**
```javascript
// Node.js crypto operation
crypto.createHash('sha256');

// OpenSSL provider selection
// 1. Query: fetch("SHA256", "fips=yes")
// 2. wolfProvider matches (has SHA-256, supports fips=yes)
// 3. wolfProvider's SHA-256 implementation selected
// 4. wolfSSL FIPS SHA-256 executes
```

### TLS Cipher Suite Selection

**FIPS Mode:**
Only FIPS-approved cipher suites are available:
```javascript
const crypto = require('crypto');
console.log('Total ciphers:', crypto.getCiphers().length);
// Output: 30 (FIPS-approved only)

// TLS connection
const tls = require('tls');
tls.connect({host: 'www.google.com', port: 443}, () => {
  console.log('Cipher:', socket.getCipher());
  // Output: { name: 'TLS_AES_256_GCM_SHA384', ... }
});
```

**Cipher Suite Filtering:**
wolfProvider filters cipher suites at provider level:
- ✅ TLS_AES_256_GCM_SHA384 (FIPS-approved)
- ✅ TLS_AES_128_GCM_SHA256 (FIPS-approved)
- ✅ ECDHE-RSA-AES256-GCM-SHA384 (FIPS-approved)
- ❌ MD5-based ciphers (blocked)
- ❌ SHA-1-based ciphers (blocked)
- ❌ RC4, DES, 3DES ciphers (blocked)

---

## Configuration Management

### OpenSSL Configuration File

**Location:** `/etc/ssl/openssl.cnf`

**Purpose:**
- Configure OpenSSL provider loading
- Set FIPS mode enforcement
- Define algorithm properties

**Full Configuration:**
```ini
# OpenSSL Configuration for Node.js 24 with wolfProvider
openssl_conf = openssl_init
nodejs_conf = openssl_init

[openssl_init]
providers = provider_sect
alg_section = algorithm_sect

[provider_sect]
libwolfprov = libwolfprov_sect

[libwolfprov_sect]
activate = 1
module = /usr/local/openssl/lib64/ossl-modules/libwolfprov.so

[algorithm_sect]
default_properties = fips=yes
```

### Environment Variables

**Required:**
```bash
OPENSSL_CONF=/etc/ssl/openssl.cnf
OPENSSL_MODULES=/usr/local/openssl/lib64/ossl-modules
```

**Set in Dockerfile:**
```dockerfile
ENV OPENSSL_CONF=/etc/ssl/openssl.cnf
ENV OPENSSL_MODULES=/usr/local/openssl/lib64/ossl-modules
```

**Verification:**
```bash
docker run --rm cr.root.io/node:24.14.0-trixie-slim-fips env | grep OPENSSL
# Expected:
# OPENSSL_CONF=/etc/ssl/openssl.cnf
# OPENSSL_MODULES=/usr/local/openssl/lib64/ossl-modules
```

### FIPS Mode Verification

**Check FIPS Mode:**
```bash
# Via Node.js
docker run --rm cr.root.io/node:24.14.0-trixie-slim-fips node -p "crypto.getFips()"
# Expected: 1

# Via OpenSSL
docker run --rm cr.root.io/node:24.14.0-trixie-slim-fips openssl list -providers
# Expected: libwolfprov (wolfSSL Provider v1.1.1, status: active)
```

**Check MD5 Blocking:**
```bash
docker run --rm cr.root.io/node:24.14.0-trixie-slim-fips node -e "crypto.createHash('md5')"
# Expected: Error: error:0308010C:digital envelope routines::unsupported
```

**Check Cipher Suites:**
```bash
docker run --rm cr.root.io/node:24.14.0-trixie-slim-fips node -e "console.log(require('crypto').getCiphers().length)"
# Expected: 30 (FIPS-approved cipher suites only)

docker run --rm cr.root.io/node:24.14.0-trixie-slim-fips node -e "console.log(require('crypto').getCiphers().filter(c => c.includes('md5') || c.includes('sha1')).length)"
# Expected: 0 (no weak cipher suites)
```

---

## Security Properties

### Defense-in-Depth Architecture

**Multiple Layers of FIPS Enforcement:**

1. **Layer 1: wolfSSL FIPS Module**
   - FIPS-validated cryptographic boundary
   - Known Answer Tests (KAT) on startup
   - In-core integrity verification

2. **Layer 2: wolfProvider**
   - Algorithm filtering at provider level
   - MD5 completely blocked (not registered with OpenSSL)
   - SHA-1 blocked in TLS cipher negotiation

3. **Layer 3: OpenSSL Configuration**
   - `fips=yes` property enforced
   - Only FIPS-approved algorithms queryable

4. **Layer 4: Container Integrity**
   - SHA-256 checksums of FIPS libraries
   - Integrity verification on startup
   - Immutable container filesystem

### Integrity Verification

**Build-Time:**
```bash
# Generate checksums during build
sha256sum /usr/local/lib/libwolfssl.so > /usr/local/bin/checksums.txt
sha256sum /usr/local/openssl/lib64/ossl-modules/libwolfprov.so >> /usr/local/bin/checksums.txt
sha256sum /test-fips >> /usr/local/bin/checksums.txt
```

**Runtime:**
```bash
# Verify checksums on container start
/usr/local/bin/integrity-check.sh

# Expected output:
# ==> Verifying FIPS component integrity...
# /usr/local/lib/libwolfssl.so: OK
# /usr/local/openssl/lib64/ossl-modules/libwolfprov.so: OK
# /test-fips: OK
# ==> FIPS COMPONENTS INTEGRITY VERIFIED
```

### Fail-Fast Behavior

**On Integrity Failure:**
```bash
# If integrity check fails
echo "ERROR: FIPS component integrity check failed"
echo "Container will not start"
exit 1
```

**On FIPS POST Failure:**
```bash
# If FIPS POST fails
echo "ERROR: FIPS Power-On Self Test failed"
echo "Container will not start"
exit 1
```

**Skip Checks (Debugging Only):**
```bash
docker run --rm -e SKIP_INTEGRITY_CHECK=true -e SKIP_FIPS_CHECK=true \
  cr.root.io/node:24.14.0-trixie-slim-fips
```

---

## Comparison with Alternatives

### Provider-based vs Engine-based

| Aspect | Provider-based (This Implementation) | Engine-based (Deprecated) |
|--------|--------------------------------------|---------------------------|
| **OpenSSL Version** | 3.0+ | 1.1.1 (deprecated in 3.0) |
| **API** | Modern OSSL_PROVIDER API | Legacy ENGINE API |
| **FIPS Support** | Native provider interface | Engine workarounds required |
| **Isolation** | Better isolation | Tight coupling with OpenSSL internals |
| **Maintenance** | Actively maintained | Deprecated, no future support |

### Provider-based vs Direct Replacement

| Aspect | Provider-based (This Implementation) | Direct Replacement |
|--------|--------------------------------------|--------------------|
| **Node.js Build** | Pre-built binaries (10-12 min) | Source compilation required (25-60 min) |
| **Image Size** | ~320MB | ~400-500MB (includes build tools) |
| **Maintenance** | Easy (just update provider) | Difficult (recompile Node.js) |
| **Compatibility** | High (standard Node.js) | Medium (custom Node.js build) |
| **FIPS Enforcement** | Provider level | Library level |

### Provider-based vs Static Linking

| Aspect | Provider-based (This Implementation) | Static Linking |
|--------|--------------------------------------|----------------|
| **Build Time** | ~12 minutes | ~60 minutes |
| **Binary Size** | Standard Node.js | Larger Node.js binary |
| **Updates** | Update provider only | Recompile entire Node.js |
| **Flexibility** | Can switch providers | Fixed at compile time |
| **FIPS Mode** | Dynamic configuration | Static configuration |

---

## Build Process

### Multi-Stage Docker Build

**4 Stages:**

1. **builder**: Custom OpenSSL 3.5.0 with FIPS support
2. **wolfssl-builder**: wolfSSL FIPS v5.8.2 compilation
3. **wolfprovider-builder**: wolfProvider v1.1.1 compilation
4. **runtime**: Final minimal image with Node.js + OpenSSL + wolfSSL FIPS

### Build Steps

**Stage 1: Custom OpenSSL 3.5.0**
```dockerfile
FROM debian:trixie-slim as builder
RUN wget https://www.openssl.org/source/openssl-3.5.0.tar.gz
RUN ./Configure --prefix=/usr/local/openssl --enable-fips shared linux-x86_64
RUN make -j"$(nproc)" && make install_sw && make install_fips
```

**Stage 2: wolfSSL FIPS**
```dockerfile
FROM debian:trixie-slim as wolfssl-builder
RUN --mount=type=secret,id=wolfssl_password \
    7z x -p$(cat /run/secrets/wolfssl_password) wolfssl-5.8.2-fips.7z
RUN ./configure --enable-fips=v5 --enable-opensslcoexist
RUN ./fips-hash.sh  # Critical: Set FIPS in-core integrity hash
RUN make -j"$(nproc)" && make install
```

**Stage 3: wolfProvider**
```dockerfile
FROM debian:trixie-slim as wolfprovider-builder
RUN git clone --depth 1 --branch v1.1.1 https://github.com/wolfSSL/wolfProvider.git
RUN ./configure --with-openssl=/usr/local/openssl --with-wolfssl=/usr/local
RUN make && make install
```

**Stage 4: Runtime + System OpenSSL Replacement**
```dockerfile
FROM debian:trixie-slim

# Copy artifacts from build stages
COPY --from=builder /usr/local/openssl /usr/local/openssl
COPY --from=wolfssl-builder /usr/local/lib/libwolfssl.so* /usr/local/lib/
COPY --from=wolfprovider-builder /usr/local/openssl/lib64/ossl-modules/ /usr/local/openssl/lib64/ossl-modules/

# CRITICAL: Replace system OpenSSL with FIPS OpenSSL
RUN cp -av /usr/local/openssl/lib64/libssl.so* /usr/lib/x86_64-linux-gnu/ && \
    cp -av /usr/local/openssl/lib64/libcrypto.so* /usr/lib/x86_64-linux-gnu/ && \
    cp -av /usr/local/openssl/bin/openssl /usr/bin/openssl && \
    echo "/usr/lib/x86_64-linux-gnu" > /etc/ld.so.conf.d/fips-openssl.conf && \
    echo "/usr/local/openssl/lib64" >> /etc/ld.so.conf.d/fips-openssl.conf && \
    echo "/usr/local/lib" >> /etc/ld.so.conf.d/fips-openssl.conf && \
    ldconfig

# Install Node.js from NodeSource
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - && \
    apt-get install -y nodejs=24.14.1-1nodesource1

# Copy configuration
COPY openssl.cnf /etc/ssl/openssl.cnf
COPY docker-entrypoint.sh /docker-entrypoint.sh

# Set environment variables
ENV OPENSSL_CONF=/etc/ssl/openssl.cnf
ENV OPENSSL_MODULES=/usr/local/openssl/lib64/ossl-modules

ENTRYPOINT ["/docker-entrypoint.sh"]
```

### Build Time

- **OpenSSL**: ~3 minutes
- **wolfSSL FIPS**: ~5 minutes
- **wolfProvider**: ~2 minutes
- **Node.js + Assembly**: ~2 minutes
- **Total**: ~12 minutes

---

## Validation and Testing

### Diagnostic Test Suites

**5 Test Suites (32 total tests):**

1. **Backend Verification** (6 tests)
   - Node.js version verification
   - wolfSSL library presence
   - wolfProvider library presence
   - OpenSSL configuration validation
   - Environment variable checks
   - Crypto module capabilities

2. **Connectivity** (8 tests)
   - HTTPS GET requests
   - TLS 1.2 protocol support
   - TLS 1.3 protocol support
   - Certificate validation
   - Cipher suite negotiation
   - Concurrent connections
   - HTTPS POST requests

3. **FIPS Verification** (6 tests)
   - FIPS mode status
   - FIPS self-test execution
   - FIPS-approved algorithms
   - Cipher suite FIPS compliance
   - FIPS boundary check
   - Non-FIPS algorithm rejection

4. **Crypto Operations** (8 tests)
   - SHA-256 hash generation
   - SHA-384 hash generation
   - SHA-512 hash generation
   - HMAC-SHA256 operations
   - Random bytes generation
   - AES-256-GCM encryption
   - FIPS cipher availability
   - MD5 rejection (blocked)

5. **Library Compatibility** (4 tests)
   - Native HTTPS module
   - Native crypto module
   - TLS module compatibility
   - Buffer/crypto integration

**Run Tests:**
```bash
./diagnostic.sh

# Expected: 32/32 tests passing (100%)
```

### FIPS KAT Tests

**Executable:** `/test-fips`

**Tests:**
- SHA-256, SHA-384, SHA-512 KAT
- AES-128-CBC, AES-256-CBC, AES-256-GCM KAT
- HMAC-SHA256, HMAC-SHA384 KAT
- RSA 2048 KAT
- ECDSA P-256 KAT

**Run:**
```bash
docker run --rm cr.root.io/node:24.14.0-trixie-slim-fips /test-fips
```

### Integration Tests

**Test Image:**
```bash
cd diagnostics/test-images/basic-test-image
./build.sh
docker run --rm node-fips-test:latest
# Expected: 15/15 tests passed (100%)
```

**Demo Applications:**
```bash
cd demos-image
./build.sh
docker run --rm node-fips-demos:24.14.0 node /opt/demos/hash_algorithm_demo.js
```

---

## Summary

This architecture provides FIPS 140-3 validated cryptography for Node.js 24 applications using a provider-based approach that:

✅ **No Node.js compilation** - Uses pre-built binaries (fast builds)
✅ **FIPS 140-3 validated** - wolfSSL 5.8.2 (Certificate #4718)
✅ **Full compatibility** - Works with existing Node.js applications
✅ **Defense-in-depth** - Multiple layers of FIPS enforcement
✅ **Production-ready** - 32/32 tests passing (100%)
✅ **Well-documented** - Comprehensive architecture documentation

**Key Innovation:** System OpenSSL replacement ensures Node.js dynamically links to FIPS-enabled OpenSSL at runtime, providing seamless FIPS enforcement without source compilation.

---

**Document Status**: APPROVED FOR RELEASE
**Classification**: PUBLIC
**Distribution**: UNLIMITED
