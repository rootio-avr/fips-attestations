# FIPS 140-3 Attestation

**Container Image**: node:16.20.1-bookworm-slim-fips
**Date**: 2026-03-22
**Version**: 1.0

---

> **⚠️ EOL NOTICE**: Node.js 16.20.1 reached End-of-Life on September 11, 2023. This attestation is provided for legacy compatibility validation only.

---

## FIPS Module Information

| Property | Value |
|----------|-------|
| **Module Name** | wolfCrypt FIPS Module |
| **Vendor** | wolfSSL Inc. |
| **Version** | 5.8.2 |
| **Certificate Number** | #4718 |
| **Validation Level** | FIPS 140-3, Security Level 1 |
| **Validation Date** | 2024 |
| **Standard** | FIPS 140-3 |

**Certificate URL**: https://csrc.nist.gov/projects/cryptographic-module-validation-program/certificate/4718

---

## Container Image Attestation

### Build Information

- **Base OS**: Debian 12 Bookworm Slim
- **Node.js Version**: 16.20.1 (EOL September 11, 2023)
- **npm Version**: 9.9.3 (upgraded from 8.19.4)
- **OpenSSL Version**: 3.0.18
- **wolfSSL Version**: 5.8.2 (FIPS 140-3 Certificate #4718)
- **wolfProvider Version**: 1.0.2
- **Build Date**: 2026-03-22
- **Build Method**: Provider-based (wolfProvider for OpenSSL 3.0)

### FIPS Components

| Component | Location | Checksum Verified |
|-----------|----------|-------------------|
| wolfSSL FIPS Library | /usr/local/lib/libwolfssl.so | ✅ SHA-256 |
| wolfProvider | /usr/local/lib/libwolfprov.so | ✅ SHA-256 |
| FIPS KAT Executable | /test-fips | ✅ SHA-256 |

---

## Cryptographic Algorithm Attestation

### FIPS-Approved Algorithms

**Symmetric Encryption**:
- ✅ AES-128-CBC, AES-192-CBC, AES-256-CBC
- ✅ AES-128-GCM, AES-192-GCM, AES-256-GCM (one-shot mode only)

**Hash Functions**:
- ✅ SHA-256, SHA-384, SHA-512

**Message Authentication**:
- ✅ HMAC-SHA256, HMAC-SHA384, HMAC-SHA512

**Asymmetric Cryptography**:
- ✅ RSA (2048, 3072, 4096 bit) - Encryption and Signatures
- ✅ ECDSA (P-256, P-384, P-521)
- ✅ ECDH (P-256, P-384, P-521)

**Random Number Generation**:
- ✅ Hash_DRBG, HMAC_DRBG

**Key Derivation**:
- ✅ PBKDF2, HKDF, TLS 1.2 PRF, TLS 1.3 HKDF

---

## TLS/SSL Protocol Attestation

**Supported Protocols**:
- ✅ TLS 1.2 (with FIPS-approved cipher suites only)
- ✅ TLS 1.3 (recommended)

**FIPS-Approved Cipher Suites** (TLS 1.3):
- TLS_AES_256_GCM_SHA384
- TLS_AES_128_GCM_SHA256
- TLS_CHACHA20_POLY1305_SHA256

**FIPS-Approved Cipher Suites** (TLS 1.2):
- ECDHE-RSA-AES256-GCM-SHA384
- ECDHE-RSA-AES128-GCM-SHA256
- ECDHE-ECDSA-AES256-GCM-SHA384
- ECDHE-ECDSA-AES128-GCM-SHA256

**Blocked Cipher Suites**:
- ❌ 0 MD5-based cipher suites
- ❌ 0 SHA-1-based cipher suites
- ❌ 0 DES/3DES cipher suites
- ❌ 0 RC4 cipher suites

---

## Self-Test Attestation

### Power-On Self-Test (POST)

**Execution**: Automatically on first cryptographic operation
**Coverage**:
- ✅ Known Answer Tests (KAT) for all approved algorithms
- ✅ Pairwise Consistency Test (PCT) for key generation
- ✅ Continuous Random Number Generator Test
- ✅ Integrity verification (HMAC-SHA-256)

**Verification**:
```bash
docker run --rm node:16.20.1-bookworm-slim-fips /test-fips
```

### Integrity Verification

**Runtime Checks**:
- ✅ SHA-256 checksum verification of libwolfssl.so
- ✅ SHA-256 checksum verification of libwolfprov.so
- ✅ SHA-256 checksum verification of /test-fips executable

**Verification Script**:
```bash
docker run --rm node:16.20.1-bookworm-slim-fips /usr/local/bin/integrity-check.sh
```

---

## Configuration Attestation

### OpenSSL Configuration

**Location**: /etc/ssl/openssl.cnf

**Provider Configuration**:
```ini
[provider_sect]
libwolfprov = libwolfprov_sect

[libwolfprov_sect]
activate = 1
module = /usr/local/lib/libwolfprov.so

[algorithm_sect]
default_properties = fips=yes
```

### Environment Variables

Explicitly set in docker-entrypoint.sh:
```bash
export OPENSSL_CONF=/etc/ssl/openssl.cnf
export OPENSSL_MODULES=/usr/local/lib
```

**Note**: These environment variables are explicitly exported in the entrypoint to ensure the OpenSSL configuration is loaded before Node.js starts.

---

## Compliance Statement

This container image provides FIPS 140-3 validated cryptography through:
1. wolfSSL FIPS Module v5.8.2 (Certificate #4718)
2. wolfProvider v1.0.2 (OpenSSL 3.0 provider interface)
3. Provider-based architecture for seamless integration

**FIPS Mode**: Automatically enabled on container startup
**Validation**: Self-tests run on every container start
**Integrity**: All FIPS components checksummed and verified

---

## Limitations and Disclaimers

### Node.js 16 EOL Status

⚠️ **IMPORTANT**: Node.js 16.20.1 reached End-of-Life on September 11, 2023. This image:
- Does NOT receive Node.js security updates
- Is provided for legacy application compatibility only
- Should NOT be used for new production deployments
- Requires migration to a supported Node.js LTS version for continued support

### Technical Limitations

1. **AES-GCM Streaming**: Supported in one-shot mode only (requires wolfSSL FIPS v6+ for streaming)
2. **PBKDF2**: FIPS-validated but not accessible via Node.js crypto API (wolfProvider v1.0.2 limitation)
3. **Legacy Algorithms**: MD5 and SHA-1 available for hashing (FIPS 140-3 compliant) but blocked in TLS cipher negotiation

---

## Attestation Verification

### Verify FIPS Mode

```bash
docker run --rm node:16.20.1-bookworm-slim-fips node -e "
  console.log('FIPS mode:', require('crypto').getFips());
"
# Expected: FIPS mode: 1
```

### Verify FIPS Components

```bash
# Run full FIPS initialization check
docker run --rm node:16.20.1-bookworm-slim-fips \
  node /opt/wolfssl-fips/bin/fips_init_check.js

# Expected: ALL FIPS INITIALIZATION CHECKS PASSED
```

### Verify Environment Configuration

```bash
docker run --rm node:16.20.1-bookworm-slim-fips env | grep OPENSSL
# Expected:
# OPENSSL_CONF=/etc/ssl/openssl.cnf
# OPENSSL_MODULES=/usr/local/lib
```

---

## Signature

**Attested By**: root.io Inc.
**Date**: 2026-03-22
**Version**: 1.0
**Purpose**: Legacy compatibility support with FIPS 140-3 validation

---

## References

- wolfSSL FIPS 140-3: https://www.wolfssl.com/license/fips/
- NIST CMVP Certificate #4718: https://csrc.nist.gov/projects/cryptographic-module-validation-program/certificate/4718
- Node.js 16 Documentation: https://nodejs.org/docs/latest-v16.x/
- Node.js Release Schedule: https://github.com/nodejs/Release#release-schedule
- OpenSSL Providers: https://www.openssl.org/docs/man3.0/man7/provider.html
