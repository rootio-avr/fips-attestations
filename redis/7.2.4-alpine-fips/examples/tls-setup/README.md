# TLS/SSL Setup for Redis FIPS

This directory contains everything needed to run Redis FIPS with TLS/SSL encryption.

## Quick Start

```bash
# 1. Generate TLS certificates
chmod +x generate-certs.sh
./generate-certs.sh

# 2. Update password in redis-tls.conf
sed -i 's/changeme_strong_password_here/YOUR_STRONG_PASSWORD/' redis-tls.conf

# 3. Start Redis with TLS
docker-compose -f docker-compose-tls.yml up -d

# 4. Test TLS connection
docker-compose -f docker-compose-tls.yml exec redis-fips-tls \
  redis-cli --tls \
  --cert /certs/redis-cert.pem \
  --key /certs/redis-key.pem \
  --cacert /certs/ca-cert.pem \
  -a YOUR_STRONG_PASSWORD \
  PING
```

## Certificate Generation

The `generate-certs.sh` script creates FIPS-compliant certificates:

### Generated Files

```
certs/
├── ca-cert.pem      # CA certificate (distribute to clients)
├── ca-key.pem       # CA private key (keep secure!)
├── redis-cert.pem   # Server certificate
├── redis-key.pem    # Server private key (keep secure!)
└── dh2048.pem       # Diffie-Hellman parameters
```

### Certificate Details

- **Algorithm**: RSA 4096-bit (FIPS-approved)
- **Signature**: SHA-256 (FIPS-approved)
- **Validity**: 365 days (configurable)
- **SAN**: redis-fips.local, localhost, 127.0.0.1, ::1

### Customization

Edit variables in `generate-certs.sh`:

```bash
DAYS_VALID=365          # Certificate validity period
COUNTRY="US"            # Country code
STATE="California"      # State/Province
CITY="San Francisco"    # City
ORG="YourOrganization"  # Organization name
CN_SERVER="redis-fips.local"  # Server common name
```

## TLS Configuration

### TLS Options Explained

**redis-tls.conf** key settings:

```conf
# Disable plain TCP, enable TLS only
port 0
tls-port 6379

# Certificate files
tls-cert-file /certs/redis-cert.pem
tls-key-file /certs/redis-key.pem
tls-ca-cert-file /certs/ca-cert.pem

# Require client certificates (mutual TLS)
tls-auth-clients yes

# TLS protocol versions (only secure versions)
tls-protocols "TLSv1.2 TLSv1.3"

# FIPS-approved cipher suites
tls-ciphers "ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256"
tls-ciphersuites "TLS_AES_256_GCM_SHA384:TLS_AES_128_GCM_SHA256"
```

### Cipher Suites

FIPS-approved ciphers:

| Cipher Suite | TLS Version | Security Level |
|-------------|-------------|----------------|
| TLS_AES_256_GCM_SHA384 | TLSv1.3 | High |
| TLS_AES_128_GCM_SHA256 | TLSv1.3 | High |
| ECDHE-RSA-AES256-GCM-SHA384 | TLSv1.2 | High |
| ECDHE-RSA-AES128-GCM-SHA256 | TLSv1.2 | High |

## Client Connection

### redis-cli (TLS)

```bash
# Basic connection
redis-cli --tls \
  --cert /path/to/redis-cert.pem \
  --key /path/to/redis-key.pem \
  --cacert /path/to/ca-cert.pem \
  -a PASSWORD \
  PING

# Without client certificate verification (if tls-auth-clients is no)
redis-cli --tls \
  --cacert /path/to/ca-cert.pem \
  -a PASSWORD \
  PING

# Interactive mode
redis-cli --tls \
  --cert /path/to/redis-cert.pem \
  --key /path/to/redis-key.pem \
  --cacert /path/to/ca-cert.pem \
  -a PASSWORD
```

### Application Clients

#### Python (redis-py)

```python
import redis
import ssl

# Create SSL context
ssl_context = ssl.create_default_context(
    ssl.Purpose.SERVER_AUTH,
    cafile='/path/to/ca-cert.pem'
)
ssl_context.load_cert_chain(
    certfile='/path/to/redis-cert.pem',
    keyfile='/path/to/redis-key.pem'
)

# Connect to Redis
r = redis.Redis(
    host='redis-fips.local',
    port=6379,
    password='YOUR_PASSWORD',
    ssl=True,
    ssl_context=ssl_context
)

# Test connection
print(r.ping())
```

#### Node.js (ioredis)

```javascript
const Redis = require('ioredis');
const fs = require('fs');

const redis = new Redis({
  host: 'redis-fips.local',
  port: 6379,
  password: 'YOUR_PASSWORD',
  tls: {
    ca: [fs.readFileSync('/path/to/ca-cert.pem')],
    cert: fs.readFileSync('/path/to/redis-cert.pem'),
    key: fs.readFileSync('/path/to/redis-key.pem'),
  }
});

redis.ping().then(result => {
  console.log(result); // "PONG"
});
```

#### Java (Jedis)

```java
import redis.clients.jedis.Jedis;
import redis.clients.jedis.DefaultJedisClientConfig;
import javax.net.ssl.*;
import java.io.FileInputStream;
import java.security.KeyStore;

// Load keystore
KeyStore keyStore = KeyStore.getInstance("JKS");
keyStore.load(new FileInputStream("/path/to/keystore.jks"), "password".toCharArray());

// Setup SSL
SSLContext sslContext = SSLContext.getInstance("TLS");
KeyManagerFactory kmf = KeyManagerFactory.getInstance("SunX509");
kmf.init(keyStore, "password".toCharArray());
TrustManagerFactory tmf = TrustManagerFactory.getInstance("SunX509");
tmf.init(keyStore);
sslContext.init(kmf.getKeyManagers(), tmf.getTrustManagers(), null);

// Connect
DefaultJedisClientConfig config = DefaultJedisClientConfig.builder()
    .password("YOUR_PASSWORD")
    .ssl(true)
    .sslSocketFactory(sslContext.getSocketFactory())
    .build();

Jedis jedis = new Jedis("redis-fips.local", 6379, config);
System.out.println(jedis.ping()); // "PONG"
```

#### Go (go-redis)

```go
package main

import (
    "crypto/tls"
    "crypto/x509"
    "io/ioutil"
    "github.com/go-redis/redis/v8"
    "context"
)

func main() {
    // Load CA cert
    caCert, _ := ioutil.ReadFile("/path/to/ca-cert.pem")
    caCertPool := x509.NewCertPool()
    caCertPool.AppendCertsFromPEM(caCert)

    // Load client cert
    cert, _ := tls.LoadX509KeyPair(
        "/path/to/redis-cert.pem",
        "/path/to/redis-key.pem",
    )

    // TLS config
    tlsConfig := &tls.Config{
        RootCAs:      caCertPool,
        Certificates: []tls.Certificate{cert},
    }

    // Connect
    rdb := redis.NewClient(&redis.Options{
        Addr:      "redis-fips.local:6379",
        Password:  "YOUR_PASSWORD",
        TLSConfig: tlsConfig,
    })

    ctx := context.Background()
    pong, _ := rdb.Ping(ctx).Result()
    println(pong) // "PONG"
}
```

## Testing TLS

### Verify TLS Connection

```bash
# Check which protocols are enabled
openssl s_client -connect localhost:6379 \
  -cert certs/redis-cert.pem \
  -key certs/redis-key.pem \
  -CAfile certs/ca-cert.pem \
  -tls1_2

# Check TLSv1.3
openssl s_client -connect localhost:6379 \
  -cert certs/redis-cert.pem \
  -key certs/redis-key.pem \
  -CAfile certs/ca-cert.pem \
  -tls1_3
```

### Test with Client Container

Start the test client:

```bash
docker-compose -f docker-compose-tls.yml --profile client up -d redis-client-tls
```

Run commands:

```bash
# Get shell in client container
docker exec -it redis-client-tls sh

# Test connection
redis-cli --tls \
  --cert /certs/redis-cert.pem \
  --key /certs/redis-key.pem \
  --cacert /certs/ca-cert.pem \
  -h redis-fips-tls \
  -a YOUR_PASSWORD \
  PING
```

## Security Best Practices

### Certificate Management

1. **Private Keys**
   - Keep `ca-key.pem` and `redis-key.pem` secure
   - Use file permissions: `chmod 600 *.key.pem`
   - Never commit to version control

2. **Certificate Rotation**
   - Plan certificate renewal before expiry
   - Generate new certs with same CA
   - Update Redis config and restart

3. **CA Distribution**
   - Only distribute `ca-cert.pem` to clients
   - Use secure channels for distribution
   - Consider using enterprise PKI

### TLS Configuration

1. **Protocol Versions**
   ```conf
   # Only allow TLS 1.2 and 1.3
   tls-protocols "TLSv1.2 TLSv1.3"
   ```

2. **Mutual TLS (mTLS)**
   ```conf
   # Require client certificates
   tls-auth-clients yes
   ```

3. **Cipher Suites**
   ```conf
   # Use only FIPS-approved ciphers
   tls-ciphers "ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256"
   ```

### Monitoring

Monitor TLS connections:

```bash
# Check connected clients
docker exec redis-fips-tls redis-cli \
  --tls --cert /certs/redis-cert.pem \
  --key /certs/redis-key.pem \
  --cacert /certs/ca-cert.pem \
  -a PASSWORD \
  CLIENT LIST

# Monitor TLS handshake errors (check logs)
docker logs redis-fips-tls | grep -i tls
```

## Troubleshooting

### Common Issues

#### Certificate Verification Failed

```
Error: SSL_connect: error:1416F086:SSL routines:tls_process_server_certificate:certificate verify failed
```

**Solution:**
- Ensure CA certificate is correct
- Check certificate hasn't expired: `openssl x509 -in certs/redis-cert.pem -noout -dates`
- Verify hostname matches CN/SAN: `openssl x509 -in certs/redis-cert.pem -noout -text | grep -A1 "Subject Alternative Name"`

#### Private Key Permission Denied

```
Error: Can't open /certs/redis-key.pem: Permission denied
```

**Solution:**
```bash
chmod 644 certs/redis-key.pem  # For Docker volume mount
# Or in Dockerfile: COPY --chmod=644 certs/redis-key.pem /certs/
```

#### TLS Handshake Timeout

**Solution:**
- Check firewall rules allow port 6379
- Verify TLS port is configured: `tls-port 6379`
- Check client and server TLS versions match

#### Protocol Version Mismatch

```
Error: unsupported protocol
```

**Solution:**
- Client trying SSLv3/TLSv1.0/TLSv1.1 (not supported)
- Update client to use TLSv1.2 or TLSv1.3
- Check `tls-protocols` configuration

### Debugging Commands

```bash
# Verify certificates
openssl verify -CAfile certs/ca-cert.pem certs/redis-cert.pem

# Check certificate details
openssl x509 -in certs/redis-cert.pem -noout -text

# Test TLS connection (verbose)
openssl s_client -connect localhost:6379 \
  -cert certs/redis-cert.pem \
  -key certs/redis-key.pem \
  -CAfile certs/ca-cert.pem \
  -showcerts

# Check Redis TLS configuration
docker exec redis-fips-tls redis-cli \
  --tls --cert /certs/redis-cert.pem \
  --key /certs/redis-key.pem \
  --cacert /certs/ca-cert.pem \
  -a PASSWORD \
  CONFIG GET tls-*
```

## Production Deployment

### Kubernetes

For Kubernetes TLS deployment:

1. Create TLS secret:
```bash
kubectl create secret generic redis-tls-certs \
  --from-file=ca-cert.pem=certs/ca-cert.pem \
  --from-file=redis-cert.pem=certs/redis-cert.pem \
  --from-file=redis-key.pem=certs/redis-key.pem \
  --from-file=dh2048.pem=certs/dh2048.pem
```

2. Mount in StatefulSet:
```yaml
volumeMounts:
- name: tls-certs
  mountPath: /certs
  readOnly: true
volumes:
- name: tls-certs
  secret:
    secretName: redis-tls-certs
    defaultMode: 0440
```

### Certificate Renewal

Before certificates expire:

```bash
# 1. Check expiry
openssl x509 -in certs/redis-cert.pem -noout -enddate

# 2. Generate new certificates (keep same CA)
./generate-certs.sh

# 3. Reload Redis (zero downtime)
docker exec redis-fips-tls redis-cli \
  --tls --cert /certs/redis-cert.pem \
  --key /certs/redis-key.pem \
  --cacert /certs/ca-cert.pem \
  -a PASSWORD \
  CONFIG SET tls-cert-file /certs/redis-cert.pem

# 4. Restart container
docker-compose -f docker-compose-tls.yml restart redis-fips-tls
```

## References

- [Redis TLS Documentation](https://redis.io/docs/management/security/encryption/)
- [FIPS 140-3 Compliance](../../ATTESTATION.md)
- [OpenSSL FIPS Module](https://www.openssl.org/docs/fips.html)
- [TLS Best Practices](https://wiki.mozilla.org/Security/Server_Side_TLS)
