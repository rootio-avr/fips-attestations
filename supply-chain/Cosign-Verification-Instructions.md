# Cosign Verification Instructions

**Version:** 1.0
**Date:** 2026-03-04

---

## Overview

This document provides complete instructions for verifying the cryptographic signatures and attestations of the FIPS POC container images using Cosign (Sigstore).

All images are signed with:
- ✅ **Image signatures** (integrity verification)
- ✅ **SLSA Level 2 attestations** (provenance verification)
- ✅ **SBOM attestations** (software bill of materials)

---

## Prerequisites

### Install Cosign

```bash
# Linux/macOS (Homebrew)
brew install cosign

# Linux (Binary download)
wget https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64
chmod +x cosign-linux-amd64
sudo mv cosign-linux-amd64 /usr/local/bin/cosign

# Verify installation
cosign version
```

**Official Installation Guide:** https://docs.sigstore.dev/cosign/installation/

### Obtain Public Key

```bash
# Download the public key used for signing
# (Replace with actual public key distribution method)

# Option 1: From repository
cat > cosign.pub <<EOF
-----BEGIN PUBLIC KEY-----
... public key content ...
-----END PUBLIC KEY-----
EOF

# Option 2: From secure key management service
# cosign public-key --key azurekms://[VAULT_NAME][VAULT_URI]/[KEY]
```

---

## Image References

| Image | Registry | Tag | Purpose |
|-------|----------|-----|---------|
| **ubuntu-fips-go** | `localhost:5000` | `v1.0.0-ubuntu-22.04` | Go FIPS runtime |
| **ubuntu-fips-java** | `localhost:5000` | `v1.0.0-ubuntu-22.04` | Java FIPS runtime |

**Note:** Replace `localhost:5000` with your actual registry:
- Docker Hub: `yourorg/ubuntu-fips-go:v1.0.0-ubuntu-22.04`
- GitHub Container Registry: `ghcr.io/yourorg/ubuntu-fips-go:v1.0.0-ubuntu-22.04`
- AWS ECR: `123456789.dkr.ecr.us-east-1.amazonaws.com/ubuntu-fips-go:v1.0.0-ubuntu-22.04`

---

## Verification Workflows

### 1. Verify Image Signature (Basic)

Verify the cryptographic signature of the container image:

```bash
# Verify Go image
cosign verify \
  --key cosign.pub \
  localhost:5000/ubuntu-fips-go:v1.0.0-ubuntu-22.04

# Verify Java image
cosign verify \
  --key cosign.pub \
  localhost:5000/ubuntu-fips-java:v1.0.0-ubuntu-22.04
```

**Expected Output:**
```json
[
  {
    "critical": {
      "identity": {
        "docker-reference": "localhost:5000/ubuntu-fips-go"
      },
      "image": {
        "docker-manifest-digest": "sha256:..."
      },
      "type": "cosign container image signature"
    },
    "optional": {
      "BuildDate": "2026-03-04T00:00:00Z",
      "Version": "v1.0.0-ubuntu-22.04"
    }
  }
]
```

**Verification Status:**
- ✅ **Valid signature** → Image integrity confirmed, safe to use
- ❌ **Invalid signature** → Image has been tampered with, DO NOT USE

---

### 2. Verify SLSA Attestation

Verify the SLSA (Supply chain Levels for Software Artifacts) provenance:

```bash
# Verify Go image SLSA attestation
cosign verify-attestation \
  --type slsaprovenance \
  --key cosign.pub \
  localhost:5000/ubuntu-fips-go:v1.0.0-ubuntu-22.04

# Verify Java image SLSA attestation
cosign verify-attestation \
  --type slsaprovenance \
  --key cosign.pub \
  localhost:5000/ubuntu-fips-java:v1.0.0-ubuntu-22.04
```

**Expected Output:**
```json
{
  "payloadType": "application/vnd.in-toto+json",
  "payload": "...",
  "signatures": [
    {
      "keyid": "",
      "sig": "..."
    }
  ]
}
```

**What This Verifies:**
- ✅ Build environment and parameters
- ✅ Source repository and commit
- ✅ Build dependencies
- ✅ Builder identity

---

### 3. Verify SBOM Attestation

Verify the Software Bill of Materials (SBOM) attestation:

```bash
# Verify Go image SBOM
cosign verify-attestation \
  --type spdx \
  --key cosign.pub \
  localhost:5000/ubuntu-fips-go:v1.0.0-ubuntu-22.04

# Verify Java image SBOM
cosign verify-attestation \
  --type spdx \
  --key cosign.pub \
  localhost:5000/ubuntu-fips-java:v1.0.0-ubuntu-22.04
```

**What This Verifies:**
- ✅ Complete list of software components
- ✅ Package versions and licenses
- ✅ Dependency tree integrity

---

### 4. Extract and Inspect Attestations

Extract attestations for detailed inspection:

```bash
# Extract SLSA provenance for Go image
cosign verify-attestation \
  --type slsaprovenance \
  --key cosign.pub \
  localhost:5000/ubuntu-fips-go:v1.0.0-ubuntu-22.04 \
  | jq -r '.payload' | base64 -d | jq .

# Extract SBOM for Go image
cosign verify-attestation \
  --type spdx \
  --key cosign.pub \
  localhost:5000/ubuntu-fips-go:v1.0.0-ubuntu-22.04 \
  | jq -r '.payload' | base64 -d | jq .
```

**Use Cases:**
- Security audits
- Compliance documentation
- Vulnerability tracking
- License verification

---

### 5. Verify Image Digest (Immutable Reference)

Pull and verify images by their cryptographic digest:

```bash
# Get image digest for Go image
IMAGE_DIGEST=$(docker inspect \
  --format='{{index .RepoDigests 0}}' \
  localhost:5000/ubuntu-fips-go:v1.0.0-ubuntu-22.04)

echo "Go Image Digest: $IMAGE_DIGEST"

# Pull by digest (immutable reference)
docker pull $IMAGE_DIGEST

# Verify signature using digest
cosign verify \
  --key cosign.pub \
  $IMAGE_DIGEST
```

**Why This Matters:**
- Tags can be moved/updated
- Digests are immutable and content-addressable
- Production deployments should always use digests

---

## Automated Verification Script

Use the provided script to verify all images at once:

```bash
# Run automated verification
./verify-all.sh

# Expected output:
# ✅ Go image signature: VALID
# ✅ Go SLSA attestation: VALID
# ✅ Go SBOM attestation: VALID
# ✅ Java image signature: VALID
# ✅ Java SLSA attestation: VALID
# ✅ Java SBOM attestation: VALID
```

---

## Troubleshooting

### Error: "no matching signatures"

**Cause:** Public key mismatch or image not signed

**Solution:**
1. Verify you have the correct public key
2. Check image reference is correct (registry/name/tag)
3. Ensure image was signed with the expected key

```bash
# List all signatures for an image
cosign tree localhost:5000/ubuntu-fips-go:v1.0.0-ubuntu-22.04
```

---

### Error: "failed to verify signature"

**Cause:** Image has been modified after signing

**Solution:**
1. **DO NOT USE THE IMAGE** - integrity compromised
2. Re-pull the image from trusted source
3. Verify digest matches expected value
4. Contact image maintainer if issue persists

---

### Error: "unsupported attestation type"

**Cause:** Trying to verify attestation type that wasn't attached

**Solution:**
1. Check available attestation types:
   ```bash
   cosign verify-attestation \
     --key cosign.pub \
     localhost:5000/ubuntu-fips-go:v1.0.0-ubuntu-22.04 \
     | jq -r '.payloadType'
   ```

2. Use the correct `--type` flag based on available attestations

---

## Keyless Verification (Sigstore Public Instance)

If images are signed using Sigstore's keyless signing:

```bash
# Verify without a key (uses Sigstore's transparency log)
cosign verify \
  localhost:5000/ubuntu-fips-go:v1.0.0-ubuntu-22.04

# Verify attestation keyless
cosign verify-attestation \
  --type slsaprovenance \
  localhost:5000/ubuntu-fips-go:v1.0.0-ubuntu-22.04
```

**Requirements:**
- Image must be signed with `cosign sign` (without `--key` flag)
- Relies on Sigstore's Fulcio CA and Rekor transparency log
- Requires internet access for verification

---

## Security Best Practices

### 1. Always Verify Before Use

```bash
# GOOD: Verify before running
cosign verify --key cosign.pub localhost:5000/ubuntu-fips-go:v1.0.0-ubuntu-22.04 && \
  docker run --rm localhost:5000/ubuntu-fips-go:v1.0.0-ubuntu-22.04

# BAD: Run without verification
docker run --rm localhost:5000/ubuntu-fips-go:v1.0.0-ubuntu-22.04
```

### 2. Use Immutable Digest References in Production

```bash
# GOOD: Digest reference (immutable)
docker run --rm localhost:5000/ubuntu-fips-go@sha256:abc123...

# BAD: Tag reference (mutable)
docker run --rm localhost:5000/ubuntu-fips-go:v1.0.0-ubuntu-22.04
```

### 3. Store Public Keys Securely

- ✅ Version control public keys (safe to share)
- ✅ Use key management services (Azure Key Vault, AWS KMS, etc.)
- ✅ Rotate keys periodically
- ❌ Never commit private keys to repositories

### 4. Verify SLSA Provenance

```bash
# Check builder identity and source repository
cosign verify-attestation \
  --type slsaprovenance \
  --key cosign.pub \
  localhost:5000/ubuntu-fips-go:v1.0.0-ubuntu-22.04 \
  | jq -r '.payload' | base64 -d | jq '.predicate.builder.id'
```

---

## Integration with CI/CD

### Example: GitLab CI

```yaml
verify-images:
  stage: verify
  image: alpine:latest
  before_script:
    - apk add --no-cache cosign
  script:
    - cosign verify --key cosign.pub localhost:5000/ubuntu-fips-go:v1.0.0-ubuntu-22.04
    - cosign verify --key cosign.pub localhost:5000/ubuntu-fips-java:v1.0.0-ubuntu-22.04
  only:
    - main
```

### Example: GitHub Actions

```yaml
- name: Verify image signatures
  run: |
    cosign verify \
      --key cosign.pub \
      localhost:5000/ubuntu-fips-go:v1.0.0-ubuntu-22.04

    cosign verify \
      --key cosign.pub \
      localhost:5000/ubuntu-fips-java:v1.0.0-ubuntu-22.04
```

---

## References

- [Cosign Documentation](https://docs.sigstore.dev/cosign/overview/)
- [SLSA Framework](https://slsa.dev/)
- [Sigstore Project](https://www.sigstore.dev/)
- [NIST Supply Chain Security](https://www.nist.gov/itl/executive-order-improving-nations-cybersecurity/software-supply-chain-security-guidance)
- [in-toto Attestation Specification](https://github.com/in-toto/attestation)

---

## Support

For issues with signature verification:
1. Check public key is correct
2. Verify image reference (registry/name/tag)
3. Ensure cosign version is up to date (`cosign version`)
4. Review troubleshooting section above
5. Contact image maintainer with verification logs

---

## Document Metadata

- **Author:** Focaloid Security Team
- **Classification:** PUBLIC
- **Distribution:** UNLIMITED
- **Version:** 1.0
- **Last Updated:** 2026-03-04

---

**END OF DOCUMENT**
