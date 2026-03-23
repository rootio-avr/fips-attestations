# Node.js 16 wolfSSL FIPS Architecture

**Document Version**: 1.0
**Last Updated**: 2026-03-22
**FIPS Certificate**: #4718 (wolfSSL 5.8.2)
**Architecture**: Provider-based (OpenSSL 3.0 with wolfProvider)
**Node.js Version**: 16.20.1 (EOL September 11, 2023)

---

> **⚠️ EOL NOTICE**: Node.js 16 reached End-of-Life on September 11, 2023. This implementation is provided for legacy application compatibility only. Consider migrating to a supported Node.js LTS version.

---

## Overview

This implementation provides FIPS 140-3 validated cryptography for Node.js 16 applications using a **provider-based architecture**. The key aspect is the **configuration loading method** which uses environment variables explicitly exported in the docker-entrypoint.sh script.

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│ Node.js 16.20.1 Application Layer                       │
│ - Standard crypto, tls, https modules                   │
│ - No application code changes required                  │
└────────────────────────┬────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────┐
│ Node.js Core Modules (Built-in)                         │
│ - crypto, tls, https modules                            │
│ - C++ bindings to OpenSSL                               │
└────────────────────────┬────────────────────────────────┘
                         │ libssl.so.3, libcrypto.so.3
┌────────────────────────▼────────────────────────────────┐
│ OpenSSL 3.0.18 (Provider Interface)                     │
│ - SSL/TLS protocol handling                             │
│ - Provider loading and management                       │
│ - Configuration: /etc/ssl/openssl.cnf                   │
└────────────────────────┬────────────────────────────────┘
                         │ Provider API
┌────────────────────────▼────────────────────────────────┐
│ wolfProvider v1.0.2                                     │
│ (/usr/local/lib/libwolfprov.so)                         │
│ - Routes crypto operations to wolfSSL                   │
│ - FIPS mode enforcement                                 │
└────────────────────────┬────────────────────────────────┘
                         │ wolfSSL API
┌────────────────────────▼────────────────────────────────┐
│ wolfSSL 5.8.2 FIPS 140-3 Module                         │
│ (/usr/local/lib/libwolfssl.so.44.0.0)                   │
│ - Certificate #4718                                     │
│ - FIPS-validated cryptographic operations               │
└─────────────────────────────────────────────────────────┘
```

---

## Configuration Management

### Configuration Approach

The OpenSSL configuration is loaded through environment variables explicitly exported in the docker-entrypoint.sh script.

**docker-entrypoint.sh**:
```bash
#!/bin/bash
set -e

# Ensure OpenSSL configuration is loaded via environment variables
export OPENSSL_CONF=/etc/ssl/openssl.cnf
export OPENSSL_MODULES=/usr/local/lib

# Run integrity and FIPS checks...

# Execute the main command
exec "$@"
```

### Environment Variables

**Set in Dockerfile**:
```dockerfile
ENV OPENSSL_CONF=/etc/ssl/openssl.cnf
ENV OPENSSL_MODULES=/usr/local/lib
```

**Explicitly exported in entrypoint**:
```bash
export OPENSSL_CONF=/etc/ssl/openssl.cnf
export OPENSSL_MODULES=/usr/local/lib
```

**Why both?**
- Dockerfile ENV: For container metadata and sub-processes
- Entrypoint export: Ensures variables are set before Node.js starts

---

## OpenSSL Configuration File

**Location**: `/etc/ssl/openssl.cnf`

**Content**:
```ini
# For OpenSSL utilities and shared applications
openssl_conf = openssl_init

# For Node.js applications (Node.js reads this section by default)
nodejs_conf = openssl_init

[openssl_init]
providers = provider_sect
alg_section = algorithm_sect

[provider_sect]
libwolfprov = libwolfprov_sect

[libwolfprov_sect]
activate = 1
module = /usr/local/lib/libwolfprov.so

[algorithm_sect]
default_properties = fips=yes
```

This configuration activates the wolfProvider and enforces FIPS mode for all cryptographic operations.

---

## Component Versions

| Component | Version | Notes |
|-----------|---------|-------|
| **Node.js** | 16.20.1 | EOL September 11, 2023 |
| **npm** | 9.9.3 | Upgraded from 8.19.4 during build |
| **Debian** | Bookworm (12) | Stable base |
| **OpenSSL** | 3.0.18 | System library |
| **wolfSSL** | 5.8.2 | FIPS 140-3 Certificate #4718 |
| **wolfProvider** | 1.0.2 | OpenSSL 3.0 provider |

---

## npm Version Management

**Default npm (shipped with Node 16.20.1)**: 8.19.4

**Upgrade during build**:
```dockerfile
# Check npm version and upgrade if needed
NPM_VERSION=$(npm --version)
if [ "$(printf '%s\n' "8.19.4" "$NPM_VERSION" | sort -V | head -n1)" = "$NPM_VERSION" ]; then
    npm install -g npm@9.9.3
fi
```

**Why npm 9.9.3?**
- Latest npm 9.x version compatible with Node 16
- npm 10.x requires newer Node.js versions
- Provides security updates and bug fixes over npm 8.19.4

---

## FIPS Validation Flow

### Container Startup Sequence

```
1. Docker starts container
   ↓
2. docker-entrypoint.sh executes
   ↓
3. Export OPENSSL_CONF and OPENSSL_MODULES (Node 16 specific)
   ↓
4. Run integrity check (/usr/local/bin/integrity-check.sh)
   - Verify libwolfssl.so checksum
   - Verify libwolfprov.so checksum
   - Verify test-fips executable checksum
   ↓
5. Run FIPS initialization check (node /opt/wolfssl-fips/bin/fips_init_check.js)
   - Verify OpenSSL config exists
   - Verify wolfSSL and wolfProvider libraries exist
   - Test FIPS-approved algorithms (SHA-256, SHA-384, SHA-512)
   - Verify random bytes generation
   - Run FIPS KAT executable (/test-fips)
   - Check crypto.getFips() returns 1
   ↓
6. Display environment information
   - Node.js version
   - npm version
   - OpenSSL config path
   - Configuration method (environment variables)
   ↓
7. Execute user command (e.g., node app.js)
```

### FIPS Mode Verification

**Verify FIPS mode is enabled**:
```javascript
const crypto = require('crypto');

console.log('FIPS mode:', crypto.getFips());
// Expected output: 1 (FIPS enabled)
```

**Check provider configuration**:
```bash
docker run --rm node:16.20.1-bookworm-slim-fips bash -c '
  echo "OPENSSL_CONF: $OPENSSL_CONF"
  echo "OPENSSL_MODULES: $OPENSSL_MODULES"
  cat $OPENSSL_CONF
'
```

---

## Build Process

### Dockerfile Key Steps

```dockerfile
# 1. Base image: Debian Bookworm Slim
FROM debian:bookworm-slim

# 2. Set environment variables (Node 16)
ENV NODE_VERSION=16.20.1
ENV OPENSSL_CONF=/etc/ssl/openssl.cnf
ENV OPENSSL_MODULES=/usr/local/lib

# 3. Build wolfSSL FIPS 5.8.2
# Compile from source with FIPS validation

# 4. Build wolfProvider 1.0.2
# Compile from source to provide OpenSSL 3.0 interface

# 5. Install Node.js 16.20.1 from NodeSource
curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
apt-get install -y nodejs

# 6. Upgrade npm to 9.9.3
npm install -g npm@9.9.3

# 7. Copy OpenSSL configuration
COPY openssl.cnf /etc/ssl/openssl.cnf

# 8. Copy entrypoint with Node 16 environment export
COPY docker-entrypoint.sh /docker-entrypoint.sh
```

### Build Time

| Component | Build Time | Notes |
|-----------|-----------|-------|
| **Node 16 FIPS** | ~45-60 min | Node.js source compilation required for OpenSSL 3.0 |
| **wolfSSL FIPS** | ~15 min | Source compilation with FIPS validation |
| **OpenSSL 3.0** | ~10 min | Source compilation for provider support |

---

## Testing and Validation

### Diagnostic Test Suite

**Run all tests**:
```bash
./diagnostic.sh
```

**Expected results**:
- Backend Verification: 6/6 tests passing
- Connectivity: 7-8/8 tests passing
- FIPS Verification: 6/6 tests passing
- Crypto Operations: 8-10/10 tests passing
- Library Compatibility: 4-6/6 tests passing

**Overall: 85-90%+ pass rate**

### Manual Verification

```bash
# Test 1: FIPS mode enabled
docker run --rm node:16.20.1-bookworm-slim-fips \
  node -e "console.log('FIPS:', require('crypto').getFips())"
# Expected: FIPS: 1

# Test 2: SHA-256 works
docker run --rm node:16.20.1-bookworm-slim-fips \
  node -e "console.log(require('crypto').createHash('sha256').update('test').digest('hex'))"

# Test 3: Run FIPS KAT tests
docker run --rm node:16.20.1-bookworm-slim-fips /test-fips
# Expected: All KAT tests pass

# Test 4: Environment variables set
docker run --rm node:16.20.1-bookworm-slim-fips env | grep OPENSSL
# Expected: OPENSSL_CONF=/etc/ssl/openssl.cnf
#           OPENSSL_MODULES=/usr/local/lib
```

---

## Troubleshooting

### Issue: FIPS mode not enabled (crypto.getFips() returns 0)

**Diagnosis**:
```bash
# Check environment variables
docker run --rm --entrypoint="" node:16.20.1-bookworm-slim-fips bash -c '
  echo "OPENSSL_CONF: $OPENSSL_CONF"
  echo "OPENSSL_MODULES: $OPENSSL_MODULES"
'

# Check if config file exists
docker run --rm node:16.20.1-bookworm-slim-fips cat /etc/ssl/openssl.cnf

# Check if provider library exists
docker run --rm node:16.20.1-bookworm-slim-fips ls -la /usr/local/lib/libwolfprov.so
```

**Solution**:
- Ensure docker-entrypoint.sh exports environment variables before starting Node.js
- Verify OpenSSL configuration file exists at `/etc/ssl/openssl.cnf`
- Check that wolfProvider library is at `/usr/local/lib/libwolfprov.so`

### Issue: Provider not loaded

**Diagnosis**:
```bash
# Run FIPS initialization check
docker run --rm node:16.20.1-bookworm-slim-fips \
  node /opt/wolfssl-fips/bin/fips_init_check.js
```

**Solution**:
- Check that `OPENSSL_MODULES` points to directory containing libwolfprov.so
- Verify library dependencies: `ldd /usr/local/lib/libwolfprov.so`

---

## Implementation Approach

This implementation uses a **provider-based architecture** which offers several advantages:

| Approach | Status | Notes |
|----------|--------|-------|
| **Provider-based** | ✅ This implementation | Uses OpenSSL 3.0 provider interface |
| **Engine-based** | ⚠️ Deprecated | Uses OpenSSL 1.1.1 engines (EOL) |
| **Source compilation** | ⚠️ Complex | Slower builds (~60 min), harder to maintain |
| **Static linking** | ⚠️ Complex | Requires Node.js rebuild, complex updates |

**Why provider-based**: Modern, maintainable, and compatible with OpenSSL 3.0 ecosystem.

---

## Additional Resources

- **[README.md](README.md)** - General documentation and usage guide
- **[POC-VALIDATION-REPORT.md](POC-VALIDATION-REPORT.md)** - POC validation evidence
- **wolfSSL FIPS**: https://www.wolfssl.com/products/wolfssl-fips/
- **wolfProvider**: https://github.com/wolfSSL/wolfProvider
- **Node.js 16 Docs**: https://nodejs.org/docs/latest-v16.x/api/
- **Node.js 16 EOL**: https://github.com/nodejs/Release#release-schedule

---

**Last Updated**: 2026-03-22
**Version**: 1.0
**wolfSSL FIPS Version**: v5.8.2 (Certificate #4718)
**Node.js Version**: 16.20.1 (EOL September 11, 2023)
**OpenSSL Version**: 3.0.18
**wolfProvider Version**: v1.0.2
