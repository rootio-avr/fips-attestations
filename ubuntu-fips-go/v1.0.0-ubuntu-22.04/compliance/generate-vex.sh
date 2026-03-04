#!/bin/bash
################################################################################
# VEX Generator for ubuntu-fips-go (OpenVEX Format)
#
# Purpose: Generate Vulnerability Exploitability eXchange statement
################################################################################

set -e

# Configuration
IMAGE_NAME="ubuntu-fips-go"
IMAGE_VERSION="v1.0.0-ubuntu-22.04"
VEX_OUTPUT="vex-ubuntu-fips-go-v1.0.0.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "================================================================================"
echo "Generating VEX for ${IMAGE_NAME}:${IMAGE_VERSION}"
echo "================================================================================"
echo ""

# Create VEX document in OpenVEX format
cat > "$VEX_OUTPUT" <<'EOF'
{
  "@context": "https://openvex.dev/ns/v0.2.0",
  "@id": "https://focaloid.com/vex/ubuntu-fips-go/v1.0.0",
  "author": "Focaloid Security Team",
  "timestamp": "TIMESTAMP_PLACEHOLDER",
  "version": 1,
  "tooling": "focaloid-vex-generator-1.0",
  "statements": [
    {
      "vulnerability": {
        "name": "CVE-2024-EXAMPLE-OPENSSL",
        "description": "Hypothetical OpenSSL vulnerability"
      },
      "products": [
        {
          "@id": "pkg:docker/ubuntu-fips-go@v1.0.0-ubuntu-22.04",
          "identifiers": {
            "purl": "pkg:docker/focaloid/ubuntu-fips-go@v1.0.0-ubuntu-22.04"
          },
          "subcomponents": [
            {
              "@id": "pkg:deb/ubuntu/openssl@3.0.2"
            }
          ]
        }
      ],
      "status": "not_affected",
      "justification": "component_not_present",
      "impact_statement": "This image uses wolfSSL FIPS v5.8.2 (Certificate #4718) as the primary cryptographic backend via wolfProvider. System OpenSSL 3.0.2 is present but not used for cryptographic operations in FIPS mode."
    },
    {
      "vulnerability": {
        "name": "CVE-2024-EXAMPLE-GOLANG",
        "description": "Hypothetical Go runtime vulnerability"
      },
      "products": [
        {
          "@id": "pkg:docker/ubuntu-fips-go@v1.0.0-ubuntu-22.04",
          "subcomponents": [
            {
              "@id": "pkg:github/golang-fips/go@go1.25-fips-release"
            }
          ]
        }
      ],
      "status": "not_affected",
      "justification": "vulnerable_code_not_in_execute_path",
      "impact_statement": "golang-fips/go fork includes security patches and FIPS-specific modifications. Strict FIPS runtime (GOEXPERIMENT=strictfipsruntime) blocks non-FIPS algorithms."
    },
    {
      "vulnerability": {
        "name": "CVE-2024-EXAMPLE-WOLFSSL",
        "description": "Hypothetical wolfSSL vulnerability"
      },
      "products": [
        {
          "@id": "pkg:docker/ubuntu-fips-go@v1.0.0-ubuntu-22.04",
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
          "@id": "pkg:docker/ubuntu-fips-go@v1.0.0-ubuntu-22.04"
        }
      ],
      "status": "not_affected",
      "justification": "vulnerable_code_not_in_execute_path",
      "impact_statement": "STRICT FIPS POLICY: MD5 blocked by Go runtime (GODEBUG=fips140=only), SHA-1 blocked at wolfSSL library level (--disable-sha). Only FIPS-approved algorithms (SHA-256, SHA-384, SHA-512) are available."
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
echo "Statements: 4 vulnerability assessments"
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
echo "  2. Go runtime vulnerabilities: NOT AFFECTED (golang-fips/go patched)"
echo "  3. wolfSSL vulnerabilities: UNDER INVESTIGATION (monitoring advisories)"
echo "  4. MD5/SHA-1 weaknesses: NOT AFFECTED (strict FIPS policy blocks)"
echo ""
echo "FIPS Compliance:"
echo "  - wolfSSL FIPS 140-3 Certificate: #4718"
echo "  - Strict Policy: MD5 and SHA-1 blocked"
echo "  - Approved Algorithms: SHA-256, SHA-384, SHA-512"
echo ""
echo "✓ VEX generation complete"
