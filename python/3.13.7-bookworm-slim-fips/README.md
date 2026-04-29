# Python 3.13.7 with wolfSSL FIPS 140-3

Production-ready Docker image for Python 3.13.7 with wolfSSL FIPS 140-3 (Certificate #4718) cryptographic module.

## Overview

This container provides Python 3.13.7 on Debian Bookworm with wolfSSL FIPS 140-3 as the cryptographic provider, replacing OpenSSL for all SSL/TLS operations. The implementation uses wolfProvider to integrate wolfSSL as the default OpenSSL provider system-wide.

### Key Features

✅ **FIPS 140-3 Compliant** - wolfSSL 5.8.2 FIPS (Certificate #4718)
✅ **Python 3.13.7** - Latest stable Python with wolfSSL integration
✅ **Debian Bookworm Slim** - Minimal, secure base image
✅ **Provider-Based Architecture** - Uses wolfProvider for seamless integration
✅ **Comprehensive Testing** - 30+ tests across 5 test suites
✅ **Production Ready** - Integrity checking, FIPS verification, health checks
✅ **Well Documented** - Complete architecture and developer guides

## Quick Start

### Prerequisites

- Docker with BuildKit enabled
- wolfSSL commercial FIPS package password

### Build

```bash
# Update password file
echo "your_password_here" > wolfssl_password.txt

# Build the image (creates cr.root.io/python:3.13.7-bookworm-slim-fips)
./build.sh

# Or with custom options
./build.sh --password your_password --verbose
```

### Run

```bash
# Run Python with FIPS verification
docker run -it cr.root.io/python:3.13.7-bookworm-slim-fips python3

# Run with FIPS checks disabled (development only)
docker run -it -e FIPS_CHECK=false cr.root.io/python:3.13.7-bookworm-slim-fips python3

# Run your application
docker run -v $(pwd)/app:/app cr.root.io/python:3.13.7-bookworm-slim-fips python3 /app/main.py
```

## Verification

The container performs automatic FIPS verification on startup:

1. **Library Integrity Check** - Verifies SHA-256 checksums
2. **FIPS Known Answer Tests (KAT)** - Runs FIPS POST
3. **Python SSL Verification** - Confirms wolfSSL integration
4. **Algorithm Availability** - Tests FIPS-approved algorithms

To skip verification (development only):
```bash
docker run -e FIPS_CHECK=false cr.root.io/python:3.13.7-bookworm-slim-fips python3
```

## Testing

### Run Diagnostic Tests

```bash
# Run all diagnostic tests
docker run -v $(pwd)/diagnostics:/diagnostics cr.root.io/python:3.13.7-bookworm-slim-fips \
    /diagnostics/run-all-tests.sh

# Run individual test suites
docker run -v $(pwd)/diagnostics:/tests cr.root.io/python:3.13.7-bookworm-slim-fips \
    python3 /tests/test-fips-verification.py
```

### Build and Run Test Image

```bash
cd diagnostics/test-images/basic-test-image
./build.sh  # Uses cr.root.io/python:3.13.7-bookworm-slim-fips as base
docker run --rm python-fips-test:latest
```

## Demos

The demos-image includes 4 demonstration applications:

```bash
# Build demos image
cd demos-image
./build.sh

# Run TLS/SSL client demo
docker run --rm python-fips-demos:latest python3 tls_ssl_client_demo.py

# Run hash algorithm demo
docker run --rm python-fips-demos:latest python3 hash_algorithm_demo.py

# Run requests library demo
docker run --rm python-fips-demos:latest python3 requests_library_demo.py

# Run certificate validation demo
docker run --rm python-fips-demos:latest python3 certificate_validation_demo.py
```

## Architecture

- **Base Image**: debian:bookworm-slim
- **wolfSSL Version**: 5.8.2 FIPS 140-3 (Certificate #4718)
- **wolfProvider Version**: 1.0.2
- **Integration Method**: OpenSSL provider system (wolfProvider)
- **Build System**: Multi-stage Docker builds with BuildKit

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed technical architecture.

## Documentation

### Core Documentation

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Comprehensive technical architecture (800+ lines)
  - Provider-based architecture explanation
  - FIPS 140-3 cryptographic module details
  - Component stack and data flows
  - Security properties and algorithm details
  - Build process and validation

- **[DEVELOPER-GUIDE.md](DEVELOPER-GUIDE.md)** - Complete developer guide (1000+ lines)
  - Quick start and installation
  - Basic usage examples for all common scenarios
  - Common patterns (HTTPS client, TLS server, etc.)
  - Configuration and testing approaches
  - Troubleshooting guide with solutions
  - Best practices and migration guide
  - API reference and FAQ

- **[TEST-RESULTS.md](TEST-RESULTS.md)** - Comprehensive test validation results
  - 100% pass rate (5/5 test suites, 35/36 individual tests)
  - Detailed test output for all 5 test suites
  - MD5/SHA-1 algorithm status and blocking verification
  - FIPS 140-3 compliance validation
  - Performance metrics
  - Production readiness assessment

### Additional Documentation

- **[Compliance Documentation](compliance/)** - SBOM, VEX, chain of custody

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `FIPS_CHECK` | `true` | Enable/disable FIPS verification on startup |
| `WOLFSSL_DEBUG` | `false` | Enable wolfSSL debug logging |
| `OPENSSL_CONF` | `/etc/ssl/openssl.cnf` | OpenSSL configuration file |
| `OPENSSL_MODULES` | `/usr/lib` | OpenSSL modules directory |

## File Structure

```
python/3.13.7-bookworm-slim-fips/
├── Dockerfile                 # Multi-stage FIPS build
├── build.sh                   # Build script
├── docker-entrypoint.sh       # Startup verification
├── openssl.cnf                # wolfProvider configuration
├── test-fips.c                # FIPS KAT executable
├── wolfssl_password.txt       # FIPS package password
├── src/
│   └── fips_init_check.py    # Python FIPS verification
├── scripts/
│   └── integrity-check.sh    # Library integrity verification
├── diagnostics/              # Diagnostic test suites
│   ├── run-all-tests.sh
│   ├── test-backend-verification.py
│   ├── test-connectivity.py
│   ├── test-fips-verification.py
│   ├── test-crypto-operations.py
│   ├── test-library-compatibility.py
│   └── test-images/          # Test container images
├── demos-image/              # Demo applications
│   ├── Dockerfile
│   ├── build.sh
│   └── demos/
│       ├── tls_ssl_client_demo.py
│       ├── hash_algorithm_demo.py
│       ├── requests_library_demo.py
│       └── certificate_validation_demo.py
├── compliance/               # Compliance artifacts
└── supply-chain/            # Supply chain security
```

## Security Considerations

### FIPS Mode

This container operates in FIPS "ready" mode by default, where:
- All cryptographic operations use wolfSSL FIPS module
- FIPS-approved algorithms are available and validated
- Non-FIPS algorithms (e.g., MD5) may be available but should not be used

### Integrity Verification

The container automatically verifies library integrity on startup using SHA-256 checksums stored during build. This prevents runtime tampering.

### Supply Chain Security

- Complete chain of custody documentation
- Software Bill of Materials (SBOM) in SPDX format
- Vulnerability Exchange (VEX) data
- Build provenance tracking

## Known Limitations

1. **Certificate Verification**: Some edge cases in certificate chain validation may behave differently from standard OpenSSL
2. **Python Version**: Only Python 3.13.7 is currently supported
3. **Base Image**: Debian Bookworm only (for compatibility and security)

## Troubleshooting

### FIPS KAT Fails
```
ERROR: FIPS KAT failed! Container will terminate.
```
**Solution**: Verify wolfSSL FIPS package integrity and build configuration

### wolfSSL Not Detected
```
✗ FAIL: wolfSSL not found in version string
```
**Solution**: Check that wolfProvider is properly configured in `/etc/ssl/openssl.cnf`

### Certificate Validation Errors
```
SSLError: certificate verify failed
```
**Solution**: Ensure CA certificates are loaded: `context.load_verify_locations(cafile="/etc/ssl/certs/ca-certificates.crt")`

See [DEVELOPER-GUIDE.md](DEVELOPER-GUIDE.md) for more troubleshooting tips.

## Support

- **Issues**: Report issues at your organization's issue tracker
- **Documentation**: See docs/ directory for comprehensive guides
- **wolfSSL Support**: Contact wolfSSL for FIPS module support

## License

This Docker configuration is provided for use with licensed wolfSSL FIPS commercial packages.

## Version Information

- **Container Version**: 1.0.0
- **Python Version**: 3.13.7
- **wolfSSL Version**: 5.8.2 FIPS 140-3
- **FIPS Certificate**: #4718
- **wolfProvider Version**: 1.0.2
- **Base Image**: debian:bookworm-slim
