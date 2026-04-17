# Podman 5.8.1 with FIPS 140-3 Compliance

FIPS 140-3 compliant Podman image based on Fedora 44, featuring wolfSSL FIPS v5.8.2 (Certificate #4718) and golang-fips/go v1.25 for building and running containers with validated cryptography.

## Features

- **Podman 5.8.1** built from source with FIPS-enabled Go compiler
- **wolfSSL FIPS v5.8.2** - NIST Certificate #4718
- **OpenSSL 3.5.0** with FIPS module support
- **wolfProvider v1.1.1** - OpenSSL provider for wolfSSL integration
- **golang-fips/go v1.25** - FIPS-enabled Go toolchain
- **Fedora 44** base image
- Full container management capabilities with FIPS-enforced cryptography

## FIPS Architecture

```
Podman (Go Binary)
    ↓
golang-fips/go Runtime (v1.25)
    ↓
OpenSSL 3.5.0 (System Crypto)
    ↓
wolfProvider v1.1.1 (OpenSSL Provider)
    ↓
wolfSSL FIPS v5.8.2 (Certificate #4718)
```

## Build Requirements

- Docker or Podman with BuildKit support
- wolfSSL FIPS package password (commercial license)
- Minimum 4GB RAM
- Approximately 20-30 minutes build time

## Quick Start

### 1. Prepare Secrets

Create a file containing your wolfSSL FIPS package password:

```bash
echo 'your-password-here' > wolfssl_password.txt
```

### 2. Build the Image

```bash
./build.sh
```

This will build the image as `cr.root.io/podman:5.8.1-fedora-44-fips`.

### 3. Verify Installation

```bash
# Check Podman version
docker run --rm cr.root.io/podman:5.8.1-fedora-44-fips podman --version

# Verify FIPS mode
docker run --rm cr.root.io/podman:5.8.1-fedora-44-fips test-fips

# Check OpenSSL providers
docker run --rm cr.root.io/podman:5.8.1-fedora-44-fips openssl list -providers
```

### 4. Run Diagnostic Tests

```bash
cd diagnostics
./run-diagnostics.sh
```

## Usage Examples

### Run Podman Interactive Shell

```bash
docker run --rm -it \
  --privileged \
  -v /var/lib/containers:/var/lib/containers \
  cr.root.io/podman:5.8.1-fedora-44-fips \
  /bin/bash
```

### Pull and Run a Container

```bash
docker run --rm --privileged \
  cr.root.io/podman:5.8.1-fedora-44-fips \
  bash -c "podman pull alpine:latest && podman run --rm alpine echo 'Hello FIPS'"
```

### Build a Container Image

```bash
docker run --rm --privileged \
  -v $(pwd):/workspace \
  -w /workspace \
  cr.root.io/podman:5.8.1-fedora-44-fips \
  podman build -t myimage:latest .
```

## Environment Variables

The following environment variables configure FIPS mode:

- `GOLANG_FIPS=1` - Enable FIPS mode for Go applications
- `GODEBUG=fips140=only` - Strict FIPS mode (block non-FIPS algorithms)
- `GOEXPERIMENT=strictfipsruntime` - Go runtime FIPS enforcement
- `OPENSSL_CONF=/etc/ssl/openssl.cnf` - OpenSSL configuration path
- `OPENSSL_MODULES=/usr/local/openssl/lib64/ossl-modules` - wolfProvider path

## Diagnostic Tests

The diagnostic test suite verifies:

1. **FIPS Compliance**
   - wolfSSL FIPS self-test
   - OpenSSL version and providers
   - Go FIPS mode configuration
   - Library integrity

2. **Podman Functionality**
   - Version and info commands
   - Runtime dependencies (conmon, crun, slirp4netns, fuse-overlayfs)
   - Configuration files (storage.conf, registries.conf)

3. **Cryptographic Operations**
   - RSA key generation (2048-bit)
   - Certificate generation
   - SHA-256/384/512 hashing
   - AES-256-CBC encryption
   - TLS 1.3 cipher support
   - Non-FIPS algorithm blocking (MD5)

Run all tests:

```bash
cd diagnostics
./run-diagnostics.sh
```

Results are saved to `diagnostics/Evidence/diagnostic_results_<timestamp>.txt`.

## Security Features

### FIPS-Approved Algorithms

- **Symmetric**: AES (128, 192, 256)
- **Asymmetric**: RSA (2048+), ECC (P-256, P-384, P-521)
- **Hash**: SHA-256, SHA-384, SHA-512
- **MAC**: HMAC-SHA256/384/512
- **TLS**: TLS 1.2, TLS 1.3 (FIPS-approved ciphers only)

### Blocked Non-FIPS Algorithms

- **Hash**: MD5, SHA-1
- **Symmetric**: RC4, DES, 3DES
- **TLS**: TLS 1.0, TLS 1.1
- **Ciphers**: ChaCha20-Poly1305

## Troubleshooting

### Build Failures

**Issue**: wolfSSL FIPS package download fails
```bash
# Verify secrets file exists and contains correct password
cat wolfssl_password.txt
```

**Issue**: Out of memory during build
```bash
# Increase Docker memory limit to at least 4GB
# Docker Desktop: Settings → Resources → Memory
```

### Runtime Issues

**Issue**: Podman requires privileged mode
```bash
# Most Podman operations require --privileged when running in Docker
docker run --rm --privileged cr.root.io/podman:5.8.1-fedora-44-fips podman info
```

**Issue**: FIPS mode errors
```bash
# Verify FIPS environment variables are set
docker run --rm cr.root.io/podman:5.8.1-fedora-44-fips env | grep -E '(GOLANG_FIPS|GODEBUG|OPENSSL)'
```

## Directory Structure

```
.
├── Dockerfile              # Multi-stage build definition
├── build.sh               # Build script with secrets handling
├── test-fips.c            # wolfSSL FIPS self-test utility
├── openssl.cnf            # OpenSSL configuration for wolfProvider
├── README.md              # This file
├── diagnostics/
│   ├── run-diagnostics.sh # Main diagnostic runner
│   ├── tests/
│   │   ├── fips-test.sh           # FIPS compliance tests
│   │   ├── podman-basic-test.sh   # Podman functionality tests
│   │   └── crypto-test.sh         # Cryptographic operation tests
│   └── Evidence/          # Test results and compliance evidence
└── demos-image/           # Demo examples (optional)
```

## Image Details

- **Base Image**: fedora:44
- **Podman Version**: 5.8.1
- **Go Version**: 1.25 (golang-fips/go)
- **OpenSSL Version**: 3.5.0
- **wolfSSL Version**: 5.8.2 (FIPS v5)
- **wolfProvider Version**: 1.1.1
- **FIPS Certificate**: #4718
- **Approximate Size**: 800MB-1GB

## Compliance

This image provides FIPS 140-3 validated cryptography through:

- **wolfSSL FIPS v5.8.2** - NIST Certificate #4718
- **Strict FIPS Mode** - Non-FIPS algorithms are blocked at runtime
- **Go FIPS Integration** - golang-fips/go with OpenSSL backend
- **Provider Architecture** - OpenSSL 3.x with wolfProvider

## Support

For issues related to:
- **Podman**: https://github.com/containers/podman
- **golang-fips/go**: https://github.com/golang-fips/go
- **wolfSSL FIPS**: Contact wolfSSL support
- **This Implementation**: Open an issue in the repository

## License

This implementation follows the licensing of its components:
- Podman: Apache 2.0
- golang-fips/go: BSD 3-Clause
- wolfSSL FIPS: Commercial (requires license)
- OpenSSL: Apache 2.0

## References

- [Podman Documentation](https://docs.podman.io/)
- [golang-fips/go GitHub](https://github.com/golang-fips/go)
- [wolfSSL FIPS 140-3](https://www.wolfssl.com/products/wolfssl-fips/)
- [NIST Cryptographic Module Validation Program](https://csrc.nist.gov/projects/cryptographic-module-validation-program)
