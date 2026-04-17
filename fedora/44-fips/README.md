# Fedora 44 FIPS Container

FIPS 140-3 compliant Fedora 44 container with:
- **OpenSSL 3.5.0** - Configured to use wolfSSL via wolfProvider
- **wolfSSL FIPS v5.8.2** - FIPS 140-3 Certificate #4718
- **wolfProvider v1.1.1** - OpenSSL 3.x provider for wolfSSL
- **Podman 5.8.1** - Container runtime with FIPS support

## Architecture

```
┌────────────────────────────────────────────────────────┐
│  Applications                                          │
│         ↓                                              │
│  OpenSSL 3.5.0 (FIPS mode enforced)                   │
│         ↓                                              │
│  wolfProvider v1.1.1                                   │
│         ↓                                              │
│  wolfSSL FIPS v5.8.2 (Certificate #4718)              │
└────────────────────────────────────────────────────────┘

System-wide enforcement:
- Crypto-policies: FIPS mode
- OPENSSL_FORCE_FIPS_MODE=1
- Non-FIPS algorithms blocked (MD5, etc.)
```

## Quick Start

### Basic Usage

Run the container interactively:
```bash
docker run -it cr.root.io/fedora:44-fips
```

The container will automatically:
- Verify FIPS mode configuration
- Run comprehensive crypto tests (14 tests)
- Display environment information

### Using Podman (CI/CD, Container-in-Container)

Podman requires privileged mode to function inside Docker containers:

```bash
# Run Podman commands
docker run --privileged cr.root.io/fedora:44-fips podman info

# Interactive shell with Podman support
docker run --privileged -it cr.root.io/fedora:44-fips

# Run container builds with Podman
docker run --privileged cr.root.io/fedora:44-fips podman build -t myimage .
```

### Running as Non-Root User (without Podman)

To run as the `appuser` user (UID 1001):
```bash
docker run --user appuser -it cr.root.io/fedora:44-fips
```

**Note**: Podman will not function in non-root mode within nested containers.

## FIPS Verification

### Automatic Verification

All containers automatically verify FIPS mode on startup with 14 comprehensive tests:
1. Crypto-policies configuration
2. OpenSSL FIPS provider
3. FIPS mode environment variables
4. FIPS-approved algorithms (SHA-256, SHA-384, SHA-512, AES, RSA, EC)
5. Non-FIPS algorithm blocking (MD5, etc.)

### Skip Startup Checks (Faster Startup)

For production deployments where startup time is critical:
```bash
docker run \
  -e SKIP_FIPS_CHECK=true \
  -e SKIP_INTEGRITY_CHECK=true \
  cr.root.io/fedora:44-fips
```

Environment variables:
- `SKIP_FIPS_CHECK=true` - Skip all FIPS verification checks
- `SKIP_INTEGRITY_CHECK=true` - Skip binary integrity checks
- `SKIP_DETAILED_CHECKS=true` - Skip detailed algorithm tests (quick check only)

### Manual Verification

Run FIPS verification manually:
```bash
# Comprehensive FIPS check (14 tests)
docker run --rm cr.root.io/fedora:44-fips /opt/fips/bin/fips_init_check.sh

# Quick OpenSSL provider check
docker run --rm cr.root.io/fedora:44-fips openssl list -providers

# Verify wolfSSL FIPS
docker run --rm cr.root.io/fedora:44-fips test-fips
```

## Environment Variables

The container sets the following FIPS-related environment variables:

| Variable | Value | Description |
|----------|-------|-------------|
| `OPENSSL_FORCE_FIPS_MODE` | `1` | Enforces FIPS mode at application level |
| `OPENSSL_CONF` | `/etc/ssl/openssl.cnf` | OpenSSL configuration (wolfProvider) |
| `OPENSSL_MODULES` | `/usr/lib64/ossl-modules` | OpenSSL provider modules directory |
| `LD_LIBRARY_PATH` | `/usr/local/lib:/usr/local/openssl/lib64` | FIPS library path |

## Building the Image

### Prerequisites

1. Docker with BuildKit enabled
2. `wolfssl_password.txt` file with wolfSSL FIPS package password:
   ```bash
   echo 'your-password-here' > wolfssl_password.txt
   chmod 600 wolfssl_password.txt
   ```

### Build Commands

```bash
# Standard build
./build.sh

# Build with custom tag
./build.sh --tag my-registry/fedora:44-fips

# Build without cache
./build.sh --no-cache

# Verbose build output
./build.sh --verbose
```

### Post-Build Verification

The build script automatically runs 6 verification tests:
1. OpenSSL version check
2. wolfProvider activation
3. wolfSSL FIPS verification
4. Crypto-policies configuration
5. Podman installation
6. Podman FIPS environment
7. Comprehensive FIPS tests (14 tests)

## Common Use Cases

### CI/CD Container Builds

```bash
# Build containers using Podman within the FIPS container
docker run --privileged \
  -v /path/to/context:/workspace \
  -w /workspace \
  cr.root.io/fedora:44-fips \
  podman build -t myapp:latest .
```

### FIPS-Compliant Application Runtime

```dockerfile
# Your application Dockerfile
FROM cr.root.io/fedora:44-fips

COPY myapp /app/myapp
RUN chmod +x /app/myapp

CMD ["/app/myapp"]
```

```bash
# Run your FIPS-compliant application
docker run -p 8080:8080 myapp:latest
```

### Testing Cryptographic Operations

```bash
# Test SHA-256 hashing (FIPS-approved)
docker run --rm cr.root.io/fedora:44-fips \
  bash -c 'echo "test" | openssl dgst -sha256'

# Test MD5 hashing (should be blocked)
docker run --rm cr.root.io/fedora:44-fips \
  bash -c 'echo "test" | openssl dgst -md5'  # This will fail
```

## Troubleshooting

### Podman: "cannot re-exec process"

**Problem**: Podman fails with namespace errors

**Solution**: Run with `--privileged` flag:
```bash
docker run --privileged cr.root.io/fedora:44-fips podman info
```

### FIPS Verification Fails

**Problem**: FIPS tests fail on container startup

**Solution**: Check the specific test that failed:
```bash
# Run manual verification for details
docker run --rm cr.root.io/fedora:44-fips /opt/fips/bin/fips_init_check.sh
```

### Slow Container Startup

**Problem**: Container takes long to start due to verification tests

**Solution**: Skip optional checks:
```bash
docker run -e SKIP_DETAILED_CHECKS=true cr.root.io/fedora:44-fips
```

## Security Considerations

1. **FIPS Mode**: This container enforces FIPS 140-3 cryptographic standards
2. **Default User**: Runs as `root` by default for Podman compatibility
3. **Privileged Mode**: Podman requires `--privileged` for nested containers
4. **Algorithm Blocking**: Non-FIPS algorithms (MD5, etc.) are blocked

## Verification Tools

Included verification scripts:
- `/opt/fips/bin/fips_init_check.sh` - Comprehensive FIPS verification (14 tests)
- `/usr/local/bin/integrity-check.sh` - Binary integrity verification
- `/usr/local/bin/enable-fips.sh` - FIPS mode enablement script
- `/usr/local/bin/test-fips` - wolfSSL FIPS test utility

## Technical Details

### Image Information

- Base Image: `fedora:44`
- Size: ~700MB
- Default User: `root` (can override with `--user appuser`)
- Entrypoint: `/docker-entrypoint.sh`

### FIPS Components

| Component | Version | Certificate |
|-----------|---------|-------------|
| wolfSSL FIPS | v5.8.2 | #4718 |
| OpenSSL | 3.5.0 | N/A (uses wolfSSL) |
| wolfProvider | v1.1.1 | N/A |

### Podman Configuration

- Storage Driver: overlay with fuse-overlayfs
- Network: slirp4netns for rootless support
- Runtime: crun
- Conmon: v2.2.1

## License

See repository license file for details.

## Support

For issues and questions:
- GitHub Issues: [Repository URL]
- Documentation: This README

## Changelog

### Latest Version
- Added FIPS 140-3 support with wolfSSL v5.8.2 (Certificate #4718)
- Configured OpenSSL 3.5.0 to use wolfProvider
- Installed Podman 5.8.1 with FIPS support
- Set default user to root for CI/CD compatibility
- Comprehensive FIPS verification (14 tests)
