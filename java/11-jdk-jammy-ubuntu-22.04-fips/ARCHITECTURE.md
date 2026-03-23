# Technical Architecture Documentation

Comprehensive technical architecture documentation for the wolfSSL FIPS 140-3 Java container.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Component Layers](#component-layers)
3. [Provider Architecture](#provider-architecture)
4. [JNI Architecture](#jni-architecture)
5. [Security Architecture](#security-architecture)
6. [Build Architecture](#build-architecture)
7. [Deployment Architecture](#deployment-architecture)
8. [Data Flow Examples](#data-flow-examples)

---

## Architecture Overview

### High-Level System Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                       Application Layer                          │
│  User Java Application (JCA/JCE/JSSE standard APIs)             │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ↓
┌──────────────────────────────────────────────────────────────────┐
│                   Java Security Framework                         │
│  - Algorithm/provider lookup                                     │
│  - Provider selection by priority                                │
│  - Security manager integration                                  │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ↓
┌──────────────────────────────────────────────────────────────────┐
│              Security Provider Layer (java.security)              │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │ 1. wolfJCE  (com.wolfssl.provider.jce.WolfCryptProvider)  │  │
│  │    Services: MessageDigest, Cipher, Signature, Mac,       │  │
│  │             KeyGenerator, KeyPairGenerator, KeyAgreement   │  │
│  └────────────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │ 2. wolfJSSE (com.wolfssl.provider.jsse.WolfSSLProvider)   │  │
│  │    Services: SSLContext, KeyManagerFactory,               │  │
│  │             TrustManagerFactory, KeyStore.WKS             │  │
│  └────────────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │ 3-5. FilteredSun* (non-crypto services only)              │  │
│  │    Services: CertificateFactory, Policy (JKS not a FIPS keystore service) │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ↓
┌──────────────────────────────────────────────────────────────────┐
│                      JNI Bridge Layer                             │
│  ┌─────────────────────────────┬──────────────────────────────┐  │
│  │ libwolfcryptjni.so          │ libwolfssljni.so            │  │
│  │ - JNI bindings for wolfCrypt│ - JNI bindings for wolfSSL  │  │
│  │ - Memory management         │ - TLS state management      │  │
│  │ - Error translation         │ - Socket integration        │  │
│  └─────────────────────────────┴──────────────────────────────┘  │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ↓
┌──────────────────────────────────────────────────────────────────┐
│         FIPS 140-3 Validated Cryptographic Module                │
│  libwolfssl.so (wolfSSL FIPS v5.8.2, Certificate #4718)         │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │ FIPS Boundary                                              │  │
│  │ ┌──────────────┬──────────────┬──────────────────────────┐ │  │
│  │ │ wolfCrypt    │ wolfSSL TLS  │ wolfCrypt FIPS Module    │ │  │
│  │ │ Algorithms   │ Protocol     │ (validated)              │ │  │
│  │ └──────────────┴──────────────┴──────────────────────────┘ │  │
│  │ - Power-On Self Test (POST)                                │  │
│  │ - In-core integrity verification                           │  │
│  │ - FIPS-approved algorithms only                            │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

### Architecture Principles

1. **Standard Java APIs**: Application code uses unmodified JCA/JCE/JSSE APIs
2. **Provider Abstraction**: Java security framework routes to FIPS providers transparently
3. **JNI Boundary**: Clean separation between Java and native code
4. **FIPS Boundary**: All crypto operations within FIPS-validated module
5. **Minimal Attack Surface**: Only necessary components included

---

## Component Layers

### Layer 1: Application Layer

**Purpose**: User application code

**Components**:
- Custom Java applications
- Third-party libraries
- Standard Java SE APIs

**Characteristics**:
- No awareness of FIPS implementation
- Uses standard `java.security.*` and `javax.crypto.*` packages
- No code changes required for FIPS compliance

**Example**:
```java
// Standard code - no FIPS-specific modifications
MessageDigest md = MessageDigest.getInstance("SHA-256");
byte[] hash = md.digest(data);
```

### Layer 2: Java Security Framework

**Purpose**: Provider management and algorithm dispatch

**Components**:
- `java.security.Security` - Provider registry
- `java.security.Provider` - Provider base class
- Algorithm service interfaces

**Responsibilities**:
- Maintain ordered list of security providers
- Route algorithm requests to appropriate provider
- Manage security properties from `java.security` file

**Provider Selection Algorithm**:
```java
// Pseudo-code for getInstance()
for (Provider p : providers) {  // Ordered by priority
    if (p.supportsService(service, algorithm)) {
        return p.createService(service, algorithm);
    }
}
throw new NoSuchAlgorithmException();
```

### Layer 3: Security Provider Layer

**Purpose**: Implement cryptographic services

**Components**:

**wolfJCE (Priority 1)**:
- Location: `/usr/share/java/wolfcrypt-jni.jar`
- Class: `com.wolfssl.provider.jce.WolfCryptProvider`
- Version: 1.0
- Services:
  - `MessageDigest`: SHA-*, SHA3-*
  - `Mac`: HmacSHA*, AESCMAC, AESGMAC
  - `Cipher`: AES (all modes), RSA
  - `Signature`: SHA*withRSA, SHA*withECDSA, RSASSA-PSS
  - `KeyGenerator`: AES, HMAC*
  - `KeyPairGenerator`: RSA, EC, DH
  - `KeyAgreement`: ECDH, DH
  - `SecureRandom`: HashDRBG, DEFAULT
  - `KeyStore`: WKS

**wolfJSSE (Priority 2)**:
- Location: `/usr/share/java/wolfssl-jsse.jar`
- Class: `com.wolfssl.provider.jsse.WolfSSLProvider`
- Version: 13.0
- Services:
  - `SSLContext`: TLS, TLSv1.2, TLSv1.3, DEFAULT
  - `KeyManagerFactory`: PKIX, X509, SunX509
  - `TrustManagerFactory`: PKIX, X509, SunX509
  - `KeyStore`: WKS

**FilteredSun* (Priority 3-5)**:
- Location: `/usr/share/java/filtered-providers.jar`
- Classes: `FilteredSun`, `FilteredSunRsaSign`, `FilteredSunEC`
- Purpose: Non-cryptographic services (CertificateFactory, Policy, etc.)
- Filtering: Removes cryptographic algorithms from original Sun providers

### Layer 4: JNI Bridge Layer

**Purpose**: Java ↔ Native code interface

**Components**:

**libwolfcryptjni.so**:
- Location: `/usr/lib/jni/libwolfcryptjni.so`
- Source: https://github.com/wolfSSL/wolfcrypt-jni
- Responsibilities:
  - Translate JCA/JCE calls to native wolfCrypt API
  - Memory management (Java ↔ C)
  - Exception handling
  - Object lifecycle management

**libwolfssljni.so**:
- Location: `/usr/lib/jni/libwolfssljni.so`
- Source: https://github.com/wolfSSL/wolfssljni
- Responsibilities:
  - Translate JSSE calls to native wolfSSL API
  - TLS session management
  - Socket integration
  - Certificate chain handling

**JNI Call Flow**:
```
Java:     MessageDigest.getInstance("SHA-256").digest(data)
          ↓
wolfJCE:  WolfCryptMessageDigest.engineDigest(data)
          ↓
JNI:      native int wc_Sha256Final(long ctx, byte[] hash)
          ↓
Native:   wc_Sha256Final((wc_Sha256*)ctx, hash)  [libwolfssl.so]
```

### Layer 5: FIPS Cryptographic Module

**Purpose**: FIPS-validated cryptographic operations

**Component**: libwolfssl.so

**Details**:
- Version: wolfSSL FIPS v5.8.2
- Certificate: FIPS 140-3 #4718
- Location: `/usr/local/lib/libwolfssl.so.44`
- Build Options:
  - `--enable-fips=v5` (FIPS 140-3 mode)
  - `--enable-jni` (JNI support)
  - `--enable-static` (static library for FIPS boundary)
  - `--enable-shared` (shared library for runtime)

**FIPS Boundary**:
- All cryptographic operations occur within this module
- In-core integrity verification on load
- Power-On Self Test (POST) executed on first use
- Only FIPS-approved algorithms accessible

---

## Provider Architecture

### Provider Registration

**Configuration File**: `$JAVA_HOME/conf/security/java.security`

```properties
security.provider.1=com.wolfssl.provider.jce.WolfCryptProvider
security.provider.2=com.wolfssl.provider.jsse.WolfSSLProvider
security.provider.3=com.wolfssl.security.providers.FilteredSun
security.provider.4=com.wolfssl.security.providers.FilteredSunRsaSign
security.provider.5=com.wolfssl.security.providers.FilteredSunEC
security.provider.6=SunJGSS
security.provider.7=SunSASL
security.provider.8=XMLDSig
security.provider.9=JdkLDAP
security.provider.10=JdkSASL
```

### Provider Loading Sequence

```
Container Startup
    ↓
JVM Initialization
    ↓
Load java.security configuration
    ↓
┌─ Load security.provider.1 (wolfJCE)
│   ↓
│   Load /usr/share/java/wolfcrypt-jni.jar
│   ↓
│   Execute WolfCryptProvider static initializer
│   ↓
│   Load libwolfcryptjni.so (System.loadLibrary("wolfcryptjni"))
│   ↓
│   Link libwolfssl.so (LD_LIBRARY_PATH resolution)
│   ↓
│   Register JCE services
│
├─ Load security.provider.2 (wolfJSSE)
│   ↓
│   (Similar sequence for wolfJSSE)
│
└─ Load remaining providers
    ↓
Application Code Starts
```

### Provider Priority and Selection

**Priority Rules**:
1. Lower number = higher priority
2. First provider implementing algorithm wins
3. Explicit provider specification bypasses priority

**Selection Examples**:

```java
// Implicit - uses highest priority provider with SHA-256
MessageDigest md = MessageDigest.getInstance("SHA-256");
// Returns: wolfJCE (priority 1)

// Explicit - bypass priority system
MessageDigest md = MessageDigest.getInstance("SHA-256", "SUN");
// Error: SUN doesn't exist (replaced with FilteredSun)

// Service not in wolfJCE - falls through
CertificateFactory cf = CertificateFactory.getInstance("X.509");
// Returns: FilteredSun (priority 3) - only provider with CertificateFactory
```

### Filtered Providers Rationale

**Problem**: Standard Sun providers include cryptographic implementations that would bypass FIPS validation.

**Solution**: FilteredSun* providers wrap original Sun providers, exposing only non-cryptographic services.

**Implementation**:
```java
public class FilteredSun extends Provider {
    public FilteredSun() {
        super("FilteredSun", 1.0, "Filtered SUN for non-crypto ops");

        // Load original Sun provider
        Provider original = new sun.security.provider.Sun();

        // Copy only allowed services
        for (Service s : original.getServices()) {
            if (serviceSupported(s)) {
                copyService(s);  // CertificateFactory, KeyStore, etc.
            }
        }
    }

    private boolean serviceSupported(Service s) {
        String type = s.getType();
        String algo = s.getAlgorithm();

        // Allow CertificateFactory, KeyStore, Policy
        // Block MessageDigest, Signature, Cipher
        return type.equals("CertificateFactory") ||
               type.equals("KeyStore") ||
               type.equals("Policy") ||
               ...
    }
}
```

---

## JNI Architecture

### JNI Call Lifecycle

**Example**: SHA-256 hashing

```
1. Java Application
   MessageDigest md = MessageDigest.getInstance("SHA-256");
   md.update(data);
   byte[] hash = md.digest();

2. wolfJCE Provider
   class WolfCryptMessageDigest extends MessageDigestSpi {
       private long nativePtr;  // Pointer to native context

       protected void engineUpdate(byte[] data, int offset, int len) {
           wc_Sha256Update(nativePtr, data, offset, len);
       }

       protected byte[] engineDigest() {
           byte[] hash = new byte[32];
           wc_Sha256Final(nativePtr, hash);
           return hash;
       }

       private native int wc_Sha256Update(long ctx, byte[] data,
                                          int offset, int len);
       private native int wc_Sha256Final(long ctx, byte[] hash);
   }

3. JNI Native Code (libwolfcryptjni.so)
   JNIEXPORT jint JNICALL Java_..._wc_1Sha256Update(
       JNIEnv* env, jobject obj, jlong ctx,
       jbyteArray data, jint offset, jint len)
   {
       wc_Sha256* sha = (wc_Sha256*)ctx;
       jbyte* nativeData = (*env)->GetByteArrayElements(env, data, NULL);

       int ret = wc_Sha256Update(sha, nativeData + offset, len);

       (*env)->ReleaseByteArrayElements(env, data, nativeData, JNI_ABORT);
       return ret;
   }

4. Native wolfSSL (libwolfssl.so)
   int wc_Sha256Update(wc_Sha256* sha, const byte* data, word32 len)
   {
       // FIPS-validated SHA-256 implementation
       // Inside FIPS boundary
   }
```

### Memory Management

**Java to Native**:
- Java creates objects (e.g., byte arrays)
- JNI provides temporary native access
- Native code copies data if needed
- JNI releases resources after call

**Native State**:
- Native contexts allocated with malloc/wolfCrypt allocators
- Stored as `long` (64-bit pointer) in Java
- Freed in Java finalizer or explicit close()

**Example**:
```java
class WolfCryptCipher {
    private long aesPtr;  // Native Aes* pointer

    WolfCryptCipher() {
        aesPtr = mallocAes();  // Native malloc
    }

    protected void finalize() {
        if (aesPtr != 0) {
            freeAes(aesPtr);  // Native free
            aesPtr = 0;
        }
    }
}
```

### Error Handling

**Native Error Codes** → **Java Exceptions**:

```c
// Native (libwolfssl.so)
#define BAD_FUNC_ARG    -173
#define BUFFER_E        -132

// JNI Bridge (libwolfcryptjni.so)
if (ret < 0) {
    switch (ret) {
        case BAD_FUNC_ARG:
            (*env)->ThrowNew(env, illegalArgEx, "Invalid argument");
            break;
        case BUFFER_E:
            (*env)->ThrowNew(env, bufferEx, "Buffer too small");
            break;
        default:
            (*env)->ThrowNew(env, cryptoEx, "Crypto operation failed");
    }
}

// Java
catch (IllegalArgumentException e) {
    // Handle Java exception
}
```

---

## Security Architecture

### FIPS Boundary

```
┌─────────────────────────────────────────────────────────┐
│                  FIPS Boundary                          │
│  ┌───────────────────────────────────────────────────┐  │
│  │ libwolfssl.so (wolfSSL FIPS v5.8.2)              │  │
│  │                                                   │  │
│  │  - wolfCrypt FIPS Module (validated)             │  │
│  │  - FIPS-approved algorithms only                 │  │
│  │  - In-core integrity check                       │  │
│  │  - Power-On Self Test (POST)                     │  │
│  │                                                   │  │
│  │  Input: Plaintext, keys, parameters              │  │
│  │  Output: Ciphertext, hashes, signatures          │  │
│  │                                                   │  │
│  │  ❌ No external crypto operations                 │  │
│  │  ❌ No algorithm bypass                          │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
         ↑                                    ↓
    Input data                           Output data
    (via JNI)                            (via JNI)
```

**FIPS Boundary Properties**:
- All cryptographic operations occur inside
- Integrity verified on library load
- POST executed before first crypto operation
- No mechanism to bypass or disable FIPS mode

### Power-On Self Test (POST)

**Execution**:
1. First cryptographic operation triggers POST
2. Tests all FIPS-approved algorithms
3. Verifies known-answer tests
4. On failure, module enters error state

**POST Trigger**:
```java
// In FipsInitCheck.java
MessageDigest md = MessageDigest.getInstance("SHA-256");
md.digest("test".getBytes());  // ← POST executes here
System.out.println("FIPS POST test completed successfully");
```

### Integrity Verification

**Build-Time**:
```bash
# During wolfSSL build
./configure --enable-fips=v5 ...
make
# → Generates libwolfssl.so with embedded integrity hash
```

**Runtime**:
```c
// In libwolfssl.so initialization
int wolfCrypt_Init(void) {
    if (DoIntegrityCheck() != 0) {
        // Integrity check failed
        return FIPS_INTEGRITY_E;
    }
    // Continue initialization
}
```

**Container Verification**:
```bash
# scripts/integrity-check.sh
sha256sum -c /opt/wolfssl-fips/checksums/libraries.sha256
# Verifies:
#   - libwolfssl.so
#   - libwolfcryptjni.so
#   - libwolfssljni.so
#   - wolfcrypt-jni.jar
#   - wolfssl-jsse.jar
```

### Cryptographic Module

**Approved Algorithms** (FIPS 140-3):
- **Symmetric**: AES (128/192/256)
- **Hash**: SHA-224, SHA-256, SHA-384, SHA-512, SHA3-*
- **MAC**: HMAC-SHA*, CMAC (AES)
- **Asymmetric**: RSA (2048/3072/4096), EC (P-256/384/521)
- **Key Agreement**: ECDH, DH
- **Random**: Hash_DRBG, HMAC_DRBG

**Non-Approved** (blocked):
- MD5, SHA-1 (deprecated)
- DES, 3DES (weak)
- RC4 (insecure)
- Non-FIPS curves (Ed25519, Curve25519)

---

## Build Architecture

### Multi-Stage Build Process

```dockerfile
# Stage 1: wolfSSL FIPS Build
FROM eclipse-temurin:11-jdk-jammy AS builder
RUN apt-get update && apt-get install -y build-essential autoconf libtool
COPY --from=secrets wolfssl-fips-bundle.zip
RUN unzip wolfssl-fips-bundle.zip
RUN cd wolfssl-*-fips && \
    ./configure --enable-fips=v5 --enable-jni --enable-static --enable-shared && \
    make && make install
# Output: libwolfssl.so → /usr/local/lib/

# Stage 2: wolfCrypt JNI Build
FROM wolfssl-fips-builder AS wolfjce-builder
RUN git clone https://github.com/wolfSSL/wolfcrypt-jni
RUN cd wolfcrypt-jni && \
    ./configure && make && make install
# Output: wolfcrypt-jni.jar, libwolfcryptjni.so

# Stage 3: wolfSSL JNI Build
FROM wolfjce-builder AS wolfjsse-builder
RUN git clone https://github.com/wolfSSL/wolfssljni
RUN cd wolfssljni && \
    ./configure && make && make install
# Output: wolfssl-jsse.jar, libwolfssljni.so

# Stage 4: FilteredSun Providers Build
FROM eclipse-temurin:11-jdk-jammy AS filtered-providers-builder
COPY src/providers/*.java /build/
RUN javac /build/*.java && jar cvf filtered-providers.jar /build/*.class
# Output: filtered-providers.jar

# Stage 5: Application Build
FROM eclipse-temurin:11-jdk-jammy AS app-builder
COPY src/main/*.java /build/
COPY --from=wolfjce-builder /usr/share/java/wolfcrypt-jni.jar /jars/
COPY --from=wolfjsse-builder /usr/share/java/wolfssl-jsse.jar /jars/
RUN javac -cp "/jars/*" /build/*.java
# Output: *.class files

# Stage 6: Runtime Image
FROM eclipse-temurin:11-jdk-jammy
COPY --from=wolfssl-fips-builder /usr/local/lib/libwolfssl.so* /usr/local/lib/
COPY --from=wolfjce-builder /usr/lib/jni/libwolfcryptjni.so /usr/lib/jni/
COPY --from=wolfjsse-builder /usr/lib/jni/libwolfssljni.so /usr/lib/jni/
COPY --from=wolfjce-builder /usr/share/java/wolfcrypt-jni.jar /usr/share/java/
COPY --from=wolfjsse-builder /usr/share/java/wolfssl-jsse.jar /usr/share/java/
COPY --from=filtered-providers-builder /filtered-providers.jar /usr/share/java/
COPY --from=app-builder /build/*.class /opt/wolfssl-fips/bin/
COPY java.security $JAVA_HOME/conf/security/java.security
COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]
```

### Build Dependencies

```
wolfSSL FIPS Build
   ↓ (libwolfssl.so)
wolfCrypt JNI Build ← depends on libwolfssl.so
   ↓ (wolfcrypt-jni.jar, libwolfcryptjni.so)
wolfSSL JNI Build ← depends on libwolfssl.so
   ↓ (wolfssl-jsse.jar, libwolfssljni.so)
Application Build ← depends on JAR files
   ↓ (*.class)
Runtime Image Assembly ← combines all artifacts
```

---

## Deployment Architecture

### Container Startup Flow

```
Docker Container Start
    ↓
Execute docker-entrypoint.sh
    ↓
Check FIPS_CHECK environment variable
    ↓
┌─ If FIPS_CHECK=true (default)
│   ↓
│   Run Library Integrity Verification
│   - Verify SHA-256 checksums
│   - Compare against known-good values
│   - Exit if mismatch
│   ↓
│   Run FIPS Container Verification (FipsInitCheck.java)
│   - List security providers
│   - Verify wolfJCE at priority 1
│   - Verify wolfJSSE at priority 2
│   - Verify WKS cacerts format
│   - Force FIPS POST execution
│   - Sanity check java.security
│   - Test algorithm availability
│   ↓
│   All checks passed?
│   ├─ Yes → Continue
│   └─ No → Exit with error
│
└─ If FIPS_CHECK=false
    ↓
    Skip validation (development mode)
    ↓
Execute User Command
```

### Library Loading Sequence

```
JVM Starts
    ↓
Load java.security
    ↓
Initialize security.provider.1 (wolfJCE)
    ↓
┌─ Load wolfcrypt-jni.jar
│   ↓
│   Execute static initializer
│   ↓
│   System.loadLibrary("wolfcryptjni")
│   ↓
│   Search LD_LIBRARY_PATH for libwolfcryptjni.so
│   ↓
│   Found at /usr/lib/jni/libwolfcryptjni.so
│   ↓
│   Load libwolfcryptjni.so
│   ↓
│   Resolve dependency: libwolfssl.so
│   ↓
│   Search LD_LIBRARY_PATH
│   ↓
│   Found at /usr/local/lib/libwolfssl.so.44
│   ↓
│   Load libwolfssl.so.44
│   ↓
│   Execute wolfCrypt_Init()
│   ↓
│   Perform in-core integrity check
│   ↓
│   Register for POST on first use
│
└─ wolfJCE ready
    ↓
Load security.provider.2 (wolfJSSE)
    ↓
    (Similar sequence)
    ↓
All Providers Loaded
```

---

## Data Flow Examples

### Example 1: AES-GCM Encryption

```
Application Code:
    KeyGenerator keyGen = KeyGenerator.getInstance("AES");
    keyGen.init(256);
    SecretKey key = keyGen.generateKey();
    Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
    cipher.init(Cipher.ENCRYPT_MODE, key, gcmSpec);
    byte[] ciphertext = cipher.doFinal(plaintext);

↓ Java Security Framework

wolfJCE Provider:
    class WolfCryptCipher {
        private long aesPtr;  // Native Aes* pointer

        engineInit(ENCRYPT_MODE, key, gcmSpec) {
            aesPtr = mallocAes();
            wc_AesGcmSetKey(aesPtr, key.getEncoded(), key.getEncoded().length);
        }

        engineDoFinal(input) {
            byte[] output = new byte[input.length + 16];  // + auth tag
            wc_AesGcmEncrypt(aesPtr, output, input, input.length,
                            gcmSpec.getIV(), gcmSpec.getIV().length,
                            authTag, 16, null, 0);
            return output;
        }
    }

↓ JNI Bridge (libwolfcryptjni.so)

    JNIEXPORT jint JNICALL Java_..._wc_1AesGcmEncrypt(...) {
        Aes* aes = (Aes*)aesPtr;
        jbyte* jInput = (*env)->GetByteArrayElements(env, input, NULL);
        jbyte* jOutput = (*env)->GetByteArrayElements(env, output, NULL);

        int ret = wc_AesGcmEncrypt(aes,
                                   (byte*)jOutput, (byte*)jInput, inputLen,
                                   (byte*)jIv, ivLen,
                                   (byte*)jAuthTag, authTagLen,
                                   NULL, 0);

        (*env)->ReleaseByteArrayElements(env, input, jInput, JNI_ABORT);
        (*env)->ReleaseByteArrayElements(env, output, jOutput, 0);
        return ret;
    }

↓ FIPS Boundary

libwolfssl.so:
    int wc_AesGcmEncrypt(Aes* aes, byte* out, const byte* in, word32 sz,
                        const byte* iv, word32 ivSz,
                        byte* authTag, word32 authTagSz,
                        const byte* authIn, word32 authInSz)
    {
        // FIPS 140-3 validated AES-GCM implementation
        // POST must have completed successfully
        // All operations within FIPS boundary
    }

↓ Return encrypted data

Application receives ciphertext
```

### Example 2: TLS Handshake

```
Application Code:
    SSLContext context = SSLContext.getInstance("TLS");
    context.init(null, null, null);
    SSLSocket socket = (SSLSocket) context.getSocketFactory()
                                          .createSocket("www.example.com", 443);
    socket.startHandshake();

↓ Java Security Framework

wolfJSSE Provider:
    class WolfSSLContext {
        SSLSocket createSocket(host, port) {
            return new WolfSSLSocket(host, port, nativeCtx);
        }
    }

    class WolfSSLSocket {
        private long sslPtr;  // Native WOLFSSL* pointer

        startHandshake() {
            int ret = wolfSSL_connect(sslPtr);
            if (ret != SSL_SUCCESS) {
                throw new SSLHandshakeException("Handshake failed");
            }
        }
    }

↓ JNI Bridge (libwolfssljni.so)

    JNIEXPORT jint JNICALL Java_..._wolfSSL_1connect(
        JNIEnv* env, jobject obj, jlong sslPtr)
    {
        WOLFSSL* ssl = (WOLFSSL*)sslPtr;
        int ret = wolfSSL_connect(ssl);
        return ret;
    }

↓ FIPS Boundary

libwolfssl.so:
    int wolfSSL_connect(WOLFSSL* ssl) {
        // Perform TLS handshake
        // - ClientHello
        // - ServerHello, Certificate, ServerHelloDone
        // - ClientKeyExchange, ChangeCipherSpec, Finished
        // - ChangeCipherSpec, Finished

        // All crypto (RSA, ECDH, AES, SHA, HMAC) within FIPS boundary
        // Uses FIPS-validated algorithms only
    }

↓ Return handshake status

Application: TLS connection established
```

---

## Additional Resources

- **[README.md](README.md)** - General documentation
- **[DEVELOPER-GUIDE.md](DEVELOPER-GUIDE.md)** - Developer integration guide
- **[ATTESTATION.md](ATTESTATION.md)** - Compliance documentation

---

**Last Updated**: 2026-03-19
**Version**: 1.0
**wolfSSL FIPS Version**: v5.8.2 (Certificate #4718)
**OpenJDK Version**: 11
