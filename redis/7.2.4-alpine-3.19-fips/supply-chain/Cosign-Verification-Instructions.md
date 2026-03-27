# Cosign Verification Guide for Redis 7.2.4 FIPS Image

## Overview

This guide explains how to verify cosign signatures for the Redis 7.2.4 FIPS container image (`cr.root.io/redis:7.2.4-alpine-3.19-fips`) stored in AWS ECR. The image is signed using Sigstore's keyless signing method with ephemeral keys.

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

**Image:** `cr.root.io/redis:7.2.4-alpine-3.19-fips`
**Base:** Redis 7.2.4 on Alpine Linux 3.19
**ECR Repository:** `root-reg/redis`
**Signing Method:** Keyless signing via Sigstore
**Image Digest:** `sha256:b6ba83202c1383843801de27da3255aef64a2a8f824fbe4e4c0c070b3f30f049`

## Verification Methods

### Method 1: Verify Using Tag (Simple)

Verify the image using its tag. This is straightforward but note that tags can change.

```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/cr.root.io/redis:7.2.4-alpine-3.19-fips
```

### Method 2: Verify Using Digest (Recommended)

Verify using the image digest for immutable verification. You can use the known digest or get it from the image:

```bash
# Option A: Use the known digest
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/redis@sha256:b6ba83202c1383843801de27da3255aef64a2a8f824fbe4e4c0c070b3f30f049
```

```bash
# Option B: Get the digest from pulled image
docker pull <redacted_root_ecr_base>/root-reg/cr.root.io/redis:7.2.4-alpine-3.19-fips
docker inspect <redacted_root_ecr_base>/root-reg/cr.root.io/redis:7.2.4-alpine-3.19-fips --format '{{index .RepoDigests 0}}'

# Then verify using the digest
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/redis@sha256:<digest-from-above>
```

### Expected Output

Successful verification will output JSON with signature details:

```json
[{
  "critical": {
    "identity": {
      "docker-reference": "<redacted_root_ecr_base>/root-reg/cr.root.io/redis:7.2.4-alpine-3.19-fips"
    },
    "image": {
      "docker-manifest-digest": "sha256:b6ba83202c1383843801de27da3255aef64a2a8f824fbe4e4c0c070b3f30f049"
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
   docker pull cr.root.io/redis:7.2.4-alpine-3.19-fips
   ```

2. **Get the digest** from the pulled image:
   ```bash
   docker inspect cr.root.io/redis:7.2.4-alpine-3.19-fips --format '{{index .RepoDigests 0}}'
   ```

3. **Verify against ECR** using the digest:
   ```bash
   cosign verify \
     --certificate-identity-regexp '.*' \
     --certificate-oidc-issuer-regexp '.*' \
     <redacted_root_ecr_base>/root-reg/redis@sha256:<digest-from-step-2>
   ```

## Advanced Commands

### View Signature Artifacts

Show the supply chain security artifacts attached to the image:

```bash
cosign tree <redacted_root_ecr_base>/root-reg/cr.root.io/redis:7.2.4-alpine-3.19-fips
```

Example output:
```
📦 Supply Chain Security Related artifacts for an image: <redacted_root_ecr_base>/root-reg/cr.root.io/redis:7.2.4-alpine-3.19-fips
└── 🔗 https://sigstore.dev/cosign/sign/v1 artifacts via OCI referrer: <redacted_root_ecr_base>/root-reg/redis@sha256:b6ba83202c1383843801de27da3255aef64a2a8f824fbe4e4c0c070b3f30f049
   └── 🍒 sha256:<signature-digest>
```

### List All Signature Artifacts in ECR

View all signature artifacts for Redis images in the ECR repository:

```bash
aws ecr describe-images \
  --repository-name root-reg/redis \
  --region us-east-1 \
  --query 'imageDetails[?imageSizeInBytes < `10000`].[imageDigest, imageSizeInBytes, imageManifestMediaType]' \
  --output table
```

### Download and Inspect the Signature Bundle

```bash
# Download the signature bundle
cosign download signature <redacted_root_ecr_base>/root-reg/cr.root.io/redis:7.2.4-alpine-3.19-fips

# View certificate details
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/cr.root.io/redis:7.2.4-alpine-3.19-fips | jq
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

For Redis FIPS images, additional verification steps ensure FIPS compliance:

### Verify FIPS Components After Pull

After verifying the image signature, verify FIPS components are intact:

```bash
# Pull the verified image
docker pull <redacted_root_ecr_base>/root-reg/cr.root.io/redis:7.2.4-alpine-3.19-fips

# Run FIPS validation check
docker run -d --name redis-fips-test <redacted_root_ecr_base>/root-reg/cr.root.io/redis:7.2.4-alpine-3.19-fips
sleep 5

# Check FIPS validation logs
docker logs redis-fips-test

# Expected output includes:
# ✓ FIPS POST completed successfully
# ✓ wolfProvider loaded
# ✓ OpenSSL FIPS mode: ENABLED
# ✓ Redis SHA-256 hashing enabled
# ✓ ALL FIPS CHECKS PASSED (5/5)
```

### Verify wolfSSL FIPS POST

Verify the FIPS Power-On Self Test (POST) execution:

```bash
# Run FIPS POST check
docker exec redis-fips-test fips-startup-check

# Expected output:
# wolfCrypt FIPS error state: 0 (OK)
# wolfSSL FIPS POST: PASS
# All Known Answer Tests (KAT): PASS
```

### Verify wolfProvider Loading

Check that wolfSSL provider is loaded in OpenSSL:

```bash
docker exec redis-fips-test openssl list -providers

# Expected output includes:
# wolfSSL Provider
#   name: wolfSSL Provider
#   version: 1.1.0
#   status: active
```

### Verify Redis Connectivity

Test Redis server functionality:

```bash
# Test basic connectivity
docker exec redis-fips-test redis-cli PING
# Expected: PONG

# Test set/get operations
docker exec redis-fips-test redis-cli SET test-key "FIPS mode active"
docker exec redis-fips-test redis-cli GET test-key
# Expected: FIPS mode active

# Check Redis info
docker exec redis-fips-test redis-cli INFO server | grep redis_version
# Expected: redis_version:7.2.4
```

### Verify MD5 Blocking (FIPS Enforcement Proof)

Verify that MD5 is blocked at the OpenSSL level (proves FIPS enforcement is real):

```bash
docker exec redis-fips-test bash -c "echo -n 'test' | openssl dgst -md5"

# Expected output: Error setting digest
# or: md5 is not supported by this provider
# This confirms FIPS mode is enforced
```

### Verify SHA-256 Available (FIPS-Approved)

Confirm that FIPS-approved algorithms work:

```bash
# Test SHA-256 (FIPS-approved)
docker exec redis-fips-test bash -c "echo -n 'test' | openssl dgst -sha256"

# Expected output: SHA2-256(stdin)= 9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08

# Test SHA-384 (FIPS-approved)
docker exec redis-fips-test bash -c "echo -n 'test' | openssl dgst -sha384"

# Expected output: SHA2-384(stdin)= 768412320f7b0aa5812fce428dc4706b3cae50e02a64caa16a782249bfe8efc4b7ef1ccb126255d196047dfedf17a0a9
```

### Run Full Diagnostic Tests

For comprehensive FIPS validation:

```bash
# Clone the repository with diagnostic tests
git clone <repository-url>
cd redis/7.2.4-alpine-3.19-fips

# Run comprehensive diagnostic script
./diagnostic.sh redis-fips-test

# Expected output:
# ======================================
# Redis FIPS Comprehensive Diagnostics
# ======================================
#
# [TEST 1/8] FIPS Validation Status
# ✓ FIPS validation passed
#
# [TEST 2/8] wolfSSL FIPS POST
# ✓ FIPS POST successful
#
# [TEST 3/8] OpenSSL Provider Status
# ✓ wolfProvider loaded
#
# [TEST 4/8] Redis Connectivity
# ✓ Redis responding
#
# [TEST 5/8] SHA-256 Algorithm Test
# ✓ SHA-256 working (FIPS-approved)
#
# [TEST 6/8] MD5 Block Test
# ✓ MD5 blocked (FIPS enforcement active)
#
# [TEST 7/8] TLS Support
# ✓ TLS support available
#
# [TEST 8/8] Container Health
# ✓ Container healthy
#
# ======================================
# All Tests Passed: 8/8 (100%)
# ======================================
```

### Verify FIPS Environment Variables

Check that FIPS environment variables are properly set:

```bash
docker exec redis-fips-test env | grep -E '(OPENSSL|FIPS|LD_LIBRARY)'

# Expected output:
# OPENSSL_CONF=/usr/local/openssl/ssl/openssl.cnf
# OPENSSL_MODULES=/usr/local/openssl/lib/ossl-modules
# LD_LIBRARY_PATH=/usr/local/openssl/lib:/usr/local/lib
```

### Verify Redis Lua Scripting with SHA-256

Confirm that Redis uses SHA-256 for Lua script hashing (FIPS-compliant):

```bash
# Redis uses SHA-256 for SCRIPT LOAD
docker exec redis-fips-test redis-cli SCRIPT LOAD "return 'FIPS test'"

# Expected: Returns a SHA-256 hash (64 hex characters)
# Example: a42059b356c875f0717db318ec74c44cfc0e821241f1bf892e26e1c9c94a2192
```

## Cleanup

After verification tests are complete:

```bash
# Stop and remove test container
docker stop redis-fips-test
docker rm redis-fips-test
```

## Additional Resources

- [Cosign Documentation](https://docs.sigstore.dev/cosign/overview/)
- [Sigstore Project](https://www.sigstore.dev/)
- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [OCI Referrers Specification](https://github.com/opencontainers/distribution-spec/blob/main/spec.md#listing-referrers)
- [Rekor Transparency Log](https://rekor.sigstore.dev/)
- [Redis FIPS Documentation](../README.md)
- [FIPS 140-3 Certificate #4718](https://csrc.nist.gov/projects/cryptographic-module-validation-program/certificate/4718)
- [wolfSSL FIPS Documentation](https://www.wolfssl.com/products/fips/)
- [Redis Security Documentation](https://redis.io/docs/management/security/)

## Contact

For questions about Cosign verification or FIPS compliance:
- Build Team
- Security Team
- Compliance Team

---

**Document Version:** 1.0
**Last Updated:** 2026-03-27
**Image Digest:** sha256:b6ba83202c1383843801de27da3255aef64a2a8f824fbe4e4c0c070b3f30f049
