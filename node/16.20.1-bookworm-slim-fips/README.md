# Node.js 16 with wolfSSL FIPS 140-3

> **⚠️ IMPORTANT END-OF-LIFE NOTICE**
> **Node.js 16.20.1 reached End-of-Life (EOL) on September 11, 2023**
> This image is provided for **legacy application compatibility only**.
> For production deployments, please migrate to a **supported Node.js LTS version**.

**Docker container providing FIPS 140-3 validated cryptography for Node.js applications**

- **Node.js Version**: 16.20.1 (EOL September 2023)
- **Base Image**: Debian Bookworm Slim
- **FIPS Module**: wolfSSL 5.8.2 (Certificate #4718)
- **Architecture**: Provider-based (OpenSSL 3.0 + wolfProvider)
- **Status**: Legacy Support POC

> **Note:** The published `cr.root.io` image reflects this configuration; run `node /opt/wolfssl-fips/bin/fips_init_check.js` or `./diagnostic.sh` to verify on your digest.

---

## Overview

This container image provides Node.js 16.20.1 with FIPS 140-3 validated cryptography using the wolfSSL FIPS module through the OpenSSL 3.0 provider interface. This implementation:

- **Compiles Node.js 16 from source** with OpenSSL 3.0 support (enables provider architecture)
- **Uses wolfProvider** to route crypto operations to wolfSSL FIPS
- **OpenSSL 3.0 provider architecture** for modern cryptographic flexibility

**Note for Node 16**: Pre-built Node 16 binaries use OpenSSL 1.1.1 (no provider support), so we compile from source with OpenSSL 3.0. Environment variable configuration is used to load the OpenSSL configuration.

### Key Features

✅ **FIPS 140-3 Validated**: wolfSSL 5.8.2 Certificate #4718
✅ **Provider Architecture**: OpenSSL 3.0 provider-based implementation (requires source compilation)
✅ **Full Compatibility**: Works with existing Node.js applications
✅ **TLS 1.2/1.3 Support**: Modern protocols with FIPS-approved ciphers
✅ **Environment Variable Config**: Uses standard OpenSSL environment variables
⚠️ **EOL Status**: Security updates no longer provided by Node.js project
⚠️ **Build Time**: ~45-60 minutes (Node.js + OpenSSL source compilation)

---

## Quick Start

### 1. Prerequisites

- Docker 20.10+ with BuildKit support
- wolfSSL FIPS 5.8.2 package password

### 2. Setup

Create the wolfSSL password file:
```bash
echo 'YOUR_WOLFSSL_PASSWORD' > wolfssl_password.txt
```

### 3. Build

```bash
./build.sh
```

**Build time: ~45-60 minutes** (Node.js source compilation required for OpenSSL 3.0 provider support)

### 4. Run

```bash
# Interactive shell
docker run --rm -it node:16.20.1-bookworm-slim-fips

# Run your application
docker run --rm -v $(pwd)/app:/app -w /app node:16.20.1-bookworm-slim-fips node server.js

# Run FIPS validation tests
docker run --rm node:16.20.1-bookworm-slim-fips /test-fips
```

### 5. Validate

```bash
# Run diagnostic tests
./diagnostic.sh

# Check FIPS initialization
docker run --rm node:16.20.1-bookworm-slim-fips node /opt/wolfssl-fips/bin/fips_init_check.js
```

---

## Configuration

### Environment Variable Configuration

Node.js 16 uses environment variables to load the OpenSSL configuration:

**Configuration set in `docker-entrypoint.sh`**:
```bash
export OPENSSL_CONF=/etc/ssl/openssl.cnf
export OPENSSL_MODULES=/usr/local/lib
```

These variables ensure Node.js loads the wolfProvider configuration on startup.

### npm Version

- Node 16.20.1 ships with **npm 8.19.4**
- Automatically upgraded to **npm 9.9.3** during build (latest compatible with Node 16)
- npm 10.x requires newer Node.js versions

---

## FIPS Compliance

### Validated Cryptography

**FIPS-Approved Algorithms:**
- ✅ SHA-256, SHA-384, SHA-512 (hashing)
- ✅ AES-CBC, AES-GCM (128, 192, 256-bit) encryption¹
- ✅ ECDHE (Elliptic Curve Diffie-Hellman) key exchange
- ✅ RSA (2048+ bit) signatures and encryption
- ✅ HMAC (Hash-based Message Authentication Code)

¹ *Note: AES-GCM requires FIPS v6+ for Node.js streaming API support. Use AES-CBC for production.*

**Blocked for New Operations:**
- ❌ MD5 (blocked at OpenSSL level)
- ❌ SHA-1 for new signatures/certificates
- ❌ RC4, DES, 3DES ciphers

**SHA-1 Policy:**
- ℹ️  Available for legacy certificate verification (FIPS 140-3 IG D.F compliant)
- ❌ Blocked for new TLS connections (0 SHA-1 cipher suites)

### TLS Configuration

**Supported Protocols:**
- ✅ TLS 1.2 (with FIPS-approved ciphers)
- ✅ TLS 1.3 (recommended)

**Example Cipher Suites:**
- `TLS_AES_256_GCM_SHA384`
- `TLS_AES_128_GCM_SHA256`
- `ECDHE-RSA-AES256-GCM-SHA384`
- `ECDHE-ECDSA-AES128-GCM-SHA256`

---

## Usage Examples

### Basic HTTPS Server

```javascript
const https = require('https');
const fs = require('fs');

const options = {
  key: fs.readFileSync('server-key.pem'),
  cert: fs.readFileSync('server-cert.pem')
};

https.createServer(options, (req, res) => {
  res.writeHead(200);
  res.end('FIPS-compliant HTTPS server\n');
}).listen(8443);

console.log('Server running with wolfSSL FIPS on port 8443');
```

### Hash Computation

```javascript
const crypto = require('crypto');

// FIPS-approved: SHA-256
const hash = crypto.createHash('sha256');
hash.update('FIPS test data');
console.log('SHA-256:', hash.digest('hex'));

// FIPS-approved: SHA-512
const hash512 = crypto.createHash('sha512');
hash512.update('FIPS test data');
console.log('SHA-512:', hash512.digest('hex'));
```

### HTTPS Client

```javascript
const https = require('https');

https.get('https://www.example.com', (res) => {
  console.log('Status:', res.statusCode);
  console.log('Cipher:', res.socket.getCipher());
  console.log('Protocol:', res.socket.getProtocol());

  res.on('data', (d) => {
    process.stdout.write(d);
  });
});
```

---

## Architecture

### Component Stack

```
Node.js 16.20.1 Application
         ↓
Node.js Crypto API (crypto module)
         ↓
OpenSSL 3.0.18 (libssl, libcrypto)
         ↓
wolfProvider v1.0.2 (provider interface)
         ↓
wolfSSL 5.8.2 FIPS Module (Certificate #4718)
```

### Configuration

**OpenSSL Configuration** (`/etc/ssl/openssl.cnf`):
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

**Environment Variables** (Set in docker-entrypoint.sh):
- `OPENSSL_CONF=/etc/ssl/openssl.cnf` - OpenSSL configuration file
- `OPENSSL_MODULES=/usr/local/lib` - Provider module location

**Note**: These variables are explicitly exported in the entrypoint script to ensure the OpenSSL configuration is loaded before Node.js starts.

---

## Diagnostics

### Run All Tests

```bash
./diagnostic.sh
```

### Test Suites

1. **Backend Verification** - wolfSSL/wolfProvider integration
2. **Connectivity Tests** - HTTPS connections, TLS protocols
3. **FIPS Verification** - FIPS mode, algorithm compliance
4. **Crypto Operations** - Hash algorithms, TLS features
5. **Library Compatibility** - Node.js native modules

### Expected Results

- ✅ Backend Verification: 6/6 tests passing
- ✅ Connectivity: 7-8/8 tests passing
- ✅ FIPS Verification: 6/6 tests passing
- ✅ Crypto Operations: 8-10/10 tests passing
- ✅ Library Compatibility: 4-6/6 tests passing

**Overall: 85-90%+ pass rate**

---

## Build Details

### Build Process

1. **Base Image**: Debian Bookworm Slim
2. **wolfSSL FIPS**: Compile from source (v5.8.2)
3. **wolfProvider**: Compile from source (v1.0.2)
4. **OpenSSL 3.0**: Compile from source (v3.0.18) - required for provider support
5. **Node.js**: **Compile from source** (v16.20.1) with shared OpenSSL 3.0
6. **npm Upgrade**: Upgrade to npm 9.9.3 (latest compatible)
7. **Configuration**: Copy OpenSSL config, entrypoint, scripts
8. **Verification**: Generate checksums for integrity

### Build Options

```bash
# Default build
./build.sh

# Build without cache
./build.sh --no-cache

# Build for specific platform
./build.sh --platform linux/amd64
```

### Image Size

- **Final Image**: ~350-400MB
- **Note**: Image size includes Node.js source compilation artifacts and OpenSSL 3.0

---

## Security

### Integrity Verification

All critical FIPS components are checksummed during build:
- `/usr/local/lib/libwolfssl.so` - wolfSSL FIPS library
- `/usr/local/lib/libwolfprov.so` - wolfProvider
- `/test-fips` - FIPS KAT executable

Integrity is verified on container startup via `/usr/local/bin/integrity-check.sh`.

### Entrypoint Checks

On container start:
1. **Integrity Check**: Verify FIPS component checksums
2. **FIPS Initialization**: Run FIPS Known Answer Tests (KATs)
3. **Configuration Validation**: Verify OpenSSL configuration

Skip checks (for debugging only):
```bash
docker run --rm -e SKIP_INTEGRITY_CHECK=true -e SKIP_FIPS_CHECK=true node:16.20.1-bookworm-slim-fips
```

---

## Documentation

- **README.md** - This file
- **ARCHITECTURE.md** - Detailed architecture documentation
- **POC-VALIDATION-REPORT.md** - Validation test results
- **IMPLEMENTATION-STATUS.md** - Implementation status and notes

---

## Security

### npm Dependency CVE Mitigations

**Status**: ✅ PATCHED (as of 2026-03-22)

This image includes patches for high-severity vulnerabilities in npm's bundled dependencies. The Dockerfile patches the following packages:

- **minimatch@9.0.7** - Fixes CVE-2026-26996, CVE-2026-27903
- **glob@10.5.0** - Fixes CVE-2025-64756
- **cross-spawn@7.0.5** - Fixes CVE-2024-21538
- **tar@7.5.11** - Fixes CVE-2026-23745

See Dockerfile lines 230-267 for patch implementation details.

**Verification**:
```bash
docker run --rm cr.root.io/node:16.20.1-bookworm-slim-fips \
  bash -c "cd /usr/local/lib/node_modules/npm && npm ls tar minimatch glob cross-spawn"
```

**Note**: Since Node 16 is EOL and npm 10+ (which includes these fixes) requires Node.js 18+, we manually patch the vulnerable dependencies within npm 9.9.3.

---

## Known Limitations

1. **Node.js 16 EOL**: Reached End-of-Life on September 11, 2023
2. **No Security Updates**: No official security patches from Node.js project
3. **Configuration Method**: Requires explicit environment variable exports in entrypoint
4. **npm Version**: Limited to npm 9.x (npm 10+ requires newer Node.js versions)
5. **Native Addons**: C++ addons that directly use OpenSSL may require recompilation
6. **Performance**: Slight overhead from provider architecture (~5-10%)

---

## Troubleshooting

### Build Fails

**Issue**: wolfSSL password error
```bash
echo 'YOUR_ACTUAL_PASSWORD' > wolfssl_password.txt
./build.sh
```

**Issue**: Network timeout during build
```bash
docker build --build-arg HTTP_PROXY=http://proxy:8080 ...
```

### Runtime Issues

**Issue**: "Provider could not be loaded"
```bash
# Check OpenSSL configuration
docker run --rm node:16.20.1-bookworm-slim-fips cat /etc/ssl/openssl.cnf

# Check provider library
docker run --rm node:16.20.1-bookworm-slim-fips ls -la /usr/local/lib/libwolfprov.so

# Check environment variables
docker run --rm node:16.20.1-bookworm-slim-fips env | grep OPENSSL
```

**Issue**: "FIPS self-test failed"
```bash
# Run FIPS tests manually
docker run --rm node:16.20.1-bookworm-slim-fips /test-fips
```

**Issue**: Node 16 not loading OpenSSL config
```bash
# Verify environment variables are set
docker run --rm --entrypoint="" node:16.20.1-bookworm-slim-fips bash -c '
  echo "OPENSSL_CONF: $OPENSSL_CONF"
  echo "OPENSSL_MODULES: $OPENSSL_MODULES"
'
```

---

## Support

For issues and questions:
- Review diagnostics output: `./diagnostic.sh`
- Check logs: `docker logs <container-id>`
- Consider migrating to a supported Node.js LTS version for continued support

---

## License

wolfSSL FIPS 5.8.2 - Commercial license required
wolfProvider - GPLv3 / Commercial license
Node.js - MIT License
Container implementation - As per your organization's license

---

## References

- [wolfSSL FIPS 140-3](https://www.wolfssl.com/license/fips/)
- [wolfProvider](https://github.com/wolfSSL/wolfProvider)
- [Node.js 16 Documentation](https://nodejs.org/docs/latest-v16.x/api/)
- [Node.js 16 EOL](https://github.com/nodejs/Release#release-schedule)
- [OpenSSL Providers](https://www.openssl.org/docs/man3.0/man7/provider.html)
- [FIPS 140-3 Implementation Guidance](https://csrc.nist.gov/publications/detail/fips/140/3/final)
