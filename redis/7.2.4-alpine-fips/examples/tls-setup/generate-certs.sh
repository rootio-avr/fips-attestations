#!/bin/bash
################################################################################
# Redis FIPS TLS Certificate Generation Script
# Generates FIPS-compliant TLS certificates for Redis
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
CERTS_DIR="./certs"
DAYS_VALID=365
COUNTRY="US"
STATE="California"
CITY="San Francisco"
ORG="YourOrganization"
OU="Engineering"
CN_CA="Redis FIPS Root CA"
CN_SERVER="redis-fips.local"

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Redis FIPS TLS Certificate Generator${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Check OpenSSL availability
if ! command -v openssl &> /dev/null; then
    echo -e "${RED}ERROR: OpenSSL not found${NC}"
    exit 1
fi

echo -e "${YELLOW}Using OpenSSL: $(openssl version)${NC}"
echo ""

# Create certificates directory
mkdir -p "$CERTS_DIR"
cd "$CERTS_DIR"

# Step 1: Generate CA Private Key (RSA 4096 for FIPS)
echo -e "${BLUE}[1/6]${NC} Generating CA private key..."
openssl genrsa -out ca-key.pem 4096
echo -e "${GREEN}✓${NC} CA private key generated: ca-key.pem"
echo ""

# Step 2: Generate CA Certificate
echo -e "${BLUE}[2/6]${NC} Generating CA certificate..."
openssl req -new -x509 -days $DAYS_VALID -key ca-key.pem -sha256 \
    -out ca-cert.pem \
    -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORG/OU=$OU/CN=$CN_CA"
echo -e "${GREEN}✓${NC} CA certificate generated: ca-cert.pem"
echo ""

# Step 3: Generate Server Private Key (RSA 4096 for FIPS)
echo -e "${BLUE}[3/6]${NC} Generating server private key..."
openssl genrsa -out redis-key.pem 4096
echo -e "${GREEN}✓${NC} Server private key generated: redis-key.pem"
echo ""

# Step 4: Generate Server Certificate Signing Request
echo -e "${BLUE}[4/6]${NC} Generating server CSR..."
openssl req -new -key redis-key.pem -sha256 \
    -out redis-csr.pem \
    -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORG/OU=$OU/CN=$CN_SERVER"
echo -e "${GREEN}✓${NC} Server CSR generated: redis-csr.pem"
echo ""

# Step 5: Create extensions file for SAN
echo -e "${BLUE}[5/6]${NC} Creating certificate extensions..."
cat > extfile.cnf <<EOF
subjectAltName = DNS:redis-fips.local,DNS:localhost,IP:127.0.0.1,IP:::1
extendedKeyUsage = serverAuth
EOF
echo -e "${GREEN}✓${NC} Extensions file created: extfile.cnf"
echo ""

# Step 6: Sign Server Certificate with CA
echo -e "${BLUE}[6/6]${NC} Signing server certificate..."
openssl x509 -req -days $DAYS_VALID -sha256 \
    -in redis-csr.pem \
    -CA ca-cert.pem \
    -CAkey ca-key.pem \
    -CAcreateserial \
    -out redis-cert.pem \
    -extfile extfile.cnf
echo -e "${GREEN}✓${NC} Server certificate signed: redis-cert.pem"
echo ""

# Generate DH parameters (optional, for stronger security)
echo -e "${BLUE}[OPTIONAL]${NC} Generating DH parameters (this may take a while)..."
openssl dhparam -out dh2048.pem 2048
echo -e "${GREEN}✓${NC} DH parameters generated: dh2048.pem"
echo ""

# Set secure permissions
chmod 600 ca-key.pem redis-key.pem
chmod 644 ca-cert.pem redis-cert.pem

# Cleanup intermediate files
rm -f redis-csr.pem extfile.cnf ca-cert.srl

# Display summary
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Certificate Generation Complete${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo "Generated files in $CERTS_DIR/:"
echo "  ca-cert.pem      - CA certificate (public)"
echo "  ca-key.pem       - CA private key (secret)"
echo "  redis-cert.pem   - Server certificate (public)"
echo "  redis-key.pem    - Server private key (secret)"
echo "  dh2048.pem       - DH parameters (optional)"
echo ""
echo -e "${YELLOW}IMPORTANT:${NC}"
echo "  - Keep ca-key.pem and redis-key.pem secure"
echo "  - Distribute ca-cert.pem to clients for verification"
echo "  - Certificate valid for $DAYS_VALID days"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Review redis-tls.conf"
echo "  2. Update docker-compose-tls.yml with correct paths"
echo "  3. Start Redis with TLS: docker-compose -f docker-compose-tls.yml up -d"
echo ""

# Verify certificates
echo -e "${BLUE}Verifying certificates...${NC}"
openssl verify -CAfile ca-cert.pem redis-cert.pem
echo ""

# Display certificate details
echo -e "${BLUE}Certificate details:${NC}"
openssl x509 -in redis-cert.pem -noout -subject -issuer -dates
echo ""

echo -e "${GREEN}✓ All done!${NC}"
