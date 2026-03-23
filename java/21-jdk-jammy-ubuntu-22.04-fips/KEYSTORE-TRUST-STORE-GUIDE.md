# Keystore and Trust Store Guide

Complete guide to understanding and using keystores and trust stores in the wolfSSL FIPS Java container, with focus on WKS (WolfSSL KeyStore) format.

## Table of Contents

1. [Introduction to Java Keystores](#introduction-to-java-keystores)
2. [Trust Store vs Key Store](#trust-store-vs-key-store)
3. [Keystore Formats Comparison](#keystore-formats-comparison)
4. [Why WKS for FIPS Compliance](#why-wks-for-fips-compliance)
5. [WKS Format and Structure](#wks-format-and-structure)
6. [System CA Certificates in WKS](#system-ca-certificates-in-wks)
7. [Working with WKS Keystores](#working-with-wks-keystores)
8. [Converting Keystores to WKS](#converting-keystores-to-wks)
9. [Managing Certificates in WKS](#managing-certificates-in-wks)
10. [Best Practices](#best-practices)
11. [Troubleshooting](#troubleshooting)

---

## Introduction to Java Keystores

### What is a Keystore?

A keystore is a repository for cryptographic keys and certificates. In Java, keystores are used to:
- Store private keys and their associated certificate chains (for authentication)
- Store trusted CA certificates (for validating others)
- Provide cryptographic material to applications

### Keystore Components

**Private Key Entry**:
- Private key (encrypted)
- Certificate chain (public key certificates)
- Alias (unique name for this entry)
- Password (protects private key)

**Trusted Certificate Entry**:
- X.509 certificate
- Alias (unique name)
- No private key, no password needed

### Common Use Cases

1. **TLS Client Authentication**: Store client certificate and private key
2. **TLS Server Authentication**: Validate server certificates using trusted CAs
3. **Code Signing**: Store signing certificates and keys
4. **Email Encryption**: Store S/MIME certificates

---

## Trust Store vs Key Store

While technically the same structure, trust stores and key stores serve different purposes:

### Trust Store

**Purpose**: Validate certificates from others (servers, peers)

**Contents**:
- CA (Certificate Authority) certificates
- Intermediate CA certificates
- Self-signed certificates you trust

**Usage**:
```java
// TLS client validating server certificate
TrustManagerFactory tmf = TrustManagerFactory.getInstance("PKIX");
tmf.init(trustStore); // trustStore contains CA certs
SSLContext.init(null, tmf.getTrustManagers(), null);
```

**Example**: System `cacerts` file containing root CA certificates from DigiCert, Let's Encrypt, etc.

### Key Store

**Purpose**: Store your own certificates and private keys

**Contents**:
- Your private keys
- Your certificate chains
- Your identity credentials

**Usage**:
```java
// TLS server or client presenting own certificate
KeyManagerFactory kmf = KeyManagerFactory.getInstance("PKIX");
kmf.init(keyStore, keyPassword); // keyStore contains your cert+key
SSLContext.init(kmf.getKeyManagers(), null, null);
```

**Example**: Application keystore with server certificate for HTTPS server

### Key Differences

| Aspect | Trust Store | Key Store |
|--------|-------------|-----------|
| **Contains** | CA certificates (public keys only) | Private keys + certificate chains |
| **Purpose** | Validate others | Authenticate self |
| **Password** | Optional (no private keys) | Required (protects private keys) |
| **TLS Role** | Client validating server | Server/client presenting certificate |
| **Sensitivity** | Medium (public CAs) | High (private keys) |

---

## Keystore Formats Comparison

### JKS (Java KeyStore)

**Description**: Sun's proprietary keystore format

**Characteristics**:
- Default format in older Java versions (pre-9)
- Uses MD5 and DES for integrity/encryption
- Not FIPS compliant (uses non-approved algorithms)
- Default password: `changeit`

**File Extension**: `.jks`

**Usage**:
```java
KeyStore jksStore = KeyStore.getInstance("JKS");
jksStore.load(new FileInputStream("keystore.jks"), "changeit".toCharArray());
```

**FIPS Status**: ❌ **NOT FIPS Compliant**

### PKCS#12

**Description**: RSA's Public-Key Cryptography Standards #12

**Characteristics**:
- Industry standard format
- Uses SHA-1/SHA-256 and 3DES/AES
- Better than JKS but still uses some non-FIPS algorithms
- Default format in Java 9+
- More portable across platforms

**File Extension**: `.p12`, `.pfx`

**Usage**:
```java
KeyStore p12Store = KeyStore.getInstance("PKCS12");
p12Store.load(new FileInputStream("keystore.p12"), password.toCharArray());
```

**FIPS Status**: ⚠️ **Partially FIPS** (depends on algorithms used)

### WKS (WolfSSL KeyStore)

**Description**: wolfSSL's FIPS-compliant keystore format

**Characteristics**:
- Uses only FIPS-approved algorithms
- SHA-256 for integrity (not MD5)
- AES-256-CBC for encryption (not DES/3DES)
- Implemented by wolfJCE provider
- Required for full FIPS compliance

**File Extension**: `.wks`

**Usage**:
```java
KeyStore wksStore = KeyStore.getInstance("WKS");
wksStore.load(new FileInputStream("keystore.wks"), password.toCharArray());
```

**FIPS Status**: ✅ **Fully FIPS Compliant**

### Format Comparison Table

| Feature | JKS | PKCS#12 | WKS |
|---------|-----|---------|-----|
| **Standard** | Sun proprietary | RSA standard | wolfSSL proprietary |
| **Integrity Hash** | MD5 | SHA-1/SHA-256 | SHA-256 |
| **Encryption** | DES | 3DES/AES | AES-256-CBC |
| **FIPS Compliant** | ❌ No | ⚠️ Partial | ✅ Yes |
| **Portability** | Java only | Cross-platform | Java (wolfJCE) only |
| **Default Password** | changeit | varies | varies |
| **Recommended For** | Legacy systems | General use | FIPS environments |

---

## Why WKS for FIPS Compliance

### The FIPS Problem with JKS/PKCS#12

FIPS 140-3 requires that **all cryptographic operations** use validated algorithms. Traditional keystore formats violate this:

**JKS Issues**:
1. **MD5 for integrity**: MD5 is not FIPS-approved
2. **DES for encryption**: DES is not FIPS-approved
3. **Proprietary format**: Not standardized, uses Sun-specific crypto

**PKCS#12 Issues**:
1. **SHA-1 usage**: SHA-1 is deprecated in FIPS 140-3
2. **3DES encryption**: 3DES has security concerns
3. **Legacy mode**: Many PKCS#12 files use old algorithms

### How WKS Achieves FIPS Compliance

WKS keystore format was designed specifically for FIPS environments:

1. **SHA-256 Integrity**:
   - Uses SHA-256 for HMAC (not MD5)
   - FIPS-approved hash algorithm

2. **AES-256-CBC Encryption**:
   - Uses AES-256-CBC for key encryption (not DES/3DES)
   - FIPS-approved symmetric algorithm

3. **wolfCrypt FIPS Backend**:
   - All operations route through FIPS-validated wolfSSL
   - Maintains FIPS boundary integrity

4. **No Fallback**:
   - Does not support non-FIPS algorithms
   - Fails explicitly if FIPS requirements not met

### FIPS Validation Chain

```
Application
    ↓
KeyStore.getInstance("WKS")
    ↓
wolfJCE Provider (WolfSSLKeyStore implementation)
    ↓
JNI Bridge (libwolfcryptjni.so)
    ↓
libwolfssl.so (FIPS 140-3 Certificate #4718)
```

Every operation stays within the FIPS boundary.

---

## WKS Format and Structure

### Internal Structure

WKS format stores:

```
WKS Keystore File (.wks)
├── Version Number
├── Integrity Hash (SHA-256 HMAC)
├── Entry Count
└── Entries
    ├── Entry 1
    │   ├── Type (PrivateKeyEntry or TrustedCertEntry)
    │   ├── Alias (UTF-8 string)
    │   ├── Timestamp
    │   ├── Certificate(s) (X.509 DER-encoded)
    │   └── Private Key (if PrivateKeyEntry, AES-256-CBC encrypted)
    ├── Entry 2
    └── ...
```

### Entry Types

**Trusted Certificate Entry**:
- Contains only public key certificate
- No encryption needed
- Used for CA certificates in trust stores

**Private Key Entry**:
- Contains private key (encrypted with AES-256-CBC)
- Contains certificate chain
- Requires password for access

### Password Usage

**Store Password**:
- Protects keystore integrity (HMAC key derivation)
- Required for loading keystore
- Used for: `keyStore.load(fis, storePassword)`

**Key Password**:
- Protects individual private keys
- Can be same as or different from store password
- Used for: `keyStore.getKey(alias, keyPassword)`

---

## System CA Certificates in WKS

### Location and Details

**Path**: `$JAVA_HOME/lib/security/cacerts`

**Format**: WKS (converted from JKS during container build)

**Password**: `changeitchangeit` (note: different from JKS's `changeit`)

**Certificate Count**: ~130 CA certificates (varies by system)

**Purpose**: Trust store for validating TLS server certificates

### Conversion During Build

The container build process converts system CA certificates:

```bash
# Dockerfile excerpt (lines 141-151)
# Convert JKS cacerts to WKS format using wolfcrypt-jni script
cd examples/certs/systemcerts
./system-cacerts-to-wks.sh ../../../lib/wolfcrypt-jni.jar
cp cacerts.wks /build/cacerts.wks

# Runtime image copies WKS cacerts
COPY --from=wolfjce-builder /build/artifacts/certs/cacerts.wks \
    $JAVA_HOME/lib/security/cacerts
```

### Loading System Trust Store

```java
import java.io.*;
import java.security.KeyStore;

public class LoadSystemTrustStore {
    public static void main(String[] args) throws Exception {
        // Get cacerts path
        String javaHome = System.getProperty("java.home");
        String cacertsPath = javaHome + "/lib/security/cacerts";

        // Load WKS trust store
        KeyStore trustStore = KeyStore.getInstance("WKS");
        try (FileInputStream fis = new FileInputStream(cacertsPath)) {
            trustStore.load(fis, "changeitchangeit".toCharArray());
        }

        System.out.println("Loaded " + trustStore.size() + " CA certificates");

        // List CA aliases
        java.util.Enumeration<String> aliases = trustStore.aliases();
        while (aliases.hasMoreElements()) {
            String alias = aliases.nextElement();
            System.out.println("  " + alias);
        }
    }
}
```

### Verifying WKS Format

```bash
# Check cacerts is WKS format
docker run --rm java:21-jdk-jammy-ubuntu-22.04-fips bash -c \
  "file \$JAVA_HOME/lib/security/cacerts"

# Expected: data (not Java KeyStore)

# Load and count certificates
docker run --rm java:21-jdk-jammy-ubuntu-22.04-fips \
  java -cp "/opt/wolfssl-fips/bin:/usr/share/java/*" -c "
    import java.security.KeyStore;
    import java.io.*;
    String javaHome = System.getProperty(\"java.home\");
    KeyStore ks = KeyStore.getInstance(\"WKS\");
    try (FileInputStream fis = new FileInputStream(
        javaHome + \"/lib/security/cacerts\")) {
      ks.load(fis, \"changeitchangeit\".toCharArray());
      System.out.println(\"Certificates: \" + ks.size());
    }
  "
```

---

## Working with WKS Keystores

### Creating New WKS Keystore

```java
import java.io.*;
import java.security.*;
import java.security.cert.*;

public class CreateWksKeystore {
    public static void main(String[] args) throws Exception {
        // Create empty WKS keystore
        KeyStore keyStore = KeyStore.getInstance("WKS");
        keyStore.load(null, null); // Initialize with null = empty

        // Add a trusted certificate
        CertificateFactory cf = CertificateFactory.getInstance("X.509");
        Certificate caCert = cf.generateCertificate(
            new FileInputStream("/path/to/ca-cert.pem"));

        keyStore.setCertificateEntry("my-ca", caCert);

        // Save to file
        try (FileOutputStream fos = new FileOutputStream("truststore.wks")) {
            keyStore.store(fos, "trustStorePassword".toCharArray());
        }

        System.out.println("Created WKS truststore with 1 CA certificate");
    }
}
```

### Adding Private Key and Certificate

```java
import java.io.*;
import java.security.*;
import java.security.cert.*;
import java.security.spec.*;

public class AddKeyToWks {
    public static void main(String[] args) throws Exception {
        // Load existing WKS keystore (or create new)
        KeyStore keyStore = KeyStore.getInstance("WKS");
        try (FileInputStream fis = new FileInputStream("keystore.wks")) {
            keyStore.load(fis, "storePassword".toCharArray());
        } catch (FileNotFoundException e) {
            keyStore.load(null, null); // Create new if doesn't exist
        }

        // Load private key (example: from PKCS#8 PEM)
        PrivateKey privateKey = loadPrivateKeyFromPem("/path/to/private-key.pem");

        // Load certificate chain
        CertificateFactory cf = CertificateFactory.getInstance("X.509");
        Certificate[] chain = new Certificate[2];
        chain[0] = cf.generateCertificate(
            new FileInputStream("/path/to/cert.pem"));
        chain[1] = cf.generateCertificate(
            new FileInputStream("/path/to/ca-cert.pem"));

        // Add private key entry
        keyStore.setKeyEntry(
            "my-key",                           // alias
            privateKey,                         // private key
            "keyPassword".toCharArray(),        // key password
            chain                               // certificate chain
        );

        // Save keystore
        try (FileOutputStream fos = new FileOutputStream("keystore.wks")) {
            keyStore.store(fos, "storePassword".toCharArray());
        }

        System.out.println("Added private key and certificate chain to WKS keystore");
    }

    private static PrivateKey loadPrivateKeyFromPem(String path) throws Exception {
        // Load PEM file
        String pem = new String(java.nio.file.Files.readAllBytes(
            java.nio.file.Paths.get(path)));

        // Remove PEM headers/footers
        pem = pem.replace("-----BEGIN PRIVATE KEY-----", "");
        pem = pem.replace("-----END PRIVATE KEY-----", "");
        pem = pem.replaceAll("\\s", "");

        // Decode base64
        byte[] encoded = java.util.Base64.getDecoder().decode(pem);

        // Create private key
        KeyFactory keyFactory = KeyFactory.getInstance("RSA");
        PKCS8EncodedKeySpec keySpec = new PKCS8EncodedKeySpec(encoded);
        return keyFactory.generatePrivate(keySpec);
    }
}
```

### Reading from WKS Keystore

```java
import java.io.*;
import java.security.*;
import java.security.cert.*;

public class ReadWksKeystore {
    public static void main(String[] args) throws Exception {
        // Load WKS keystore
        KeyStore keyStore = KeyStore.getInstance("WKS");
        try (FileInputStream fis = new FileInputStream("keystore.wks")) {
            keyStore.load(fis, "storePassword".toCharArray());
        }

        // List all aliases
        System.out.println("Keystore entries:");
        java.util.Enumeration<String> aliases = keyStore.aliases();
        while (aliases.hasMoreElements()) {
            String alias = aliases.nextElement();
            System.out.println("\nAlias: " + alias);

            if (keyStore.isKeyEntry(alias)) {
                System.out.println("  Type: Private Key Entry");

                // Get private key
                Key key = keyStore.getKey(alias, "keyPassword".toCharArray());
                System.out.println("  Key Algorithm: " + key.getAlgorithm());

                // Get certificate chain
                Certificate[] chain = keyStore.getCertificateChain(alias);
                System.out.println("  Certificate Chain Length: " + chain.length);

                for (int i = 0; i < chain.length; i++) {
                    X509Certificate cert = (X509Certificate) chain[i];
                    System.out.println("    [" + i + "] Subject: " +
                        cert.getSubjectX500Principal().getName());
                }
            } else if (keyStore.isCertificateEntry(alias)) {
                System.out.println("  Type: Trusted Certificate Entry");

                Certificate cert = keyStore.getCertificate(alias);
                if (cert instanceof X509Certificate) {
                    X509Certificate x509 = (X509Certificate) cert;
                    System.out.println("  Subject: " +
                        x509.getSubjectX500Principal().getName());
                    System.out.println("  Issuer: " +
                        x509.getIssuerX500Principal().getName());
                }
            }
        }
    }
}
```

---

## Converting Keystores to WKS

### JKS to WKS Conversion

```java
import java.io.*;
import java.security.*;
import java.security.cert.*;

public class ConvertJksToWks {
    public static void main(String[] args) throws Exception {
        String jksFile = "keystore.jks";
        String jksPassword = "changeit";
        String wksFile = "keystore.wks";
        String wksPassword = "newpassword";

        // Load JKS keystore
        KeyStore jksStore = KeyStore.getInstance("JKS");
        try (FileInputStream fis = new FileInputStream(jksFile)) {
            jksStore.load(fis, jksPassword.toCharArray());
        }

        // Create new WKS keystore
        KeyStore wksStore = KeyStore.getInstance("WKS");
        wksStore.load(null, null);

        // Copy all entries
        java.util.Enumeration<String> aliases = jksStore.aliases();
        while (aliases.hasMoreElements()) {
            String alias = aliases.nextElement();

            if (jksStore.isKeyEntry(alias)) {
                // Copy private key entry
                Key key = jksStore.getKey(alias, jksPassword.toCharArray());
                Certificate[] chain = jksStore.getCertificateChain(alias);
                wksStore.setKeyEntry(alias, key, wksPassword.toCharArray(), chain);

                System.out.println("Copied key entry: " + alias);

            } else if (jksStore.isCertificateEntry(alias)) {
                // Copy certificate entry
                Certificate cert = jksStore.getCertificate(alias);
                wksStore.setCertificateEntry(alias, cert);

                System.out.println("Copied certificate entry: " + alias);
            }
        }

        // Save WKS keystore
        try (FileOutputStream fos = new FileOutputStream(wksFile)) {
            wksStore.store(fos, wksPassword.toCharArray());
        }

        System.out.println("\nConversion complete: " + jksFile + " -> " + wksFile);
        System.out.println("Total entries: " + wksStore.size());
    }
}
```

### PKCS#12 to WKS Conversion

```java
import java.io.*;
import java.security.*;
import java.security.cert.*;

public class ConvertPkcs12ToWks {
    public static void main(String[] args) throws Exception {
        String p12File = "keystore.p12";
        String p12Password = "password";
        String wksFile = "keystore.wks";
        String wksPassword = "newpassword";

        // Load PKCS#12 keystore
        KeyStore p12Store = KeyStore.getInstance("PKCS12");
        try (FileInputStream fis = new FileInputStream(p12File)) {
            p12Store.load(fis, p12Password.toCharArray());
        }

        // Create new WKS keystore
        KeyStore wksStore = KeyStore.getInstance("WKS");
        wksStore.load(null, null);

        // Copy all entries (same process as JKS)
        java.util.Enumeration<String> aliases = p12Store.aliases();
        while (aliases.hasMoreElements()) {
            String alias = aliases.nextElement();

            if (p12Store.isKeyEntry(alias)) {
                Key key = p12Store.getKey(alias, p12Password.toCharArray());
                Certificate[] chain = p12Store.getCertificateChain(alias);
                wksStore.setKeyEntry(alias, key, wksPassword.toCharArray(), chain);
                System.out.println("Copied key entry: " + alias);
            } else if (p12Store.isCertificateEntry(alias)) {
                Certificate cert = p12Store.getCertificate(alias);
                wksStore.setCertificateEntry(alias, cert);
                System.out.println("Copied certificate entry: " + alias);
            }
        }

        // Save WKS keystore
        try (FileOutputStream fos = new FileOutputStream(wksFile)) {
            wksStore.store(fos, wksPassword.toCharArray());
        }

        System.out.println("\nConversion complete: " + p12File + " -> " + wksFile);
    }
}
```

### Using Container for Conversion

```bash
# Run conversion inside container
docker run --rm -it \
  -v /path/to/keystores:/keystores \
  java:21-jdk-jammy-ubuntu-22.04-fips bash

# Inside container, create conversion script
cat > /tmp/convert.java << 'EOF'
import java.io.*;
import java.security.*;

public class convert {
    public static void main(String[] args) throws Exception {
        // Load JKS
        KeyStore jks = KeyStore.getInstance("JKS");
        try (FileInputStream fis = new FileInputStream(args[0])) {
            jks.load(fis, args[1].toCharArray());
        }

        // Create WKS
        KeyStore wks = KeyStore.getInstance("WKS");
        wks.load(null, null);

        // Copy entries
        java.util.Enumeration<String> aliases = jks.aliases();
        while (aliases.hasMoreElements()) {
            String alias = aliases.nextElement();
            if (jks.isKeyEntry(alias)) {
                Key key = jks.getKey(alias, args[1].toCharArray());
                Certificate[] chain = jks.getCertificateChain(alias);
                wks.setKeyEntry(alias, key, args[2].toCharArray(), chain);
            } else if (jks.isCertificateEntry(alias)) {
                wks.setCertificateEntry(alias, jks.getCertificate(alias));
            }
        }

        // Save WKS
        try (FileOutputStream fos = new FileOutputStream(args[3])) {
            wks.store(fos, args[2].toCharArray());
        }
        System.out.println("Converted: " + args[0] + " -> " + args[3]);
    }
}
EOF

# Compile and run
javac /tmp/convert.java
java -cp "/tmp:/usr/share/java/*" convert \
  /keystores/input.jks \
  jkspassword \
  wkspassword \
  /keystores/output.wks
```

---

## Managing Certificates in WKS

### Adding CA Certificate

```java
import java.io.*;
import java.security.KeyStore;
import java.security.cert.*;

public class AddCaCertificate {
    public static void main(String[] args) throws Exception {
        // Load existing WKS trust store
        KeyStore trustStore = KeyStore.getInstance("WKS");
        try (FileInputStream fis = new FileInputStream("truststore.wks")) {
            trustStore.load(fis, "password".toCharArray());
        } catch (FileNotFoundException e) {
            trustStore.load(null, null); // Create new if doesn't exist
        }

        // Load CA certificate from PEM file
        CertificateFactory cf = CertificateFactory.getInstance("X.509");
        Certificate caCert = cf.generateCertificate(
            new FileInputStream("/path/to/ca-cert.pem"));

        // Add to trust store
        String alias = "my-custom-ca";
        trustStore.setCertificateEntry(alias, caCert);

        // Save trust store
        try (FileOutputStream fos = new FileOutputStream("truststore.wks")) {
            trustStore.store(fos, "password".toCharArray());
        }

        System.out.println("Added CA certificate with alias: " + alias);
        System.out.println("Total certificates: " + trustStore.size());
    }
}
```

### Deleting Certificate

```java
import java.io.*;
import java.security.KeyStore;

public class DeleteCertificate {
    public static void main(String[] args) throws Exception {
        String alias = "certificate-to-delete";

        // Load WKS keystore
        KeyStore keyStore = KeyStore.getInstance("WKS");
        try (FileInputStream fis = new FileInputStream("keystore.wks")) {
            keyStore.load(fis, "password".toCharArray());
        }

        // Check if alias exists
        if (!keyStore.containsAlias(alias)) {
            System.out.println("Alias not found: " + alias);
            return;
        }

        // Delete entry
        keyStore.deleteEntry(alias);

        // Save keystore
        try (FileOutputStream fos = new FileOutputStream("keystore.wks")) {
            keyStore.store(fos, "password".toCharArray());
        }

        System.out.println("Deleted entry: " + alias);
        System.out.println("Remaining entries: " + keyStore.size());
    }
}
```

### Changing Password

```java
import java.io.*;
import java.security.*;

public class ChangeKeystorePassword {
    public static void main(String[] args) throws Exception {
        String keystoreFile = "keystore.wks";
        char[] oldPassword = "oldpassword".toCharArray();
        char[] newPassword = "newpassword".toCharArray();

        // Load with old password
        KeyStore keyStore = KeyStore.getInstance("WKS");
        try (FileInputStream fis = new FileInputStream(keystoreFile)) {
            keyStore.load(fis, oldPassword);
        }

        // Re-encrypt private keys with new password
        java.util.Enumeration<String> aliases = keyStore.aliases();
        while (aliases.hasMoreElements()) {
            String alias = aliases.nextElement();

            if (keyStore.isKeyEntry(alias)) {
                // Get private key with old password
                Key key = keyStore.getKey(alias, oldPassword);
                Certificate[] chain = keyStore.getCertificateChain(alias);

                // Re-add with new password
                keyStore.setKeyEntry(alias, key, newPassword, chain);
            }
        }

        // Save with new password
        try (FileOutputStream fos = new FileOutputStream(keystoreFile)) {
            keyStore.store(fos, newPassword);
        }

        // Clear sensitive data
        java.util.Arrays.fill(oldPassword, ' ');
        java.util.Arrays.fill(newPassword, ' ');

        System.out.println("Keystore password changed successfully");
    }
}
```

---

## Best Practices

### Security Best Practices

1. **Use Strong Passwords**:
   ```java
   // Generate strong password
   SecureRandom random = new SecureRandom();
   byte[] passwordBytes = new byte[32];
   random.nextBytes(passwordBytes);
   String password = Base64.getEncoder().encodeToString(passwordBytes);
   ```

2. **Protect Keystore Files**:
   ```bash
   # Set restrictive permissions
   chmod 600 keystore.wks
   chmod 600 truststore.wks

   # Don't commit to version control
   echo "*.wks" >> .gitignore
   echo "*.p12" >> .gitignore
   ```

3. **Use Separate Passwords**:
   ```java
   // Different passwords for store and keys
   keyStore.store(fos, storePassword);  // Store password
   keyStore.setKeyEntry(alias, key, keyPassword, chain);  // Key password
   ```

4. **Clear Sensitive Data**:
   ```java
   // Clear password arrays when done
   char[] password = getPassword();
   try {
       keyStore.load(fis, password);
   } finally {
       java.util.Arrays.fill(password, ' ');
   }
   ```

### Operational Best Practices

1. **Backup Keystores**:
   ```bash
   # Automated backup
   cp keystore.wks keystore.wks.backup.$(date +%Y%m%d)
   ```

2. **Version Control Metadata Only**:
   ```
   # In .gitignore
   *.wks
   *.jks
   *.p12

   # In README
   See keystore-template.wks.example for format
   ```

3. **Use Environment Variables for Passwords**:
   ```java
   String password = System.getenv("KEYSTORE_PASSWORD");
   if (password == null) {
       throw new IllegalStateException("KEYSTORE_PASSWORD not set");
   }
   ```

4. **Validate Certificates**:
   ```java
   X509Certificate cert = (X509Certificate) keyStore.getCertificate(alias);

   // Check expiration
   try {
       cert.checkValidity();
       System.out.println("Certificate is valid");
   } catch (CertificateExpiredException e) {
       System.err.println("Certificate expired!");
   }

   // Check subject
   String subject = cert.getSubjectX500Principal().getName();
   System.out.println("Subject: " + subject);
   ```

### Container-Specific Practices

1. **Mount Keystores as Secrets**:
   ```bash
   # Docker
   docker run --rm \
     -v /secure/keystore.wks:/app/keystore.wks:ro \
     -e KEYSTORE_PASSWORD_FILE=/run/secrets/ks_password \
     java:21-jdk-jammy-ubuntu-22.04-fips

   # Kubernetes
   kubectl create secret generic app-keystore \
     --from-file=keystore.wks=/path/to/keystore.wks
   ```

2. **Use Init Containers for Keystore Setup**:
   ```yaml
   # Kubernetes example
   initContainers:
   - name: setup-keystore
     image: java:21-jdk-jammy-ubuntu-22.04-fips
     command: ['sh', '-c', 'convert-jks-to-wks.sh']
     volumeMounts:
     - name: keystore
       mountPath: /keystores
   ```

3. **Read-Only Mounts**:
   ```bash
   # Trust stores should be read-only
   docker run --rm \
     -v /path/to/truststore.wks:/app/truststore.wks:ro \
     java:21-jdk-jammy-ubuntu-22.04-fips
   ```

---

## Troubleshooting

### Common Issues

#### Issue: "WKS not available"

**Error**: `java.security.KeyStoreException: WKS not available`

**Cause**: wolfJCE provider not loaded

**Solution**:
```java
// Verify wolfJCE is loaded
Provider wolfJCE = Security.getProvider("wolfJCE");
if (wolfJCE == null) {
    System.err.println("wolfJCE not loaded!");
    // Check java.security configuration
}

// Then get WKS
KeyStore ks = KeyStore.getInstance("WKS");
```

#### Issue: Wrong Password

**Error**: `java.io.IOException: Keystore was tampered with, or password was incorrect`

**Cause**: Incorrect password or corrupted keystore

**Solution**:
```java
// Try loading with different passwords
String[] passwords = {"changeitchangeit", "changeit", "password"};
KeyStore ks = KeyStore.getInstance("WKS");

for (String pwd : passwords) {
    try {
        ks.load(new FileInputStream("keystore.wks"), pwd.toCharArray());
        System.out.println("Correct password: " + pwd);
        break;
    } catch (IOException e) {
        System.out.println("Failed with password: " + pwd);
    }
}
```

#### Issue: Cannot Load System Cacerts

**Error**: `java.io.FileNotFoundException: cacerts (No such file or directory)`

**Cause**: Cacerts path incorrect or not converted to WKS

**Solution**:
```bash
# Verify cacerts exists and is WKS format
docker run --rm java:21-jdk-jammy-ubuntu-22.04-fips bash -c \
  "ls -l \$JAVA_HOME/lib/security/cacerts && \
   file \$JAVA_HOME/lib/security/cacerts"

# Load with correct password
docker run --rm java:21-jdk-jammy-ubuntu-22.04-fips \
  java -cp "/opt/wolfssl-fips/bin:/usr/share/java/*" -c "
    import java.security.KeyStore;
    import java.io.*;
    KeyStore ks = KeyStore.getInstance(\"WKS\");
    String path = System.getProperty(\"java.home\") + \"/lib/security/cacerts\";
    try (FileInputStream fis = new FileInputStream(path)) {
      ks.load(fis, \"changeitchangeit\".toCharArray());
      System.out.println(\"Loaded \" + ks.size() + \" certificates\");
    }
  "
```

#### Issue: Certificate Chain Invalid

**Error**: `java.security.cert.CertificateException: Certificate chain is not valid`

**Cause**: Incomplete chain or wrong order

**Solution**:
```java
// Correct order: leaf cert, intermediate(s), root CA
Certificate[] chain = new Certificate[3];
chain[0] = leafCert;      // Your certificate
chain[1] = intermediateCert; // Intermediate CA
chain[2] = rootCert;      // Root CA

// Validate chain
for (int i = 0; i < chain.length - 1; i++) {
    X509Certificate current = (X509Certificate) chain[i];
    X509Certificate issuer = (X509Certificate) chain[i + 1];

    try {
        current.verify(issuer.getPublicKey());
        System.out.println("Chain link " + i + " valid");
    } catch (Exception e) {
        System.err.println("Chain link " + i + " invalid: " + e.getMessage());
    }
}
```

### Debugging Commands

```bash
# List keystore contents
keytool -list -keystore keystore.wks \
  -storepass password \
  -storetype WKS \
  -provider com.wolfssl.provider.jce.WolfCryptProvider \
  -providerpath /usr/share/java/wolfcrypt-jni.jar

# Export certificate
keytool -exportcert -alias myalias \
  -keystore keystore.wks \
  -storepass password \
  -storetype WKS \
  -file exported-cert.pem \
  -rfc

# Import certificate
keytool -importcert -alias newca \
  -file ca-cert.pem \
  -keystore truststore.wks \
  -storepass password \
  -storetype WKS \
  -noprompt
```

---

## Additional Resources

- **[DEVELOPER-GUIDE.md](DEVELOPER-GUIDE.md)** - Comprehensive developer guide
- **[EXAMPLES.md](EXAMPLES.md)** - Code examples with keystores
- **[Java KeyStore Documentation](https://docs.oracle.com/en/java/javase/21/security/java-pki-programmers-guide.html)** - Oracle KeyStore guide
- **[wolfSSL Documentation](https://www.wolfssl.com/documentation/)** - wolfSSL reference

---

**Last Updated**: 2026-03-19
**Version**: 1.0
**wolfSSL FIPS Version**: v5.8.2 (Certificate #4718)
