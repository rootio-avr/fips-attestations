# Cosign Verification Guide for Podman 5.8.1 FIPS Image

## Overview

This guide explains how to verify cosign signatures for the Podman 5.8.1 FIPS container image (`podman:5.8.1-fedora-44-fips`) stored in AWS ECR. The image is signed using Sigstore's keyless signing method with ephemeral keys.

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

**Image:** `podman:5.8.1-fedora-44-fips`
**Base:** Fedora 44
**Components:**
- Podman v5.8.1 (built from source)
- golang-fips/go v1.25
- wolfSSL FIPS v5.8.2 (Certificate #4718)
- OpenSSL 3.5.0
- wolfProvider v1.1.1

**ECR Repository:** `root-reg/podman`
**Signing Method:** Keyless signing via Sigstore

## Verification Methods

### Method 1: Verify Using Tag (Simple)

Verify the image using its tag. This is straightforward but note that tags can change.

```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/podman:5.8.1-fedora-44-fips
```

### Method 2: Verify Using Digest (Recommended)

Verify using the image digest for immutable verification. First, get the digest from the image:

```bash
# Get the digest
docker pull <redacted_root_ecr_base>/root-reg/podman:5.8.1-fedora-44-fips
docker inspect <redacted_root_ecr_base>/root-reg/podman:5.8.1-fedora-44-fips --format '{{index .RepoDigests 0}}'
```

Then verify using the digest:

```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/podman@sha256:<digest-from-previous-command>
```

### Expected Output

Successful verification will output JSON with signature details:

```json
[{
  "critical": {
    "identity": {
      "docker-reference": "<redacted_root_ecr_base>/root-reg/podman:5.8.1-fedora-44-fips"
    },
    "image": {
      "docker-manifest-digest": "sha256:<image-digest>"
    },
    "type": "https://sigstore.dev/cosign/sign/v1"
  },
  "optional": {
    "podman-version": "5.8.1",
    "golang-fips-version": "1.25",
    "wolfssl-fips-version": "5.8.2",
    "wolfssl-certificate": "4718",
    "openssl-version": "3.5.0"
  }
}]
```

## Verifying Proxy Images (cr.root.io)

The cr.root.io proxy is read-only and doesn't store signature artifacts. To verify images pulled from the proxy:

1. **Pull from proxy** (for runtime use):
   ```bash
   docker pull cr.root.io/podman:5.8.1-fedora-44-fips
   ```

2. **Get the digest** from the pulled image:
   ```bash
   docker inspect cr.root.io/podman:5.8.1-fedora-44-fips --format '{{index .RepoDigests 0}}'
   ```

3. **Verify against ECR** using the digest:
   ```bash
   cosign verify \
     --certificate-identity-regexp '.*' \
     --certificate-oidc-issuer-regexp '.*' \
     <redacted_root_ecr_base>/root-reg/podman@sha256:<digest-from-step-2>
   ```

## Advanced Commands

### View Signature Artifacts

Show the supply chain security artifacts attached to the image:

```bash
cosign tree <redacted_root_ecr_base>/root-reg/podman:5.8.1-fedora-44-fips
```

Example output:
```
📦 Supply Chain Security Related artifacts for an image: <redacted_root_ecr_base>/root-reg/podman:5.8.1-fedora-44-fips
└── 🔗 https://sigstore.dev/cosign/sign/v1 artifacts via OCI referrer: <redacted_root_ecr_base>/root-reg/podman@sha256:<digest>
   └── 🍒 sha256:<signature-digest>
```

### List All Signature Artifacts in ECR

View all signature artifacts for Podman images in the ECR repository:

```bash
aws ecr describe-images \
  --repository-name root-reg/podman \
  --region us-east-1 \
  --query 'imageDetails[?imageSizeInBytes < `10000`].[imageDigest, imageSizeInBytes, imageManifestMediaType]' \
  --output table
```

### Download and Inspect the Signature Bundle

```bash
# Download the signature bundle
cosign download signature <redacted_root_ecr_base>/root-reg/podman:5.8.1-fedora-44-fips

# View certificate details
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/podman:5.8.1-fedora-44-fips | jq
```

### Verify Specific FIPS Components

After pulling the image, verify FIPS components are intact:

```bash
# Verify wolfSSL FIPS self-test
docker run --rm cr.root.io/podman:5.8.1-fedora-44-fips test-fips

# Verify OpenSSL providers
docker run --rm cr.root.io/podman:5.8.1-fedora-44-fips openssl list -providers

# Verify FIPS environment
docker run --rm cr.root.io/podman:5.8.1-fedora-44-fips env | grep -E '(GOLANG_FIPS|GODEBUG|GOEXPERIMENT)'

# Verify Podman version
docker run --rm cr.root.io/podman:5.8.1-fedora-44-fips podman --version
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

### Error: image not found or unauthorized

If you receive 403 or 404 errors:
1. Verify AWS credentials are configured: `aws ecr get-login-password`
2. Ensure you have proper IAM permissions for ECR repository access
3. Check that the image tag/digest exists in the repository

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

**Signature Metadata (Optional Annotations):**
- podman-version: 5.8.1
- golang-fips-version: 1.25
- wolfssl-fips-version: 5.8.2
- wolfssl-certificate: 4718
- openssl-version: 3.5.0
- base-image: fedora:44
- build-date: Timestamp of build

## Security Considerations

1. **Digest Verification:** Always verify using digests in production for immutability
2. **Certificate Identity:** In production, use specific certificate identity patterns instead of `.*`
3. **Transparency Log:** Signatures are publicly logged in Rekor for audit purposes
4. **Registry Access:** Ensure proper AWS IAM permissions for ECR access
5. **Proxy Limitations:** Be aware that read-only proxies cannot store signatures
6. **Time Sensitivity:** Keyless signatures use short-lived certificates; verify promptly after signing
7. **Audit Trail:** Check Rekor transparency log for tamper-evidence
8. **FIPS Validation:** After signature verification, also validate FIPS components with test-fips utility

## FIPS-Specific Verification

For FIPS compliance verification, after cosign verification succeeds:

```bash
# Run complete diagnostic suite
docker run --rm \
  -v $(pwd)/diagnostics:/diagnostics \
  -w /diagnostics \
  cr.root.io/podman:5.8.1-fedora-44-fips \
  bash -c './run-diagnostics.sh'

# Or run individual verification
docker run --rm cr.root.io/podman:5.8.1-fedora-44-fips test-fips

# Expected output:
# wolfSSL FIPS Test Utility
# =========================
# wolfSSL version: 5.8.2
# FIPS mode: ENABLED
# FIPS version: 5
# ✓ wolfSSL FIPS test PASSED
# ✓ FIPS module is correctly installed
```

## Best Practices

1. **Always use digest-based verification** in production environments
2. **Pin specific certificate identities** when possible for stronger verification
3. **Automate verification** in CI/CD pipelines before deployment
4. **Monitor Rekor logs** for unexpected signing events
5. **Store image digests** alongside deployment manifests
6. **Verify before pull** in production to prevent supply chain attacks
7. **Run FIPS diagnostics** after signature verification for complete assurance
8. **Document verification results** for compliance auditing
9. **Verify both signature AND FIPS status** before using in production
10. **Test privileged operations** if Podman will be used for container management

## Example: Complete Verification Workflow

```bash
#!/bin/bash
# Complete verification workflow for Podman FIPS image

set -e

IMAGE_TAG="<redacted_root_ecr_base>/root-reg/podman:5.8.1-fedora-44-fips"

echo "Step 1: Pull image"
docker pull "$IMAGE_TAG"

echo "Step 2: Get image digest"
DIGEST=$(docker inspect "$IMAGE_TAG" --format '{{index .RepoDigests 0}}')
echo "Image digest: $DIGEST"

echo "Step 3: Verify cosign signature"
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  "$DIGEST"

echo "Step 4: Verify FIPS components"
docker run --rm "$IMAGE_TAG" test-fips

echo "Step 5: Verify Podman functionality"
docker run --rm "$IMAGE_TAG" podman --version

echo "Step 6: Verify OpenSSL providers"
docker run --rm "$IMAGE_TAG" openssl list -providers | grep -E '(fips|wolfssl)'

echo "✓ All verification checks passed!"
```

## Integration with CI/CD

### GitHub Actions Example

```yaml
- name: Verify Podman FIPS Image
  run: |
    # Login to ECR
    aws ecr get-login-password --region us-east-1 | \
      docker login --username AWS --password-stdin <redacted_root_ecr_base>

    # Verify signature
    cosign verify \
      --certificate-identity-regexp '.*' \
      --certificate-oidc-issuer-regexp '.*' \
      <redacted_root_ecr_base>/root-reg/podman:5.8.1-fedora-44-fips

    # Verify FIPS
    docker run --rm <redacted_root_ecr_base>/root-reg/podman:5.8.1-fedora-44-fips test-fips
```

### GitLab CI Example

```yaml
verify-podman-image:
  stage: verify
  image: bitnami/cosign:latest
  script:
    - aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <redacted_root_ecr_base>
    - cosign verify --certificate-identity-regexp '.*' --certificate-oidc-issuer-regexp '.*' <redacted_root_ecr_base>/root-reg/podman:5.8.1-fedora-44-fips
    - docker run --rm <redacted_root_ecr_base>/root-reg/podman:5.8.1-fedora-44-fips test-fips
```

## Additional Resources

- [Cosign Documentation](https://docs.sigstore.dev/cosign/overview/)
- [Sigstore Project](https://www.sigstore.dev/)
- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [OCI Referrers Specification](https://github.com/opencontainers/distribution-spec/blob/main/spec.md#listing-referrers)
- [Rekor Transparency Log](https://rekor.sigstore.dev/)
- [Podman Documentation](https://docs.podman.io/)
- [golang-fips/go Project](https://github.com/golang-fips/go)
- [wolfSSL FIPS 140-3](https://www.wolfssl.com/products/wolfssl-fips/)
- [NIST CMVP Certificate #4718](https://csrc.nist.gov/projects/cryptographic-module-validation-program)

## Support

For issues related to:
- **Cosign verification**: Check Sigstore documentation or GitHub issues
- **ECR access**: Review AWS IAM permissions and ECR repository policies
- **FIPS compliance**: Verify wolfSSL FIPS module installation and configuration
- **Podman functionality**: Consult Podman documentation or test with --privileged mode
- **Image issues**: Contact Root Security Team at security@root.io

## Document Metadata

- **Version**: 1.0
- **Last Updated**: 2026-04-17
- **Author**: Root Security Team
- **Classification**: PUBLIC
- **Distribution**: UNLIMITED
