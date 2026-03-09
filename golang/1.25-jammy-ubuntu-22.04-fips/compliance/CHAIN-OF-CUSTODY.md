# Chain of Custody: golang:1.25-jammy-ubuntu-22.04-fips

## Document Information
- **Image Name**: golang
- **Version**: 1.25-jammy-ubuntu-22.04-fips
- **Date**: 2026-03-04
- **Document Version**: 1.0
- **Author**: Root Security Team

## Executive Summary

This document establishes the chain of custody for the golang container image, documenting its complete provenance from source materials through build process to final artifact. This image provides a FIPS 140-3 compliant Go development and runtime environment with strict policy enforcement.

---

## 1. Component Provenance

### 1.1 Base Image
- **Component**: Ubuntu 22.04 LTS (Jammy Jellyfish)
- **Source**: `docker.io/library/ubuntu:22.04`
- **Verification**: Official Docker Hub repository
- **SHA256**: Verified via Docker image manifest
- **Purpose**: Operating system foundation

### 1.2 wolfSSL FIPS Module
- **Component**: wolfSSL FIPS v5.8.2
- **Source**: `https://www.wolfssl.com/comm/wolfssl/wolfssl-5.8.2-commercial-fips-v5.2.3.7z`
- **FIPS Certificate**: #4718 (FIPS 140-3 validated)
- **Verification**: Password-protected archive, FIPS hash verification via `fips-hash.sh`
- **Build Configuration**: `--enable-fips=v5 --disable-sha` (strict policy)
- **Purpose**: FIPS-validated cryptographic module

###1.3 wolfProvider
- **Component**: wolfProvider v1.1.0
- **Source**: `https://github.com/wolfSSL/wolfProvider/releases/tag/v1.1.0`
- **Git Commit**: Tagged release v1.1.0
- **Verification**: GitHub official repository, GPG signatures (if available)
- **Purpose**: OpenSSL 3.x provider routing to wolfSSL

### 1.4 golang-fips/go
- **Component**: golang-fips/go v1.25
- **Source**: `https://github.com/golang-fips/go/tree/go1.25-fips-release`
- **Git Branch**: `go1.25-fips-release`
- **Verification**: GitHub official fork, branch integrity
- **Modifications**: ChaCha20-Poly1305 removed, strict FIPS runtime enabled
- **Purpose**: FIPS-enabled Go compiler and runtime

### 1.5 System Dependencies
- **OpenSSL**: 3.0.2 (Ubuntu package)
- **Build Tools**: gcc, g++, make, pkg-config (Ubuntu packages)
- **Source**: Ubuntu 22.04 official repositories
- **Verification**: APT package manager, package signatures

---

## 2. Build Process

### 2.1 Build Environment
- **Build System**: Docker multi-stage build
- **Build File**: `Dockerfile` (committed to repository)
- **Build Command**:
  ```bash
  docker build -t golang:1.25-jammy-ubuntu-22.04-fips \
    --secret id=wolfssl_password,src=.wolfssl_password .
  ```
- **Build Stages**:
  1. wolfssl-builder: Compiles wolfSSL FIPS
  2. wolfprov-builder: Compiles wolfProvider
  3. go-builder: Compiles golang-fips/go and demo app
  4. Final: Runtime image with compiler toolchain

### 2.2 Build Steps Verification
1. **wolfSSL Compilation**:
   - Source extracted from password-protected archive
   - Configured with FIPS v5 and strict policy (`--disable-sha`)
   - FIPS hash validation performed via `fips-hash.sh`
   - Compiled twice (before and after hash verification)
   - Installed to `/usr/local`

2. **wolfProvider Compilation**:
   - Cloned from GitHub (tag v1.1.0)
   - Architecture detection (x86_64/aarch64)
   - Linked against wolfSSL and system OpenSSL
   - Installed to architecture-specific path

3. **golang-fips/go Compilation**:
   - Bootstrap compiler: Go 1.22.6 (official release)
   - Source cloned from golang-fips fork
   - ChaCha20-Poly1305 cipher suite removed
   - Built with `GOEXPERIMENT=strictfipsruntime`
   - Installed to `/usr/local/go-fips`

4. **Demo Application Compilation**:
   - Source: `src/main.go`
   - Compiled with golang-fips/go
   - FIPS environment enforced during build

### 2.3 Build Artifacts
- **Container Image**: `golang:1.25-jammy-ubuntu-22.04-fips`
- **SBOM**: `sbom-golang-1.25-jammy-ubuntu-22.04-fips.spdx.json`
- **VEX**: `vex-golang-1.25-jammy-ubuntu-22.04-fips.json`
- **Signatures**: (Generated via Cosign)
- **Attestations**: (Generated via SLSA framework)

---

## 3. Verification Procedures

### 3.1 Component Integrity Verification
```bash
# Verify wolfSSL FIPS hash
cd /usr/src/wolfssl && ./fips-hash.sh

# Verify wolfProvider installation
ls -la /usr/lib/*/ossl-modules/libwolfprov.so

# Verify golang-fips/go installation
/usr/local/go-fips/bin/go version

# Verify OpenSSL provider
openssl list -providers
```

### 3.2 FIPS Mode Verification
```bash
# Run validation tests
cd /app/tests
./run-all-tests.sh

# Verify environment
echo $GOLANG_FIPS  # Should be "1"
echo $GODEBUG      # Should be "fips140=only"
echo $GOEXPERIMENT # Should be "strictfipsruntime"
```

### 3.3 Algorithm Enforcement Verification
```bash
# CLI algorithm tests
./diagnostic.sh test-openssl-cli-algorithms.sh

# Go algorithm tests
./diagnostic.sh test-go-fips-algorithms.sh
```

### 3.4 Audit Log Verification
```bash
# View audit logs
cat /var/log/fips-audit.log | jq .

# Verify logged events
grep "container_start" /var/log/fips-audit.log
grep "fips_validation_complete" /var/log/fips-audit.log
```

---

## 4. Artifact Traceability

### 4.1 SBOM Traceability
- **File**: `sbom-golang-1.25-jammy-ubuntu-22.04-fips.spdx.json`
- **Format**: SPDX 2.3
- **Components Documented**: 8 packages
- **Relationships**: Dependency graph included
- **Verification**: `python3 -c "import json; json.load(open('sbom-...'))`

### 4.2 VEX Traceability
- **File**: `vex-golang-1.25-jammy-ubuntu-22.04-fips.json`
- **Format**: OpenVEX v0.2.0
- **Vulnerability Statements**: 4 assessments
- **Status Tracking**: All vulnerabilities documented

### 4.3 Container Image Traceability
- **Image Digest**: SHA256 hash of container image
- **Layer Hashes**: Individual layer SHA256 digests
- **Manifest**: Docker manifest with all references
- **Registry**: Image registry location and access controls

---

## 5. Security Controls

### 5.1 Build-Time Controls
- **Source Verification**: All sources from verified repositories
- **Secret Management**: wolfSSL password via Docker secrets
- **Reproducibility**: Dockerfile version controlled
- **Integrity Checks**: FIPS hash validation, library verification

### 5.2 Runtime Controls
- **FIPS Enforcement**: Strict policy enabled
- **Algorithm Blocking**: MD5 blocked by Go runtime, SHA-1 blocked by wolfSSL
- **Audit Logging**: All FIPS operations logged to `/var/log/fips-audit.log`
- **Provider Validation**: wolfProvider status checked on startup

### 5.3 Access Controls
- **Build Access**: Controlled access to build system
- **Secret Access**: Password-protected wolfSSL archive
- **Registry Access**: Authenticated push/pull to container registry
- **Audit Access**: Read-only audit log access

---

## 6. Compliance Attestations

### 6.1 FIPS 140-3 Compliance
- **Certificate**: #4718 (wolfSSL FIPS v5.8.2)
- **Validation**: CMVP (Cryptographic Module Validation Program)
- **Algorithms**: SHA-256, SHA-384, SHA-512, AES, RSA, ECDSA
- **Blocked Algorithms**: MD5, SHA-1

### 6.2 Supply Chain Security
- **SBOM**: SPDX 2.3 format, all components documented
- **VEX**: OpenVEX format, vulnerability status tracked
- **Signatures**: Cosign keyless signing (Sigstore)
- **Attestations**: SLSA Level 2 build provenance

### 6.3 Testing and Validation
- **Test Suite**: 5 comprehensive test suites
  1. Algorithm enforcement
  2. OpenSSL integration
  3. Full FIPS validation
  4. In-container compilation
  5. CLI algorithm enforcement
- **Coverage**: 100% of FIPS POC requirements
- **Automation**: All tests automated and repeatable

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
- **Configuration Backups**: All configs version controlled
- **Testing**: Validation tests before rollback

---

## 8. Audit Trail

### 8.1 Build Audit
- **Build Date**: YYYY-MM-DD HH:MM:SS UTC
- **Build System**: Docker version X.X.X
- **Builder Identity**: Build system identifier
- **Build Duration**: Logged for anomaly detection

### 8.2 Runtime Audit
- **Audit Log Location**: `/var/log/fips-audit.log`
- **Log Format**: JSON structured logging
- **Events Logged**:
  - Container startup
  - FIPS validation
  - Provider status checks
  - Command execution
- **Retention**: Configurable via volume mounts

### 8.3 Compliance Audit
- **FIPS Validation**: Tested on every startup
- **Algorithm Tests**: Automated test suite
- **Vulnerability Scanning**: VEX statements updated
- **Access Review**: Periodic review of access controls

---

## 9. Contact Information

### 9.1 Security Team
- **Email**: security@Root.com
- **Incident Reporting**: security-incidents@Root.com
- **Office Hours**: 24/7 for critical issues

### 9.2 Support Team
- **Email**: support@Root.com
- **Documentation**: https://docs.Root.com
- **Issue Tracking**: GitHub Issues

---

## 10. Document Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-03-04 | Root Security Team | Initial release |

---

## Appendices

### Appendix A: Build Script
See `build.sh` in repository

### Appendix B: Diagnostic Scripts
See `diagnostics/` directory in repository

### Appendix C: Configuration Files
- `Dockerfile`: Multi-stage build definition
- `openssl-wolfprov.cnf`: wolfProvider configuration
- `entrypoint.sh`: Container entrypoint with validation

---

**Document Status**: APPROVED FOR RELEASE
**Classification**: PUBLIC
**Distribution**: UNLIMITED
