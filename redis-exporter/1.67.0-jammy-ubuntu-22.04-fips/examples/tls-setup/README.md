# TLS Setup Examples

This directory contains scripts and examples for setting up FIPS-compliant TLS connections between Redis and redis_exporter.

## FIPS-Approved Algorithms

All certificates generated use FIPS 140-3 approved algorithms:

- **Key Algorithm:** RSA 2048/4096 bits
- **Signature Algorithm:** SHA-256
- **TLS Versions:** TLS 1.2, TLS 1.3
- **Cipher Suites:** AES-GCM only

## Quick Start

```bash
# Generate all certificates
./generate-certs.sh

# Certificates will be in ./certs/
ls -la certs/
```

## Generated Certificates

| File | Description | Algorithm |
|------|-------------|-----------|
| `ca.crt` | CA certificate | RSA-4096, SHA-256 |
| `ca.key` | CA private key | RSA-4096 |
| `redis.crt` | Redis server certificate | RSA-2048, SHA-256 |
| `redis.key` | Redis server private key | RSA-2048 |
| `client.crt` | Client certificate | RSA-2048, SHA-256 |
| `client.key` | Client private key | RSA-2048 |
| `dhparam.pem` | DH parameters | 2048-bit |

## Usage Examples

### 1. Redis Server with TLS

```bash
redis-server \
  --tls-port 6380 \
  --port 0 \
  --tls-cert-file ./certs/redis.crt \
  --tls-key-file ./certs/redis.key \
  --tls-ca-cert-file ./certs/ca.crt \
  --tls-auth-clients yes \
  --tls-protocols "TLSv1.2 TLSv1.3" \
  --tls-ciphers "ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256" \
  --tls-ciphersuites "TLS_AES_256_GCM_SHA384:TLS_AES_128_GCM_SHA256"
```

### 2. redis_exporter with TLS

```bash
docker run -d \
  -v $(pwd)/certs:/certs:ro \
  -p 9121:9121 \
  cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips \
  --redis.addr=rediss://redis:6380 \
  --tls-client-cert-file=/certs/client.crt \
  --tls-client-key-file=/certs/client.key \
  --tls-ca-cert-file=/certs/ca.crt
```

### 3. Docker Compose with TLS

```yaml
version: '3.8'

services:
  redis:
    image: redis:7.2-alpine
    command: >
      redis-server
      --tls-port 6380
      --port 0
      --tls-cert-file /certs/redis.crt
      --tls-key-file /certs/redis.key
      --tls-ca-cert-file /certs/ca.crt
      --tls-auth-clients yes
    volumes:
      - ./certs:/certs:ro

  redis-exporter:
    image: cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips
    command:
      - --redis.addr=rediss://redis:6380
      - --tls-client-cert-file=/certs/client.crt
      - --tls-client-key-file=/certs/client.key
      - --tls-ca-cert-file=/certs/ca.crt
    volumes:
      - ./certs:/certs:ro
    ports:
      - "9121:9121"
```

### 4. Kubernetes with TLS

```bash
# Create secret from certificates
kubectl create secret generic redis-tls \
  --from-file=ca.crt=certs/ca.crt \
  --from-file=tls.crt=certs/client.crt \
  --from-file=tls.key=certs/client.key \
  -n monitoring

# Mount in deployment
spec:
  containers:
  - name: redis-exporter
    volumeMounts:
    - name: tls-certs
      mountPath: /certs
      readOnly: true
    args:
    - --redis.addr=rediss://redis:6380
    - --tls-client-cert-file=/certs/tls.crt
    - --tls-client-key-file=/certs/tls.key
    - --tls-ca-cert-file=/certs/ca.crt
  volumes:
  - name: tls-certs
    secret:
      secretName: redis-tls
```

## Verification

### Verify Certificate Chain

```bash
# Verify server certificate
openssl verify -CAfile certs/ca.crt certs/redis.crt

# Verify client certificate
openssl verify -CAfile certs/ca.crt certs/client.crt
```

### Test TLS Connection

```bash
# Test with redis-cli
redis-cli --tls \
  --cert certs/client.crt \
  --key certs/client.key \
  --cacert certs/ca.crt \
  -h localhost -p 6380 \
  ping

# Test with openssl
openssl s_client -connect localhost:6380 \
  -cert certs/client.crt \
  -key certs/client.key \
  -CAfile certs/ca.crt \
  -tls1_2 \
  -cipher 'ECDHE-RSA-AES256-GCM-SHA384'
```

### Verify FIPS Cipher Suites

```bash
# Show negotiated cipher
openssl s_client -connect localhost:6380 \
  -cert certs/client.crt \
  -key certs/client.key \
  -CAfile certs/ca.crt \
  -tls1_2 2>&1 | grep -i cipher
```

Expected output should show FIPS-approved cipher like:
- `ECDHE-RSA-AES256-GCM-SHA384`
- `ECDHE-RSA-AES128-GCM-SHA256`

## Customization

### Change Validity Period

```bash
DAYS_VALID=730 ./generate-certs.sh  # 2 years
```

### Change Key Size

Edit `generate-certs.sh`:

```bash
# Use RSA-4096 for server cert instead of RSA-2048
openssl genrsa -out "$CERT_DIR/redis.key" 4096
```

### Add Custom SANs

Edit the SAN section in `generate-certs.sh`:

```bash
cat > "$CERT_DIR/redis-san.cnf" << EOF
subjectAltName = @alt_names

[alt_names]
DNS.1 = redis
DNS.2 = redis.example.com
DNS.3 = *.redis.svc.cluster.local
IP.1 = 127.0.0.1
IP.2 = 10.0.0.1
EOF
```

## Security Best Practices

1. **Protect Private Keys**
   - Never commit private keys to version control
   - Use restrictive permissions (600)
   - Store in secure location (secrets management)

2. **Certificate Rotation**
   - Rotate certificates before expiration
   - Implement automated rotation process
   - Monitor certificate expiration

3. **Cipher Suite Selection**
   - Use only FIPS-approved cipher suites
   - Disable weak ciphers
   - Keep TLS libraries updated

4. **Certificate Validation**
   - Always validate certificate chain
   - Verify hostname/IP matches
   - Check certificate revocation (CRL/OCSP)
