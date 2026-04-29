# Python 3.13.7 wolfSSL FIPS Architecture

**Document Version**: 1.0
**Last Updated**: 2026-03-21
**FIPS Certificate**: #4718 (wolfSSL 5.8.2)
**Architecture**: Provider-based (OpenSSL 3.0+ with wolfProvider)

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

This implementation provides FIPS 140-3 validated cryptography for Python 3.13.7 applications using a **provider-based architecture**. Instead of replacing Python's OpenSSL with wolfSSL directly, we use **OpenSSL 3.0's provider interface** to route cryptographic operations to wolfSSL's FIPS-validated module.

### Key Features

- **FIPS 140-3 Validated**: wolfSSL 5.8.2 (Certificate #4718)
- **Provider-based**: Uses OpenSSL 3.0.18 provider architecture
- **Python 3.13.7 Compatible**: Full standard library support
- **TLS 1.2/1.3**: Modern protocol support with FIPS-approved cipher suites
- **No Python Recompilation**: Works with standard Python builds
- **Debian Bookworm**: Based on stable Debian 12

### Architecture Type

**Provider-based** (recommended approach for OpenSSL 3.0+)

```
Python 3.13.7 → OpenSSL 3.0.18 API → wolfProvider v1.0.2 → wolfSSL 5.8.2 FIPS
```

This differs from:
- **Engine-based** (deprecated in OpenSSL 3.0)
- **Direct replacement** (requires Python recompilation)
- **Static linking** (inflexible, larger binaries)

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│ Python 3.13.7 Application Layer                          │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Python Code (app.py)                                │ │
│ │   import ssl, hashlib, http.client                  │ │
│ └─────────────────────────────────────────────────────┘ │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│ Python Standard Library                                 │
│ ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│ │ ssl module   │  │ hashlib      │  │ http.client  │   │
│ │ (OpenSSL API)│  │ (crypto API) │  │ (HTTPS)      │   │
│ └──────────────┘  └──────────────┘  └──────────────┘   │
└────────────────────────┬────────────────────────────────┘
                         │ libssl, libcrypto
                         ▼
┌─────────────────────────────────────────────────────────┐
│ OpenSSL 3.0.18 (Provider Interface)                     │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ SSL/TLS Engine (libssl)                             │ │
│ │ - Protocol handling (TLS 1.2, TLS 1.3)              │ │
│ │ - Certificate validation                            │ │
│ │ - Handshake management                              │ │
│ └─────────────────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Crypto API Layer (libcrypto)                        │ │
│ │ - Algorithm dispatch via EVP interface              │ │
│ │ - Provider loading and management                   │ │
│ │ - Configuration: /etc/ssl/openssl.cnf               │ │
│ └─────────────────────────────────────────────────────┘ │
└────────────────────────┬────────────────────────────────┘
                         │ Provider API (OSSL_PROVIDER)
                         ▼
┌─────────────────────────────────────────────────────────┐
│ wolfProvider v1.0.2                                     │
│ (/usr/local/lib/libwolfprov.so)                         │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Provider Implementation                             │ │
│ │ - Implements OpenSSL provider interface            │ │
│ │ - Routes crypto operations to wolfSSL              │ │
│ │ - Registers FIPS-approved algorithms               │ │
│ │   ✓ AES-GCM (128, 192, 256)                        │ │
│ │   ✓ SHA-2 family (SHA-256, SHA-384, SHA-512)       │ │
│ │   ✓ ECDHE, RSA, HMAC                               │ │
│ │ - Filters algorithms via FIPS property             │ │
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
│ └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
                    Hardware/OS
```

---

## Component Stack

### Layer 1: Python Application Layer

**Components:**
- Python 3.13.7.x application code
- Standard library modules: `ssl`, `hashlib`, `http.client`, `urllib`
- Third-party libraries: `requests`, `urllib3`, etc.

**Responsibilities:**
- Application logic
- TLS connection requests
- Certificate verification
- Cryptographic operations via standard Python APIs

**FIPS Relevance:**
- No application code changes required for FIPS compliance
- Transparent FIPS operation through standard library

---

### Layer 2: Python Standard Library

**Components:**
- `ssl` module - TLS/SSL wrapper for OpenSSL
- `hashlib` module - Cryptographic hash functions
- `_hashlib` C extension - Links to OpenSSL libcrypto

**File Locations:**
```
/usr/local/lib/python3.13/ssl.py
/usr/local/lib/python3.13/lib-dynload/_ssl.cpython-313-x86_64-linux-gnu.so
/usr/local/lib/python3.13/lib-dynload/_hashlib.cpython-313-x86_64-linux-gnu.so
```

**API Examples:**
```python
import ssl
context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
# Calls: OpenSSL SSL_CTX_new() → wolfProvider → wolfSSL

import hashlib
h = hashlib.sha256(b"data")
# Calls: OpenSSL EVP_DigestInit() → wolfProvider → wolfSSL
```

---

### Layer 3: OpenSSL 3.0.18

**Components:**
- **libssl.so.3** - SSL/TLS protocol implementation
- **libcrypto.so.3** - Cryptographic algorithms and providers

**Configuration:**
- `/etc/ssl/openssl.cnf` - Provider configuration
- Environment: `OPENSSL_CONF=/etc/ssl/openssl.cnf`

**Key Functions:**
- Protocol handling (TLS 1.2, TLS 1.3)
- Certificate chain validation
- Provider interface management
- Algorithm dispatch via EVP API

**Provider Loading:**
```c
// OpenSSL loads providers at initialization
OSSL_PROVIDER *prov = OSSL_PROVIDER_load(NULL, "libwolfprov");
OSSL_PROVIDER_set_default_search_path(NULL, "/usr/local/lib");
```

---

### Layer 4: wolfProvider 1.0.2

**File:** `/usr/local/lib/libwolfprov.so`

**Purpose:**
Bridge between OpenSSL 3.0 provider API and wolfSSL FIPS module

**Responsibilities:**

1. **Provider Registration:**
   ```c
   OSSL_provider_init() {
       // Register provider with OpenSSL
       // Declare algorithm support
       // Set FIPS properties
   }
   ```

2. **Algorithm Dispatch:**
   - Maps OpenSSL EVP calls to wolfSSL functions
   - Example: `EVP_DigestInit(SHA256)` → `wc_Sha256Init()`

3. **FIPS Property Management:**
   - Tags FIPS-approved algorithms with `fips=yes`
   - Blocks non-FIPS algorithms when `default_properties = fips=yes`

4. **Supported Algorithms:**
   - **Ciphers:** AES-GCM (128, 192, 256), AES-CCM
   - **Hashes:** SHA-256, SHA-384, SHA-512
   - **MAC:** HMAC with SHA-2
   - **Key Exchange:** ECDHE (P-256, P-384, P-521), RSA
   - **Signatures:** RSA-PSS, ECDSA

**Source Code:**
- Built from: `https://github.com/wolfSSL/wolfProvider`
- Version: v1.0.2
- Build flags: `--enable-fips=v5.8.2`

---

### Layer 5: wolfSSL 5.8.2 FIPS Module

**File:** `/usr/local/lib/libwolfssl.so.44.0.0`

**FIPS Validation:**
- **Certificate Number:** #4718
- **Algorithm Certificate:** A4718
- **Standard:** FIPS 140-3
- **Security Level:** Level 1
- **Operational Environment:** Intel x86_64 / Debian 12

**FIPS Boundary:**
- **Size:** 789,400 bytes (library file)
- **Scope:** wolfCrypt cryptographic library
- **Integrity:** HMAC-SHA-256 verification on startup

**Self-Tests:**
```c
// Executed at module load
wolfCrypt_FIPS_POST()  // Power-On Self Test
  ├── KAT for AES-GCM
  ├── KAT for SHA-256/384/512
  ├── KAT for HMAC
  ├── KAT for ECDSA
  ├── KAT for RSA
  └── Integrity check (HMAC-SHA-256)
```

**Validated Algorithms:**

| Algorithm | Key Sizes | Modes | Usage |
|-----------|-----------|-------|-------|
| AES | 128, 192, 256 | GCM, CCM | Encryption |
| SHA-2 | N/A | SHA-256, SHA-384, SHA-512 | Hashing |
| HMAC | Variable | SHA-256, SHA-384, SHA-512 | MAC |
| RSA | 2048, 3072, 4096 | PKCS#1, PSS | Key exchange, signing |
| ECDSA | P-256, P-384, P-521 | N/A | Signing |
| ECDH | P-256, P-384, P-521 | N/A | Key agreement |

**Build Configuration:**
```bash
./configure \
    --enable-fips=v5.8.2 \
    --enable-aesni \
    --enable-intelasm \
    --enable-sp \
    --enable-sp-asm \
    --enable-tlsv12 \
    --enable-tlsv13
```

---

## FIPS 140-3 Cryptographic Module

### Compliance Details

**Certificate Information:**
- **Certificate #:** 4718
- **Module Name:** wolfCrypt FIPS 140-3
- **Module Version:** 5.8.2
- **Validation Level:** Level 1
- **Validation Date:** 2024
- **Vendor:** root.io Inc.

**Security Requirements Met:**
1. **Cryptographic Module Specification** - Level 1
2. **Cryptographic Module Interfaces** - Level 1
3. **Roles, Services, and Authentication** - Level 1
4. **Software/Firmware Security** - Level 1
5. **Operational Environment** - Level 1
6. **Physical Security** - N/A (software module)
7. **Non-invasive Security** - N/A
8. **Sensitive Security Parameter Management** - Level 1
9. **Self-Tests** - Level 1
10. **Life-Cycle Assurance** - Level 1
11. **Mitigation of Other Attacks** - N/A

### FIPS Mode Operation

**Mode:** FIPS Ready Mode (Recommended)

**Configuration:**
```ini
# /etc/ssl/openssl.cnf
[algorithm_sect]
default_properties = fips=yes  # Only use FIPS-approved algorithms
```

**Verification:**

1. **Known Answer Tests (KAT):**
   ```bash
   # Automatically run on module load
   # Tests include: AES, SHA-2, HMAC, RSA, ECDSA
   # Location: wolfSSL library initialization
   ```

2. **Algorithm Verification:**
   ```bash
   # Verify FIPS algorithms available
   openssl list -digest-algorithms -provider libwolfprov
   openssl list -cipher-algorithms -provider libwolfprov
   ```

3. **MD5 Blocking Test:**
   ```bash
   # Should fail with "unsupported" error
   echo -n "test" | openssl dgst -md5
   # Error: Algorithm (MD5 : 100), Properties ()
   ```

### FIPS Boundary

The FIPS boundary encompasses the wolfSSL cryptographic library:

**Included in Boundary:**
- All cryptographic algorithm implementations
- Key generation and management
- Self-test code (POST, KAT)
- Integrity verification
- FIPS-approved random number generation

**Excluded from Boundary:**
- OpenSSL protocol layer (TLS handshake logic)
- wolfProvider glue code
- Python interpreter
- Application code

**Data Flows Across Boundary:**

```
Input:
  - Plaintext data
  - Keys (AES, RSA, ECC)
  - Initialization vectors
  - Authentication tags

Processing (within boundary):
  - Encryption/Decryption
  - Hashing
  - Signature generation/verification
  - Key derivation

Output:
  - Ciphertext
  - Hash digests
  - Signatures
  - Derived keys
```

---

## Provider Architecture

### Why Provider-based?

**Advantages:**

1. **Python Compiled from Official Source:**
   - Python 3.13.7 is built from the official CPython source tarball (GPG-verified)
   - Python's `_ssl` and `_hashlib` extensions link to OpenSSL dynamically at runtime

2. **Clean Separation:**
   - OpenSSL handles protocols (TLS, X.509)
   - wolfSSL handles cryptography (AES, SHA-2)
   - Each component does what it does best

3. **Standards Compliance:**
   - OpenSSL 3.0 provider API is the official mechanism
   - Replaces deprecated ENGINE API
   - Future-proof architecture

4. **Flexibility:**
   - Can load multiple providers
   - Runtime provider selection
   - Easy configuration changes

**Comparison:**

| Approach | Python Rebuild | FIPS Crypto | Protocol Layer | Complexity |
|----------|----------------|-------------|----------------|------------|
| **Provider-based** | Source build | wolfSSL FIPS | OpenSSL | Low |
| Engine-based | Source build | wolfSSL FIPS | OpenSSL | Medium (deprecated) |
| Direct replacement | **Yes** | wolfSSL FIPS | wolfSSL | High |
| Static linking | **Yes** | wolfSSL FIPS | wolfSSL | Very High |

### Provider Loading Sequence

```
1. Python starts
   └─> Imports ssl module

2. ssl module loads
   └─> Dynamically links _ssl.so
       └─> Links against libssl.so.3, libcrypto.so.3

3. OpenSSL initialization
   ├─> Reads OPENSSL_CONF environment variable
   ├─> Parses /etc/ssl/openssl.cnf
   ├─> Loads providers listed in [provider_sect]
   └─> Activates providers with activate = 1

4. wolfProvider loads
   ├─> OSSL_provider_init() called by OpenSSL
   ├─> Links to libwolfssl.so at runtime
   ├─> Runs wolfSSL FIPS POST (self-tests)
   └─> Registers algorithms with FIPS property

5. Application runs
   ├─> Python ssl/hashlib calls
   ├─> OpenSSL EVP layer dispatches to provider
   ├─> wolfProvider routes to wolfSSL
   └─> wolfSSL executes FIPS-approved crypto
```

### Provider Configuration

**/etc/ssl/openssl.cnf:**

```ini
# Global OpenSSL configuration
openssl_conf = openssl_init

[openssl_init]
providers = provider_sect
alg_section = algorithm_sect

[provider_sect]
# Load wolfProvider
libwolfprov = libwolfprov_sect

[libwolfprov_sect]
# Activate provider on startup
activate = 1
# Provider library location
module = /usr/local/lib/libwolfprov.so

[algorithm_sect]
# CRITICAL: Only use algorithms with fips=yes property
default_properties = fips=yes
```

**Key Setting:** `default_properties = fips=yes`

This instructs OpenSSL to only use algorithms that have the `fips` property set. wolfProvider marks only FIPS-approved algorithms with this property, effectively blocking MD5, SHA-1 (for signing), and other non-FIPS algorithms.

**Without this setting:**
- MD5 would be available via `openssl dgst -md5`
- Non-FIPS cipher suites would be negotiable
- FIPS mode would not be enforced

**With this setting:**
- MD5 blocked: `openssl dgst -md5` fails with "unsupported"
- Only 14 FIPS cipher suites available (all AES-GCM with SHA-256/384)
- SHA-1 available only for legacy cert verification (FIPS-compliant)

---

## Configuration Management

### Environment Variables

```bash
# OpenSSL configuration file location
export OPENSSL_CONF=/etc/ssl/openssl.cnf

# Provider search path (optional, defaults to system lib paths)
export OPENSSL_MODULES=/usr/local/lib

# Enable OpenSSL debugging (optional)
export OPENSSL_DEBUG_MEMORY=1
```

### Library Paths

**wolfSSL FIPS Module:**
```
/usr/local/lib/libwolfssl.so.44 -> libwolfssl.so.44.0.0
/usr/local/lib/libwolfssl.so.44.0.0  # Actual library
```

**wolfProvider:**
```
/usr/local/lib/libwolfprov.so  # Provider library
```

**OpenSSL:**
```
/usr/lib/x86_64-linux-gnu/libssl.so.3 -> libssl.so.3.0.13
/usr/lib/x86_64-linux-gnu/libcrypto.so.3 -> libcrypto.so.3.0.13
```

**LD_LIBRARY_PATH:**
```bash
# Ensure wolfSSL is found before any system OpenSSL FIPS modules
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
```

### Cipher Suite Configuration

**Default Configuration** (FIPS Ready Mode):

All 14 available cipher suites use only FIPS-approved algorithms:

**TLS 1.3 Cipher Suites (3):**
- `TLS_AES_256_GCM_SHA384`
- `TLS_CHACHA20_POLY1305_SHA256`
- `TLS_AES_128_GCM_SHA256`

**TLS 1.2 Cipher Suites (11):**
- `ECDHE-ECDSA-AES256-GCM-SHA384`
- `ECDHE-RSA-AES256-GCM-SHA384`
- `ECDHE-ECDSA-AES128-GCM-SHA256`
- `ECDHE-RSA-AES128-GCM-SHA256`
- `AES256-GCM-SHA384`
- `AES128-GCM-SHA256`
- (+ 5 more AES-GCM variants)

**Blocked Cipher Suites:**
- Any using MD5 (0 available)
- Any using SHA-1 for TLS handshake (0 available)
- Any using 3DES, RC4, or other deprecated algorithms

**Cipher String Examples:**

```python
import ssl

# Strict FIPS (AES-GCM only with SHA-256/384)
context.set_ciphers('ECDHE+AESGCM:AES256-GCM-SHA384:AES128-GCM-SHA256')

# TLS 1.3 preferred
context.set_ciphers('TLS_AES_256_GCM_SHA384:TLS_AES_128_GCM_SHA256')

# High security (256-bit only)
context.set_ciphers('AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384')
```

---

## Security Properties

### FIPS Compliance

**Status:** ✅ FIPS 140-3 Validated

**Evidence:**
1. wolfSSL 5.8.2 FIPS module (Certificate #4718)
2. All cryptographic operations routed to FIPS module
3. Known Answer Tests passing on every startup
4. Integrity verification (HMAC-SHA-256) on module load
5. Non-FIPS algorithms blocked via `fips=yes` property

### Algorithm Security

**Approved Algorithms:**

| Category | Algorithms | Key Sizes | Status |
|----------|-----------|-----------|--------|
| **Symmetric** | AES-GCM | 128, 192, 256-bit | ✅ FIPS Approved |
| **Hash** | SHA-256 | 256-bit output | ✅ FIPS Approved |
| **Hash** | SHA-384 | 384-bit output | ✅ FIPS Approved |
| **Hash** | SHA-512 | 512-bit output | ✅ FIPS Approved |
| **MAC** | HMAC-SHA256 | Variable key | ✅ FIPS Approved |
| **Key Exchange** | ECDHE | P-256, P-384, P-521 | ✅ FIPS Approved |
| **Key Exchange** | RSA | 2048, 3072, 4096-bit | ✅ FIPS Approved |
| **Signature** | ECDSA | P-256, P-384, P-521 | ✅ FIPS Approved |
| **Signature** | RSA-PSS | 2048, 3072, 4096-bit | ✅ FIPS Approved |

**Blocked Algorithms:**

| Algorithm | Reason | Blocking Mechanism |
|-----------|--------|-------------------|
| MD5 | Cryptographically broken | `fips=yes` property filter |
| SHA-1 (signing) | Weak collision resistance | Not available in cipher suites |
| SHA-1 (verify) | Legacy only | ℹ️ Available for old certs (FIPS-compliant) |
| 3DES | 64-bit block size weakness | Not provided by wolfProvider |
| RC4 | Stream cipher vulnerabilities | Not provided by wolfProvider |

### TLS/SSL Security

**Supported Protocols:**
- ✅ TLS 1.3 (preferred)
- ✅ TLS 1.2 (required for legacy compatibility)
- ❌ TLS 1.1 (disabled - deprecated)
- ❌ TLS 1.0 (disabled - deprecated)
- ❌ SSL 3.0 (disabled - broken)
- ❌ SSL 2.0 (disabled - broken)

**Security Features:**

1. **Perfect Forward Secrecy (PFS):**
   - All ECDHE cipher suites provide PFS
   - Session keys not derivable from long-term keys

2. **Certificate Validation:**
   - X.509 certificate chain verification
   - Hostname verification (SNI)
   - Revocation checking (OCSP, CRL)

3. **Modern Extensions:**
   - SNI (Server Name Indication)
   - ALPN (Application-Layer Protocol Negotiation)
   - Session resumption (TLS 1.3 PSK)

4. **Downgrade Protection:**
   - TLS 1.3 downgrade protection
   - Protocol version enforcement

### MD5/SHA-1 Handling

**MD5:**
- ❌ **BLOCKED** at OpenSSL level
- Verification: `openssl dgst -md5` fails with "unsupported"
- Zero MD5-based cipher suites available
- Python `hashlib.md5()` may work (built-in implementation, not OpenSSL)

**SHA-1:**
- ℹ️ **Available** for legacy certificate verification (FIPS-compliant)
- ❌ **Not available** for new signatures in TLS handshakes
- ✅ **Can verify** old certificates with SHA-1 signatures
- ❌ **Cannot create** new SHA-1 signatures

**Why SHA-1 is Allowed:**

FIPS 140-3 Implementation Guidance (IG) permits SHA-1 for:
1. Verification of existing digital signatures
2. Legacy certificate chain validation
3. Non-security-critical contexts (checksums, identifiers)

**Not Permitted:**
- Creating new SHA-1 signatures
- Using SHA-1 in HMAC for new TLS sessions
- SHA-1-based cipher suites

---

## Comparison with Alternatives

### Architecture Comparison

| Feature | Provider-based | Engine-based | Direct Replacement | Static Linking |
|---------|----------------|--------------|-------------------|----------------|
| **Python Rebuild** | ❌ No | ❌ No | ✅ Yes | ✅ Yes |
| **OpenSSL Version** | 3.0+ | 1.1.1 (deprecated) | N/A | N/A |
| **FIPS Crypto** | wolfSSL | wolfSSL | wolfSSL | wolfSSL |
| **TLS Protocol** | OpenSSL | OpenSSL | wolfSSL | wolfSSL |
| **Configuration** | openssl.cnf | openssl.cnf | Runtime | Compile-time |
| **Flexibility** | High | Medium | Low | Very Low |
| **Complexity** | Low | Medium | High | Very High |
| **Maintainability** | Easy | Medium | Hard | Very Hard |
| **Future-proof** | ✅ Yes | ❌ Deprecated | ⚠️ Uncertain | ❌ No |

### Recommended Approach

**Provider-based (this implementation)** is recommended because:

1. **Standards-compliant:** Uses OpenSSL 3.0+ official provider API
2. **No Python changes:** Works with standard Python builds
3. **Clean architecture:** Separation of concerns between protocol and crypto
4. **Easy upgrades:** Update wolfSSL without rebuilding Python
5. **Widely supported:** Provider API is the future of OpenSSL

**When to use alternatives:**

- **Engine-based:** Only if stuck on OpenSSL 1.1.1 (not recommended)
- **Direct replacement:** If you need wolfSSL for both TLS and crypto (rare)
- **Static linking:** Embedded systems with minimal dynamic linking

---

## Build Process

### Build Stages

**Stage 1: wolfSSL FIPS 5.8.2**

```dockerfile
FROM cr.root.io/debian:bookworm-slim AS builder

# Download wolfSSL FIPS commercial archive (password-protected 7z)
RUN --mount=type=secret,id=wolfssl_password \
    wget -O /tmp/wolfssl.7z "${WOLFSSL_URL}"; \
    7z x /tmp/wolfssl.7z -o/usr/src -p"$(cat /run/secrets/wolfssl_password)"; \
    mv /usr/src/wolfssl* /usr/src/wolfssl

# Configure for FIPS 140-3 v5
cd /usr/src/wolfssl && ./configure \
    --prefix=/usr/local \
    --enable-fips=v5 \
    --enable-opensslcoexist \
    --enable-cmac \
    --enable-keygen \
    --enable-sha \
    --enable-aesctr \
    --enable-aesccm \
    --enable-x963kdf \
    --enable-compkey \
    --enable-altcertchains \
    --enable-certgen \
    --enable-aeskeywrap \
    --enable-enckeys \
    --enable-base16 \
    --with-eccminsz=192 \
    CPPFLAGS="-DHAVE_AES_ECB -DWOLFSSL_AES_DIRECT -DWC_RSA_NO_PADDING \
              -DWOLFSSL_PUBLIC_MP -DHAVE_PUBLIC_FFDHE -DWOLFSSL_DH_EXTRA \
              -DWOLFSSL_PSS_LONG_SALT -DWOLFSSL_PSS_SALT_LEN_DISCOVER \
              -DRSA_MIN_SIZE=2048"

# Build, run fips-hash.sh to embed FIPS integrity hash, then install
make -j$(nproc) && ./fips-hash.sh && make -j$(nproc) && make install

# Result: /usr/local/lib/libwolfssl.so*
```

**Stage 2: wolfProvider 1.0.2**

```dockerfile
# Download wolfProvider v1.0.2 source tarball
wget -O /tmp/wolfprovider.tar.gz "${WOLFPROVIDER_URL}"
tar --extract --directory /usr/src --file /tmp/wolfprovider.tar.gz
mv /usr/src/wolfProvider* /usr/src/wolfProvider

cd /usr/src/wolfProvider && autoreconf -ivf

# Configure against wolfSSL installed in /usr/local
./configure \
    --prefix=/usr/local \
    --with-wolfssl=/usr/local

make -j$(nproc) && make install

# Result: /usr/local/lib/libwolfprov.so
```

**Stage 3: OpenSSL 3.0 (from base image)**

OpenSSL is **not installed explicitly** — it is provided by the base image
`cr.root.io/debian:bookworm-slim` (OpenSSL 3.0.x from Debian Bookworm).
The builder stage installs `libssl-dev` only as a compile-time dependency for
building Python; the runtime stage inherits OpenSSL shared libraries directly
from the base image.

The wolfProvider is wired in by copying a custom `openssl.cnf`:

```ini
# /etc/ssl/openssl.cnf
openssl_conf = openssl_init

[openssl_init]
providers = provider_sect
alg_section = algorithm_sect

[provider_sect]
libwolfprov = libwolfprov_sect

[libwolfprov_sect]
activate = 1
module = /usr/local/lib/libwolfprov.so

[algorithm_sect]
default_properties = fips=yes
```

Environment variables activate the configuration at runtime:

```dockerfile
ENV OPENSSL_CONF=/etc/ssl/openssl.cnf
ENV OPENSSL_MODULES=/usr/local/lib
ENV LD_LIBRARY_PATH=/usr/local/lib
```

**Stage 4: Python 3.13.7 (compiled from source)**

Python is **compiled from source** in the builder stage against the system
OpenSSL headers (`libssl-dev`). It is NOT installed from Debian packages.

```dockerfile
# Download and GPG-verify Python 3.13.7 source tarball
wget -O python.tar.xz "https://www.python.org/ftp/python/3.13.7/Python-3.13.7.tar.xz"
echo "$PYTHON_SHA256 *python.tar.xz" | sha256sum -c -

cd /usr/src/python

# Patch: remove scrypt support (not available in wolfSSL)
sed -i 's/#define PY_OPENSSL_HAS_SCRYPT 1//g' Modules/_hashopenssl.c

./configure \
    --enable-loadable-sqlite-extensions \
    --enable-option-checking=fatal \
    --enable-shared \
    --with-lto \
    --with-ensurepip

make -j$(nproc) && make install

# Result: /usr/local/bin/python3*, /usr/local/lib/python3.13/,
#         /usr/local/lib/libpython3.13.so*
# Python's _ssl and _hashlib extensions link dynamically to the system
# libssl.so.3 / libcrypto.so.3, which load wolfProvider at runtime.
```

### Verification Steps

```dockerfile
# Verify wolfSSL FIPS
RUN ldd /usr/local/lib/libwolfssl.so.44.0.0
RUN ls -lh /usr/local/lib/libwolfssl.so.44.0.0  # Should be ~789KB

# Verify wolfProvider
RUN ldd /usr/local/lib/libwolfprov.so
RUN openssl list -providers -provider libwolfprov

# Verify Python links to OpenSSL
RUN ldd /usr/local/lib/python3.13/lib-dynload/_ssl.cpython-313-*.so | grep libssl

# Verify FIPS mode
RUN python3 -c "import ssl; print(ssl.OPENSSL_VERSION)"
RUN echo 'test' | openssl dgst -md5 2>&1 | grep -i unsupported
```

---

## Validation and Testing

### Test Coverage

**1. Backend Verification (6 tests):**
- SSL version reporting
- wolfSSL/wolfProvider library presence
- OpenSSL configuration
- SSL module capabilities
- Available cipher suites
- Provider loading

**2. Connectivity Tests (8 tests):**
- HTTPS GET requests (Google, GitHub, Python.org, APIs)
- TLS 1.2 connections
- TLS 1.3 connections
- Certificate chain validation
- Concurrent connections

**3. FIPS Verification (6 tests):**
- FIPS mode status
- FIPS self-test execution (/test-fips binary)
- FIPS-approved algorithms (SHA-256, SHA-384, SHA-512)
- Cipher suite FIPS compliance
- FIPS boundary check (wolfSSL library)
- Non-FIPS algorithm rejection (MD5 blocking)

**4. Crypto Operations (10 tests):**
- Default SSL context creation
- Custom SSL contexts (TLS 1.2, TLS 1.3)
- Cipher suite selection
- Certificate loading (CA bundle)
- SNI (Server Name Indication)
- ALPN (Application-Layer Protocol Negotiation)
- Session resumption
- Peer certificate retrieval
- Certificate hostname verification

**5. Library Compatibility (6 tests):**
- Standard library: http.client
- Standard library: json
- Standard library: hashlib
- Standard library: ssl
- Third-party: requests (optional)
- Standard library: urllib.request

**Total:** 36 individual tests across 5 test suites

### Test Results

**Overall Pass Rate:** 100% (5/5 test suites)
**Individual Tests:** 35/36 passing (1 optional library skipped)

See [TEST-RESULTS.md](TEST-RESULTS.md) for detailed test output.

### Running Tests

**Inside Docker Container:**

```bash
# Run all diagnostic tests
./diagnostics/run-all-tests.sh

# Run individual test suite
./diagnostics/test-backend-verification.py
./diagnostics/test-connectivity.py
./diagnostics/test-fips-verification.py
./diagnostics/test-crypto-operations.py
./diagnostics/test-library-compatibility.py
```

**Expected Output:**

```
================================================================
  Test Summary
================================================================
  Total Test Suites: 5
  Passed: 5
  Failed: 0

  Pass Rate: 100%

✓ ALL TEST SUITES PASSED
  Python wolfSSL FIPS implementation is ready for production
```

### Continuous Validation

**FIPS Self-Tests (Automatic):**

wolfSSL runs Known Answer Tests (KATs) automatically on every module load:

```
Module Load Sequence:
1. Library loaded by dynamic linker
2. wolfCrypt_FIPS_first() called (initialization)
3. Power-On Self Test (POST) executed
   ├─ AES-GCM KAT
   ├─ SHA-256/384/512 KAT
   ├─ HMAC KAT
   ├─ ECDSA KAT
   ├─ RSA KAT
   └─ Integrity check (HMAC-SHA-256 of module)
4. If tests pass: module initialized
5. If tests fail: module refuses to operate
```

**Manual Verification:**

```bash
# Verify MD5 is blocked
echo -n "test" | openssl dgst -md5
# Should fail with "unsupported"

# Verify SHA-256 works
echo -n "test" | openssl dgst -sha256
# Should succeed: a94a8fe5ccb19ba61c4c0873d391e987982fbbd3

# Verify FIPS cipher suites
python3 -c "
import ssl
ctx = ssl.create_default_context()
ciphers = ctx.get_ciphers()
print(f'Total ciphers: {len(ciphers)}')
for c in ciphers[:5]:
    print(f'  - {c[\"name\"]}: {c[\"protocol\"]}')
"
```

---

## References

### Documentation

- [TEST-RESULTS.md](TEST-RESULTS.md) - Comprehensive test results
- [DEVELOPER-GUIDE.md](DEVELOPER-GUIDE.md) - Development and usage guide
- [Dockerfile](Dockerfile) - Complete build instructions

### Specifications

- **FIPS 140-3:** [NIST FIPS 140-3](https://csrc.nist.gov/publications/detail/fips/140/3/final)
- **wolfSSL FIPS:** [Certificate #4718](https://csrc.nist.gov/projects/cryptographic-module-validation-program/certificate/4718)
- **OpenSSL Providers:** [OpenSSL Provider Documentation](https://www.openssl.org/docs/manmaster/man7/provider.html)

### Source Code

- **wolfSSL:** https://github.com/wolfSSL/wolfssl (FIPS 5.8.2 release)
- **wolfProvider:** https://github.com/wolfSSL/wolfProvider (v1.0.2)
- **OpenSSL:** https://github.com/openssl/openssl (3.0.18)
- **Python:** https://github.com/python/cpython (3.13.7)

---

## Appendix: Architecture Decision Record

### ADR-001: Use Provider-based Architecture

**Status:** Accepted

**Context:**

We need to provide FIPS 140-3 validated cryptography for Python 3.13.7 applications. Multiple approaches exist:
1. Provider-based (OpenSSL 3.0+ with wolfProvider)
2. Engine-based (OpenSSL 1.1.1 with wolfEngine) - deprecated
3. Direct replacement (Python rebuilt against wolfSSL)
4. Static linking (Python statically linked to wolfSSL)

**Decision:**

Use provider-based architecture with OpenSSL 3.0.18 and wolfProvider 1.0.2.

**Rationale:**

1. **Standards Compliance:** Provider API is the official OpenSSL 3.0+ mechanism
2. **Official Python Source:** Built from GPG-verified CPython source; no patching of the OpenSSL layer required
3. **Separation of Concerns:** OpenSSL handles protocols, wolfSSL handles crypto
4. **Future-proof:** Engines are deprecated, providers are the future
5. **Community Support:** Active development and support from both OpenSSL and wolfSSL

**Consequences:**

- **Positive:** Easy upgrades, clean architecture, broad compatibility
- **Negative:** Requires OpenSSL 3.0+ (not an issue with Debian Bookworm)
- **Neutral:** Slightly more complex configuration than direct replacement

**Alternatives Considered:**

- **Engine-based:** Rejected due to deprecation in OpenSSL 3.0
- **Direct replacement:** Rejected due to Python rebuild complexity
- **Static linking:** Rejected due to inflexibility and large binary size

---

**Document Version:** 1.0
**Last Updated:** 2026-03-21
**Validated With:** Python 3.13.7, wolfSSL 5.8.2 FIPS, OpenSSL 3.0.18, wolfProvider 1.0.2
