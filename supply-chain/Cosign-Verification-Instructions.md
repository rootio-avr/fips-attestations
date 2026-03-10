# Cosign Verification Guide for ECR Images

## Overview

This guide explains how to verify cosign signatures for container images stored in AWS ECR. The images are signed using Sigstore's keyless signing method with ephemeral keys.

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

## Signed Images

The following images have been signed with cosign:

| Image Name | Tag | Digest | ECR Repository |
|------------|-----|--------|----------------|
| java | 17-jammy-ubuntu-22.04-fips | sha256:57188b45df1e59ceb69c230ef1a9ffe5b44e93cc827121744413683593901b44 | root-reg/java |
| golang | 1.25-jammy-ubuntu-22.04-fips | sha256:d48386da5fcaea2cfc40a659ab16d37bd27619a031210e2e394b8685b02b5fad | root-reg/golang |

## Verification Methods

### Method 1: Verify Using Tag (Simple)

Verify the image using its tag. This is straightforward but note the warning that tags can change.

**Java Image:**
```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/java:17-jammy-ubuntu-22.04-fips
```

**Golang Image:**
```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/golang:1.25-jammy-ubuntu-22.04-fips
```

### Method 2: Verify Using Digest (Recommended)

Verify using the image digest for immutable verification.

**Java Image:**
```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/java@sha256:57188b45df1e59ceb69c230ef1a9ffe5b44e93cc827121744413683593901b44
```

**Golang Image:**
```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/golang@sha256:d48386da5fcaea2cfc40a659ab16d37bd27619a031210e2e394b8685b02b5fad
```

### Expected Output

Successful verification will output JSON with signature details:

```json
[{
  "critical": {
    "identity": {
      "docker-reference": "<redacted_root_ecr_base>/root-reg/java:17-jammy-ubuntu-22.04-fips"
    },
    "image": {
      "docker-manifest-digest": "sha256:57188b45df1e59ceb69c230ef1a9ffe5b44e93cc827121744413683593901b44"
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
   docker pull cr.root.io/java:17-jammy-ubuntu-22.04-fips
   ```

2. **Verify against ECR** using the same digest:
   ```bash
   # Get the digest from the pulled image
   docker inspect cr.root.io/java:17-jammy-ubuntu-22.04-fips --format '{{index .RepoDigests 0}}'

   # Verify using the ECR reference
   cosign verify \
     --certificate-identity-regexp '.*' \
     --certificate-oidc-issuer-regexp '.*' \
     <redacted_root_ecr_base>/root-reg/java@sha256:57188b45df1e59ceb69c230ef1a9ffe5b44e93cc827121744413683593901b44
   ```

## Advanced Commands

### View Signature Artifacts

Show the supply chain security artifacts attached to an image:

**Java:**
```bash
cosign tree <redacted_root_ecr_base>/root-reg/java:17-jammy-ubuntu-22.04-fips
```

**Golang:**
```bash
cosign tree <redacted_root_ecr_base>/root-reg/golang:1.25-jammy-ubuntu-22.04-fips
```

Example output:
```
📦 Supply Chain Security Related artifacts for an image: <redacted_root_ecr_base>/root-reg/java:17-jammy-ubuntu-22.04-fips
└── 🔗 https://sigstore.dev/cosign/sign/v1 artifacts via OCI referrer: <redacted_root_ecr_base>/root-reg/java@sha256:6972503a1f2083a3c49d2c8aa1bd914c325bbe5884887f7d003e8286c8996218
   └── 🍒 sha256:26f1f642c6c31b76789cfea296e26558ac80e1363701c6f5856ec69fbf3ba306
```

### List All Signature Artifacts in ECR

**Java signatures:**
```bash
aws ecr describe-images \
  --repository-name root-reg/java \
  --region us-east-1 \
  --query 'imageDetails[?imageSizeInBytes < `10000`].[imageDigest, imageSizeInBytes, imageManifestMediaType]' \
  --output table
```

**Golang signatures:**
```bash
aws ecr describe-images \
  --repository-name root-reg/golang \
  --region us-east-1 \
  --query 'imageDetails[?imageSizeInBytes < `10000`].[imageDigest, imageSizeInBytes, imageManifestMediaType]' \
  --output table
```

## Troubleshooting

### Error: no signatures found

This error means:
- The image is not signed, or
- You're trying to verify through a proxy that doesn't support OCI referrers
- Solution: Verify against the ECR URL directly

### Error: --certificate-identity or --certificate-identity-regexp is required

Cosign requires identity verification flags for keyless signatures.
- Use `--certificate-identity-regexp '.*'` and `--certificate-oidc-issuer-regexp '.*'` for basic verification
- For production, use specific identity patterns to ensure only authorized signers

### Error: response did not include Docker-Content-Digest header

This indicates:
- The registry doesn't support required OCI headers
- Cannot be used for signing operations
- Solution: Sign against ECR directly, not the proxy

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

## Security Considerations

1. **Digest Verification:** Always verify using digests in production for immutability
2. **Certificate Identity:** In production, use specific certificate identity patterns instead of `.*`
3. **Transparency Log:** Signatures are publicly logged in Rekor for audit purposes
4. **Registry Access:** Ensure proper AWS IAM permissions for ECR access
5. **Proxy Limitations:** Be aware that read-only proxies cannot store signatures

## Additional Resources

- [Cosign Documentation](https://docs.sigstore.dev/cosign/overview/)
- [Sigstore Project](https://www.sigstore.dev/)
- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [OCI Referrers Specification](https://github.com/opencontainers/distribution-spec/blob/main/spec.md#listing-referrers)
