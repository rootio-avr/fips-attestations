# Fedora 44 with FIPS 140-3 Support

A minimal FIPS-compliant base image using Fedora's native crypto-policies system and OpenSSL FIPS provider.

This is a **minimal base image** with no language runtimes (Node.js, Python, etc.), designed to be a lightweight foundation for building FIPS-compliant applications.

## Quick Start

### Build the Image
```bash
./build.sh
```

### Run the Container
```bash
docker run --rm -it cr.root.io/fedora:44-fips
```

### Verify FIPS Mode
```bash
# Run comprehensive FIPS verification
docker run --rm cr.root.io/fedora:44-fips /opt/fips/bin/fips_init_check.sh

# Check OpenSSL FIPS provider
docker run --rm cr.root.io/fedora:44-fips openssl list -providers
```

## FIPS Architecture

This image uses **Fedora's native FIPS approach**:

1. **Crypto-Policies Framework**: System-wide cryptographic policy management
2. **OpenSSL FIPS Provider**: Built-in FIPS module (no custom compilation needed)
3. **Application-Level FIPS**: `OPENSSL_FORCE_FIPS_MODE=1` forces FIPS mode

### Key Differences from wolfSSL Images

| Aspect | Fedora FIPS | wolfSSL FIPS |
|--------|-------------|--------------|
| Approach | System crypto-policies | Custom build |
| OpenSSL | Native Fedora package | Compiled from source |
| FIPS Module | OpenSSL FIPS provider | wolfSSL FIPS 5.8.2 |
| Complexity | Simple | Complex build |
| Compatibility | Fedora ecosystem | Cross-platform |

## Verification

### Verify FIPS Mode
```bash
# Run comprehensive shell-based FIPS verification (14 tests)
docker run --rm cr.root.io/fedora:44-fips /opt/fips/bin/fips_init_check.sh

# Check crypto-policies configuration
docker run --rm cr.root.io/fedora:44-fips cat /etc/crypto-policies/config

# Check OpenSSL FIPS provider status
docker run --rm cr.root.io/fedora:44-fips openssl list -providers

# Test FIPS-approved algorithm (SHA-256)
docker run --rm cr.root.io/fedora:44-fips sh -c 'echo "test" | openssl dgst -sha256'

# Verify non-FIPS algorithm is blocked (MD5)
docker run --rm cr.root.io/fedora:44-fips sh -c 'echo "test" | openssl dgst -md5 || echo "MD5 correctly blocked"'
```

## Components Included

- **Base**: Fedora 44 (minimal)
- **OpenSSL**: 3.x with FIPS provider
- **Crypto-Policies**: FIPS mode enabled
- **Shell-based FIPS Verification**: Comprehensive 14-test suite
- **No Language Runtimes**: Pure minimal base image

## Environment Variables

- `OPENSSL_FORCE_FIPS_MODE=1` - Force OpenSSL FIPS mode
- `SKIP_FIPS_CHECK=true` - Skip startup FIPS verification
- `SKIP_INTEGRITY_CHECK=true` - Skip integrity checks
- `SKIP_DETAILED_CHECKS=true` - Skip detailed FIPS tests at startup

## Verification Scripts

Located in `/opt/fips/bin/`:
- `fips_init_check.sh` - Comprehensive shell-based FIPS validation (14 tests)

Located in `/usr/local/bin/`:
- `integrity-check.sh` - Verify checksums of FIPS verification scripts
- `enable-fips.sh` - Enable FIPS mode at runtime

## Important Notes

### Container FIPS Limitations

- **Kernel FIPS**: Full kernel-level FIPS requires host support
- **Application FIPS**: This image provides application-level FIPS via `OPENSSL_FORCE_FIPS_MODE`
- **Crypto-Policies**: Configures system-wide cryptographic settings

### Use Cases

- **Minimal FIPS base image** - Foundation for building custom FIPS-compliant containers
- **Multi-stage builds** - Use as a FIPS-enabled base layer in Dockerfiles
- **Testing FIPS compliance** - Verify cryptographic operations in FIPS mode
- **Educational purposes** - Learn about FIPS mode and crypto-policies
- **Language runtime parent** - Build Node.js, Python, Go, etc. images on top

## Why Minimal?

This image intentionally excludes language runtimes to:
- **Reduce attack surface** - Fewer packages mean fewer vulnerabilities
- **Smaller image size** - ~30% smaller than images with Node.js/Python (~350MB vs ~500MB)
- **Flexibility** - Install only what your application needs
- **Clean foundation** - No runtime version conflicts or dependency issues
- **Supply chain security** - Less third-party code to audit and maintain

## Build Information

- **Image**: `cr.root.io/fedora:44-fips`
- **Base**: `fedora:44`
- **Image Type**: Minimal base image (no language runtimes)
- **FIPS Method**: Crypto-policies + OpenSSL FIPS provider
- **Verification**: Shell-based (14 comprehensive tests)
- **Size**: ~350 MB (30% smaller than full-featured version)
- **Maintained by**: root.io Inc.

## License

See repository LICENSE file.

## Support

For issues and questions, please refer to the project documentation or contact the maintainers.
