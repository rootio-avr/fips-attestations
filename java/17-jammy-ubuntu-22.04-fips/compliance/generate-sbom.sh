#!/bin/bash
################################################################################
# SBOM Generator for java (SPDX Format)
#
# Purpose: Generate Software Bill of Materials in SPDX 2.3 JSON format
################################################################################

set -e

# Configuration
IMAGE_NAME="java"
IMAGE_VERSION="17-jammy-ubuntu-22.04-fips"
SBOM_OUTPUT="sbom-java-17-jammy-ubuntu-22.04-fips.spdx.json"
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
      "description": "Ubuntu FIPS Java Image with OpenJDK 17 and wolfSSL FIPS v5 backend",
      "comment": "FIPS 140-3 compliant Java runtime with strict policy (MD5 and SHA-1 blocked)"
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
      "SPDXID": "SPDXRef-Package-OpenJDK",
      "name": "openjdk",
      "versionInfo": "17",
      "supplier": "Organization: Oracle / OpenJDK Community",
      "downloadLocation": "https://openjdk.java.net/",
      "filesAnalyzed": false,
      "licenseConcluded": "GPL-2.0-with-classpath-exception",
      "licenseDeclared": "GPL-2.0-with-classpath-exception",
      "copyrightText": "Copyright (c) Oracle and/or its affiliates",
      "description": "OpenJDK 17 Java Runtime Environment with FIPS security policy",
      "comment": "Configured with java.security policy to disable MD5 and SHA-1 algorithms",
      "externalRefs": [
        {
          "referenceCategory": "SECURITY",
          "referenceType": "cpe23Type",
          "referenceLocator": "cpe:2.3:a:oracle:openjdk:17:*:*:*:*:*:*:*"
        },
        {
          "referenceCategory": "PACKAGE-MANAGER",
          "referenceType": "purl",
          "referenceLocator": "pkg:deb/ubuntu/openjdk-17-jre-headless@17"
        }
      ]
    },
    {
      "SPDXID": "SPDXRef-Package-JavaSecurityPolicy",
      "name": "java-security-fips-policy",
      "versionInfo": "1.0.0",
      "supplier": "Organization: Root",
      "downloadLocation": "NOASSERTION",
      "filesAnalyzed": false,
      "licenseConcluded": "NOASSERTION",
      "licenseDeclared": "NOASSERTION",
      "copyrightText": "NOASSERTION",
      "description": "Custom Java security policy for FIPS mode enforcement",
      "comment": "Disables MD5, SHA-1, weak ciphers. Sets fips.mode=strict and crypto.policy=unlimited"
    },
    {
      "SPDXID": "SPDXRef-Package-FipsDemoApp",
      "name": "fips-demo-app",
      "versionInfo": "1.0.0",
      "supplier": "Organization: Root",
      "downloadLocation": "NOASSERTION",
      "filesAnalyzed": false,
      "licenseConcluded": "NOASSERTION",
      "licenseDeclared": "NOASSERTION",
      "copyrightText": "NOASSERTION",
      "description": "Java demonstration application for FIPS algorithm testing"
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
      "relatedSpdxElement": "SPDXRef-Package-OpenJDK"
    },
    {
      "spdxElementId": "SPDXRef-Package-Container",
      "relationshipType": "CONTAINS",
      "relatedSpdxElement": "SPDXRef-Package-JavaSecurityPolicy"
    },
    {
      "spdxElementId": "SPDXRef-Package-Container",
      "relationshipType": "CONTAINS",
      "relatedSpdxElement": "SPDXRef-Package-FipsDemoApp"
    },
    {
      "spdxElementId": "SPDXRef-Package-OpenJDK",
      "relationshipType": "DEPENDS_ON",
      "relatedSpdxElement": "SPDXRef-Package-OpenSSL"
    },
    {
      "spdxElementId": "SPDXRef-Package-OpenJDK",
      "relationshipType": "DEPENDS_ON",
      "relatedSpdxElement": "SPDXRef-Package-JavaSecurityPolicy"
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
      "spdxElementId": "SPDXRef-Package-FipsDemoApp",
      "relationshipType": "DEPENDS_ON",
      "relatedSpdxElement": "SPDXRef-Package-OpenJDK"
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
echo "  - OpenJDK 17 JRE"
echo "  - Java FIPS Security Policy"
echo "  - FIPS Demo Application"
echo ""
echo "FIPS Compliance:"
echo "  - FIPS 140-3 Certificate: #4718 (wolfSSL)"
echo "  - Strict Policy: MD5 and SHA-1 blocked"
echo "  - Java Security: fips.mode=strict"
echo "  - Approved Algorithms: SHA-256, SHA-384, SHA-512"
echo ""
echo "✓ SBOM generation complete"
