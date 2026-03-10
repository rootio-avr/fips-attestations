#!/bin/bash
################################################################################
# VEX Generator for java (OpenVEX Format)
#
# Purpose: Generate Vulnerability Exploitability eXchange statement
################################################################################

set -e

# Configuration
IMAGE_NAME="java"
IMAGE_VERSION="17-jammy-ubuntu-22.04-fips"
VEX_OUTPUT="vex-java-17-jammy-ubuntu-22.04-fips.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "================================================================================"
echo "Generating VEX for ${IMAGE_NAME}:${IMAGE_VERSION}"
echo "================================================================================"
echo ""

# Create VEX document in OpenVEX format
cat > "$VEX_OUTPUT" <<'EOF'
{
  "@context": "https://openvex.dev/ns/v0.2.0",
  "@id": "https://Root.com/vex/java/v1.0.0",
  "author": "Root Security Team",
  "timestamp": "TIMESTAMP_PLACEHOLDER",
  "version": 1,
  "tooling": "Root-vex-generator-1.0",
  "statements": [
    {
      "vulnerability": {
        "name": "CVE-2024-EXAMPLE-OPENSSL",
        "description": "Hypothetical OpenSSL vulnerability"
      },
      "products": [
        {
          "@id": "pkg:docker/java@17-jammy-ubuntu-22.04-fips",
          "identifiers": {
            "purl": "pkg:docker/Root/java@17-jammy-ubuntu-22.04-fips"
          },
          "subcomponents": [
            {
              "@id": "pkg:generic/openssl@3.0.19"
            }
          ]
        }
      ],
      "status": "not_affected",
      "justification": "component_not_present",
      "impact_statement": "This image uses wolfSSL FIPS v5.8.2 (Certificate #4718) as the primary cryptographic backend via wolfProvider. OpenSSL 3.0.19 (compiled from source) provides the provider interface but cryptographic operations route through wolfSSL in FIPS mode."
    },
    {
      "vulnerability": {
        "name": "CVE-2024-EXAMPLE-OPENJDK",
        "description": "Hypothetical OpenJDK vulnerability"
      },
      "products": [
        {
          "@id": "pkg:docker/java@17-jammy-ubuntu-22.04-fips",
          "subcomponents": [
            {
              "@id": "pkg:deb/ubuntu/openjdk-17-jre-headless@17"
            }
          ]
        }
      ],
      "status": "not_affected",
      "justification": "vulnerable_code_not_in_execute_path",
      "impact_statement": "OpenJDK 17 JRE with custom java.security policy. FIPS mode configured (fips.mode=strict, crypto.policy=unlimited). MD5, SHA-1, and weak algorithms disabled at JDK level."
    },
    {
      "vulnerability": {
        "name": "CVE-2024-EXAMPLE-WOLFSSL",
        "description": "Hypothetical wolfSSL vulnerability"
      },
      "products": [
        {
          "@id": "pkg:docker/java@17-jammy-ubuntu-22.04-fips",
          "subcomponents": [
            {
              "@id": "pkg:generic/wolfssl@5.8.2-fips"
            }
          ]
        }
      ],
      "status": "under_investigation",
      "action_statement": "Monitoring wolfSSL security advisories. FIPS 140-3 Certificate #4718 validation ensures cryptographic module integrity.",
      "action_statement_timestamp": "TIMESTAMP_PLACEHOLDER"
    },
    {
      "vulnerability": {
        "name": "GENERAL-MD5-SHA1-WEAKNESS",
        "description": "MD5 and SHA-1 cryptographic weaknesses"
      },
      "products": [
        {
          "@id": "pkg:docker/java@17-jammy-ubuntu-22.04-fips"
        }
      ],
      "status": "not_affected",
      "justification": "vulnerable_code_not_in_execute_path",
      "impact_statement": "STRICT FIPS POLICY: MD5 and SHA-1 disabled via java.security policy (jdk.tls.disabledAlgorithms, jdk.certpath.disabledAlgorithms, jdk.jar.disabledAlgorithms). wolfSSL built with --disable-sha. Only FIPS-approved algorithms available."
    },
    {
      "vulnerability": {
        "name": "LOG4SHELL-CVE-2021-44228",
        "description": "Log4j RCE vulnerability"
      },
      "products": [
        {
          "@id": "pkg:docker/java@17-jammy-ubuntu-22.04-fips"
        }
      ],
      "status": "not_affected",
      "justification": "component_not_present",
      "impact_statement": "Log4j library not included in this image. Only OpenJDK 17 JRE runtime is present."
    }
  ]
}
EOF

# Replace timestamp placeholder
sed -i "s/TIMESTAMP_PLACEHOLDER/$TIMESTAMP/g" "$VEX_OUTPUT"

echo "✓ VEX generated successfully"
echo ""
echo "Output: $VEX_OUTPUT"
echo "Format: OpenVEX v0.2.0"
echo "Statements: 5 vulnerability assessments"
echo ""

# Validate JSON syntax
if command -v python3 >/dev/null 2>&1; then
    if python3 -c "import json; json.load(open('$VEX_OUTPUT'))" 2>/dev/null; then
        echo "✓ VEX JSON validation: PASSED"
    else
        echo "✗ VEX JSON validation: FAILED"
        exit 1
    fi
fi

echo ""
echo "================================================================================"
echo "VEX Summary"
echo "================================================================================"
echo "Document: ${IMAGE_NAME}-${IMAGE_VERSION}"
echo "Standard: OpenVEX v0.2.0"
echo "Created: ${TIMESTAMP}"
echo ""
echo "Vulnerability Assessments:"
echo "  1. OpenSSL vulnerabilities: NOT AFFECTED (wolfSSL backend used)"
echo "  2. OpenJDK vulnerabilities: NOT AFFECTED (FIPS security policy applied)"
echo "  3. wolfSSL vulnerabilities: UNDER INVESTIGATION (monitoring advisories)"
echo "  4. MD5/SHA-1 weaknesses: NOT AFFECTED (strict FIPS policy blocks)"
echo "  5. Log4Shell (Log4j): NOT AFFECTED (Log4j not present)"
echo ""
echo "FIPS Compliance:"
echo "  - wolfSSL FIPS 140-3 Certificate: #4718"
echo "  - Java Security: fips.mode=strict"
echo "  - Strict Policy: MD5 and SHA-1 blocked"
echo "  - Approved Algorithms: SHA-256, SHA-384, SHA-512"
echo ""
echo "✓ VEX generation complete"
