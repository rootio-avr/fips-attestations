# FIPS Demo Applications Docker Image

This directory contains a Docker image that extends the base FIPS Java image with pre-compiled demonstration applications.

## Overview

The demos-image builds a separate Docker image FROM the base FIPS Java image, similar to how `diagnostics/test-images/basic-test-image` is structured. This approach:

- ✅ Keeps the base image lean and production-ready
- ✅ Separates demo/test code from production code
- ✅ Allows independent versioning and updates
- ✅ Follows Docker best practices (separation of concerns)

## Documentation

- **[DEMO-RESULTS.md](DEMO-RESULTS.md)** - Comprehensive test results and analysis for all demos

## Quick Start

### Build the Demos Image

```bash
cd demos-image
chmod +x build.sh
./build.sh
```

### Run Default (Shows Available Demos)

```bash
docker run --rm java-19-jdk-bookworm-slim-fips-demos:latest
```

### Run Individual Demos

```bash
# 1. WolfJCE Blocking Demo (JCA algorithm enforcement)
docker run --rm java-19-jdk-bookworm-slim-fips-demos:latest \
  java -cp "/app/demos:/opt/wolfssl-fips/bin:/usr/share/java/*" WolfJceBlockingDemo

# 2. WolfJSSE Blocking Demo (JSSE TLS enforcement)
docker run --rm java-19-jdk-bookworm-slim-fips-demos:latest \
  java -cp "/app/demos:/opt/wolfssl-fips/bin:/usr/share/java/*" WolfJsseBlockingDemo

# 3. MD5 Availability Demo (why MD5 is available but blocked)
docker run --rm java-19-jdk-bookworm-slim-fips-demos:latest \
  java -cp "/app/demos:/opt/wolfssl-fips/bin:/usr/share/java/*" MD5AvailabilityDemo

# 4. KeyStore Format Demo (JKS vs WKS comparison)
docker run --rm java-19-jdk-bookworm-slim-fips-demos:latest \
  java -cp "/app/demos:/opt/wolfssl-fips/bin:/usr/share/java/*" KeyStoreFormatDemo
```

## Build Options

```bash
# Custom image name and tag
./build.sh --name my-fips-demos --tag v1.0

# Use custom base image
./build.sh --base java:19-jdk-bookworm-slim-fips:custom

# Build without cache (clean build)
./build.sh --no-cache

# Verbose output
./build.sh --verbose

# Show help
./build.sh --help
```

## Directory Structure

```
demos-image/
├── Dockerfile           # Builds FROM base FIPS image
├── build.sh            # Build script
├── README.md           # This file
├── DEMO-RESULTS.md     # Test results and compliance analysis
└── src/                # Demo source files
    ├── WolfJceBlockingDemo.java
    ├── WolfJsseBlockingDemo.java
    ├── MD5AvailabilityDemo.java
    └── KeyStoreFormatDemo.java
```

## Demo Applications

### 1. WolfJceBlockingDemo
**Purpose**: Demonstrates JCA algorithm blocking

**Tests**:
- ✓ Non-FIPS algorithms (MD5, DES, 3DES, RC4) are blocked
- ✓ FIPS algorithms (SHA-256, AES-GCM, RSA, EC) work correctly
- ✓ All crypto uses wolfJCE provider

### 2. WolfJsseBlockingDemo
**Purpose**: Demonstrates JSSE TLS configuration blocking

**Tests**:
- ✓ Non-FIPS protocols (SSLv2, SSLv3, TLSv1.0, TLSv1.1) are blocked
- ✓ FIPS protocols (TLSv1.2, TLSv1.3) work correctly
- ✓ Weak cipher suites are not enabled
- ✓ HTTPS connections use FIPS cipher suites

### 3. MD5AvailabilityDemo
**Purpose**: Explains why MD5 is available in FIPS mode

**Key Points**:
- MD5 is part of wolfSSL FIPS 140-3 Certificate #4718
- MD5 is BLOCKED for TLS, certificates, and JAR signing
- MD5 is available for non-security uses (backward compatibility)
- This is CORRECT FIPS 140-3 behavior

### 4. KeyStoreFormatDemo
**Purpose**: Demonstrates JKS vs WKS keystore formats

**Key Points**:
- JKS uses MD5/SHA-1 (non-FIPS) for integrity
- WKS uses FIPS-approved HMAC
- System CA certificates MUST be in WKS format
- WKS password: "changeitchangeit"

## Running with Debug Logging

```bash
docker run --rm \
  -e WOLFJCE_DEBUG=true \
  -e WOLFJSSE_DEBUG=true \
  java:19-jdk-bookworm-slim-fips \
  java -cp "/app/demos:/opt/wolfssl-fips/bin:/usr/share/java/*" WolfJceBlockingDemo
```

## Comparing with Test Images

This demos-image follows the same pattern as `diagnostics/test-images/basic-test-image`:

| Feature | test-images/basic-test-image | demos-image |
|---------|------------------------------|-------------|
| **Purpose** | Comprehensive test suite | Educational demos |
| **FROM** | Base FIPS image | Base FIPS image |
| **Pattern** | Separate derived image | Separate derived image |
| **Location** | `/app/test/*.class` | `/app/demos/*.class` |
| **Source** | `src/main/*.java` | `src/*.java` |

## Architecture

```
Base Image (java:19-jdk-bookworm-slim-fips)
  ├── wolfSSL FIPS libraries
  ├── wolfJCE/wolfJSSE providers
  ├── System configuration
  └── /opt/wolfssl-fips/bin (FipsInitCheck, etc.)
      │
      ├─> Test Image (basic-test-image)
      │     └── /app/test (FipsUserApplication, test suites)
      │
      └─> Demos Image (java:19-jdk-bookworm-slim-fips-demos)
            └── /app/demos (Demo applications)
```

## Integration with CI/CD

```yaml
# Example GitLab CI/CD
build-demos:
  stage: build
  script:
    - cd demos-image
    - ./build.sh --tag $CI_COMMIT_TAG

test-demos:
  stage: test
  script:
    - docker run --rm java:19-jdk-bookworm-slim-fips-demos:$CI_COMMIT_TAG java -cp "/app/demos:/opt/wolfssl-fips/bin:/usr/share/java/*" WolfJceBlockingDemo
    - docker run --rm java:19-jdk-bookworm-slim-fips-demos:$CI_COMMIT_TAG java -cp "/app/demos:/opt/wolfssl-fips/bin:/usr/share/java/*" WolfJsseBlockingDemo
```

## Troubleshooting

### Base image not found
```bash
cd ..
./build.sh  # Build base FIPS image first
```

### Demo source files not found
Ensure you're in the `demos-image` directory and `src/*.java` files exist.

### Compilation errors
Check that all demo files are compatible with OpenJDK 19 and use proper imports.

## See Also

- **[DEMO-RESULTS.md](DEMO-RESULTS.md)** - Complete test results and compliance analysis
- `../diagnostics/test-images/basic-test-image/` - Similar pattern for test suite
- `../DEVELOPER-GUIDE.md` - Integration guide
- `../ARCHITECTURE.md` - System architecture
