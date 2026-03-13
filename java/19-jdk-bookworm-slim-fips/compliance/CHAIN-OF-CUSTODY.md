# Chain of Custody: java:19-jdk-bookworm-slim-fips

## Document Information
- **Image Name**: java
- **Version**: 19-jdk-bookworm-slim-fips
- **Date**: 2026-03-04
- **Document Version**: 1.0
- **Author**: Root Security Team

## Executive Summary

This document establishes the chain of custody for the java container image, documenting its complete provenance from source materials through build process to final artifact. This image provides a FIPS 140-3 compliant Java runtime environment with strict security policy enforcement.

---

## 1. Component Provenance

### 1.1 Base Image
- **Component**: Debian 12 (Bookworm) Slim with OpenJDK 19
- **Source**: `rootpublic/openjdk:19-jdk-bookworm-slim`
- **Verification**: Container registry verification
- **SHA256**: Verified via Docker image manifest
- **Purpose**: Operating system foundation and Java runtime

### 1.2 wolfSSL FIPS Module
- **Component**: wolfSSL FIPS v5.8.2 (bundled with FIPS v5.2.3)
- **Source**: `https://www.wolfssl.com/comm/wolfssl/wolfssl-5.8.2-commercial-fips-v5.2.3.7z`
- **FIPS Certificate**: #4718 (FIPS 140-3 validated)
- **Verification**: Password-protected archive (BuildKit secret), FIPS hash verification via `fips-hash.sh`
- **Build Configuration**: `--enable-fips=v5 --enable-jni --disable-md5`
- **Purpose**: FIPS-validated cryptographic module for JNI integration

### 1.3 wolfCrypt JNI (JCE Provider)
- **Component**: wolfcrypt-jni (from GitHub master branch)
- **Source**: `https://github.com/wolfSSL/wolfcrypt-jni.git`
- **Build**: Ant build system, JUnit 4 tests executed
- **Artifacts**: libwolfcryptjni.so, wolfcrypt-jni.jar
- **Purpose**: Java JCE provider (WolfCryptProvider) backed by wolfSSL FIPS

### 1.4 wolfSSL JNI (JSSE Provider)
- **Component**: wolfssljni (from GitHub master branch)
- **Source**: `https://github.com/wolfSSL/wolfssljni.git`
- **Build**: Ant build system, JUnit 4 tests executed
- **Artifacts**: libwolfssljni.so, wolfssl-jsse.jar
- **Purpose**: Java JSSE provider (WolfSSLProvider) for TLS/SSL

### 1.5 Java Security Policy
- **Component**: Custom java.security configuration
- **Source**: `java.security` (included in repository)
- **Modifications**:
  - `security.provider.1`: com.wolfssl.provider.jce.WolfCryptProvider
  - `security.provider.2`: com.wolfssl.provider.jsse.WolfSSLProvider
  - `keystore.type`: WKS (WolfSSL KeyStore format)
  - `jdk.tls.disabledAlgorithms`: MD5, SHA-1, DSA, RC4, DES, weak TLS versions blocked
  - `jdk.certpath.disabledAlgorithms`: MD5, SHA-1, weak key sizes blocked
  - `jdk.jar.disabledAlgorithms`: MD5, SHA-1 blocked for JAR signing
  - `crypto.policy`: unlimited
- **Purpose**: FIPS policy enforcement at JDK level

### 1.6 System Dependencies
- **JUnit/Hamcrest**: JUnit 4.13.2, Hamcrest 1.3 (for build-time testing)
- **Source**: Maven Central Repository
- **CA Certificates**: Converted from JKS to WKS format using wolfcrypt-jni
- **Build Tools**: gcc, g++, make, automake, autoconf, libtool, git, ant, curl, p7zip-full
- **Source**: Debian Bookworm official repositories
- **Verification**: APT package manager, package signatures

---

## 2. Build Process

### 2.1 Build Environment
- **Build System**: Docker multi-stage build with BuildKit
- **Build File**: `Dockerfile` (committed to repository)
- **Build Command**:
  ```bash
  DOCKER_BUILDKIT=1 docker build -t java:19-jdk-bookworm-slim-fips \
    --secret id=wolfssl_pw,src=.wolfssl_password .
  ```
- **Build Stages**:
  1. builder: Base build environment with JDK and build tools
  2. wolfssl-builder: Compiles wolfSSL FIPS v5.2.3 with JNI support
  3. wolfjce-builder: Compiles wolfCrypt JNI (JCE provider)
  4. wolfjsse-builder: Compiles wolfSSL JNI (JSSE provider)
  5. java-compiler: Compiles Java application code (FipsInitCheck, filtered providers)
  6. Runtime: Final minimal image with OpenJDK 19 and wolfSSL providers

### 2.2 Build Steps Verification
1. **wolfSSL FIPS Compilation**:
   - Source extracted from password-protected 7z archive using BuildKit secret
   - Configured with `--enable-fips=v5 --enable-jni --disable-md5`
   - FIPS in-core integrity hash set via `fips-hash.sh`
   - Compiled twice (before and after hash update per FIPS requirements)
   - wolfCrypt test suite executed (`testwolfcrypt`)
   - Libraries installed to `/usr/local/lib`

2. **wolfCrypt JNI Compilation**:
   - Cloned from GitHub wolfcrypt-jni repository
   - JUnit/Hamcrest dependencies downloaded from Maven Central
   - Native library built using makefile.linux
   - JAR built using Ant (build-jce-release target)
   - JUnit tests executed (`ant test`)
   - System CA certificates converted from JKS to WKS format

3. **wolfSSL JNI Compilation**:
   - Cloned from GitHub wolfssljni repository
   - Native library and JAR built using Ant
   - JUnit tests executed (`ant test`)
   - TLS/SSL provider artifacts generated

4. **Java Application Compilation**:
   - Source: `src/main/FipsInitCheck.java`, `src/providers/*.java`
   - Compiled with OpenJDK 19 compiler (`javac`)
   - Classpath includes wolfcrypt-jni.jar and wolfssl-jsse.jar
   - JAR created for filtered Sun providers

5. **Java Security Configuration**:
   - Original `java.security` backed up to java.security.backup
   - Custom FIPS-compliant java.security installed
   - WKS-format CA certificates (cacerts.wks) replace default JKS cacerts
   - Installed to `${JAVA_HOME}/conf/security/` and `${JAVA_HOME}/lib/security/`

### 2.3 Build Artifacts
- **Container Image**: `java:19-jdk-bookworm-slim-fips`
- **SBOM**: `SBOM-java-19-jdk-bookworm-slim-fips.spdx.json`
- **VEX**: `vex-java-19-jdk-bookworm-slim-fips.json`
- **Signatures**: (Generated via Cosign)
- **Attestations**: (Generated via SLSA framework)

---

## 3. Verification Procedures

### 3.1 Component Integrity Verification
```bash
# Verify wolfSSL FIPS library
ls -la /usr/local/lib/libwolfssl.so*

# Verify wolfCrypt JNI and wolfSSL JNI
ls -la /usr/lib/jni/libwolfcryptjni.so
ls -la /usr/lib/jni/libwolfssljni.so

# Verify JAR files
ls -la /usr/share/java/wolfcrypt-jni.jar
ls -la /usr/share/java/wolfssl-jsse.jar
ls -la /usr/share/java/filtered-providers.jar

# Verify Java runtime
java -version

# Run integrity check script
/usr/local/bin/integrity-check.sh
```

### 3.2 FIPS Mode Verification
```bash
# Run entrypoint FIPS validation
/docker-entrypoint.sh java -version

# Run Java FIPS init check directly
java -cp "/opt/wolfssl-fips/bin:/usr/share/java/*" FipsInitCheck

# Verify Java security providers
grep "security.provider" ${JAVA_HOME}/conf/security/java.security

# Verify keystore type
grep "keystore.type" ${JAVA_HOME}/conf/security/java.security
```

### 3.3 Algorithm Enforcement Verification
```bash
# Run Java algorithm enforcement tests
./diagnostics/test-java-algorithm-enforcement.sh

# Run Java algorithm availability tests
./diagnostics/test-java-algorithms.sh

# Verify disabled algorithms in policy
grep "jdk.tls.disabledAlgorithms" ${JAVA_HOME}/conf/security/java.security
grep "jdk.certpath.disabledAlgorithms" ${JAVA_HOME}/conf/security/java.security
grep "jdk.jar.disabledAlgorithms" ${JAVA_HOME}/conf/security/java.security
```

### 3.4 Runtime Validation
```bash
# View container startup logs
docker logs <container-id>

# Verify integrity check passed
docker logs <container-id> | grep "FIPS COMPONENTS INTEGRITY VERIFIED"

# Verify FIPS validation passed
docker logs <container-id> | grep "All Container Tests Passed"

# Check for any validation failures
docker logs <container-id> | grep "ERROR"
```

---

## 4. Artifact Traceability

### 4.1 SBOM Traceability
- **File**: `SBOM-java-19-jdk-bookworm-slim-fips.spdx.json`
- **Format**: SPDX 2.3
- **Components Documented**: 8 packages
- **Relationships**: Dependency graph included
- **Verification**: `python3 -c "import json; json.load(open('sbom-...')"`

### 4.2 VEX Traceability
- **File**: `vex-java-19-jdk-bookworm-slim-fips.json`
- **Format**: OpenVEX v0.2.0
- **Vulnerability Statements**: 5 assessments (including Log4Shell)
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
- **Backup Policy**: Original java.security backed up before modification

### 5.2 Runtime Controls
- **FIPS Enforcement**: Java Security providers enforced (WolfCryptProvider, WolfSSLProvider)
- **Integrity Verification**: SHA-256 checksums validated on startup via integrity-check.sh
- **Provider Validation**: FipsInitCheck.java validates providers on container startup
- **Algorithm Blocking via java.security**:
  - MD5, MD4, MD2, SHA-1 blocked for TLS/JAR/CertPath operations
  - DSA, RC4, DES, DESede, Ed25519, Ed448 completely disabled
  - Weak TLS versions blocked (SSLv3, TLS 1.0, TLS 1.1)
  - Weak key sizes blocked (RSA < 2048, EC < 224, DH < 2048)
- **Keystore Format**: WKS (WolfSSL KeyStore) - FIPS-compliant format only
- **Container Termination**: Validation failures cause container to exit (fail-fast)

### 5.3 Access Controls
- **Build Access**: Controlled access to build system
- **Secret Access**: Password-protected wolfSSL archive
- **Registry Access**: Authenticated push/pull to container registry
- **Audit Access**: Read-only audit log access

---

## 6. Compliance Attestations

### 6.1 FIPS 140-3 Compliance
- **Certificate**: #4718 (wolfSSL FIPS v5.2.3)
- **Validation**: CMVP (Cryptographic Module Validation Program)
- **JCE Provider**: WolfCryptProvider (com.wolfssl.provider.jce.WolfCryptProvider)
- **JSSE Provider**: WolfSSLProvider (com.wolfssl.provider.jsse.WolfSSLProvider)
- **Approved Algorithms**: SHA-256, SHA-384, SHA-512, AES, RSA (≥2048), ECDSA
- **Blocked Algorithms**: MD5, MD4, MD2, SHA-1 (for most uses), DSA, RC4, DES, DESede
- **Java Security**: crypto.policy=unlimited, keystore.type=WKS
- **Provider Priority**: wolfJCE (#1), wolfJSSE (#2) take precedence over Sun providers

### 6.2 Supply Chain Security
- **SBOM**: SPDX 2.3 format, all components documented
- **VEX**: OpenVEX format, vulnerability status tracked (including Log4Shell assessment)
- **Signatures**: Cosign keyless signing (Sigstore)
- **Attestations**: SLSA Level 2 build provenance

### 6.3 Testing and Validation
- **Build-Time Tests**:
  1. wolfCrypt native test suite (testwolfcrypt)
  2. wolfCrypt JNI JUnit tests (ant test)
  3. wolfSSL JNI JUnit tests (ant test)
- **Runtime Tests**:
  1. Library integrity verification (integrity-check.sh)
  2. Java FIPS provider validation (FipsInitCheck.java)
  3. Algorithm enforcement tests (test-java-algorithms.sh)
  4. FIPS validation tests (test-java-fips-validation.sh)
- **Coverage**: 100% of FIPS POC requirements
- **Automation**: All tests automated and repeatable
- **Fail-Fast**: Container exits if any validation fails

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
- **Configuration Backups**: java.security.backup preserved
- **Testing**: Validation tests before rollback

---

## 8. Audit Trail

### 8.1 Build Audit
- **Build Date**: YYYY-MM-DD HH:MM:SS UTC
- **Build System**: Docker version X.X.X
- **Builder Identity**: Build system identifier
- **Build Duration**: Logged for anomaly detection

### 8.2 Runtime Audit
- **Entrypoint Logging**: docker-entrypoint.sh outputs to stdout/stderr
- **Validation Output**: Visible in `docker logs <container-id>`
- **Events Logged**:
  - Container startup
  - Library integrity verification (SHA-256)
  - FIPS provider validation
  - Java Security provider checks
  - WKS keystore validation
  - Command execution
- **Fail-Fast Behavior**: Container exits with error code if validation fails
- **Retention**: Container logs retained per Docker/Kubernetes log retention policy

### 8.3 Compliance Audit
- **FIPS Validation**: Tested on every startup
- **Algorithm Tests**: Automated test suite
- **Vulnerability Scanning**: VEX statements updated (Log4Shell explicitly addressed)
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
- `Dockerfile`: Multi-stage build definition (6 stages)
- `java.security`: Java FIPS security policy with wolfSSL providers
- `docker-entrypoint.sh`: Container entrypoint with integrity and FIPS validation
- `scripts/integrity-check.sh`: SHA-256 checksum verification script
- `src/main/FipsInitCheck.java`: Java FIPS provider validation program

### Appendix D: Java Security Policy
Key security settings applied:
- `security.provider.1`: com.wolfssl.provider.jce.WolfCryptProvider
- `security.provider.2`: com.wolfssl.provider.jsse.WolfSSLProvider
- `keystore.type`: WKS (WolfSSL KeyStore format)
- `jdk.tls.disabledAlgorithms`: SSLv3, TLS1.0, TLS1.1, RC4, DES, MD5withRSA, DSA, Ed25519, Ed448
- `jdk.certpath.disabledAlgorithms`: MD2, MD4, MD5, RC4, DES, DESede, Ed25519, Ed448, EdDSA, DSA, RSA keySize < 1024
- `jdk.jar.disabledAlgorithms`: MD2, MD4, MD5, RC4, DES, DESede, Ed25519, Ed448, EdDSA, DSA, RSA keySize < 2048
- `jdk.tls.ephemeralDHKeySize`: 2048
- `crypto.policy`: unlimited

---

**Document Status**: APPROVED FOR RELEASE
**Classification**: PUBLIC
**Distribution**: UNLIMITED
