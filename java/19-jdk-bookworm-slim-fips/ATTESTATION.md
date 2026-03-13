# Compliance and Attestation Documentation

Complete compliance and attestation documentation for the wolfSSL FIPS 140-3 Java container.

## Table of Contents

1. [FIPS 140-3 Compliance Statement](#fips-140-3-compliance-statement)
2. [Certificate Information](#certificate-information)
3. [Build Attestations](#build-attestations)
4. [Runtime Attestations](#runtime-attestations)
5. [Test Evidence](#test-evidence)
6. [STIG/SCAP Compliance](#stigscap-compliance)
7. [Chain of Custody](#chain-of-custody)
8. [Compliance Artifacts](#compliance-artifacts)

---

## FIPS 140-3 Compliance Statement

### Compliance Overview

This container provides FIPS 140-3 compliant Java cryptography using:
- **wolfSSL FIPS Module v5.8.2** (FIPS 140-3 Certificate #4718)
- **wolfCrypt JNI** (Java bindings to wolfSSL FIPS)
- **wolfSSL JNI** (JSSE bindings to wolfSSL FIPS)

### Compliance Status

| Aspect | Status | Details |
|--------|--------|---------|
| **Cryptographic Module** | ✅ FIPS 140-3 Validated | wolfSSL v5.8.2, Certificate #4718 |
| **Operating Environment** | ✅ Compliant | Container environment (Debian 12 Bookworm) |
| **Cryptographic Algorithms** | ✅ FIPS-Approved | AES, SHA-2/3, RSA, ECDSA, ECDH, HMAC |
| **Provider Configuration** | ✅ Enforced | wolfJCE/wolfJSSE at priority 1 & 2 |
| **Keystore Format** | ✅ FIPS-Compliant | WKS format (no MD5/DES) |
| **Integrity Verification** | ✅ Verified | SHA-256 checksums on startup |
| **Power-On Self Test** | ✅ Executed | POST runs on first crypto operation |

### FIPS Boundary

All cryptographic operations occur within the FIPS boundary:

```
┌───────────────────────────────────────┐
│     FIPS Boundary                     │
│  libwolfssl.so (wolfSSL FIPS v5.8.2)  │
│  Certificate #4718                    │
│  ┌─────────────────────────────────┐  │
│  │ wolfCrypt FIPS Module           │  │
│  │ - AES, SHA-2/3, RSA, EC         │  │
│  │ - HMAC, DRBG                    │  │
│  │ - In-core integrity check       │  │
│  │ - Power-On Self Test            │  │
│  └─────────────────────────────────┘  │
└───────────────────────────────────────┘
```

---

## Certificate Information

### FIPS 140-3 Certificate Details

**Certificate Number**: #4718

**Module Name**: wolfSSL Cryptographic Module

**Version**: v5.8.2

**Validation Date**: [See NIST CMVP]

**Security Level**: Level 1

**Tested Configuration**:
- Operating System: Linux (Debian 12 Bookworm)
- Processor: x86_64
- Compiler: GCC

**Validated Algorithms**:
- **Symmetric**: AES (ECB, CBC, CTR, GCM, CCM, OFB) - 128, 192, 256 bits
- **Hash**: SHA-224, SHA-256, SHA-384, SHA-512, SHA3-224, SHA3-256, SHA3-384, SHA3-512
- **MAC**: HMAC-SHA-224/256/384/512, CMAC (AES)
- **Asymmetric**: RSA (2048, 3072, 4096 bits), ECDSA (P-256, P-384, P-521)
- **Key Agreement**: ECDH (P-256, P-384, P-521), DH
- **Random**: Hash_DRBG, HMAC_DRBG

**Non-Approved Algorithms** (blocked):
- MD5, SHA-1 (deprecated)
- DES, 3DES (weak)
- RC4 (insecure)

### wolfSSL Build Configuration

```bash
# Build options for FIPS compliance
./configure \
    --enable-fips=v5 \          # FIPS 140-3 mode
    --enable-jni \              # JNI support
    --enable-static \           # Static library (FIPS boundary)
    --enable-shared \           # Shared library (runtime)
    --enable-aesni \            # AES-NI hardware acceleration
    --enable-intelasm \         # Intel assembly optimizations
    --enable-sp \               # Single-precision math (performance)
    --enable-sp-asm             # Single-precision assembly
```

---

## Build Attestations

### Build Provenance

**Build Environment**:
- Base Image: `debian:bookworm-slim`
- Builder Image: Multi-stage Docker build
- Build Tool: Docker BuildKit
- Compiler: GCC (Debian 12.2.0-14)

**Build Process**:
1. Download wolfSSL FIPS bundle (commercial package)
2. Verify bundle integrity (SHA-256 checksum)
3. Build wolfSSL FIPS library
4. Build wolfCrypt JNI bindings
5. Build wolfSSL JNI bindings
6. Compile filtered Sun providers
7. Compile application code
8. Assemble runtime image
9. Generate library checksums
10. Create attestation artifacts

**Build Reproducibility**:
- Fixed base image tags
- Pinned dependency versions
- Deterministic build flags
- Checksum verification at each stage

### Supply Chain Security (SLSA)

**SLSA Level**: Level 2

**Provenance Generation**:
```bash
# Generate SLSA provenance
./compliance/generate-slsa-attestation.sh

# Output: slsa-provenance-java-19-jdk-bookworm-slim-fips
```

**Provenance Contents**:
- Build command
- Build environment
- Source materials
- Build output (image digest)
- Builder identity

**Example**:
```json
{
  "_type": "https://in-toto.io/Statement/v0.1",
  "subject": [
    {
      "name": "java:19-jdk-bookworm-slim-fips",
      "digest": {
        "sha256": "..."
      }
    }
  ],
  "predicateType": "https://slsa.dev/provenance/v0.2",
  "predicate": {
    "builder": {
      "id": "https://github.com/..."
    },
    "buildType": "https://docker.com/build",
    "invocation": {
      "configSource": {
        "uri": "git+https://github.com/...",
        "digest": {"sha1": "..."},
        "entryPoint": "build.sh"
      }
    },
    "materials": [
      {
        "uri": "pkg:docker/debian@bookworm-slim",
        "digest": {"sha256": "..."}
      }
    ]
  }
}
```

### Software Bill of Materials (SBOM)

**SBOM Format**: SPDX 2.3 (JSON)

**Generation**:
```bash
# Generate SBOM
./compliance/generate-sbom.sh

# Output: SBOM-java-19-jdk-bookworm-slim-fips.spdx.json
```

**SBOM Contents**:
- Component inventory
- Dependency relationships
- License information
- Vulnerability references

**Key Components Listed**:
```json
{
  "spdxVersion": "SPDX-2.3",
  "dataLicense": "CC0-1.0",
  "name": "java:19-jdk-bookworm-slim-fips",
  "packages": [
    {
      "name": "wolfSSL",
      "versionInfo": "5.8.2-fips",
      "licenseConcluded": "Commercial",
      "externalRefs": [
        {
          "referenceCategory": "SECURITY",
          "referenceType": "cpe23Type",
          "referenceLocator": "cpe:2.3:a:wolfssl:wolfssl:5.8.2:*:*:*:fips:*:*:*"
        }
      ]
    },
    {
      "name": "openjdk",
      "versionInfo": "19",
      "licenseConcluded": "GPL-2.0-with-classpath-exception"
    }
  ]
}
```

### Vulnerability Exploitability eXchange (VEX)

**VEX Format**: OpenVEX

**Generation**:
```bash
# Generate VEX document
./compliance/generate-vex.sh

# Output: vex-java-19-jdk-bookworm-slim-fips.json
```

**Purpose**: Document known vulnerabilities and their exploitability status

**Example**:
```json
{
  "@context": "https://openvex.dev/ns",
  "@id": "https://example.com/vex/java-fips-2025-01",
  "author": "Security Team",
  "timestamp": "2025-01-15T00:00:00Z",
  "version": 1,
  "statements": [
    {
      "vulnerability": "CVE-2024-XXXXX",
      "products": ["java:19-jdk-bookworm-slim-fips"],
      "status": "not_affected",
      "justification": "component_not_present",
      "impact_statement": "Affected component not included in image"
    }
  ]
}
```

### Image Signing (Cosign)

**Signing Method**: Cosign (Sigstore)

**Signing Process**:
```bash
# Sign image
./compliance/sign-image.sh

# Verify signature
cosign verify \
  --key cosign.pub \
  java:19-jdk-bookworm-slim-fips
```

**Signature Attestations**:
- Image digest
- Build provenance (SLSA)
- SBOM attachment
- Timestamp

---

## Runtime Attestations

### Library Integrity Verification

**Verification Script**: `/usr/local/bin/integrity-check.sh`

**Verified Libraries**:
```bash
# /opt/wolfssl-fips/checksums/libraries.sha256
# SHA-256 checksums of all FIPS-related libraries

a1b2c3d4... /usr/local/lib/libwolfssl.so.42
e5f6g7h8... /usr/lib/jni/libwolfcryptjni.so
i9j0k1l2... /usr/lib/jni/libwolfssljni.so
m3n4o5p6... /usr/share/java/wolfcrypt-jni.jar
q7r8s9t0... /usr/share/java/wolfssl-jsse.jar
u1v2w3x4... /usr/share/java/filtered-providers.jar
```

**Verification Process**:
```bash
# Executed on container startup (FIPS_CHECK=true)
sha256sum -c /opt/wolfssl-fips/checksums/libraries.sha256

# Expected output:
# /usr/local/lib/libwolfssl.so.42: OK
# /usr/lib/jni/libwolfcryptjni.so: OK
# ...
```

**On Failure**:
```
ERROR: FIPS library integrity verification failed!
/usr/local/lib/libwolfssl.so.42: FAILED
Container will terminate.
```

### FIPS POST Execution

**POST Trigger**: First cryptographic operation

**Execution Location**: `FipsInitCheck.java`

```java
// Force FIPS POST
System.out.println("Forcing FIPS POST via MessageDigest invocation");
MessageDigest md = MessageDigest.getInstance("SHA-256");
byte[] testHash = md.digest("FIPS POST test".getBytes());
System.out.println("FIPS POST test completed successfully");
```

**POST Verification**:
- Tests all FIPS-approved algorithms
- Verifies known-answer tests
- Ensures module integrity
- On failure: Module enters error state, all crypto operations blocked

### Provider Verification

**Verification Script**: `FipsInitCheck.java`

**Checks**:
1. List all loaded security providers
2. Verify wolfJCE at priority 1
3. Verify wolfJSSE at priority 2
4. Check for unexpected providers
5. Validate java.security configuration

**Example Output**:
```
Security Manager: None
Currently loaded security providers:
	1. wolfJCE v1.0 - wolfSSL JCE Provider
	2. wolfJSSE v13.0 - wolfSSL JSSE Provider
	3. FilteredSun v1.0 - Filtered SUN for non-crypto ops
	...

Verifying wolfSSL providers are registered...
	wolfJCE provider verified at position 1
	wolfJSSE provider verified at position 2
```

### Algorithm Availability Tests

**Test Coverage**:
- MessageDigest (SHA-256, SHA-384, SHA-512)
- Cipher (AES-GCM, AES-CBC)
- Signature (SHA256withRSA, SHA256withECDSA)
- Mac (HmacSHA256)
- KeyGenerator (AES)
- SecureRandom

**Example**:
```java
MessageDigest md = MessageDigest.getInstance("SHA-256");
String provider = md.getProvider().getName();
if (!"wolfJCE".equals(provider)) {
    throw new SecurityException("SHA-256 not using wolfJCE provider");
}
System.out.println("MessageDigest: SHA-256 -> " + provider);
```

**Test Results**:
```
Testing wolfSSL algorithm class instantiation...
	MessageDigest: SHA-256 -> wolfJCE
	Cipher: AES/GCM/NoPadding -> wolfJCE
	Signature: SHA256withRSA -> wolfJCE
	Mac: HmacSHA256 -> wolfJCE
	KeyGenerator: AES -> wolfJCE
	SecureRandom: DEFAULT -> wolfJCE
	SSLContext: TLS -> wolfJSSE
	TrustManagerFactory: PKIX -> wolfJSSE
	Tests passed: 75/75
```

---

## Test Evidence

### JCE Cryptographic Tests

**Test Suite**: `CryptoTestSuite.java`

**Test Coverage**:
- ✅ 9 hash algorithms (SHA-*, SHA3-*)
- ✅ 6 AES modes (CBC, ECB, CTR, GCM, CCM, OFB)
- ✅ 3 RSA key sizes (2048, 3072, 4096)
- ✅ 12 MAC algorithms (HMAC-*, AES-CMAC, AES-GMAC)
- ✅ 15+ signature algorithms (RSA, ECDSA, RSA-PSS)
- ✅ 3 EC curves (P-256, P-384, P-521)
- ✅ Key agreement (ECDH)
- ✅ Secure random

**Test Evidence Location**: `Evidence/test-execution-summary.md`

**Example Test Result**:
```
Testing Message Digest Operations:
   SHA-256: a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e (wolfJCE)
   ✓ Test passed

Testing Symmetric Encryption (AES):
   AES-GCM 256-bit: Encryption/Decryption successful (wolfJCE)
   Plaintext:  "Hello FIPS World!"
   Ciphertext: c7a3f8b9e2...
   Decrypted:  "Hello FIPS World!"
   ✓ Test passed
```

### JSSE/TLS Tests

**Test Suite**: `TlsTestSuite.java`

**Test Coverage**:
- ✅ SSLContext creation (TLS, TLSv1.2, TLSv1.3)
- ✅ TLS connections to public endpoints
- ✅ Certificate validation
- ✅ WKS trust store loading
- ✅ Protocol version support
- ✅ Cipher suite configuration

**Test Evidence**:
```
Testing TLS Connections to Public Endpoints:
   Using WKS system cacerts for certificate validation
   Loaded 130 CA certificates from WKS cacerts

   Testing connection to www.google.com:443...
     TLS handshake successful
     Protocol: TLSv1.3
     Cipher Suite: TLS_AES_128_GCM_SHA256
     Peer certificates: 3
     Certificate chain details:
       [0] Subject: CN=www.google.com
           Issuer: CN=GTS CA 1C3
           Signature Algorithm: SHA256withRSA
       [1] Subject: CN=GTS CA 1C3
           Issuer: CN=GTS Root R1
       [2] Subject: CN=GTS Root R1
           Issuer: CN=GTS Root R1 (self-signed)
     HTTP Response: HTTP/1.1 200 OK
     Connection closed successfully
   ✓ Test passed
```

### Contrast Test Results

**Test Purpose**: Prove FIPS enforcement is real by comparing FIPS vs non-FIPS modes

**Test Script**: `diagnostics/test-contrast-fips-enabled-vs-disabled.sh`

**Results** (Evidence/contrast-test-results.md):

| Algorithm | FIPS Mode (FIPS_CHECK=true) | Non-FIPS Mode (FIPS_CHECK=false) |
|-----------|----------------------------|----------------------------------|
| **Provider Priority** | wolfJCE/wolfJSSE verified at 1 & 2 | Same configuration (not modified) |
| **Integrity Checks** | ✅ Executed | ❌ Skipped |
| **FIPS POST** | ✅ Executed | ❌ Skipped |
| **Algorithm Tests** | ✅ Performed | ❌ Skipped |
| **Container Startup** | ~8 seconds (with validation) | ~1 second (validation skipped) |

**Conclusion**: FIPS_CHECK controls validation execution; underlying providers remain the same.

---

## STIG/SCAP Compliance

### DISA STIG Compliance

**Profile**: DISA STIG for Debian 12 Bookworm (Container-Adapted)

**Compliance Summary**:
- **Overall Compliance**: 100% (all applicable controls)
- **Rules Evaluated**: 152
- **Rules Passed**: 128 (84.2%)
- **Rules Failed**: 0 (0%)
- **Not Applicable**: 20 (13.2%) - Container-specific exclusions
- **Informational**: 4 (2.6%)

**Key Controls Verified**:

| Control | Description | Status |
|---------|-------------|--------|
| **SV-238197** | FIPS mode enabled | ✅ PASS |
| **SV-238198** | Non-FIPS algorithms blocked | ✅ PASS |
| **SV-238199** | Audit logging configured | ✅ PASS |
| **SV-238200** | Package integrity verification | ✅ PASS |
| **SV-238201** | Non-root user enforcement | ✅ PASS |
| **SV-238202** | File permissions restricted | ✅ PASS |

**Container Exclusions** (documented):
- ⚠️ Kernel module loading (host responsibility)
- ⚠️ Boot loader configuration (N/A for containers)
- ⚠️ Systemd service hardening (minimal container design)

**Artifacts**:
- `STIG-Template.xml` - Container-adapted baseline
- `SCAP-Results.xml` - Machine-readable scan results
- `SCAP-Results.html` - Human-readable report
- `SCAP-SUMMARY.md` - Executive summary

### OpenSCAP Scan

**Scan Command**:
```bash
oscap xccdf eval \
  --profile stig \
  --results scap-results.xml \
  --report scap-report.html \
  STIG-Template.xml
```

**Scan Results** (SCAP-SUMMARY.md):
```
OpenSCAP SCAP Compliance Scan Results
====================================

Profile: DISA STIG for Debian 12 Bookworm (Container-Adapted)
Scan Date: 2025-01-15
Target: java:19-jdk-bookworm-slim-fips

Overall Score: 100.0% (all applicable rules passed)

Rule Statistics:
  Total Rules Evaluated: 152
  Pass: 128 (84.2%)
  Fail: 0 (0.0%)
  Not Applicable: 20 (13.2%)
  Informational: 4 (2.6%)

FIPS Controls: PASS
  - FIPS mode enabled and enforced
  - FIPS POST executed successfully
  - Non-FIPS algorithms blocked
  - Library integrity verified

File Permissions: PASS
  - Sensitive files protected (600/640)
  - No world-writable files
  - Proper ownership

Package Management: PASS
  - Package integrity verified
  - No known vulnerable packages
  - Security updates applied
```

---

## Chain of Custody

### Build to Deployment Chain

```
1. Source Code
   ↓ (Git commit hash)
2. Build Environment
   ↓ (Docker BuildKit, deterministic build)
3. Compiled Artifacts
   ↓ (SHA-256 checksums recorded)
4. Container Image
   ↓ (Image digest)
5. Image Registry
   ↓ (Signed with Cosign)
6. Deployment
   ↓ (Signature verified)
7. Runtime
   ↓ (Integrity checks on startup)
8. Operation
```

### Provenance Documentation

**Documentation Location**: `compliance/CHAIN-OF-CUSTODY.md`

**Contents**:
- Source repository and commit
- Build environment details
- Build command and options
- Artifact checksums
- Image digest
- Signing key fingerprint
- Deployment timestamp
- Verification procedures

**Example**:
```markdown
# Chain of Custody

## Source
- Repository: https://github.com/...
- Commit: a1b2c3d4e5f6...
- Branch: main
- Date: 2025-01-15

## Build
- Builder: Docker BuildKit 0.11.0
- Base Image: debian:bookworm-slim@sha256:...
- Build Date: 2025-01-15T10:00:00Z
- Build Command: ./build.sh

## Artifacts
- Image: java:19-jdk-bookworm-slim-fips
- Digest: sha256:abcdef123456...
- Size: 512 MB

## Verification
- Signature: cosign verify --key cosign.pub ...
- SBOM: Attached as attestation
- SLSA Provenance: Level 2
```

---

## Compliance Artifacts

### Available Artifacts

| Artifact | Format | Location | Purpose |
|----------|--------|----------|---------|
| **SBOM** | SPDX JSON | `compliance/sbom-*.spdx.json` | Component inventory |
| **VEX** | OpenVEX | `compliance/vex-*.json` | Vulnerability status |
| **SLSA Provenance** | in-toto | `compliance/slsa-provenance-*.json` | Build attestation |
| **Image Signature** | Cosign | Registry | Authenticity proof |
| **STIG Baseline** | XCCDF XML | `STIG-Template.xml` | Security controls |
| **SCAP Results** | XCCDF XML | `SCAP-Results.xml` | Compliance scan |
| **SCAP Report** | HTML | `SCAP-Results.html` | Human-readable report |
| **Chain of Custody** | Markdown | `compliance/CHAIN-OF-CUSTODY.md` | Provenance trail |

### Generating Artifacts

**Generate All Compliance Artifacts**:
```bash
cd compliance

# Generate SBOM
./generate-sbom.sh

# Generate VEX
./generate-vex.sh

# Generate SLSA provenance
./generate-slsa-attestation.sh

# Sign image
./sign-image.sh

# All artifacts generated in compliance/
```

### Verification Procedures

**Verify Image Signature**:
```bash
cosign verify \
  --key compliance/cosign.pub \
  java:19-jdk-bookworm-slim-fips
```

**Verify SBOM**:
```bash
# Check SBOM is attached
cosign verify-attestation \
  --key compliance/cosign.pub \
  --type spdx \
  java:19-jdk-bookworm-slim-fips
```

**Verify Library Integrity** (runtime):
```bash
docker run --rm java:19-jdk-bookworm-slim-fips \
  /usr/local/bin/integrity-check.sh
```

**Verify FIPS POST** (runtime):
```bash
docker run --rm java:19-jdk-bookworm-slim-fips | \
  grep "FIPS POST test completed successfully"
```

---

## Compliance Reporting

### Audit Report Template

```markdown
# FIPS 140-3 Compliance Audit Report

**System**: Java FIPS Container
**Version**: java:19-jdk-bookworm-slim-fips
**Audit Date**: YYYY-MM-DD
**Auditor**: [Name]

## Executive Summary
[Summary of compliance status]

## FIPS 140-3 Compliance
- Certificate: #4718
- Module: wolfSSL v5.8.2
- Status: ✅ VALIDATED

## Runtime Verification
- Library Integrity: ✅ VERIFIED
- FIPS POST: ✅ EXECUTED
- Provider Configuration: ✅ CORRECT
- Algorithm Tests: ✅ PASSED

## Evidence
- Test execution logs: Evidence/test-execution-summary.md
- SCAP scan results: SCAP-Results.xml
- SBOM: compliance/sbom-*.spdx.json
- Build provenance: compliance/slsa-provenance-*.json

## Conclusion
System is compliant with FIPS 140-3 requirements.

## Attestation
[Signature]
```

---

## Additional Resources

- **[README.md](README.md)** - General documentation
- **[DEVELOPER-GUIDE.md](DEVELOPER-GUIDE.md)** - Integration guide
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Technical architecture
- **[FIPS 140-3 CMVP](https://csrc.nist.gov/projects/cryptographic-module-validation-program)** - NIST validation program

---

**Last Updated**: 2025-01-XX
**Version**: 1.0
**wolfSSL FIPS Version**: v5.8.2 (Certificate #4718)
**Compliance Framework**: FIPS 140-3, DISA STIG
