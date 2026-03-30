# FIPS 140-3 Compliance Attestation

## Redis Exporter v1.67.0 - Ubuntu 22.04 (Jammy) FIPS Image

**Document Version:** 1.0
**Date:** 2026-03-27
**Image:** `cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips`
**Maintainer:** Root FIPS Team

---

## Executive Summary

This document provides formal attestation that the Redis Exporter v1.67.0 FIPS image implements FIPS 140-3 compliant cryptographic operations through the integration of NIST-validated cryptographic modules.

**Attestation Statement:**

> The `redis-exporter:1.67.0-jammy-ubuntu-22.04-fips` container image implements FIPS 140-3 compliant cryptography exclusively through the use of wolfSSL FIPS Module v5.8.2 (CMVP Certificate #4718) and golang-fips/go v1.25, with runtime enforcement mechanisms preventing the use of non-approved cryptographic algorithms.

---

## Table of Contents

1. [FIPS Compliance Components](#fips-compliance-components)
2. [Cryptographic Module Validation](#cryptographic-module-validation)
3. [Implementation Architecture](#implementation-architecture)
4. [Enforcement Mechanisms](#enforcement-mechanisms)
5. [Approved Security Functions](#approved-security-functions)
6. [Non-Approved Security Functions](#non-approved-security-functions)
7. [Operational Environment](#operational-environment)
8. [Security Policy](#security-policy)
9. [Testing and Validation](#testing-and-validation)
10. [Compliance Maintenance](#compliance-maintenance)
11. [Attestation Signatures](#attestation-signatures)

---

## 1. FIPS Compliance Components

### 1.1 Primary Cryptographic Module

**wolfSSL FIPS Module v5.8.2**
- **CMVP Certificate Number:** #4718
- **Validation Date:** 2024
- **Standard:** FIPS 140-3
- **Security Level:** Level 1
- **Embodiment:** Software
- **Description:** FIPS 140-3 validated cryptographic module providing approved algorithms

**Certificate Details:**
- Validation Authority: NIST CMVP
- Validation Status: Active
- Operating Environment: General Purpose Operating System
- Applicable Security Policies: wolfSSL FIPS Security Policy Version 5.8.2

### 1.2 Go FIPS Integration

**golang-fips/go v1.25**
- **Source:** https://github.com/golang-fips/go
- **Base:** Go 1.25
- **Modifications:** Cryptographic operations routed through OpenSSL/wolfSSL
- **FIPS Mode:** Enforced via GODEBUG=fips140=only
- **Validation:** Inherits validation from underlying wolfSSL FIPS module

### 1.3 OpenSSL Provider Architecture

**wolfProvider v1.1.0**
- **Purpose:** OpenSSL 3.x provider bridging to wolfSSL FIPS
- **Source:** https://github.com/wolfSSL/wolfProvider
- **Version:** 1.1.0
- **Integration:** Registered as OpenSSL provider for FIPS operations
- **Configuration:** `/etc/ssl/openssl-wolfprov.cnf`

### 1.4 Base Operating System

**Ubuntu 22.04 LTS (Jammy Jellyfish)**
- **Kernel:** Linux 5.15+
- **Libc:** glibc 2.35
- **Role:** General Purpose Operating System per FIPS 140-3 requirements
- **Hardening:** Minimal attack surface, non-root execution

---

## 2. Cryptographic Module Validation

### 2.1 CMVP Certificate #4718 Details

**Algorithm Validation Certificates (Sample):**

| Algorithm | Certificate | Details |
|-----------|------------|---------|
| AES | CAVP Cert | AES-128, AES-192, AES-256 (ECB, CBC, CTR, GCM) |
| SHA | CAVP Cert | SHA-256, SHA-384, SHA-512 |
| HMAC | CAVP Cert | HMAC-SHA256, HMAC-SHA384, HMAC-SHA512 |
| RSA | CAVP Cert | RSA 2048, 3072, 4096 (PKCS#1 v1.5, PSS) |
| ECDSA | CAVP Cert | P-256, P-384, P-521 |
| DRBG | CAVP Cert | Hash_DRBG, HMAC_DRBG, CTR_DRBG |
| KDF | CAVP Cert | TLS 1.2/1.3 KDF, HKDF |

### 2.2 Power-On Self-Tests (POST)

The wolfSSL FIPS module executes comprehensive POST on initialization:

**Known Answer Tests (KAT):**
- AES Encrypt/Decrypt KAT
- SHA-256/384/512 KAT
- HMAC KAT
- RSA Sign/Verify KAT
- ECDSA Sign/Verify KAT
- DRBG KAT

**Continuous Random Number Generator Tests:**
- DRBG Health Tests
- Entropy Source Tests

**Integrity Tests:**
- HMAC-SHA256 integrity verification of module binary
- Digital signature verification (if applicable)

**POST Execution:**
```c
// Executed in test-fips.c during container startup
int ret = wolfCrypt_GetStatus_fips();
if (ret == 0) {
    // POST passed - module operational
} else {
    // POST failed - module enters error state
}
```

### 2.3 Module Boundaries

**Physical Boundary:**
- Software module contained within process memory space
- Loaded as shared library: `libwolfssl.so.42.1.0`
- Location: `/usr/local/lib/libwolfssl.so.42.1.0`

**Logical Boundary:**
- API functions exported by wolfSSL FIPS module
- Entry points protected by module integrity checks
- No bypass mechanisms present

**Data Flows:**
```
Application → wolfSSL FIPS API → Approved Algorithm Implementation → Hardware
     ↑                                                                    ↓
     └─────────────────────── Cryptographic Output ───────────────────────┘
```

---

## 3. Implementation Architecture

### 3.1 Cryptographic Stack

```
┌─────────────────────────────────────────────────────────┐
│ Redis Exporter Application (Go)                         │
├─────────────────────────────────────────────────────────┤
│ golang-fips/go v1.25                                    │
│ - crypto/tls (FIPS mode)                                │
│ - crypto/sha256, crypto/sha512 (FIPS mode)              │
│ - crypto/rand (FIPS DRBG)                               │
├─────────────────────────────────────────────────────────┤
│ OpenSSL 3.0.19 (API Layer)                              │
├─────────────────────────────────────────────────────────┤
│ wolfProvider v1.1.0 (OpenSSL Provider)                  │
├─────────────────────────────────────────────────────────┤
│ wolfSSL FIPS v5.8.2 (CMVP #4718) ← VALIDATED MODULE    │
├─────────────────────────────────────────────────────────┤
│ Ubuntu 22.04 LTS (General Purpose OS)                   │
└─────────────────────────────────────────────────────────┘
```

### 3.2 Build Process FIPS Compliance

**Stage 1: wolfSSL FIPS Build**
```bash
# Configuration ensures FIPS-only operation
./configure \
    --enable-fips=v5 \
    --enable-aesni \
    --enable-sha \
    --disable-sha \       # Disables SHA-1
    --disable-md5 \       # Disables MD5
    --disable-oldtls      # Disables TLS < 1.2
```

**Stage 2: wolfProvider Build**
```bash
# Links against FIPS-validated wolfSSL
./configure --with-wolfssl=/usr/local \
            --with-openssl=/usr/local
```

**Stage 3: golang-fips Build**
```bash
# FIPS-enabled Go build
export GOLANG_FIPS=1
export GOEXPERIMENT=strictfipsruntime
```

**Stage 4: Runtime Image**
- Only validated modules present
- System OpenSSL removed
- FIPS enforcement at container startup

### 3.3 Data Flow for Redis Connections

**TLS Connection Establishment (FIPS-compliant):**

```
1. redis_exporter initiates TLS connection
   ↓
2. Go crypto/tls (FIPS mode) calls OpenSSL
   ↓
3. OpenSSL 3.x routes to wolfProvider
   ↓
4. wolfProvider invokes wolfSSL FIPS module
   ↓
5. wolfSSL FIPS performs:
   - TLS handshake (TLS 1.2/1.3 only)
   - Certificate validation (RSA-2048+, ECDSA P-256+)
   - Key exchange (ECDHE, DHE with approved parameters)
   - Cipher suite negotiation (AES-GCM only)
   - MAC (HMAC-SHA256/384)
   ↓
6. Secure channel established using FIPS-approved crypto
```

---

## 4. Enforcement Mechanisms

### 4.1 Build-Time Enforcement

**1. Algorithm Exclusion**
- Non-approved algorithms excluded from build
- `--disable-sha` prevents SHA-1 compilation
- `--disable-md5` prevents MD5 compilation
- `--disable-oldtls` prevents TLS 1.0/1.1

**2. Dependency Verification**
```bash
# Only wolfSSL FIPS library linked
ldd /usr/local/bin/redis_exporter
# Shows: libwolfssl.so.42 → /usr/local/lib/libwolfssl.so.42.1.0
# No system OpenSSL libraries present
```

### 4.2 Runtime Enforcement

**1. Environment Variables**
```bash
GOLANG_FIPS=1                    # Enables Go FIPS mode
GODEBUG=fips140=only             # Enforces FIPS-only operation
GOEXPERIMENT=strictfipsruntime   # Strict FIPS runtime checks
```

**2. Startup Validation**
```bash
# docker-entrypoint.sh performs:
- FIPS POST execution (/usr/local/bin/fips-check)
- Environment variable validation
- wolfProvider registration check
- Algorithm availability verification
- Non-approved algorithm blocking verification
```

**3. OpenSSL Configuration**
```ini
# /etc/ssl/openssl-wolfprov.cnf
[provider_sect]
fips = fips_sect           # FIPS provider activated
default = default_sect     # Default provider NOT activated

[fips_sect]
activate = 1
module = /usr/lib/x86_64-linux-gnu/ossl-modules/libwolfprov.so
```

**4. Runtime Algorithm Checks**
```bash
# Approved: SHA-256
echo "test" | openssl dgst -sha256  # ✓ Works

# Non-approved: MD5
echo "test" | openssl dgst -md5     # ✗ Error: disabled
```

### 4.3 Container Isolation

**Security Boundaries:**
- Non-root user execution (UID 10001)
- Read-only root filesystem (optional)
- Minimal capabilities
- No setuid binaries
- Network namespace isolation

---

## 5. Approved Security Functions

### 5.1 Symmetric Encryption

| Algorithm | Key Sizes | Modes | Usage |
|-----------|-----------|-------|-------|
| AES | 128, 192, 256 bits | CBC, CTR, GCM | TLS encryption, data encryption |

**Implementation:** wolfCrypt AES module (FIPS-validated)

### 5.2 Hashing

| Algorithm | Output Size | Usage |
|-----------|-------------|-------|
| SHA-256 | 256 bits | Certificate signatures, HMAC, TLS PRF |
| SHA-384 | 384 bits | Certificate signatures, HMAC, TLS PRF |
| SHA-512 | 512 bits | Certificate signatures, HMAC, integrity |

**Implementation:** wolfCrypt Hash module (FIPS-validated)

### 5.3 Message Authentication

| Algorithm | Key Sizes | Usage |
|-----------|-----------|-------|
| HMAC-SHA256 | ≥112 bits | TLS MAC, integrity protection |
| HMAC-SHA384 | ≥112 bits | TLS MAC, integrity protection |

**Implementation:** wolfCrypt HMAC module (FIPS-validated)

### 5.4 Digital Signatures

| Algorithm | Key Sizes | Padding | Usage |
|-----------|-----------|---------|-------|
| RSA | 2048, 3072, 4096 bits | PKCS#1 v1.5, PSS | Certificate signatures, TLS |
| ECDSA | P-256, P-384, P-521 | - | Certificate signatures, TLS |

**Implementation:** wolfCrypt RSA and ECC modules (FIPS-validated)

### 5.5 Key Agreement

| Algorithm | Parameters | Usage |
|-----------|------------|-------|
| ECDHE | P-256, P-384, P-521 | TLS key exchange |
| DHE | ≥2048 bits | TLS key exchange (legacy) |

**Implementation:** wolfCrypt ECC and DH modules (FIPS-validated)

### 5.6 Random Number Generation

| DRBG Type | Security Strength | Usage |
|-----------|-------------------|-------|
| Hash_DRBG (SHA-256) | 256 bits | General random number generation |
| HMAC_DRBG (SHA-256) | 256 bits | Key generation, nonces |
| CTR_DRBG (AES-256) | 256 bits | High-performance RNG |

**Implementation:** wolfCrypt DRBG module (FIPS-validated)
**Entropy Source:** `/dev/urandom` (seeded by kernel)

### 5.7 Key Derivation

| Function | Usage |
|----------|-------|
| TLS 1.2 PRF | TLS 1.2 key derivation |
| TLS 1.3 HKDF | TLS 1.3 key derivation |
| HKDF-SHA256/384 | General key derivation |

**Implementation:** wolfCrypt KDF module (FIPS-validated)

---

## 6. Non-Approved Security Functions

### 6.1 Blocked Algorithms

The following non-approved algorithms are **BLOCKED** at build time and runtime:

| Algorithm | Status | Enforcement Method |
|-----------|--------|-------------------|
| MD5 | ❌ BLOCKED | Build-time exclusion, runtime error |
| SHA-1 | ❌ BLOCKED | Build-time exclusion, runtime error |
| RC4 | ❌ BLOCKED | Not compiled |
| DES/3DES | ❌ BLOCKED | Not compiled |
| TLS 1.0 | ❌ BLOCKED | Protocol version restriction |
| TLS 1.1 | ❌ BLOCKED | Protocol version restriction |
| RSA < 2048 | ❌ BLOCKED | Parameter validation |
| DH < 2048 | ❌ BLOCKED | Parameter validation |

**Verification:**
```bash
# These commands return errors in FIPS mode:
echo "test" | openssl dgst -md5    # Error: md5 is not a known digest
echo "test" | openssl dgst -sha1   # Error: disabled
openssl enc -rc4 -help             # Error: unknown cipher
```

### 6.2 Non-FIPS Cipher Suites Blocked

**Prohibited TLS Cipher Suites:**
- All cipher suites using non-approved algorithms
- All cipher suites with key sizes below FIPS minimums
- All non-authenticated encryption cipher suites

**Examples:**
- `TLS_RSA_WITH_RC4_128_SHA` (RC4)
- `TLS_RSA_WITH_3DES_EDE_CBC_SHA` (3DES)
- `TLS_RSA_WITH_AES_128_CBC_SHA` (SHA-1 MAC)
- `TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA` (SHA-1 MAC)

---

## 7. Operational Environment

### 7.1 Approved Mode of Operation

**FIPS Mode:** Always enabled, cannot be disabled

**Configuration:**
```bash
# Environment variables (mandatory)
export GOLANG_FIPS=1
export GODEBUG=fips140=only
export GOEXPERIMENT=strictfipsruntime

# OpenSSL configuration
export OPENSSL_CONF=/etc/ssl/openssl-wolfprov.cnf

# Verification
/usr/local/bin/fips-check  # Must return 0 (success)
```

### 7.2 System Requirements

**Operating System:**
- Ubuntu 22.04 LTS or compatible
- Linux kernel 5.15+
- glibc 2.35+

**Hardware:**
- x86_64 (amd64) architecture
- AES-NI support (recommended)
- Minimum 512MB RAM
- 200MB disk space

**Container Runtime:**
- Docker 20.10+
- containerd 1.6+
- Kubernetes 1.24+ (optional)

### 7.3 Deployment Considerations

**Approved Configurations:**
1. Standalone container (Docker)
2. Kubernetes Pod
3. Docker Compose stack
4. Systemd service with container

**Network Security:**
- TLS 1.2/1.3 for Redis connections (required for encryption)
- HTTPS for metrics endpoint (optional, recommended)
- Firewall rules restricting port 9121 access

---

## 8. Security Policy

### 8.1 Cryptographic Officer Role

**Responsibilities:**
- Deploy FIPS-compliant image
- Verify FIPS POST execution
- Monitor FIPS mode status
- Respond to FIPS violations

**Actions:**
```bash
# Verify FIPS mode
docker exec redis-exporter /usr/local/bin/fips-check

# Check environment
docker exec redis-exporter env | grep -E 'GOLANG_FIPS|GODEBUG'

# Verify no non-FIPS crypto
docker exec redis-exporter openssl dgst -md5 < /dev/null
# Expected: Error message (MD5 blocked)
```

### 8.2 User Role

**Responsibilities:**
- Use FIPS-approved configurations
- Report suspected FIPS violations
- Avoid modifying container image

**Restrictions:**
- Cannot disable FIPS mode
- Cannot load non-FIPS libraries
- Cannot bypass POST

### 8.3 Physical Security

**Requirements:**
- Host system must be in controlled environment
- Container image must be from trusted registry
- Image signatures must be verified (recommended)

### 8.4 Key Management

**Approved Practices:**
- TLS private keys: RSA ≥2048 bits or ECDSA P-256+
- Secrets management: Use Docker secrets, Kubernetes secrets, or HashiCorp Vault
- Key rotation: Per organizational policy

**Key Generation:**
```bash
# Approved: RSA 2048
openssl genrsa 2048

# Approved: ECDSA P-256
openssl ecparam -name prime256v1 -genkey
```

---

## 9. Testing and Validation

### 9.1 FIPS Validation Tests

**Automated Test Suite:** `diagnostics/test-images/basic-test-image/`

**Test Categories:**
1. **FIPS POST Tests** (8 tests)
   - wolfSSL FIPS POST execution
   - wolfProvider registration
   - Environment variable validation
   - OpenSSL version check

2. **Algorithm Availability** (7 tests)
   - SHA-256/384/512 availability
   - AES-128/256-GCM availability
   - RSA key generation
   - ECDSA key generation

3. **Algorithm Blocking** (6 tests)
   - MD5 blocked
   - SHA-1 blocked
   - DES blocked
   - RC4 blocked

4. **TLS Cipher Suites** (4 tests)
   - TLS 1.2/1.3 support
   - FIPS-approved ciphers present
   - Non-approved ciphers absent

**Execution:**
```bash
# Build test image
cd diagnostics/test-images/basic-test-image
./build.sh

# Run tests
docker run --rm cr.root.io/redis-exporter-test:latest

# Expected output:
# Total Tests: 30
# Passed: 12+ (FIPS tests)
# Skipped: 18 (require external Redis)
```

### 9.2 Continuous Validation

**Pre-deployment Checks:**
```bash
# 1. Verify image signature (if using signed images)
cosign verify cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips

# 2. Run FIPS validation
docker run --rm cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips \
    /usr/local/bin/fips-check

# 3. Verify environment
docker run --rm cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips \
    env | grep GOLANG_FIPS
```

### 9.3 Compliance Monitoring

**Runtime Checks:**
```bash
# FIPS status API endpoint (if implemented)
curl http://localhost:9121/fips-status

# Log monitoring
docker logs redis-exporter | grep -i fips

# Process verification
docker exec redis-exporter ldd /usr/local/bin/redis_exporter | grep wolfssl
```

---

## 10. Compliance Maintenance

### 10.1 CMVP Certificate Monitoring

**Responsibility:** Root FIPS Team

**Actions:**
- Monitor wolfSSL CMVP certificate status quarterly
- Subscribe to NIST CMVP announcements
- Track algorithm transitions and deprecations

**Resources:**
- NIST CMVP website: https://csrc.nist.gov/projects/cryptographic-module-validation-program
- wolfSSL FIPS certificate: Search CMVP for Certificate #4718

### 10.2 Update Policy

**FIPS Module Updates:**
- Only use validated versions of wolfSSL FIPS
- Verify new version has valid CMVP certificate
- Update image tag to reflect new FIPS version

**Application Updates:**
- redis_exporter version updates must not bypass FIPS crypto
- All crypto operations must route through wolfSSL FIPS
- Test FIPS validation after any update

### 10.3 Algorithm Transitions

**SHA-2 to SHA-3 (Future):**
- Monitor NIST guidance on algorithm transitions
- Update wolfSSL FIPS when SHA-3 validated version available
- Maintain SHA-2 support during transition period

**RSA to Post-Quantum (Future):**
- Track NIST post-quantum standardization
- Evaluate wolfSSL post-quantum FIPS module when available
- Plan migration timeline per NIST recommendations

---

## 11. Attestation Signatures

### 11.1 Technical Attestation

**I hereby attest that:**

1. This image uses wolfSSL FIPS Module v5.8.2 (CMVP Certificate #4718) exclusively for all cryptographic operations
2. All non-approved cryptographic algorithms are blocked at build-time and runtime
3. FIPS POST executes successfully on container startup
4. The implementation follows the wolfSSL FIPS Security Policy
5. No bypass mechanisms exist to use non-FIPS cryptography

**Attested by:**
Name: [Technical Lead Name]
Title: Senior FIPS Engineer
Date: 2026-03-27
Signature: _____________________________

### 11.2 Security Review

**I hereby certify that:**

1. The security configuration aligns with FIPS 140-3 requirements
2. The operational environment is approved for FIPS use
3. Key management practices are FIPS-compliant
4. The deployment architecture maintains FIPS boundaries

**Certified by:**
Name: [Security Officer Name]
Title: Information Security Manager
Date: 2026-03-27
Signature: _____________________________

### 11.3 Management Approval

**I hereby approve:**

1. The use of this FIPS-compliant image in controlled environments
2. The documented security policies and procedures
3. The testing and validation methodology
4. The compliance maintenance plan

**Approved by:**
Name: [Manager Name]
Title: Engineering Director
Date: 2026-03-27
Signature: _____________________________

---

## Appendices

### Appendix A: References

1. FIPS 140-3: Security Requirements for Cryptographic Modules
2. wolfSSL FIPS Security Policy v5.8.2
3. NIST SP 800-131A Rev. 2: Transitioning the Use of Cryptographic Algorithms and Key Lengths
4. NIST SP 800-52 Rev. 2: Guidelines for the Selection, Configuration, and Use of TLS Implementations
5. NIST SP 800-57 Part 1 Rev. 5: Recommendation for Key Management

### Appendix B: Acronyms

- **AES:** Advanced Encryption Standard
- **CAVP:** Cryptographic Algorithm Validation Program
- **CMVP:** Cryptographic Module Validation Program
- **DRBG:** Deterministic Random Bit Generator
- **ECDSA:** Elliptic Curve Digital Signature Algorithm
- **FIPS:** Federal Information Processing Standard
- **HMAC:** Hash-based Message Authentication Code
- **NIST:** National Institute of Standards and Technology
- **POST:** Power-On Self-Test
- **RSA:** Rivest-Shamir-Adleman (public key algorithm)
- **SHA:** Secure Hash Algorithm
- **TLS:** Transport Layer Security

### Appendix C: Contact Information

**FIPS Compliance Questions:**
Team: FIPS Engineering

**Security Incidents:**
Team: Information Security

---

**Document Classification:** Internal Use
**Distribution:** Approved personnel and auditors only
**Review Cycle:** Quarterly or upon FIPS module update

---

*End of FIPS 140-3 Compliance Attestation*
