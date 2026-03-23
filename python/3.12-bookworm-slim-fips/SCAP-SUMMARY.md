# SCAP Scan Summary - python:3.12-bookworm-slim-fips

**Scan Date:** 2026-03-21
**Scanner:** OpenSCAP 1.3.9
**Profile:** DISA STIG Baseline (Container-Adapted for Debian Bookworm)
**Image:** python:3.12-bookworm-slim-fips (Python 3.12 / Debian Bookworm)

---

## Executive Summary

This document summarizes the OpenSCAP security compliance scan results for the python container image. The scan evaluates compliance against DISA STIG baseline controls adapted for containerized environments.

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
/scripts/integrity-check.sh

# FIPS KATs
/test-fips

# Python ssl module validation
python3 -c "import ssl; print(ssl.OPENSSL_VERSION)"

# Check OpenSSL configuration
cat /etc/ssl/openssl.cnf | grep -A5 "libwolfprov"
```

**Results:**
- wolfProvider v1.0.2: Active in OpenSSL provider system
- wolfSSL FIPS v5.8.2 (Certificate #4718): Active
- OpenSSL version: 3.0.18 30 Sep 2025
- Available ciphers: 14 (all FIPS-approved AES-GCM variants)
- FIPS property filtering: `default_properties = fips=yes` in /etc/ssl/openssl.cnf
- Native libraries: Present at /usr/local/lib/libwolfssl.so*, /usr/local/lib/libwolfprov.so*

**Evidence Files:**
- `docker-entrypoint.sh`
- `scripts/integrity-check.sh`
- `src/fips_init_check.py`
- `diagnostics/test-backend-verification.py`
- `diagnostics/test-fips-verification.py`

---

### Algorithm Blocking (SV-238198)

**Status:** ✅ PASS

**Check Performed:**
```bash
# Test MD5 blocking at OpenSSL level
echo -n "test" | openssl dgst -md5

# Run Python FIPS verification tests
./diagnostics/test-fips-verification.py

# Check available cipher suites
python3 -c "import ssl; ctx = ssl.create_default_context(); print(len(ctx.get_ciphers()))"

# Verify OpenSSL configuration
grep "default_properties" /etc/ssl/openssl.cnf
```

**Results:**
- MD5: ❌ BLOCKED at OpenSSL EVP API level (`openssl dgst -md5` returns "Error setting digest: unsupported")
- 3DES, RC4, DES, DSA cipher suites: 0 available (blocked by wolfProvider)
- SHA-1 new TLS cipher suites: 0 available (blocked for new connections)
- SHA-1 verification: Available (legacy cert verification - FIPS 140-3 compliant)
- SHA-256, SHA-384, SHA-512: ✅ AVAILABLE (FIPS approved)
- AES-128-GCM, AES-256-GCM: ✅ AVAILABLE (14 FIPS cipher suites total)
- TLS 1.2, TLS 1.3: ✅ AVAILABLE (FIPS approved protocols)

**Evidence Files:**
- `/etc/ssl/openssl.cnf` (default_properties = fips=yes)
- `diagnostics/test-fips-verification.py` (Test 6: Non-FIPS Algorithm Rejection)
- `diagnostics/test-backend-verification.py` (Test 5: Available Ciphers)
- `Evidence/contrast-test-results.md` (MD5 blocking proof)

---

### Audit Logging (SV-238199)

**Status:** ✅ PASS

**Check Performed:**
```bash
# Container entrypoint validation
cat /docker-entrypoint.sh

# Integrity check script
cat /scripts/integrity-check.sh

# Review entrypoint output
docker logs <container-id>
```

**Results:**
- Entrypoint validation: docker-entrypoint.sh performs FIPS checks on startup
- Integrity verification: SHA-256 checksums validated for all libraries
- FIPS KATs: Executed via /test-fips on every container startup
- Python validation: fips-init-check.py validates ssl module integration
- Startup checks: Container terminates if any validation fails (fail-fast)

**Validation Events:**
1. Library checksum verification (integrity-check.sh)
2. FIPS Known Answer Tests (/test-fips)
3. FIPS container verification (fips-init-check.py)
4. Python ssl module verification
5. OpenSSL provider validation
6. Cipher suite availability check

**Evidence Files:**
- `docker-entrypoint.sh` (Lines 30-80)
- `scripts/integrity-check.sh`
- `src/fips_init_check.py`

---

### Package Integrity (SV-238200)

**Status:** ✅ PASS

**Check Performed:**
```bash
# Library checksum verification
/scripts/integrity-check.sh

# FIPS hash validation (during build)
cd /build/wolfssl && ./fips-hash.sh

# SBOM presence
ls compliance/SBOM-python-3.12-bookworm-slim-fips.spdx.json

# Image signature
cosign verify python:3.12-bookworm-slim-fips

# Run diagnostic test suite
./diagnostics/run-all-tests.sh
```

**Results:**
- Library checksums: SHA-256 verified (libraries.sha256)
- wolfSSL FIPS: In-core integrity hash validated via fips-hash.sh
- wolfCrypt test suite: Passed during build (testwolfcrypt)
- SBOM generated: SPDX 2.3 format
- Image signed: Cosign signature with keyless signing via Sigstore
- VEX statement: Available (compliance/vex-python-3.12-bookworm-slim-fips.json)
- Test suite: 5/5 diagnostic test suites passed (100%)

**Evidence Files:**
- `/opt/wolfssl-fips/checksums/libraries.sha256`
- `scripts/integrity-check.sh`
- `compliance/SBOM-python-3.12-bookworm-slim-fips.spdx.json`
- `compliance/vex-python-3.12-bookworm-slim-fips.json`
- `Dockerfile` (Lines 85-93 - fips-hash.sh execution)
- `Evidence/test-execution-summary.md`

---

### Non-Root User (SV-238201)

**Status:** ✅ PASS

**Check Performed:**
```bash
# Inspect image USER directive
docker inspect python:3.12-bookworm-slim-fips | grep User

# Verify at runtime
docker run --rm python:3.12-bookworm-slim-fips id
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
ls -la /usr/local/lib/libwolfprov.so*
ls -la /etc/ssl/openssl.cnf
ls -la /scripts/integrity-check.sh
ls -la /test-fips
```

**Results:**
- No world-writable files found
- Native libraries: 0644 (/usr/local/lib/libwolfssl.so.44.0.0, /usr/local/lib/libwolfprov.so.1.0.2)
- Configuration: 0644 (/etc/ssl/openssl.cnf)
- Scripts: 0755 (docker-entrypoint.sh, integrity-check.sh)
- Test executables: 0755 (/test-fips)
- Application files: Owned by appuser (UID 1001)

**Evidence:**
- Dockerfile permissions set during build
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
docker run -d --name fips-python-scan python:3.12-bookworm-slim-fips tail -f /dev/null

# Execute SCAP scan
oscap xccdf eval \
  --profile container-fips-baseline \
  --results SCAP-Results.xml \
  --report SCAP-Results.html \
  STIG-Template.xml

# Cleanup
docker stop fips-python-scan
docker rm fips-python-scan
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
| **Test Execution Summary** | `Evidence/test-execution-summary.md` | Detailed test results |

---

## References

- **DISA STIG:** https://public.cyber.mil/stigs/
- **OpenSCAP:** https://www.open-scap.org/
- **NIST SCAP:** https://csrc.nist.gov/projects/security-content-automation-protocol
- **XCCDF Specification:** https://csrc.nist.gov/publications/detail/nistir/7275/rev-4/final
- **FIPS 140-3 Certificate #4718:** https://csrc.nist.gov/projects/cryptographic-module-validation-program/certificate/4718

---

## Document Metadata

- **Author:** Root Security Team
- **Classification:** PUBLIC
- **Distribution:** UNLIMITED
- **Version:** 1.0
- **Last Updated:** 2026-03-21
- **Related Documents:**
  - SCAP-Results.xml
  - SCAP-Results.html
  - STIG-Template.xml
  - POC-VALIDATION-REPORT.md
  - Evidence/test-execution-summary.md

---

**END OF SUMMARY**
