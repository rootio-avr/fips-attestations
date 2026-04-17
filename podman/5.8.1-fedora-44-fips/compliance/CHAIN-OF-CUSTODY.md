# Chain of Custody: podman:5.8.1-fedora-44-fips

## Document Information
- **Image Name**: podman
- **Version**: 5.8.1-fedora-44-fips
- **Date**: 2026-04-17
- **Document Version**: 1.0
- **Author**: Root Security Team

## Executive Summary

This document establishes the chain of custody for the Podman FIPS container image, documenting its complete provenance from source materials through build process to final artifact. This image provides a FIPS 140-3 compliant container management platform with Podman 5.8.1 built using golang-fips/go with strict cryptographic policy enforcement.

---

## 1. Component Provenance

### 1.1 Base Image
- **Component**: Fedora 44
- **Source**: `registry.fedoraproject.org/fedora:44`
- **Verification**: Official Fedora registry
- **SHA256**: Verified via Docker image manifest
- **Purpose**: Operating system foundation for Podman runtime

### 1.2 wolfSSL FIPS Module
- **Component**: wolfSSL FIPS v5.8.2
- **Source**: `https://www.wolfssl.com/comm/wolfssl/wolfssl-5.8.2-commercial-fips-v5.2.3.7z`
- **FIPS Certificate**: #4718 (FIPS 140-3 validated)
- **Verification**: Password-protected archive, FIPS hash verification via `fips-hash.sh`
- **Build Configuration**: `--enable-fips=v5 --enable-all --enable-keygen --enable-certgen`
- **Purpose**: FIPS-validated cryptographic module

### 1.3 OpenSSL
- **Component**: OpenSSL 3.5.0
- **Source**: `https://www.openssl.org/source/openssl-3.5.0.tar.gz`
- **Verification**: SHA256 checksum verification, official OpenSSL website
- **Build Configuration**: `enable-fips shared --openssldir=/usr/local/openssl/ssl`
- **Purpose**: Cryptographic library framework with FIPS provider support

### 1.4 wolfProvider
- **Component**: wolfProvider v1.1.1
- **Source**: `https://github.com/wolfSSL/wolfProvider.git` (tag v1.1.1)
- **Git Commit**: Tagged release v1.1.1
- **Verification**: GitHub official repository, commit hash verification
- **Purpose**: OpenSSL 3.x provider routing cryptographic operations to wolfSSL FIPS

### 1.5 golang-fips/go
- **Component**: golang-fips/go v1.25
- **Source**: `https://github.com/golang-fips/go.git` (branch go1.25-fips-release)
- **Git Branch**: `go1.25-fips-release`
- **Verification**: GitHub official fork, branch integrity verification
- **Build Configuration**: CGO_ENABLED=1, strict FIPS runtime enabled
- **Purpose**: FIPS-enabled Go compiler and runtime for building Podman

### 1.6 Podman
- **Component**: Podman v5.8.1
- **Source**: `https://github.com/containers/podman.git` (tag v5.8.1)
- **Git Tag**: v5.8.1
- **Verification**: Official Podman GitHub repository, GPG signature verification
- **Build Method**: Source compilation with golang-fips/go
- **Purpose**: Container management platform with FIPS-compliant cryptography

### 1.7 Podman Runtime Dependencies
- **conmon**: v2.1.12 - Container monitoring utility
- **crun**: v1.18.2 - OCI runtime
- **slirp4netns**: v1.3.1 - User-mode networking
- **fuse-overlayfs**: v1.14 - FUSE overlay filesystem
- **Source**: Fedora 44 official repositories
- **Verification**: DNF package manager, RPM signatures

---

## 2. Build Process

### 2.1 Build Environment
- **Build System**: Docker multi-stage build
- **Build File**: `Dockerfile` (committed to repository)
- **Build Command**:
  ```bash
  docker build -t cr.root.io/podman:5.8.1-fedora-44-fips \
    --secret id=wolfssl_password,src=wolfssl_password.txt .
  ```
- **Build Stages**:
  1. wolfssl-builder: Compiles wolfSSL FIPS v5.8.2
  2. wolfprov-builder: Compiles wolfProvider v1.1.1
  3. go-fips-builder: Compiles golang-fips/go v1.25 from source
  4. podman-builder: Compiles Podman v5.8.1 with FIPS-capable Go
  5. runtime: Final image with FIPS enforcement and runtime dependencies

### 2.2 Build Steps Verification

#### Stage 1: wolfSSL FIPS Compilation
- Source extracted from password-protected 7z archive
- Configured with FIPS v5 validation
- FIPS hash validation performed via `fips-hash.sh`
- Compiled with full feature set (keygen, certgen, all algorithms)
- Installed to `/usr/local/lib` and `/usr/local/include`
- **Verification**: `libwolfssl.so.44` presence, FIPS hash check

#### Stage 2: OpenSSL Compilation
- Source downloaded from official OpenSSL website
- Configured with FIPS provider support (`enable-fips`)
- Built as shared library for dynamic linking
- `openssl fipsinstall` executed to generate fipsmodule.cnf
- Installed to `/usr/local/openssl`
- **Verification**: OpenSSL version 3.5.0, FIPS provider present

#### Stage 3: wolfProvider Compilation
- Cloned from GitHub (tag v1.1.1)
- Built against wolfSSL FIPS and OpenSSL 3.5.0
- Configured to route OpenSSL calls to wolfSSL
- Installed to `/usr/local/openssl/lib64/ossl-modules/`
- **Verification**: `libwolfprov.so` presence, provider loading test

#### Stage 4: golang-fips/go Compilation
- Bootstrap compiler: Go 1.22.6 (official release)
- Source cloned from golang-fips fork (branch go1.25-fips-release)
- Built with CGO_ENABLED=1 for OpenSSL integration
- Installed to `/usr/local/go-fips`
- **Verification**: `go version` shows go1.25, CGO available

#### Stage 5: Podman Compilation
- Source cloned from Podman GitHub (tag v5.8.1)
- Built using golang-fips/go compiler
- CGO_ENABLED=1 to link with OpenSSL/wolfSSL
- FIPS variables NOT set during build (capability only)
- Installed to `/usr/local/bin/podman`
- **Verification**: `podman --version` shows 5.8.1

#### Stage 6: Runtime Image Assembly
- Copies compiled binaries from builder stages
- Installs Podman runtime dependencies (conmon, crun, slirp4netns, fuse-overlayfs)
- Copies OpenSSL configuration with wolfProvider setup
- Copies entrypoint.sh for runtime FIPS enforcement
- Copies test-fips utility for FIPS validation
- **Verification**: All binaries executable, dependencies present

### 2.3 Build Artifacts
- **Container Image**: `cr.root.io/podman:5.8.1-fedora-44-fips`
- **Image Size**: ~800MB-1GB (includes compiler toolchain)
- **Dockerfile**: Version controlled in Git repository
- **Build Logs**: Available in Evidence/
- **Diagnostic Results**: Evidence/diagnostic_results.txt

---

## 3. Verification Procedures

### 3.1 Component Integrity Verification
```bash
# Verify wolfSSL FIPS module
docker run --rm cr.root.io/podman:5.8.1-fedora-44-fips test-fips

# Verify OpenSSL providers
docker run --rm cr.root.io/podman:5.8.1-fedora-44-fips openssl list -providers

# Verify golang-fips/go installation
docker run --rm cr.root.io/podman:5.8.1-fedora-44-fips go version

# Verify Podman installation
docker run --rm cr.root.io/podman:5.8.1-fedora-44-fips podman --version
```

### 3.2 FIPS Mode Verification
```bash
# Verify FIPS environment variables
docker run --rm cr.root.io/podman:5.8.1-fedora-44-fips env | grep -E '(GOLANG_FIPS|GODEBUG|GOEXPERIMENT)'

# Expected output:
# GOLANG_FIPS=1
# GODEBUG=fips140=only
# GOEXPERIMENT=strictfipsruntime

# Verify OpenSSL configuration
docker run --rm cr.root.io/podman:5.8.1-fedora-44-fips \
  cat /etc/ssl/openssl.cnf | grep -A5 "\[algorithm_sect\]"

# Expected: default_properties = fips=yes
```

### 3.3 Algorithm Enforcement Verification
```bash
# Run diagnostic test suite
cd podman/5.8.1-fedora-44-fips
./diagnostic.sh

# Expected: All 30 tests pass
# - 10 FIPS compliance tests
# - 10 Podman functionality tests
# - 10 Cryptographic operations tests

# Test MD5 blocking (non-FIPS)
docker run --rm cr.root.io/podman:5.8.1-fedora-44-fips \
  bash -c "echo 'test' | openssl dgst -md5"
# Expected: Error - disabled for FIPS

# Test SHA-256 (FIPS-approved)
docker run --rm cr.root.io/podman:5.8.1-fedora-44-fips \
  bash -c "echo 'test' | openssl dgst -sha256"
# Expected: Hash generated successfully
```

### 3.4 Podman Functionality Verification
```bash
# Basic Podman commands
docker run --rm cr.root.io/podman:5.8.1-fedora-44-fips podman --version
docker run --rm cr.root.io/podman:5.8.1-fedora-44-fips podman --help

# Podman info (requires privileged)
docker run --rm --privileged cr.root.io/podman:5.8.1-fedora-44-fips podman info

# Runtime dependencies
docker run --rm cr.root.io/podman:5.8.1-fedora-44-fips bash -c \
  "command -v conmon && command -v crun && command -v slirp4netns && command -v fuse-overlayfs"
```

---

## 4. Artifact Traceability

### 4.1 Source Code Traceability
- **Podman Source**: GitHub commit hash from tag v5.8.1
- **golang-fips/go Source**: Git commit hash from go1.25-fips-release branch
- **wolfProvider Source**: GitHub commit hash from tag v1.1.1
- **wolfSSL Source**: Version 5.8.2 from commercial FIPS package
- **OpenSSL Source**: Version 3.5.0 from official release tarball

### 4.2 Binary Traceability
- **Podman Binary**: `/usr/local/bin/podman` - SHA256 checksum documented
- **Go Compiler**: `/usr/local/go-fips/bin/go` - Version string and checksum
- **wolfSSL Library**: `/usr/local/lib/libwolfssl.so.44` - FIPS hash verified
- **wolfProvider**: `/usr/local/openssl/lib64/ossl-modules/libwolfprov.so` - Checksum
- **OpenSSL**: `/usr/local/openssl/bin/openssl` - Version and checksum

### 4.3 Configuration Traceability
- **OpenSSL Config**: `/etc/ssl/openssl.cnf` - Version controlled
- **FIPS Module Config**: `/usr/local/openssl/ssl/fipsmodule.cnf` - Generated by openssl fipsinstall
- **Entrypoint Script**: `/entrypoint.sh` - Sets FIPS environment variables
- **Storage Config**: `/etc/containers/storage.conf` - Podman storage configuration
- **Registries Config**: `/etc/containers/registries.conf` - Container registry configuration

### 4.4 Container Image Traceability
- **Image Digest**: SHA256 hash of container image (immutable reference)
- **Layer Hashes**: Individual layer SHA256 digests for each build stage
- **Manifest**: Docker manifest with all layer references
- **Registry**: Image stored in cr.root.io registry with access controls

---

## 5. Security Controls

### 5.1 Build-Time Controls
- **Source Verification**: All sources from verified official repositories
- **Secret Management**: wolfSSL FIPS password via Docker BuildKit secrets (not in image)
- **Reproducibility**: Dockerfile version controlled, multi-stage build documented
- **Integrity Checks**: FIPS hash validation, OpenSSL provider verification
- **Isolation**: Build stages isolated, minimal runtime artifacts

### 5.2 Runtime Controls
- **FIPS Enforcement**: Enabled via entrypoint.sh (GOLANG_FIPS=1, GODEBUG=fips140=only)
- **Algorithm Blocking**: MD5/SHA-1 blocked, only FIPS-approved algorithms allowed
- **Provider Architecture**: Three providers loaded (fips, wolfssl, base)
- **Configuration Management**: OpenSSL config with `default_properties = fips=yes`
- **Validation**: test-fips utility verifies wolfSSL FIPS module on startup

### 5.3 Access Controls
- **Build Access**: Controlled access to build system and Docker daemon
- **Secret Access**: wolfSSL FIPS password restricted to authorized build systems
- **Registry Access**: Authenticated push/pull to container registry (cr.root.io)
- **Container Execution**: User namespace isolation, capability restrictions

### 5.4 Network Controls
- **Build Network**: Internet access required for source downloads (official repos only)
- **Runtime Network**: Configurable via Docker/Podman networking
- **Podman Networking**: slirp4netns for rootless networking, netavark for rootful

---

## 6. Compliance Attestations

### 6.1 FIPS 140-3 Compliance
- **Certificate**: #4718 (wolfSSL FIPS v5.8.2)
- **Validation**: CMVP (Cryptographic Module Validation Program)
- **Approved Algorithms**:
  - Symmetric: AES-128, AES-192, AES-256
  - Asymmetric: RSA-2048+, ECC (P-256, P-384, P-521)
  - Hash: SHA-256, SHA-384, SHA-512
  - MAC: HMAC-SHA256/384/512
  - TLS: TLS 1.2, TLS 1.3 (FIPS ciphers only)
- **Blocked Algorithms**: MD5, SHA-1, DES, 3DES, RC4, ChaCha20-Poly1305

### 6.2 Podman FIPS Integration
- **Build Method**: Source compilation with golang-fips/go (CGO_ENABLED=1)
- **Crypto Backend**: OpenSSL 3.5.0 + wolfProvider → wolfSSL FIPS v5.8.2
- **Runtime Enforcement**: GODEBUG=fips140=only ensures Go runtime uses FIPS crypto
- **Binary Linkage**: Podman binary dynamically linked to OpenSSL/wolfSSL libraries

### 6.3 Testing and Validation
- **Test Suite**: 30 comprehensive tests across 3 categories
  1. FIPS Compliance (10 tests): wolfSSL self-test, providers, environment, libraries
  2. Podman Functionality (10 tests): Version, dependencies, configuration, help
  3. Cryptographic Operations (10 tests): RSA, AES, SHA-2, EC, TLS, MD5 blocking
- **Pass Rate**: 100% (30/30 tests passed)
- **Evidence**: See Evidence/diagnostic_results.txt
- **Automation**: All tests automated via ./diagnostic.sh script

### 6.4 Contrast Testing
- **Purpose**: Prove FIPS enforcement is real, not superficial
- **Method**: Compare behavior with FIPS enabled vs disabled
- **Results**: MD5 blocked with FIPS, configurable enforcement demonstrated
- **Evidence**: See Evidence/contrast-test-results.md

---

## 7. Change Control

### 7.1 Version Control
- **Repository**: Git version control system
- **Branch Structure**: Main branch for stable releases
- **Commit History**: All changes tracked with descriptive messages
- **Tagging**: Semantic versioning (e.g., podman-5.8.1-fips-v1.0)

### 7.2 Component Update Process
1. **Identify Update**: Monitor for new versions of Podman, Go, wolfSSL, OpenSSL
2. **Security Review**: Assess security implications, CVE analysis
3. **Build Testing**: Update Dockerfile, rebuild, run diagnostic tests
4. **Validation**: Verify FIPS compliance maintained, all tests pass
5. **Documentation**: Update README, CHAIN-OF-CUSTODY, Evidence files
6. **Release**: Tag release, push to registry, update downstream consumers

### 7.3 Rollback Procedures
- **Previous Versions**: Maintained in container registry with immutable tags
- **Image Digests**: Use SHA256 digest for exact version reference
- **Rollback Command**: `docker pull cr.root.io/podman@sha256:<digest>`
- **Testing**: Run diagnostic.sh on rolled-back image before deployment

### 7.4 Emergency Updates
- **Security Vulnerabilities**: Expedited build and release process
- **FIPS Certificate Expiry**: Plan for wolfSSL FIPS updates before expiration
- **Critical Bugs**: Fast-track patch, abbreviated testing for hotfixes

---

## 8. Audit Trail

### 8.1 Build Audit
- **Build Date**: 2026-04-17 (as documented)
- **Build System**: Docker BuildKit with multi-stage builds
- **Build Duration**: 20-30 minutes (varies by system performance)
- **Build Logs**: Available for review, saved during build process
- **Builder Identity**: Build system hostname and user tracked

### 8.2 Component Audit
| Component | Version | Source | Verification Method |
|-----------|---------|--------|---------------------|
| Fedora | 44 | registry.fedoraproject.org | Image manifest SHA256 |
| wolfSSL FIPS | 5.8.2 | Commercial package | Password-protected, FIPS hash |
| OpenSSL | 3.5.0 | openssl.org | SHA256 checksum |
| wolfProvider | 1.1.1 | GitHub tag | Git commit hash |
| golang-fips/go | 1.25 | GitHub branch | Git commit hash |
| Podman | 5.8.1 | GitHub tag | Git tag, GPG signature |

### 8.3 Runtime Audit
- **Startup Validation**: test-fips utility can be run to verify FIPS module
- **Environment Verification**: FIPS environment variables logged on container start
- **Provider Status**: OpenSSL provider list can be checked at runtime
- **Diagnostic Tests**: Full test suite can be run post-deployment

### 8.4 Compliance Audit
- **FIPS Validation**: wolfSSL FIPS v5.8.2 Certificate #4718 (validated)
- **Algorithm Tests**: MD5 blocked, SHA-256+ functional (verified)
- **Provider Integration**: wolfProvider active, routing to wolfSSL (verified)
- **Build Reproducibility**: Dockerfile committed, build repeatable (verified)

---

## 9. Known Limitations

### 9.1 Container-Specific Limitations
- **Kernel FIPS Mode**: Containers share host kernel; kernel-level FIPS is host responsibility
- **Privileged Operations**: Some Podman operations (podman info, advanced networking) require --privileged
- **User Namespaces**: User namespace operations limited in nested containers (Docker-in-Docker)

### 9.2 Podman-Specific Limitations
- **netavark/aardvark-dns**: Not included in image; basic networking functional, advanced features may need additional setup
- **Storage Drivers**: overlay filesystem supported; other drivers may need configuration
- **Container Nesting**: Running Podman inside Docker has limitations (shared mount warnings)

### 9.3 FIPS-Specific Limitations
- **Build-Time FIPS**: FIPS not enforced during Podman compilation (prevents build issues)
- **Runtime-Only**: FIPS enforcement activated by entrypoint.sh at container startup
- **ChaCha20-Poly1305**: Not available (not FIPS-approved)
- **SHA-1**: Blocked for security (even though some FIPS modes allow it)

---

## 10. Contact Information

### 10.1 Security Team
- **Email**: security@root.io
- **Incident Reporting**: security-incidents@root.io
- **Response Time**: 24/7 for critical FIPS/security issues

### 10.2 Support Team
- **Email**: support@root.io
- **Documentation**: https://docs.root.io/podman-fips
- **Issue Tracking**: GitHub Issues at repository

### 10.3 Build Team
- **Email**: build-team@root.io
- **Build Requests**: Coordinate through build team for custom builds
- **Access Requests**: For build system access or wolfSSL FIPS password

---

## 11. Document Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-04-17 | Root Security Team | Initial release for Podman 5.8.1 FIPS image |

---

## Appendices

### Appendix A: Build Script
See `build.sh` in repository root

### Appendix B: Diagnostic Scripts
- `diagnostic.sh` - Main test runner
- `diagnostics/run-diagnostics.sh` - Internal test orchestrator
- `diagnostics/tests/fips-test.sh` - FIPS compliance tests
- `diagnostics/tests/podman-basic-test.sh` - Podman functionality tests
- `diagnostics/tests/crypto-test.sh` - Cryptographic operation tests

### Appendix C: Configuration Files
- `Dockerfile` - Multi-stage build definition (5 stages)
- `openssl.cnf` - OpenSSL configuration with wolfProvider
- `entrypoint.sh` - Container entrypoint with FIPS environment setup
- `test-fips.c` - wolfSSL FIPS self-test utility source

### Appendix D: Evidence Files
- `Evidence/diagnostic_results.txt` - Complete test output
- `Evidence/test-execution-summary.md` - Test execution documentation
- `Evidence/contrast-test-results.md` - FIPS on/off comparison analysis

### Appendix E: Reference Documentation
- `README.md` - User guide and quick start
- FIPS 140-3 validation documentation
- Podman official documentation: https://docs.podman.io/
- golang-fips/go documentation: https://github.com/golang-fips/go
- wolfSSL FIPS documentation: https://www.wolfssl.com/products/wolfssl-fips/

---

**Document Status**: APPROVED FOR RELEASE
**Classification**: PUBLIC
**Distribution**: UNLIMITED
**Next Review Date**: 2027-04-17
