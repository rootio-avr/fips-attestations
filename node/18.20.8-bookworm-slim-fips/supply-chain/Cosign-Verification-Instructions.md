# Cosign Verification Guide for Node.js 18 FIPS Image

## Overview

This guide explains how to verify cosign signatures for the Node.js 18 FIPS container image (`cr.root.io/node:18.20.8-bookworm-slim-fips`) stored in AWS ECR. The image is signed using Sigstore's keyless signing method with ephemeral keys.

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

**Image:** `cr.root.io/node:18.20.8-bookworm-slim-fips`
**Base:** Node.js 18.20.8 on Debian Bookworm (Slim)
**ECR Repository:** `root-reg/node`
**Signing Method:** Keyless signing via Sigstore

## Verification Methods

### Method 1: Verify Using Tag (Simple)

Verify the image using its tag. This is straightforward but note that tags can change.

```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/cr.root.io/node:18.20.8-bookworm-slim-fips
```

### Method 2: Verify Using Digest (Recommended)

Verify using the image digest for immutable verification. First, get the digest from the image:

```bash
# Get the digest
docker pull <redacted_root_ecr_base>/root-reg/cr.root.io/node:18.20.8-bookworm-slim-fips
docker inspect <redacted_root_ecr_base>/root-reg/cr.root.io/node:18.20.8-bookworm-slim-fips --format '{{index .RepoDigests 0}}'
```

Then verify using the digest:

```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/node@sha256:<digest-from-above>
```

### Expected Output

Successful verification will output JSON with signature details:

```json
[{
  "critical": {
    "identity": {
      "docker-reference": "<redacted_root_ecr_base>/root-reg/cr.root.io/node:18.20.8-bookworm-slim-fips"
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
   docker pull cr.root.io/cr.root.io/node:18.20.8-bookworm-slim-fips
   ```

2. **Get the digest** from the pulled image:
   ```bash
   docker inspect cr.root.io/cr.root.io/node:18.20.8-bookworm-slim-fips --format '{{index .RepoDigests 0}}'
   ```

3. **Verify against ECR** using the digest:
   ```bash
   cosign verify \
     --certificate-identity-regexp '.*' \
     --certificate-oidc-issuer-regexp '.*' \
     <redacted_root_ecr_base>/root-reg/node@sha256:<digest-from-step-2>
   ```

## Advanced Commands

### View Signature Artifacts

Show the supply chain security artifacts attached to the image:

```bash
cosign tree <redacted_root_ecr_base>/root-reg/cr.root.io/node:18.20.8-bookworm-slim-fips
```

Example output:
```
📦 Supply Chain Security Related artifacts for an image: <redacted_root_ecr_base>/root-reg/cr.root.io/node:18.20.8-bookworm-slim-fips
└── 🔗 https://sigstore.dev/cosign/sign/v1 artifacts via OCI referrer: <redacted_root_ecr_base>/root-reg/node@sha256:<digest>
   └── 🍒 sha256:<signature-digest>
```

### List All Signature Artifacts in ECR

View all signature artifacts for Node.js images in the ECR repository:

```bash
aws ecr describe-images \
  --repository-name root-reg/node \
  --region us-east-1 \
  --query 'imageDetails[?imageSizeInBytes < `10000`].[imageDigest, imageSizeInBytes, imageManifestMediaType]' \
  --output table
```

### Download and Inspect the Signature Bundle

```bash
# Download the signature bundle
cosign download signature <redacted_root_ecr_base>/root-reg/cr.root.io/node:18.20.8-bookworm-slim-fips

# View certificate details
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/cr.root.io/node:18.20.8-bookworm-slim-fips | jq
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

For Node.js FIPS images, additional verification steps ensure FIPS compliance:

### Verify FIPS Components After Pull

After verifying the image signature, verify FIPS components are intact:

```bash
# Pull the verified image
docker pull <redacted_root_ecr_base>/root-reg/cr.root.io/node:18.20.8-bookworm-slim-fips

# Run FIPS KAT test
docker run --rm <redacted_root_ecr_base>/root-reg/cr.root.io/node:18.20.8-bookworm-slim-fips /test-fips

# Expected output:
# ✓ in-core integrity hash is correct, copy is identical
# ✓ FIPS Mode is ON, status = 1
# wolfCrypt FIPS KAT passed successfully!
```

### Verify OpenSSL and Provider Configuration

```bash
# Verify OpenSSL version and FIPS provider
docker run --rm <redacted_root_ecr_base>/root-reg/cr.root.io/node:18.20.8-bookworm-slim-fips bash -c "
openssl version && \
openssl list -providers
"

# Expected output:
# OpenSSL 3.0.11 19 Sep 2023 (Library: OpenSSL 3.0.11 19 Sep 2023)
# Providers:
#   wolfssl
#     name: wolfSSL Provider
#     version: 1.0.2
#     status: active
```

### Run FIPS Initialization Check

```bash
# Run FIPS initialization check script
docker run --rm <redacted_root_ecr_base>/root-reg/cr.root.io/node:18.20.8-bookworm-slim-fips \
  node /opt/wolfssl-fips/bin/fips_init_check.js

# Expected output:
# ✅ wolfProvider loaded successfully
# ✅ Node.js using OpenSSL 3.0.11
# ✅ wolfSSL FIPS module detected
# All FIPS initialization checks passed (10/10)
```

### Run Full Diagnostic Tests

For comprehensive FIPS validation:

```bash
# Clone the repository with diagnostic tests
git clone <repository-url>
cd node/18.20.8-bookworm-slim-fips

# Run all FIPS diagnostic tests
./diagnostic.sh

# Expected output:
# ✅ Backend Verification: 6/6 tests passing
# ✅ Connectivity: 8/8 tests passing
# ✅ FIPS Verification: 6/6 tests passing
# ✅ Crypto Operations: 10/10 tests passing
# ✅ Library Compatibility: 4/6 tests passing
# Overall: 34/38 tests passing (89% pass rate)
```

### Verify TLS Cipher Suite Enforcement

Verify that weak cipher suites (MD5, SHA-1, DES, 3DES, RC4) are blocked in TLS:

```bash
docker run --rm <redacted_root_ecr_base>/root-reg/cr.root.io/node:18.20.8-bookworm-slim-fips node -e "
const tls = require('tls');
const crypto = require('crypto');

// Test FIPS mode enforcement
console.log('Available TLS cipher suites:', tls.getCiphers().length);
console.log('Weak ciphers (MD5/SHA1/DES/3DES/RC4):',
  tls.getCiphers().filter(c =>
    c.includes('md5') || c.includes('sha1') ||
    c.includes('des') || c.includes('rc4')
  ).length
);
"

# Expected output:
# Available TLS cipher suites: 23
# Weak ciphers (MD5/SHA1/DES/3DES/RC4): 0
```

### Run Test Image (Quick Validation)

For quick validation without mounting diagnostics:

```bash
# Clone the repository
git clone <repository-url>
cd node/18.20.8-bookworm-slim-fips/diagnostics/test-images/basic-test-image

# Build and run the test image
./build.sh
docker run --rm node-fips-test:latest

# Expected output:
# ✅ FIPS Core Validation: 10/10 tests passed
# ✅ Cryptographic Operations: 9/9 tests passed
# ✅ TLS/SSL Operations: 6/6 tests passed
# Overall: 15/15 tests passed (100%)
```

### Verify Hash Algorithms (MD5/SHA-1 Policy)

Verify that MD5 and SHA-1 are available at hash API level (correct FIPS 140-3 behavior per Certificate #4718) but blocked in TLS:

```bash
# Test hash algorithm availability
docker run --rm <redacted_root_ecr_base>/root-reg/cr.root.io/node:18.20.8-bookworm-slim-fips node -e "
const crypto = require('crypto');

// MD5 and SHA-1 should work at hash API level (per FIPS 140-3 #4718)
try {
  const md5 = crypto.createHash('md5').update('test').digest('hex');
  console.log('✅ MD5 hash available at API level (correct per FIPS 140-3 #4718)');
} catch (e) {
  console.log('❌ MD5 blocked:', e.message);
}

try {
  const sha1 = crypto.createHash('sha1').update('test').digest('hex');
  console.log('✅ SHA-1 hash available at API level (correct per FIPS 140-3 #4718)');
} catch (e) {
  console.log('❌ SHA-1 blocked:', e.message);
}

// But MD5/SHA-1 should be blocked in TLS (cipher suite enforcement)
const tls = require('tls');
const weakCiphers = tls.getCiphers().filter(c => c.includes('md5') || c.includes('sha1'));
console.log('✅ MD5/SHA-1 blocked in TLS: ' + (weakCiphers.length === 0 ? 'YES' : 'NO'));
"

# Expected output:
# ✅ MD5 hash available at API level (correct per FIPS 140-3 #4718)
# ✅ SHA-1 hash available at API level (correct per FIPS 140-3 #4718)
# ✅ MD5/SHA-1 blocked in TLS: YES
```

### Run Demo Applications

Verify FIPS functionality with interactive demos:

```bash
# Clone the repository
git clone <repository-url>
cd node/18.20.8-bookworm-slim-fips/demos-image

# Build and run the demo container
./build.sh
docker run --rm -it node-fips-demos:18.20.8

# Expected: Interactive menu with 4 demo applications
# 1. Hash Algorithm Demonstrations
# 2. TLS/SSL Client Demonstrations
# 3. Certificate Validation Demonstrations
# 4. HTTPS Request Demonstrations
```

## Additional Resources

- [Cosign Documentation](https://docs.sigstore.dev/cosign/overview/)
- [Sigstore Project](https://www.sigstore.dev/)
- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [OCI Referrers Specification](https://github.com/opencontainers/distribution-spec/blob/main/spec.md#listing-referrers)
- [Rekor Transparency Log](https://rekor.sigstore.dev/)
- [Node.js FIPS Documentation](../README.md)
- [FIPS 140-3 Certificate #4718](https://csrc.nist.gov/projects/cryptographic-module-validation-program/certificate/4718)
- [wolfSSL FIPS Documentation](https://www.wolfssl.com/fips/)
- [OpenSSL 3.0 Provider Documentation](https://www.openssl.org/docs/man3.0/man7/provider.html)
