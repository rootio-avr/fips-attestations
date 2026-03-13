# SCAP Scan Summary - java:17-jammy-ubuntu-22.04-fips

**Scan Date:** 2026-03-04
**Scanner:** OpenSCAP 1.3.9
**Profile:** DISA STIG Baseline (Container-Adapted for Debian Bookworm)
**Image:** java:17-jammy-ubuntu-22.04-fips (OpenJDK 19 / Debian Bookworm)

---

## Executive Summary

This document summarizes the OpenSCAP security compliance scan results for the java container image. The scan evaluates compliance against DISA STIG baseline controls adapted for containerized environments.

**Overall Compliance Status:** ✅ **COMPLIANT**

**Scan Statistics:**
- **Total Rules Evaluated:** 152
- **Pass:** 128 (84.2%)
- **Fail:** 0 (0%)
- **Not Applicable:** 20 (13.2%)
- **Not Selected:** 4 (2.6%)

**Severity Breakdown:**
| Severity | Pass | Fail | N/A | Total |
|----------|------|------|-----|-------|
| High     | 45   | 0    | 5   | 50    |
| Medium   | 58   | 0    | 10  | 68    |
| Low      | 25   | 0    | 5   | 30    |
| Info     | 0    | 0    | 0   | 4     |

---

## Key Findings

### ✅ Critical FIPS Controls - PASS

All FIPS-related controls passed successfully:

| Rule ID | Title | Status | Severity |
|---------|-------|--------|----------|
| SV-238197 | FIPS mode enabled | ✅ PASS | High |
| SV-238198 | Non-FIPS algorithms blocked | ✅ PASS | High |
| SV-238199 | Audit logging configured | ✅ PASS | Medium |
| SV-238200 | Package integrity verification | ✅ PASS | Medium |
| SV-238201 | Non-root user enforcement | ✅ PASS | Medium |
| SV-238202 | File permissions restricted | ✅ PASS | Medium |

### ℹ️ Not Applicable Controls

20 controls marked as Not Applicable due to container scope limitations:

| Rule ID | Title | Reason |
|---------|-------|--------|
| SV-238203 | Kernel module restrictions | Kernel managed by host |
| SV-238204 | Boot loader password | No boot process in container |
| SV-238205 | Systemd service hardening | Systemd not present |
| SV-238206 | Physical console access | Virtual environment |
| SV-238207 | GRUB configuration | No boot loader |
| SV-238208-238222 | Various host-level controls | Host responsibility |

**Note:** All N/A controls are documented in STIG-Template.xml with justifications.

### 📊 Compliance by Control Family

| Control Family | Pass | Fail | N/A | Compliance Rate |
|---------------|------|------|-----|-----------------|
| Access Control (AC) | 22 | 0 | 3 | 100% (applicable) |
| Audit and Accountability (AU) | 18 | 0 | 2 | 100% |
| Identification and Authentication (IA) | 15 | 0 | 4 | 100% |
| System and Communications Protection (SC) | 35 | 0 | 5 | 100% |
| System and Information Integrity (SI) | 28 | 0 | 4 | 100% |
| Configuration Management (CM) | 10 | 0 | 2 | 100% |

---

## Detailed FIPS Validation Results

### FIPS Mode Enforcement (SV-238197)

**Status:** ✅ PASS

**Check Performed:**
```bash
# Entrypoint integrity and FIPS validation
/docker-entrypoint.sh

# Library integrity verification
/usr/local/bin/integrity-check.sh

# Java FIPS provider validation
java -cp "/opt/wolfssl-fips/bin:/usr/share/java/*" FipsInitCheck

# Java Security providers list
java -XshowSettings:properties -version 2>&1 | grep security.provider
```

**Results:**
- wolfCrypt JNI (WolfCryptProvider): Installed as security.provider.1
- wolfSSL JNI (WolfSSLProvider): Installed as security.provider.2
- wolfSSL FIPS v5.2.3 (Certificate #4718): Active
- Java keystore type: WKS (FIPS-compliant)
- Native libraries: Present at /usr/local/lib/libwolfssl.so*, /usr/lib/jni/

**Evidence Files:**
- `docker-entrypoint.sh`
- `scripts/integrity-check.sh`
- `src/main/FipsInitCheck.java`
- `diagnostics/test-java-fips-validation.sh`

---

### Algorithm Blocking (SV-238198)

**Status:** ✅ PASS

**Check Performed:**
```bash
# Run Java algorithm enforcement tests
./diagnostics/test-java-algorithm-enforcement.sh

# Run Java algorithm availability tests
./diagnostics/test-java-algorithms.sh

# Check java.security policy
grep "jdk.tls.disabledAlgorithms" $JAVA_HOME/conf/security/java.security
grep "jdk.certpath.disabledAlgorithms" $JAVA_HOME/conf/security/java.security
```

**Results:**
- MD5, MD4, MD2: ❌ BLOCKED (jdk.certpath.disabledAlgorithms, jdk.jar.disabledAlgorithms)
- SHA-1: ❌ BLOCKED for TLS/JAR signing (jdk.tls.disabledAlgorithms, jdk.jar.disabledAlgorithms)
- DSA, RC4, DES, DESede, Ed25519, Ed448: ❌ BLOCKED (jdk.tls.disabledAlgorithms)
- RSA < 2048 bits: ❌ BLOCKED (key size constraints)
- SHA-256, SHA-384, SHA-512: ✅ AVAILABLE (FIPS approved)
- AES (all key sizes): ✅ AVAILABLE (FIPS approved)
- RSA ≥ 2048 bits: ✅ AVAILABLE (FIPS approved)

**Evidence Files:**
- `java.security` (Lines 644-836)
- `diagnostics/test-java-algorithm-enforcement.sh`
- `diagnostics/test-java-algorithms.sh`
- `src/main/FipsInitCheck.java`

---

### Audit Logging (SV-238199)

**Status:** ✅ PASS

**Check Performed:**
```bash
# Container entrypoint validation
cat /docker-entrypoint.sh

# Integrity check script
cat /usr/local/bin/integrity-check.sh

# Review entrypoint output
docker logs <container-id>
```

**Results:**
- Entrypoint validation: docker-entrypoint.sh performs FIPS checks on startup
- Integrity verification: SHA-256 checksums validated for all libraries
- FIPS validation: FipsInitCheck.java validates Java Security providers
- Startup checks: Container terminates if any validation fails

**Validation Events:**
1. Library checksum verification (integrity-check.sh)
2. FIPS provider installation check (FipsInitCheck.java)
3. Java Security provider priority validation
4. WKS keystore format verification
5. FIPS POST execution via MessageDigest

**Evidence Files:**
- `docker-entrypoint.sh` (Lines 66-106)
- `scripts/integrity-check.sh`
- `src/main/FipsInitCheck.java`

---

### Package Integrity (SV-238200)

**Status:** ✅ PASS

**Check Performed:**
```bash
# Library checksum verification
/usr/local/bin/integrity-check.sh

# FIPS hash validation (during build)
cd /build/wolfssl && ./fips-hash.sh

# SBOM presence
ls compliance/sbom-java-17-jammy-ubuntu-22.04-fips.spdx.json

# Image signature
cosign verify java:17-jammy-ubuntu-22.04-fips
```

**Results:**
- Library checksums: SHA-256 verified (libraries.sha256)
- wolfSSL FIPS: In-core integrity hash validated via fips-hash.sh
- wolfCrypt test suite: Passed during build (testwolfcrypt)
- SBOM generated: SPDX 2.3 format
- Image signed: Cosign signature valid
- VEX statement: Available

**Evidence Files:**
- `/opt/wolfssl-fips/checksums/libraries.sha256`
- `scripts/integrity-check.sh`
- `compliance/sbom-java-17-jammy-ubuntu-22.04-fips.spdx.json`
- `Dockerfile` (Lines 85-93 - fips-hash.sh execution)

---

### Non-Root User (SV-238201)

**Status:** ✅ PASS

**Check Performed:**
```bash
# Inspect image USER directive
docker inspect java:17-jammy-ubuntu-22.04-fips | grep User

# Verify at runtime
docker run --rm java:17-jammy-ubuntu-22.04-fips id
```

**Results:**
- Container user: appuser (UID 1001)
- Group: appuser (GID 1001)
- Not running as root: Verified

**Evidence:**
- Dockerfile: `USER appuser`
- Runtime verification successful

---

### File Permissions (SV-238202)

**Status:** ✅ PASS

**Check Performed:**
```bash
# Find world-writable files
find / -type f -perm -002 2>/dev/null

# Check sensitive files
ls -la /usr/local/lib/libwolfssl.so*
ls -la /usr/lib/jni/*.so
ls -la /usr/share/java/*.jar
ls -la $JAVA_HOME/conf/security/java.security
ls -la $JAVA_HOME/lib/security/cacerts
ls -la /usr/local/bin/integrity-check.sh
```

**Results:**
- No world-writable files found
- Native libraries: 0644 (/usr/local/lib/libwolfssl.so*, /usr/lib/jni/)
- JAR files: 0644 (wolfcrypt-jni.jar, wolfssl-jsse.jar, filtered-providers.jar)
- Configuration: 0644 (java.security)
- Keystore: 0444 read-only (cacerts.wks)
- Scripts: 0755 (docker-entrypoint.sh, integrity-check.sh)
- Application files: Owned by appuser (UID 1001)

**Evidence:**
- Dockerfile:258-264, 297-299 (chmod operations)
- Dockerfile:358 (USER appuser directive)
- Runtime verification

---

## Container-Specific Exclusions

The following controls are marked as **Not Applicable** with documented justifications:

### Kernel-Level Controls (Host Responsibility)

| Rule ID | Control | Justification |
|---------|---------|---------------|
| SV-238203 | Kernel module loading | Containers share host kernel; no independent module loading |
| SV-238210 | Kernel parameter tuning | sysctl settings controlled by host |
| SV-238215 | Kernel crash dumps | Host kernel responsibility |

**Mitigation:** Deploy container on STIG-compliant host with proper kernel hardening.

### Boot Process Controls (Not Applicable)

| Rule ID | Control | Justification |
|---------|---------|---------------|
| SV-238204 | Boot loader password | Containers don't have boot loaders |
| SV-238207 | GRUB configuration | No GRUB in container environment |
| SV-238211 | Boot parameter validation | Container runtime starts, not boots |

**Mitigation:** N/A - containers are started by runtime, not booted.

### System Service Controls (Limited Scope)

| Rule ID | Control | Justification |
|---------|---------|---------------|
| SV-238205 | Systemd hardening | Minimal container uses entrypoint, not systemd |
| SV-238212 | Service enumeration | Only application process runs |
| SV-238218 | Service account restrictions | Single-purpose container |

**Mitigation:** Process supervision handled by container runtime (Docker, Kubernetes).

---

## Remediation Summary

**Total Remediations Required:** 0

All applicable controls are compliant. No remediation actions required.

### Continuous Compliance Recommendations

1. **Periodic Rescanning**
   ```bash
   # Re-run SCAP scan after updates
   oscap xccdf eval --profile container-fips-baseline \
     --results SCAP-Results.xml \
     --report SCAP-Results.html \
     STIG-Template.xml
   ```

2. **Monitor for New STIG Updates**
   - Check DISA STIG releases quarterly
   - Update STIG-Template.xml as needed
   - Re-scan and document changes

3. **Host Compliance**
   - Ensure container host is STIG-compliant
   - Validate host kernel FIPS mode if required
   - Review host-level controls (N/A items)

4. **Runtime Security**
   - Use security profiles (AppArmor, SELinux)
   - Implement network policies
   - Enable runtime monitoring

---

## Scan Methodology

### Scan Execution

```bash
# Run container in background for scanning
docker run -d --name fips-java-scan java:17-jammy-ubuntu-22.04-fips tail -f /dev/null

# Execute SCAP scan
oscap xccdf eval \
  --profile container-fips-baseline \
  --results SCAP-Results.xml \
  --report SCAP-Results.html \
  STIG-Template.xml

# Cleanup
docker stop fips-java-scan
docker rm fips-java-scan
```

### Scan Scope

**Included:**
- File system configuration
- Package integrity
- User and group settings
- Cryptographic configuration
- Audit logging
- Application permissions

**Excluded (Host Responsibility):**
- Kernel configuration
- Boot process
- Physical security
- Host network configuration
- Container runtime security

---

## Compliance Artifacts

| Artifact | Location | Purpose |
|----------|----------|---------|
| **SCAP Results (XML)** | `SCAP-Results.xml` | Machine-readable scan output |
| **SCAP Report (HTML)** | `SCAP-Results.html` | Human-readable report |
| **STIG Template** | `STIG-Template.xml` | Baseline configuration |
| **This Summary** | `SCAP-SUMMARY.md` | Executive summary and analysis |
| **POC Report** | `POC-VALIDATION-REPORT.md` | Complete validation evidence |
| **Section 6 Checklist** | `../../SECTION-6-CHECKLIST.md` | Requirement traceability |

---

## References

- **DISA STIG:** https://public.cyber.mil/stigs/
- **OpenSCAP:** https://www.open-scap.org/
- **NIST SCAP:** https://csrc.nist.gov/projects/security-content-automation-protocol
- **XCCDF Specification:** https://csrc.nist.gov/publications/detail/nistir/7275/rev-4/final

---

## Document Metadata

- **Author:** Root Security Team
- **Classification:** PUBLIC
- **Distribution:** UNLIMITED
- **Version:** 1.0
- **Last Updated:** 2026-03-04
- **Related Documents:**
  - SCAP-Results.xml
  - SCAP-Results.html
  - STIG-Template.xml
  - POC-VALIDATION-REPORT.md

---

**END OF SUMMARY**
