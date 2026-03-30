#!/bin/bash
################################################################################
# Redis Exporter FIPS - TLS Certificate Setup Script
#
# This script generates FIPS-compliant TLS certificates for:
# - CA (Certificate Authority)
# - Redis Server
# - Redis Client
# - redis_exporter
#
# All certificates use FIPS-approved algorithms:
# - RSA 2048/4096 bit keys
# - SHA-256 signatures
#
# Usage:
#   ./setup-tls.sh [OPTIONS]
#
# Options:
#   --ca-only       Generate only CA certificate
#   --force         Overwrite existing certificates
#   --help          Show this help message
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Certificate directory
CERT_DIR="${CERT_DIR:-/demo/certs}"
FORCE=false
CA_ONLY=false

################################################################################
# Permission Check Functions
################################################################################

check_directory_permissions() {
    local test_file="$CERT_DIR/.permission_test_$$"

    # Try to create a test file
    if touch "$test_file" 2>/dev/null; then
        rm -f "$test_file"
        return 0
    else
        return 1
    fi
}

handle_permission_error() {
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}ERROR: Permission Denied${NC}"
    echo -e "${RED}========================================${NC}"
    echo ""

    # Show current context
    echo -e "${YELLOW}Current situation:${NC}"
    echo "  Current user: $(whoami) (UID: $(id -u), GID: $(id -g))"
    echo "  Certificate directory: $CERT_DIR"

    # Check directory ownership
    if [ -d "$CERT_DIR" ]; then
        local dir_owner=$(stat -c '%U:%G (UID:%u GID:%g)' "$CERT_DIR" 2>/dev/null || stat -f '%Su:%Sg (UID:%u GID:%g)' "$CERT_DIR" 2>/dev/null)
        echo "  Directory owner: $dir_owner"
    fi

    echo ""
    echo -e "${YELLOW}Problem:${NC}"
    echo "  Cannot write to $CERT_DIR"
    echo "  This typically happens when using volume mounts without proper user mapping."
    echo ""

    # Check if running in Docker
    if [ -f "/.dockerenv" ] || grep -q docker /proc/1/cgroup 2>/dev/null; then
        echo -e "${GREEN}Solution 1: Run with --user flag (RECOMMENDED)${NC}"
        echo "  This maps the container user to your host user, ensuring correct permissions."
        echo ""
        echo "  docker run --rm --user=\"\$(id -u):\$(id -g)\" \\"
        echo "    -v \$(pwd)/certs:/demo/certs \\"
        echo "    redis-exporter-demos:1.67.0-jammy-ubuntu-22.04-fips \\"
        echo "    /demo/scripts/setup-tls.sh"
        echo ""
        echo -e "${GREEN}Solution 2: Fix directory ownership on host${NC}"
        echo "  If the certs directory was created by root, remove and recreate it:"
        echo ""
        echo "  sudo rm -rf certs"
        echo "  mkdir -p certs"
        echo "  docker run --rm --user=\"\$(id -u):\$(id -g)\" \\"
        echo "    -v \$(pwd)/certs:/demo/certs \\"
        echo "    redis-exporter-demos:1.67.0-jammy-ubuntu-22.04-fips \\"
        echo "    /demo/scripts/setup-tls.sh"
        echo ""
    else
        echo -e "${GREEN}Solution: Fix directory permissions${NC}"
        echo "  Ensure the current user has write access to: $CERT_DIR"
        echo ""
        echo "  sudo chown -R \$(id -u):\$(id -g) $CERT_DIR"
        echo "  sudo chmod -R u+w $CERT_DIR"
        echo ""
    fi

    exit 1
}

################################################################################
# Parse Arguments
################################################################################

while [[ $# -gt 0 ]]; do
    case $1 in
        --ca-only)
            CA_ONLY=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --help)
            head -n 30 "$0" | grep "^#" | sed 's/^# //; s/^#//'
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

################################################################################
# Setup
################################################################################

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}TLS Certificate Generation (FIPS)${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Create certificate directory
mkdir -p "$CERT_DIR"

# Check directory permissions
if ! check_directory_permissions; then
    handle_permission_error
fi

# Check if certificates exist
if [ -f "$CERT_DIR/ca.crt" ] && [ "$FORCE" != "true" ]; then
    echo -e "${YELLOW}[WARN]${NC} Certificates already exist. Use --force to regenerate."
    exit 0
fi

################################################################################
# Generate CA Certificate
################################################################################

echo -e "${YELLOW}[1/4]${NC} Generating CA certificate..."

# Generate CA private key and certificate (RSA 4096, SHA-256 - FIPS approved)
# Use OPENSSL_CONF=/dev/null to bypass wolfProvider decoder incompatibility
OPENSSL_CONF=/dev/null openssl req -x509 -newkey rsa:4096 -nodes \
    -keyout "$CERT_DIR/ca.key" -out "$CERT_DIR/ca.crt" \
    -days 3650 -sha256 \
    -subj "/C=US/ST=Demo/L=Demo/O=Redis Exporter FIPS Demo/OU=CA/CN=Demo CA"

echo -e "${GREEN}[OK]${NC} CA certificate generated"
echo "      Key: $CERT_DIR/ca.key"
echo "      Cert: $CERT_DIR/ca.crt"
echo ""

if [ "$CA_ONLY" = "true" ]; then
    echo -e "${GREEN}CA-only mode. Exiting.${NC}"
    exit 0
fi

################################################################################
# Generate Redis Server Certificate
################################################################################

echo -e "${YELLOW}[2/4]${NC} Generating Redis server certificate..."

# Generate server private key (RSA 2048 - FIPS approved)
# Use OPENSSL_CONF=/dev/null to bypass wolfProvider decoder incompatibility
OPENSSL_CONF=/dev/null openssl genrsa -out "$CERT_DIR/redis.key" 2048

# Generate server CSR
OPENSSL_CONF=/dev/null openssl req -new -key "$CERT_DIR/redis.key" \
    -out "$CERT_DIR/redis.csr" \
    -subj "/C=US/ST=Demo/L=Demo/O=Redis Exporter FIPS Demo/OU=Redis/CN=redis"

# Sign server certificate with CA (SHA-256 - FIPS approved)
OPENSSL_CONF=/dev/null openssl x509 -req -in "$CERT_DIR/redis.csr" \
    -CA "$CERT_DIR/ca.crt" -CAkey "$CERT_DIR/ca.key" \
    -CAcreateserial -out "$CERT_DIR/redis.crt" \
    -days 365 -sha256

# Clean up CSR
rm "$CERT_DIR/redis.csr"

echo -e "${GREEN}[OK]${NC} Redis server certificate generated"
echo "      Key: $CERT_DIR/redis.key"
echo "      Cert: $CERT_DIR/redis.crt"
echo ""

################################################################################
# Generate Client Certificate
################################################################################

echo -e "${YELLOW}[3/4]${NC} Generating client certificate..."

# Generate client private key (RSA 2048 - FIPS approved)
# Use OPENSSL_CONF=/dev/null to bypass wolfProvider decoder incompatibility
OPENSSL_CONF=/dev/null openssl genrsa -out "$CERT_DIR/client.key" 2048

# Generate client CSR
OPENSSL_CONF=/dev/null openssl req -new -key "$CERT_DIR/client.key" \
    -out "$CERT_DIR/client.csr" \
    -subj "/C=US/ST=Demo/L=Demo/O=Redis Exporter FIPS Demo/OU=Client/CN=client"

# Sign client certificate with CA (SHA-256 - FIPS approved)
OPENSSL_CONF=/dev/null openssl x509 -req -in "$CERT_DIR/client.csr" \
    -CA "$CERT_DIR/ca.crt" -CAkey "$CERT_DIR/ca.key" \
    -CAcreateserial -out "$CERT_DIR/client.crt" \
    -days 365 -sha256

# Clean up CSR
rm "$CERT_DIR/client.csr"

echo -e "${GREEN}[OK]${NC} Client certificate generated"
echo "      Key: $CERT_DIR/client.key"
echo "      Cert: $CERT_DIR/client.crt"
echo ""

################################################################################
# Generate Exporter Certificate
################################################################################

echo -e "${YELLOW}[4/4]${NC} Generating exporter certificate..."

# Generate exporter private key (RSA 2048 - FIPS approved)
# Use OPENSSL_CONF=/dev/null to bypass wolfProvider decoder incompatibility
OPENSSL_CONF=/dev/null openssl genrsa -out "$CERT_DIR/exporter.key" 2048

# Generate exporter CSR
OPENSSL_CONF=/dev/null openssl req -new -key "$CERT_DIR/exporter.key" \
    -out "$CERT_DIR/exporter.csr" \
    -subj "/C=US/ST=Demo/L=Demo/O=Redis Exporter FIPS Demo/OU=Exporter/CN=exporter"

# Sign exporter certificate with CA (SHA-256 - FIPS approved)
OPENSSL_CONF=/dev/null openssl x509 -req -in "$CERT_DIR/exporter.csr" \
    -CA "$CERT_DIR/ca.crt" -CAkey "$CERT_DIR/ca.key" \
    -CAcreateserial -out "$CERT_DIR/exporter.crt" \
    -days 365 -sha256

# Clean up CSR
rm "$CERT_DIR/exporter.csr"

echo -e "${GREEN}[OK]${NC} Exporter certificate generated"
echo "      Key: $CERT_DIR/exporter.key"
echo "      Cert: $CERT_DIR/exporter.crt"
echo ""

################################################################################
# Set Permissions
################################################################################

echo -e "${YELLOW}Setting permissions...${NC}"

chmod 600 "$CERT_DIR"/*.key
chmod 644 "$CERT_DIR"/*.crt

echo -e "${GREEN}[OK]${NC} Permissions set"
echo ""

################################################################################
# Verification
################################################################################

echo -e "${YELLOW}Verifying certificates...${NC}"

# Verify server certificate
if OPENSSL_CONF=/dev/null openssl verify -CAfile "$CERT_DIR/ca.crt" "$CERT_DIR/redis.crt" >/dev/null 2>&1; then
    echo -e "${GREEN}[OK]${NC} Redis server certificate valid"
else
    echo -e "${RED}[FAIL]${NC} Redis server certificate invalid"
fi

# Verify client certificate
if OPENSSL_CONF=/dev/null openssl verify -CAfile "$CERT_DIR/ca.crt" "$CERT_DIR/client.crt" >/dev/null 2>&1; then
    echo -e "${GREEN}[OK]${NC} Client certificate valid"
else
    echo -e "${RED}[FAIL]${NC} Client certificate invalid"
fi

# Verify exporter certificate
if OPENSSL_CONF=/dev/null openssl verify -CAfile "$CERT_DIR/ca.crt" "$CERT_DIR/exporter.crt" >/dev/null 2>&1; then
    echo -e "${GREEN}[OK]${NC} Exporter certificate valid"
else
    echo -e "${RED}[FAIL]${NC} Exporter certificate invalid"
fi

echo ""

################################################################################
# Certificate Information
################################################################################

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Certificate Information${NC}"
echo -e "${BLUE}========================================${NC}"

echo ""
echo "CA Certificate:"
OPENSSL_CONF=/dev/null openssl x509 -in "$CERT_DIR/ca.crt" -noout -subject -issuer -dates -ext basicConstraints

echo ""
echo "Redis Server Certificate:"
OPENSSL_CONF=/dev/null openssl x509 -in "$CERT_DIR/redis.crt" -noout -subject -issuer -dates

echo ""
echo "Client Certificate:"
OPENSSL_CONF=/dev/null openssl x509 -in "$CERT_DIR/client.crt" -noout -subject -issuer -dates

echo ""
echo "Exporter Certificate:"
OPENSSL_CONF=/dev/null openssl x509 -in "$CERT_DIR/exporter.crt" -noout -subject -issuer -dates

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}TLS Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Certificates are located in: $CERT_DIR"
echo ""
echo "To use TLS with Redis:"
echo "  tls-port 6380"
echo "  tls-cert-file $CERT_DIR/redis.crt"
echo "  tls-key-file $CERT_DIR/redis.key"
echo "  tls-ca-cert-file $CERT_DIR/ca.crt"
echo ""
echo "To connect with redis-cli:"
echo "  redis-cli --tls --cert $CERT_DIR/client.crt --key $CERT_DIR/client.key --cacert $CERT_DIR/ca.crt"
echo ""
