# Root FIPS / STIG Proof of Concept

**Version:** 1.1
**Date:** 2026-03-13
**Status:** Production-Ready POC

---

## Executive Summary

This repository contains a complete, customer-ready Proof of Concept (POC) package that fully satisfies **Section 6 (FIPS / STIG Verification)** requirements. It demonstrates production-realistic, lean container images (Ubuntu 22.04 for Go, Debian 12 Bookworm for Java) with comprehensive FIPS enforcement, STIG baseline compatibility, and complete supply chain security.

**Key Achievements:**
- ✅ **FIPS 140-3 Enforcement** at OS and application runtime levels
- ✅ **Algorithm Validation** with contrast testing (FIPS on/off)
- ✅ **STIG Baseline Compatibility** with SCAP scan evidence
- ✅ **Supply Chain Security** with signed images, SBOM, VEX, and SLSA attestations
- ✅ **10-Minute Validation** path for customer verification

**Strategic Design Choice:**
This POC uses **wolfSSL FIPS v5.8.2 (Certificate #4718)** as the cryptographic foundation, providing CMVP-aligned, OS-agnostic FIPS enforcement developed in close partnership.

---

## What We Are Delivering

### Two Production-Ready Images

| Image | Base | Runtime | FIPS Module | Tag |
|-------|------|---------|-------------|-----|
| **golang** | Ubuntu 22.04 LTS | golang-fips/go v1.25 | wolfSSL FIPS v5.8.2 | 1.25-jammy-ubuntu-22.04-fips |
| **java** | Debian 12 LTS | OpenJDK 19 | wolfSSL FIPS v5.8.2 | 19-jdk-bookworm-slim-fips |

Each image provides:
- ✅ Lean and hardened base (Ubuntu 22.04 LTS for Go; Debian 12 Bookworm Slim for Java)
- ✅ FIPS mode enforcement at multiple layers
- ✅ Cryptographic operations routed through wolfSSL FIPS
- ✅ Signed with cosign for image integrity
- ✅ Immutable digest references
- ✅ Complete SBOM and VEX documentation

---

## Direct Mapping to Section 6 Requirements

This POC explicitly addresses every requirement from Section 6:

| Requirement | Evidence Location | Verification Method |
|-------------|------------------|---------------------|
| **6.1** FIPS incompatible algorithms fail | Go: `golang/.../diagnostics/test-go-fips-algorithms.sh`; Java: `java/.../diagnostics/test-java-algorithm-enforcement.sh` | Run test, observe blocked algorithms |
| **6.2** FIPS compatible algorithms succeed | Go: `golang/.../diagnostics/test-go-fips-algorithms.sh`; Java: `java/.../diagnostics/test-java-algorithms.sh` | Run test, observe SHA-256+ success |
| **6.3** OS FIPS enabled | Go: `golang/.../diagnostics/test-os-fips-status.sh`; Java: `java/.../diagnostics/test-os-fips-status.sh` | Run test, verify provider status |
| **STIG Baseline** | `[go\|java]/STIG-Template.xml` | Review template and exclusions |
| **SCAP Output** | `[go\|java]/SCAP-Results.{xml,html}` | Review scan results |
| **Signed Images** | `supply-chain/Cosign-Verification-Instructions.md` | Run cosign verify |
| **Attestation** | `supply-chain/slsa-provenance-*.json` | Verify SLSA attestation |
| **Contrast Test** | `[go\|java]/Evidence/contrast-test-results.md` | Review side-by-side comparison |

**Detailed Mapping:** See [SECTION-6-CHECKLIST.md](SECTION-6-CHECKLIST.md) for line-by-line traceability.

---

## 10-Minute Validation Guide

This guide allows the customer to validate all POC requirements in under 10 minutes.

### Prerequisites

```bash
# Ensure Docker is installed
docker --version

# (Optional) Install cosign for signature verification
# Installation: https://docs.sigstore.dev/cosign/installation/
```

### Step 1: Pull Images (1 minute)

```bash
# Pull Go FIPS image
docker pull cr.root.io/golang:1.25-jammy-ubuntu-22.04-fips

# Pull Java FIPS image
docker pull cr.root.io/java:19-jdk-bookworm-slim-fips
```

**Note:** Replace `cr.root.io` with your registry:
- Docker Hub: `yourorg/golang:1.25-jammy-ubuntu-22.04-fips`
- GitHub CR: `ghcr.io/yourorg/golang:1.25-jammy-ubuntu-22.04-fips`
- AWS ECR: `123456789.dkr.ecr.us-east-1.amazonaws.com/golang:1.25-jammy-ubuntu-22.04-fips`

### Step 2: Verify Image Signatures (1 minute)

```bash
# Verify Go image signature
cosign verify cr.root.io/golang:1.25-jammy-ubuntu-22.04-fips

# Verify Java image signature
cosign verify cr.root.io/java:19-jdk-bookworm-slim-fips
```

See [supply-chain/Cosign-Verification-Instructions.md](supply-chain/Cosign-Verification-Instructions.md) for detailed verification steps.

### Step 3: Run Go FIPS Validation (3 minutes)

```bash
# Run default FIPS demo (algorithm enforcement)
docker run --rm cr.root.io/golang:1.25-jammy-ubuntu-22.04-fips

# Expected output:
# ✅ MD5: BLOCKED (golang-fips/go active)
# ✅ SHA-1: BLOCKED (strict policy)
# ✅ SHA-256/384/512: PASS
```

```bash
# Run complete test suite (6 tests)
docker run --rm \
  -v $(pwd)/golang/1.25-jammy-ubuntu-22.04-fips/diagnostics:/diagnostics \
  --entrypoint="" \
  cr.root.io/golang:1.25-jammy-ubuntu-22.04-fips \
  bash -c 'cd /diagnostics && ./run-all-tests.sh'

# Expected: ✅ 6/6 test suites passed
```

### Step 4: Run Java FIPS Validation (3 minutes)

```bash
# Run default FIPS demo (startup FIPS validation + java -version)
docker run --rm cr.root.io/java:19-jdk-bookworm-slim-fips

# Expected output:
# ✅ wolfJCE/wolfJSSE providers loaded at positions 1 and 2
# ✅ FIPS POST completed successfully
# ✅ WKS cacerts verified (140 certificates)
# ✅ DES/DESede/RC4: BLOCKED via wolfJCE
# ✅ MD5/SHA-1: LEGACY ALLOWED (blocked in TLS/cert/JAR by java.security policy)
# ✅ SHA-256/384/512: AVAILABLE via wolfJCE
```

```bash
# Run complete diagnostic suite (4 tests via diagnostic runner)
cd java/19-jdk-bookworm-slim-fips
./diagnostic.sh

# Expected: ✅ Test Suites Passed: 4/4, ALL TESTS PASSED
```

### Step 5: Review Evidence Bundle (2 minutes)

```bash
# View Go POC validation report
cat golang/1.25-jammy-ubuntu-22.04-fips/POC-VALIDATION-REPORT.md

# View Java POC validation report
cat java/19-jdk-bookworm-slim-fips/POC-VALIDATION-REPORT.md

# View SCAP scan results (HTML)
firefox golang/1.25-jammy-ubuntu-22.04-fips/SCAP-Results.html
firefox java/19-jdk-bookworm-slim-fips/SCAP-Results.html

# View contrast test evidence
cat golang/1.25-jammy-ubuntu-22.04-fips/Evidence/contrast-test-results.md
cat java/19-jdk-bookworm-slim-fips/Evidence/contrast-test-results.md
```

**Total Time:** ~10 minutes
**Validation Complete:** ✅ All Section 6 requirements verified

**📋 Validation Report:** See [10-MINUTE-VALIDATION-REPORT.md](10-MINUTE-VALIDATION-REPORT.md) for complete execution results and evidence from this workflow.

---

## Evidence Index

### Go Image (golang)

```
golang/1.25-jammy-ubuntu-22.04-fips/
├── README.md                          # Complete image documentation
├── POC-VALIDATION-REPORT.md           # Detailed compliance report
├── STIG-Template.xml                  # Container-adapted Ubuntu STIG
├── SCAP-Results.xml                   # Raw OpenSCAP scan output
├── SCAP-Results.html                  # Human-readable scan report
├── SCAP-SUMMARY.md                    # Scan results summary
├── src/main.go                        # FIPS test application
├── tests/
│   ├── run-all-tests.sh              # Master test runner (6 tests)
│   ├── test-go-fips-algorithms.sh    # Algorithm enforcement
│   ├── test-go-openssl-integration.sh # OpenSSL integration
│   ├── test-go-fips-validation.sh    # Full FIPS validation
│   ├── test-openssl-cli-algorithms.sh # CLI enforcement
│   ├── test-os-fips-status.sh        # OS FIPS status
│   └── test-contrast-fips-enabled-vs-disabled.sh # Contrast test
├── Evidence/
│   ├── contrast-test-results.md      # Side-by-side comparison
│   ├── algorithm-enforcement-evidence.log
│   ├── test-execution-summary.md
│   └── fips-validation-screenshots/
├── compliance/
│   ├── sbom-golang-1.25-jammy-ubuntu-22.04-fips.spdx.json
│   ├── vex-golang-1.25-jammy-ubuntu-22.04-fips.json
│   ├── slsa-provenance-golang-1.25-jammy-ubuntu-22.04-fips.json
│   ├── CHAIN-OF-CUSTODY.md
│   ├── generate-sbom.sh
│   ├── generate-vex.sh
│   ├── generate-slsa-attestation.sh
├── Dockerfile                         # Multi-stage build
├── build.sh                           # Build script
└── entrypoint.sh                      # Container entrypoint
```

### Java Image (java)

```
java/19-jdk-bookworm-slim-fips/
├── README.md                          # Complete image documentation
├── POC-VALIDATION-REPORT.md           # Detailed compliance report
├── STIG-Template.xml                  # Container-adapted Debian STIG
├── SCAP-Results.xml                   # Raw OpenSCAP scan output
├── SCAP-Results.html                  # Human-readable scan report
├── SCAP-SUMMARY.md                    # Scan results summary
├── diagnostic.sh                      # Diagnostic runner (runs diagnostics/)
├── diagnostics/
│   ├── run-all-tests.sh              # Master test runner (4 tests)
│   ├── test-java-algorithm-enforcement.sh # Algorithm enforcement
│   ├── test-java-fips-validation.sh  # FIPS component validation
│   ├── test-java-algorithms.sh       # Algorithm suite (SHA-256/384/512)
│   ├── test-os-fips-status.sh        # OS FIPS status
│   └── test-contrast-fips-enabled-vs-disabled.sh # Contrast test (host-side)
├── demos-image/
│   ├── build.sh                      # Build demos image
│   └── src/
│       ├── WolfJceBlockingDemo.java  # JCE algorithm enforcement demo
│       ├── WolfJsseBlockingDemo.java # TLS protocol/cipher demo
│       ├── MD5AvailabilityDemo.java  # MD5 context policy explanation
│       └── KeyStoreFormatDemo.java   # WKS vs JKS keystore demo
├── Evidence/
│   ├── contrast-test-results.md      # Side-by-side comparison
│   ├── algorithm-enforcement-evidence.log
│   ├── diagnostic_results.txt        # Full run-all-tests.sh output
│   ├── test-execution-summary.md
│   └── fips-validation-screenshots/
├── compliance/
│   ├── sbom-java-19-jdk-bookworm-slim-fips.spdx.json
│   ├── vex-java-19-jdk-bookworm-slim-fips.json
│   ├── slsa-provenance-java-19-jdk-bookworm-slim-fips.json
│   ├── CHAIN-OF-CUSTODY.md
│   ├── generate-sbom.sh
│   ├── generate-vex.sh
│   ├── generate-slsa-attestation.sh
├── Dockerfile                         # Multi-stage build
├── build.sh                           # Build script
├── entrypoint.sh                      # Container entrypoint
└── java.security.fips                 # Java security policy
```

### Supply Chain (Consolidated)

```
supply-chain/
├── Cosign-Verification-Instructions.md # Complete verification guide
├── SBOM-golang-1.25-jammy-ubuntu-22.04-fips.spdx.json      # Go image SBOM (SPDX 2.3)
├── SBOM-java-19-jdk-bookworm-slim-fips.spdx.json    # Java image SBOM (SPDX 2.3)
├── VEX-golang-1.25-jammy-ubuntu-22.04-fips.json            # Go image VEX (OpenVEX v0.2.0)
├── VEX-java-19-jdk-bookworm-slim-fips.json          # Java image VEX (OpenVEX v0.2.0)
└── verify-all.sh                      # Automated verification script
```

---

## Image Digests and Verification

### Go Image

```bash
# Image reference
Image: cr.root.io/golang:1.25-jammy-ubuntu-22.04-fips

# Get image digest
docker inspect --format='{{index .RepoDigests 0}}' \
  cr.root.io/golang:1.25-jammy-ubuntu-22.04-fips

# Pull by digest (immutable reference)
docker pull cr.root.io/golang@sha256:<digest>

# Verify signature
cosign verify \
  --key cosign.pub \
  cr.root.io/golang:1.25-jammy-ubuntu-22.04-fips

# Verify SLSA attestation
cosign verify-attestation \
  --type slsaprovenance \
  --key cosign.pub \
  cr.root.io/golang:1.25-jammy-ubuntu-22.04-fips
```

### Java Image

```bash
# Image reference
Image: cr.root.io/java:19-jdk-bookworm-slim-fips

# Get image digest
docker inspect --format='{{index .RepoDigests 0}}' \
  cr.root.io/java:19-jdk-bookworm-slim-fips

# Pull by digest (immutable reference)
docker pull cr.root.io/java@sha256:<digest>

# Verify signature
cosign verify \
  --key cosign.pub \
  cr.root.io/java:19-jdk-bookworm-slim-fips

# Verify SLSA attestation
cosign verify-attestation \
  --type slsaprovenance \
  --key cosign.pub \
  cr.root.io/java:19-jdk-bookworm-slim-fips
```

See [supply-chain/Cosign-Verification-Instructions.md](supply-chain/Cosign-Verification-Instructions.md) for complete verification workflows.

---

## WolfSSL Strategic Note

This POC uses **wolfSSL FIPS v5.8.2** as the cryptographic foundation:

**CMVP Certification:**
- FIPS 140-3 Certificate #4718
- Validated cryptographic module
- Approved algorithms: AES, RSA, ECDSA, SHA-2 family

**Strategic Benefits:**
- **OS-Agnostic:** Works across Ubuntu, Alpine, RHEL, etc.
- **Provider Architecture:** Integrates via OpenSSL 3.x provider interface
- **Strict Enforcement:** Built with `--disable-sha` for maximum security posture
- **Partnership:** Developed in close collaboration for enterprise use cases

**Important Note:**
This POC implements a **stricter-than-FIPS** policy by blocking SHA-1 at the library level. While this invalidates the FIPS certificate (SHA-1 is required for approved legacy operations), it provides stronger security posture suitable for modern applications.

For environments requiring strict FIPS 140-3 certification compliance, wolfSSL can be rebuilt without `--disable-sha` to allow SHA-1 for approved uses.

---

## Architecture Overview

### Go Image FIPS Stack

```
┌─────────────────────────────────────────┐
│   Go Application (User Code)           │
├─────────────────────────────────────────┤
│   golang-fips/go Runtime                │ ← GODEBUG=fips140=only
│   (GOEXPERIMENT=strictfipsruntime)      │   (blocks MD5 via panic)
├─────────────────────────────────────────┤
│   OpenSSL 3.x (dlopen at runtime)       │ ← OPENSSL_CONF configured
├─────────────────────────────────────────┤
│   wolfProvider (OSSL provider)          │ ← Provider: fips
├─────────────────────────────────────────┤
│   wolfSSL FIPS v5.8.2                   │ ← Certificate #4718
│   (--disable-sha for strict policy)     │   (blocks SHA-1 at library)
└─────────────────────────────────────────┘
```

### Java Image FIPS Stack

```
┌─────────────────────────────────────────┐
│   Java Application (User Code)         │
├─────────────────────────────────────────┤
│   Java Crypto API (JCA/JCE/JSSE)       │ ← wolfJCE at position 1
│   Security Providers                   │   wolfJSSE at position 2
├─────────────────────────────────────────┤
│   wolfJCE / wolfJSSE (JNI providers)   │ ← java.security policy blocks
│   Debian 12 Bookworm Slim base         │   MD5/SHA-1 in TLS/cert/JAR;
│                                        │   DES/RC4 hard-blocked by wolfJCE
├─────────────────────────────────────────┤
│   wolfSSL FIPS v5.8.2 (JNI)            │ ← Certificate #4718
│   (native FIPS module)                 │   FIPS POST on init
└─────────────────────────────────────────┘
```

---

## Non-Goals

This POC is intentionally scoped to FIPS and STIG validation only. It does **not** cover:

- ❌ Zero CVE claims
- ❌ Automated remediation demonstrations
- ❌ Container catalog density
- ❌ Formal FIPS 140-3 audit submission
- ❌ Complete FIPS Security Policy documentation

This is **validation-level evidence** suitable for POC evaluation and procurement assessment.

---

## Building Images

### Prerequisites

```bash
# Create wolfSSL password file (required for commercial FIPS package)
echo 'your-wolfssl-password' > golang/1.25-jammy-ubuntu-22.04-fips/.wolfssl_password
echo 'your-wolfssl-password' > java/19-jdk-bookworm-slim-fips/.wolfssl_password
chmod 600 golang/1.25-jammy-ubuntu-22.04-fips/.wolfssl_password java/19-jdk-bookworm-slim-fips/.wolfssl_password
```

### Build Go Image

```bash
cd golang/1.25-jammy-ubuntu-22.04-fips
./build.sh

# Or manual build
docker build \
  --secret id=wolfssl_password,src=.wolfssl_password \
  -t cr.root.io/golang:1.25-jammy-ubuntu-22.04-fips \
  .
```

### Build Java Image

```bash
cd java/19-jdk-bookworm-slim-fips
./build.sh

# Or manual build
docker build \
  --secret id=wolfssl_password,src=.wolfssl_password \
  -t cr.root.io/java:19-jdk-bookworm-slim-fips \
  .
```

---

## Support and Documentation

### Image-Specific Documentation
- [Go Image README](golang/1.25-jammy-ubuntu-22.04-fips/README.md)
- [Java Image README](java/19-jdk-bookworm-slim-fips/README.md)

### Compliance Documentation
- [Section 6 Checklist Mapping](SECTION-6-CHECKLIST.md)
- [Go POC Validation Report](golang/1.25-jammy-ubuntu-22.04-fips/POC-VALIDATION-REPORT.md)
- [Java POC Validation Report](java/19-jdk-bookworm-slim-fips/POC-VALIDATION-REPORT.md)

### Supply Chain Security
- [Cosign Verification Instructions](supply-chain/Cosign-Verification-Instructions.md)
- [SBOM Files](supply-chain/)
- [VEX Statements](supply-chain/)

---

## References

- [FIPS 140-3 Standard](https://csrc.nist.gov/publications/detail/fips/140/3/final)
- [wolfSSL FIPS Certificate #4718](https://www.wolfssl.com/products/wolfssl-fips/)
- [DISA STIG for Ubuntu 22.04](https://public.cyber.mil/stigs/)
- [OpenSCAP Project](https://www.open-scap.org/)
- [SLSA Framework](https://slsa.dev/)
- [SPDX Specification](https://spdx.dev/specifications/)
- [OpenVEX Specification](https://github.com/openvex/spec)
- [Cosign Documentation](https://docs.sigstore.dev/cosign/overview/)

---

## License

Components:
- wolfSSL FIPS: Commercial License (required)
- wolfProvider: GPL v3
- golang-fips/go: BSD-style (Go License)
- OpenJDK 19: GPL v2 with Classpath Exception

---

## Document Metadata

- **Author:** Root Security Team
- **Classification:** PUBLIC
- **Distribution:** UNLIMITED
- **Version:** 1.1
- **Last Updated:** 2026-03-13

---

**END OF README**
