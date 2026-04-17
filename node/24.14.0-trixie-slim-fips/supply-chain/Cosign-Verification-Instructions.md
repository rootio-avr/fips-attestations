# Cosign Verification Guide for Node.js 24.14.0 FIPS Image

## Overview

This guide explains how to verify cosign signatures for the Node.js 24.14.0 FIPS container image (`cr.root.io/node:24.14.0-trixie-slim-fips`) stored in AWS ECR. The image is signed using Sigstore's keyless signing method with ephemeral keys.

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

**Image:** `cr.root.io/node:24.14.0-trixie-slim-fips`
**Base:** Node.js 24.14.1 on Debian Trixie (Slim)
**ECR Repository:** `root-reg/node`
**Signing Method:** Keyless signing via Sigstore
**Image Digest:** `sha256:9e33d3730c85a7fef44a3953c7dd455893814d2942dff675630b6d0179dba2cb`

## Verification Methods

### Method 1: Verify Using Tag (Simple)

Verify the image using its tag. This is straightforward but note that tags can change.

```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/cr.root.io/node:24.14.0-trixie-slim-fips
```

### Method 2: Verify Using Digest (Recommended)

Verify using the image digest for immutable verification. You can use the known digest or get it from the image:

```bash
# Option A: Use the known digest (after signing)
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/node@sha256:9e33d3730c85a7fef44a3953c7dd455893814d2942dff675630b6d0179dba2cb
```

```bash
# Option B: Get the digest from pulled image
docker pull <redacted_root_ecr_base>/root-reg/cr.root.io/node:24.14.0-trixie-slim-fips
docker inspect <redacted_root_ecr_base>/root-reg/cr.root.io/node:24.14.0-trixie-slim-fips --format '{{index .RepoDigests 0}}'

# Then verify using the digest
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
      "docker-reference": "<redacted_root_ecr_base>/root-reg/cr.root.io/node:24.14.0-trixie-slim-fips"
    },
    "image": {
      "docker-manifest-digest": "sha256:9e33d3730c85a7fef44a3953c7dd455893814d2942dff675630b6d0179dba2cb"
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
   docker pull cr.root.io/node:24.14.0-trixie-slim-fips
   ```

2. **Get the digest** from the pulled image:
   ```bash
   docker inspect cr.root.io/node:24.14.0-trixie-slim-fips --format '{{index .RepoDigests 0}}'
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
cosign tree <redacted_root_ecr_base>/root-reg/cr.root.io/node:24.14.0-trixie-slim-fips
```

Example output:
```
📦 Supply Chain Security Related artifacts for an image: <redacted_root_ecr_base>/root-reg/cr.root.io/node:24.14.0-trixie-slim-fips
└── 🔗 https://sigstore.dev/cosign/sign/v1 artifacts via OCI referrer: <redacted_root_ecr_base>/root-reg/node@sha256:9e33d3730c85a7fef44a3953c7dd455893814d2942dff675630b6d0179dba2cb
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
cosign download signature <redacted_root_ecr_base>/root-reg/cr.root.io/node:24.14.0-trixie-slim-fips

# View certificate details
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/cr.root.io/node:24.14.0-trixie-slim-fips | jq
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
docker pull <redacted_root_ecr_base>/root-reg/cr.root.io/node:24.14.0-trixie-slim-fips

# Run FIPS validation check
docker run -d --name node-fips-test <redacted_root_ecr_base>/root-reg/cr.root.io/node:24.14.0-trixie-slim-fips tail -f /dev/null
sleep 2

# Check FIPS validation logs
docker logs node-fips-test

# Expected output includes:
# ==> FIPS COMPONENTS INTEGRITY VERIFIED
# ==> FIPS INITIALIZATION TESTS PASSED (10/10)
# ==> wolfProvider active and loaded
# ==> OpenSSL FIPS mode: ENABLED
```

### Verify FIPS Mode Status

Verify that FIPS mode is enabled in Node.js:

```bash
# Check FIPS mode status (should return 1)
docker exec node-fips-test node -p "crypto.getFips()"
# Expected output: 1

# Alternative check using Node.js
docker exec node-fips-test node -e "const crypto = require('crypto'); console.log('FIPS mode:', crypto.getFips() === 1 ? 'ENABLED' : 'DISABLED')"
# Expected output: FIPS mode: ENABLED
```

### Verify wolfProvider Loading

Check that wolfSSL provider is loaded in OpenSSL:

```bash
docker exec node-fips-test openssl list -providers

# Expected output includes:
# Providers:
#   libwolfprov
#     name: wolfSSL Provider
#     version: 1.1.0
#     status: active
```

### Verify Node.js Crypto Operations

Test FIPS-approved cryptographic operations:

#### SHA-256 Hash (FIPS-Approved)

```bash
docker exec node-fips-test node -e "const crypto = require('crypto'); const hash = crypto.createHash('sha256').update('test').digest('hex'); console.log('SHA-256:', hash);"

# Expected output:
# SHA-256: 9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08
```

#### AES-256-GCM Encryption (FIPS-Approved)

```bash
docker exec node-fips-test node -e "
const crypto = require('crypto');
const key = crypto.randomBytes(32);
const iv = crypto.randomBytes(16);
const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
let encrypted = cipher.update('Hello, FIPS!', 'utf8', 'hex');
encrypted += cipher.final('hex');
console.log('AES-256-GCM encryption: SUCCESS');
"

# Expected output:
# AES-256-GCM encryption: SUCCESS
```

#### HMAC-SHA256 Operations (FIPS-Approved)

```bash
docker exec node-fips-test node -e "
const crypto = require('crypto');
const hmac = crypto.createHmac('sha256', 'secret-key').update('test').digest('hex');
console.log('HMAC-SHA256:', hmac);
"

# Expected output:
# HMAC-SHA256: <64-character hex string>
```

### Verify MD5 Blocking (FIPS Enforcement Proof)

Verify that MD5 is blocked at the crypto API level (proves FIPS enforcement is real):

```bash
docker exec node-fips-test node -e "crypto.createHash('md5')"

# Expected output: Error: error:0308010C:digital envelope routines::unsupported
# This confirms FIPS mode blocks non-approved algorithms
```

### Verify TLS Cipher Suites (Only FIPS-Approved)

Confirm that only FIPS-approved cipher suites are available:

```bash
# Check total cipher count (should be 30 FIPS-approved ciphers)
docker exec node-fips-test node -e "console.log('Total ciphers:', require('crypto').getCiphers().length)"
# Expected output: Total ciphers: 30

# Verify 0 MD5 cipher suites
docker exec node-fips-test node -e "console.log('MD5 ciphers:', require('crypto').getCiphers().filter(c => c.includes('md5')).length)"
# Expected output: MD5 ciphers: 0

# Verify 0 SHA-1 cipher suites in TLS
docker exec node-fips-test node -e "console.log('SHA-1 ciphers:', require('crypto').getCiphers().filter(c => c.includes('sha1')).length)"
# Expected output: SHA-1 ciphers: 0

# List available FIPS-approved ciphers
docker exec node-fips-test node -e "console.log(require('crypto').getCiphers().filter(c => c.includes('gcm')).join(', '))"
# Expected output: aes-128-gcm, aes-192-gcm, aes-256-gcm
```

### Verify TLS Connection with FIPS Ciphers

Test TLS connection to ensure only FIPS-approved cipher suites are negotiated:

```bash
docker exec node-fips-test node -e "
const tls = require('tls');
const socket = tls.connect({host: 'www.google.com', port: 443}, () => {
  console.log('Protocol:', socket.getProtocol());
  console.log('Cipher:', socket.getCipher().name);
  console.log('FIPS-compliant:', socket.getCipher().name.includes('GCM') || socket.getCipher().name.includes('AES'));
  socket.end();
});
"

# Expected output:
# Protocol: TLSv1.3
# Cipher: TLS_AES_256_GCM_SHA384
# FIPS-compliant: true
```

### Run Full Diagnostic Tests

For comprehensive FIPS validation, run the full diagnostic test suite:

```bash
# Navigate to the Node.js FIPS attestation directory
cd /path/to/node/24.14.0-trixie-slim-fips

# Run all diagnostic tests
./diagnostic.sh

# Expected output:
# ================================================================================
# Node.js wolfSSL FIPS - Diagnostic Test Suite
# ================================================================================
#
# Running Test 1/5: Backend Verification
# Tests Passed: 6/6
# ✓ ALL TESTS PASSED
#
# Running Test 2/5: Connectivity
# Tests Passed: 8/8
# ✓ ALL TESTS PASSED
#
# Running Test 3/5: FIPS Verification
# Tests Passed: 6/6
# ✓ FIPS VERIFICATION PASSED
#
# Running Test 4/5: Crypto Operations
# Tests Passed: 8/8
# ✓ ALL TESTS PASSED
#
# Running Test 5/5: Library Compatibility
# Tests Passed: 4/4
# ✓ CORE FUNCTIONALITY PASSED
#
# ================================================================================
# OVERALL DIAGNOSTIC RESULTS
# ================================================================================
# Total Test Suites: 5
# Overall Status: ✅ ALL CORE TESTS PASSED (32/32, 100%)
```

### Verify FIPS Environment Variables

Check that FIPS environment variables are properly set:

```bash
docker exec node-fips-test env | grep -E '(OPENSSL|FIPS)'

# Expected output:
# OPENSSL_CONF=/etc/ssl/openssl.cnf
# OPENSSL_MODULES=/usr/local/openssl/lib64/ossl-modules
```

### Verify wolfSSL FIPS Library

Confirm wolfSSL FIPS library is present and correct:

```bash
# Check wolfSSL library
docker exec node-fips-test ls -lh /usr/local/lib/libwolfssl.so*

# Expected output:
# lrwxrwxrwx ... /usr/local/lib/libwolfssl.so -> libwolfssl.so.42
# lrwxrwxrwx ... /usr/local/lib/libwolfssl.so.42 -> libwolfssl.so.42.2.0
# -rwxr-xr-x ... /usr/local/lib/libwolfssl.so.42.2.0 (779 KB)

# Check wolfProvider library
docker exec node-fips-test ls -lh /usr/local/openssl/lib64/ossl-modules/libwolfprov.so

# Expected output:
# -rwxr-xr-x ... /usr/local/openssl/lib64/ossl-modules/libwolfprov.so (1027 KB)
```

### Verify FIPS KAT Tests

Run FIPS Known Answer Tests:

```bash
docker exec node-fips-test /test-fips

# Expected output:
# wolfSSL FIPS v5.8.2 (Certificate #4718)
# Known Answer Tests (KAT):
#
#   SHA-256 KAT: PASS
#   SHA-384 KAT: PASS
#   SHA-512 KAT: PASS
#   AES-128-CBC KAT: PASS
#   AES-256-CBC KAT: PASS
#   AES-256-GCM KAT: PASS
#   HMAC-SHA256 KAT: PASS
#   HMAC-SHA384 KAT: PASS
#   RSA 2048 KAT: PASS
#   ECDSA P-256 KAT: PASS
#
# All FIPS KATs: PASSED
```

### Verify OpenSSL Configuration

Check OpenSSL configuration for FIPS settings:

```bash
docker exec node-fips-test cat /etc/ssl/openssl.cnf

# Expected output includes:
# [openssl_init]
# providers = provider_sect
# alg_section = algorithm_sect
#
# [provider_sect]
# libwolfprov = libwolfprov_sect
#
# [libwolfprov_sect]
# activate = 1
# module = /usr/local/openssl/lib64/ossl-modules/libwolfprov.so
#
# [algorithm_sect]
# default_properties = fips=yes
```

## Cleanup

After verification tests are complete:

```bash
# Stop and remove test container
docker stop node-fips-test
docker rm node-fips-test
```

## Additional Resources

- [Cosign Documentation](https://docs.sigstore.dev/cosign/overview/)
- [Sigstore Project](https://www.sigstore.dev/)
- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [OCI Referrers Specification](https://github.com/opencontainers/distribution-spec/blob/main/spec.md#listing-referrers)
- [Rekor Transparency Log](https://rekor.sigstore.dev/)
- [Node.js FIPS Documentation](../README.md)
- [FIPS Evidence Documentation](../Evidence/)
- [FIPS 140-3 Certificate #4718](https://csrc.nist.gov/projects/cryptographic-module-validation-program/certificate/4718)
- [wolfSSL FIPS Documentation](https://www.wolfssl.com/products/fips/)
- [Node.js Crypto Module Documentation](https://nodejs.org/api/crypto.html)
- [OpenSSL Provider Documentation](https://www.openssl.org/docs/man3.0/man7/provider.html)

## Contact

For questions about Cosign verification or FIPS compliance:
- **Security Team**: security@root.com
- **Build Team**: build@root.com
- **Compliance Team**: compliance@root.com

---

**Document Version:** 1.0
**Last Updated:** 2026-04-15
**Image:** cr.root.io/node:24.14.0-trixie-slim-fips
**Base:** Node.js 24.14.1 on Debian Trixie (Slim)
**FIPS Module:** wolfSSL FIPS v5.8.2 (Certificate #4718)
**Provider:** wolfProvider v1.1.1 for OpenSSL 3.5.0
