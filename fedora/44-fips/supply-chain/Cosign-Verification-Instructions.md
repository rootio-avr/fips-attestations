# Cosign Verification Instructions
# Fedora 44 FIPS Minimal Base Image

**Image:** cr.root.io/fedora:44-fips
**Version:** 1.0
**Date:** April 16, 2026

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Cosign Installation](#cosign-installation)
4. [Public Key Distribution](#public-key-distribution)
5. [Image Signature Verification](#image-signature-verification)
6. [Attestation Verification](#attestation-verification)
7. [SBOM Verification](#sbom-verification)
8. [SLSA Provenance Verification](#slsa-provenance-verification)
9. [Policy Enforcement](#policy-enforcement)
10. [Keyless Verification (Sigstore)](#keyless-verification-sigstore)
11. [Automation and CI/CD Integration](#automation-and-cicd-integration)
12. [Troubleshooting](#troubleshooting)
13. [Best Practices](#best-practices)

---

## Overview

This document provides comprehensive instructions for verifying the cryptographic signatures and attestations of the Fedora 44 FIPS minimal base container image using Cosign.

**What is Cosign?**
Cosign is a tool for signing and verifying container images and other artifacts using Sigstore. It provides cryptographic verification of image provenance and integrity.

**Why Verify Images?**
- Ensure image authenticity (built by trusted source)
- Detect tampering or unauthorized modifications
- Verify build provenance and supply chain
- Meet compliance and security requirements for FIPS deployments
- Implement zero-trust security model

**What This Guide Covers:**
- Installing and configuring Cosign
- Verifying image signatures with public keys
- Verifying SLSA provenance attestations
- Verifying SBOM attestations (checking for Red Hat OpenSSL FIPS Provider)
- Implementing policy-based verification for FIPS compliance
- Integrating with CI/CD pipelines
- Troubleshooting common issues

---

## Prerequisites

### System Requirements

- **Operating System:** Linux, macOS, or Windows (WSL2)
- **Architecture:** x86_64 (amd64) or arm64
- **Tools Required:**
  - curl or wget (for downloading Cosign)
  - Docker or Podman (for pulling/running images)
  - jq (optional, for JSON processing)

### Network Requirements

- Internet access to:
  - GitHub (to download Cosign)
  - cr.root.io (container registry)
  - Sigstore infrastructure (for keyless verification)

### Knowledge Prerequisites

- Basic command line usage
- Understanding of container images
- Familiarity with public key cryptography concepts
- Basic understanding of FIPS 140-3 requirements

---

## Cosign Installation

### Method 1: Binary Installation (Recommended)

**Linux (amd64):**
```bash
# Download latest Cosign binary
COSIGN_VERSION=$(curl -s https://api.github.com/repos/sigstore/cosign/releases/latest | grep tag_name | cut -d '"' -f 4)
curl -LO "https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-linux-amd64"

# Verify checksum (optional but recommended)
curl -LO "https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-linux-amd64.sha256"
sha256sum -c cosign-linux-amd64.sha256

# Install
chmod +x cosign-linux-amd64
sudo mv cosign-linux-amd64 /usr/local/bin/cosign

# Verify installation
cosign version
```

**macOS (amd64):**
```bash
# Using Homebrew
brew install cosign

# Or manual installation
COSIGN_VERSION=$(curl -s https://api.github.com/repos/sigstore/cosign/releases/latest | grep tag_name | cut -d '"' -f 4)
curl -LO "https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-darwin-amd64"
chmod +x cosign-darwin-amd64
sudo mv cosign-darwin-amd64 /usr/local/bin/cosign
```

**macOS (arm64/M1/M2):**
```bash
brew install cosign

# Or manual:
COSIGN_VERSION=$(curl -s https://api.github.com/repos/sigstore/cosign/releases/latest | grep tag_name | cut -d '"' -f 4)
curl -LO "https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-darwin-arm64"
chmod +x cosign-darwin-arm64
sudo mv cosign-darwin-arm64 /usr/local/bin/cosign
```

**Windows (WSL2):**
```bash
# Follow Linux amd64 instructions within WSL2
```

### Method 2: Package Manager Installation

**Debian/Ubuntu:**
```bash
# Add Sigstore repository
echo "deb [signed-by=/usr/share/keyrings/sigstore-archive-keyring.gpg] https://sigstore.github.io/cosign/debian stable main" | sudo tee /etc/apt/sources.list.d/sigstore.list

# Import GPG key
curl -fsSL https://sigstore.github.io/cosign/key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/sigstore-archive-keyring.gpg

# Install
sudo apt-get update
sudo apt-get install -y cosign
```

**Fedora/RHEL:**
```bash
sudo dnf install cosign
```

### Method 3: Container-Based Installation

```bash
# Run Cosign in a container
docker run --rm gcr.io/projectsigstore/cosign:latest version

# Create alias for convenience
alias cosign='docker run --rm -v $(pwd):/workspace gcr.io/projectsigstore/cosign:latest'
```

### Verify Installation

```bash
cosign version
# Expected output:
# GitVersion:    v2.x.x
# GitCommit:     [commit hash]
# GitTreeState:  clean
# BuildDate:     [date]
# GoVersion:     go1.21.x
```

---

## Public Key Distribution

### Obtaining the Public Key

The Cosign public key is used to verify image signatures. It must be obtained through a secure, trusted channel.

**Option 1: Download from trusted source**
```bash
# Download public key (replace with actual URL)
curl -o cosign.pub https://cr.root.io/fedora/44-fips/cosign.pub

# Verify key fingerprint (compare with published fingerprint)
openssl pkey -pubin -in cosign.pub -text -noout | grep "Public-Key" -A 5
```

**Option 2: Receive via secure channel**
- Email from Root FIPS Team (GPG signed)
- Secure file transfer
- In-person transfer for high-security environments

**Option 3: Embedded in organization's key management**
- Store in secure key vault (HashiCorp Vault, AWS KMS, etc.)
- Distribute via configuration management (Ansible, Puppet, etc.)

### Public Key Format

Expected format (PKCS#8 PEM):
```
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE...
-----END PUBLIC KEY-----
```

### Security Considerations

**Key Verification:**
- Always verify public key fingerprint through independent channel
- Compare fingerprint with published value on official website
- Verify GPG signature if key is distributed via signed email

**Key Storage:**
- Store public key in secure, read-only location
- Version control public keys (Git repository)
- Implement key rotation policy (annual review recommended)

---

## Image Signature Verification

### Basic Signature Verification

**Verify using public key:**
```bash
# Basic verification
cosign verify --key cosign.pub cr.root.io/fedora:44-fips

# Expected output on success:
# Verification for cr.root.io/fedora:44-fips --
# The following checks were performed on each of these signatures:
#   - The cosign claims were validated
#   - The signatures were verified against the specified public key
#
# [{"critical":{"identity":{"docker-reference":"cr.root.io/fedora"},...}]
```

**Verify with specific key file location:**
```bash
cosign verify --key /path/to/cosign.pub cr.root.io/fedora:44-fips
```

**Verify and extract claims:**
```bash
# Save verification output to file
cosign verify --key cosign.pub cr.root.io/fedora:44-fips > verification.json

# Parse with jq
cat verification.json | jq '.[]'
```

### Verify Multiple Tags

```bash
# Verify multiple tags
for tag in 44-fips latest-fips fedora44-fips; do
    echo "Verifying cr.root.io/fedora:${tag}"
    cosign verify --key cosign.pub cr.root.io/fedora:${tag}
done
```

### Verify Before Pull

**Safe Pull Workflow:**
```bash
#!/bin/bash
set -e

IMAGE="cr.root.io/fedora:44-fips"
PUBLIC_KEY="cosign.pub"

echo "Step 1: Verifying image signature..."
cosign verify --key "${PUBLIC_KEY}" "${IMAGE}"

if [ $? -eq 0 ]; then
    echo "✓ Signature verification passed"
    echo "Step 2: Pulling image..."
    docker pull "${IMAGE}"
    echo "✓ Image pulled successfully"
else
    echo "✗ Signature verification failed"
    echo "ABORTING: Image will not be pulled"
    exit 1
fi
```

### Signature Inspection

```bash
# View signature metadata without verification
cosign triangulate cr.root.io/fedora:44-fips

# Download signature
cosign download signature cr.root.io/fedora:44-fips > signature.json

# Inspect signature contents
cat signature.json | jq '.'
```

---

## Attestation Verification

Attestations provide additional metadata about the image (SBOM, provenance, vulnerability scans, etc.).

### Verify All Attestations

```bash
# List all attestations
cosign verify-attestation --key cosign.pub \
    cr.root.io/fedora:44-fips
```

### Verify Specific Attestation Type

```bash
# Verify SLSA provenance
cosign verify-attestation --type slsaprovenance \
    --key cosign.pub \
    cr.root.io/fedora:44-fips

# Verify SBOM
cosign verify-attestation --type spdx \
    --key cosign.pub \
    cr.root.io/fedora:44-fips
```

### Extract Attestation Contents

```bash
# Extract and save SLSA provenance
cosign verify-attestation --type slsaprovenance \
    --key cosign.pub \
    cr.root.io/fedora:44-fips | \
    jq '.payload | @base64d | fromjson' > provenance.json

# Extract and save SBOM
cosign verify-attestation --type spdx \
    --key cosign.pub \
    cr.root.io/fedora:44-fips | \
    jq '.payload | @base64d | fromjson' > sbom.json
```

---

## SBOM Verification

### Verify and Inspect SBOM

```bash
# Verify SBOM attestation
cosign verify-attestation --type spdx \
    --key cosign.pub \
    cr.root.io/fedora:44-fips

# Extract SBOM
cosign verify-attestation --type spdx \
    --key cosign.pub \
    cr.root.io/fedora:44-fips | \
    jq -r '.payload | @base64d | fromjson' > sbom.json

# Inspect SBOM
cat sbom.json | jq '.predicate.Data'
```

### Validate SBOM Contents (FIPS-Specific)

```bash
# Check for OpenSSL package
cat sbom.json | jq '.predicate.Data.packages[] | select(.name == "openssl-libs")'

# Verify OpenSSL version (should be 3.5.5)
cat sbom.json | jq '.predicate.Data.packages[] | select(.name == "openssl-libs") | .versionInfo'
# Expected: "3.5.5-1.fc44"

# Check for crypto-policies package
cat sbom.json | jq '.predicate.Data.packages[] | select(.name == "crypto-policies")'

# List all packages
cat sbom.json | jq '.predicate.Data.packages[] | {name: .name, version: .versionInfo}'
```

### SBOM-Based FIPS Policy Enforcement

```bash
#!/bin/bash
################################################################################
# Fedora 44 FIPS SBOM Validation
#
# Verifies:
# 1. OpenSSL 3.5.5 is present
# 2. crypto-policies package is present
# 3. Fedora 44 base
################################################################################

set -e

# Extract SBOM
cosign verify-attestation --type spdx \
    --key cosign.pub \
    cr.root.io/fedora:44-fips | \
    jq -r '.payload | @base64d | fromjson' > sbom.json

# Check OpenSSL
OPENSSL_VERSION=$(cat sbom.json | jq -r '.predicate.Data.packages[] | select(.name == "openssl-libs") | .versionInfo')

if echo "${OPENSSL_VERSION}" | grep -q "3.5.5"; then
    echo "✓ OpenSSL version verified: ${OPENSSL_VERSION}"
else
    echo "✗ FAIL: OpenSSL version mismatch. Expected 3.5.5, found ${OPENSSL_VERSION}"
    exit 1
fi

# Check crypto-policies
CRYPTO_POLICIES=$(cat sbom.json | jq -r '.predicate.Data.packages[] | select(.name == "crypto-policies") | .name')

if [ "${CRYPTO_POLICIES}" = "crypto-policies" ]; then
    echo "✓ crypto-policies package confirmed"
else
    echo "✗ FAIL: crypto-policies package not found"
    exit 1
fi

# Verify Fedora 44 base
FEDORA_VERSION=$(cat sbom.json | jq -r '.predicate.Data.packages[] | select(.name == "fedora-release") | .versionInfo')

if echo "${FEDORA_VERSION}" | grep -q "44"; then
    echo "✓ Fedora 44 base confirmed"
else
    echo "✗ FAIL: Not Fedora 44 base"
    exit 1
fi

echo "✓ All SBOM checks passed"
```

---

## SLSA Provenance Verification

### Verify Build Provenance

```bash
# Verify SLSA provenance attestation
cosign verify-attestation --type slsaprovenance \
    --key cosign.pub \
    cr.root.io/fedora:44-fips

# Extract provenance
cosign verify-attestation --type slsaprovenance \
    --key cosign.pub \
    cr.root.io/fedora:44-fips | \
    jq -r '.payload | @base64d | fromjson' > provenance.json
```

### Inspect Build Metadata

```bash
# View build metadata
cat provenance.json | jq '.predicate.buildDefinition.externalParameters'

# Check builder information
cat provenance.json | jq '.predicate.runDetails.builder'

# Verify build date
cat provenance.json | jq '.predicate.runDetails.metadata.startedOn'
```

### Validate SLSA Level

```bash
# Check SLSA compliance
cat provenance.json | jq '.predicateType'
# Expected: "https://slsa.dev/provenance/v1"

# Verify resolved dependencies
cat provenance.json | jq '.predicate.buildDefinition.resolvedDependencies[] | {uri: .uri, name: .name}'
```

### SLSA-Based Policy Enforcement

```bash
#!/bin/bash
# Fedora 44 FIPS - Verify build was performed with expected builder

PROVENANCE_FILE="provenance.json"

# Extract provenance
cosign verify-attestation --type slsaprovenance \
    --key cosign.pub \
    cr.root.io/fedora:44-fips | \
    jq -r '.payload | @base64d | fromjson' > "${PROVENANCE_FILE}"

# Check builder ID
BUILDER_ID=$(cat "${PROVENANCE_FILE}" | jq -r '.predicate.runDetails.builder.id')
EXPECTED_BUILDER="https://cr.root.io/build-infrastructure/docker-buildx"

if [ "${BUILDER_ID}" = "${EXPECTED_BUILDER}" ]; then
    echo "✓ Builder verified: ${BUILDER_ID}"
else
    echo "✗ FAIL: Unexpected builder. Expected ${EXPECTED_BUILDER}, found ${BUILDER_ID}"
    exit 1
fi

# Verify Fedora base image source
FEDORA_SOURCE=$(cat "${PROVENANCE_FILE}" | jq -r '.predicate.buildDefinition.externalParameters.source.repository')
if echo "${FEDORA_SOURCE}" | grep -q "fedora:44"; then
    echo "✓ Fedora 44 base source verified"
else
    echo "✗ FAIL: Unexpected base image source"
    exit 1
fi

echo "✓ SLSA provenance verification passed"
```

---

## Policy Enforcement

### Method 1: Custom Verification Script

```bash
#!/bin/bash
################################################################################
# Fedora 44 FIPS Image Verification Policy
#
# This script enforces the following policies:
# 1. Image signature must be valid
# 2. SLSA provenance must be present
# 3. SBOM must be present
# 4. OpenSSL 3.5.5 must be in SBOM
# 5. crypto-policies package must be present
# 6. Fedora 44 base verified
################################################################################

set -e

IMAGE="cr.root.io/fedora:44-fips"
PUBLIC_KEY="cosign.pub"
PASSED=0
FAILED=0

echo "================================================================================"
echo "Fedora 44 FIPS Image Verification Policy"
echo "================================================================================"
echo "Image: ${IMAGE}"
echo "Date: $(date)"
echo ""

# Policy 1: Signature Verification
echo "[1/6] Verifying image signature..."
if cosign verify --key "${PUBLIC_KEY}" "${IMAGE}" > /dev/null 2>&1; then
    echo "✓ PASS: Image signature valid"
    ((PASSED++))
else
    echo "✗ FAIL: Image signature invalid or missing"
    ((FAILED++))
fi

# Policy 2: SLSA Provenance
echo "[2/6] Verifying SLSA provenance..."
if cosign verify-attestation --type slsaprovenance --key "${PUBLIC_KEY}" "${IMAGE}" > /dev/null 2>&1; then
    echo "✓ PASS: SLSA provenance verified"
    ((PASSED++))
else
    echo "✗ FAIL: SLSA provenance missing or invalid"
    ((FAILED++))
fi

# Policy 3: SBOM Presence
echo "[3/6] Verifying SBOM..."
if cosign verify-attestation --type spdx --key "${PUBLIC_KEY}" "${IMAGE}" > /dev/null 2>&1; then
    echo "✓ PASS: SBOM verified"
    ((PASSED++))
else
    echo "✗ FAIL: SBOM missing or invalid"
    ((FAILED++))
fi

# Policy 4: OpenSSL Version
echo "[4/6] Verifying OpenSSL 3.5.5..."
cosign verify-attestation --type spdx --key "${PUBLIC_KEY}" "${IMAGE}" | \
    jq -r '.payload | @base64d | fromjson' > /tmp/sbom.json

OPENSSL_VERSION=$(cat /tmp/sbom.json | jq -r '.predicate.Data.packages[] | select(.name == "openssl-libs") | .versionInfo')
if echo "${OPENSSL_VERSION}" | grep -q "3.5.5"; then
    echo "✓ PASS: OpenSSL 3.5.5 confirmed"
    ((PASSED++))
else
    echo "✗ FAIL: OpenSSL version mismatch (expected 3.5.5, found ${OPENSSL_VERSION})"
    ((FAILED++))
fi

# Policy 5: crypto-policies Package
echo "[5/6] Verifying crypto-policies package..."
CRYPTO_POLICIES=$(cat /tmp/sbom.json | jq -r '.predicate.Data.packages[] | select(.name == "crypto-policies") | .name')
if [ "${CRYPTO_POLICIES}" = "crypto-policies" ]; then
    echo "✓ PASS: crypto-policies package confirmed"
    ((PASSED++))
else
    echo "✗ FAIL: crypto-policies package not found"
    ((FAILED++))
fi

# Policy 6: Fedora 44 Base
echo "[6/6] Verifying Fedora 44 base..."
FEDORA_VERSION=$(cat /tmp/sbom.json | jq -r '.predicate.Data.packages[] | select(.name == "fedora-release") | .versionInfo')
if echo "${FEDORA_VERSION}" | grep -q "44"; then
    echo "✓ PASS: Fedora 44 base confirmed"
    ((PASSED++))
else
    echo "✗ FAIL: Fedora 44 base verification failed"
    ((FAILED++))
fi

# Summary
echo "
================================================================================"
echo "Policy Verification Summary"
echo "================================================================================"
echo "Passed: ${PASSED}/6"
echo "Failed: ${FAILED}/6"
echo ""

if [ ${FAILED} -eq 0 ]; then
    echo "✓ ALL POLICIES PASSED - Image approved for FIPS use"
    exit 0
else
    echo "✗ POLICY VERIFICATION FAILED - Image NOT approved for use"
    exit 1
fi
```

### Method 2: Kubernetes Admission Controller (Kyverno)

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-fedora-fips-signatures
spec:
  validationFailureAction: enforce
  background: false
  webhookTimeoutSeconds: 30
  rules:
  - name: verify-signature
    match:
      any:
      - resources:
          kinds:
          - Pod
    verifyImages:
    - imageReferences:
      - "cr.root.io/fedora:44-fips*"
      attestors:
      - count: 1
        entries:
        - keys:
            publicKeys: |-
              -----BEGIN PUBLIC KEY-----
              MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE...
              -----END PUBLIC KEY-----
      attestations:
      - predicateType: https://slsa.dev/provenance/v1
        conditions:
        - all:
          - key: "{{ builder.id }}"
            operator: Equals
            value: "https://cr.root.io/build-infrastructure/docker-buildx"
```

---

## Keyless Verification (Sigstore)

If the image was signed using keyless signing with Sigstore:

### Keyless Signature Verification

```bash
# Verify using Sigstore's transparency log
cosign verify \
    --certificate-identity-regexp=".*@root.io" \
    --certificate-oidc-issuer="https://accounts.google.com" \
    cr.root.io/fedora:44-fips
```

### Verify with Certificate Chain

```bash
# Verify with full certificate chain
cosign verify \
    --certificate-chain=/path/to/ca-cert.pem \
    --certificate-identity="fips-team@root.io" \
    cr.root.io/fedora:44-fips
```

---

## Automation and CI/CD Integration

### GitHub Actions

```yaml
name: Verify Fedora 44 FIPS Image

on:
  workflow_dispatch:
  schedule:
    - cron: '0 0 * * *'  # Daily verification

jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - name: Install Cosign
        uses: sigstore/cosign-installer@main

      - name: Verify Image Signature
        env:
          IMAGE: cr.root.io/fedora:44-fips
          PUBLIC_KEY: ${{ secrets.COSIGN_PUBLIC_KEY }}
        run: |
          echo "${PUBLIC_KEY}" > cosign.pub
          cosign verify --key cosign.pub ${IMAGE}

      - name: Verify SLSA Provenance
        run: |
          cosign verify-attestation --type slsaprovenance \
            --key cosign.pub \
            cr.root.io/fedora:44-fips

      - name: Verify SBOM
        run: |
          cosign verify-attestation --type spdx \
            --key cosign.pub \
            cr.root.io/fedora:44-fips
```

### GitLab CI

```yaml
verify_fedora_fips_image:
  stage: verify
  image: gcr.io/projectsigstore/cosign:latest
  script:
    - echo "${COSIGN_PUBLIC_KEY}" > cosign.pub
    - cosign verify --key cosign.pub cr.root.io/fedora:44-fips
    - cosign verify-attestation --type slsaprovenance --key cosign.pub cr.root.io/fedora:44-fips
    - cosign verify-attestation --type spdx --key cosign.pub cr.root.io/fedora:44-fips
  only:
    - main
```

### Jenkins Pipeline

```groovy
pipeline {
    agent any

    environment {
        IMAGE = 'cr.root.io/fedora:44-fips'
        COSIGN_PUBLIC_KEY = credentials('cosign-public-key')
    }

    stages {
        stage('Verify Signature') {
            steps {
                sh '''
                    echo "${COSIGN_PUBLIC_KEY}" > cosign.pub
                    cosign verify --key cosign.pub ${IMAGE}
                '''
            }
        }

        stage('Verify Attestations') {
            steps {
                sh '''
                    cosign verify-attestation --type slsaprovenance --key cosign.pub ${IMAGE}
                    cosign verify-attestation --type spdx --key cosign.pub ${IMAGE}
                '''
            }
        }
    }
}
```

---

## Troubleshooting

### Common Issues and Solutions

#### Issue 1: "Error: no matching signatures"

**Problem:** Image signature not found or invalid.

**Solutions:**
```bash
# Check if image was actually signed
cosign triangulate cr.root.io/fedora:44-fips

# Verify you're using the correct registry/tag
docker images | grep fedora

# Ensure network access to registry
curl -I https://cr.root.io/v2/
```

#### Issue 2: "Error: invalid public key"

**Problem:** Public key format is incorrect or corrupted.

**Solutions:**
```bash
# Verify public key format
cat cosign.pub
# Should start with: -----BEGIN PUBLIC KEY-----

# Re-download public key
curl -o cosign.pub https://cr.root.io/fedora/44-fips/cosign.pub

# Check for extra whitespace/newlines
dos2unix cosign.pub  # If available
```

#### Issue 3: "Error: failed to verify signature"

**Problem:** Signature verification failed (possible tampering).

**Solutions:**
```bash
# DO NOT USE THE IMAGE - potential security issue

# Verify image digest matches expected value
docker inspect cr.root.io/fedora:44-fips | jq '.[0].RepoDigests'

# Report to security team
# Email: fips-team@root.io
```

#### Issue 4: Network/Timeout Issues

```bash
# Increase timeout
cosign verify --timeout 60s --key cosign.pub cr.root.io/fedora:44-fips

# Use local image
docker pull cr.root.io/fedora:44-fips
cosign verify --key cosign.pub --local-image cr.root.io/fedora:44-fips
```

---

## Best Practices

### Security Best Practices

1. **Always Verify Before Use**
   - Never pull/run unverified images in production
   - Automate verification in CI/CD pipelines
   - Fail deployments on verification failure
   - Especially critical for FIPS-compliant deployments

2. **Secure Key Management**
   - Store public keys in version control
   - Use key vaults for sensitive environments (HashiCorp Vault, AWS KMS)
   - Implement key rotation policy
   - Verify key fingerprints through independent channels

3. **Defense in Depth**
   - Combine signature verification with other security measures
   - Use image scanning tools (Trivy, Grype)
   - Implement runtime security (Falco, Sysdig)
   - Apply principle of least privilege
   - Verify FIPS mode on container startup

4. **Monitoring and Alerting**
   - Monitor for signature verification failures
   - Alert on policy violations
   - Track image provenance changes
   - Regular security audits
   - Monitor FIPS validation logs

### Operational Best Practices

1. **Automation**
   - Integrate verification into CI/CD
   - Use admission controllers (Kyverno, OPA Gatekeeper)
   - Automate SBOM analysis (OpenSSL version checks)
   - Schedule regular verification checks

2. **Documentation**
   - Document verification procedures
   - Maintain runbooks for troubleshooting
   - Track public key versions
   - Record policy decisions
   - Document FIPS compliance requirements

3. **Testing**
   - Test verification in non-production first
   - Validate policy enforcement
   - Test failure scenarios
   - Regular disaster recovery drills
   - Validate FIPS mode in test environments

### FIPS-Specific Best Practices

1. **FIPS Validation**
   - Always verify OpenSSL 3.5.5 in SBOM
   - Check for crypto-policies package
   - Verify Fedora 44 base
   - Test FIPS mode after deployment
   - Run diagnostic test suite (68+ tests)

2. **Compliance Documentation**
   - Maintain verification logs
   - Document attestation checks
   - Keep SBOM records
   - Track FIPS provider versions
   - Regular compliance audits

---

## Additional Resources

### Official Documentation

- **Cosign Documentation:** https://docs.sigstore.dev/cosign/overview/
- **Sigstore:** https://www.sigstore.dev/
- **SLSA Framework:** https://slsa.dev/
- **SPDX:** https://spdx.dev/
- **FIPS 140-3:** https://csrc.nist.gov/publications/detail/fips/140/3/final

### Root FIPS Team Resources

- **Image Registry:** https://cr.root.io/
- **Documentation:** See ../README.md, ARCHITECTURE.md, ATTESTATION.md
- **FIPS Validation:** See ../Evidence/test-execution-summary.md
- **Security Contact:** fips-team@root.io
- **Support:** Create issue at internal support portal

### Fedora Resources

- **Fedora Crypto-Policies:** https://docs.fedoraproject.org/en-US/security-guide/crypto-policies/
- **Fedora Security:** https://docs.fedoraproject.org/en-US/security-guide/
- **Fedora 44 Release Notes:** https://docs.fedoraproject.org/en-US/fedora/f44/release-notes/

### Community Resources

- **Cosign GitHub:** https://github.com/sigstore/cosign
- **Sigstore Slack:** https://sigstore.slack.com/
- **SLSA Community:** https://github.com/slsa-framework/slsa

---

## Document Information

**Version:** 1.0
**Last Updated:** April 16, 2026
**Maintained By:** Root FIPS Team
**Review Frequency:** Quarterly
**Next Review:** July 16, 2026

**Contact Information:**
- Email: fips-team@root.io
- Security Issues: security@root.io
- FIPS Questions: fips-team@root.io
- Response Time: 48 hours for security issues

---

**End of Document**
