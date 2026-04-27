# Gotenberg 8.30.0 with wolfSSL FIPS 140-3

**Docker container providing FIPS 140-3 validated cryptography for Gotenberg PDF conversion service**

- **Gotenberg Version**: 8.30.0
- **Base Image**: Debian Trixie Slim
- **Go Compiler**: golang-fips/go v1.26.2 (with CGO)
- **FIPS Module**: wolfSSL 5.8.2 (Certificate #4718)
- **Architecture**: Full FIPS Stack (golang-fips/go + Provider-based)
- **Status**: Production-ready

> **Note:** This implementation uses **Approach 1 (Full FIPS Stack)** - Gotenberg rebuilt from source with golang-fips/go, ensuring comprehensive FIPS compliance across all components.

---

## Overview

This container image provides Gotenberg 8.30.0 with FIPS 140-3 validated cryptography using a dual-layer approach:

- **Go Application Layer**: Gotenberg rebuilt with golang-fips/go v1.26.2 (CGO-enabled)
- **System Layer**: Chromium + LibreOffice using system OpenSSL with wolfSSL FIPS

Unlike simple system-level FIPS approaches, this implementation ensures:
- ✅ Gotenberg Go code uses FIPS-validated crypto (via golang-fips/go)
- ✅ Chromium browser uses FIPS-validated TLS (HTML → PDF conversions)
- ✅ LibreOffice suite uses FIPS-validated TLS (Office docs → PDF conversions)
- ✅ All cryptographic operations route through wolfSSL FIPS module

### Key Features

✅ **FIPS 140-3 Validated**: wolfSSL 5.8.2 Certificate #4718
✅ **Full FIPS Stack**: Gotenberg rebuilt with golang-fips/go + system FIPS
✅ **CGO Enabled**: golang-fips/go requires CGO_ENABLED=1
✅ **Chromium + LibreOffice**: Both use FIPS OpenSSL for TLS
✅ **TLS 1.2/1.3 Support**: Modern protocols with FIPS-approved ciphers
✅ **MD5 Blocked**: Complete MD5 blocking at crypto API level
✅ **35 Diagnostic Tests**: Comprehensive validation (backend, connectivity, FIPS, crypto, API)

---

## Quick Start

### 1. Prerequisites

- Docker 20.10+ with BuildKit support
- wolfSSL FIPS 5.8.2 package password
- Build time: ~45-60 minutes (golang-fips/go + Gotenberg compilation)

### 2. Setup

Create the wolfSSL password file:
```bash
echo 'YOUR_WOLFSSL_PASSWORD' > wolfssl_password.txt
chmod 600 wolfssl_password.txt
```

### 3. Build

```bash
./build.sh
```

Build stages:
1. OpenSSL 3.0.19 builder (~5 minutes)
2. wolfSSL FIPS v5.8.2 builder (~10 minutes)
3. wolfProvider v1.1.0 builder (~3 minutes)
4. golang-fips/go v1.26.2 builder (~15 minutes)
5. Gotenberg 8.30.0 builder (~10 minutes)
6. PDF tools builder (~2 minutes)
7. Final runtime assembly (~5 minutes)

**Total build time**: 45-60 minutes (first build)

### 4. Run

```bash
# Run Gotenberg service
docker run --rm -p 3000:3000 gotenberg:8.30.0-trixie-slim-fips

# Interactive shell
docker run --rm -it --entrypoint bash --user root gotenberg:8.30.0-trixie-slim-fips

# Check version
docker run --rm gotenberg:8.30.0-trixie-slim-fips gotenberg --version
```

### 5. Validate

```bash
# Run diagnostic tests (35 tests)
./diagnostic.sh

# Verify CGO is enabled
docker run --rm --entrypoint "" gotenberg:8.30.0-trixie-slim-fips sh -c 'echo $CGO_ENABLED'
# Expected output: 1

# Verify FIPS mode
docker run --rm --entrypoint "" gotenberg:8.30.0-trixie-slim-fips openssl list -providers
# Expected: libwolfprov (wolfSSL Provider v1.1.0, status: active)
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
  - OpenSSL: `error:0308010C:digital envelope routines::unsupported`
  - Go runtime: Blocked by `GODEBUG=fips140=only`

**SHA-1 Policy:**
- ℹ️  Status depends on wolfSSL build configuration
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

### Basic PDF Conversion

```bash
# Start Gotenberg service
docker run -d --name gotenberg-fips -p 3000:3000 gotenberg:8.30.0-trixie-slim-fips

# Convert HTML to PDF (Chromium with FIPS TLS)
curl --request POST \
  --url http://localhost:3000/forms/chromium/convert/url \
  --header 'Content-Type: multipart/form-data' \
  --form url=https://example.com \
  -o example.pdf

# Convert Office document to PDF (LibreOffice with FIPS TLS)
curl --request POST \
  --url http://localhost:3000/forms/libreoffice/convert \
  --header 'Content-Type: multipart/form-data' \
  --form files=@document.docx \
  -o document.pdf
```

### Health Check

```bash
# Check service health
curl http://localhost:3000/health

# Expected response:
# {"status":"up"}
```

### Docker Compose

```yaml
version: '3.8'

services:
  gotenberg-fips:
    image: gotenberg:8.30.0-trixie-slim-fips
    ports:
      - "3000:3000"
    environment:
      - GOTENBERG_CHROMIUM_DISABLE_JAVASCRIPT=false
      - GOTENBERG_LIBREOFFICE_AUTO_START=false
    restart: unless-stopped
```

---

## Architecture

### Component Stack

```
Gotenberg 8.30.0 Application (golang-fips/go v1.26.2, CGO_ENABLED=1)
         ↓ (dlopen via CGO)
OpenSSL 3.0.19 (libssl, libcrypto)
         ↓
wolfProvider v1.1.0 (provider interface)
         ↓
wolfSSL 5.8.2 FIPS Module (Certificate #4718)
         ↑
Chromium + LibreOffice (via system OpenSSL)
```

### CGO Configuration

**Critical Requirement**: golang-fips/go uses CGO to dynamically load OpenSSL at runtime via `dlopen()`.

**Build Time**:
```dockerfile
ENV CGO_ENABLED=1
ENV CGO_CFLAGS="-I/usr/local/openssl/include -I/usr/local/include"
ENV CGO_LDFLAGS="-L/usr/local/openssl/lib64 -L/usr/local/lib"
```

**Runtime**:
```dockerfile
ENV CGO_ENABLED=1
ENV LD_LIBRARY_PATH="/usr/local/openssl/lib64:/usr/local/lib"
```

**Dependencies**:
- Build: `gcc`, `g++`, `libc6-dev`, `pkg-config`
- Runtime: `libc6`, `libstdc++6`

### Configuration

**OpenSSL Configuration** (`/etc/ssl/openssl.cnf`):
```ini
openssl_conf = openssl_init
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
- `CGO_ENABLED=1` - **REQUIRED** for golang-fips/go
- `GODEBUG=fips140=only` - Strict FIPS mode for Go runtime
- `GOEXPERIMENT=strictfipsruntime` - Strict FIPS runtime enforcement
- `GOLANG_FIPS=1` - Enable FIPS mode in golang-fips/go
- `OPENSSL_CONF=/etc/ssl/openssl.cnf` - OpenSSL configuration file
- `OPENSSL_MODULES=/usr/local/openssl/lib64/ossl-modules` - Provider module location

---

## Diagnostics

### Run All Tests

```bash
# Run core diagnostics (35 tests - recommended for quick validation)
./diagnostic.sh

# Run all tests including TLS server mode (40 tests)
./diagnostic.sh --with-tls

# Run specific test suite
./diagnostic.sh backend
./diagnostic.sh tls-server
```

### Test Suites

**Core Diagnostics (35 tests):**
1. **Backend Verification** (6 tests) - wolfSSL/wolfProvider/CGO integration
2. **Connectivity Tests** (8 tests) - HTTPS connections, TLS protocols
3. **FIPS Verification** (7 tests) - FIPS mode, algorithm compliance
4. **Crypto Operations** (8 tests) - Hash algorithms, encryption
5. **Gotenberg API Tests** (6 tests) - PDF conversion functionality

**Optional (5 tests):**
6. **TLS Server Tests** (5 tests) - TLS 1.3 server mode validation
   - Validates golang-fips/go v1.26.2 session ticket fix
   - Tests HTTPS health check and PDF conversion
   - Run with: `./diagnostic.sh --with-tls` or `./diagnostics/tls-server-tests.sh`

### Expected Results

**Core Diagnostics:**
- ✅ Backend Verification: 6/6 tests passing
- ✅ Connectivity: 8/8 tests passing
- ✅ FIPS Verification: 7/7 tests passing
- ✅ Crypto Operations: 8/8 tests passing
- ✅ Gotenberg API Tests: 6/6 tests passing

**Overall: 35/35 tests passing (100% pass rate)**

**With TLS Server Tests:**
- ✅ TLS Server Tests: 5/5 tests passing

**Overall: 40/40 tests passing (100% pass rate)**

### Test Evidence

Complete test results and evidence available in:
- `Evidence/diagnostic_results.txt` - Raw test output
- `Evidence/test-execution-summary.md` - Comprehensive test summary
- `Evidence/contrast-test-results.md` - FIPS on/off comparison

---

## Build Details

### Build Process

1. **OpenSSL 3.0.19**: Custom build with FIPS support
2. **wolfSSL FIPS v5.8.2**: Compile from source (requires password)
3. **wolfProvider v1.1.0**: Compile from source
4. **golang-fips/go v1.26.2**: Build from source with CGO
5. **Gotenberg 8.30.0**: Rebuild from source with golang-fips/go
6. **PDF Tools**: Build pdfcpu, install QPDF, ExifTool
7. **System Integration**: Install Chromium, LibreOffice, fonts
8. **System OpenSSL Replacement**: Critical step for runtime FIPS

### Build Options

```bash
# Default build
./build.sh

# Build without cache
./build.sh --no-cache
```

### Image Size

- **Final Image**: ~1.2GB (includes Chromium + LibreOffice + fonts)
- **Breakdown**:
  - Base system: ~100MB
  - Chromium: ~200MB
  - LibreOffice: ~400MB
  - Fonts: ~150MB
  - FIPS components: ~50MB
  - Gotenberg + tools: ~100MB
  - Other dependencies: ~200MB

---

## Security

### Integrity Verification

All critical FIPS components are checksummed during build:
- `/usr/local/openssl/lib64/libssl.so` - OpenSSL FIPS library
- `/usr/local/lib/libwolfssl.so` - wolfSSL FIPS library
- `/usr/local/openssl/lib64/ossl-modules/libwolfprov.so` - wolfProvider

Integrity is verified on container startup via `/usr/local/bin/docker-entrypoint.sh`.

### Entrypoint Checks

On container start:
1. **CGO Configuration**: Verify CGO_ENABLED=1
2. **FIPS Environment**: Verify GODEBUG, GOEXPERIMENT, GOLANG_FIPS
3. **OpenSSL Configuration**: Verify configuration file and provider loading
4. **Library Dependencies**: Verify wolfSSL, OpenSSL libraries

Skip checks (for debugging only):
```bash
docker run --rm -e SKIP_FIPS_CHECK=true gotenberg:8.30.0-trixie-slim-fips
```

### FIPS Mode Verification

```bash
# Check CGO is enabled
docker run --rm --entrypoint "" gotenberg:8.30.0-trixie-slim-fips sh -c 'echo $CGO_ENABLED'
# Expected output: 1

# Verify wolfProvider is loaded
docker run --rm --entrypoint "" gotenberg:8.30.0-trixie-slim-fips openssl list -providers
# Expected: libwolfprov (wolfSSL Provider v1.1.0, status: active)

# Verify MD5 is blocked
docker run --rm --entrypoint "" gotenberg:8.30.0-trixie-slim-fips sh -c 'echo test | openssl dgst -md5'
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

1. **Go Version**: Uses golang-fips/go v1.26.2 (FIPS-enabled Go compiler with OpenSSL backend)
2. **Build Time**: 45-60 minutes due to golang-fips/go compilation and Gotenberg rebuild
3. **Image Size**: ~1.2GB due to Chromium + LibreOffice + fonts
4. **CGO Requirement**: CGO_ENABLED=1 is mandatory (no pure Go builds)
5. **Performance**: Slight overhead from provider architecture (~5-10%)
6. **Debian Trixie**: Testing distribution (not yet stable as of 2026-04-15)

---

## Troubleshooting

### Build Fails

**Issue**: wolfSSL password error
```bash
echo 'YOUR_ACTUAL_PASSWORD' > wolfssl_password.txt
./build.sh
```

**Issue**: golang-fips/go build timeout
```bash
# Increase Docker build timeout
export DOCKER_BUILDKIT_TIMEOUT=7200
./build.sh
```

### Runtime Issues

**Issue**: "CGO_ENABLED is not set to 1"
```bash
# Check CGO configuration
docker run --rm --entrypoint "" gotenberg:8.30.0-trixie-slim-fips env | grep CGO
```

**Issue**: "Provider could not be loaded"
```bash
# Check OpenSSL configuration
docker run --rm --entrypoint "" gotenberg:8.30.0-trixie-slim-fips cat /etc/ssl/openssl.cnf

# Check provider library
docker run --rm --entrypoint "" gotenberg:8.30.0-trixie-slim-fips ls -la /usr/local/openssl/lib64/ossl-modules/libwolfprov.so
```

**Issue**: Gotenberg API errors
```bash
# Check Gotenberg logs
docker logs <container-id>

# Test service health
curl http://localhost:3000/health
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
golang-fips/go - BSD License
Gotenberg - MIT License
Container implementation - As per your organization's license

---

## References

- [wolfSSL FIPS 140-3](https://www.wolfssl.com/license/fips/)
- [wolfProvider GitHub](https://github.com/wolfSSL/wolfProvider)
- [golang-fips/go GitHub](https://github.com/golang-fips/go)
- [Gotenberg Documentation](https://gotenberg.dev/)
- [OpenSSL Providers](https://www.openssl.org/docs/man3.0/man7/provider.html)
- [FIPS 140-3 Implementation Guidance](https://csrc.nist.gov/publications/detail/fips/140/3/final)
- [FIPS 140-3 Certificate #4718](https://csrc.nist.gov/projects/cryptographic-module-validation-program/certificate/4718)

---

**Document Version:** 1.0
**Last Updated:** 2026-04-15
**Image:** gotenberg:8.30.0-trixie-slim-fips
