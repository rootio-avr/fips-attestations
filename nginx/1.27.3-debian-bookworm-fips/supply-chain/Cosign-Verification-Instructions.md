# Cosign Verification Guide for Nginx 1.27.3 FIPS Image

## Overview

This guide explains how to verify cosign signatures for the Nginx 1.27.3 FIPS container image (`cr.root.io/nginx:1.27.3-debian-bookworm-fips`) stored in AWS ECR. The image is signed using Sigstore's keyless signing method with ephemeral keys.

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

**Image:** `cr.root.io/nginx:1.27.3-debian-bookworm-fips`
**Base:** Nginx 1.27.3 on Debian Bookworm Slim
**ECR Repository:** `root-reg/nginx`
**Signing Method:** Keyless signing via Sigstore

**FIPS Components:**
- wolfSSL FIPS: 5.8.2 (Certificate #4718)
- wolfProvider: 1.1.0
- OpenSSL: 3.0.19
- Supported Protocols: TLS 1.2, TLS 1.3

## Verification Methods

### Method 1: Verify Using Tag (Simple)

Verify the image using its tag. This is straightforward but note that tags can change.

```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/cr.root.io/nginx:1.27.3-debian-bookworm-fips
```

### Method 2: Verify Using Digest (Recommended)

Verify using the image digest for immutable verification. First, get the digest from the image:

```bash
# Get the digest
docker pull <redacted_root_ecr_base>/root-reg/cr.root.io/nginx:1.27.3-debian-bookworm-fips
docker inspect <redacted_root_ecr_base>/root-reg/cr.root.io/nginx:1.27.3-debian-bookworm-fips --format '{{index .RepoDigests 0}}'
```

Then verify using the digest:

```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/nginx@sha256:<digest-from-above>
```

### Expected Output

Successful verification will output JSON with signature details:

```json
[{
  "critical": {
    "identity": {
      "docker-reference": "<redacted_root_ecr_base>/root-reg/cr.root.io/nginx:1.27.3-debian-bookworm-fips"
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
   docker pull cr.root.io/nginx:1.27.3-debian-bookworm-fips
   ```

2. **Get the digest** from the pulled image:
   ```bash
   docker inspect cr.root.io/nginx:1.27.3-debian-bookworm-fips --format '{{index .RepoDigests 0}}'
   ```

3. **Verify against ECR** using the digest:
   ```bash
   cosign verify \
     --certificate-identity-regexp '.*' \
     --certificate-oidc-issuer-regexp '.*' \
     <redacted_root_ecr_base>/root-reg/nginx@sha256:<digest-from-step-2>
   ```

## Advanced Commands

### View Signature Artifacts

Show the supply chain security artifacts attached to the image:

```bash
cosign tree <redacted_root_ecr_base>/root-reg/cr.root.io/nginx:1.27.3-debian-bookworm-fips
```

Example output:
```
📦 Supply Chain Security Related artifacts for an image: <redacted_root_ecr_base>/root-reg/cr.root.io/nginx:1.27.3-debian-bookworm-fips
└── 🔗 https://sigstore.dev/cosign/sign/v1 artifacts via OCI referrer: <redacted_root_ecr_base>/root-reg/nginx@sha256:<digest>
   └── 🍒 sha256:<signature-digest>
```

### List All Signature Artifacts in ECR

View all signature artifacts for Nginx images in the ECR repository:

```bash
aws ecr describe-images \
  --repository-name root-reg/nginx \
  --region us-east-1 \
  --query 'imageDetails[?imageSizeInBytes < `10000`].[imageDigest, imageSizeInBytes, imageManifestMediaType]' \
  --output table
```

### Download and Inspect the Signature Bundle

```bash
# Download the signature bundle
cosign download signature <redacted_root_ecr_base>/root-reg/cr.root.io/nginx:1.27.3-debian-bookworm-fips

# View certificate details
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/cr.root.io/nginx:1.27.3-debian-bookworm-fips | jq
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

For Nginx FIPS images, additional verification steps ensure FIPS compliance:

### Verify FIPS Components After Pull

After verifying the image signature, verify FIPS components are intact:

```bash
# Pull the verified image
docker pull <redacted_root_ecr_base>/root-reg/cr.root.io/nginx:1.27.3-debian-bookworm-fips

# Run the container
docker run -d --name nginx-fips \
  -p 80:80 -p 443:443 \
  <redacted_root_ecr_base>/root-reg/cr.root.io/nginx:1.27.3-debian-bookworm-fips

# Expected startup output:
# ✓ FIPS POST completed successfully
# ✓ wolfProvider loaded and active
# ✓ OpenSSL version: OpenSSL 3.0.19
# ✓ FIPS enforcement enabled (fips=yes)
# ✓ Nginx configuration is valid
```

### Verify wolfSSL FIPS POST

Verify that wolfSSL FIPS Known Answer Tests (KAT) passed:

```bash
# Check container logs for FIPS POST
docker logs nginx-fips 2>&1 | grep -A 5 "FIPS POST"

# Expected output:
# ✓ FIPS POST completed successfully
#   All Known Answer Tests (KAT) passed
#   wolfSSL FIPS module is operational
#
# ================================================================================
# FIPS 140-3 Validation: PASS
# Certificate: #4718
# ================================================================================
```

### Verify OpenSSL Provider Configuration

Verify that wolfProvider is loaded and active:

```bash
# List OpenSSL providers
docker exec nginx-fips openssl list -providers

# Expected output:
# Providers:
#   fips
#     name: wolfSSL Provider FIPS
#     version: 1.1.0
#     status: active

# Verify OpenSSL version
docker exec nginx-fips openssl version

# Expected output:
# OpenSSL 3.0.19 27 Jan 2026 (Library: OpenSSL 3.0.19 27 Jan 2026)
```

### Test FIPS-Compliant TLS Connections

Verify TLS 1.2 and TLS 1.3 with FIPS-approved ciphers:

```bash
# Test TLS 1.3 with FIPS cipher
echo "Q" | openssl s_client -connect localhost:443 -tls1_3 2>&1 | grep -E "(Protocol|Cipher)"

# Expected output:
# New, TLSv1.3, Cipher is TLS_AES_256_GCM_SHA384

# Test TLS 1.2 with FIPS cipher
echo "Q" | openssl s_client -connect localhost:443 -tls1_2 -cipher 'ECDHE-RSA-AES256-GCM-SHA384' 2>&1 | grep -E "(Protocol|Cipher)"

# Expected output:
# Cipher    : ECDHE-RSA-AES256-GCM-SHA384
```

### Verify Legacy Protocol Blocking

Verify that TLS 1.0/1.1 are blocked (FIPS requirement):

```bash
# Test TLS 1.0 (should fail)
echo "Q" | timeout 3 openssl s_client -connect localhost:443 -tls1 2>&1 | grep "Cipher"

# Expected output:
# New, (NONE), Cipher is (NONE)
# (Connection fails - TLS 1.0 is blocked)

# Test TLS 1.1 (should fail)
echo "Q" | timeout 3 openssl s_client -connect localhost:443 -tls1_1 2>&1 | grep "Cipher"

# Expected output:
# New, (NONE), Cipher is (NONE)
# (Connection fails - TLS 1.1 is blocked)
```

### Verify MD5 Blocking (FIPS Enforcement Proof)

Verify that MD5 is blocked at the OpenSSL level (proves FIPS enforcement is real):

```bash
docker exec nginx-fips bash -c "echo -n 'test' | openssl dgst -md5"

# Expected output:
# Error setting digest
# (MD5 is blocked in FIPS mode)
```

### Run Comprehensive Diagnostic Tests

For complete FIPS validation, run the diagnostic test suite:

```bash
# Clone the repository with diagnostic tests (if not already available)
git clone <repository-url>
cd nginx/1.27.3-debian-bookworm-fips/diagnostics/test-images/basic-test-image

# Build and run the test image
./build.sh
docker run --rm nginx-fips-test:latest

# Expected output:
# ================================================================================
# FINAL TEST SUMMARY
# ================================================================================
# Total Test Suites: 3
# Passed: 3
# Failed: 0
#
# Test Suite Results:
#   ✓ TLS Protocol Tests: PASS (5/5)
#   ✓ FIPS Cipher Tests: PASS (5/5)
#   ✓ Certificate Validation Tests: PASS (4/4)
#
# ✓ ALL TESTS PASSED
# Nginx wolfSSL FIPS is production ready
# ================================================================================
```

### Test Health and FIPS Status Endpoints

```bash
# Test health endpoint
curl -k https://localhost:443/health

# Expected output:
# OK

# Check Nginx logs for request
docker exec nginx-fips tail -n 1 /var/log/nginx/access.log
```

## Additional Resources

- [Cosign Documentation](https://docs.sigstore.dev/cosign/overview/)
- [Sigstore Project](https://www.sigstore.dev/)
- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [OCI Referrers Specification](https://github.com/opencontainers/distribution-spec/blob/main/spec.md#listing-referrers)
- [Rekor Transparency Log](https://rekor.sigstore.dev/)
- [Nginx FIPS Documentation](../README.md)
- [Nginx FIPS Architecture](../ARCHITECTURE.md)
- [Nginx FIPS Developer Guide](../DEVELOPER-GUIDE.md)
- [FIPS 140-3 Certificate #4718](https://csrc.nist.gov/projects/cryptographic-module-validation-program/certificate/4718)
- [wolfSSL FIPS Documentation](https://www.wolfssl.com/documentation/manuals/wolfssl/chapter13.html)
