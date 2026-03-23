# Node.js FIPS Demos Image

Interactive demonstrations of FIPS 140-3 cryptographic capabilities in Node.js 18 with wolfSSL.

## Overview

This container provides hands-on demos showcasing:
- FIPS-approved hash algorithms (SHA-256/384/512)
- TLS 1.2/1.3 client connections
- Certificate chain validation
- HTTPS request patterns

## Quick Start

### Build the Image

```bash
./build.sh
```

### Run Interactive Menu

```bash
docker run --rm -it node-fips-demos:18.20.8
```

This launches an interactive menu where you can select individual demos.

## Available Demos

### 1. Hash Algorithm Demo
**File**: `hash_algorithm_demo.js`

Demonstrates:
- FIPS-approved algorithms (SHA-256, SHA-384, SHA-512)
- Non-FIPS algorithms (MD5, SHA-1) with warnings
- Hash streaming for large data
- Data integrity verification
- Different output formats (hex, base64, buffer)

**Run directly**:
```bash
docker run --rm node-fips-demos:18.20.8 node /opt/demos/hash_algorithm_demo.js
```

### 2. TLS/SSL Client Demo
**File**: `tls_ssl_client_demo.js`

Demonstrates:
- Basic HTTPS connections
- TLS 1.2 and TLS 1.3 negotiation
- FIPS-compliant cipher suites
- Certificate information retrieval
- Connection performance metrics

**Run directly**:
```bash
docker run --rm node-fips-demos:18.20.8 node /opt/demos/tls_ssl_client_demo.js
```

### 3. Certificate Validation Demo
**File**: `certificate_validation_demo.js`

Demonstrates:
- Certificate chain validation
- Hostname verification (CN and SAN)
- Expiration date checking
- Multi-host validation
- SHA-1 signature handling (legacy CAs)

**Run directly**:
```bash
docker run --rm node-fips-demos:18.20.8 node /opt/demos/certificate_validation_demo.js
```

### 4. HTTPS Request Demo
**File**: `https_request_demo.js`

Demonstrates:
- GET and POST requests
- Custom headers
- Concurrent requests
- Timeout handling
- Error handling

**Run directly**:
```bash
docker run --rm node-fips-demos:18.20.8 node /opt/demos/https_request_demo.js
```

## Running Individual Demos

You can run any demo directly without the menu:

```bash
# Hash demo
docker run --rm node-fips-demos:18.20.8 node /opt/demos/hash_algorithm_demo.js

# TLS demo
docker run --rm node-fips-demos:18.20.8 node /opt/demos/tls_ssl_client_demo.js

# Certificate demo
docker run --rm node-fips-demos:18.20.8 node /opt/demos/certificate_validation_demo.js

# HTTPS demo
docker run --rm node-fips-demos:18.20.8 node /opt/demos/https_request_demo.js
```

## Running All Demos

```bash
docker run --rm -it node-fips-demos:18.20.8 /bin/bash -c "
  node /opt/demos/hash_algorithm_demo.js && \
  node /opt/demos/tls_ssl_client_demo.js && \
  node /opt/demos/certificate_validation_demo.js && \
  node /opt/demos/https_request_demo.js
"
```

## Interactive Shell

For manual exploration:

```bash
docker run --rm -it node-fips-demos:18.20.8 /bin/bash
```

Then run demos from `/opt/demos/`:
```bash
cd /opt/demos
ls -l
node hash_algorithm_demo.js
```

## Network Requirements

Most demos require internet access to connect to public HTTPS endpoints (www.google.com, httpbin.org, etc.). Ensure your Docker environment allows outbound HTTPS connections.

## FIPS Compliance Notes

All demos use FIPS-approved cryptography:
- **Hash Algorithms**: SHA-256, SHA-384, SHA-512
- **Ciphers**: AES-GCM (128, 192, 256-bit)
- **TLS Protocols**: TLS 1.2, TLS 1.3
- **Key Exchange**: ECDHE, RSA (2048+ bit)

### Non-FIPS Algorithms

Some demos show non-FIPS algorithms for educational purposes:
- **MD5**: Available in Node.js but NOT FIPS-approved
- **SHA-1**: Available for legacy verification only (FIPS 140-3 IG D.F)

These are clearly marked with warnings in the output.

## Troubleshooting

### Connection Errors

If demos fail to connect:
1. Check internet connectivity
2. Verify Docker DNS configuration
3. Check firewall rules for outbound HTTPS

### Certificate Validation Failures

If certificate validation fails:
1. Ensure system time is correct
2. Check CA bundle is up to date
3. Verify network isn't intercepting TLS

## Educational Use

These demos are designed for:
- Learning FIPS 140-3 compliance requirements
- Understanding TLS/HTTPS in Node.js
- Testing FIPS-enabled applications
- Training and demonstrations

## License

Same as base Node.js FIPS image.

## See Also

- [Base Image README](../README.md)
- [FIPS Implementation Status](../IMPLEMENTATION-STATUS.md)
- [Node.js Crypto Documentation](https://nodejs.org/docs/latest-v18.x/api/crypto.html)
- [wolfSSL FIPS 140-3](https://www.wolfssl.com/license/fips/)
