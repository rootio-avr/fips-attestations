# SCAP Scan Summary - redis:7.2.4-alpine-3.19-fips

**Scan Date:** 2026-03-26
**Scanner:** OpenSCAP 1.3.9
**Profile:** DISA STIG Baseline (Container-Adapted for Alpine Linux 3.19)
**Image:** redis:7.2.4-alpine-3.19-fips (Redis 7.2.4 / Alpine Linux 3.19)

---

## Executive Summary

This document summarizes the OpenSCAP security compliance scan results for the redis container image. The scan evaluates compliance against DISA STIG baseline controls adapted for containerized environments.

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
# FIPS startup validation
docker run --rm cr.root.io/redis:7.2.4-alpine-3.19-fips fips-startup-check

# OpenSSL provider verification
docker exec <container> openssl list -providers

# Verify Redis FIPS patch (Lua SHA-256)
docker exec <container> redis-cli SCRIPT LOAD "return 'test'"
# Output: 64-character SHA-256 script ID (not 40-character SHA-1)

# Verify redis.sha1hex() uses SHA-256
docker exec <container> redis-cli EVAL "return redis.sha1hex('test')" 0
# Output: 64-character SHA-256 hash

# Check OpenSSL configuration
cat /usr/local/openssl/lib/ossl-modules/wolfprov.so
```

**Results:**
- wolfProvider v1.1.0: Active in OpenSSL provider system
- wolfSSL FIPS v5.8.2 (Certificate #4718): Active
- OpenSSL version: 3.3.0 9 Apr 2024
- Redis FIPS patch: Applied (Lua scripts use SHA-256, not SHA-1)
- Script IDs: 64 characters (SHA-256 hash)
- redis.sha1hex() API: Returns 64-character SHA-256 hash
- FIPS POST: Known Answer Tests (KAT) passed on container startup
- Alpine Linux: 3.19 (musl libc 1.2.4)

**Evidence Files:**
- `docker-entrypoint.sh`
- `fips-startup-check` (compiled binary)
- `Evidence/diagnostic_results.txt`
- `Evidence/test-execution-summary.md`
- `Evidence/contrast-test-results.md`
- `POC-VALIDATION-REPORT.md`

---

### Algorithm Blocking (SV-238198)

**Status:** ✅ PASS

**Check Performed:**
```bash
# Test MD5 blocking at OpenSSL level
docker exec <container> openssl dgst -md5 /etc/redis/redis.conf

# Test SHA-256 availability (FIPS-approved)
docker exec <container> openssl dgst -sha256 /etc/redis/redis.conf

# Verify Lua SHA-256 hashing (Redis FIPS patch)
docker exec <container> redis-cli SCRIPT LOAD "return 'Hello FIPS'"
docker exec <container> redis-cli EVAL "return redis.sha1hex('test')\" 0

# Run algorithm enforcement tests
./diagnostics/test-redis-fips-status.sh

# Run comprehensive test suite
docker run -t --rm cr.root.io/redis:7.2.4-alpine-3.19-fips \
  /diagnostics/test-images/basic-test-image/test-suite.sh
```

**Results:**
- MD5: ❌ BLOCKED at OpenSSL EVP API level (`error:0308010C:digital envelope routines::unsupported`)
- DES/3DES: ❌ BLOCKED (not available in wolfSSL FIPS build)
- RC4: ❌ BLOCKED (not available in wolfSSL FIPS build)
- SHA-1 for new operations: ⚠️ DEPRECATED (replaced with SHA-256 in Redis patch)
- SHA-256, SHA-384, SHA-512: ✅ AVAILABLE (FIPS approved)
- AES-128-GCM, AES-256-GCM: ✅ AVAILABLE (FIPS approved)
- Lua script hashing: ✅ SHA-256 (64-character script IDs)
- redis.sha1hex() API: ✅ Uses SHA-256 internally (64-character output)

**Redis FIPS Patch Verification:**
- Script LOAD: Returns 64-char SHA-256 hash (vs 40-char SHA-1 in standard Redis)
- redis.sha1hex('test'): Returns `9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08` (64 chars)
- Breaking change: Script IDs incompatible with non-FIPS Redis

**Evidence Files:**
- `patches/redis-fips-sha256-redis7.2.4.patch`
- `Evidence/contrast-test-results.md` (FIPS enabled vs disabled comparison)
- `Evidence/diagnostic_results.txt` (MD5 blocking proof, Lua SHA-256 tests)
- `diagnostics/test-redis-fips-status.sh`

---

### Audit Logging (SV-238199)

**Status:** ✅ PASS

**Check Performed:**
```bash
# Container entrypoint validation
cat /docker-entrypoint.sh

# FIPS startup check execution
docker run --rm cr.root.io/redis:7.2.4-alpine-3.19-fips fips-startup-check

# Review container startup logs
docker logs <container-id>

# Run diagnostic suite
./diagnostic.sh
```

**Results:**
- Entrypoint validation: docker-entrypoint.sh performs FIPS checks on startup
- FIPS POST: wolfSSL Known Answer Tests executed on every container startup
- OpenSSL provider verification: wolfProvider status checked on startup
- Redis configuration validation: redis-server --test-memory executed before starting
- Startup checks: Container terminates if any validation fails (fail-fast)
- Diagnostic tests: 60+ tests executed (pre-build + runtime + comprehensive + demos)

**Validation Events:**
1. FIPS POST execution (wolfSSL Known Answer Tests)
2. OpenSSL provider validation (wolfProvider v1.1.0 status)
3. FIPS enforcement verification (MD5 blocked, SHA-256 working)
4. Redis FIPS patch verification (Lua SHA-256 hashing)
5. Comprehensive test suite execution (60/60 tests passed)

**Evidence Files:**
- `docker-entrypoint.sh`
- `fips-startup-check.c` (source code)
- `diagnostic.sh` (test runner)
- `Evidence/diagnostic_results.txt` (complete test output)
- `Evidence/test-execution-summary.md`

---

### Package Integrity (SV-238200)

**Status:** ✅ PASS

**Check Performed:**
```bash
# Verify FIPS POST execution
docker logs <container> 2>&1 | grep "FIPS"

# Check OpenSSL provider
docker exec <container> openssl list -providers

# SBOM presence
ls compliance/SBOM-redis-7.2.4-alpine-3.19-fips.spdx.json

# VEX document
ls compliance/vex-redis-7.2.4-alpine-3.19-fips.json

# SLSA provenance
ls compliance/slsa-provenance-redis-7.2.4-alpine-3.19-fips.json

# Run pre-build validation
./test-build.sh

# Run runtime diagnostics
./diagnostic.sh

# Run comprehensive test suite
docker run -t --rm cr.root.io/redis:7.2.4-alpine-3.19-fips \
  /diagnostics/test-images/basic-test-image/test-suite.sh

# Run demo tests
cd demos-image && ./test-demos.sh all
```

**Results:**
- wolfSSL FIPS: In-core integrity hash validated via fips-hash.sh during build
- FIPS POST: Known Answer Tests validate cryptographic module on every startup
- OpenSSL provider: wolfProvider v1.1.0 verified active
- Redis FIPS patch: Applied and verified (SHA-256 Lua scripting)
- SBOM generated: SPDX 2.3 format
- VEX statement: Available (compliance/vex-redis-7.2.4-alpine-3.19-fips.json)
- SLSA provenance: Available (compliance/slsa-provenance-redis-7.2.4-alpine-3.19-fips.json)
- Chain of Custody: Complete documentation (compliance/CHAIN-OF-CUSTODY.md)
- Test suite results: **60/60 tests passed (100%)**
  - Pre-Build Validation: 27/27 passed
  - Runtime Diagnostics: 8/8 passed
  - Comprehensive Test Suite: 20/20 passed
  - Demo Configurations: 5/5 passed

**Evidence Files:**
- `compliance/SBOM-redis-7.2.4-alpine-3.19-fips.spdx.json`
- `compliance/vex-redis-7.2.4-alpine-3.19-fips.json`
- `compliance/slsa-provenance-redis-7.2.4-alpine-3.19-fips.json`
- `compliance/CHAIN-OF-CUSTODY.md`
- `Evidence/test-execution-summary.md`
- `Evidence/diagnostic_results.txt`
- `POC-VALIDATION-REPORT.md`

---

### Non-Root User (SV-238201)

**Status:** ✅ PASS

**Check Performed:**
```bash
# Verify Redis runs as non-root
docker exec <container> ps aux | grep redis

# Check user at runtime
docker run --rm cr.root.io/redis:7.2.4-alpine-3.19-fips id

# Inspect image USER directive
docker inspect cr.root.io/redis:7.2.4-alpine-3.19-fips | grep User
```

**Results:**
- Container user: redis (UID 1000)
- Group: redis (GID 1000)
- Not running as root: Verified
- Redis process: Runs as redis user
- File ownership: /data owned by redis:redis

**Evidence:**
- Dockerfile: `USER redis`
- Runtime verification successful
- All Redis processes run as non-root redis user (UID 1000)

---

### File Permissions (SV-238202)

**Status:** ✅ PASS

**Check Performed:**
```bash
# Find world-writable files
find / -type f -perm -002 2>/dev/null

# Check sensitive files
ls -la /usr/local/lib/libwolfssl.so*
ls -la /usr/local/openssl/lib/ossl-modules/wolfprov.so
ls -la /usr/local/openssl/lib/libssl.so*
ls -la /usr/local/openssl/lib/libcrypto.so*
ls -la /etc/redis/redis.conf
ls -la /docker-entrypoint.sh
ls -la /usr/local/bin/fips-startup-check
```

**Results:**
- No world-writable files found
- wolfSSL libraries: 0755 (/usr/local/lib/libwolfssl.so.42.0.0)
- wolfProvider: 0755 (/usr/local/openssl/lib/ossl-modules/wolfprov.so)
- OpenSSL libraries: 0755 (/usr/local/openssl/lib/libssl.so.3, libcrypto.so.3)
- Redis configuration: 0644 (/etc/redis/redis.conf)
- Entrypoint script: 0755 (/docker-entrypoint.sh)
- FIPS startup check: 0755 (/usr/local/bin/fips-startup-check)
- Data directory: 0755, owned by redis:redis (/data)

**Evidence:**
- Dockerfile permissions set during build
- Runtime verification
- No world-writable files detected

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
| SV-238212 | Service enumeration | Only Redis process runs |
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
   - Use read-only root filesystem where possible

5. **Redis Best Practices**
   - Use requirepass for authentication in production
   - Enable TLS for network encryption
   - Configure persistence (RDB/AOF) based on requirements
   - Monitor Lua script SHA-256 performance

---

## Scan Methodology

### Scan Execution

```bash
# Run container in background for scanning
docker run -d --name fips-redis-scan \
  -p 6379:6379 \
  cr.root.io/redis:7.2.4-alpine-3.19-fips

# Wait for Redis to be ready
sleep 2

# Execute SCAP scan
oscap xccdf eval \
  --profile container-fips-baseline \
  --results SCAP-Results.xml \
  --report SCAP-Results.html \
  STIG-Template.xml

# Test Redis FIPS functionality
docker exec fips-redis-scan redis-cli PING
docker exec fips-redis-scan redis-cli SCRIPT LOAD "return 'test'"
docker exec fips-redis-scan redis-cli EVAL "return redis.sha1hex('test')" 0

# Cleanup
docker stop fips-redis-scan
docker rm fips-redis-scan
```

### Scan Scope

**Included:**
- File system configuration
- Package integrity
- User and group settings
- Cryptographic configuration
- Audit logging
- Application permissions
- Redis FIPS patch validation
- Lua script SHA-256 hashing

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
| **POC Validation Report** | `POC-VALIDATION-REPORT.md` | Complete POC validation |
| **Test Execution Summary** | `Evidence/test-execution-summary.md` | Detailed test results |
| **Diagnostic Results** | `Evidence/diagnostic_results.txt` | Raw test outputs |
| **Contrast Test Results** | `Evidence/contrast-test-results.md` | FIPS enforcement proof |
| **SBOM** | `compliance/SBOM-redis-7.2.4-alpine-3.19-fips.spdx.json` | Software Bill of Materials |
| **VEX** | `compliance/vex-redis-7.2.4-alpine-3.19-fips.json` | Vulnerability disclosure |
| **SLSA** | `compliance/slsa-provenance-redis-7.2.4-alpine-3.19-fips.json` | Build provenance |
| **Chain of Custody** | `compliance/CHAIN-OF-CUSTODY.md` | Supply chain documentation |

---

## Redis-Specific Security Features

### FIPS-Compliant Redis Configuration

The Redis image includes comprehensive FIPS security configurations:

1. **Lua Script SHA-256 Hashing**
   - All Lua scripts hashed with SHA-256 (not SHA-1)
   - Script IDs: 64 characters (SHA-256) vs 40 characters (SHA-1)
   - redis.sha1hex() API: Uses SHA-256 internally (backward compatible name)
   - Breaking change: Script IDs incompatible with non-FIPS Redis

2. **Cryptographic Module**
   - wolfSSL FIPS v5.8.2 (Certificate #4718)
   - OpenSSL 3.3.0 with wolfProvider v1.1.0
   - FIPS POST validation on every startup
   - MD5/DES/RC4 blocked at library level

3. **Demo Configurations**
   - `persistence-demo.conf`: RDB and AOF persistence with FIPS
   - `pubsub-demo.conf`: Pub/Sub messaging
   - `memory-optimization.conf`: Memory limits and eviction policies
   - `strict-fips.conf`: Maximum security enforcement
   - `tls-demo.conf`: TLS configuration (requires certificates)

4. **Test Coverage**
   - Pre-Build Validation: 27/27 tests passed
   - Runtime Diagnostics: 8/8 tests passed
   - Comprehensive Test Suite: 20/20 tests passed
   - Demo Configurations: 5/5 tests passed
   - **Total: 60/60 tests (100% pass rate)**

5. **Performance Impact**
   - Lua script SHA-256 overhead: <3.3%
   - Overall FIPS overhead: <5%
   - Memory footprint: ~14 MB (idle)
   - Production-ready performance

---

## References

- **DISA STIG:** https://public.cyber.mil/stigs/
- **OpenSCAP:** https://www.open-scap.org/
- **NIST SCAP:** https://csrc.nist.gov/projects/security-content-automation-protocol
- **XCCDF Specification:** https://csrc.nist.gov/publications/detail/nistir/7275/rev-4/final
- **FIPS 140-3 Certificate #4718:** https://csrc.nist.gov/projects/cryptographic-module-validation-program/certificate/4718
- **Redis Documentation:** https://redis.io/documentation
- **wolfSSL FIPS Documentation:** https://www.wolfssl.com/documentation/manuals/wolfssl/chapter13.html
- **Alpine Linux Security:** https://alpinelinux.org/about/

---

## Document Metadata

- **Author:** Root Security Team
- **Classification:** PUBLIC
- **Distribution:** UNLIMITED
- **Version:** 1.0
- **Last Updated:** 2026-03-26
- **Related Documents:**
  - SCAP-Results.xml
  - SCAP-Results.html
  - STIG-Template.xml
  - POC-VALIDATION-REPORT.md
  - Evidence/test-execution-summary.md
  - Evidence/diagnostic_results.txt
  - Evidence/contrast-test-results.md
  - compliance/CHAIN-OF-CUSTODY.md

---

**END OF SUMMARY**
