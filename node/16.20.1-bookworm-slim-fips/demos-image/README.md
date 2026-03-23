# Node.js 16 FIPS Demos

**Interactive demonstrations of FIPS 140-3 capabilities**

> **⚠️ EOL NOTICE**: Node.js 16.20.1 reached End-of-Life on September 11, 2023

---

## Overview

This demo image provides interactive examples demonstrating FIPS 140-3 validated cryptography in Node.js 16 applications.

---

## Quick Start

### Build the Demos Image

```bash
./build.sh
```

### Run Interactive Menu

```bash
docker run --rm -it node-fips-demos:16.20.1
```

### Run Specific Demo

```bash
# Hash Algorithm Demo
docker run --rm node-fips-demos:16.20.1 node /opt/demos/hash_algorithm_demo.js

# TLS/SSL Client Demo
docker run --rm node-fips-demos:16.20.1 node /opt/demos/tls_ssl_client_demo.js

# Certificate Validation Demo
docker run --rm node-fips-demos:16.20.1 node /opt/demos/certificate_validation_demo.js

# HTTPS Request Demo
docker run --rm node-fips-demos:16.20.1 node /opt/demos/https_request_demo.js
```

---

## Available Demos

### 1. Hash Algorithm Demo

Demonstrates FIPS-approved hash algorithms:
- SHA-256
- SHA-384
- SHA-512
- MD5/SHA-1 behavior (available for hashing, blocked in TLS)

### 2. TLS/SSL Client Demo

Shows FIPS-compliant TLS connections:
- TLS 1.2 support
- TLS 1.3 support
- FIPS-approved cipher suite negotiation
- Certificate verification

### 3. Certificate Validation Demo

Demonstrates certificate chain validation:
- Certificate authority verification
- Hostname validation
- Chain of trust

### 4. HTTPS Request Demo

Various HTTPS request patterns:
- Basic GET requests
- POST requests
- Concurrent requests
- Error handling

---

## Node 16 Specifics

**Configuration**: Environment variables set in base image entrypoint
**FIPS Mode**: Automatically enabled via OpenSSL provider
**npm Version**: 9.9.3

---

## Requirements

- Base image: `node:16.20.1-bookworm-slim-fips`
- Build the base image first before building demos

---

## Files

- `hash_algorithm_demo.js` - Hash algorithm demonstrations
- `tls_ssl_client_demo.js` - TLS/SSL connection examples
- `certificate_validation_demo.js` - Certificate validation examples
- `https_request_demo.js` - HTTPS request patterns
- `menu.sh` - Interactive demo selection menu

---

## Support

This is a legacy support image for Node.js 16 (EOL September 11, 2023).
For production use, migrate to a supported Node.js LTS version with FIPS support.
