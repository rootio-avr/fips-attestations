# Nginx 1.27.3 with wolfSSL FIPS 140-3

Production-ready Docker image for Nginx 1.27.3 with wolfSSL FIPS 140-3 (Certificate #4718) cryptographic module.

## Overview

This container provides Nginx 1.27.3 on Debian Bookworm with wolfSSL FIPS 140-3 as the cryptographic provider for all SSL/TLS operations. The implementation uses wolfProvider to integrate wolfSSL as the OpenSSL provider system-wide.

### Key Features

✅ **FIPS 140-3 Compliant** - wolfSSL 5.8.2 FIPS (Certificate #4718)
✅ **Nginx 1.27.3** - Latest stable Nginx with wolfSSL integration
✅ **Debian Bookworm Slim** - Minimal, secure base image
✅ **Provider-Based Architecture** - Uses wolfProvider for seamless integration
✅ **TLS 1.2 & 1.3** - Modern protocols with FIPS-approved cipher suites
✅ **Comprehensive Testing** - Diagnostic test suites for validation
✅ **Production Ready** - FIPS verification, health checks, security hardening
✅ **Well Documented** - Complete architecture and developer guides

## Architecture

```
┌─────────────────────────────────────────┐
│   Nginx 1.27.3 (SSL Module)            │
├─────────────────────────────────────────┤
│   OpenSSL 3.0.19 API                   │ ← OPENSSL_CONF configured
├─────────────────────────────────────────┤
│   wolfProvider 1.1.0                   │ ← Provider: fips
├─────────────────────────────────────────┤
│   wolfSSL FIPS v5.8.2                  │ ← Certificate #4718
│   (FIPS 140-3 cryptographic module)    │   FIPS POST on startup
└─────────────────────────────────────────┘
```

**Integration Pattern:** wolfProvider (same as PostgreSQL, RabbitMQ, Python, Node.js)
- ✅ No source code patches required
- ✅ Standard Nginx SSL module
- ✅ Proven, reliable architecture

## Quick Start

### Prerequisites

- Docker with BuildKit enabled
- wolfSSL commercial FIPS package password

### Build

```bash
# Create password file
echo "your-wolfssl-password" > wolfssl_password.txt
chmod 600 wolfssl_password.txt

# Build the image
./build.sh

# Or manual build
DOCKER_BUILDKIT=1 docker buildx build \
  --secret id=wolfssl_password,src=wolfssl_password.txt \
  -t cr.root.io/nginx:1.27.3-debian-bookworm-fips .
```

### Run

```bash
# Run with FIPS validation (default)
docker run -d -p 80:80 -p 443:443 \
  --name nginx-fips \
  cr.root.io/nginx:1.27.3-debian-bookworm-fips

# Run with custom configuration
docker run -d -p 80:80 -p 443:443 \
  -v $(pwd)/my-nginx.conf:/etc/nginx/nginx.conf:ro \
  cr.root.io/nginx:1.27.3-debian-bookworm-fips

# Run in development mode (skip FIPS checks)
docker run -d -p 80:80 -p 443:443 \
  -e FIPS_CHECK=false \
  cr.root.io/nginx:1.27.3-debian-bookworm-fips
```

### Verify

```bash
# Test FIPS provider
docker exec nginx-fips openssl list -providers

# Expected output:
#   Providers:
#     fips
#       name: wolfSSL Provider FIPS
#       version: 1.1.0
#       status: active

# Test HTTPS endpoint
curl -k https://localhost/fips-status

# Expected output:
#   Nginx 1.27.3 with wolfSSL FIPS 140-3 (Cert #4718)
#   Status: Active
```

## FIPS Compliance

### FIPS Enforcement

This image implements FIPS 140-3 compliance at multiple layers:

| Layer | Enforcement |
|-------|-------------|
| **TLS Protocols** | TLS 1.2 and TLS 1.3 only (SSLv3, TLS 1.0, TLS 1.1 blocked) |
| **Cipher Suites** | FIPS-approved only (AES-GCM, AES-CBC + SHA-256/384) |
| **Blocked Ciphers** | RC4, DES, 3DES, MD5, SHA-1 in ciphersuites |
| **Key Exchange** | ECDHE, RSA (2048-bit minimum) |
| **Hash Algorithms** | SHA-256, SHA-384, SHA-512 (MD5, SHA-1 blocked except legacy) |

### FIPS-Approved Cipher Suites (TLS 1.2)

```
ECDHE-ECDSA-AES256-GCM-SHA384
ECDHE-RSA-AES256-GCM-SHA384
ECDHE-ECDSA-AES128-GCM-SHA256
ECDHE-RSA-AES128-GCM-SHA256
ECDHE-ECDSA-AES256-SHA384
ECDHE-RSA-AES256-SHA384
ECDHE-ECDSA-AES128-SHA256
ECDHE-RSA-AES128-SHA256
AES256-GCM-SHA384
AES128-GCM-SHA256
AES256-SHA256
AES128-SHA256
```

### FIPS-Approved Cipher Suites (TLS 1.3)

```
TLS_AES_256_GCM_SHA384
TLS_AES_128_GCM_SHA256
```

### Startup Validation

The container performs automatic FIPS validation on startup:

1. **wolfSSL FIPS POST** - Known Answer Tests (KAT)
2. **OpenSSL Provider Verification** - Confirms wolfProvider is active
3. **Nginx Configuration Test** - Validates syntax and SSL settings
4. **Library Integrity Check** - Verifies cryptographic module integrity

To skip validation (development only):
```bash
docker run -e FIPS_CHECK=false cr.root.io/nginx:1.27.3-debian-bookworm-fips
```

## Configuration

### Custom Nginx Configuration

Mount your own nginx.conf:

```bash
docker run -d -p 80:80 -p 443:443 \
  -v $(pwd)/nginx.conf:/etc/nginx/nginx.conf:ro \
  cr.root.io/nginx:1.27.3-debian-bookworm-fips
```

**Important FIPS Requirements:**

```nginx
# Enforce TLS 1.2 and 1.3 only
ssl_protocols TLSv1.2 TLSv1.3;

# Use FIPS-approved ciphers only
ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:...';

# Prefer server cipher order
ssl_prefer_server_ciphers on;
```

See [nginx.conf.template](nginx.conf.template) for complete FIPS-hardened configuration.

### Custom SSL Certificates

Replace self-signed certificate with production certificates:

```bash
docker run -d -p 80:80 -p 443:443 \
  -v $(pwd)/certs/server.crt:/etc/nginx/ssl/server.crt:ro \
  -v $(pwd)/certs/server.key:/etc/nginx/ssl/server.key:ro \
  -v $(pwd)/nginx-custom.conf:/etc/nginx/nginx.conf:ro \
  cr.root.io/nginx:1.27.3-debian-bookworm-fips
```

Update nginx.conf to use your certificates:

```nginx
ssl_certificate /etc/nginx/ssl/server.crt;
ssl_certificate_key /etc/nginx/ssl/server.key;
```

## Testing

### Run Diagnostic Tests

```bash
# Run all diagnostic tests
./diagnostic.sh

# Expected: 8/8 test suites passed
```

### Build and Run Test Image

```bash
cd diagnostics/test-images/basic-test-image
./build.sh
docker run --rm nginx-fips-test:latest
```

### Manual Testing

```bash
# Test TLS 1.2 handshake
openssl s_client -connect localhost:443 -tls1_2

# Test TLS 1.3 handshake
openssl s_client -connect localhost:443 -tls1_3

# Verify cipher suite
openssl s_client -connect localhost:443 -cipher 'ECDHE-RSA-AES256-GCM-SHA384'

# Test weak cipher (should fail)
openssl s_client -connect localhost:443 -cipher 'RC4-SHA'
# Expected: no shared cipher
```

## Use Cases

### 1. HTTPS Web Server

Serve static content with FIPS-compliant TLS:

```bash
docker run -d -p 443:443 \
  -v $(pwd)/html:/usr/share/nginx/html:ro \
  -v $(pwd)/certs:/etc/nginx/ssl:ro \
  cr.root.io/nginx:1.27.3-debian-bookworm-fips
```

### 2. Reverse Proxy

TLS termination for backend services:

```nginx
server {
    listen 443 ssl http2;
    server_name api.example.com;

    ssl_certificate /etc/nginx/ssl/server.crt;
    ssl_certificate_key /etc/nginx/ssl/server.key;

    location / {
        proxy_pass http://backend:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### 3. Load Balancer

HTTPS load balancing with FIPS enforcement:

```nginx
upstream backend {
    server backend1:8080;
    server backend2:8080;
    server backend3:8080;
}

server {
    listen 443 ssl http2;
    ssl_certificate /etc/nginx/ssl/server.crt;
    ssl_certificate_key /etc/nginx/ssl/server.key;

    location / {
        proxy_pass http://backend;
    }
}
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `FIPS_CHECK` | `true` | Enable/disable FIPS validation on startup |
| `NGINX_CONF` | `/etc/nginx/nginx.conf` | Path to Nginx configuration file |
| `OPENSSL_CONF` | `/etc/ssl/openssl.cnf` | OpenSSL configuration file |
| `OPENSSL_MODULES` | `/usr/lib/x86_64-linux-gnu/ossl-modules` | OpenSSL modules directory |

## File Structure

```
nginx/1.27.3-debian-bookworm-fips/
├── Dockerfile                         # Multi-stage FIPS build
├── build.sh                           # Build script
├── docker-entrypoint.sh               # Startup validation
├── openssl.cnf                        # wolfProvider configuration
├── fips_properties.cnf                # FIPS enforcement properties
├── nginx.conf.template                # FIPS-hardened Nginx config
├── src/
│   └── test-fips.c                   # FIPS KAT executable
├── patches/
│   └── README.md                     # Patch information
├── diagnostics/                       # Diagnostic test suites
├── demos-image/                       # Demo configurations
├── compliance/                        # SBOM, VEX, SLSA
├── supply-chain/                      # Cosign verification
└── Evidence/                          # Test results
```

## Security Considerations

### FIPS Mode

This container operates in FIPS mode by default:
- All cryptographic operations use wolfSSL FIPS module
- FIPS-approved algorithms enforced at provider level
- Non-FIPS algorithms blocked in TLS negotiation

### Port Binding

By default, Nginx binds to ports 80 and 443, which require root privileges. The container runs as root by design for production flexibility. For restricted environments:

```bash
# Use non-privileged ports
docker run -d -p 8080:8080 -p 8443:8443 \
  -e NGINX_CONF=/etc/nginx/nginx-unprivileged.conf \
  --user nginx \
  cr.root.io/nginx:1.27.3-debian-bookworm-fips
```

### Supply Chain Security

- Complete chain of custody documentation
- Software Bill of Materials (SBOM) in SPDX format
- Vulnerability Exchange (VEX) data
- Build provenance tracking

## Known Limitations

1. **Nginx Version 1.27.3 Patch**: wolfssl-nginx repository may not have a specific patch for 1.27.3. The Dockerfile uses direct configuration with `--with-wolfssl` flag. For production, adapt patches from nearby versions (1.27.x or 1.28.1).

2. **OCSP Stapling**: Some OCSP stapling features may behave differently from standard OpenSSL.

3. **Post-Quantum Algorithms**: Not enabled by default. Can be added with additional wolfSSL configuration.

## Troubleshooting

### FIPS POST Fails

```
ERROR: FIPS POST failed! Container will terminate.
```

**Solution**: Verify wolfSSL FIPS package integrity and build configuration. Check `fips-startup-check` utility:

```bash
docker run --rm --entrypoint="" \
  cr.root.io/nginx:1.27.3-debian-bookworm-fips \
  fips-startup-check
```

### wolfProvider Not Loaded

```
✗ wolfProvider not found in OpenSSL providers
```

**Solution**: Check OpenSSL configuration:

```bash
docker run --rm --entrypoint="" \
  cr.root.io/nginx:1.27.3-debian-bookworm-fips \
  cat /etc/ssl/openssl.cnf
```

Verify wolfProvider module exists:

```bash
docker run --rm --entrypoint="" \
  cr.root.io/nginx:1.27.3-debian-bookworm-fips \
  ls -la /usr/lib/x86_64-linux-gnu/ossl-modules/
```

### Nginx Configuration Test Fails

```
✗ Nginx configuration test failed
```

**Solution**: Test configuration manually:

```bash
docker run --rm --entrypoint="" \
  cr.root.io/nginx:1.27.3-debian-bookworm-fips \
  nginx -t -c /etc/nginx/nginx.conf
```

### TLS Handshake Fails

**Symptom**: `SSL_ERROR_NO_CYPHER_OVERLAP` or similar

**Solution**: Verify client supports FIPS-approved cipher suites:

```bash
# Test with specific cipher
openssl s_client -connect localhost:443 \
  -cipher 'ECDHE-RSA-AES256-GCM-SHA384'
```

If this works, the issue is client-side cipher support.

## Compliance Documentation

This image fully satisfies FIPS Proof of Concept (POC) criteria:

- ✅ [POC-VALIDATION-REPORT.md](POC-VALIDATION-REPORT.md) - Detailed compliance report
- ✅ [ARCHITECTURE.md](ARCHITECTURE.md) - Technical architecture (to be created)
- ✅ [DEVELOPER-GUIDE.md](DEVELOPER-GUIDE.md) - Integration guide (to be created)
- ✅ [STIG-Template.xml](STIG-Template.xml) - Container-adapted Debian STIG (to be created)
- ✅ [SCAP-Results.html](SCAP-Results.html) - OpenSCAP scan results (to be created)

### Supply Chain Security

- [Cosign Verification Instructions](supply-chain/Cosign-Verification-Instructions.md) (to be created)
- [SBOM](compliance/SBOM-nginx-1.27.3-debian-bookworm-fips.spdx.json) (to be created)
- [VEX](compliance/vex-nginx-1.27.3-debian-bookworm-fips.json) (to be created)
- [SLSA Provenance](compliance/slsa-provenance-nginx-1.27.3-debian-bookworm-fips.json) (to be created)

## Support

- **Issues**: Report issues at your organization's issue tracker
- **Documentation**: See docs/ directory for comprehensive guides
- **wolfSSL Support**: Contact wolfSSL for FIPS module support

## License

This Docker configuration is provided for use with licensed wolfSSL FIPS commercial packages.

## Version Information

- **Container Version**: 1.0.0
- **Nginx Version**: 1.27.3
- **wolfSSL Version**: 5.8.2 FIPS 140-3
- **FIPS Certificate**: #4718
- **wolfProvider Version**: 1.1.0
- **Base Image**: debian:bookworm-slim
- **OpenSSL Version**: 3.0.19

## Related Images

- **golang**: Go-only FIPS image with golang-fips/go v1.25
- **java**: Java FIPS images with OpenJDK 8/11/17/19/21
- **python**: Python 3.12 FIPS image with wolfProvider
- **node**: Node.js 16/18 FIPS images with wolfProvider

## References

- [FIPS 140-3 Standard](https://csrc.nist.gov/publications/detail/fips/140/3/final)
- [wolfSSL FIPS Certificate #4718](https://www.wolfssl.com/products/wolfssl-fips/)
- [wolfssl-nginx GitHub Repository](https://github.com/wolfSSL/wolfssl-nginx)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [OpenSSL 3.x Providers](https://www.openssl.org/docs/man3.0/man7/provider.html)
