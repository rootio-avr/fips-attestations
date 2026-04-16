# Nginx wolfSSL FIPS 140-3 - Architecture Documentation

**Version:** 1.0
**Image:** cr.root.io/nginx:1.29.1-debian-bookworm-fips
**Date:** 2024-01-20

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [System Architecture](#system-architecture)
3. [Component Stack](#component-stack)
4. [FIPS Integration Design](#fips-integration-design)
5. [Build Architecture](#build-architecture)
6. [Security Architecture](#security-architecture)
7. [Runtime Architecture](#runtime-architecture)
8. [Network Architecture](#network-architecture)
9. [Data Flow](#data-flow)
10. [Cryptographic Boundaries](#cryptographic-boundaries)
11. [Threat Model](#threat-model)
12. [Design Decisions](#design-decisions)

---

## Executive Summary

This document describes the architecture of the Nginx 1.29.1 FIPS 140-3 container image, which integrates Nginx with wolfSSL's FIPS-validated cryptographic module (Certificate #4718) via the OpenSSL 3.x provider interface.

**Key Architectural Characteristics:**
- **FIPS Module:** wolfSSL v5.8.2 FIPS 140-3 (Certificate #4718)
- **Integration Pattern:** OpenSSL 3.x Provider (wolfProvider v1.1.0)
- **Base Platform:** Debian 12 Bookworm Slim
- **Build Strategy:** Multi-stage Docker with security hardening
- **Cryptographic Boundary:** wolfSSL FIPS module with integrity verification

---

## System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Container Runtime (Docker)                    │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Nginx 1.29.1 Process Layer                  │   │
│  │                                                           │   │
│  │  ┌──────────────┐      ┌──────────────────────────┐    │   │
│  │  │ HTTP Module  │──────│  SSL/TLS Module          │    │   │
│  │  │              │      │  (nginx-mod-http-ssl)    │    │   │
│  │  └──────────────┘      └───────────┬──────────────┘    │   │
│  │                                     │                    │   │
│  └─────────────────────────────────────┼────────────────────┘   │
│                                        │                         │
│  ┌─────────────────────────────────────▼────────────────────┐   │
│  │           OpenSSL 3.0.19 Library Layer                   │   │
│  │                                                           │   │
│  │  ┌──────────────────────────────────────────────────┐   │   │
│  │  │         Provider Interface (OSSL_PROVIDER)       │   │   │
│  │  │                                                   │   │   │
│  │  │  ┌────────────────┐      ┌──────────────────┐  │   │   │
│  │  │  │ Default Provider│      │  wolfProvider    │  │   │   │
│  │  │  │  (disabled)    │      │   v1.1.0         │  │   │   │
│  │  │  └────────────────┘      └────────┬─────────┘  │   │   │
│  │  │                                    │            │   │   │
│  │  └────────────────────────────────────┼────────────┘   │   │
│  │                                       │                │   │
│  └───────────────────────────────────────┼────────────────┘   │
│                                          │                     │
│  ┌───────────────────────────────────────▼────────────────┐   │
│  │      wolfSSL FIPS 140-3 Cryptographic Module          │   │
│  │              (Certificate #4718)                       │   │
│  │                                                         │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐ │   │
│  │  │  TLS 1.2/1.3 │  │  AES-GCM     │  │   ECDHE     │ │   │
│  │  │  Protocols   │  │  Ciphers     │  │   P-256/384 │ │   │
│  │  └──────────────┘  └──────────────┘  └─────────────┘ │   │
│  │                                                         │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐ │   │
│  │  │  SHA-256/384 │  │  RSA 2048+   │  │   HMAC      │ │   │
│  │  │  Hashing     │  │  Signatures  │  │             │ │   │
│  │  └──────────────┘  └──────────────┘  └─────────────┘ │   │
│  │                                                         │   │
│  │  ┌──────────────────────────────────────────────────┐ │   │
│  │  │        Power-On Self Test (POST)                 │ │   │
│  │  │        Continuous Health Checks                  │ │   │
│  │  │        Integrity Verification (HMAC-SHA256)      │ │   │
│  │  └──────────────────────────────────────────────────┘ │   │
│  │                                                         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                 Operating System Layer                   │   │
│  │          Debian 12 Bookworm (Minimal Base)              │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Component Stack

### Layer 1: Application Layer - Nginx 1.29.1

**Purpose:** HTTP/HTTPS web server and reverse proxy

**Key Components:**
- `nginx` binary (compiled with SSL support)
- HTTP modules (core, proxy, static)
- SSL/TLS module (nginx-mod-http-ssl)
- Configuration files (`/etc/nginx/nginx.conf`)

**Responsibilities:**
- HTTP request handling
- TLS handshake initiation
- Certificate management
- Request routing and proxying

**OpenSSL Integration:**
- Calls OpenSSL EVP API for cryptographic operations
- No direct access to wolfSSL (abstracted by provider)
- Uses standard OpenSSL configuration

### Layer 2: Cryptographic API Layer - OpenSSL 3.0.19

**Purpose:** Cryptographic abstraction and provider management

**Key Components:**
- `libssl.so.3` - TLS protocol implementation
- `libcrypto.so.3` - Cryptographic primitives
- Provider interface (OSSL_PROVIDER API)
- Configuration (`/etc/ssl/openssl.cnf`)

**Responsibilities:**
- TLS protocol state machine
- Certificate validation
- Provider loading and dispatching
- Algorithm routing

**Provider Configuration:**
```ini
[openssl_init]
providers = provider_sect

[provider_sect]
wolfssl = wolfssl_sect
default = default_sect

[wolfssl_sect]
activate = 1
module = /usr/lib/x86_64-linux-gnu/ossl-modules/libwolfprov.so

[default_sect]
activate = 0
```

### Layer 3: Provider Layer - wolfProvider 1.1.0

**Purpose:** Bridge OpenSSL 3.x to wolfSSL FIPS module

**Key Components:**
- `libwolfprov.so` - OpenSSL provider shared library
- Algorithm implementations (routing to wolfSSL)
- Property queries and capability reporting

**Responsibilities:**
- Translate OpenSSL EVP calls to wolfSSL API
- Expose wolfSSL algorithms to OpenSSL
- Maintain FIPS boundary integrity
- Report FIPS status and capabilities

**Supported Algorithms:**
- **Ciphers:** AES-128/256-GCM, AES-128/256-CBC
- **Digests:** SHA-256, SHA-384, SHA-512
- **Key Exchange:** ECDHE (P-256, P-384, P-521)
- **Signatures:** RSA-PSS, ECDSA
- **MAC:** HMAC-SHA256, HMAC-SHA384

### Layer 4: FIPS Cryptographic Module - wolfSSL 5.8.2 FIPS

**Purpose:** FIPS 140-3 validated cryptographic operations

**Key Components:**
- `libwolfssl.so.39` - FIPS-validated shared library
- FIPS integrity check file (`.fips-checksum`)
- POST (Power-On Self Test) routines
- Continuous health checks

**Responsibilities:**
- All cryptographic operations (AES, SHA, ECDHE, RSA)
- FIPS self-tests and integrity verification
- Key generation and management
- Random number generation (DRBG)

**FIPS Certificate:**
- **Certificate Number:** #4718
- **Validation Level:** FIPS 140-3
- **Algorithms:** Listed in Security Policy
- **Operational Environment:** Linux x86_64

### Layer 5: Operating System - Debian 12 Bookworm

**Purpose:** Base operating system and runtime

**Key Components:**
- Linux kernel (6.x)
- glibc 2.36
- Minimal system utilities
- CA certificates

**Security Hardening:**
- Minimal package installation
- Non-root user (`nginx:nginx`)
- Read-only root filesystem (where applicable)
- No shell access in runtime image

---

## FIPS Integration Design

### Integration Pattern: OpenSSL Provider Interface

**Why OpenSSL Provider (Not Nginx Patch)?**

Traditional Nginx + wolfSSL integration used source patches (`--enable-nginx` configure flag). This image uses a **different approach**:

```
┌────────────────────────────────────────────────────────────────┐
│                     TRADITIONAL APPROACH                        │
│                     (NOT USED IN THIS IMAGE)                    │
│                                                                  │
│  Nginx ──(source patches)──> wolfSSL                            │
│                                                                  │
│  Pros: Direct integration                                       │
│  Cons: Requires Nginx source modification                       │
│        Complex maintenance across Nginx versions                │
│        Tight coupling                                           │
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│                       MODERN APPROACH                           │
│                   (USED IN THIS IMAGE)                          │
│                                                                  │
│  Nginx ──(OpenSSL API)──> OpenSSL 3.x ──(Provider)──> wolfSSL │
│                                                                  │
│  Pros: No Nginx source modification needed                      │
│        Standard OpenSSL 3.x interface                           │
│        Easier maintenance and upgrades                          │
│        Transparent to Nginx                                     │
│  Cons: Additional layer (minimal overhead)                      │
└────────────────────────────────────────────────────────────────┘
```

**Key Benefits:**
1. **No Nginx Patches:** Standard Nginx binary works unmodified
2. **OpenSSL Compatibility:** Applications see standard OpenSSL API
3. **Provider Abstraction:** Swap FIPS modules without app changes
4. **Simpler Maintenance:** Nginx upgrades don't require re-patching

### FIPS Boundary

The **cryptographic boundary** is the wolfSSL FIPS module:

```
┌─────────────────────────────────────────────────────────────────┐
│                       OUTSIDE FIPS BOUNDARY                      │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Nginx Process                                          │   │
│  │  - Accepts TLS connections                             │   │
│  │  - Calls OpenSSL EVP_* functions                       │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  OpenSSL 3.0.19                                         │   │
│  │  - TLS protocol state machine                          │   │
│  │  - Dispatches to provider                              │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  wolfProvider 1.1.0                                     │   │
│  │  - Translates calls to wolfSSL API                     │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                   │
├═══════════════════════════════════════════════════════════════════┤
│                     ╔═════════════════════════════╗              │
│                     ║   FIPS BOUNDARY START       ║              │
│                     ╚═════════════════════════════╝              │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  wolfSSL FIPS Module v5.8.2 (Certificate #4718)        │   │
│  │                                                         │   │
│  │  • AES encryption/decryption                           │   │
│  │  • SHA hashing                                         │   │
│  │  • ECDHE key agreement                                 │   │
│  │  • RSA signatures                                      │   │
│  │  • HMAC                                                │   │
│  │  • DRBG (random number generation)                    │   │
│  │  • Power-On Self Test (POST)                          │   │
│  │  • Integrity verification                             │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                   │
│                     ╔═════════════════════════════╗              │
│                     ║    FIPS BOUNDARY END        ║              │
│                     ╚═════════════════════════════╝              │
└─────────────────────────────────────────────────────────────────┘
```

**Data Entering Boundary:**
- Plaintext data to encrypt
- Ciphertext to decrypt
- Data to hash
- Keys for cryptographic operations

**Data Leaving Boundary:**
- Encrypted ciphertext
- Decrypted plaintext
- Hash digests
- Signatures

**Integrity Protection:**
- HMAC-SHA256 checksum of module binary
- Verified on every module load
- Failure causes module load rejection

---

## Build Architecture

### Multi-Stage Build Strategy

The image uses a **two-stage build** to minimize attack surface:

```
┌────────────────────────────────────────────────────────────────┐
│                         STAGE 1: BUILDER                        │
│                    (Discarded after build)                      │
│                                                                  │
│  Base: debian:bookworm (full development image)                 │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  1. Install build dependencies                           │  │
│  │     - gcc, g++, make, autoconf, libtool                 │  │
│  │     - Build tools for compilation                       │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  2. Build wolfSSL FIPS 5.8.2                            │  │
│  │     - Configure with --enable-fips=v5-dev              │  │
│  │     - Compile FIPS module                              │  │
│  │     - Generate integrity checksum                       │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  3. Build wolfProvider 1.1.0                            │  │
│  │     - Configure with wolfSSL support                    │  │
│  │     - Build OpenSSL 3.x provider module                │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  4. Build OpenSSL 3.0.19                                │  │
│  │     - Configure for provider support                    │  │
│  │     - Install to /opt/openssl                          │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  5. Build Nginx 1.29.1                                  │  │
│  │     - Configure with --with-http_ssl_module            │  │
│  │     - Link against OpenSSL 3.0.19                      │  │
│  │     - NO wolfSSL patches needed                        │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  Output: Compiled binaries ready for runtime stage              │
└────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────────┐
│                       STAGE 2: RUNTIME                          │
│                  (Final production image)                       │
│                                                                  │
│  Base: debian:bookworm-slim (minimal runtime)                   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  1. Copy binaries from builder:                         │  │
│  │     - /usr/local/nginx (Nginx binary)                   │  │
│  │     - /opt/openssl (OpenSSL libraries)                  │  │
│  │     - /usr/local/lib/libwolfssl.so.39                  │  │
│  │     - /usr/lib/.../ossl-modules/libwolfprov.so         │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  2. Install minimal runtime dependencies only:          │  │
│  │     - ca-certificates                                   │  │
│  │     - libc6 (already present)                          │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  3. Security hardening:                                 │  │
│  │     - Create nginx user (non-root)                     │  │
│  │     - Set minimal file permissions                      │  │
│  │     - Remove unnecessary packages                       │  │
│  │     - Clear package cache                              │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  4. Configuration:                                      │  │
│  │     - OpenSSL config with wolfProvider                  │  │
│  │     - Nginx config template                            │  │
│  │     - SSL certificates (self-signed for demo)          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  Final Image Size: ~150-200 MB (vs ~1GB with build tools)      │
└────────────────────────────────────────────────────────────────┘
```

**Build-time Security:**
- Verify source checksums (SHA256)
- Build from official source tarballs
- No network access during build (after downloads)

**Runtime Security:**
- No compilers or build tools in final image
- Minimal attack surface
- Only production dependencies included

---

## Security Architecture

### Defense in Depth

```
┌────────────────────────────────────────────────────────────────┐
│  Layer 1: Container Isolation                                   │
│  - User namespace isolation                                     │
│  - Network namespace isolation                                  │
│  - Capability dropping (CAP_NET_BIND_SERVICE only)             │
└────────────────────────────────────────────────────────────────┘
┌────────────────────────────────────────────────────────────────┐
│  Layer 2: Process Isolation                                     │
│  - Non-root user (nginx:nginx)                                 │
│  - Minimal file permissions                                     │
│  - No shell in production image                                │
└────────────────────────────────────────────────────────────────┘
┌────────────────────────────────────────────────────────────────┐
│  Layer 3: Cryptographic Security                               │
│  - FIPS 140-3 validated cryptography                           │
│  - TLS 1.2+ only (no SSLv3, TLS 1.0/1.1)                      │
│  - FIPS-approved ciphers only                                  │
│  - Perfect Forward Secrecy (ECDHE)                             │
└────────────────────────────────────────────────────────────────┘
┌────────────────────────────────────────────────────────────────┐
│  Layer 4: Application Security                                 │
│  - Nginx security headers                                      │
│  - Request validation                                          │
│  - Rate limiting (configurable)                                │
└────────────────────────────────────────────────────────────────┘
┌────────────────────────────────────────────────────────────────┐
│  Layer 5: Supply Chain Security                                │
│  - Source verification (checksums)                             │
│  - SBOM generation                                             │
│  - Vulnerability scanning (VEX)                                │
│  - SLSA provenance                                             │
└────────────────────────────────────────────────────────────────┘
```

### FIPS Compliance Controls

**1. Integrity Verification**
```bash
# At container start:
1. Load wolfSSL FIPS module
2. Module verifies own HMAC-SHA256 checksum
3. If checksum fails → module load rejected → container fails
4. If checksum passes → POST runs → module activates
```

**2. Power-On Self Test (POST)**
```
Startup sequence:
├─ Load wolfSSL FIPS module
├─ Integrity check (HMAC-SHA256)
├─ Power-On Self Test:
│  ├─ AES Known Answer Tests (KAT)
│  ├─ SHA Known Answer Tests
│  ├─ ECDHE KAT
│  ├─ RSA KAT
│  ├─ HMAC KAT
│  └─ DRBG health checks
├─ POST Success → Module ready
└─ POST Failure → Module load fails
```

**3. Algorithm Enforcement**

Only FIPS-approved algorithms are available:
- **Ciphers:** AES-GCM only (no RC4, DES, 3DES)
- **Hashing:** SHA-256, SHA-384, SHA-512 (no MD5, SHA-1)
- **Key Exchange:** ECDHE P-256/384 (no DH)
- **Protocols:** TLS 1.2, TLS 1.3 (no SSLv3, TLS 1.0/1.1)

---

## Runtime Architecture

### Process Model

```
Container Startup:
┌─────────────────────────────────────────────────────────────┐
│  1. ENTRYPOINT: /docker-entrypoint.sh                       │
│     - Validates OpenSSL configuration                       │
│     - Runs FIPS startup check (fips-startup-check)         │
│     - Verifies wolfProvider is loaded                       │
│     - Validates POST completed successfully                 │
└─────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  2. Nginx Master Process (PID 1)                            │
│     - User: root (needed for privileged ports)              │
│     - Reads /etc/nginx/nginx.conf                          │
│     - Spawns worker processes                              │
└─────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  3. Nginx Worker Processes (multiple)                       │
│     - User: nginx (dropped privileges)                      │
│     - Handle client connections                            │
│     - Perform TLS handshakes via OpenSSL/wolfSSL           │
└─────────────────────────────────────────────────────────────┘
```

### Shared Libraries

```
$ ldd /usr/local/nginx/sbin/nginx
linux-vdso.so.1
libcrypto.so.3 => /opt/openssl/lib64/libcrypto.so.3
libssl.so.3 => /opt/openssl/lib64/libssl.so.3
libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6
libwolfssl.so.39 => /usr/local/lib/libwolfssl.so.39
ld-linux-x86-64.so.2
```

**Library Loading Order:**
1. Nginx loads `libssl.so.3` (OpenSSL)
2. OpenSSL reads `/etc/ssl/openssl.cnf`
3. Config activates wolfProvider
4. wolfProvider loads `libwolfprov.so`
5. wolfProvider links `libwolfssl.so.39`
6. wolfSSL runs FIPS POST

---

## Network Architecture

### TLS Handshake Flow

```
Client                    Nginx                OpenSSL              wolfSSL
  │                         │                      │                   │
  ├─ ClientHello ──────────>│                      │                   │
  │                         │                      │                   │
  │                         ├─ SSL_accept() ──────>│                   │
  │                         │                      │                   │
  │                         │                      ├─ ECDHE_compute ──>│
  │                         │                      │                   │
  │                         │                      │<─ shared_secret ──┤
  │                         │                      │                   │
  │                         │                      ├─ AES_GCM_init ───>│
  │                         │                      │                   │
  │<─ ServerHello ──────────┤<─ handshake_msg ────┤                   │
  │   Certificate           │                      │                   │
  │   ServerKeyExchange     │                      │                   │
  │   ServerHelloDone       │                      │                   │
  │                         │                      │                   │
  ├─ ClientKeyExchange ────>│                      │                   │
  │   ChangeCipherSpec      ├──────────────────────>│                   │
  │   Finished              │                      │                   │
  │                         │                      ├─ AES_GCM_decrypt─>│
  │                         │                      │<─ plaintext ──────┤
  │                         │                      │                   │
  │<─ ChangeCipherSpec ─────┤                      │                   │
  │   Finished              │                      │                   │
  │                         │                      │                   │
  ├─ HTTP Request (enc) ───>│                      │                   │
  │                         ├──────────────────────>├─ AES_GCM_decrypt─>│
  │                         │                      │<─ plaintext ──────┤
  │                         │                      │                   │
  │                         │  [Process request]   │                   │
  │                         │                      │                   │
  │<─ HTTP Response (enc) ──┤                      ├─ AES_GCM_encrypt─>│
  │                         │<─────────────────────┤<─ ciphertext ─────┤
  │                         │                      │                   │
```

**All cryptographic operations occur in wolfSSL FIPS boundary**

---

## Data Flow

### Configuration Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│  1. Container Start                                          │
└─────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  2. Read /etc/ssl/openssl.cnf                               │
│     - Identifies wolfProvider location                       │
│     - Sets provider activation flags                        │
└─────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  3. OpenSSL loads /usr/lib/.../libwolfprov.so               │
│     - Provider initialization                               │
│     - Algorithm registration                                │
└─────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  4. wolfProvider loads libwolfssl.so.39                     │
│     - FIPS integrity check (HMAC-SHA256)                    │
│     - Power-On Self Test (POST)                            │
│     - Algorithm setup                                       │
└─────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  5. Nginx reads /etc/nginx/nginx.conf                       │
│     - SSL protocols: TLSv1.2 TLSv1.3                       │
│     - SSL ciphers: ECDHE-*-AES*-GCM-SHA*                   │
│     - SSL certificates                                      │
└─────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  6. Nginx Ready - Accepting TLS Connections                 │
└─────────────────────────────────────────────────────────────┘
```

### Request Processing Data Flow

```
TLS Request Flow:
┌─────────────────────────────────────────────────────────────┐
│  1. Client TCP connection → Nginx :443                      │
└─────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  2. Nginx calls SSL_accept() → OpenSSL                      │
└─────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  3. OpenSSL dispatches to wolfProvider                       │
│     - Cipher negotiation                                    │
│     - Key exchange (ECDHE via wolfSSL)                     │
└─────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  4. wolfSSL FIPS performs cryptographic operations           │
│     - ECDHE key agreement (P-256/384)                       │
│     - Certificate signature verification (RSA/ECDSA)        │
│     - Session key derivation (HMAC-SHA256)                 │
└─────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  5. TLS handshake complete → Encrypted channel established  │
└─────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  6. Application data encrypted/decrypted via wolfSSL         │
│     - AES-256-GCM encryption/decryption                     │
│     - HMAC-SHA384 for integrity                            │
└─────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  7. Nginx processes HTTP request (plaintext internally)     │
│     - Proxy to backend, or serve static files              │
└─────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  8. Response encrypted and sent to client                   │
└─────────────────────────────────────────────────────────────┘
```

---

## Cryptographic Boundaries

### FIPS Module Boundary Definition

```
┌═══════════════════════════════════════════════════════════════┐
║                     FIPS CRYPTOGRAPHIC BOUNDARY               ║
║                                                                ║
║  File: /usr/local/lib/libwolfssl.so.39                       ║
║  Checksum File: /usr/local/lib/.libs/libwolfssl.so.39.fips   ║
║  Verification: HMAC-SHA256                                    ║
║                                                                ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │  Approved Algorithms (FIPS 140-3)                       │ ║
║  │                                                         │ ║
║  │  • AES (128, 256) - ECB, CBC, GCM modes                │ ║
║  │  • SHA-256, SHA-384, SHA-512                           │ ║
║  │  • HMAC-SHA-256, HMAC-SHA-384                          │ ║
║  │  • RSA (2048, 3072, 4096) - signature, encryption      │ ║
║  │  • ECDSA (P-256, P-384, P-521)                         │ ║
║  │  • ECDH/ECDHE (P-256, P-384, P-521)                    │ ║
║  │  • DRBG (Hash_DRBG, HMAC_DRBG)                         │ ║
║  │  • KDF (TLS 1.2 PRF, HKDF)                             │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                                ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │  Self-Tests (Executed at module load)                   │ ║
║  │                                                         │ ║
║  │  1. Integrity Test: HMAC-SHA256 of module binary       │ ║
║  │  2. Known Answer Tests (KAT) for all algorithms        │ ║
║  │  3. Pairwise Consistency Tests for key generation      │ ║
║  │  4. Continuous Random Number Generator Test            │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                                ║
╚═══════════════════════════════════════════════════════════════╝
```

### Data Crossing Boundary

**Input (Entering FIPS Boundary):**
- Plaintext to encrypt
- Ciphertext to decrypt
- Data to hash/HMAC
- Private keys for signing
- Public keys for verification
- Entropy for DRBG

**Output (Leaving FIPS Boundary):**
- Encrypted ciphertext
- Decrypted plaintext
- Hash digests
- HMAC tags
- Digital signatures
- Random bytes

**Control Interface:**
- Algorithm parameters (key size, mode)
- Operation commands (encrypt, decrypt, sign)
- Status queries (POST status, provider info)

---

## Threat Model

### Assets Protected

1. **TLS Session Keys** (AES keys, HMAC keys)
2. **Server Private Keys** (RSA/ECDSA)
3. **Client Data in Transit** (encrypted HTTP)
4. **FIPS Module Integrity** (binary checksum)

### Threats and Mitigations

| Threat | Mitigation | Component |
|--------|-----------|-----------|
| **Weak Cryptography** | FIPS-approved algorithms only | wolfSSL FIPS |
| **Downgrade Attack** | TLS 1.2+ only, strong ciphers | Nginx Config |
| **Module Tampering** | HMAC-SHA256 integrity check | wolfSSL POST |
| **Side-Channel Attack** | FIPS-validated implementation | wolfSSL FIPS |
| **Key Compromise** | Perfect Forward Secrecy (ECDHE) | TLS Protocol |
| **Container Escape** | Minimal privileges, namespaces | Docker |
| **Supply Chain Attack** | Source verification, SBOM | Build Process |
| **Vulnerable Dependencies** | Minimal base, VEX scanning | Debian Slim |

### Compliance Boundaries

```
┌──────────────────────────────────────────────────────────────┐
│  Compliance Scope: FIPS 140-3 Certificate #4718              │
│                                                               │
│  IN SCOPE (FIPS-validated):                                  │
│  ✓ wolfSSL cryptographic module                              │
│  ✓ All cryptographic operations (AES, SHA, ECDHE, RSA)       │
│  ✓ Key generation, derivation                                │
│  ✓ Random number generation (DRBG)                           │
│                                                               │
│  OUT OF SCOPE (not FIPS-validated):                          │
│  ✗ Nginx application logic                                   │
│  ✗ OpenSSL library (non-cryptographic parts)                 │
│  ✗ wolfProvider (shim layer)                                 │
│  ✗ Operating system                                          │
│  ✗ Network stack                                             │
│                                                               │
│  FIPS Mode: Mandatory (module always operates in FIPS mode)  │
└──────────────────────────────────────────────────────────────┘
```

---

## Design Decisions

### Decision 1: wolfProvider vs Nginx Patches

**Decision:** Use OpenSSL 3.x provider interface instead of Nginx source patches

**Rationale:**
- Nginx requires no source modification
- Standard OpenSSL API compatibility
- Easier to maintain across Nginx versions
- Industry-standard provider pattern

**Trade-offs:**
- Additional abstraction layer (wolfProvider)
- Slightly more complex configuration

**Outcome:** Simplified maintenance, better long-term supportability

---

### Decision 2: Multi-Stage Build

**Decision:** Use multi-stage Docker build (builder + runtime)

**Rationale:**
- Minimize attack surface (no build tools in production)
- Reduce image size (~1GB → ~200MB)
- Faster deployment and pulls

**Trade-offs:**
- Slightly more complex Dockerfile
- Longer initial build time

**Outcome:** Significantly improved security and efficiency

---

### Decision 3: Debian Bookworm Base

**Decision:** Use Debian 12 Bookworm Slim instead of Alpine or Ubuntu

**Rationale:**
- Stable, well-tested base
- glibc compatibility (required by wolfSSL FIPS)
- Long-term support (5 years)
- Familiar tooling

**Trade-offs:**
- Larger base image than Alpine (~50MB vs ~5MB)

**Outcome:** Better compatibility and stability for FIPS workloads

---

### Decision 4: Self-Signed Certificates for Demos

**Decision:** Include self-signed certificates in demo images

**Rationale:**
- Immediate usability for testing
- No external dependencies
- Clear documentation for production replacement

**Trade-offs:**
- Users must replace for production
- Browser warnings in testing

**Outcome:** Easy testing, clear upgrade path

---

### Decision 5: TLS 1.2 + TLS 1.3 Default

**Decision:** Support both TLS 1.2 and TLS 1.3 by default (strict mode: TLS 1.3 only)

**Rationale:**
- TLS 1.2 still widely used (compatibility)
- TLS 1.3 offers better security and performance
- FIPS 140-3 approves both

**Trade-offs:**
- TLS 1.2 less secure than TLS 1.3 (but still FIPS-approved)

**Outcome:** Balanced security and compatibility

---

## Appendix A: Version Matrix

| Component | Version | Role | FIPS Status |
|-----------|---------|------|-------------|
| Nginx | 1.29.1 | Web server | Not validated |
| OpenSSL | 3.0.19 | Crypto API | Not validated |
| wolfProvider | 1.1.0 | Provider shim | Not validated |
| wolfSSL FIPS | 5.8.2 | Crypto module | **Certificate #4718** |
| Debian | 12 Bookworm | OS base | Not validated |

---

## Appendix B: File Locations

```
/
├── etc/
│   ├── nginx/
│   │   ├── nginx.conf              # Main Nginx config
│   │   └── ssl/
│   │       ├── self-signed.crt     # Demo certificate
│   │       └── self-signed.key     # Demo private key
│   └── ssl/
│       └── openssl.cnf             # OpenSSL config (wolfProvider activation)
├── opt/
│   └── openssl/
│       ├── bin/openssl             # OpenSSL 3.0.19 binary
│       └── lib64/
│           ├── libssl.so.3         # OpenSSL SSL library
│           └── libcrypto.so.3      # OpenSSL crypto library
├── usr/
│   ├── lib/x86_64-linux-gnu/
│   │   └── ossl-modules/
│   │       └── libwolfprov.so      # wolfProvider module
│   ├── local/
│   │   ├── nginx/
│   │   │   └── sbin/nginx          # Nginx binary
│   │   └── lib/
│   │       ├── libwolfssl.so.39    # wolfSSL FIPS library
│   │       └── .libs/
│   │           └── libwolfssl.so.39.fips  # FIPS checksum file
│   └── share/
│       └── nginx/
│           └── html/               # Default web root
└── docker-entrypoint.sh            # Container startup script
```

---

## Appendix C: References

- [NIST FIPS 140-3 Standard](https://csrc.nist.gov/publications/detail/fips/140/3/final)
- [wolfSSL FIPS Certificate #4718](https://csrc.nist.gov/projects/cryptographic-module-validation-program/certificate/4718)
- [OpenSSL Provider Documentation](https://www.openssl.org/docs/man3.0/man7/provider.html)
- [Nginx SSL Module Documentation](https://nginx.org/en/docs/http/ngx_http_ssl_module.html)
- [wolfSSL FIPS Documentation](https://www.wolfssl.com/documentation/manuals/wolfssl/chapter10.html)

---

**Document Version:** 1.0
**Last Updated:** 2024-01-20
**Maintained By:** Root FIPS Team
