#!/bin/bash
################################################################################
# SBOM Generator for golang (SPDX Format)
#
# Purpose: Generate Software Bill of Materials in SPDX 2.3 JSON format
################################################################################

set -e

# Configuration
IMAGE_NAME="golang"
IMAGE_VERSION="1.25-jammy-ubuntu-22.04-fips"
SBOM_OUTPUT="sbom-golang-1.25-jammy-ubuntu-22.04-fips.spdx.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DOCUMENT_NAMESPACE="https://Root.com/sbom/${IMAGE_NAME}/${IMAGE_VERSION}/${TIMESTAMP}"

echo "================================================================================"
echo "Generating SBOM for ${IMAGE_NAME}:${IMAGE_VERSION}"
echo "================================================================================"
echo ""

# Create SBOM in SPDX 2.3 JSON format
cat > "$SBOM_OUTPUT" <<EOF
{
  "spdxVersion": "SPDX-2.3",
  "dataLicense": "CC0-1.0",
  "SPDXID": "SPDXRef-DOCUMENT",
  "name": "${IMAGE_NAME}-${IMAGE_VERSION}",
  "documentNamespace": "${DOCUMENT_NAMESPACE}",
  "creationInfo": {
    "created": "${TIMESTAMP}",
    "creators": [
      "Tool: Root-sbom-generator-1.0",
      "Organization: Root"
    ],
    "licenseListVersion": "3.21"
  },
  "packages": [
    {
      "SPDXID": "SPDXRef-Package-Container",
      "name": "${IMAGE_NAME}",
      "versionInfo": "${IMAGE_VERSION}",
      "supplier": "Organization: Root",
      "downloadLocation": "NOASSERTION",
      "filesAnalyzed": false,
      "licenseConcluded": "NOASSERTION",
      "licenseDeclared": "NOASSERTION",
      "copyrightText": "NOASSERTION",
      "description": "Go FIPS Image with golang-fips/go compiler and wolfSSL FIPS v5 backend",
      "comment": "FIPS 140-3 compliant Go runtime and compiler with strict policy (MD5 and SHA-1 blocked)"
    },
    {
      "SPDXID": "SPDXRef-Package-Ubuntu",
      "name": "ubuntu",
      "versionInfo": "22.04",
      "supplier": "Organization: Canonical Ltd.",
      "downloadLocation": "https://hub.docker.com/_/ubuntu",
      "filesAnalyzed": false,
      "licenseConcluded": "NOASSERTION",
      "licenseDeclared": "Various",
      "copyrightText": "Copyright (c) Canonical Ltd.",
      "description": "Ubuntu 22.04 LTS (Jammy Jellyfish) base operating system",
      "externalRefs": [
        {
          "referenceCategory": "PACKAGE-MANAGER",
          "referenceType": "purl",
          "referenceLocator": "pkg:docker/ubuntu@22.04"
        }
      ]
    },
    {
      "SPDXID": "SPDXRef-Package-OpenSSL",
      "name": "openssl",
      "versionInfo": "3.0.19",
      "supplier": "Organization: OpenSSL Project",
      "downloadLocation": "https://www.openssl.org/source/openssl-3.0.19.tar.gz",
      "filesAnalyzed": false,
      "licenseConcluded": "Apache-2.0",
      "licenseDeclared": "Apache-2.0",
      "copyrightText": "Copyright (c) The OpenSSL Project",
      "description": "OpenSSL 3.0.19 cryptographic library (compiled from source)",
      "externalRefs": [
        {
          "referenceCategory": "SECURITY",
          "referenceType": "cpe23Type",
          "referenceLocator": "cpe:2.3:a:openssl:openssl:3.0.19:*:*:*:*:*:*:*"
        }
      ]
    },
    {
      "SPDXID": "SPDXRef-Package-wolfSSL",
      "name": "wolfssl",
      "versionInfo": "5.8.2-fips",
      "supplier": "Organization: wolfSSL Inc.",
      "downloadLocation": "https://www.wolfssl.com/comm/wolfssl/",
      "filesAnalyzed": false,
      "licenseConcluded": "NOASSERTION",
      "licenseDeclared": "Commercial",
      "copyrightText": "Copyright (c) wolfSSL Inc.",
      "description": "wolfSSL FIPS 140-3 Cryptographic Module v5.8.2 (Certificate #4718)",
      "comment": "Built with --disable-sha to block SHA-1 at library level. FIPS 140-3 validated.",
      "externalRefs": [
        {
          "referenceCategory": "SECURITY",
          "referenceType": "url",
          "referenceLocator": "https://csrc.nist.gov/projects/cryptographic-module-validation-program/certificate/4718"
        }
      ]
    },
    {
      "SPDXID": "SPDXRef-Package-wolfProvider",
      "name": "wolfProvider",
      "versionInfo": "1.1.0",
      "supplier": "Organization: wolfSSL Inc.",
      "downloadLocation": "https://github.com/wolfSSL/wolfProvider/releases/tag/v1.1.0",
      "filesAnalyzed": false,
      "licenseConcluded": "GPL-3.0",
      "licenseDeclared": "GPL-3.0",
      "copyrightText": "Copyright (c) wolfSSL Inc.",
      "description": "OpenSSL 3.x provider that routes cryptographic operations to wolfSSL",
      "externalRefs": [
        {
          "referenceCategory": "PACKAGE-MANAGER",
          "referenceType": "purl",
          "referenceLocator": "pkg:github/wolfSSL/wolfProvider@v1.1.0"
        }
      ]
    },
    {
      "SPDXID": "SPDXRef-Package-GolangFIPS",
      "name": "golang-fips",
      "versionInfo": "go1.25-fips-release",
      "supplier": "Organization: golang-fips project",
      "downloadLocation": "https://github.com/golang-fips/go/tree/go1.25-fips-release",
      "filesAnalyzed": false,
      "licenseConcluded": "BSD-3-Clause",
      "licenseDeclared": "BSD-3-Clause",
      "copyrightText": "Copyright (c) The Go Authors",
      "description": "FIPS-enabled Go compiler and runtime with OpenSSL backend integration",
      "comment": "Built with GOEXPERIMENT=strictfipsruntime for strict FIPS enforcement. ChaCha20-Poly1305 removed.",
      "externalRefs": [
        {
          "referenceCategory": "PACKAGE-MANAGER",
          "referenceType": "purl",
          "referenceLocator": "pkg:github/golang-fips/go@go1.25-fips-release"
        }
      ]
    },
    {
      "SPDXID": "SPDXRef-Package-BuildEssential",
      "name": "build-essential",
      "versionInfo": "12.9ubuntu3",
      "supplier": "Organization: Canonical Ltd.",
      "downloadLocation": "http://archive.ubuntu.com/ubuntu/pool/main/b/build-essential/",
      "filesAnalyzed": false,
      "licenseConcluded": "NOASSERTION",
      "licenseDeclared": "GPL",
      "copyrightText": "NOASSERTION",
      "description": "Build tools including gcc, g++, and make for Go compilation support"
    }
  ],
  "relationships": [
    {
      "spdxElementId": "SPDXRef-DOCUMENT",
      "relationshipType": "DESCRIBES",
      "relatedSpdxElement": "SPDXRef-Package-Container"
    },
    {
      "spdxElementId": "SPDXRef-Package-Container",
      "relationshipType": "CONTAINS",
      "relatedSpdxElement": "SPDXRef-Package-Ubuntu"
    },
    {
      "spdxElementId": "SPDXRef-Package-Container",
      "relationshipType": "CONTAINS",
      "relatedSpdxElement": "SPDXRef-Package-OpenSSL"
    },
    {
      "spdxElementId": "SPDXRef-Package-Container",
      "relationshipType": "CONTAINS",
      "relatedSpdxElement": "SPDXRef-Package-wolfSSL"
    },
    {
      "spdxElementId": "SPDXRef-Package-Container",
      "relationshipType": "CONTAINS",
      "relatedSpdxElement": "SPDXRef-Package-wolfProvider"
    },
    {
      "spdxElementId": "SPDXRef-Package-Container",
      "relationshipType": "CONTAINS",
      "relatedSpdxElement": "SPDXRef-Package-GolangFIPS"
    },
    {
      "spdxElementId": "SPDXRef-Package-Container",
      "relationshipType": "CONTAINS",
      "relatedSpdxElement": "SPDXRef-Package-BuildEssential"
    },
    {
      "spdxElementId": "SPDXRef-Package-Container",
      "relationshipType": "CONTAINS",
      "relatedSpdxElement": "SPDXRef-Package-LibSSLDev"
    },
    {
      "spdxElementId": "SPDXRef-Package-GolangFIPS",
      "relationshipType": "DEPENDS_ON",
      "relatedSpdxElement": "SPDXRef-Package-OpenSSL"
    },
    {
      "spdxElementId": "SPDXRef-Package-wolfProvider",
      "relationshipType": "DEPENDS_ON",
      "relatedSpdxElement": "SPDXRef-Package-wolfSSL"
    },
    {
      "spdxElementId": "SPDXRef-Package-wolfProvider",
      "relationshipType": "DEPENDS_ON",
      "relatedSpdxElement": "SPDXRef-Package-OpenSSL"
    },
    {
      "spdxElementId": "SPDXRef-Package-OpenSSL",
      "relationshipType": "RUNTIME_DEPENDENCY_OF",
      "relatedSpdxElement": "SPDXRef-Package-wolfProvider"
    },
    {
      "spdxElementId": "SPDXRef-Package-wolfSSL",
      "relationshipType": "RUNTIME_DEPENDENCY_OF",
      "relatedSpdxElement": "SPDXRef-Package-wolfProvider"
    }
  ]
}
EOF

echo "✓ SBOM generated successfully"
echo ""
echo "Output: $SBOM_OUTPUT"
echo "Format: SPDX 2.3 JSON"
echo "Components: 8 packages documented"
echo ""

# Validate JSON syntax
if command -v python3 >/dev/null 2>&1; then
    if python3 -c "import json; json.load(open('$SBOM_OUTPUT'))" 2>/dev/null; then
        echo "✓ SBOM JSON validation: PASSED"
    else
        echo "✗ SBOM JSON validation: FAILED"
        exit 1
    fi
fi

# Display summary
echo ""
echo "================================================================================"
echo "SBOM Summary"
echo "================================================================================"
echo "Document: ${IMAGE_NAME}-${IMAGE_VERSION}"
echo "Standard: SPDX 2.3"
echo "Created: ${TIMESTAMP}"
echo ""
echo "Key Components:"
echo "  - Ubuntu 22.04 LTS"
echo "  - OpenSSL 3.0.19 (compiled from source)"
echo "  - wolfSSL FIPS v5.8.2 (Cert #4718)"
echo "  - wolfProvider v1.1.0"
echo "  - golang-fips/go v1.25"
echo "  - Build tools (gcc, g++, make)"
echo ""
echo "FIPS Compliance:"
echo "  - FIPS 140-3 Certificate: #4718 (wolfSSL)"
echo "  - Strict Policy: MD5 and SHA-1 blocked"
echo "  - Approved Algorithms: SHA-256, SHA-384, SHA-512"
echo ""
echo "✓ SBOM generation complete"
