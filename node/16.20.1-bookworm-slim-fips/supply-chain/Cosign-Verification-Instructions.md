# Container Image Signing and Verification

**Image**: cr.root.io/node:16.20.1-bookworm-slim-fips
**Purpose**: Supply chain security via Cosign

---

## Overview

This document describes how to sign and verify the Node.js 16 FIPS container image using Cosign for supply chain security.

---

## Prerequisites

Install Cosign:
```bash
# macOS
brew install cosign

# Linux
wget https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64
sudo mv cosign-linux-amd64 /usr/local/bin/cosign
sudo chmod +x /usr/local/bin/cosign
```

---

## Signing the Image

### 1. Generate Signing Key

```bash
cosign generate-key-pair
# Creates: cosign.key and cosign.pub
```

### 2. Sign the Image

```bash
cosign sign --key cosign.key cr.root.io/node:16.20.1-bookworm-slim-fips
```

### 3. Add Attestations

```bash
# Create SBOM
syft cr.root.io/node:16.20.1-bookworm-slim-fips -o spdx-json > sbom.spdx.json

# Attach SBOM
cosign attest --key cosign.key --predicate sbom.spdx.json cr.root.io/node:16.20.1-bookworm-slim-fips
```

---

## Verifying the Image

### 1. Verify Signature

```bash
cosign verify --key cosign.pub cr.root.io/node:16.20.1-bookworm-slim-fips
```

### 2. Verify Attestation

```bash
cosign verify-attestation --key cosign.pub cr.root.io/node:16.20.1-bookworm-slim-fips
```

---

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: Sign and Verify FIPS Image

on:
  push:
    branches: [main]

jobs:
  sign-image:
    runs-on: ubuntu-latest
    steps:
      - name: Install Cosign
        uses: sigstore/cosign-installer@main
      
      - name: Build Image
        run: docker build -t cr.root.io/node:16.20.1-bookworm-slim-fips .
      
      - name: Sign Image
        run: cosign sign --key ${{ secrets.COSIGN_KEY }} cr.root.io/node:16.20.1-bookworm-slim-fips
      
      - name: Verify Image
        run: cosign verify --key cosign.pub cr.root.io/node:16.20.1-bookworm-slim-fips
```

---

## Verifying Proxy Images (cr.root.io)

The cr.root.io proxy is read-only and doesn't store signature artifacts. To verify images pulled from the proxy:

1. **Pull the image**:
   ```bash
   docker pull cr.root.io/node:16.20.1-bookworm-slim-fips
   ```

2. **Get the original digest**:
   ```bash
   docker inspect cr.root.io/node:16.20.1-bookworm-slim-fips --format '{{index .RepoDigests 0}}'
   ```

3. **Verify against the original registry** (where signatures are stored):
   ```bash
   cosign verify --key cosign.pub <original-registry>/<image>@<digest>
   ```

---

## Security Considerations

⚠️ **Node.js 16 EOL**: This image is EOL and should only be used for legacy compatibility
✅ **FIPS Validation**: wolfSSL Certificate #4718
✅ **Supply Chain**: Cosign signature verification
✅ **Integrity**: Runtime checksum verification

---

## References

- Cosign: https://github.com/sigstore/cosign
- Sigstore: https://www.sigstore.dev/
