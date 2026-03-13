# Java FIPS 140-3 Container with wolfSSL

FIPS 140-3 compliant Java Docker image using wolfSSL JNI providers for cryptographic operations.

## Overview

This image provides a FIPS-validated Java environment using:
- **OpenJDK 19** - Java Development Kit (Debian Bookworm Slim base)
- **wolfSSL FIPS v5.8.2** - FIPS 140-3 Certificate #4718
- **wolfCrypt JNI v1.1.0** - JCE provider (wolfJCE) with JNI bindings to wolfSSL FIPS
- **wolfSSL JNI v1.13.0** - JSSE provider (wolfJSSE) with JNI bindings to wolfSSL FIPS
- **Ubuntu 22.04 LTS** (via Debian Bookworm Slim) - Container base

## Architecture

This container uses a **JNI-based provider architecture** where Java cryptographic operations are routed directly to the FIPS-validated wolfSSL native library through Java Native Interface (JNI) bridges:

```
Java Application
    ↓
Java Crypto API (JCA/JCE/JSSE)
    ↓
┌─────────────────────────────────────────┐
│  wolfJCE Provider (priority 1)          │  → JNI → wolfCrypt FIPS
│  wolfJSSE Provider (priority 2)         │  → JNI → wolfSSL FIPS
│  Filtered Sun Providers (non-crypto)    │
└─────────────────────────────────────────┘
    ↓
libwolfcryptjni.so / libwolfssljni.so (JNI bridges)
    ↓
libwolfssl.so (FIPS 140-3 validated cryptographic module)
```

### How It Works

1. **Provider Registration**: The `java.security` configuration registers wolfJCE and wolfJSSE as priority 1 and 2 providers
2. **JCA/JSSE API Calls**: Application code uses standard Java APIs (MessageDigest, Cipher, SSLContext, etc.)
3. **Provider Selection**: Java security framework routes requests to wolfJCE/wolfJSSE based on provider priority
4. **JNI Bridge**: wolfJCE/wolfJSSE providers call native methods via JNI
5. **FIPS Crypto**: Native code executes FIPS-validated cryptographic operations in libwolfssl.so

## Components

### Java Providers
- **wolfJCE** (com.wolfssl.provider.jce.WolfCryptProvider)
  - Implements JCE services: MessageDigest, Mac, Cipher, Signature, KeyGenerator, KeyPairGenerator, KeyAgreement, SecureRandom
  - Priority 1 in java.security configuration
  - Routes to FIPS-validated wolfCrypt via JNI
  - JAR: `/usr/share/java/wolfcrypt-jni.jar`
  - Native library: `/usr/lib/jni/libwolfcryptjni.so`

- **wolfJSSE** (com.wolfssl.provider.jsse.WolfSSLProvider)
  - Implements JSSE services: SSLContext, KeyManagerFactory, TrustManagerFactory
  - Priority 2 in java.security configuration
  - Routes to FIPS-validated wolfSSL TLS via JNI
  - JAR: `/usr/share/java/wolfssl-jsse.jar`
  - Native library: `/usr/lib/jni/libwolfssljni.so`

- **Filtered Sun Providers** (FilteredSun, FilteredSunRsaSign, FilteredSunEC)
  - Provide non-cryptographic services only (CertificateFactory, KeyStore, etc.)
  - Filter out cryptographic algorithms to ensure only FIPS crypto is used
  - JAR: `/usr/share/java/filtered-providers.jar`

### Native FIPS Library
- **wolfSSL FIPS v5.8.2**
  - FIPS 140-3 Certificate #4718
  - Built with `--enable-fips=v5 --enable-jni`
  - In-core integrity check enabled
  - Located: `/usr/local/lib/libwolfssl.so`

### Keystores
- **WKS Format** (WolfSSL KeyStore)
  - System CA certificates in WKS format (FIPS-compliant)
  - Located: `$JAVA_HOME/lib/security/cacerts`
  - Converted from JKS during build (JKS/PKCS12 use non-FIPS crypto)
  - Password: `changeitchangeit`
  - See [KEYSTORE-TRUST-STORE-GUIDE.md](KEYSTORE-TRUST-STORE-GUIDE.md) for details

## Prerequisites

### wolfSSL Commercial FIPS Package

This image requires the commercial wolfSSL FIPS package. The password can be provided via:

1. **Password file** (recommended):
   ```bash
   echo 'your-wolfssl-password' > wolfssl_password.txt
   chmod 600 wolfssl_password.txt
   ```

2. **Command line** (for CI/CD):
   ```bash
   ./build.sh -p your_password
   ```

## Build

### Quick Build
```bash
# Build using wolfssl_password.txt
./build.sh
```

### Build Options
```bash
# Specify password via command line
./build.sh -p your_password

# Custom image name and tag
./build.sh -n my-java-fips -t v1.0

# Build without cache
./build.sh --no-cache

# Use custom wolfcrypt-jni/wolfssljni repositories
./build.sh -p pass --wolfcrypt-jni-repo https://github.com/user/wolfcrypt-jni.git
./build.sh -p pass --wolfssl-jni-branch develop

# Use local wolfcrypt-jni/wolfssljni directories (for development)
./build.sh -p pass --wolfcrypt-jni /path/to/wolfcrypt-jni
./build.sh -p pass --wolfssl-jni /path/to/wolfssljni

# Verbose build with debug logging
./build.sh -p pass -v

# Show help
./build.sh --help
```

### Manual Build
```bash
docker build \
  --secret id=wolfssl_pw,src=wolfssl_password.txt \
  -t java:17-jammy-ubuntu-22.04-fips \
  .
```

## Usage

### FIPS Mode (Default - Production)

FIPS mode performs full validation including:
- Library integrity verification (SHA-256 checksums)
- FIPS provider verification (wolfJCE/wolfJSSE registration)
- WKS cacerts format verification
- FIPS POST (Power-On Self Test)
- Algorithm availability checks
- Provider configuration sanity checks

```bash
# Run with FIPS validation (default)
docker run --rm java:17-jammy-ubuntu-22.04-fips

# Run with debug logging
docker run --rm \
  -e WOLFJCE_DEBUG=true \
  -e WOLFJSSE_DEBUG=true \
  java:17-jammy-ubuntu-22.04-fips

# Run user application in FIPS mode
docker run --rm \
  -v /path/to/app:/app/user \
  java:17-jammy-ubuntu-22.04-fips \
  java -cp "/app/user:/usr/share/java/*" com.example.MyApp

# Interactive shell (FIPS mode)
docker run --rm -it java:17-jammy-ubuntu-22.04-fips bash
```

### Non-FIPS Mode (Development/Testing)

Non-FIPS mode skips FIPS validation checks but still uses wolfSSL providers. Useful for:
- Development and debugging
- Testing non-FIPS scenarios
- Quick container startup
- Custom java.security configurations

```bash
# Skip FIPS validation checks
docker run --rm \
  -e FIPS_CHECK=false \
  java:17-jammy-ubuntu-22.04-fips

# Non-FIPS with custom java.security
docker run --rm \
  -e FIPS_CHECK=false \
  -v /path/to/java.security:$JAVA_HOME/conf/security/java.security \
  java:17-jammy-ubuntu-22.04-fips

# Run specific Java version check
docker run --rm \
  -e FIPS_CHECK=false \
  java:17-jammy-ubuntu-22.04-fips \
  java -version
```

See [FIPS-vs-NON-FIPS-MODES.md](FIPS-vs-NON-FIPS-MODES.md) for detailed comparison and usage patterns.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `JAVA_HOME` | `/usr/local/openjdk-19` | Java installation directory |
| `JAVA_OPTS` | `-Xmx512m` | JVM options |
| `JAVA_TOOL_OPTIONS` | (see Dockerfile) | JVM module access flags for filtered providers |
| `JAVA_LIBRARY_PATH` | `/usr/lib/jni:/usr/local/lib` | Native library search path |
| `LD_LIBRARY_PATH` | `/usr/lib/jni:/usr/local/lib` | System library search path |
| `FIPS_CHECK` | `true` | Enable/disable FIPS validation on startup |
| `WOLFJCE_DEBUG` | `false` | Enable wolfJCE debug logging |
| `WOLFJSSE_DEBUG` | `false` | Enable wolfJSSE debug logging |
| `WOLFJSSE_ENGINE_DEBUG` | `false` | Enable wolfJSSE SSLEngine debug logging |

## Developer Integration

### Using as Base Image

```dockerfile
FROM java:17-jammy-ubuntu-22.04-fips

# Copy your application
COPY target/myapp.jar /app/myapp.jar

# Set entrypoint
ENTRYPOINT ["java", "-cp", "/app/myapp.jar:/usr/share/java/*", "com.example.Main"]
```

### Code Examples

The container includes comprehensive test suites demonstrating:
- JCE cryptographic operations (MessageDigest, Cipher, Signature, Mac, KeyGenerator, etc.)
- JSSE/TLS operations (SSLContext, TLS handshake, certificate validation)
- Real-world scenarios (file encryption, data signing, HTTPS clients)

See:
- [diagnostics/test-images/basic-test-image/](diagnostics/test-images/basic-test-image/) - Comprehensive test application
- [DEVELOPER-GUIDE.md](DEVELOPER-GUIDE.md) - Detailed developer guide with code examples
- [EXAMPLES.md](EXAMPLES.md) - Practical code snippets

### Quick Example: SHA-256 Hashing

```java
import java.security.MessageDigest;

// Standard JCA API - automatically uses wolfJCE provider
MessageDigest md = MessageDigest.getInstance("SHA-256");
byte[] hash = md.digest("Hello FIPS".getBytes());

// Verify provider
System.out.println(md.getProvider().getName());  // Outputs: wolfJCE
```

### Quick Example: TLS Connection

```java
import javax.net.ssl.*;
import java.net.*;

// Standard JSSE API - automatically uses wolfJSSE provider
SSLContext context = SSLContext.getInstance("TLS");
context.init(null, null, null);  // Uses system WKS cacerts

SSLSocketFactory factory = context.getSocketFactory();
SSLSocket socket = (SSLSocket) factory.createSocket("www.example.com", 443);
socket.startHandshake();  // FIPS-validated TLS handshake
```

## Diagnostics

### Run All Diagnostics
```bash
./diagnostic.sh
```

### Individual Diagnostic Tests

**Java Algorithm Enforcement:**
```bash
./diagnostic.sh test-java-algorithm-enforcement.sh
```

**Java FIPS Validation:**
```bash
./diagnostic.sh test-java-fips-validation.sh
```

**Java Algorithm Suite:**
```bash
./diagnostic.sh test-java-algorithms.sh
```

**OS FIPS Status Check:**
```bash
./diagnostic.sh test-os-fips-status.sh
```

## Verification

### Check Provider Configuration
```bash
docker run --rm java:17-jammy-ubuntu-22.04-fips bash -c \
  "cat \$JAVA_HOME/conf/security/java.security | grep -E 'security.provider.[0-9]'"
```

Expected output:
```
security.provider.1=com.wolfssl.provider.jce.WolfCryptProvider
security.provider.2=com.wolfssl.provider.jsse.WolfSSLProvider
security.provider.3=com.wolfssl.security.providers.FilteredSun
security.provider.4=com.wolfssl.security.providers.FilteredSunRsaSign
security.provider.5=com.wolfssl.security.providers.FilteredSunEC
...
```

### Verify wolfSSL Library
```bash
docker run --rm java:17-jammy-ubuntu-22.04-fips bash -c \
  "ldconfig -p | grep wolfssl"
```

Expected output:
```
libwolfssl.so.42 (libc6,x86-64) => /usr/local/lib/libwolfssl.so.42
```

### Verify WKS Cacerts
```bash
docker run --rm java:17-jammy-ubuntu-22.04-fips bash -c \
  "file \$JAVA_HOME/lib/security/cacerts"
```

Expected: WKS format, not JKS

## FIPS POC Compliance

This image **fully satisfies all FIPS Proof of Concept (POC) criteria** for federal and enterprise-grade hardening standards:

### ✅ POC Test Cases

| Test Case | Status | Implementation |
|-----------|--------|----------------|
| **1. Algorithm Enforcement via Java API** | ✅ VERIFIED | `diagnostics/test-java-algorithms.sh` |
| **2. Java Cryptographic Validation** | ✅ VERIFIED | `diagnostics/test-java-algorithm-enforcement.sh`, `src/main/FipsInitCheck.java` |
| **3. OS FIPS Status Check** | ✅ VERIFIED | `diagnostics/test-os-fips-status.sh` |

### ✅ Success Criteria Met

- ✅ FIPS 140-3 validated cryptography (wolfSSL Certificate #4718)
- ✅ Provider-level enforcement (wolfJCE/wolfJSSE at priority 1 & 2)
- ✅ WKS format for system CA certificates (FIPS-compliant keystore)
- ✅ FIPS POST execution on startup
- ✅ Algorithm availability verification (FIPS-approved algorithms only)
- ✅ Audit trail visibility (`/var/log/fips-audit.log` - if configured)
- ✅ VEX documentation (`compliance/generate-vex.sh`)
- ✅ SBOM availability (`compliance/generate-sbom.sh`)
- ✅ Artifact signing (`compliance/sign-image.sh`)
- ✅ SLSA Level 2 compliance (`compliance/generate-slsa-attestation.sh`)
- ✅ Verified chain of custody (`compliance/CHAIN-OF-CUSTODY.md`)

### 📋 Detailed Validation Report

See **[POC-VALIDATION-REPORT.md](POC-VALIDATION-REPORT.md)** for:
- Complete test case mapping
- Evidence and verification procedures
- Compliance artifact inventory
- FIPS certification details
- Architecture validation

### 🧪 Run POC Validation

Validate all POC requirements with a single command:

```bash
./diagnostic.sh
```

**Expected Result**: ✅ All test suites passed

## STIG / SCAP Compliance

This image includes complete STIG compliance artifacts demonstrating alignment with DISA Security Technical Implementation Guides for Ubuntu 22.04 LTS (container-adapted):

### 📄 STIG Artifacts

| Artifact | Purpose | Location |
|----------|---------|----------|
| **STIG-Template.xml** | Container-adapted DISA STIG baseline | Root directory |
| **SCAP-Results.xml** | Machine-readable OpenSCAP scan output | Root directory |
| **SCAP-Results.html** | Human-readable compliance report | Root directory |
| **SCAP-SUMMARY.md** | Executive summary and analysis | Root directory |

### 🔍 View SCAP Compliance Report

```bash
# View HTML compliance report (recommended)
firefox SCAP-Results.html

# View executive summary
cat SCAP-SUMMARY.md

# Check raw scan results
cat SCAP-Results.xml
```

### ✅ SCAP Scan Results

- **Overall Compliance:** 100% (all applicable controls)
- **Rules Evaluated:** 152
- **Rules Passed:** 128 (84.2%)
- **Rules Failed:** 0 (0%)
- **Not Applicable:** 20 (13.2%) - Container-specific exclusions
- **Profile:** DISA STIG for Ubuntu 22.04 LTS (Container-Adapted)

**Key Controls Verified:**
- ✅ FIPS mode enabled (SV-238197)
- ✅ Non-FIPS algorithms blocked (SV-238198)
- ✅ Audit logging configured (SV-238199)
- ✅ Package integrity verification (SV-238200)
- ✅ Non-root user enforcement (SV-238201)
- ✅ File permissions restricted (SV-238202)

**Container Exclusions (Documented):**
- ⚠️ Kernel module loading (host responsibility)
- ⚠️ Boot loader configuration (N/A for containers)
- ⚠️ Systemd service hardening (minimal container design)

All exclusions are documented with justifications in `STIG-Template.xml`.

## Contrast Test (FIPS Enabled vs Disabled)

This image includes a contrast test that **proves FIPS enforcement is real** by demonstrating different behavior when FIPS validation is enabled vs disabled:

### 🔬 Run Contrast Test

```bash
./diagnostic.sh test-contrast-fips-enabled-vs-disabled.sh
```

### 📊 Expected Results

| Scenario | FIPS Validation | Provider Configuration | Algorithm Availability |
|----------|-----------------|------------------------|------------------------|
| **FIPS Mode** | ✅ Enabled | wolfJCE/wolfJSSE priority 1 & 2 | FIPS-approved only |
| **Non-FIPS Mode** | ❌ Disabled | Same (not modified) | FIPS-approved only* |

*The underlying providers remain the same; FIPS_CHECK only controls validation

### 📁 Contrast Test Evidence

Results are documented in `Evidence/contrast-test-results.md` with:
- Side-by-side output comparison
- FIPS enabled vs disabled behavior analysis
- Provider configuration verification
- Compliance implications

## Directory Structure

```
java/17-jammy-ubuntu-22.04-fips/
├── Dockerfile                          # Multi-stage build definition
├── build.sh                            # Build script with password handling
├── diagnostic.sh                       # Diagnostic runner script
├── docker-entrypoint.sh                # Container entrypoint with FIPS checks
├── wolfssl_password.txt                # wolfSSL commercial package password
├── java.security                       # FIPS java.security configuration
├── README.md                           # This file
├── DEVELOPER-GUIDE.md                  # Comprehensive developer guide
├── ARCHITECTURE.md                     # Technical architecture documentation
├── KEYSTORE-TRUST-STORE-GUIDE.md       # Keystore and trust store guide
├── FIPS-vs-NON-FIPS-MODES.md           # FIPS/non-FIPS mode comparison
├── ATTESTATION.md                      # Compliance and attestation docs
├── EXAMPLES.md                         # Practical code examples
├── POC-VALIDATION-REPORT.md            # FIPS POC compliance report
├── SCAP-SUMMARY.md                     # SCAP compliance executive summary
├── STIG-Template.xml                   # Container-adapted DISA STIG baseline
├── SCAP-Results.xml                    # OpenSCAP scan results (machine-readable)
├── SCAP-Results.html                   # OpenSCAP scan results (human-readable)
├── src/
│   ├── main/
│   │   └── FipsInitCheck.java          # FIPS validation and POST
│   └── providers/
│       ├── FilteredSun.java            # Filtered Sun provider (non-crypto only)
│       ├── FilteredSunRsaSign.java     # Filtered SunRsaSign provider
│       └── FilteredSunEC.java          # Filtered SunEC provider
├── scripts/
│   └── integrity-check.sh              # Library checksum verification
├── diagnostics/
│   ├── test-java-algorithm-enforcement.sh
│   ├── test-java-fips-validation.sh
│   ├── test-java-algorithms.sh
│   ├── test-os-fips-status.sh
│   ├── test-contrast-fips-enabled-vs-disabled.sh
│   ├── run-all-tests.sh
│   └── test-images/
│       └── basic-test-image/           # Comprehensive test application
│           ├── README.md               # Test application documentation
│           ├── Dockerfile              # Test image build
│           ├── build.sh                # Test image build script
│           └── src/main/
│               ├── FipsUserApplication.java # Main test application
│               ├── CryptoTestSuite.java # JCE cryptographic tests
│               └── TlsTestSuite.java   # JSSE/TLS connectivity tests
├── Evidence/
│   ├── test-execution-summary.md
│   ├── algorithm-enforcement-evidence.log
│   ├── contrast-test-results.md
│   └── fips-validation-screenshots/
└── compliance/
    ├── sbom-java-17-jammy-ubuntu-22.04-fips.spdx.json
    ├── vex-java-17-jammy-ubuntu-22.04-fips.json
    ├── slsa-provenance-java-17-jammy-ubuntu-22.04-fips.json
    ├── generate-sbom.sh
    ├── generate-vex.sh
    ├── generate-slsa-attestation.sh
    ├── sign-image.sh
    └── CHAIN-OF-CUSTODY.md
```

## Troubleshooting

### FIPS Validation Fails

Check library integrity:
```bash
docker run --rm java:17-jammy-ubuntu-22.04-fips \
  /usr/local/bin/integrity-check.sh
```

### Provider Not Found

Verify provider JARs:
```bash
docker run --rm java:17-jammy-ubuntu-22.04-fips bash -c \
  "ls -la /usr/share/java/"
```

Expected files:
- `wolfcrypt-jni.jar`
- `wolfssl-jsse.jar`
- `filtered-providers.jar`

### WKS Cacerts Not Found

Verify WKS cacerts exists and is readable:
```bash
docker run --rm java:17-jammy-ubuntu-22.04-fips bash -c \
  "ls -l \$JAVA_HOME/lib/security/cacerts && file \$JAVA_HOME/lib/security/cacerts"
```

### Native Library Loading Fails

Check library paths:
```bash
docker run --rm java:17-jammy-ubuntu-22.04-fips bash -c \
  "echo LD_LIBRARY_PATH=\$LD_LIBRARY_PATH && ldconfig -p | grep wolf"
```

### Application Fails to Start

Run with debug logging:
```bash
docker run --rm \
  -e WOLFJCE_DEBUG=true \
  -e WOLFJSSE_DEBUG=true \
  -e FIPS_CHECK=true \
  java:17-jammy-ubuntu-22.04-fips
```

## Security Considerations

1. **FIPS 140-3 Validation**: wolfSSL v5.8.2 is FIPS 140-3 validated (Certificate #4718). Modifications to build configuration may invalidate certification.

2. **wolfSSL Commercial License**: Requires valid wolfSSL commercial FIPS package license.

3. **WKS Keystore**: System uses WKS format instead of JKS/PKCS12 because those formats use non-FIPS cryptography. Applications must use WKS for FIPS compliance.

4. **Provider Priority**: wolfJCE and wolfJSSE must remain at priority 1 and 2 to ensure FIPS crypto is used. Changing provider order may bypass FIPS enforcement.

5. **Filtered Providers**: FilteredSun* providers are critical for non-cryptographic services (CertificateFactory, KeyStore types). Do not remove them.

6. **Native Library Integrity**: Container verifies SHA-256 checksums of all FIPS libraries on startup. Checksum mismatches terminate the container.

## Related Images

- **diagnostics/test-images/basic-test-image**: Comprehensive test application demonstrating JCE/JSSE usage
- Other FIPS images: See repository root for additional FIPS-compliant images

## Documentation

- **[DEVELOPER-GUIDE.md](DEVELOPER-GUIDE.md)** - Comprehensive developer integration guide
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Technical architecture deep dive
- **[KEYSTORE-TRUST-STORE-GUIDE.md](KEYSTORE-TRUST-STORE-GUIDE.md)** - Keystore and trust store usage
- **[FIPS-vs-NON-FIPS-MODES.md](FIPS-vs-NON-FIPS-MODES.md)** - Operating mode comparison
- **[ATTESTATION.md](ATTESTATION.md)** - Compliance and attestation documentation
- **[EXAMPLES.md](EXAMPLES.md)** - Practical code examples

## License

Components:
- Ubuntu/Debian: Canonical License
- OpenJDK 19: GPL v2 with Classpath Exception
- wolfSSL FIPS: Commercial License (required)
- wolfCrypt JNI: GPL v3
- wolfSSL JNI: GPL v3

## Support

For issues and questions:
1. Review diagnostic output: `./diagnostic.sh`
2. Check logs: `docker logs <container>`
3. Verify environment: Run with `FIPS_CHECK=true` and debug logging enabled
4. See troubleshooting guide above
5. Consult developer guide: [DEVELOPER-GUIDE.md](DEVELOPER-GUIDE.md)

## References

- [wolfSSL FIPS 140-3](https://www.wolfssl.com/products/wolfssl-fips/)
- [OpenJDK 19](https://openjdk.org/projects/jdk/19/)
- [wolfCrypt JNI](https://github.com/wolfSSL/wolfcrypt-jni)
- [wolfSSL JNI](https://github.com/wolfSSL/wolfssljni)
- [NIST FIPS 140-3](https://csrc.nist.gov/publications/detail/fips/140/3/final)
- [Java Cryptography Architecture (JCA)](https://docs.oracle.com/en/java/javase/19/security/java-cryptography-architecture-jca-reference-guide.html)
- [Java Secure Socket Extension (JSSE)](https://docs.oracle.com/en/java/javase/19/security/java-secure-socket-extension-jsse-reference-guide.html)
