# Chain of Custody Documentation

**Image**: node:16.20.1-bookworm-slim-fips
**FIPS Certificate**: #4718 (wolfSSL 5.8.2)
**Date**: 2026-03-22

---

## Purpose

This document establishes the chain of custody for FIPS-validated cryptographic components used in the Node.js 16 FIPS container image.

---

## Source Components

### 1. wolfSSL FIPS Module

**Component**: wolfSSL FIPS 140-3 Cryptographic Module
**Version**: 5.8.2
**Certificate**: FIPS 140-3 #4718
**Source**: wolfSSL Inc.
**Download**: https://www.wolfssl.com/comm/wolfssl/wolfssl-5.8.2-commercial-fips-v5.2.3.7z
**Verification**: Password-protected archive (commercial license required)
**Integrity**: HMAC-SHA-256 embedded in module

### 2. wolfProvider

**Component**: wolfProvider for OpenSSL 3.0
**Version**: 1.0.2
**Source**: wolfSSL Inc. (Open Source)
**Repository**: https://github.com/wolfSSL/wolfProvider
**Download**: https://github.com/wolfSSL/wolfProvider/archive/refs/tags/v1.0.2.tar.gz
**Verification**: Git tag signature

### 3. Node.js Runtime

**Component**: Node.js JavaScript Runtime
**Version**: 16.20.1
**EOL Date**: September 11, 2023
**Source**: NodeSource (official binary distribution)
**Repository**: https://deb.nodesource.com/node_16.x/
**Verification**: Package signature via apt

### 4. npm Package Manager

**Component**: npm
**Version**: 9.9.3 (upgraded from 8.19.4)
**Source**: npm Inc. (via npmjs.org)
**Verification**: npm registry signatures

### 5. Base Operating System

**Component**: Debian Linux
**Version**: Bookworm (12)
**Variant**: Slim
**Source**: Official Debian repository
**Container Base**: debian:bookworm-slim
**Verification**: Official Docker Hub image

---

## Build Process Chain of Custody

### Step 1: Base Image Acquisition

```dockerfile
FROM debian:bookworm-slim
```

**Verification**:
- Official Debian Docker image
- SHA-256 digest verified by Docker

### Step 2: wolfSSL FIPS Download and Build

**Download**:
```bash
wget -O wolfssl.7z "${WOLFSSL_URL}"
cat /run/secrets/wolfssl_password | 7z x wolfssl.7z
```

**Build**:
```bash
./configure --enable-fips=v5 ...
make -j $(nproc)
./fips-hash.sh
make -j $(nproc)
make install
```

**Verification**:
- FIPS hash computed during build (fips-hash.sh)
- In-core integrity check on library load

### Step 3: wolfProvider Download and Build

**Download**:
```bash
wget -O wolfprovider.tar.gz ${WOLFPROVIDER_URL}
```

**Build**:
```bash
./configure --with-wolfssl=/usr/local
make -j $(nproc)
make install
```

**Verification**:
- Dynamic linking to wolfSSL FIPS module
- SHA-256 checksum generated post-build

### Step 4: Node.js Installation

**Install**:
```bash
curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
apt-get install -y nodejs
```

**Verification**:
- NodeSource package signature
- Version verification: `node --version`

### Step 5: npm Upgrade

**Upgrade**:
```bash
npm install -g npm@9.9.3
```

**Verification**:
- npm registry signature
- Version verification: `npm --version`

### Step 6: Integrity Checksum Generation

**Checksums Generated**:
```bash
sha256sum /usr/local/lib/libwolfssl.so* > libwolfssl.sha256
sha256sum /usr/local/lib/libwolfprov.so* > libwolfprov.sha256
sha256sum /test-fips > test-fips.sha256
```

**Storage**: /opt/wolfssl-fips/checksums/

---

## Runtime Verification

### Container Startup

**Entrypoint**: /docker-entrypoint.sh

**Checks Performed**:
1. **Integrity Check**: Verify SHA-256 checksums of FIPS components
2. **FIPS Initialization**: Run Known Answer Tests (KATs)
3. **Configuration Validation**: Verify OpenSSL provider configuration

### Environment Configuration (Node 16 Specific)

**Explicit Exports**:
```bash
export OPENSSL_CONF=/etc/ssl/openssl.cnf
export OPENSSL_MODULES=/usr/local/lib
```

**Purpose**: Ensure OpenSSL configuration is loaded before Node.js starts (Node 16 requirement)

---

## Audit Trail

### Build Artifacts

| Artifact | Location | Verification Method |
|----------|----------|---------------------|
| wolfSSL FIPS Library | /usr/local/lib/libwolfssl.so | SHA-256 checksum + in-core HMAC |
| wolfProvider | /usr/local/lib/libwolfprov.so | SHA-256 checksum |
| FIPS KAT Executable | /test-fips | SHA-256 checksum + runtime execution |
| OpenSSL Config | /etc/ssl/openssl.cnf | File integrity check |

### Verification Commands

```bash
# Verify FIPS library integrity
sha256sum -c /opt/wolfssl-fips/checksums/libwolfssl.sha256

# Verify provider integrity
sha256sum -c /opt/wolfssl-fips/checksums/libwolfprov.sha256

# Run FIPS KAT tests
/test-fips

# Verify FIPS mode enabled
node -e "console.log(require('crypto').getFips())"
```

---

## Compliance Attestation

**FIPS Module**: ✅ Certificate #4718 (wolfSSL 5.8.2)
**Build Process**: ✅ Documented and reproducible
**Integrity Verification**: ✅ Runtime checksums verified
**Configuration**: ✅ Environment-based (Node 16 compatible)

**Limitations**:
- ⚠️ Node.js 16 EOL (September 11, 2023)
- ⚠️ No Node.js security updates
- ⚠️ Legacy support only

---

## Document Control

**Version**: 1.0
**Date**: 2026-03-22
**Author**: root.io Inc.
**Purpose**: Chain of custody for FIPS compliance audit
