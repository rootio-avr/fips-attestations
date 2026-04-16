# Node.js 24 with wolfSSL FIPS 140-3

**Docker container providing FIPS 140-3 validated cryptography for Node.js applications**

- **Node.js Version**: 24.14.1 LTS
- **Base Image**: Debian Trixie Slim
- **FIPS Module**: wolfSSL 5.8.2 (Certificate #4718)
- **Architecture**: Provider-based (OpenSSL 3.5 + wolfProvider)
- **Status**: Production-ready

> **Note:** The published `cr.root.io` image reflects this configuration; run `node /opt/wolfssl-fips/bin/fips_init_check.js` or `./diagnostic.sh` to verify on your digest.

---

## Overview

This container image provides Node.js 24.14.1 with FIPS 140-3 validated cryptography using the wolfSSL FIPS module through the OpenSSL 3.5 provider interface. Unlike traditional approaches that require rebuilding Node.js from source, this implementation uses:

- **Pre-built Node.js binaries** from NodeSource (faster builds, smaller images)
- **wolfProvider** to route crypto operations to wolfSSL FIPS
- **OpenSSL 3.5 provider architecture** for seamless integration
- **System OpenSSL replacement** to ensure FIPS enforcement at runtime

### Key Features

✅ **FIPS 140-3 Validated**: wolfSSL 5.8.2 Certificate #4718
✅ **No Node.js Compilation**: Uses pre-built binaries (faster builds)
✅ **Full Compatibility**: Works with existing Node.js applications
✅ **TLS 1.2/1.3 Support**: Modern protocols with FIPS-approved ciphers
✅ **Automatic Integration**: Node.js 24+ auto-loads OpenSSL config
✅ **MD5 Blocked**: Complete MD5 blocking at crypto API level
✅ **100% Test Pass Rate**: 32/32 core diagnostic tests passing

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

Build time: ~12 minutes (vs ~25 minutes for source builds)

### 4. Run

```bash
# Interactive shell
docker run --rm -it cr.root.io/node:24.14.0-trixie-slim-fips

# Run your application
docker run --rm -v $(pwd)/app:/app -w /app cr.root.io/node:24.14.0-trixie-slim-fips node server.js

# Run FIPS validation tests
docker run --rm cr.root.io/node:24.14.0-trixie-slim-fips /test-fips
```

### 5. Validate

```bash
# Run diagnostic tests
./diagnostic.sh

# Check FIPS initialization
docker run --rm cr.root.io/node:24.14.0-trixie-slim-fips node /opt/wolfssl-fips/bin/fips_init_check.js

# Verify FIPS mode
docker run --rm cr.root.io/node:24.14.0-trixie-slim-fips node -p "crypto.getFips()"
# Expected output: 1
```

---

## FIPS Compliance

### Validated Cryptography

**FIPS-Approved Algorithms:**
- ✅ SHA-256, SHA-384, SHA-512 (hashing)
- ✅ AES-CBC, AES-GCM (128, 192, 256-bit) encryption
- ✅ ECDHE (Elliptic Curve Diffie-Hellman) key exchange
- ✅ RSA (2048+ bit) signatures and encryption
- ✅ HMAC (Hash-based Message Authentication Code)

**Blocked for All Operations:**
- ❌ MD5 (completely blocked at crypto API level)
  - `crypto.createHash('md5')` throws error: `error:0308010C:digital envelope routines::unsupported`

**SHA-1 Policy:**
- ℹ️  Available for legacy hash operations (FIPS 140-3 IG D.F compliant)
- ❌ Blocked for TLS connections (0 SHA-1 cipher suites)
- ✅ Compliant with FIPS 140-3 Certificate #4718 requirements

### TLS Configuration

**Supported Protocols:**
- ✅ TLS 1.2 (with FIPS-approved ciphers)
- ✅ TLS 1.3 (recommended)

**Available Cipher Suites:** 30 FIPS-approved cipher suites

**Example Cipher Suites:**
- `TLS_AES_256_GCM_SHA384`
- `TLS_AES_128_GCM_SHA256`
- `ECDHE-RSA-AES256-GCM-SHA384`
- `ECDHE-RSA-AES128-GCM-SHA256`

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

// MD5 is blocked (will throw error)
try {
  crypto.createHash('md5');
} catch (err) {
  console.log('MD5 blocked:', err.message);
  // Output: MD5 blocked: error:0308010C:digital envelope routines::unsupported
}
```

### HTTPS Client with Cipher Verification

```javascript
const https = require('https');

https.get('https://www.example.com', (res) => {
  console.log('Status:', res.statusCode);
  console.log('Cipher:', res.socket.getCipher());
  console.log('Protocol:', res.socket.getProtocol());

  // Verify FIPS-compliant cipher
  const cipher = res.socket.getCipher();
  if (cipher.name.includes('GCM') || cipher.name.includes('AES')) {
    console.log('✓ Using FIPS-approved cipher');
  }

  res.on('data', (d) => {
    process.stdout.write(d);
  });
});
```

### AES-256-GCM Encryption

```javascript
const crypto = require('crypto');

const key = crypto.randomBytes(32);
const iv = crypto.randomBytes(16);

// Encrypt
const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
let encrypted = cipher.update('Hello, FIPS!', 'utf8', 'hex');
encrypted += cipher.final('hex');
const authTag = cipher.getAuthTag();

// Decrypt
const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
decipher.setAuthTag(authTag);
let decrypted = decipher.update(encrypted, 'hex', 'utf8');
decrypted += decipher.final('utf8');

console.log('Decrypted:', decrypted);
// Output: Decrypted: Hello, FIPS!
```

---

## Architecture

### Component Stack

```
Node.js 24.14.1 Application
         ↓
Node.js Crypto API (crypto module)
         ↓
OpenSSL 3.5.0 (libssl, libcrypto)
         ↓
wolfProvider v1.1.1 (provider interface)
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
module = /usr/local/openssl/lib64/ossl-modules/libwolfprov.so

[algorithm_sect]
default_properties = fips=yes
```

**Environment Variables**:
- `OPENSSL_CONF=/etc/ssl/openssl.cnf` - OpenSSL configuration file
- `OPENSSL_MODULES=/usr/local/openssl/lib64/ossl-modules` - Provider module location

Node.js 24+ automatically reads the `nodejs_conf` section from `OPENSSL_CONF` via `--openssl-shared-config` (enabled by default).

---

## Diagnostics

### Run All Tests

```bash
./diagnostic.sh
```

### Test Suites

1. **Backend Verification** (6 tests) - wolfSSL/wolfProvider integration
2. **Connectivity Tests** (8 tests) - HTTPS connections, TLS protocols
3. **FIPS Verification** (6 tests) - FIPS mode, algorithm compliance
4. **Crypto Operations** (8 tests) - Hash algorithms, encryption
5. **Library Compatibility** (4 tests) - Node.js native modules

### Expected Results

- ✅ Backend Verification: 6/6 tests passing
- ✅ Connectivity: 8/8 tests passing
- ✅ FIPS Verification: 6/6 tests passing
- ✅ Crypto Operations: 8/8 tests passing
- ✅ Library Compatibility: 4/4 tests passing

**Overall: 32/32 tests passing (100% pass rate)**

### Test Evidence

Complete test results and evidence available in:
- `Evidence/diagnostic_results.txt` - Raw test output
- `Evidence/test-execution-summary.md` - Comprehensive test summary
- `Evidence/contrast-test-results.md` - FIPS on/off comparison

---

## Build Details

### Build Process

1. **Base Image**: Debian Trixie Slim
2. **OpenSSL**: Custom build 3.5.0 with FIPS support
3. **wolfSSL FIPS**: Compile from source (v5.8.2)
4. **wolfProvider**: Compile from source (v1.1.1)
5. **System OpenSSL Replacement**: Critical step for runtime FIPS
6. **Node.js**: Install pre-built binary from NodeSource
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

- **Final Image**: ~320MB
- **Python FIPS equivalent**: ~400MB
- **Savings**: 20% smaller due to provider-based architecture

---

## Security

### Integrity Verification

All critical FIPS components are checksummed during build:
- `/usr/local/lib/libwolfssl.so` - wolfSSL FIPS library
- `/usr/local/openssl/lib64/ossl-modules/libwolfprov.so` - wolfProvider
- `/test-fips` - FIPS KAT executable

Integrity is verified on container startup via `/usr/local/bin/integrity-check.sh`.

### Entrypoint Checks

On container start:
1. **Integrity Check**: Verify FIPS component checksums
2. **FIPS Initialization**: Run FIPS Known Answer Tests (KATs)
3. **Configuration Validation**: Verify OpenSSL configuration

Skip checks (for debugging only):
```bash
docker run --rm -e SKIP_INTEGRITY_CHECK=true -e SKIP_FIPS_CHECK=true cr.root.io/node:24.14.0-trixie-slim-fips
```

### FIPS Mode Verification

```bash
# Check FIPS mode status
docker run --rm cr.root.io/node:24.14.0-trixie-slim-fips node -p "crypto.getFips()"
# Expected output: 1

# Verify wolfProvider is loaded
docker run --rm cr.root.io/node:24.14.0-trixie-slim-fips openssl list -providers
# Expected: libwolfprov (wolfSSL Provider v1.1.1, status: active)

# Verify MD5 is blocked
docker run --rm cr.root.io/node:24.14.0-trixie-slim-fips node -e "crypto.createHash('md5')"
# Expected: Error: error:0308010C:digital envelope routines::unsupported
```

---

## Documentation

- **README.md** - This file (Quick start guide)
- **ARCHITECTURE.md** - Detailed architecture documentation
- **ATTESTATION.md** - FIPS compliance and attestation
- **POC-VALIDATION-REPORT.md** - Validation test results
- **compliance/CHAIN-OF-CUSTODY.md** - Chain of custody documentation
- **supply-chain/Cosign-Verification-Instructions.md** - Image signing verification
- **Evidence/** - Test results and evidence files

---

## Known Limitations

1. **Node.js 24 EOL**: Node.js 24 reaches End-of-Life on April 30, 2026
2. **Native Addons**: C++ addons that directly use OpenSSL may require recompilation
3. **Performance**: Slight overhead from provider architecture (~5-10%)
4. **Debian Trixie**: Testing distribution (not yet stable as of 2026-04-15)

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
docker run --rm cr.root.io/node:24.14.0-trixie-slim-fips cat /etc/ssl/openssl.cnf

# Check provider library
docker run --rm cr.root.io/node:24.14.0-trixie-slim-fips ls -la /usr/local/openssl/lib64/ossl-modules/libwolfprov.so
```

**Issue**: "FIPS self-test failed"
```bash
# Run FIPS tests manually
docker run --rm cr.root.io/node:24.14.0-trixie-slim-fips /test-fips
```

**Issue**: FIPS mode not enabled
```bash
# Verify FIPS mode
docker run --rm cr.root.io/node:24.14.0-trixie-slim-fips node -p "crypto.getFips()"

# Check environment variables
docker run --rm cr.root.io/node:24.14.0-trixie-slim-fips env | grep OPENSSL
```

---

## Support

For issues and questions:
- Review diagnostics output: `./diagnostic.sh`
- Check logs: `docker logs <container-id>`
- See ARCHITECTURE.md for detailed technical information
- See Evidence/ folder for test results

---

## License

wolfSSL FIPS 5.8.2 - Commercial license required
wolfProvider - GPLv3 / Commercial license
Node.js - MIT License
Container implementation - As per your organization's license

---

## References

- [wolfSSL FIPS 140-3](https://www.wolfssl.com/license/fips/)
- [wolfProvider GitHub](https://github.com/wolfSSL/wolfProvider)
- [Node.js Documentation](https://nodejs.org/docs/latest-v24.x/api/)
- [OpenSSL Providers](https://www.openssl.org/docs/man3.0/man7/provider.html)
- [FIPS 140-3 Implementation Guidance](https://csrc.nist.gov/publications/detail/fips/140/3/final)
- [FIPS 140-3 Certificate #4718](https://csrc.nist.gov/projects/cryptographic-module-validation-program/certificate/4718)

---

**Document Version:** 1.0
**Last Updated:** 2026-04-15
**Image:** cr.root.io/node:24.14.0-trixie-slim-fips
