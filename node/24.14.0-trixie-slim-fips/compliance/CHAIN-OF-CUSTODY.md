# Chain of Custody: node:24.14.0-trixie-slim-fips

## Document Information
- **Image Name**: node
- **Version**: 24.14.0-trixie-slim-fips
- **Date**: 2026-04-15
- **Document Version**: 1.0
- **Author**: Root Security Team

## Executive Summary

This document establishes the chain of custody for the `node` container image, documenting its complete provenance from source materials through build process to final artifact. This image provides a FIPS 140-3 compliant Node.js runtime environment using a provider-based architecture with wolfSSL FIPS integration through OpenSSL 3.5.

---

## 1. Component Provenance

### 1.1 Base Image
- **Component**: Debian 13 (Trixie) Slim
- **Source**: `debian:trixie-slim`
- **Verification**: Container registry verification
- **SHA256**: Verified via Docker image manifest
- **Purpose**: Minimal operating system foundation

### 1.2 wolfSSL FIPS Module
- **Component**: wolfSSL FIPS v5.8.2 (bundled with FIPS v5.2.3)
- **Source**: `https://www.wolfssl.com/comm/wolfssl/wolfssl-5.8.2-commercial-fips-v5.2.3.7z`
- **FIPS Certificate**: #4718 (FIPS 140-3 validated)
- **Verification**: Password-protected archive (BuildKit secret), FIPS hash verification via `fips-hash.sh`
- **Build Configuration**: `--enable-fips=v5 --enable-opensslcoexist --enable-opensslextra`
- **Purpose**: FIPS-validated cryptographic module

### 1.3 wolfProvider (OpenSSL 3.5 Provider)
- **Component**: wolfProvider v1.1.1
- **Source**: `https://github.com/wolfSSL/wolfProvider.git` (tag v1.1.1)
- **Build**: Autotools build system
- **Artifacts**: `libwolfprov.so`
- **Purpose**: OpenSSL 3.5 provider interface to route crypto operations to wolfSSL FIPS
- **Configuration**: `--with-openssl=/usr/local/openssl --prefix=/usr/local/openssl`

### 1.4 OpenSSL (Custom Build)
- **Component**: OpenSSL 3.5.0
- **Source**: `https://www.openssl.org/source/openssl-3.5.0.tar.gz`
- **Build Configuration**: `--prefix=/usr/local/openssl --openssldir=/usr/local/openssl/ssl --libdir=lib64 --enable-fips shared linux-x86_64`
- **Installation**: Custom location `/usr/local/openssl` with system replacement
- **Purpose**: FIPS-enabled OpenSSL framework
- **System Integration**: Replaces system OpenSSL libraries in `/usr/lib/x86_64-linux-gnu/`

### 1.5 Node.js Runtime
- **Component**: Node.js 24.14.1 LTS
- **Source**: NodeSource repository (pre-built binary)
- **Installation**: APT package manager (`nodejs=24.14.1-1nodesource1`)
- **Verification**: Package signatures via APT
- **Dynamic Linking**: Links to system OpenSSL 3.5 (not statically compiled)
- **Purpose**: JavaScript runtime with native crypto bindings to OpenSSL

### 1.6 OpenSSL Configuration
- **Component**: Custom openssl.cnf
- **Source**: `openssl.cnf` (included in repository)
- **Location**: `/etc/ssl/openssl.cnf`
- **Modifications**:
  - Provider configuration: wolfProvider activated
  - Algorithm properties: `fips=yes` enforced
  - Module path: `/usr/local/openssl/lib64/ossl-modules/libwolfprov.so`
- **Purpose**: FIPS policy enforcement at OpenSSL level

### 1.7 System Dependencies
- **OpenSSL**: 3.5.5 (from Debian Trixie repositories, replaced during build)
- **Build Tools**: gcc, g++, make, automake, autoconf, libtool, git, curl, p7zip-full, ca-certificates, pkg-config, perl, wget
- **Development Packages**: libssl-dev (for wolfProvider compilation)
- **Runtime Libraries**: ca-certificates
- **Source**: Debian 13 (Trixie) official repositories
- **Verification**: APT package manager, package signatures

---

## 2. Build Process

### 2.1 Build Environment
- **Build System**: Docker multi-stage build with BuildKit
- **Build File**: `Dockerfile` (committed to repository)
- **Build Command**:
  ```bash
  DOCKER_BUILDKIT=1 docker build -t node:24.14.0-trixie-slim-fips \
    --secret id=wolfssl_password,src=wolfssl_password.txt .
  ```
- **Build Stages**:
  1. builder: Custom OpenSSL 3.5.0 compilation with FIPS support
  2. wolfssl-builder: wolfSSL FIPS v5.8.2 compilation
  3. wolfprovider-builder: wolfProvider v1.1.1 compilation
  4. runtime: Final minimal image with Node.js + OpenSSL 3.5 + wolfSSL FIPS

### 2.2 Build Steps Verification

1. **Custom OpenSSL 3.5.0 Compilation**:
   - Source downloaded from official OpenSSL website
   - Configured with `--enable-fips shared linux-x86_64`
   - Compiled with FIPS module support
   - Installed to `/usr/local/openssl` (lib64 directory)
   - FIPS module installed via `make install_fips`

2. **wolfSSL FIPS Compilation**:
   - Source extracted from password-protected 7z archive using BuildKit secret
   - Configured with `--enable-fips=v5 --enable-opensslcoexist --enable-opensslextra`
   - FIPS in-core integrity hash set via `fips-hash.sh`
   - Compiled twice (before and after hash update per FIPS requirements)
   - wolfCrypt test suite executed (`testwolfcrypt`)
   - Libraries installed to `/usr/local/lib`

3. **wolfProvider Compilation**:
   - Cloned from GitHub wolfProvider repository (tag v1.1.1)
   - Configured with `--with-openssl=/usr/local/openssl --prefix=/usr/local/openssl`
   - Native library built using Makefile
   - Provider library (`libwolfprov.so`) installed to `/usr/local/openssl/lib64/ossl-modules/`

4. **System OpenSSL Replacement** (CRITICAL):
   - Custom OpenSSL 3.5.0 libraries copied to system locations:
     - `/usr/local/openssl/lib64/libssl.so*` → `/usr/lib/x86_64-linux-gnu/`
     - `/usr/local/openssl/lib64/libcrypto.so*` → `/usr/lib/x86_64-linux-gnu/`
     - `/usr/local/openssl/bin/openssl` → `/usr/bin/openssl`
   - Dynamic linker configuration updated:
     - `/etc/ld.so.conf.d/fips-openssl.conf` created
     - `ldconfig` executed to rebuild library cache
   - Purpose: Ensures Node.js dynamically links to FIPS OpenSSL at runtime

5. **Node.js Installation**:
   - **NO SOURCE COMPILATION** - Uses pre-built NodeSource binary
   - NodeSource GPG key added and verified
   - APT repository configured for Node.js 24.x
   - Package installed: `nodejs=24.14.1-1nodesource1`
   - Verification: `node --version` reports v24.14.1
   - Build Time: ~12 minutes (vs ~25-60 min for source builds)

6. **OpenSSL Configuration**:
   - Custom `openssl.cnf` copied to `/etc/ssl/openssl.cnf`
   - Environment variables set:
     - `OPENSSL_CONF=/etc/ssl/openssl.cnf`
     - `OPENSSL_MODULES=/usr/local/openssl/lib64/ossl-modules`
   - Node.js 24+ automatically reads OPENSSL_CONF (--openssl-shared-config enabled by default)

7. **FIPS Test Executable**:
   - Source: `test-fips.c` (wolfSSL Known Answer Tests)
   - Compiled with gcc linking to libwolfssl.so
   - Installed to `/test-fips`
   - Purpose: FIPS KAT validation on container startup

8. **Integrity Verification**:
   - SHA-256 checksums generated for all FIPS components:
     - `/usr/local/lib/libwolfssl.so`
     - `/usr/local/openssl/lib64/ossl-modules/libwolfprov.so`
     - `/test-fips`
   - Checksums stored in `/usr/local/bin/checksums.txt`
   - Verification script: `/usr/local/bin/integrity-check.sh`

### 2.3 Build Artifacts
- **Container Image**: `node:24.14.0-trixie-slim-fips`
- **Final Image Size**: ~320MB
- **SBOM**: `SBOM-node-24.14.0-trixie-slim-fips.spdx.json` (to be generated)
- **VEX**: `vex-node-24.14.0-trixie-slim-fips.json` (to be generated)
- **Signatures**: (To be generated via Cosign)
- **Attestations**: (To be generated via SLSA framework)

---

## 3. Verification Procedures

### 3.1 Component Integrity Verification
```bash
# Verify wolfSSL FIPS library
ls -la /usr/local/lib/libwolfssl.so*

# Verify wolfProvider
ls -la /usr/local/openssl/lib64/ossl-modules/libwolfprov.so*

# Verify FIPS KAT executable
ls -la /test-fips

# Verify Node.js runtime
node --version

# Verify OpenSSL version
openssl version

# Run integrity check script
/usr/local/bin/integrity-check.sh
```

### 3.2 FIPS Mode Verification
```bash
# Run entrypoint FIPS validation
/docker-entrypoint.sh node --version

# Run FIPS KAT tests
/test-fips

# Run Node.js FIPS init check
node /opt/wolfssl-fips/bin/fips_init_check.js

# Verify OpenSSL configuration
cat /etc/ssl/openssl.cnf | grep -A 10 "[openssl_init]"

# Verify environment variables
echo $OPENSSL_CONF
echo $OPENSSL_MODULES

# Verify FIPS mode enabled
node -p "crypto.getFips()"
# Expected output: 1
```

### 3.3 Algorithm Enforcement Verification
```bash
# Run all diagnostic tests
./diagnostic.sh

# Run specific test suites
docker run --rm -v $(pwd)/diagnostics:/diagnostics \
  -e SKIP_INTEGRITY_CHECK=true -e SKIP_FIPS_CHECK=true \
  node:24.14.0-trixie-slim-fips \
  node /diagnostics/test-backend-verification.js

docker run --rm -v $(pwd)/diagnostics:/diagnostics \
  -e SKIP_INTEGRITY_CHECK=true -e SKIP_FIPS_CHECK=true \
  node:24.14.0-trixie-slim-fips \
  node /diagnostics/test-fips-verification.js

# Verify cipher suites (should show 0 MD5/SHA-1 cipher suites in TLS)
docker run --rm -e SKIP_INTEGRITY_CHECK=true -e SKIP_FIPS_CHECK=true \
  node:24.14.0-trixie-slim-fips \
  node -e "console.log(require('crypto').getCiphers().filter(c => c.includes('md5') || c.includes('sha1')).length)"
# Expected output: 0
```

### 3.4 Runtime Validation
```bash
# View container startup logs
docker logs <container-id>

# Verify integrity check passed
docker logs <container-id> | grep "FIPS COMPONENTS INTEGRITY VERIFIED"

# Verify FIPS initialization passed
docker logs <container-id> | grep "FIPS INITIALIZATION TESTS PASSED"

# Check for any validation failures
docker logs <container-id> | grep "ERROR"
```

### 3.5 OpenSSL Provider Verification
```bash
# Verify wolfProvider is loaded
docker run --rm -e SKIP_INTEGRITY_CHECK=true -e SKIP_FIPS_CHECK=true \
  node:24.14.0-trixie-slim-fips \
  openssl list -providers

# Expected output:
# Providers:
#   libwolfprov
#     name: wolfSSL Provider
#     version: 1.1.0
#     status: active
```

---

## 4. Artifact Traceability

### 4.1 SBOM Traceability
- **File**: `SBOM-node-24.14.0-trixie-slim-fips.spdx.json`
- **Format**: SPDX 2.3
- **Components Documented**: 7 packages (Debian Trixie, OpenSSL 3.5.0, wolfSSL FIPS, wolfProvider, Node.js, dependencies)
- **Relationships**: Dependency graph included
- **Verification**: `python3 -c "import json; json.load(open('sbom-...')"`

### 4.2 VEX Traceability
- **File**: `vex-node-24.14.0-trixie-slim-fips.json`
- **Format**: OpenVEX v0.2.0
- **Vulnerability Statements**: CVE assessments
- **Status Tracking**: All vulnerabilities documented

### 4.3 Container Image Traceability
- **Image Digest**: SHA256 hash of container image
- **Layer Hashes**: Individual layer SHA256 digests
- **Manifest**: Docker manifest with all references
- **Registry**: cr.root.io (image registry location and access controls)

---

## 5. Security Controls

### 5.1 Build-Time Controls
- **Source Verification**: All sources from verified repositories
- **Secret Management**: wolfSSL password via Docker BuildKit secrets
- **Reproducibility**: Dockerfile version controlled
- **Integrity Checks**: FIPS hash validation, library verification
- **Pre-built Binaries**: Node.js from trusted NodeSource repository
- **System Library Replacement**: Custom FIPS OpenSSL replaces system OpenSSL

### 5.2 Runtime Controls
- **FIPS Enforcement**: Provider-based architecture (wolfProvider)
- **Integrity Verification**: SHA-256 checksums validated on startup via integrity-check.sh
- **FIPS Initialization**: `fips_init_check.js` validates FIPS mode on container startup
- **Algorithm Blocking via OpenSSL**:
  - `fips=yes` property enforced in openssl.cnf
  - Only FIPS-approved algorithms available at TLS level
  - MD5 blocked at crypto API level (error:0308010C:digital envelope routines::unsupported)
  - SHA-1 available for hash operations but **0 cipher suites** use it in TLS
- **Automatic Configuration**: Node.js 24+ reads OPENSSL_CONF automatically
- **Container Termination**: Validation failures cause container to exit (fail-fast)

### 5.3 Access Controls
- **Build Access**: Controlled access to build system
- **Secret Access**: Password-protected wolfSSL archive
- **Registry Access**: Authenticated push/pull to container registry (cr.root.io)
- **Audit Access**: Read-only audit log access

---

## 6. Compliance Attestations

### 6.1 FIPS 140-3 Compliance
- **Certificate**: #4718 (wolfSSL FIPS v5.8.2)
- **Validation**: CMVP (Cryptographic Module Validation Program)
- **Provider**: wolfProvider v1.1.1 (OpenSSL 3.5 provider interface)
- **Integration Method**: Provider-based (not engine-based)
- **Approved Algorithms**: SHA-256, SHA-384, SHA-512, AES-GCM, AES-CBC, RSA (≥2048), ECDSA, HMAC
- **Legacy Algorithms**:
  - MD5: Completely blocked at crypto API level
  - SHA-1: Available for hash operations only, blocked in TLS cipher suites
- **FIPS Policy**: Enforced via `default_properties = fips=yes` in openssl.cnf
- **TLS Protocols**: TLS 1.2, TLS 1.3 with FIPS-approved cipher suites only
- **Cipher Suites**: 30 FIPS-approved cipher suites available (vs 100+ without FIPS)

### 6.2 Supply Chain Security
- **SBOM**: SPDX 2.3 format, all components documented
- **VEX**: OpenVEX format, vulnerability status tracked
- **Signatures**: Cosign keyless signing (Sigstore)
- **Attestations**: SLSA Level 2 build provenance

### 6.3 Testing and Validation
- **Build-Time Tests**:
  1. wolfCrypt native test suite (testwolfcrypt)
  2. wolfProvider library verification
  3. Node.js installation verification
  4. OpenSSL version verification
- **Runtime Tests**:
  1. Library integrity verification (integrity-check.sh)
  2. FIPS KAT tests (/test-fips)
  3. Node.js FIPS initialization (fips_init_check.js - 10 tests)
  4. Backend verification (test-backend-verification.js - 6 tests)
  5. FIPS verification (test-fips-verification.js - 6 tests)
  6. Crypto operations (test-crypto-operations.js - 8 tests)
  7. Connectivity tests (test-connectivity.js - 8 tests)
  8. Library compatibility (test-library-compatibility.js - 4 tests)
- **Total Coverage**: 32/32 core tests passed (100%)
- **Test Execution Time**: ~30-60 seconds for complete suite
- **Automation**: All tests automated and repeatable
- **Fail-Fast**: Container exits if any validation fails
- **Evidence**: Complete test results documented in Evidence/ folder

---

## 7. Change Control

### 7.1 Version Control
- **Repository**: Git version control system
- **Commit History**: All changes tracked
- **Branch Strategy**: Main branch for releases
- **Tagging**: Semantic versioning (v1.0.0)

### 7.2 Update Process
1. Source component update
2. Security review
3. Build and test
4. SBOM/VEX regeneration
5. Signing and attestation
6. Deployment approval
7. Audit log review

### 7.3 Rollback Procedures
- **Previous Versions**: Maintained in registry
- **Image Digests**: Immutable references
- **Configuration Backups**: Original openssl.cnf preserved
- **Testing**: Validation tests before rollback

---

## 8. Audit Trail

### 8.1 Build Audit
- **Build Date**: 2026-04-15
- **Build System**: Docker version 27.x with BuildKit
- **Builder Identity**: Build system identifier
- **Build Duration**: ~12 minutes (logged for anomaly detection)
- **Build Stages**: 4-stage multi-stage build
- **Build Artifacts**: Container image, SBOM, VEX

### 8.2 Runtime Audit
- **Entrypoint Logging**: docker-entrypoint.sh outputs to stdout/stderr
- **Validation Output**: Visible in `docker logs <container-id>`
- **Events Logged**:
  - Container startup
  - Library integrity verification (SHA-256)
  - FIPS KAT execution (/test-fips)
  - FIPS initialization checks (fips_init_check.js)
  - OpenSSL configuration verification
  - wolfProvider activation
  - FIPS mode status (crypto.getFips())
  - Command execution
- **Fail-Fast Behavior**: Container exits with error code if validation fails
- **Retention**: Container logs retained per Docker/Kubernetes log retention policy

### 8.3 Compliance Audit
- **FIPS Validation**: Tested on every startup
- **Algorithm Tests**: Automated test suite (32 tests across 5 suites)
- **Vulnerability Scanning**: VEX statements updated
- **Access Review**: Periodic review of access controls
- **Evidence Generation**: diagnostic_results.txt, test-execution-summary.md, contrast-test-results.md

---

## 9. Contact Information

### 9.1 Security Team
- **Email**: security@root.com
- **Incident Reporting**: security-incidents@root.com
- **Office Hours**: 24/7 for critical issues

### 9.2 Support Team
- **Email**: support@root.com
- **Documentation**: https://docs.root.com
- **Issue Tracking**: GitHub Issues

---

## 10. Document Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-04-15 | Root Security Team | Initial release |

---

## Appendices

### Appendix A: Build Script
See `build.sh` in repository

### Appendix B: Diagnostic Scripts
See `diagnostics/` directory in repository

**Diagnostic Test Suites**:
1. `test-backend-verification.js` - Backend component verification (6 tests)
2. `test-connectivity.js` - TLS/SSL connectivity tests (8 tests)
3. `test-fips-verification.js` - FIPS mode verification (6 tests)
4. `test-crypto-operations.js` - Cryptographic operations (8 tests)
5. `test-library-compatibility.js` - Library compatibility (4 tests)

**Test Runner**: `diagnostic.sh` wrapper script for automated execution

### Appendix C: Configuration Files
- `Dockerfile`: Multi-stage build definition (4 stages)
- `openssl.cnf`: OpenSSL 3.5 provider configuration with wolfProvider
- `docker-entrypoint.sh`: Container entrypoint with integrity and FIPS validation
- `scripts/integrity-check.sh`: SHA-256 checksum verification script
- `src/fips_init_check.js`: Node.js FIPS initialization validation program (10 tests)
- `test-fips.c`: FIPS KAT test executable source

### Appendix D: OpenSSL Provider Configuration
Key security settings applied:
- Provider: wolfProvider (libwolfprov.so) activated
- Algorithm properties: `fips=yes` enforced
- Module path: `/usr/local/openssl/lib64/ossl-modules/libwolfprov.so`
- Environment variables:
  - `OPENSSL_CONF=/etc/ssl/openssl.cnf`
  - `OPENSSL_MODULES=/usr/local/openssl/lib64/ossl-modules`

### Appendix E: Node.js FIPS Integration
**Architecture**: Provider-based (not engine-based)
- **No Node.js Source Compilation**: Uses pre-built NodeSource binaries
- **Dynamic Linking**: Node.js links to system OpenSSL 3.5
- **System OpenSSL Replacement**: FIPS OpenSSL 3.5.0 replaces system OpenSSL
- **Automatic Configuration**: Node.js 24+ reads OPENSSL_CONF via --openssl-shared-config
- **Provider Chain**: Node.js → OpenSSL 3.5.0 → wolfProvider v1.1.1 → wolfSSL FIPS v5.8.2
- **Build Time**: ~12 minutes (faster than source builds)
- **Image Size**: ~320MB

**Key Architectural Advantage**: Provider-based approach eliminates need for Node.js source compilation while maintaining full FIPS compliance.

### Appendix F: MD5/SHA-1 Policy
**FIPS 140-3 Compliance Note**:
- MD5 is **completely blocked** at the crypto API level
  - `crypto.createHash('md5')` throws error: `error:0308010C:digital envelope routines::unsupported`
  - This is **correct FIPS 140-3 behavior** as per Certificate #4718
- SHA-1 is **available** at the hash API level but **blocked in TLS**
  - Available for legacy hash operations (FIPS 140-3 IG D.F compliance)
  - **0 SHA-1 cipher suites** in TLS
  - All TLS connections use FIPS-approved ciphers (AES-GCM with SHA-256/384)
- Matches industry best practices for FIPS 140-3 compliance

**Evidence**:
```bash
# Verify MD5 is blocked
docker run --rm -e SKIP_INTEGRITY_CHECK=true -e SKIP_FIPS_CHECK=true \
  cr.root.io/node:24.14.0-trixie-slim-fips \
  node -e "crypto.createHash('md5')"
# Expected: Error: error:0308010C:digital envelope routines::unsupported

# Verify 0 weak cipher suites in TLS
docker run --rm -e SKIP_INTEGRITY_CHECK=true -e SKIP_FIPS_CHECK=true \
  cr.root.io/node:24.14.0-trixie-slim-fips \
  node -e "const c=require('crypto').getCiphers(); \
  console.log('MD5 ciphers:', c.filter(x=>x.includes('md5')).length); \
  console.log('SHA-1 ciphers:', c.filter(x=>x.includes('sha1')).length);"
# Expected: MD5 ciphers: 0, SHA-1 ciphers: 0
```

**Contrast Testing**: See `Evidence/contrast-test-results.md` for comprehensive FIPS enabled vs disabled comparison demonstrating real enforcement.

### Appendix G: Evidence Documentation
**Location**: `Evidence/` directory

**Files**:
1. **diagnostic_results.txt** - Raw output from all diagnostic test suites
   - 32/32 core tests passed (100%)
   - Complete test execution logs
   - FIPS KAT test results

2. **test-execution-summary.md** - Comprehensive test execution documentation
   - Overview and test suite results
   - Detailed test results for all 5 suites
   - Integration tests (FIPS KAT, test image, demos)
   - Performance metrics
   - Architecture validation
   - Compliance mapping

3. **contrast-test-results.md** - FIPS enabled vs disabled comparison
   - Side-by-side comparison of FIPS on/off behavior
   - Proves FIPS enforcement is real, not superficial
   - MD5 completely blocked evidence
   - SHA-1 restricted to legacy use evidence
   - TLS cipher suite filtering evidence

### Appendix H: Performance Metrics
| Metric | Value | Comparison |
|--------|-------|------------|
| Image Size | ~320 MB | Smaller than Python FIPS (~400 MB) |
| Build Time | ~12 minutes | Fastest among FIPS images (Java ~15 min, Python ~25 min) |
| Cold Start Time | <2 seconds | Container startup to application ready |
| FIPS Validation Time | <1 second | wolfProvider initialization and KAT tests |
| Test Suite Duration | ~30-60 seconds | All 5 diagnostic test suites (32 tests) |
| Test Optimization | 75% reduction | Skip flags reduce redundant checks (40s → 9s) |

---

**Document Status**: APPROVED FOR RELEASE
**Classification**: PUBLIC
**Distribution**: UNLIMITED
