# Developer Guide: Java FIPS 140-3 Container

Comprehensive guide for developers integrating applications with the wolfSSL FIPS 140-3 Java container.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Understanding wolfJCE and wolfJSSE Providers](#understanding-wolfjce-and-wolfjsse-providers)
3. [Provider Override Mechanisms](#provider-override-mechanisms)
4. [Keystore and Trust Store Deep Dive](#keystore-and-trust-store-deep-dive)
5. [JCE Cryptographic Operations](#jce-cryptographic-operations)
6. [JSSE/TLS Operations](#jssetls-operations)
7. [Using the Image in Different Modes](#using-the-image-in-different-modes)
8. [Integration Patterns](#integration-patterns)
9. [Best Practices and Common Pitfalls](#best-practices-and-common-pitfalls)
10. [Troubleshooting Guide](#troubleshooting-guide)

---

## Architecture Overview

### JNI-Based Provider Architecture

This container uses a Java Native Interface (JNI) based architecture where Java cryptographic operations are routed directly to FIPS-validated native code:

```
┌──────────────────────────────────────────────────────────────┐
│                    Java Application Layer                     │
│  (Your Code using standard JCA/JCE/JSSE APIs)                │
└──────────────────┬───────────────────────────────────────────┘
                   │
                   ↓
┌──────────────────────────────────────────────────────────────┐
│               Java Security Framework                         │
│  - Provider selection based on priority                       │
│  - Algorithm lookup and routing                               │
└──────────────────┬───────────────────────────────────────────┘
                   │
                   ↓
┌──────────────────────────────────────────────────────────────┐
│           Security Provider Layer (java.security)             │
│  1. wolfJCE (com.wolfssl.provider.jce.WolfCryptProvider)      │
│  2. wolfJSSE (com.wolfssl.provider.jsse.WolfSSLProvider)      │
│  3-5. FilteredSun providers (non-crypto services only)        │
└──────────────────┬───────────────────────────────────────────┘
                   │
                   ↓
┌──────────────────────────────────────────────────────────────┐
│                    JNI Bridge Layer                           │
│  - libwolfcryptjni.so (wolfJCE ↔ native wolfCrypt)           │
│  - libwolfssljni.so (wolfJSSE ↔ native wolfSSL TLS)          │
└──────────────────┬───────────────────────────────────────────┘
                   │
                   ↓
┌──────────────────────────────────────────────────────────────┐
│          FIPS 140-3 Validated Cryptographic Module            │
│  libwolfssl.so (wolfSSL FIPS v5.8.2, Certificate #4718)      │
│  - FIPS POST (Power-On Self Test)                            │
│  - In-core integrity verification                            │
│  - FIPS-approved algorithms only                             │
└──────────────────────────────────────────────────────────────┘
```

### Data Flow Example

When you call `MessageDigest.getInstance("SHA-256")`:

1. **Java Application**: Your code requests SHA-256 via JCA API
2. **Java Security Framework**: Looks up "SHA-256" in registered providers
3. **Provider Selection**: Finds wolfJCE (priority 1) implements SHA-256
4. **wolfJCE Provider**: Creates WolfCryptMessageDigest instance
5. **JNI Call**: wolfJCE calls native method via libwolfcryptjni.so
6. **Native Execution**: libwolfssl.so performs FIPS-validated SHA-256
7. **Return Path**: Result flows back through JNI to Java

### Why JNI Instead of Pure Java?

- **FIPS Validation**: Only native wolfSSL library is FIPS 140-3 validated
- **Performance**: Native code is faster for cryptographic operations
- **Compliance**: FIPS boundary is at native library level
- **Compatibility**: Standard JCA/JSSE APIs remain unchanged

---

## Understanding wolfJCE and wolfJSSE Providers

### wolfJCE Provider (wolfCrypt JNI)

**Full Class Name**: `com.wolfssl.provider.jce.WolfCryptProvider`

**Purpose**: Implements Java Cryptography Extension (JCE) services using FIPS-validated wolfCrypt

**Services Provided**:
- **MessageDigest**: SHA-1, SHA-224, SHA-256, SHA-384, SHA-512, SHA3-224, SHA3-256, SHA3-384, SHA3-512
- **Mac**: HmacSHA1, HmacSHA224, HmacSHA256, HmacSHA384, HmacSHA512, HmacSHA3-*, AESCMAC, AESGMAC
- **Cipher**: AES (CBC, ECB, CTR, GCM, CCM, OFB), RSA
- **Signature**: SHA*withRSA, SHA*withECDSA, SHA3-*withRSA, SHA3-*withECDSA, RSASSA-PSS
- **KeyGenerator**: AES, DES, DESede, HMAC*
- **KeyPairGenerator**: RSA, EC, DH
- **KeyAgreement**: ECDH, DH
- **SecureRandom**: HashDRBG, DEFAULT
- **AlgorithmParameters**: Various

**Location**:
- JAR: `/usr/share/java/wolfcrypt-jni.jar`
- Native Library: `/usr/lib/jni/libwolfcryptjni.so`
- Priority: 1 (highest)

**Usage**:
```java
// Implicit (recommended - uses highest priority provider)
MessageDigest md = MessageDigest.getInstance("SHA-256");

// Explicit (if needed)
Provider wolfJCE = Security.getProvider("wolfJCE");
MessageDigest md = MessageDigest.getInstance("SHA-256", wolfJCE);
```

### wolfJSSE Provider (wolfSSL JNI)

**Full Class Name**: `com.wolfssl.provider.jsse.WolfSSLProvider`

**Purpose**: Implements Java Secure Socket Extension (JSSE) services using FIPS-validated wolfSSL TLS

**Services Provided**:
- **SSLContext**: SSL, TLS, TLSv1.2, TLSv1.3, DEFAULT
- **KeyManagerFactory**: PKIX, X509, SunX509
- **TrustManagerFactory**: PKIX, X509, SunX509
- **KeyStore**: WKS (WolfSSL KeyStore)

**Location**:
- JAR: `/usr/share/java/wolfssl-jsse.jar`
- Native Library: `/usr/lib/jni/libwolfssljni.so`
- Priority: 2

**Usage**:
```java
// Implicit (recommended)
SSLContext context = SSLContext.getInstance("TLS");

// Explicit (if needed)
Provider wolfJSSE = Security.getProvider("wolfJSSE");
SSLContext context = SSLContext.getInstance("TLS", wolfJSSE);
```

### Filtered Sun Providers

These providers wrap standard Sun providers and filter out cryptographic algorithms, keeping only non-cryptographic services:

**FilteredSun** (com.wolfssl.security.providers.FilteredSun):
- CertPathBuilder.PKIX
- CertStore.Collection
- CertificateFactory.X.509
- Configuration.JavaLoginConfig
- KeyStore.JKS, KeyStore.PKCS12 (for compatibility - use WKS for FIPS)
- Policy.JavaPolicy

**FilteredSunRsaSign** (com.wolfssl.security.providers.FilteredSunRsaSign):
- KeyFactory.RSA (key conversion only, not signature)

**FilteredSunEC** (com.wolfssl.security.providers.FilteredSunEC):
- KeyFactory.EC (key conversion only)
- AlgorithmParameters.EC

**Why Filtering?**: These services are needed for certificate handling, key conversion, and policy management, but we want cryptographic operations to use wolfSSL providers only.

---

## Provider Override Mechanisms

### java.security Configuration

The container uses a custom `java.security` file that registers providers in specific order:

```properties
# Priority 1: JCE cryptographic operations
security.provider.1=com.wolfssl.provider.jce.WolfCryptProvider

# Priority 2: JSSE TLS operations
security.provider.2=com.wolfssl.provider.jsse.WolfSSLProvider

# Priority 3-5: Non-cryptographic services only
security.provider.3=com.wolfssl.security.providers.FilteredSun
security.provider.4=com.wolfssl.security.providers.FilteredSunRsaSign
security.provider.5=com.wolfssl.security.providers.FilteredSunEC

# Priority 6-10: Framework providers (non-crypto)
security.provider.6=SunJGSS
security.provider.7=SunSASL
security.provider.8=XMLDSig
security.provider.9=JdkLDAP
security.provider.10=JdkSASL
```

**Location**: `$JAVA_HOME/conf/security/java.security`

### Provider Selection Algorithm

When you call `getInstance()` without specifying a provider:

1. Java iterates through providers in priority order (1, 2, 3, ...)
2. For each provider, checks if it implements the requested algorithm
3. Returns the first match found
4. Throws NoSuchAlgorithmException if no provider implements it

**Example**:
```java
// Looking for "SHA-256"
MessageDigest.getInstance("SHA-256");

// Search order:
// 1. wolfJCE (priority 1) - HAS SHA-256 ✓ (returns this)
// 2. wolfJSSE (priority 2) - no MessageDigest service
// 3. FilteredSun (priority 3) - no SHA-256 (filtered out)
// ...
```

### Overriding Providers Dynamically

While not recommended for FIPS compliance, you can modify providers at runtime:

```java
// Add provider (appends to end)
Security.addProvider(new MyProvider());

// Insert at specific position (shifts existing providers down)
Security.insertProviderAt(new MyProvider(), 1);

// Remove provider
Security.removeProvider("ProviderName");
```

**Warning**: Modifying providers at runtime may bypass FIPS enforcement. Only do this in non-FIPS mode or for testing.

### Provider Debugging

Enable provider debugging to see which provider is selected:

```bash
docker run --rm \
  -e JAVA_OPTS="-Djava.security.debug=provider" \
  java:17-jammy-ubuntu-22.04-fips
```

---

## Keystore and Trust Store Deep Dive

### What is WKS (WolfSSL KeyStore)?

WKS is a keystore format implemented by wolfJCE that uses FIPS-validated cryptography for all operations. It's required for FIPS compliance because traditional formats (JKS, PKCS12) use non-FIPS crypto.

**Key Differences**:

| Feature | JKS | PKCS12 | WKS |
|---------|-----|--------|-----|
| Format | Sun proprietary | PKCS#12 standard | wolfSSL proprietary |
| Encryption | MD5, DES | SHA-1, 3DES/AES | SHA-256, AES-256 |
| FIPS Compliant | ❌ No | ❌ No | ✅ Yes |
| Password | changeit | varies | changeitchangeit (system cacerts) |
| File Extension | .jks | .p12/.pfx | .wks |

### Trust Store vs Key Store

**Trust Store**:
- Contains CA certificates used to validate server certificates
- Public keys only (no private keys)
- Used by TLS clients to verify server identity
- System trust store: `$JAVA_HOME/lib/security/cacerts`

**Key Store**:
- Contains client certificates and private keys
- Used for client authentication (mutual TLS)
- Used for code signing
- Application-specific, not system-wide

### System CA Certificates (Trust Store)

The container includes system CA certificates in WKS format:

```bash
# Location
$JAVA_HOME/lib/security/cacerts

# Format
WKS (converted from JKS during build)

# Password
changeitchangeit

# Certificate count
~130 CA certificates (varies by system)
```

### Loading WKS Trust Store in Code

```java
import java.io.FileInputStream;
import java.security.KeyStore;
import javax.net.ssl.*;

// Load system WKS cacerts
String javaHome = System.getProperty("java.home");
String cacertsPath = javaHome + "/lib/security/cacerts";

KeyStore trustStore = KeyStore.getInstance("WKS");
try (FileInputStream fis = new FileInputStream(cacertsPath)) {
    trustStore.load(fis, "changeitchangeit".toCharArray());
    System.out.println("Loaded " + trustStore.size() + " CA certificates");
}

// Create TrustManagerFactory with WKS
TrustManagerFactory tmf = TrustManagerFactory.getInstance("PKIX");
tmf.init(trustStore);

// Use in SSLContext
SSLContext context = SSLContext.getInstance("TLS");
context.init(null, tmf.getTrustManagers(), null);
```

### Creating Custom WKS Keystore

```java
import java.security.*;
import java.security.cert.*;
import java.io.*;

// Create new WKS keystore
KeyStore keyStore = KeyStore.getInstance("WKS");
keyStore.load(null, null); // Initialize empty keystore

// Add a certificate
CertificateFactory cf = CertificateFactory.getInstance("X.509");
Certificate cert = cf.generateCertificate(
    new FileInputStream("/path/to/cert.pem"));
keyStore.setCertificateEntry("mycert", cert);

// Add a private key and certificate chain
PrivateKey privateKey = ...; // Load your private key
Certificate[] chain = ...; // Load certificate chain
keyStore.setKeyEntry("mykey", privateKey,
    "keyPassword".toCharArray(), chain);

// Save to file
try (FileOutputStream fos = new FileOutputStream("mystore.wks")) {
    keyStore.store(fos, "storePassword".toCharArray());
}
```

### Converting JKS/PKCS12 to WKS

The container includes a conversion script used during build. For manual conversion:

```bash
# During build (automatic)
cd /path/to/wolfcrypt-jni/examples/certs/systemcerts
./system-cacerts-to-wks.sh /path/to/wolfcrypt-jni.jar

# Manual conversion (in container)
docker run --rm -it \
  -v /path/to/keystore.jks:/input.jks \
  -v /path/to/output:/output \
  java:17-jammy-ubuntu-22.04-fips bash

# Inside container, use Java code to read JKS and write WKS
java -cp "/usr/share/java/*" YourConversionClass
```

### Using Custom Trust Store

```bash
# Option 1: Replace system cacerts
docker run --rm \
  -v /path/to/custom-cacerts.wks:$JAVA_HOME/lib/security/cacerts:ro \
  java:17-jammy-ubuntu-22.04-fips

# Option 2: Specify via system property
docker run --rm \
  -e JAVA_OPTS="-Djavax.net.ssl.trustStore=/app/custom-truststore.wks \
                -Djavax.net.ssl.trustStorePassword=mypassword \
                -Djavax.net.ssl.trustStoreType=WKS" \
  -v /path/to/custom-truststore.wks:/app/custom-truststore.wks:ro \
  java:17-jammy-ubuntu-22.04-fips
```

---

## JCE Cryptographic Operations

This section provides comprehensive examples of using JCE with wolfJCE provider. All code uses standard JCA APIs.

### Message Digest (Hashing)

```java
import java.security.MessageDigest;

public class HashingExample {
    public static void main(String[] args) throws Exception {
        // SHA-256 hashing
        MessageDigest md = MessageDigest.getInstance("SHA-256");
        byte[] data = "Hello FIPS!".getBytes();
        byte[] hash = md.digest(data);

        // Verify using wolfJCE
        System.out.println("Provider: " + md.getProvider().getName()); // wolfJCE
        System.out.println("Hash: " + bytesToHex(hash));

        // Incremental hashing (for large data)
        md.reset();
        md.update("Part 1".getBytes());
        md.update("Part 2".getBytes());
        byte[] incrementalHash = md.digest();

        // Other supported algorithms
        String[] algorithms = {
            "SHA-1", "SHA-224", "SHA-256", "SHA-384", "SHA-512",
            "SHA3-224", "SHA3-256", "SHA3-384", "SHA3-512"
        };

        for (String alg : algorithms) {
            MessageDigest digest = MessageDigest.getInstance(alg);
            byte[] result = digest.digest(data);
            System.out.println(alg + ": " + bytesToHex(result).substring(0, 16) + "...");
        }
    }

    private static String bytesToHex(byte[] bytes) {
        StringBuilder result = new StringBuilder();
        for (byte b : bytes) {
            result.append(String.format("%02x", b));
        }
        return result.toString();
    }
}
```

### Symmetric Encryption (AES)

```java
import javax.crypto.*;
import javax.crypto.spec.*;
import java.security.*;

public class AesExample {
    public static void main(String[] args) throws Exception {
        // Generate AES key
        KeyGenerator keyGen = KeyGenerator.getInstance("AES");
        keyGen.init(256); // 128, 192, or 256 bits
        SecretKey key = keyGen.generateKey();

        String plaintext = "Sensitive data to encrypt";

        // AES-GCM (recommended for authenticated encryption)
        encryptDecryptAesGcm(key, plaintext);

        // AES-CBC
        encryptDecryptAesCbc(key, plaintext);

        // AES-CTR
        encryptDecryptAesCtr(key, plaintext);
    }

    private static void encryptDecryptAesGcm(SecretKey key, String plaintext)
            throws Exception {
        // Encrypt
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");

        // Generate random IV (12 bytes for GCM)
        SecureRandom random = new SecureRandom();
        byte[] iv = new byte[12];
        random.nextBytes(iv);
        GCMParameterSpec gcmSpec = new GCMParameterSpec(128, iv); // 128-bit auth tag

        cipher.init(Cipher.ENCRYPT_MODE, key, gcmSpec);
        byte[] ciphertext = cipher.doFinal(plaintext.getBytes());

        System.out.println("AES-GCM Encrypted: " + bytesToHex(ciphertext).substring(0, 32) + "...");

        // Decrypt
        cipher.init(Cipher.DECRYPT_MODE, key, gcmSpec);
        byte[] decrypted = cipher.doFinal(ciphertext);

        System.out.println("AES-GCM Decrypted: " + new String(decrypted));
        assert plaintext.equals(new String(decrypted));
    }

    private static void encryptDecryptAesCbc(SecretKey key, String plaintext)
            throws Exception {
        // Encrypt
        Cipher cipher = Cipher.getInstance("AES/CBC/PKCS5Padding");
        cipher.init(Cipher.ENCRYPT_MODE, key);
        byte[] iv = cipher.getIV(); // Save IV for decryption
        byte[] ciphertext = cipher.doFinal(plaintext.getBytes());

        System.out.println("AES-CBC Encrypted: " + bytesToHex(ciphertext).substring(0, 32) + "...");

        // Decrypt
        cipher.init(Cipher.DECRYPT_MODE, key, new IvParameterSpec(iv));
        byte[] decrypted = cipher.doFinal(ciphertext);

        System.out.println("AES-CBC Decrypted: " + new String(decrypted));
        assert plaintext.equals(new String(decrypted));
    }

    private static void encryptDecryptAesCtr(SecretKey key, String plaintext)
            throws Exception {
        // Encrypt
        Cipher cipher = Cipher.getInstance("AES/CTR/NoPadding");
        cipher.init(Cipher.ENCRYPT_MODE, key);
        byte[] iv = cipher.getIV();
        byte[] ciphertext = cipher.doFinal(plaintext.getBytes());

        System.out.println("AES-CTR Encrypted: " + bytesToHex(ciphertext).substring(0, 32) + "...");

        // Decrypt
        cipher.init(Cipher.DECRYPT_MODE, key, new IvParameterSpec(iv));
        byte[] decrypted = cipher.doFinal(ciphertext);

        System.out.println("AES-CTR Decrypted: " + new String(decrypted));
        assert plaintext.equals(new String(decrypted));
    }

    private static String bytesToHex(byte[] bytes) {
        StringBuilder result = new StringBuilder();
        for (byte b : bytes) {
            result.append(String.format("%02x", b));
        }
        return result.toString();
    }
}
```

### Asymmetric Encryption (RSA)

```java
import java.security.*;
import javax.crypto.Cipher;

public class RsaExample {
    public static void main(String[] args) throws Exception {
        // Generate RSA key pair
        KeyPairGenerator keyPairGen = KeyPairGenerator.getInstance("RSA");
        keyPairGen.initialize(2048); // 2048, 3072, or 4096 bits
        KeyPair keyPair = keyPairGen.generateKeyPair();

        String plaintext = "Secret message";

        // Encrypt with public key
        Cipher cipher = Cipher.getInstance("RSA/ECB/PKCS1Padding");
        cipher.init(Cipher.ENCRYPT_MODE, keyPair.getPublic());
        byte[] ciphertext = cipher.doFinal(plaintext.getBytes());

        System.out.println("RSA Encrypted: " + bytesToHex(ciphertext).substring(0, 32) + "...");

        // Decrypt with private key
        cipher.init(Cipher.DECRYPT_MODE, keyPair.getPrivate());
        byte[] decrypted = cipher.doFinal(ciphertext);

        System.out.println("RSA Decrypted: " + new String(decrypted));
        assert plaintext.equals(new String(decrypted));
    }

    private static String bytesToHex(byte[] bytes) {
        StringBuilder result = new StringBuilder();
        for (byte b : bytes) {
            result.append(String.format("%02x", b));
        }
        return result.toString();
    }
}
```

### MAC (Message Authentication Code)

```java
import javax.crypto.*;
import javax.crypto.spec.*;
import java.security.*;

public class MacExample {
    public static void main(String[] args) throws Exception {
        String data = "Data to authenticate";

        // HMAC-SHA256
        KeyGenerator keyGen = KeyGenerator.getInstance("HmacSHA256");
        SecretKey key = keyGen.generateKey();

        Mac mac = Mac.getInstance("HmacSHA256");
        mac.init(key);
        byte[] macValue = mac.doFinal(data.getBytes());

        System.out.println("HMAC-SHA256: " + bytesToHex(macValue));

        // AES-CMAC
        keyGen = KeyGenerator.getInstance("AES");
        keyGen.init(256);
        key = keyGen.generateKey();

        mac = Mac.getInstance("AESCMAC");
        mac.init(key);
        macValue = mac.doFinal(data.getBytes());

        System.out.println("AES-CMAC: " + bytesToHex(macValue));

        // AES-GMAC (requires GCMParameterSpec)
        SecureRandom random = new SecureRandom();
        byte[] iv = new byte[12];
        random.nextBytes(iv);
        GCMParameterSpec gcmSpec = new GCMParameterSpec(128, iv);

        mac = Mac.getInstance("AESGMAC");
        mac.init(key, gcmSpec);
        macValue = mac.doFinal(data.getBytes());

        System.out.println("AES-GMAC: " + bytesToHex(macValue));
    }

    private static String bytesToHex(byte[] bytes) {
        StringBuilder result = new StringBuilder();
        for (byte b : bytes) {
            result.append(String.format("%02x", b));
        }
        return result.toString();
    }
}
```

### Digital Signatures

```java
import java.security.*;

public class SignatureExample {
    public static void main(String[] args) throws Exception {
        String data = "Document to sign";

        // RSA Signature
        rsaSignatureExample(data);

        // ECDSA Signature
        ecdsaSignatureExample(data);

        // RSA-PSS Signature
        rsaPssSignatureExample(data);
    }

    private static void rsaSignatureExample(String data) throws Exception {
        // Generate RSA key pair
        KeyPairGenerator keyPairGen = KeyPairGenerator.getInstance("RSA");
        keyPairGen.initialize(2048);
        KeyPair keyPair = keyPairGen.generateKeyPair();

        // Sign
        Signature signature = Signature.getInstance("SHA256withRSA");
        signature.initSign(keyPair.getPrivate());
        signature.update(data.getBytes());
        byte[] signatureBytes = signature.sign();

        System.out.println("RSA Signature: " + bytesToHex(signatureBytes).substring(0, 32) + "...");

        // Verify
        signature.initVerify(keyPair.getPublic());
        signature.update(data.getBytes());
        boolean verified = signature.verify(signatureBytes);

        System.out.println("RSA Signature Verified: " + verified);
        assert verified;
    }

    private static void ecdsaSignatureExample(String data) throws Exception {
        // Generate EC key pair
        KeyPairGenerator keyPairGen = KeyPairGenerator.getInstance("EC");
        ECGenParameterSpec ecSpec = new ECGenParameterSpec("secp256r1"); // P-256
        keyPairGen.initialize(ecSpec);
        KeyPair keyPair = keyPairGen.generateKeyPair();

        // Sign
        Signature signature = Signature.getInstance("SHA256withECDSA");
        signature.initSign(keyPair.getPrivate());
        signature.update(data.getBytes());
        byte[] signatureBytes = signature.sign();

        System.out.println("ECDSA Signature: " + bytesToHex(signatureBytes).substring(0, 32) + "...");

        // Verify
        signature.initVerify(keyPair.getPublic());
        signature.update(data.getBytes());
        boolean verified = signature.verify(signatureBytes);

        System.out.println("ECDSA Signature Verified: " + verified);
        assert verified;
    }

    private static void rsaPssSignatureExample(String data) throws Exception {
        // Generate RSA key pair
        KeyPairGenerator keyPairGen = KeyPairGenerator.getInstance("RSA");
        keyPairGen.initialize(2048);
        KeyPair keyPair = keyPairGen.generateKeyPair();

        // Create PSS parameter spec
        PSSParameterSpec pssSpec = new PSSParameterSpec(
            "SHA-256", "MGF1", MGF1ParameterSpec.SHA256, 32, 1);

        // Sign
        Signature signature = Signature.getInstance("RSASSA-PSS");
        signature.setParameter(pssSpec);
        signature.initSign(keyPair.getPrivate());
        signature.update(data.getBytes());
        byte[] signatureBytes = signature.sign();

        System.out.println("RSA-PSS Signature: " + bytesToHex(signatureBytes).substring(0, 32) + "...");

        // Verify
        signature.setParameter(pssSpec);
        signature.initVerify(keyPair.getPublic());
        signature.update(data.getBytes());
        boolean verified = signature.verify(signatureBytes);

        System.out.println("RSA-PSS Signature Verified: " + verified);
        assert verified;
    }

    private static String bytesToHex(byte[] bytes) {
        StringBuilder result = new StringBuilder();
        for (byte b : bytes) {
            result.append(String.format("%02x", b));
        }
        return result.toString();
    }
}
```

### Key Agreement (ECDH)

```java
import java.security.*;
import java.security.spec.*;
import javax.crypto.*;

public class KeyAgreementExample {
    public static void main(String[] args) throws Exception {
        // Alice and Bob generate their own EC key pairs
        KeyPairGenerator keyPairGen = KeyPairGenerator.getInstance("EC");
        ECGenParameterSpec ecSpec = new ECGenParameterSpec("secp256r1");
        keyPairGen.initialize(ecSpec);

        KeyPair aliceKeyPair = keyPairGen.generateKeyPair();
        KeyPair bobKeyPair = keyPairGen.generateKeyPair();

        // Alice performs key agreement
        KeyAgreement aliceKeyAgree = KeyAgreement.getInstance("ECDH");
        aliceKeyAgree.init(aliceKeyPair.getPrivate());
        aliceKeyAgree.doPhase(bobKeyPair.getPublic(), true);
        byte[] aliceSharedSecret = aliceKeyAgree.generateSecret();

        // Bob performs key agreement
        KeyAgreement bobKeyAgree = KeyAgreement.getInstance("ECDH");
        bobKeyAgree.init(bobKeyPair.getPrivate());
        bobKeyAgree.doPhase(aliceKeyPair.getPublic(), true);
        byte[] bobSharedSecret = bobKeyAgree.generateSecret();

        // Verify both computed the same shared secret
        assert java.util.Arrays.equals(aliceSharedSecret, bobSharedSecret);

        System.out.println("ECDH Shared Secret: " + bytesToHex(aliceSharedSecret));
        System.out.println("Alice and Bob successfully established shared secret!");

        // Derive AES key from shared secret (recommended practice)
        MessageDigest sha256 = MessageDigest.getInstance("SHA-256");
        byte[] keyMaterial = sha256.digest(aliceSharedSecret);
        SecretKey aesKey = new SecretKeySpec(keyMaterial, 0, 32, "AES");

        System.out.println("Derived AES Key: " + bytesToHex(aesKey.getEncoded()));
    }

    private static String bytesToHex(byte[] bytes) {
        StringBuilder result = new StringBuilder();
        for (byte b : bytes) {
            result.append(String.format("%02x", b));
        }
        return result.toString();
    }
}
```

### Secure Random

```java
import java.security.SecureRandom;

public class SecureRandomExample {
    public static void main(String[] args) throws Exception {
        // Default SecureRandom (uses wolfJCE)
        SecureRandom random = new SecureRandom();
        System.out.println("Provider: " + random.getProvider().getName());
        System.out.println("Algorithm: " + random.getAlgorithm());

        // Generate random bytes
        byte[] randomBytes = new byte[32];
        random.nextBytes(randomBytes);
        System.out.println("Random Bytes: " + bytesToHex(randomBytes));

        // Generate random int
        int randomInt = random.nextInt();
        System.out.println("Random Int: " + randomInt);

        // Generate random int in range [0, bound)
        int randomInRange = random.nextInt(100);
        System.out.println("Random Int (0-99): " + randomInRange);

        // Specific algorithm (HashDRBG)
        SecureRandom hashDrbg = SecureRandom.getInstance("HashDRBG");
        hashDrbg.nextBytes(randomBytes);
        System.out.println("HashDRBG Random: " + bytesToHex(randomBytes));

        // Get instance strong (highest entropy)
        SecureRandom strongRandom = SecureRandom.getInstanceStrong();
        strongRandom.nextBytes(randomBytes);
        System.out.println("Strong Random: " + bytesToHex(randomBytes));
    }

    private static String bytesToHex(byte[] bytes) {
        StringBuilder result = new StringBuilder();
        for (byte b : bytes) {
            result.append(String.format("%02x", b));
        }
        return result.toString();
    }
}
```

---

## JSSE/TLS Operations

This section provides comprehensive examples of using JSSE with wolfJSSE provider.

### Basic TLS Connection

```java
import javax.net.ssl.*;
import java.io.*;
import java.net.Socket;

public class BasicTlsExample {
    public static void main(String[] args) throws Exception {
        String host = "www.google.com";
        int port = 443;

        // Create SSLContext
        SSLContext context = SSLContext.getInstance("TLS");
        context.init(null, null, null); // Uses default trust managers and system cacerts

        // Verify provider
        System.out.println("SSLContext Provider: " + context.getProvider().getName());

        // Create SSL socket
        SSLSocketFactory factory = context.getSocketFactory();
        SSLSocket socket = (SSLSocket) factory.createSocket(host, port);

        // Set SNI (Server Name Indication)
        SSLParameters sslParams = socket.getSSLParameters();
        sslParams.setServerNames(java.util.Arrays.asList(new SNIHostName(host)));
        socket.setSSLParameters(sslParams);

        // Perform handshake
        socket.startHandshake();

        // Get session info
        SSLSession session = socket.getSession();
        System.out.println("Protocol: " + session.getProtocol());
        System.out.println("Cipher Suite: " + session.getCipherSuite());
        System.out.println("Peer Host: " + session.getPeerHost());

        // Send HTTP request
        PrintWriter out = new PrintWriter(socket.getOutputStream(), true);
        BufferedReader in = new BufferedReader(new InputStreamReader(socket.getInputStream()));

        out.println("GET / HTTP/1.1");
        out.println("Host: " + host);
        out.println("Connection: close");
        out.println();

        // Read response
        String line;
        while ((line = in.readLine()) != null && !line.isEmpty()) {
            if (line.startsWith("HTTP/")) {
                System.out.println("Response: " + line);
                break;
            }
        }

        socket.close();
        System.out.println("TLS connection successful!");
    }
}
```

### Certificate Validation with Custom Trust Store

```java
import javax.net.ssl.*;
import java.io.*;
import java.security.*;

public class CustomTrustStoreExample {
    public static void main(String[] args) throws Exception {
        // Load custom WKS trust store
        KeyStore trustStore = KeyStore.getInstance("WKS");
        try (FileInputStream fis = new FileInputStream("/path/to/truststore.wks")) {
            trustStore.load(fis, "truststore_password".toCharArray());
        }

        // Create TrustManagerFactory
        TrustManagerFactory tmf = TrustManagerFactory.getInstance("PKIX");
        tmf.init(trustStore);

        // Verify provider
        System.out.println("TrustManagerFactory Provider: " + tmf.getProvider().getName());

        // Create SSLContext with custom trust managers
        SSLContext context = SSLContext.getInstance("TLS");
        context.init(null, tmf.getTrustManagers(), null);

        // Use context for connections
        SSLSocketFactory factory = context.getSocketFactory();
        SSLSocket socket = (SSLSocket) factory.createSocket("www.example.com", 443);
        socket.startHandshake();

        System.out.println("Certificate validation successful!");
        socket.close();
    }
}
```

### Client Authentication (Mutual TLS)

```java
import javax.net.ssl.*;
import java.io.*;
import java.security.*;

public class MutualTlsExample {
    public static void main(String[] args) throws Exception {
        // Load client keystore (contains client cert and private key)
        KeyStore keyStore = KeyStore.getInstance("WKS");
        try (FileInputStream fis = new FileInputStream("/path/to/client-keystore.wks")) {
            keyStore.load(fis, "keystore_password".toCharArray());
        }

        // Load trust store (contains CA certs)
        KeyStore trustStore = KeyStore.getInstance("WKS");
        try (FileInputStream fis = new FileInputStream("/path/to/truststore.wks")) {
            trustStore.load(fis, "truststore_password".toCharArray());
        }

        // Create KeyManagerFactory
        KeyManagerFactory kmf = KeyManagerFactory.getInstance("PKIX");
        kmf.init(keyStore, "key_password".toCharArray());

        // Create TrustManagerFactory
        TrustManagerFactory tmf = TrustManagerFactory.getInstance("PKIX");
        tmf.init(trustStore);

        // Create SSLContext with both key and trust managers
        SSLContext context = SSLContext.getInstance("TLS");
        context.init(kmf.getKeyManagers(), tmf.getTrustManagers(), null);

        // Connect with client certificate
        SSLSocketFactory factory = context.getSocketFactory();
        SSLSocket socket = (SSLSocket) factory.createSocket("server.example.com", 8443);

        // Require client authentication
        socket.setNeedClientAuth(true);

        socket.startHandshake();

        System.out.println("Mutual TLS successful!");
        System.out.println("Client authenticated with certificate");

        socket.close();
    }
}
```

### HTTPS URL Connection

```java
import javax.net.ssl.*;
import java.net.*;
import java.io.*;

public class HttpsUrlConnectionExample {
    public static void main(String[] args) throws Exception {
        // Create SSLContext
        SSLContext context = SSLContext.getInstance("TLS");
        context.init(null, null, null);

        // Set default SSLSocketFactory
        HttpsURLConnection.setDefaultSSLSocketFactory(context.getSocketFactory());

        // Create HTTPS connection
        URL url = new URL("https://httpbin.org/get");
        HttpsURLConnection connection = (HttpsURLConnection) url.openConnection();
        connection.setRequestMethod("GET");
        connection.setConnectTimeout(10000);
        connection.setReadTimeout(10000);

        // Get response
        int responseCode = connection.getResponseCode();
        System.out.println("Response Code: " + responseCode);

        if (responseCode == 200) {
            BufferedReader reader = new BufferedReader(
                new InputStreamReader(connection.getInputStream()));
            String line;
            StringBuilder response = new StringBuilder();

            while ((line = reader.readLine()) != null) {
                response.append(line).append("\n");
            }
            reader.close();

            System.out.println("Response:");
            System.out.println(response.toString());
        }

        // Get SSL session info
        SSLSession session = connection.getSSLSession();
        System.out.println("Protocol: " + session.getProtocol());
        System.out.println("Cipher Suite: " + session.getCipherSuite());

        connection.disconnect();
    }
}
```

### Protocol and Cipher Suite Configuration

```java
import javax.net.ssl.*;
import java.security.Security;

public class TlsConfigExample {
    public static void main(String[] args) throws Exception {
        SSLContext context = SSLContext.getInstance("TLS");
        context.init(null, null, null);

        SSLSocketFactory factory = context.getSocketFactory();
        SSLSocket socket = (SSLSocket) factory.createSocket();

        // Get supported protocols
        String[] supportedProtocols = socket.getSupportedProtocols();
        System.out.println("Supported Protocols:");
        for (String protocol : supportedProtocols) {
            System.out.println("  " + protocol);
        }

        // Set enabled protocols (TLS 1.2 and 1.3 only)
        socket.setEnabledProtocols(new String[]{"TLSv1.2", "TLSv1.3"});

        // Get supported cipher suites
        String[] supportedCiphers = socket.getSupportedCipherSuites();
        System.out.println("\nSupported Cipher Suites: " + supportedCiphers.length);

        // Filter for AES-GCM cipher suites
        java.util.List<String> gcmCiphers = new java.util.ArrayList<>();
        for (String cipher : supportedCiphers) {
            if (cipher.contains("AES") && cipher.contains("GCM")) {
                gcmCiphers.add(cipher);
                System.out.println("  " + cipher);
            }
        }

        // Set enabled cipher suites
        socket.setEnabledCipherSuites(gcmCiphers.toArray(new String[0]));

        System.out.println("\nEnabled " + gcmCiphers.size() + " AES-GCM cipher suites");

        socket.close();
    }
}
```

---

## Using the Image in Different Modes

### FIPS Mode (Production)

**Purpose**: Full FIPS compliance with validation

**Validation Steps**:
1. Library integrity verification (SHA-256 checksums)
2. wolfJCE/wolfJSSE provider registration verification
3. WKS cacerts format verification
4. FIPS POST execution
5. Algorithm availability checks
6. Provider configuration sanity checks

**Usage**:
```bash
# Default (FIPS mode)
docker run --rm java:17-jammy-ubuntu-22.04-fips

# With application
docker run --rm \
  -v /path/to/app:/app/user \
  java:17-jammy-ubuntu-22.04-fips \
  java -cp "/app/user:/usr/share/java/*" com.example.App

# With debug logging
docker run --rm \
  -e WOLFJCE_DEBUG=true \
  -e WOLFJSSE_DEBUG=true \
  java:17-jammy-ubuntu-22.04-fips
```

### Non-FIPS Mode (Development/Testing)

**Purpose**: Skip validation for faster startup and development

**What's Skipped**:
- Library integrity checks
- FIPS provider verification
- POST execution
- Algorithm checks

**What's Still Active**:
- wolfJCE/wolfJSSE providers (same configuration)
- FIPS-validated crypto (unless you change providers)
- WKS cacerts format

**Usage**:
```bash
# Skip FIPS validation
docker run --rm \
  -e FIPS_CHECK=false \
  java:17-jammy-ubuntu-22.04-fips

# With custom java.security
docker run --rm \
  -e FIPS_CHECK=false \
  -v /path/to/java.security:$JAVA_HOME/conf/security/java.security \
  java:17-jammy-ubuntu-22.04-fips

# Interactive development
docker run --rm -it \
  -e FIPS_CHECK=false \
  -v /path/to/app:/app/user \
  -w /app/user \
  java:17-jammy-ubuntu-22.04-fips \
  bash
```

**When to Use Non-FIPS Mode**:
- Local development and testing
- Debugging application issues
- Custom provider configurations
- Quick container startup
- CI/CD build steps (not runtime)

---

## Integration Patterns

### Pattern 1: Extend Base Image

```dockerfile
FROM java:17-jammy-ubuntu-22.04-fips

# Copy application JAR
COPY target/myapp.jar /app/myapp.jar

# Copy additional dependencies
COPY target/lib/*.jar /app/lib/

# Set classpath
ENV CLASSPATH=/app/myapp.jar:/app/lib/*:/usr/share/java/*

# Set entrypoint
ENTRYPOINT ["java", "com.example.Main"]
```

### Pattern 2: Multi-Stage Build

```dockerfile
# Build stage
FROM maven:3.9-openjdk-19 AS builder
WORKDIR /build
COPY pom.xml .
COPY src src
RUN mvn clean package -DskipTests

# Runtime stage
FROM java:17-jammy-ubuntu-22.04-fips
COPY --from=builder /build/target/myapp.jar /app/myapp.jar
ENTRYPOINT ["java", "-jar", "/app/myapp.jar"]
```

### Pattern 3: Volume Mount Application

```bash
# Development pattern
docker run --rm \
  -v $(pwd)/target:/app \
  -v $(pwd)/truststore.wks:/app/truststore.wks:ro \
  -e JAVA_OPTS="-Djavax.net.ssl.trustStore=/app/truststore.wks" \
  java:17-jammy-ubuntu-22.04-fips \
  java -cp "/app/*:/usr/share/java/*" com.example.App
```

### Pattern 4: Spring Boot Application

```dockerfile
FROM java:17-jammy-ubuntu-22.04-fips

# Copy Spring Boot JAR
COPY target/myapp-spring-boot.jar /app/app.jar

# Expose port
EXPOSE 8080

# Run Spring Boot
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
```

### Pattern 5: Microservice with Health Check

```dockerfile
FROM java:17-jammy-ubuntu-22.04-fips

COPY target/service.jar /app/service.jar

HEALTHCHECK --interval=30s --timeout=3s --start-period=40s \
  CMD curl -f http://localhost:8080/health || exit 1

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/service.jar"]
```

---

## Best Practices and Common Pitfalls

### Best Practices

1. **Use Standard JCA/JSSE APIs**
   - Don't hardcode provider names unless absolutely necessary
   - Let provider priority handle selection

2. **Always Use WKS for FIPS Compliance**
   - Convert JKS/PKCS12 to WKS
   - Don't load JKS/PKCS12 keystores directly

3. **Keep Providers at Correct Priority**
   - wolfJCE must be priority 1
   - wolfJSSE must be priority 2
   - Don't modify java.security provider order

4. **Use FIPS-Approved Algorithms**
   - SHA-256 or higher for hashing
   - AES-GCM for authenticated encryption
   - RSA 2048+ or EC P-256+ for asymmetric

5. **Enable Debug Logging During Development**
   ```bash
   -e WOLFJCE_DEBUG=true -e WOLFJSSE_DEBUG=true
   ```

6. **Verify Providers in Production**
   - Check that wolfJCE/wolfJSSE are loaded
   - Verify FIPS POST passed
   - Monitor for algorithm failures

7. **Use Proper IV Generation**
   - Always use SecureRandom for IVs
   - Don't reuse IVs with same key (especially GCM)

8. **Handle Sensitive Data Securely**
   - Clear sensitive byte arrays after use
   - Use char[] for passwords, not String
   - Don't log sensitive data

### Common Pitfalls

1. **Forgetting to Set SNI**
   ```java
   // Wrong - may fail with virtual hosts
   SSLSocket socket = (SSLSocket) factory.createSocket("www.example.com", 443);

   // Correct
   SSLSocket socket = (SSLSocket) factory.createSocket("www.example.com", 443);
   SSLParameters params = socket.getSSLParameters();
   params.setServerNames(Arrays.asList(new SNIHostName("www.example.com")));
   socket.setSSLParameters(params);
   ```

2. **Using Wrong Keystore Password**
   ```java
   // System cacerts use different password
   trustStore.load(fis, "changeitchangeit".toCharArray()); // Correct for WKS cacerts
   // NOT "changeit" (JKS default)
   ```

3. **Not Specifying GCMParameterSpec for AES-GCM**
   ```java
   // Wrong - will fail
   cipher.init(Cipher.ENCRYPT_MODE, key);

   // Correct
   GCMParameterSpec spec = new GCMParameterSpec(128, iv);
   cipher.init(Cipher.ENCRYPT_MODE, key, spec);
   ```

4. **Modifying Providers at Runtime (FIPS Mode)**
   ```java
   // Wrong in FIPS mode - bypasses enforcement
   Security.removeProvider("wolfJCE");
   Security.addProvider(new MyProvider());

   // Correct - use configured providers
   // Don't modify Security.providers in FIPS mode
   ```

5. **Expecting JKS Keystore to Work**
   ```java
   // Wrong - will fail in FIPS mode
   KeyStore ks = KeyStore.getInstance("JKS");

   // Correct
   KeyStore ks = KeyStore.getInstance("WKS");
   ```

6. **Not Checking Provider**
   ```java
   // Good practice - verify provider
   MessageDigest md = MessageDigest.getInstance("SHA-256");
   assert "wolfJCE".equals(md.getProvider().getName());
   ```

---

## Troubleshooting Guide

### Issue: NoSuchAlgorithmException

**Problem**: `java.security.NoSuchAlgorithmException: SHA-256 MessageDigest not available`

**Cause**: Provider not loaded or algorithm not implemented

**Solution**:
```bash
# Check providers
docker run --rm java:17-jammy-ubuntu-22.04-fips \
  java -cp "/opt/wolfssl-fips/bin:/usr/share/java/*" -c "
    import java.security.Security;
    for (var p : Security.getProviders()) {
        System.out.println(p.getName() + \" \" + p.getVersion());
    }
  "

# Expected: wolfJCE, wolfJSSE at top
```

### Issue: KeyStoreException - WKS not found

**Problem**: `java.security.KeyStoreException: WKS not available`

**Cause**: wolf JCE provider not loaded

**Solution**:
```java
// Ensure wolfJCE is loaded
Provider wolfJCE = Security.getProvider("wolfJCE");
if (wolfJCE == null) {
    throw new RuntimeException("wolfJCE not loaded - check java.security");
}

// Then get WKS
KeyStore ks = KeyStore.getInstance("WKS");
```

### Issue: Certificate Validation Fails

**Problem**: `javax.net.ssl.SSLHandshakeException: PKIX path building failed`

**Cause**: CA certificate not in trust store or SNI not set

**Solution**:
```java
// 1. Check trust store has CA cert
KeyStore trustStore = KeyStore.getInstance("WKS");
trustStore.load(new FileInputStream(...), password);
String alias = trustStore.getCertificateAlias(caCert);
if (alias == null) {
    System.err.println("CA cert not in trust store!");
}

// 2. Ensure SNI is set
SSLParameters params = socket.getSSLParameters();
params.setServerNames(Arrays.asList(new SNIHostName(hostname)));
socket.setSSLParameters(params);
```

### Issue: Library Not Found

**Problem**: `UnsatisfiedLinkError: no wolfcryptjni in java.library.path`

**Cause**: Native library not in LD_LIBRARY_PATH

**Solution**:
```bash
# Check library paths
docker run --rm java:17-jammy-ubuntu-22.04-fips bash -c \
  "echo LD_LIBRARY_PATH=\$LD_LIBRARY_PATH && ldconfig -p | grep wolf"

# Expected output:
# LD_LIBRARY_PATH=/usr/lib/jni:/usr/local/lib
# libwolfssl.so.42 => /usr/local/lib/libwolfssl.so.42
# libwolfssljni.so => /usr/lib/jni/libwolfssljni.so
# libwolfcryptjni.so => /usr/lib/jni/libwolfcryptjni.so
```

### Issue: FIPS POST Fails

**Problem**: Container exits with "FIPS POST failed"

**Cause**: Library integrity check failed or POST test failed

**Solution**:
```bash
# Run integrity check manually
docker run --rm java:17-jammy-ubuntu-22.04-fips \
  /usr/local/bin/integrity-check.sh

# Check library checksums
docker run --rm java:17-jammy-ubuntu-22.04-fips bash -c \
  "cat /opt/wolfssl-fips/checksums/libraries.sha256"

# If checksums don't match, rebuild image
```

### Issue: Performance Problems

**Problem**: Slow cryptographic operations

**Cause**: Debug logging enabled

**Solution**:
```bash
# Disable debug logging
docker run --rm \
  -e WOLFJCE_DEBUG=false \
  -e WOLFJSSE_DEBUG=false \
  java:17-jammy-ubuntu-22.04-fips

# Use larger heap if needed
docker run --rm \
  -e JAVA_OPTS="-Xmx2g" \
  java:17-jammy-ubuntu-22.04-fips
```

### Getting Help

1. **Enable Full Debug Output**:
   ```bash
   docker run --rm \
     -e WOLFJCE_DEBUG=true \
     -e WOLFJSSE_DEBUG=true \
     -e JAVA_OPTS="-Djava.security.debug=all" \
     java:17-jammy-ubuntu-22.04-fips \
     2>&1 | tee debug-output.log
   ```

2. **Check Container Logs**:
   ```bash
   docker logs <container-id> > container.log 2>&1
   ```

3. **Run Diagnostics**:
   ```bash
   ./diagnostic.sh > diagnostics.log 2>&1
   ```

4. **Inspect Configuration**:
   ```bash
   docker run --rm java:17-jammy-ubuntu-22.04-fips bash -c \
     "cat \$JAVA_HOME/conf/security/java.security | grep security.provider"
   ```

---

## Additional Resources

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Detailed architecture documentation
- **[KEYSTORE-TRUST-STORE-GUIDE.md](KEYSTORE-TRUST-STORE-GUIDE.md)** - Complete keystore guide
- **[EXAMPLES.md](EXAMPLES.md)** - Additional code examples
- **[diagnostics/test-images/basic-test-image/](diagnostics/test-images/basic-test-image/)** - Comprehensive test suite
- **[wolfSSL Documentation](https://www.wolfssl.com/documentation/)** - wolfSSL reference
- **[Java Security Documentation](https://docs.oracle.com/en/java/javase/19/security/)** - Oracle JCA/JSSE docs

---

## Feedback and Contributions

This is a living document. If you find issues or have suggestions:

1. Review the code examples in `diagnostics/test-images/basic-test-image/`
2. Check existing documentation
3. Run diagnostics: `./diagnostic.sh`
4. Report issues with full debug output

---

**Last Updated**: 2025-01-XX
**Version**: 1.0
**wolfSSL FIPS Version**: v5.8.2 (Certificate #4718)
**OpenJDK Version**: 19
