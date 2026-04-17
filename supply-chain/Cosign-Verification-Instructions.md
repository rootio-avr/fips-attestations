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
| golang | 1.25-jammy-ubuntu-22.04-fips | sha256:d48386da5fcaea2cfc40a659ab16d37bd27619a031210e2e394b8685b02b5fad | root-reg/golang |
| java | 8-jdk-jammy-ubuntu-22.04-fips | sha256:f29735f2ed8029032a67155e46399765e4281b214b12c8761033df0fbae82f19 | root-reg/java |
| java | 11-jdk-jammy-ubuntu-22.04-fips | sha256:76dc68a85aeee6ccd070a2f5fbc9aaf1df7423643c46ea2b4559bf9fa1bcc569 | root-reg/java |
| java | 17-jdk-jammy-ubuntu-22.04-fips | sha256:27480e4d6689457e21a968f3647b1689641df098d162ec836e4fb0f5d3accae0 | root-reg/java |
| java | 21-jdk-jammy-ubuntu-22.04-fips | sha256:5b20e08d1e9421556f8225d92f75da2b8d9dca72dbdfe748558b72091d2cb231 | root-reg/java |
| java | 19-jdk-bookworm-slim-fips | sha256:73047fef8b4f7345504ef0478682edbce7f69150dbfd88eafcc22ffb264a29e9 | root-reg/java |
| python | 3.12-bookworm-slim-fips | sha256:bf8e621d764abb9bf11f917c04997c385fa66f098621a8ce71846a6bbbb3e859 | root-reg/python |
| node | 16.20.1-bookworm-slim-fips ⚠️ EOL | sha256:49ea1c95fc97f4a71be5ca289659e3f4c7b8be2313624fbd1c332d62143f82aa | root-reg/node |
| node | 18.20.8-bookworm-slim-fips | sha256:211ae007634b11e825ce5788eabfb13552d973d6dc90daa49bac13586e82e9cd | root-reg/node |
| node | 24.14.0-trixie-slim-fips | sha256:9e33d3730c85a7fef44a3953c7dd455893814d2942dff675630b6d0179dba2cb | root-reg/node |
| nginx | 1.27.3-debian-bookworm-fips | sha256:951cb515992a28a21451336e1fd937df0679de310079aad75b416d0003a70035 | root-reg/nginx |
| nginx | 1.29.1-debian-bookworm-fips | sha256:27829c6a7a91c6af1b1a5b28d6dc6c3d0c3a2448625b97abaf419e584a29a1b9 | root-reg/nginx |
| redis | 7.2.4-alpine-3.19-fips | sha256:b6ba83202c1383843801de27da3255aef64a2a8f824fbe4e4c0c070b3f30f049 | root-reg/redis |
| redis-exporter | 1.67.0-jammy-ubuntu-22.04-fips | sha256:597724bbae809230508773e2be2e39ebb62d6ab332b6b5d9320785c420a67290 | root-reg/redis-exporter |

## Verification Methods

### Method 1: Verify Using Tag (Simple)

Verify the image using its tag. This is straightforward but note the warning that tags can change.

**Golang Image:**
```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/golang:1.25-jammy-ubuntu-22.04-fips
```

**Java Jammy Images (JDK 8 / 11 / 17 / 21):**
```bash
# Replace NN with 8, 11, 17, or 21
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/java:8-jdk-jammy-ubuntu-22.04-fips

cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/java:11-jdk-jammy-ubuntu-22.04-fips

cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/java:17-jdk-jammy-ubuntu-22.04-fips

cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/java:21-jdk-jammy-ubuntu-22.04-fips
```

**Java Bookworm Image (JDK 19):**
```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/java:19-jdk-bookworm-slim-fips
```

**Python Image:**
```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/python:3.12-bookworm-slim-fips
```

**Node.js 16 Image (⚠️ EOL — legacy compatibility only):**
```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/node:16.20.1-bookworm-slim-fips
```

**Node.js 18 Image:**
```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/node:18.20.8-bookworm-slim-fips
```

**Node.js 24 Image (Trixie):**
```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/node:24.14.0-trixie-slim-fips
```

**Nginx 1.27.3 Image:**
```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/nginx:1.27.3-debian-bookworm-fips
```

**Nginx 1.29.1 Image:**
```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/nginx:1.29.1-debian-bookworm-fips
```

**Redis Image:**
```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/redis:7.2.4-alpine-3.19-fips
```

**Redis Exporter Image:**
```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips
```

### Method 2: Verify Using Digest (Recommended)

Verify using the image digest for immutable verification.

**Golang Image:**
```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/golang@sha256:d48386da5fcaea2cfc40a659ab16d37bd27619a031210e2e394b8685b02b5fad
```

**Java 8 (Jammy):**
```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/java@sha256:f29735f2ed8029032a67155e46399765e4281b214b12c8761033df0fbae82f19
```

**Java 11 (Jammy):**
```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/java@sha256:76dc68a85aeee6ccd070a2f5fbc9aaf1df7423643c46ea2b4559bf9fa1bcc569
```

**Java 17 (Jammy):**
```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/java@sha256:27480e4d6689457e21a968f3647b1689641df098d162ec836e4fb0f5d3accae0
```

**Java 21 (Jammy):**
```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/java@sha256:5b20e08d1e9421556f8225d92f75da2b8d9dca72dbdfe748558b72091d2cb231
```

**Java 19 (Bookworm):**
```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/java@sha256:73047fef8b4f7345504ef0478682edbce7f69150dbfd88eafcc22ffb264a29e9
```

**Python 3.12 (Bookworm):**
```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/python@sha256:bf8e621d764abb9bf11f917c04997c385fa66f098621a8ce71846a6bbbb3e859
```

**Node.js 16.20.1 (Bookworm — ⚠️ EOL):**
```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/node@sha256:49ea1c95fc97f4a71be5ca289659e3f4c7b8be2313624fbd1c332d62143f82aa
```

**Node.js 18.20.8 (Bookworm):**
```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/node@sha256:211ae007634b11e825ce5788eabfb13552d973d6dc90daa49bac13586e82e9cd
```

**Node.js 24.14.0 (Trixie):**
```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/node@sha256:9e33d3730c85a7fef44a3953c7dd455893814d2942dff675630b6d0179dba2cb
```

**Nginx 1.27.3 (Bookworm):**
```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/nginx@sha256:951cb515992a28a21451336e1fd937df0679de310079aad75b416d0003a70035
```

**Nginx 1.29.1 (Bookworm):**
```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/nginx@sha256:27829c6a7a91c6af1b1a5b28d6dc6c3d0c3a2448625b97abaf419e584a29a1b9
```

**Redis 7.2.4 (Alpine 3.19):**
```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/redis@sha256:b6ba83202c1383843801de27da3255aef64a2a8f824fbe4e4c0c070b3f30f049
```

**Redis Exporter 1.67.0 (Jammy):**
```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/redis-exporter@sha256:597724bbae809230508773e2be2e39ebb62d6ab332b6b5d9320785c420a67290
```

### Expected Output

Successful verification will output JSON with signature details:

```json
[{
  "critical": {
    "identity": {
      "docker-reference": "<redacted_root_ecr_base>/root-reg/java:21-jdk-jammy-ubuntu-22.04-fips"
    },
    "image": {
      "docker-manifest-digest": "sha256:5b20e08d1e9421556f8225d92f75da2b8d9dca72dbdfe748558b72091d2cb231"
    },
    "type": "https://sigstore.dev/cosign/sign/v1"
  },
  "optional": {}
}]
```

## Verifying Proxy Images (cr.root.io)

The cr.root.io proxy is read-only and doesn't store signature artifacts. To verify images pulled from the proxy, always verify against the ECR URL directly using the image digest.

The same pattern applies to all images. Example with each variant:

**Java 21 (Jammy):**
```bash
docker pull cr.root.io/java:21-jdk-jammy-ubuntu-22.04-fips
docker inspect cr.root.io/java:21-jdk-jammy-ubuntu-22.04-fips --format '{{index .RepoDigests 0}}'
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/java@sha256:5b20e08d1e9421556f8225d92f75da2b8d9dca72dbdfe748558b72091d2cb231
```

**Java 19 (Bookworm):**
```bash
docker pull cr.root.io/java:19-jdk-bookworm-slim-fips
docker inspect cr.root.io/java:19-jdk-bookworm-slim-fips --format '{{index .RepoDigests 0}}'
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/java@sha256:73047fef8b4f7345504ef0478682edbce7f69150dbfd88eafcc22ffb264a29e9
```

**Python 3.12 (Bookworm):**
```bash
docker pull cr.root.io/python:3.12-bookworm-slim-fips
docker inspect cr.root.io/python:3.12-bookworm-slim-fips --format '{{index .RepoDigests 0}}'
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/python@sha256:bf8e621d764abb9bf11f917c04997c385fa66f098621a8ce71846a6bbbb3e859
```

**Golang:**
```bash
docker pull cr.root.io/golang:1.25-jammy-ubuntu-22.04-fips
docker inspect cr.root.io/golang:1.25-jammy-ubuntu-22.04-fips --format '{{index .RepoDigests 0}}'
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/golang@sha256:d48386da5fcaea2cfc40a659ab16d37bd27619a031210e2e394b8685b02b5fad
```

**Node.js 16.20.1 (Bookworm — ⚠️ EOL):**
```bash
docker pull cr.root.io/node:16.20.1-bookworm-slim-fips
docker inspect cr.root.io/node:16.20.1-bookworm-slim-fips --format '{{index .RepoDigests 0}}'
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/node@sha256:49ea1c95fc97f4a71be5ca289659e3f4c7b8be2313624fbd1c332d62143f82aa
```

**Node.js 18.20.8 (Bookworm):**
```bash
docker pull cr.root.io/node:18.20.8-bookworm-slim-fips
docker inspect cr.root.io/node:18.20.8-bookworm-slim-fips --format '{{index .RepoDigests 0}}'
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/node@sha256:211ae007634b11e825ce5788eabfb13552d973d6dc90daa49bac13586e82e9cd
```

**Node.js 24.14.0 (Trixie):**
```bash
docker pull cr.root.io/node:24.14.0-trixie-slim-fips
docker inspect cr.root.io/node:24.14.0-trixie-slim-fips --format '{{index .RepoDigests 0}}'
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/node@sha256:9e33d3730c85a7fef44a3953c7dd455893814d2942dff675630b6d0179dba2cb
```

**Nginx 1.27.3 (Bookworm):**
```bash
docker pull cr.root.io/nginx:1.27.3-debian-bookworm-fips
docker inspect cr.root.io/nginx:1.27.3-debian-bookworm-fips --format '{{index .RepoDigests 0}}'
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/nginx@sha256:951cb515992a28a21451336e1fd937df0679de310079aad75b416d0003a70035
```

**Nginx 1.29.1 (Bookworm):**
```bash
docker pull cr.root.io/nginx:1.29.1-debian-bookworm-fips
docker inspect cr.root.io/nginx:1.29.1-debian-bookworm-fips --format '{{index .RepoDigests 0}}'
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/nginx@sha256:27829c6a7a91c6af1b1a5b28d6dc6c3d0c3a2448625b97abaf419e584a29a1b9
```

**Redis 7.2.4 (Alpine 3.19):**
```bash
docker pull cr.root.io/redis:7.2.4-alpine-3.19-fips
docker inspect cr.root.io/redis:7.2.4-alpine-3.19-fips --format '{{index .RepoDigests 0}}'
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/redis@sha256:b6ba83202c1383843801de27da3255aef64a2a8f824fbe4e4c0c070b3f30f049
```

**Redis Exporter 1.67.0 (Jammy):**
```bash
docker pull cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips
docker inspect cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips --format '{{index .RepoDigests 0}}'
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/redis-exporter@sha256:597724bbae809230508773e2be2e39ebb62d6ab332b6b5d9320785c420a67290
```

## Advanced Commands

### View Signature Artifacts

Show the supply chain security artifacts attached to an image:

**Java 8 (Jammy):**
```bash
cosign tree <redacted_root_ecr_base>/root-reg/java:8-jdk-jammy-ubuntu-22.04-fips
```

**Java 11 (Jammy):**
```bash
cosign tree <redacted_root_ecr_base>/root-reg/java:11-jdk-jammy-ubuntu-22.04-fips
```

**Java 17 (Jammy):**
```bash
cosign tree <redacted_root_ecr_base>/root-reg/java:17-jdk-jammy-ubuntu-22.04-fips
```

**Java 21 (Jammy):**
```bash
cosign tree <redacted_root_ecr_base>/root-reg/java:21-jdk-jammy-ubuntu-22.04-fips
```

**Java 19 (Bookworm):**
```bash
cosign tree <redacted_root_ecr_base>/root-reg/java:19-jdk-bookworm-slim-fips
```

**Python 3.12 (Bookworm):**
```bash
cosign tree <redacted_root_ecr_base>/root-reg/python:3.12-bookworm-slim-fips
```

**Golang:**
```bash
cosign tree <redacted_root_ecr_base>/root-reg/golang:1.25-jammy-ubuntu-22.04-fips
```

**Node.js 16.20.1 (Bookworm — ⚠️ EOL):**
```bash
cosign tree <redacted_root_ecr_base>/root-reg/node:16.20.1-bookworm-slim-fips
```

**Node.js 18.20.8 (Bookworm):**
```bash
cosign tree <redacted_root_ecr_base>/root-reg/node:18.20.8-bookworm-slim-fips
```

**Node.js 24.14.0 (Trixie):**
```bash
cosign tree <redacted_root_ecr_base>/root-reg/node:24.14.0-trixie-slim-fips
```

**Nginx 1.27.3 (Bookworm):**
```bash
cosign tree <redacted_root_ecr_base>/root-reg/nginx:1.27.3-debian-bookworm-fips
```

**Nginx 1.29.1 (Bookworm):**
```bash
cosign tree <redacted_root_ecr_base>/root-reg/nginx:1.29.1-debian-bookworm-fips
```

**Redis 7.2.4 (Alpine 3.19):**
```bash
cosign tree <redacted_root_ecr_base>/root-reg/redis:7.2.4-alpine-3.19-fips
```

**Redis Exporter 1.67.0 (Jammy):**
```bash
cosign tree <redacted_root_ecr_base>/root-reg/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips
```

Example output:
```
📦 Supply Chain Security Related artifacts for an image: <redacted_root_ecr_base>/root-reg/java:21-jdk-jammy-ubuntu-22.04-fips
└── 🔗 https://sigstore.dev/cosign/sign/v1 artifacts via OCI referrer: <redacted_root_ecr_base>/root-reg/java@sha256:<referrer-digest>
   └── 🍒 sha256:<signature-digest>
```

### List All Signature Artifacts in ECR

**Java signatures (all variants share the root-reg/java repository):**
```bash
aws ecr describe-images \
  --repository-name root-reg/java \
  --region us-east-1 \
  --query 'imageDetails[?imageSizeInBytes < `10000`].[imageDigest, imageSizeInBytes, imageManifestMediaType]' \
  --output table
```

**Python signatures:**
```bash
aws ecr describe-images \
  --repository-name root-reg/python \
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

**Node.js signatures (both 16 and 18 share the root-reg/node repository):**
```bash
aws ecr describe-images \
  --repository-name root-reg/node \
  --region us-east-1 \
  --query 'imageDetails[?imageSizeInBytes < `10000`].[imageDigest, imageSizeInBytes, imageManifestMediaType]' \
  --output table
```

**Nginx signatures:**
```bash
aws ecr describe-images \
  --repository-name root-reg/nginx \
  --region us-east-1 \
  --query 'imageDetails[?imageSizeInBytes < `10000`].[imageDigest, imageSizeInBytes, imageManifestMediaType]' \
  --output table
```

**Redis signatures:**
```bash
aws ecr describe-images \
  --repository-name root-reg/redis \
  --region us-east-1 \
  --query 'imageDetails[?imageSizeInBytes < `10000`].[imageDigest, imageSizeInBytes, imageManifestMediaType]' \
  --output table
```

**Redis Exporter signatures:**
```bash
aws ecr describe-images \
  --repository-name root-reg/redis-exporter \
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
