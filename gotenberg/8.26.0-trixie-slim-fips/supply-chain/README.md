# Supply Chain Security Documentation
# Gotenberg 8.26.0 Debian Trixie FIPS Image

**Image:** cr.root.io/gotenberg:8.26.0-trixie-slim-fips
**Version:** 1.0
**Date:** April 16, 2026

---

## Overview

This directory contains supply chain security documentation and verification tools for the Gotenberg 8.26.0 Debian Trixie FIPS container image.

**Purpose:** Provide cryptographic verification, attestation, and transparency for the complete software supply chain from source acquisition through distribution.

---

## Available Documentation

### 1. Cosign Verification Instructions
**File:** `Cosign-Verification-Instructions.md`

Comprehensive guide for verifying image signatures and attestations using Cosign/Sigstore.

**Contents:**
- Cosign installation instructions
- Image signature verification
- SLSA provenance verification
- SBOM verification
- Policy enforcement examples
- Troubleshooting guide

**Quick Verification:**
```bash
# Verify image signature
cosign verify --key cosign.pub cr.root.io/gotenberg:8.26.0-trixie-slim-fips

# Verify SLSA provenance
cosign verify-attestation --type slsaprovenance \
    --key cosign.pub \
    cr.root.io/gotenberg:8.26.0-trixie-slim-fips
```

---

## Related Documentation

### Compliance Artifacts
Located in `../compliance/` directory:

- **SBOM (sbom.json):** Software Bill of Materials in SPDX 2.3 format
- **SLSA Provenance (slsa-provenance.json):** Build provenance attestation
- **VEX (vex.json):** Vulnerability Exploitability eXchange document
- **Chain of Custody (CHAIN-OF-CUSTODY.md):** Complete custody tracking

### Technical Documentation
Located in parent directory:

- **ARCHITECTURE.md:** Detailed technical architecture
- **ATTESTATION.md:** FIPS 140-3 compliance attestation
- **POC-VALIDATION-REPORT.md:** Validation and testing results

---

## Supply Chain Security Features

### 1. Cryptographic Signing
- ✅ Image signed with Cosign
- ✅ Keyless signing with Sigstore (optional)
- ✅ Private key signing supported
- ✅ Signature verification required before deployment

### 2. Provenance Tracking
- ✅ SLSA provenance attestation
- ✅ Build environment documented
- ✅ Source code commits tracked
- ✅ Dependencies documented with hashes

### 3. Transparency
- ✅ Complete SBOM (13 major components)
- ✅ License information for all components
- ✅ Chain of custody documentation
- ✅ Build process reproducibility

### 4. Vulnerability Management
- ✅ VEX document with exploitability assessments
- ✅ Regular security scanning
- ✅ Update policy documented
- ✅ Security contact information

---

## Quick Start

### Verify Image Before Use

**Minimum Recommended Verification:**
```bash
# 1. Install cosign
curl -LO https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64
chmod +x cosign-linux-amd64
sudo mv cosign-linux-amd64 /usr/local/bin/cosign

# 2. Obtain public key
# (Public key should be distributed separately from image)
curl -LO https://cr.root.io/gotenberg/8.26.0-trixie-slim-fips/cosign.pub

# 3. Verify signature
cosign verify --key cosign.pub cr.root.io/gotenberg:8.26.0-trixie-slim-fips

# 4. Pull only if verification succeeds
docker pull cr.root.io/gotenberg:8.26.0-trixie-slim-fips
```

---

## Continuous Verification

### Policy Enforcement with Admission Controllers

For Kubernetes deployments, enforce signature verification:

**Example Kyverno Policy:**
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-gotenberg-fips-image
spec:
  validationFailureAction: enforce
  rules:
  - name: verify-signature
    match:
      resources:
        kinds:
        - Pod
    verifyImages:
    - image: "cr.root.io/gotenberg:8.26.0-trixie-slim-fips"
      key: |-
        -----BEGIN PUBLIC KEY-----
        [Your Cosign Public Key]
        -----END PUBLIC KEY-----
```

---

## Security Contacts

**For security issues or questions:**
- Email: fips-team@root.io
- Security Policy: See SECURITY.md (if available)
- Response Time: 48 hours for security issues

---

## Additional Resources

- **Cosign Documentation:** https://docs.sigstore.dev/cosign/overview/
- **SLSA Framework:** https://slsa.dev/
- **SPDX Specification:** https://spdx.dev/
- **OpenVEX Specification:** https://github.com/openvex/spec
- **NIST CMVP:** https://csrc.nist.gov/projects/cmvp

---

**Maintained By:** Root FIPS Team
**Last Updated:** April 16, 2026
**Next Review:** July 16, 2026
