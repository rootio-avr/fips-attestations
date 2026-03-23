# Cosign Verification Guide for Python 3.12 FIPS Image

## Overview

This guide explains how to verify cosign signatures for the Python 3.12 FIPS container image (`cr.root.io/python:3.12-bookworm-slim-fips`) stored in AWS ECR. The image is signed using Sigstore's keyless signing method with ephemeral keys.

## Prerequisites

1. **Cosign installed**: Version 2.x or later
   ```bash
   cosign version
   ```

2. **AWS CLI configured**: With credentials for ECR access
   ```bash
   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <redacted_root_ecr_base>
   ```

3. **Docker installed**: For pulling images

## Image Information

**Image:** `cr.root.io/python:3.12-bookworm-slim-fips`
**Base:** Python 3.12 on Debian Bookworm (Slim)
**ECR Repository:** `root-reg/python`
**Signing Method:** Keyless signing via Sigstore

## Verification Methods

### Method 1: Verify Using Tag (Simple)

Verify the image using its tag. This is straightforward but note that tags can change.

```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/cr.root.io/python:3.12-bookworm-slim-fips
```

### Method 2: Verify Using Digest (Recommended)

Verify using the image digest for immutable verification. First, get the digest from the image:

```bash
# Get the digest
docker pull <redacted_root_ecr_base>/root-reg/cr.root.io/python:3.12-bookworm-slim-fips
docker inspect <redacted_root_ecr_base>/root-reg/cr.root.io/python:3.12-bookworm-slim-fips --format '{{index .RepoDigests 0}}'
```

Then verify using the digest:

```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/python@sha256:<digest-from-above>
```

### Expected Output

Successful verification will output JSON with signature details:

```json
[{
  "critical": {
    "identity": {
      "docker-reference": "<redacted_root_ecr_base>/root-reg/cr.root.io/python:3.12-bookworm-slim-fips"
    },
    "image": {
      "docker-manifest-digest": "sha256:<image-digest>"
    },
    "type": "https://sigstore.dev/cosign/sign/v1"
  },
  "optional": {}
}]
```

## Verifying Proxy Images (cr.root.io)

The cr.root.io proxy is read-only and doesn't store signature artifacts. To verify images pulled from the proxy:

1. **Pull from proxy** (for runtime use):
   ```bash
   docker pull cr.root.io/cr.root.io/python:3.12-bookworm-slim-fips
   ```

2. **Get the digest** from the pulled image:
   ```bash
   docker inspect cr.root.io/cr.root.io/python:3.12-bookworm-slim-fips --format '{{index .RepoDigests 0}}'
   ```

3. **Verify against ECR** using the digest:
   ```bash
   cosign verify \
     --certificate-identity-regexp '.*' \
     --certificate-oidc-issuer-regexp '.*' \
     <redacted_root_ecr_base>/root-reg/python@sha256:<digest-from-step-2>
   ```

## Advanced Commands

### View Signature Artifacts

Show the supply chain security artifacts attached to the image:

```bash
cosign tree <redacted_root_ecr_base>/root-reg/cr.root.io/python:3.12-bookworm-slim-fips
```

Example output:
```
📦 Supply Chain Security Related artifacts for an image: <redacted_root_ecr_base>/root-reg/cr.root.io/python:3.12-bookworm-slim-fips
└── 🔗 https://sigstore.dev/cosign/sign/v1 artifacts via OCI referrer: <redacted_root_ecr_base>/root-reg/python@sha256:<digest>
   └── 🍒 sha256:<signature-digest>
```

### List All Signature Artifacts in ECR

View all signature artifacts for Python images in the ECR repository:

```bash
aws ecr describe-images \
  --repository-name root-reg/python \
  --region us-east-1 \
  --query 'imageDetails[?imageSizeInBytes < `10000`].[imageDigest, imageSizeInBytes, imageManifestMediaType]' \
  --output table
```

### Download and Inspect the Signature Bundle

```bash
# Download the signature bundle
cosign download signature <redacted_root_ecr_base>/root-reg/cr.root.io/python:3.12-bookworm-slim-fips

# View certificate details
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/cr.root.io/python:3.12-bookworm-slim-fips | jq
```

## Troubleshooting

### Error: no signatures found

This error means:
- The image is not signed, or
- You're trying to verify through a proxy that doesn't support OCI referrers
- **Solution:** Verify against the ECR URL directly, not the proxy

### Error: --certificate-identity or --certificate-identity-regexp is required

Cosign requires identity verification flags for keyless signatures.
- Use `--certificate-identity-regexp '.*'` and `--certificate-oidc-issuer-regexp '.*'` for basic verification
- For production, use specific identity patterns to ensure only authorized signers

### Error: response did not include Docker-Content-Digest header

This indicates:
- The registry doesn't support required OCI headers
- Cannot be used for signing operations
- **Solution:** Sign against ECR directly, not the proxy

### Verification Fails with Certificate Errors

If you see certificate validation errors:
1. Ensure you're using cosign v2.x or later
2. Check that your system time is correct (certificates are time-sensitive)
3. Verify you have internet access to reach Sigstore infrastructure

## Signing Information

**Signing Method:** Keyless signing via Sigstore
- **Authentication:** OAuth2 device flow
- **Key Type:** Ephemeral keys (generated per signing operation)
- **Transparency Log:** Rekor (public log at rekor.sigstore.dev)
- **Certificate Authority:** Fulcio (Sigstore's certificate authority)

**Signature Storage:**
- Signatures are stored as OCI artifacts in ECR
- Linked to images via OCI Referrers specification
- Small artifacts (~6KB) containing signature bundles
- Each signature includes certificate chain and transparency log entry

## Security Considerations

1. **Digest Verification:** Always verify using digests in production for immutability
2. **Certificate Identity:** In production, use specific certificate identity patterns instead of `.*`
3. **Transparency Log:** Signatures are publicly logged in Rekor for audit purposes
4. **Registry Access:** Ensure proper AWS IAM permissions for ECR access
5. **Proxy Limitations:** Be aware that read-only proxies cannot store signatures
6. **Time Sensitivity:** Keyless signatures use short-lived certificates; verify promptly after signing
7. **Audit Trail:** Check Rekor transparency log for tamper-evidence

## Best Practices

1. **Always use digest-based verification** in production environments
2. **Pin specific certificate identities** when possible for stronger verification
3. **Automate verification** in CI/CD pipelines before deployment
4. **Monitor Rekor logs** for unexpected signing events
5. **Store image digests** alongside deployment manifests
6. **Verify before pull** in production to prevent supply chain attacks

## FIPS-Specific Verification

For Python FIPS images, additional verification steps ensure FIPS compliance:

### Verify FIPS Components After Pull

After verifying the image signature, verify FIPS components are intact:

```bash
# Pull the verified image
docker pull <redacted_root_ecr_base>/root-reg/cr.root.io/python:3.12-bookworm-slim-fips

# Run FIPS verification
docker run --rm <redacted_root_ecr_base>/root-reg/cr.root.io/python:3.12-bookworm-slim-fips python3 -c "
import ssl
print(f'OpenSSL Version: {ssl.OPENSSL_VERSION}')
print(f'Available Ciphers: {len(ssl.create_default_context().get_ciphers())}')
"

# Expected output:
# ✓ Library checksum verification: All integrity checks passed
# ✓ FIPS KAT: FIPS KAT passed successfully
# ✓ FIPS Container Verification: All checks passed (7/7)
# OpenSSL Version: OpenSSL 3.0.18 30 Sep 2025
# Available Ciphers: 14
```

### Run Full Diagnostic Tests

For comprehensive FIPS validation:

```bash
# Clone the repository with diagnostic tests
git clone <repository-url>
cd python/3.12-bookworm-slim-fips

# Run all FIPS diagnostic tests
docker run --rm \
  -v $(pwd)/diagnostics:/diagnostics \
  <redacted_root_ecr_base>/root-reg/cr.root.io/python:3.12-bookworm-slim-fips \
  bash -c 'cd /diagnostics && ./run-all-tests.sh'

# Expected: ✅ ALL TEST SUITES PASSED (5/5, 100%)
```

### Verify MD5 Blocking (FIPS Enforcement Proof)

Verify that MD5 is blocked at the OpenSSL level (proves FIPS enforcement is real):

```bash
docker run --rm <redacted_root_ecr_base>/root-reg/cr.root.io/python:3.12-bookworm-slim-fips \
  bash -c "echo -n 'test' | openssl dgst -md5"

# Expected output: Error setting digest (unsupported)
# This confirms FIPS mode is enforced via default_properties=fips=yes
```

## Additional Resources

- [Cosign Documentation](https://docs.sigstore.dev/cosign/overview/)
- [Sigstore Project](https://www.sigstore.dev/)
- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [OCI Referrers Specification](https://github.com/opencontainers/distribution-spec/blob/main/spec.md#listing-referrers)
- [Rekor Transparency Log](https://rekor.sigstore.dev/)
- [Python FIPS Documentation](../README.md)
- [FIPS 140-3 Certificate #4718](https://csrc.nist.gov/projects/cryptographic-module-validation-program/certificate/4718)
