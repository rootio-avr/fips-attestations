# wolfSSL FIPS Java Test Application

Comprehensive test application demonstrating FIPS-compliant cryptographic and TLS operations using the wolfSSL Java container.

## Overview

This test application serves multiple purposes:
1. **Validation Tool**: Verifies FIPS-compliant crypto services are working correctly
2. **Integration Example**: Demonstrates how to use wolfJCE/wolfJSSE providers
3. **Reference Implementation**: Shows best practices for FIPS Java development
4. **Educational Resource**: Complete working examples of JCA/JSSE operations

## What This Test Application Demonstrates

### 1. JCE Cryptographic Operations (CryptoTestSuite.java)

**Purpose**: Comprehensive testing of Java Cryptography Extension (JCE) services

**Test Coverage**:
- ✅ **Message Digest**: SHA-1, SHA-224, SHA-256, SHA-384, SHA-512, SHA3-224, SHA3-256, SHA3-384, SHA3-512
- ✅ **Symmetric Encryption**: AES-GCM, AES-CBC, AES-ECB, AES-CTR, AES-OFB, AES-CCM with 128/192/256-bit keys
- ✅ **Asymmetric Encryption**: RSA (2048/3072/4096-bit) with PKCS1Padding
- ✅ **MAC Operations**: HMAC-SHA*, AES-CMAC, AES-GMAC
- ✅ **Digital Signatures**: RSA (SHA*withRSA), ECDSA (SHA*withECDSA), RSA-PSS
- ✅ **Key Generation**: AES keys, RSA key pairs (2048/3072/4096-bit), EC key pairs (P-256/P-384/P-521)
- ✅ **Key Agreement**: ECDH with various curves
- ✅ **Secure Random**: DEFAULT, HashDRBG, getInstanceStrong()

**What It Validates**:
- All operations use wolfJCE provider (priority 1)
- FIPS-approved algorithms work correctly
- Encryption/decryption round-trips succeed
- Signature generation and verification work
- Key agreement produces matching shared secrets
- SecureRandom generates unique, non-zero entropy

**Key Code Patterns Demonstrated**:
```java
// Standard JCA API usage (provider selected automatically)
MessageDigest md = MessageDigest.getInstance("SHA-256");
Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
Signature sig = Signature.getInstance("SHA256withRSA");

// Provider verification
assert "wolfJCE".equals(md.getProvider().getName());
```

### 2. JSSE/TLS Operations (TlsTestSuite.java)

**Purpose**: Comprehensive testing of Java Secure Socket Extension (JSSE) services

**Test Coverage**:
- ✅ **SSLContext Creation**: TLS, TLSv1.2, TLSv1.3, DEFAULT protocols
- ✅ **TLS Connections**: Real HTTPS connections to public endpoints (www.google.com, www.wolfssl.com, httpbin.org)
- ✅ **Certificate Validation**: TrustManagerFactory with WKS cacerts, certificate chain inspection
- ✅ **SSL Socket Creation**: Socket factory, protocol and cipher suite configuration
- ✅ **TLS Protocol Versions**: TLS 1.2 and TLS 1.3 support verification
- ✅ **Cipher Suites**: FIPS-approved cipher suite availability (AES-GCM, ECDHE)

**What It Validates**:
- All TLS operations use wolfJSSE provider (priority 2)
- SSLContext initialization works with system WKS cacerts
- TLS handshakes complete successfully
- Server certificates are validated using WKS trust store
- Certificate chains are properly inspected
- SNI (Server Name Indication) works correctly
- HTTP requests over TLS succeed

**Key Code Patterns Demonstrated**:
```java
// Standard JSSE API usage
SSLContext context = SSLContext.getInstance("TLS");
context.init(null, null, null); // Uses system WKS cacerts

// WKS trust store loading
KeyStore trustStore = KeyStore.getInstance("WKS");
trustStore.load(fis, "changeitchangeit".toCharArray());
TrustManagerFactory tmf = TrustManagerFactory.getInstance("PKIX");
tmf.init(trustStore);

// TLS connection with certificate validation
SSLSocket socket = (SSLSocket) factory.createSocket(host, 443);
SSLParameters params = socket.getSSLParameters();
params.setServerNames(Arrays.asList(new SNIHostName(host)));
socket.setSSLParameters(params);
socket.startHandshake();
```

### 3. Real-World Scenarios (FipsUserApplication.java)

**Purpose**: Demonstrate practical usage patterns for common tasks

**Scenarios Covered**:
- ✅ **File Encryption/Decryption**: AES-256-GCM for secure file handling
- ✅ **Data Signing**: RSA-2048 with SHA-256 for document signing
- ✅ **Password Hashing**: SHA-256 with salt for secure password storage
- ✅ **HTTPS Client**: Complete HTTPS client implementation

**What It Validates**:
- Provider verification at startup
- Practical integration patterns
- Error handling
- Debug logging configuration
- End-to-end workflows

**Key Code Patterns Demonstrated**:
```java
// Environment-based debug configuration
if ("true".equals(System.getenv("WOLFJCE_DEBUG"))) {
    System.setProperty("wolfjce.debug", "true");
}

// Provider verification
Provider[] providers = Security.getProviders();
if (!"wolfJCE".equals(providers[0].getName())) {
    throw new SecurityException("wolfJCE not at position 1");
}

// Practical usage
Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
SecureRandom random = new SecureRandom();
byte[] iv = new byte[12];
random.nextBytes(iv);
GCMParameterSpec spec = new GCMParameterSpec(128, iv);
cipher.init(Cipher.ENCRYPT_MODE, key, spec);
```

## Features

### Comprehensive Algorithm Coverage

**Hashing Algorithms**:
- SHA-1, SHA-224, SHA-256, SHA-384, SHA-512 (SHA-2 family)
- SHA3-224, SHA3-256, SHA3-384, SHA3-512 (SHA-3 family)

**Symmetric Encryption**:
- AES modes: CBC, ECB, CTR, GCM, CCM, OFB
- Key sizes: 128, 192, 256 bits
- Authenticated encryption: GCM, CCM

**Asymmetric Encryption**:
- RSA: 2048, 3072, 4096 bits
- Padding: PKCS1Padding

**Digital Signatures**:
- RSA signatures: SHA1/224/256/384/512 with RSA
- ECDSA signatures: SHA1/224/256/384/512 with ECDSA
- SHA3 variants: SHA3-224/256/384/512 with RSA/ECDSA
- RSA-PSS: RSASSA-PSS, SHA224/256/384/512 with RSA/PSS

**Key Agreement**:
- ECDH with curves: P-256 (secp256r1), P-384 (secp384r1), P-521 (secp521r1)

**MAC Algorithms**:
- HMAC: HmacSHA1, HmacSHA224, HmacSHA256, HmacSHA384, HmacSHA512
- HMAC-SHA3: HmacSHA3-224, HmacSHA3-256, HmacSHA3-384, HmacSHA3-512
- AES-based: AESCMAC, AES-CMAC, AESGMAC, AES-GMAC

### TLS/SSL Protocol Support

**Protocols**:
- TLS 1.2
- TLS 1.3
- Generic TLS (negotiates highest supported)

**Cipher Suites** (FIPS-approved):
- TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
- TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
- TLS_RSA_WITH_AES_128_GCM_SHA256
- TLS_RSA_WITH_AES_256_GCM_SHA384
- And more...

### Certificate and KeyStore Support

**KeyStore Types**:
- WKS (WolfSSL KeyStore) - FIPS-compliant
- System cacerts in WKS format

**Certificate Operations**:
- Loading WKS trust stores
- Certificate chain validation
- X.509 certificate inspection
- TrustManagerFactory initialization
- KeyManagerFactory initialization

## Directory Structure

```
basic-test-image/
├── README.md                      # This file
├── Dockerfile                     # Container definition extending base image
├── build.sh                       # Build script for test image
└── src/main/
    ├── FipsUserApplication.java   # Main application orchestrator
    ├── CryptoTestSuite.java       # JCE cryptographic tests
    └── TlsTestSuite.java          # JSSE/TLS connectivity tests
```

## Building the Test Application

### Prerequisites

1. **Base Image**: The `java:17-jammy-ubuntu-22.04-fips` image must be built first
   ```bash
   cd ../../..
   ./build.sh
   # (uses wolfssl_password.txt for password)
   ```

2. **Docker**: Docker must be installed and running

### Build Commands

```bash
# Basic build (uses default base image)
./build.sh

# Custom image name and tag
./build.sh -n my-test-image -t v1.0

# Use custom base image
./build.sh -b java:17-jammy-ubuntu-22.04-fips:custom

# Build without cache
./build.sh --no-cache

# Verbose output
./build.sh -v

# Show help
./build.sh -h
```

### Build Process

The build process:
1. Extends base FIPS image (`java:17-jammy-ubuntu-22.04-fips`)
2. Copies Java source files
3. Compiles with wolfJCE/wolfJSSE JARs in classpath
4. Creates executable test application
5. Sets entrypoint to run all tests

## Running the Test Application

### Complete Test Suite (Default)

Runs all tests: provider verification, cryptographic operations, TLS connectivity, and real-world scenarios.

```bash
docker run --rm wolfssl-fips-basic-test-image:latest
```

**Expected Output**:
```
=== wolfSSL Simple Java FIPS Test Application ===
Demonstrating FIPS 140-3 validated operations

=== Provider Verification ===
Currently loaded security providers:
  1. wolfJCE v1.0 - wolfSSL JCE Provider
  2. wolfJSSE v13.0 - wolfSSL JSSE Provider
  ...

=== wolfSSL FIPS JCA Cryptographic Operations Test Suite ===
Verifying wolfJCE Provider Setup:
   wolfJCE provider found: wolfJCE v1.0

Testing Message Digest Operations:
   SHA-256: a591a6d40bf420... (wolfJCE)
   ...

Testing Symmetric Encryption (AES):
   AES-GCM 256-bit: Encryption/Decryption successful (wolfJCE)
   ...

=== All JCA Cryptographic Tests PASSED ===

=== wolfSSL FIPS SSL/TLS Test Suite ===
Testing SSLContext Creation:
   SSLContext TLS: Created and initialized (wolfJSSE)
   ...

Testing TLS Connections to Public Endpoints:
   Testing connection to www.google.com:443...
     TLS handshake successful
     Protocol: TLSv1.3
     Cipher Suite: TLS_AES_128_GCM_SHA256
     Peer certificates: 3
     ...

=== All SSL/TLS Tests PASSED ===

=== FIPS Tests COMPLETED SUCCESSFULLY ===
```

### Individual Test Suites

**Run JCA Cryptographic Operations Only**:
```bash
docker run --rm wolfssl-fips-basic-test-image:latest \
  java -cp "/app/test:/opt/wolfssl-fips/bin:/usr/share/java/*" CryptoTestSuite
```

**Run SSL/TLS Operations Only**:
```bash
docker run --rm wolfssl-fips-basic-test-image:latest \
  java -cp "/app/test:/opt/wolfssl-fips/bin:/usr/share/java/*" TlsTestSuite
```

**Run with Debug Logging**:
```bash
docker run --rm \
  -e WOLFJCE_DEBUG=true \
  -e WOLFJSSE_DEBUG=true \
  wolfssl-fips-basic-test-image:latest
```

### Interactive Testing

```bash
# Interactive shell for manual testing
docker run --rm -it wolfssl-fips-basic-test-image:latest bash

# Inside container
cd /app/test
java -cp "/app/test:/opt/wolfssl-fips/bin:/usr/share/java/*" CryptoTestSuite
java -cp "/app/test:/opt/wolfssl-fips/bin:/usr/share/java/*" TlsTestSuite
```

## Using as Reference Implementation

### Example 1: Using the Crypto Patterns

You can copy code patterns from CryptoTestSuite.java:

```java
// From your application
import java.security.*;
import javax.crypto.*;
import javax.crypto.spec.*;

public class MyApp {
    public void encryptData() throws Exception {
        // Pattern from CryptoTestSuite.testAesGcm()
        KeyGenerator keyGen = KeyGenerator.getInstance("AES");
        keyGen.init(256);
        SecretKey key = keyGen.generateKey();

        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        SecureRandom random = new SecureRandom();
        byte[] iv = new byte[12];
        random.nextBytes(iv);
        GCMParameterSpec spec = new GCMParameterSpec(128, iv);

        cipher.init(Cipher.ENCRYPT_MODE, key, spec);
        byte[] encrypted = cipher.doFinal(plaintext);
    }
}
```

### Example 2: Using the TLS Patterns

You can copy TLS patterns from TlsTestSuite.java:

```java
// From your application
import javax.net.ssl.*;
import java.io.*;
import java.security.*;

public class MyHttpsClient {
    public void connect(String host, int port) throws Exception {
        // Pattern from TlsTestSuite.testTlsConnections()

        // Load WKS trust store
        String javaHome = System.getProperty("java.home");
        KeyStore trustStore = KeyStore.getInstance("WKS");
        try (FileInputStream fis = new FileInputStream(
                javaHome + "/lib/security/cacerts")) {
            trustStore.load(fis, "changeitchangeit".toCharArray());
        }

        // Create TrustManagerFactory
        TrustManagerFactory tmf = TrustManagerFactory.getInstance("PKIX");
        tmf.init(trustStore);

        // Create SSLContext
        SSLContext context = SSLContext.getInstance("TLS");
        context.init(null, tmf.getTrustManagers(), null);

        // Connect
        SSLSocketFactory factory = context.getSocketFactory();
        SSLSocket socket = (SSLSocket) factory.createSocket(host, port);

        // Set SNI
        SSLParameters params = socket.getSSLParameters();
        params.setServerNames(java.util.Arrays.asList(new SNIHostName(host)));
        socket.setSSLParameters(params);

        // Handshake
        socket.startHandshake();

        // Use socket...
        socket.close();
    }
}
```

### Example 3: Provider Verification

Pattern from FipsUserApplication.java:

```java
public void verifyProviders() {
    Provider[] providers = Security.getProviders();

    // Verify wolfJCE at position 1
    if (!"wolfJCE".equals(providers[0].getName())) {
        throw new SecurityException("wolfJCE not at position 1");
    }

    // Verify wolfJSSE at position 2
    if (!"wolfJSSE".equals(providers[1].getName())) {
        throw new SecurityException("wolfJSSE not at position 2");
    }

    System.out.println("✓ wolfJCE verified at position 1");
    System.out.println("✓ wolfJSSE verified at position 2");
}
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `JAVA_OPTS` | JVM configuration options | `-Xmx512m` |
| `JAVA_TOOL_OPTIONS` | JVM module access flags | See base image |
| `WOLFJCE_DEBUG` | Enable wolfJCE debug logging | `false` |
| `WOLFJSSE_DEBUG` | Enable wolfJSSE debug logging | `false` |
| `WOLFJSSE_ENGINE_DEBUG` | Enable wolfJSSE SSLEngine debug | `false` |
| `FIPS_CHECK` | Run FIPS validation on startup | `true` |

## Expected Test Results

### Success Criteria

All tests should pass with output similar to:

```
✓ Provider verification successful
✓ All message digest algorithms working
✓ All symmetric encryption modes working
✓ All asymmetric encryption operations working
✓ All MAC operations working
✓ All digital signature algorithms working
✓ Key generation successful
✓ Key agreement successful
✓ Secure random working
✓ SSLContext creation successful
✓ TLS connections successful
✓ Certificate validation working
✓ All tests PASSED
```

### Known Issues

**TLS Connection Failures**:
Some public endpoints may occasionally fail due to:
- Certificate using Ed25519/Ed448 (not supported in FIPS build)
- Network connectivity issues
- SNI requirements
- Firewall restrictions

These are expected and don't indicate FIPS validation failures. The test output will show:
```
Testing connection to www.example.com:443...
  Connection failed: ASN.1 parsing error (error code: -140)
  This may indicate Ed25519/Ed448 signatures (non-FIPS algorithms)
  wolfSSL FIPS build may not include required ASN.1 parsers
  wolfJSSE provider is functioning for TLS operations
```

## Troubleshooting

### Common Issues

1. **Base Image Not Found**
   ```
   Error: Base image 'java:17-jammy-ubuntu-22.04-fips' not found!
   ```
   **Solution**: Build the base image first:
   ```bash
   cd ../.. && ./build.sh
   ```

2. **Provider Not Found**
   ```
   SecurityException: wolfJCE provider not found
   ```
   **Solution**: Check base image was built correctly and includes wolfJCE JAR:
   ```bash
   docker run --rm java:17-jammy-ubuntu-22.04-fips \
     ls -la /usr/share/java/
   ```

3. **Compilation Errors**
   ```
   error: package com.wolfssl.provider.jce does not exist
   ```
   **Solution**: Ensure classpath includes wolfJCE/wolfJSSE JARs in Dockerfile

### Debug Mode

Enable verbose logging to diagnose issues:

```bash
docker run --rm \
  -e WOLFJCE_DEBUG=true \
  -e WOLFJSSE_DEBUG=true \
  -e WOLFJSSE_ENGINE_DEBUG=true \
  -e JAVA_OPTS="-Djava.security.debug=all" \
  wolfssl-fips-basic-test-image:latest
```

## Integration Examples

### Using in Your Own Application

**Dockerfile**:
```dockerfile
FROM java:17-jammy-ubuntu-22.04-fips

# Copy your application
COPY target/myapp.jar /app/myapp.jar

# Copy dependencies
COPY target/lib/*.jar /app/lib/

# Set classpath (include wolfJCE/wolfJSSE)
ENV CLASSPATH=/app/myapp.jar:/app/lib/*:/usr/share/java/*

# Run application
ENTRYPOINT ["java", "com.example.MyApplication"]
```

**Code Pattern**:
```java
import java.security.*;
import javax.crypto.*;
import javax.net.ssl.*;

public class MyApplication {
    public static void main(String[] args) {
        // Use patterns from test suites
        performCryptoOperations();
        performTlsOperations();
    }

    private static void performCryptoOperations() {
        // See CryptoTestSuite.java for examples
    }

    private static void performTlsOperations() {
        // See TlsTestSuite.java for examples
    }
}
```

## Additional Resources

- **[../../README.md](../../README.md)** - Base image documentation
- **[../../DEVELOPER-GUIDE.md](../../DEVELOPER-GUIDE.md)** - Comprehensive developer guide
- **[../../EXAMPLES.md](../../EXAMPLES.md)** - Additional code examples
- **[../../KEYSTORE-TRUST-STORE-GUIDE.md](../../KEYSTORE-TRUST-STORE-GUIDE.md)** - Keystore usage guide

## License

Same as base image:
- Ubuntu/Debian: Canonical License
- OpenJDK 19: GPL v2 with Classpath Exception
- wolfSSL FIPS: Commercial License (required)
- wolfCrypt JNI: GPL v3
- wolfSSL JNI: GPL v3

---

**Last Updated**: 2025-01-XX
**Version**: 1.0
**wolfSSL FIPS Version**: v5.8.2 (Certificate #4718)
