#!/bin/bash
################################################################################
# FIPS-Compliant TLS Certificate Generation Script
#
# Generates TLS certificates using FIPS-approved algorithms:
# - RSA 2048/4096 bit keys
# - SHA-256/384 signatures
#
# Usage: ./generate-certs.sh [OPTIONS]
################################################################################

set -e

# Configuration
CERT_DIR="${CERT_DIR:-./certs}"
DAYS_VALID="${DAYS_VALID:-365}"
COUNTRY="${COUNTRY:-US}"
STATE="${STATE:-Demo}"
CITY="${CITY:-Demo}"
ORG="${ORG:-Redis Exporter FIPS}"

# Create certificate directory
mkdir -p "$CERT_DIR"

echo "Generating FIPS-compliant TLS certificates..."
echo "Certificate directory: $CERT_DIR"
echo ""

################################################################################
# 1. Generate CA Certificate
################################################################################

echo "[1/4] Generating CA certificate (RSA 4096, SHA-256)..."

# Generate CA private key
openssl genrsa -out "$CERT_DIR/ca.key" 4096 2>/dev/null

# Generate CA certificate
openssl req -new -x509 \
    -days $((DAYS_VALID * 10)) \
    -key "$CERT_DIR/ca.key" \
    -sha256 \
    -out "$CERT_DIR/ca.crt" \
    -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORG/OU=CA/CN=Redis CA" \
    2>/dev/null

echo "✓ CA certificate generated"
echo "  Private key: $CERT_DIR/ca.key"
echo "  Certificate: $CERT_DIR/ca.crt"
echo ""

################################################################################
# 2. Generate Redis Server Certificate
################################################################################

echo "[2/4] Generating Redis server certificate (RSA 2048, SHA-256)..."

# Generate server private key
openssl genrsa -out "$CERT_DIR/redis.key" 2048 2>/dev/null

# Generate server CSR
openssl req -new \
    -key "$CERT_DIR/redis.key" \
    -out "$CERT_DIR/redis.csr" \
    -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORG/OU=Server/CN=redis" \
    2>/dev/null

# Create SAN extension file
cat > "$CERT_DIR/redis-san.cnf" << EOF
subjectAltName = @alt_names

[alt_names]
DNS.1 = redis
DNS.2 = localhost
DNS.3 = *.redis.svc.cluster.local
IP.1 = 127.0.0.1
EOF

# Sign server certificate
openssl x509 -req \
    -in "$CERT_DIR/redis.csr" \
    -CA "$CERT_DIR/ca.crt" \
    -CAkey "$CERT_DIR/ca.key" \
    -CAcreateserial \
    -out "$CERT_DIR/redis.crt" \
    -days $DAYS_VALID \
    -sha256 \
    -extfile "$CERT_DIR/redis-san.cnf" \
    2>/dev/null

# Cleanup
rm "$CERT_DIR/redis.csr" "$CERT_DIR/redis-san.cnf"

echo "✓ Redis server certificate generated"
echo "  Private key: $CERT_DIR/redis.key"
echo "  Certificate: $CERT_DIR/redis.crt"
echo ""

################################################################################
# 3. Generate Client Certificate
################################################################################

echo "[3/4] Generating client certificate (RSA 2048, SHA-256)..."

# Generate client private key
openssl genrsa -out "$CERT_DIR/client.key" 2048 2>/dev/null

# Generate client CSR
openssl req -new \
    -key "$CERT_DIR/client.key" \
    -out "$CERT_DIR/client.csr" \
    -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORG/OU=Client/CN=redis-exporter" \
    2>/dev/null

# Sign client certificate
openssl x509 -req \
    -in "$CERT_DIR/client.csr" \
    -CA "$CERT_DIR/ca.crt" \
    -CAkey "$CERT_DIR/ca.key" \
    -CAcreateserial \
    -out "$CERT_DIR/client.crt" \
    -days $DAYS_VALID \
    -sha256 \
    2>/dev/null

# Cleanup
rm "$CERT_DIR/client.csr"

echo "✓ Client certificate generated"
echo "  Private key: $CERT_DIR/client.key"
echo "  Certificate: $CERT_DIR/client.crt"
echo ""

################################################################################
# 4. Generate DH Parameters (Optional)
################################################################################

echo "[4/4] Generating DH parameters (2048 bit) - this may take a few minutes..."

openssl dhparam -out "$CERT_DIR/dhparam.pem" 2048 2>/dev/null

echo "✓ DH parameters generated"
echo "  File: $CERT_DIR/dhparam.pem"
echo ""

################################################################################
# Set Permissions
################################################################################

chmod 600 "$CERT_DIR"/*.key
chmod 644 "$CERT_DIR"/*.crt "$CERT_DIR"/*.pem

################################################################################
# Verification
################################################################################

echo "Verifying certificates..."

# Verify server certificate
if openssl verify -CAfile "$CERT_DIR/ca.crt" "$CERT_DIR/redis.crt" >/dev/null 2>&1; then
    echo "✓ Redis server certificate valid"
else
    echo "✗ Redis server certificate validation failed"
    exit 1
fi

# Verify client certificate
if openssl verify -CAfile "$CERT_DIR/ca.crt" "$CERT_DIR/client.crt" >/dev/null 2>&1; then
    echo "✓ Client certificate valid"
else
    echo "✗ Client certificate validation failed"
    exit 1
fi

echo ""

################################################################################
# Summary
################################################################################

echo "==================================="
echo "Certificate generation complete!"
echo "==================================="
echo ""
echo "Files generated in: $CERT_DIR/"
echo ""
echo "Usage examples:"
echo ""
echo "1. Redis Server with TLS:"
echo "   redis-server \\"
echo "     --tls-port 6380 \\"
echo "     --port 0 \\"
echo "     --tls-cert-file $CERT_DIR/redis.crt \\"
echo "     --tls-key-file $CERT_DIR/redis.key \\"
echo "     --tls-ca-cert-file $CERT_DIR/ca.crt \\"
echo "     --tls-auth-clients yes"
echo ""
echo "2. redis-cli with TLS:"
echo "   redis-cli \\"
echo "     --tls \\"
echo "     --cert $CERT_DIR/client.crt \\"
echo "     --key $CERT_DIR/client.key \\"
echo "     --cacert $CERT_DIR/ca.crt \\"
echo "     -h localhost -p 6380"
echo ""
echo "3. redis_exporter with TLS:"
echo "   redis_exporter \\"
echo "     --redis.addr=rediss://redis:6380 \\"
echo "     --tls-client-cert-file=$CERT_DIR/client.crt \\"
echo "     --tls-client-key-file=$CERT_DIR/client.key \\"
echo "     --tls-ca-cert-file=$CERT_DIR/ca.crt"
echo ""
