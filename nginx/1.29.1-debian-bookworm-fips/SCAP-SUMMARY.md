# SCAP Scan Summary - nginx:1.29.1-debian-bookworm-fips

**Scan Date:** 2026-03-25
**Scanner:** OpenSCAP 1.3.9
**Profile:** DISA STIG Baseline (Container-Adapted for Debian Bookworm)
**Image:** nginx:1.29.1-debian-bookworm-fips (Nginx 1.29.1 / Debian Bookworm)

---

## Executive Summary

This document summarizes the OpenSCAP security compliance scan results for the nginx container image. The scan evaluates compliance against DISA STIG baseline controls adapted for containerized environments.

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
# Entrypoint FIPS validation
/docker-entrypoint.sh

# FIPS POST execution
# (wolfSSL Known Answer Tests)

# OpenSSL provider verification
openssl list -providers

# Check OpenSSL configuration
cat /etc/ssl/openssl.cnf | grep -A10 "fips_sect"

# Test TLS connection with FIPS cipher
echo "Q" | openssl s_client -connect localhost:443 -tls1_3 2>&1 | grep "Cipher"

# Verify nginx SSL configuration
grep ssl_protocols /etc/nginx/nginx.conf
```

**Results:**
- wolfProvider v1.1.0: Active in OpenSSL provider system
- wolfSSL FIPS v5.8.2 (Certificate #4718): Active
- OpenSSL version: 3.0.19 27 Jan 2026
- Available ciphers: 14 (all FIPS-approved AES-GCM variants)
- FIPS property filtering: `default_properties = fips=yes` in /etc/ssl/openssl.cnf
- Nginx SSL protocols: TLSv1.2 TLSv1.3 only
- FIPS POST: Known Answer Tests (KAT) passed on container startup
- TLS 1.3 cipher verified: TLS_AES_256_GCM_SHA384
- TLS 1.2 cipher verified: ECDHE-RSA-AES256-GCM-SHA384

**Evidence Files:**
- `docker-entrypoint.sh`
- `Evidence/diagnostic_results.txt`
- `Evidence/test-execution-summary.md`
- `demos-image/test-demos.sh`

---

### Algorithm Blocking (SV-238198)

**Status:** ✅ PASS

**Check Performed:**
```bash
# Test MD5 blocking at OpenSSL level
echo -n "test" | openssl dgst -md5

# Test TLS 1.0 connection (should fail)
echo "Q" | timeout 3 openssl s_client -connect localhost:443 -tls1 2>&1 | grep "Cipher"

# Test TLS 1.1 connection (should fail)
echo "Q" | timeout 3 openssl s_client -connect localhost:443 -tls1_1 2>&1 | grep "Cipher"

# Check nginx SSL protocols configuration
grep ssl_protocols /etc/nginx/nginx.conf

# Check nginx SSL cipher configuration
grep ssl_ciphers /etc/nginx/nginx.conf

# Verify OpenSSL configuration
grep "default_properties" /etc/ssl/openssl.cnf
```

**Results:**
- MD5: ❌ BLOCKED at OpenSSL EVP API level (`openssl dgst -md5` returns "Error setting digest")
- TLS 1.0/1.1: ❌ BLOCKED (cannot negotiate - MD5-SHA1 digest unavailable in FIPS mode)
- 3DES, RC4, DES cipher suites: 0 available (blocked by wolfProvider)
- SHA-1 new TLS cipher suites: 0 available (blocked for new connections)
- SHA-1 verification: Available (legacy cert verification - FIPS 140-3 compliant)
- SHA-256, SHA-384, SHA-512: ✅ AVAILABLE (FIPS approved)
- AES-128-GCM, AES-256-GCM: ✅ AVAILABLE (14 FIPS cipher suites total)
- TLS 1.2, TLS 1.3: ✅ AVAILABLE (FIPS approved protocols)
- TLS 1.3 cipher: TLS_AES_256_GCM_SHA384 verified in live connection
- TLS 1.2 cipher: ECDHE-RSA-AES256-GCM-SHA384 verified in live connection

**Evidence Files:**
- `/etc/ssl/openssl.cnf` (default_properties = fips=yes)
- `/etc/nginx/nginx.conf` (ssl_protocols TLSv1.2 TLSv1.3)
- `Evidence/contrast-test-results.md` (MD5 blocking proof)
- `Evidence/diagnostic_results.txt` (TLS 1.0/1.1 blocking tests)

---

### Audit Logging (SV-238199)

**Status:** ✅ PASS

**Check Performed:**
```bash
# Container entrypoint validation
cat /docker-entrypoint.sh

# Review container startup logs
docker logs <container-id>

# Check nginx access log configuration
grep access_log /etc/nginx/nginx.conf

# Check nginx error log configuration
grep error_log /etc/nginx/nginx.conf
```

**Results:**
- Entrypoint validation: docker-entrypoint.sh performs FIPS checks on startup
- FIPS POST: wolfSSL Known Answer Tests executed on every container startup
- OpenSSL provider verification: wolfProvider status checked on startup
- Nginx configuration validation: `nginx -t` executed before starting service
- Access logs: /var/log/nginx/access.log with SSL protocol and cipher logging
- Error logs: /var/log/nginx/error.log for SSL/TLS issues
- Startup checks: Container terminates if any validation fails (fail-fast)

**Validation Events:**
1. FIPS POST execution (wolfSSL Known Answer Tests)
2. OpenSSL provider validation (wolfProvider v1.1.0 status)
3. FIPS enforcement verification (default_properties=fips=yes)
4. Nginx configuration validation (nginx -t)
5. TLS protocol/cipher logging per request

**Evidence Files:**
- `docker-entrypoint.sh`
- `Evidence/diagnostic_results.txt` (Container Startup Verification)

---

### Package Integrity (SV-238200)

**Status:** ✅ PASS

**Check Performed:**
```bash
# Verify FIPS POST execution
docker logs <container> 2>&1 | grep "FIPS POST"

# Check OpenSSL provider
openssl list -providers

# SBOM presence
ls supply-chain/SBOM-nginx-1.29.1-debian-bookworm-fips.spdx.json

# Image signature
cosign verify nginx:1.29.1-debian-bookworm-fips

# Run diagnostic test suite
cd diagnostics/test-images/basic-test-image
./build.sh && docker run --rm nginx-fips-test:latest

# Run demo tests
cd demos-image
./test-demos.sh all
```

**Results:**
- wolfSSL FIPS: In-core integrity hash validated via fips-hash.sh during build
- FIPS POST: Known Answer Tests validate cryptographic module on every startup
- OpenSSL provider: wolfProvider v1.1.0 verified active
- SBOM generated: SPDX 2.3 format
- Image signed: Cosign signature with keyless signing via Sigstore
- VEX statement: Available (supply-chain/vex-nginx-1.29.1-debian-bookworm-fips.json)
- SLSA provenance: Available (supply-chain/slsa-provenance-nginx-1.29.1-debian-bookworm-fips.json)
- Test suite: 14/14 tests passed (100%) - 3 test suites
  - TLS Protocol Tests: 5/5 passed
  - FIPS Cipher Tests: 5/5 passed
  - Certificate Validation Tests: 4/4 passed
- Demo tests: 4/4 demo configurations passed
  - reverse-proxy.conf: 5/5 tests passed
  - static-webserver.conf: 5/5 tests passed
  - tls-termination.conf: 5/5 tests passed
  - strict-fips.conf: 4/4 tests passed

**Evidence Files:**
- `supply-chain/SBOM-nginx-1.29.1-debian-bookworm-fips.spdx.json`
- `supply-chain/vex-nginx-1.29.1-debian-bookworm-fips.json`
- `supply-chain/slsa-provenance-nginx-1.29.1-debian-bookworm-fips.json`
- `supply-chain/Cosign-Verification-Instructions.md`
- `Evidence/test-execution-summary.md`
- `Evidence/diagnostic_results.txt`

---

### Non-Root User (SV-238201)

**Status:** ✅ PASS

**Check Performed:**
```bash
# Check nginx configuration for user directive
grep "^user" /etc/nginx/nginx.conf

# Verify worker processes at runtime
docker exec <container> ps aux | grep nginx

# Inspect image USER directive
docker inspect nginx:1.29.1-debian-bookworm-fips | grep User
```

**Results:**
- Nginx master process: root (required for privileged ports 80/443)
- Nginx worker processes: nginx user (non-root)
- User directive in nginx.conf enforces worker process user
- Architecture: Standard nginx security model - master as root, workers as unprivileged
- Verified at runtime: ps aux shows worker processes running as nginx user

**Evidence:**
- `/etc/nginx/nginx.conf` (user nginx directive)
- Runtime process list verification
- Nginx worker processes run as non-root nginx user

---

### File Permissions (SV-238202)

**Status:** ✅ PASS

**Check Performed:**
```bash
# Find world-writable files
find / -type f -perm -002 2>/dev/null

# Check sensitive files
ls -la /usr/local/lib/libwolfssl.so*
ls -la /usr/local/openssl/lib64/ossl-modules/wolfprov.so
ls -la /etc/ssl/openssl.cnf
ls -la /etc/nginx/nginx.conf
ls -la /docker-entrypoint.sh
ls -la /etc/nginx/ssl/self-signed.key
```

**Results:**
- No world-writable files found
- wolfSSL libraries: 0644 (/usr/local/lib/libwolfssl.so.44.0.0)
- wolfProvider: 0644 (/usr/local/openssl/lib64/ossl-modules/wolfprov.so)
- OpenSSL configuration: 0644 (/etc/ssl/openssl.cnf)
- Nginx configuration: 0644 (/etc/nginx/nginx.conf)
- Entrypoint script: 0755 (/docker-entrypoint.sh)
- SSL certificates: 0644 (/etc/nginx/ssl/*.crt)
- SSL private keys: 0600 (/etc/nginx/ssl/*.key)

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
| SV-238212 | Service enumeration | Only nginx process runs |
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

5. **TLS/SSL Best Practices**
   - Use CA-signed certificates in production (not self-signed)
   - Rotate certificates before expiration
   - Monitor TLS protocol usage via nginx access logs
   - Regularly update cipher suite configuration based on FIPS guidance

---

## Scan Methodology

### Scan Execution

```bash
# Run container in background for scanning
docker run -d --name fips-nginx-scan \
  -p 80:80 -p 443:443 \
  nginx:1.29.1-debian-bookworm-fips

# Wait for nginx to be ready
sleep 2

# Execute SCAP scan
oscap xccdf eval \
  --profile container-fips-baseline \
  --results SCAP-Results.xml \
  --report SCAP-Results.html \
  STIG-Template.xml

# Test TLS connections
echo "Q" | openssl s_client -connect localhost:443 -tls1_3 2>&1 | grep "Cipher"
echo "Q" | openssl s_client -connect localhost:443 -tls1_2 2>&1 | grep "Cipher"

# Cleanup
docker stop fips-nginx-scan
docker rm fips-nginx-scan
```

### Scan Scope

**Included:**
- File system configuration
- Package integrity
- User and group settings
- Cryptographic configuration
- Audit logging
- Application permissions
- TLS/SSL configuration
- Web server security

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
| **Test Execution Summary** | `Evidence/test-execution-summary.md` | Detailed test results |
| **Diagnostic Results** | `Evidence/diagnostic_results.txt` | Raw test outputs |
| **Contrast Test Results** | `Evidence/contrast-test-results.md` | FIPS enforcement proof |
| **SBOM** | `supply-chain/SBOM-nginx-1.29.1-debian-bookworm-fips.spdx.json` | Software Bill of Materials |
| **VEX** | `supply-chain/vex-nginx-1.29.1-debian-bookworm-fips.json` | Vulnerability disclosure |
| **SLSA** | `supply-chain/slsa-provenance-nginx-1.29.1-debian-bookworm-fips.json` | Build provenance |

---

## Nginx-Specific Security Features

### FIPS-Compliant TLS Configuration

The nginx image includes comprehensive TLS security configurations:

1. **Protocol Restrictions**
   - TLS 1.2 and TLS 1.3 only
   - TLS 1.0/1.1 blocked at OpenSSL level (MD5-SHA1 digest unavailable)
   - SSLv3 not supported by client

2. **Cipher Suite Restrictions**
   - 14 FIPS-approved cipher suites only
   - All weak ciphers blocked (RC4, DES, 3DES)
   - Perfect Forward Secrecy enabled (ECDHE cipher suites)

3. **Demo Configurations**
   - `reverse-proxy.conf`: HTTPS reverse proxy with FIPS TLS
   - `static-webserver.conf`: HTTPS static content serving
   - `tls-termination.conf`: SSL offloading (HTTPS→HTTP backend)
   - `strict-fips.conf`: TLS 1.3 only, maximum security enforcement

4. **Security Headers**
   - Strict-Transport-Security (HSTS)
   - X-Frame-Options
   - X-Content-Type-Options
   - X-XSS-Protection
   - Content-Security-Policy

---

## References

- **DISA STIG:** https://public.cyber.mil/stigs/
- **OpenSCAP:** https://www.open-scap.org/
- **NIST SCAP:** https://csrc.nist.gov/projects/security-content-automation-protocol
- **XCCDF Specification:** https://csrc.nist.gov/publications/detail/nistir/7275/rev-4/final
- **FIPS 140-3 Certificate #4718:** https://csrc.nist.gov/projects/cryptographic-module-validation-program/certificate/4718
- **Nginx Security:** https://nginx.org/en/docs/http/ngx_http_ssl_module.html
- **wolfSSL FIPS Documentation:** https://www.wolfssl.com/documentation/manuals/wolfssl/chapter13.html

---

## Document Metadata

- **Author:** Root Security Team
- **Classification:** PUBLIC
- **Distribution:** UNLIMITED
- **Version:** 1.0
- **Last Updated:** 2026-03-25
- **Related Documents:**
  - SCAP-Results.xml
  - SCAP-Results.html
  - STIG-Template.xml
  - Evidence/test-execution-summary.md
  - Evidence/diagnostic_results.txt
  - Evidence/contrast-test-results.md
  - supply-chain/Cosign-Verification-Instructions.md

---

**END OF SUMMARY**
