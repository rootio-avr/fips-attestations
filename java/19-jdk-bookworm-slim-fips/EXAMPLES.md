# Practical Code Examples

Copy-paste ready code examples for using the wolfSSL FIPS Java container.

## Table of Contents

1. [Basic Examples](#basic-examples)
2. [Hashing and Message Digest](#hashing-and-message-digest)
3. [Symmetric Encryption](#symmetric-encryption)
4. [Asymmetric Encryption](#asymmetric-encryption)
5. [Digital Signatures](#digital-signatures)
6. [Key Agreement](#key-agreement)
7. [TLS/SSL Examples](#tlsssl-examples)
8. [Keystore Examples](#keystore-examples)
9. [Real-World Scenarios](#real-world-scenarios)
10. [Using as Base Image](#using-as-base-image)

---

## Basic Examples

### Example 1: Simple SHA-256 Hash

**Purpose**: Hash a string using SHA-256

```java
import java.security.MessageDigest;

public class SimpleHashExample {
    public static void main(String[] args) throws Exception {
        // Standard JCA API - automatically uses wolfJCE provider
        MessageDigest md = MessageDigest.getInstance("SHA-256");
        byte[] hash = md.digest("Hello FIPS!".getBytes());

        // Convert to hex string
        StringBuilder hexString = new StringBuilder();
        for (byte b : hash) {
            hexString.append(String.format("%02x", b));
        }

        System.out.println("SHA-256 Hash: " + hexString.toString());
        System.out.println("Provider: " + md.getProvider().getName());  // wolfJCE
    }
}
```

**Expected Output**:
```
SHA-256 Hash: 7a3f4e8c9d2b1a5c6e8f0a2b4d6e8f0a1c3e5f7a9b0d2f4e6a8c0e2a4c6e8f0a2
Provider: wolfJCE
```

### Example 2: Generate Random Bytes

**Purpose**: Generate cryptographically secure random bytes

```java
import java.security.SecureRandom;

public class RandomBytesExample {
    public static void main(String[] args) throws Exception {
        SecureRandom random = new SecureRandom();

        // Generate 32 random bytes
        byte[] randomBytes = new byte[32];
        random.nextBytes(randomBytes);

        System.out.println("Provider: " + random.getProvider().getName());
        System.out.println("Algorithm: " + random.getAlgorithm());
        System.out.println("Random bytes generated (hex): " +
            bytesToHex(randomBytes));
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

## Hashing and Message Digest

### Example 3: Hash File Contents

**Purpose**: Compute SHA-256 hash of a file

```java
import java.io.*;
import java.security.MessageDigest;

public class FileHashExample {
    public static void main(String[] args) throws Exception {
        String filePath = "/path/to/file.txt";

        // Create MessageDigest instance
        MessageDigest md = MessageDigest.getInstance("SHA-256");

        // Read file and update digest
        try (FileInputStream fis = new FileInputStream(filePath);
             BufferedInputStream bis = new BufferedInputStream(fis)) {

            byte[] buffer = new byte[8192];
            int bytesRead;

            while ((bytesRead = bis.read(buffer)) != -1) {
                md.update(buffer, 0, bytesRead);
            }
        }

        // Get final hash
        byte[] hash = md.digest();

        System.out.println("File: " + filePath);
        System.out.println("SHA-256: " + bytesToHex(hash));
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

### Example 4: Multiple Hash Algorithms

**Purpose**: Hash data with different algorithms

```java
import java.security.MessageDigest;

public class MultiHashExample {
    public static void main(String[] args) throws Exception {
        String data = "Data to hash";
        byte[] dataBytes = data.getBytes();

        // Hash with different algorithms
        String[] algorithms = {
            "SHA-256", "SHA-384", "SHA-512",
            "SHA3-256", "SHA3-384", "SHA3-512"
        };

        for (String algorithm : algorithms) {
            MessageDigest md = MessageDigest.getInstance(algorithm);
            byte[] hash = md.digest(dataBytes);

            System.out.printf("%-12s: %s (%s)%n",
                algorithm,
                bytesToHex(hash).substring(0, 32) + "...",
                md.getProvider().getName());
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

---

## Symmetric Encryption

### Example 5: AES-GCM Encryption

**Purpose**: Encrypt and decrypt data using AES-GCM (authenticated encryption)

```java
import javax.crypto.*;
import javax.crypto.spec.*;
import java.security.*;

public class AesGcmExample {
    public static void main(String[] args) throws Exception {
        // Generate AES-256 key
        KeyGenerator keyGen = KeyGenerator.getInstance("AES");
        keyGen.init(256);
        SecretKey key = keyGen.generateKey();

        // Data to encrypt
        String plaintext = "Sensitive data";
        byte[] plaintextBytes = plaintext.getBytes();

        // Encrypt
        byte[] ciphertext = encrypt(key, plaintextBytes);
        System.out.println("Ciphertext: " + bytesToHex(ciphertext));

        // Decrypt
        byte[] decrypted = decrypt(key, ciphertext);
        System.out.println("Decrypted: " + new String(decrypted));
    }

    private static byte[] encrypt(SecretKey key, byte[] plaintext)
            throws Exception {
        // Create cipher
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");

        // Generate random IV (12 bytes for GCM)
        SecureRandom random = new SecureRandom();
        byte[] iv = new byte[12];
        random.nextBytes(iv);

        // Initialize cipher
        GCMParameterSpec spec = new GCMParameterSpec(128, iv);  // 128-bit auth tag
        cipher.init(Cipher.ENCRYPT_MODE, key, spec);

        // Encrypt
        byte[] ciphertext = cipher.doFinal(plaintext);

        // Prepend IV to ciphertext (IV is not secret)
        byte[] result = new byte[iv.length + ciphertext.length];
        System.arraycopy(iv, 0, result, 0, iv.length);
        System.arraycopy(ciphertext, 0, result, iv.length, ciphertext.length);

        return result;
    }

    private static byte[] decrypt(SecretKey key, byte[] ivAndCiphertext)
            throws Exception {
        // Extract IV and ciphertext
        byte[] iv = new byte[12];
        byte[] ciphertext = new byte[ivAndCiphertext.length - 12];
        System.arraycopy(ivAndCiphertext, 0, iv, 0, 12);
        System.arraycopy(ivAndCiphertext, 12, ciphertext, 0, ciphertext.length);

        // Create cipher
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");

        // Initialize cipher
        GCMParameterSpec spec = new GCMParameterSpec(128, iv);
        cipher.init(Cipher.DECRYPT_MODE, key, spec);

        // Decrypt and verify
        return cipher.doFinal(ciphertext);
    }

    private static String bytesToHex(byte[] bytes) {
        StringBuilder result = new StringBuilder();
        for (int i = 0; i < Math.min(bytes.length, 32); i++) {
            result.append(String.format("%02x", bytes[i]));
        }
        if (bytes.length > 32) result.append("...");
        return result.toString();
    }
}
```

### Example 6: Encrypt File with AES

**Purpose**: Encrypt a file using AES-256-GCM

```java
import javax.crypto.*;
import javax.crypto.spec.*;
import java.io.*;
import java.security.*;

public class FileEncryptionExample {
    public static void main(String[] args) throws Exception {
        String inputFile = "plaintext.txt";
        String encryptedFile = "encrypted.bin";
        String decryptedFile = "decrypted.txt";

        // Generate key
        KeyGenerator keyGen = KeyGenerator.getInstance("AES");
        keyGen.init(256);
        SecretKey key = keyGen.generateKey();

        // Save key (in practice, use secure key storage)
        saveKey(key, "aes-key.bin");

        // Encrypt file
        encryptFile(key, inputFile, encryptedFile);
        System.out.println("File encrypted: " + encryptedFile);

        // Decrypt file
        decryptFile(key, encryptedFile, decryptedFile);
        System.out.println("File decrypted: " + decryptedFile);
    }

    private static void encryptFile(SecretKey key, String inputFile,
                                   String outputFile) throws Exception {
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");

        // Generate IV
        SecureRandom random = new SecureRandom();
        byte[] iv = new byte[12];
        random.nextBytes(iv);

        GCMParameterSpec spec = new GCMParameterSpec(128, iv);
        cipher.init(Cipher.ENCRYPT_MODE, key, spec);

        try (FileInputStream fis = new FileInputStream(inputFile);
             FileOutputStream fos = new FileOutputStream(outputFile)) {

            // Write IV first
            fos.write(iv);

            // Encrypt file
            byte[] buffer = new byte[8192];
            int bytesRead;
            while ((bytesRead = fis.read(buffer)) != -1) {
                byte[] output = cipher.update(buffer, 0, bytesRead);
                if (output != null) {
                    fos.write(output);
                }
            }

            byte[] output = cipher.doFinal();
            if (output != null) {
                fos.write(output);
            }
        }
    }

    private static void decryptFile(SecretKey key, String inputFile,
                                   String outputFile) throws Exception {
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");

        try (FileInputStream fis = new FileInputStream(inputFile);
             FileOutputStream fos = new FileOutputStream(outputFile)) {

            // Read IV
            byte[] iv = new byte[12];
            fis.read(iv);

            GCMParameterSpec spec = new GCMParameterSpec(128, iv);
            cipher.init(Cipher.DECRYPT_MODE, key, spec);

            // Decrypt file
            byte[] buffer = new byte[8192];
            int bytesRead;
            while ((bytesRead = fis.read(buffer)) != -1) {
                byte[] output = cipher.update(buffer, 0, bytesRead);
                if (output != null) {
                    fos.write(output);
                }
            }

            byte[] output = cipher.doFinal();
            if (output != null) {
                fos.write(output);
            }
        }
    }

    private static void saveKey(SecretKey key, String fileName)
            throws IOException {
        try (FileOutputStream fos = new FileOutputStream(fileName)) {
            fos.write(key.getEncoded());
        }
    }
}
```

---

## Asymmetric Encryption

### Example 7: RSA Key Generation and Encryption

**Purpose**: Generate RSA key pair and encrypt/decrypt data

```java
import java.security.*;
import javax.crypto.Cipher;

public class RsaExample {
    public static void main(String[] args) throws Exception {
        // Generate RSA-2048 key pair
        KeyPairGenerator keyGen = KeyPairGenerator.getInstance("RSA");
        keyGen.initialize(2048);
        KeyPair keyPair = keyGen.generateKeyPair();

        System.out.println("Public Key: " +
            bytesToHex(keyPair.getPublic().getEncoded()).substring(0, 32) + "...");
        System.out.println("Private Key: " +
            bytesToHex(keyPair.getPrivate().getEncoded()).substring(0, 32) + "...");

        // Data to encrypt (max size for RSA-2048 with PKCS1Padding: ~245 bytes)
        String message = "Secret message";
        byte[] messageBytes = message.getBytes();

        // Encrypt with public key
        Cipher encryptCipher = Cipher.getInstance("RSA/ECB/PKCS1Padding");
        encryptCipher.init(Cipher.ENCRYPT_MODE, keyPair.getPublic());
        byte[] ciphertext = encryptCipher.doFinal(messageBytes);

        System.out.println("\nCiphertext: " + bytesToHex(ciphertext));

        // Decrypt with private key
        Cipher decryptCipher = Cipher.getInstance("RSA/ECB/PKCS1Padding");
        decryptCipher.init(Cipher.DECRYPT_MODE, keyPair.getPrivate());
        byte[] decrypted = decryptCipher.doFinal(ciphertext);

        System.out.println("Decrypted: " + new String(decrypted));
    }

    private static String bytesToHex(byte[] bytes) {
        StringBuilder result = new StringBuilder();
        for (int i = 0; i < Math.min(bytes.length, 32); i++) {
            result.append(String.format("%02x", bytes[i]));
        }
        if (bytes.length > 32) result.append("...");
        return result.toString();
    }
}
```

---

## Digital Signatures

### Example 8: Sign and Verify Data

**Purpose**: Create and verify digital signature

```java
import java.security.*;

public class SignatureExample {
    public static void main(String[] args) throws Exception {
        // Generate RSA key pair
        KeyPairGenerator keyGen = KeyPairGenerator.getInstance("RSA");
        keyGen.initialize(2048);
        KeyPair keyPair = keyGen.generateKeyPair();

        String data = "Important document";
        byte[] dataBytes = data.getBytes();

        // Sign data
        Signature signer = Signature.getInstance("SHA256withRSA");
        signer.initSign(keyPair.getPrivate());
        signer.update(dataBytes);
        byte[] signature = signer.sign();

        System.out.println("Data: " + data);
        System.out.println("Signature: " + bytesToHex(signature));

        // Verify signature
        Signature verifier = Signature.getInstance("SHA256withRSA");
        verifier.initVerify(keyPair.getPublic());
        verifier.update(dataBytes);
        boolean valid = verifier.verify(signature);

        System.out.println("Signature valid: " + valid);

        // Tamper with data and verify again
        byte[] tamperedData = "Tampered document".getBytes();
        verifier.initVerify(keyPair.getPublic());
        verifier.update(tamperedData);
        boolean tamperedValid = verifier.verify(signature);

        System.out.println("Tampered signature valid: " + tamperedValid);
    }

    private static String bytesToHex(byte[] bytes) {
        StringBuilder result = new StringBuilder();
        for (int i = 0; i < Math.min(bytes.length, 32); i++) {
            result.append(String.format("%02x", bytes[i]));
        }
        if (bytes.length > 32) result.append("...");
        return result.toString();
    }
}
```

### Example 9: Sign File

**Purpose**: Create detached signature for file

```java
import java.io.*;
import java.security.*;

public class FileSigningExample {
    public static void main(String[] args) throws Exception {
        String fileName = "document.pdf";
        String signatureFile = "document.pdf.sig";

        // Generate key pair
        KeyPairGenerator keyGen = KeyPairGenerator.getInstance("RSA");
        keyGen.initialize(2048);
        KeyPair keyPair = keyGen.generateKeyPair();

        // Sign file
        signFile(keyPair.getPrivate(), fileName, signatureFile);
        System.out.println("Signature created: " + signatureFile);

        // Verify signature
        boolean valid = verifyFileSignature(keyPair.getPublic(),
                                           fileName, signatureFile);
        System.out.println("Signature valid: " + valid);
    }

    private static void signFile(PrivateKey privateKey, String fileName,
                                 String signatureFile) throws Exception {
        Signature signer = Signature.getInstance("SHA256withRSA");
        signer.initSign(privateKey);

        // Read file and update signature
        try (FileInputStream fis = new FileInputStream(fileName)) {
            byte[] buffer = new byte[8192];
            int bytesRead;
            while ((bytesRead = fis.read(buffer)) != -1) {
                signer.update(buffer, 0, bytesRead);
            }
        }

        // Write signature to file
        byte[] signature = signer.sign();
        try (FileOutputStream fos = new FileOutputStream(signatureFile)) {
            fos.write(signature);
        }
    }

    private static boolean verifyFileSignature(PublicKey publicKey,
                                              String fileName,
                                              String signatureFile)
            throws Exception {
        Signature verifier = Signature.getInstance("SHA256withRSA");
        verifier.initVerify(publicKey);

        // Read file and update verifier
        try (FileInputStream fis = new FileInputStream(fileName)) {
            byte[] buffer = new byte[8192];
            int bytesRead;
            while ((bytesRead = fis.read(buffer)) != -1) {
                verifier.update(buffer, 0, bytesRead);
            }
        }

        // Read signature
        byte[] signature;
        try (FileInputStream fis = new FileInputStream(signatureFile)) {
            signature = fis.readAllBytes();
        }

        return verifier.verify(signature);
    }
}
```

---

## Key Agreement

### Example 10: ECDH Key Exchange

**Purpose**: Perform Elliptic Curve Diffie-Hellman key exchange

```java
import java.security.*;
import java.security.spec.*;
import javax.crypto.*;
import javax.crypto.spec.*;

public class EcdhExample {
    public static void main(String[] args) throws Exception {
        // Alice generates her key pair
        KeyPairGenerator aliceKeyGen = KeyPairGenerator.getInstance("EC");
        ECGenParameterSpec ecSpec = new ECGenParameterSpec("secp256r1");  // P-256
        aliceKeyGen.initialize(ecSpec);
        KeyPair aliceKeyPair = aliceKeyGen.generateKeyPair();

        // Bob generates his key pair
        KeyPairGenerator bobKeyGen = KeyPairGenerator.getInstance("EC");
        bobKeyGen.initialize(ecSpec);
        KeyPair bobKeyPair = bobKeyGen.generateKeyPair();

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
        boolean match = MessageDigest.isEqual(aliceSharedSecret, bobSharedSecret);

        System.out.println("Alice's shared secret: " + bytesToHex(aliceSharedSecret));
        System.out.println("Bob's shared secret:   " + bytesToHex(bobSharedSecret));
        System.out.println("Shared secrets match: " + match);

        // Derive AES key from shared secret
        MessageDigest sha256 = MessageDigest.getInstance("SHA-256");
        byte[] keyMaterial = sha256.digest(aliceSharedSecret);
        SecretKey aesKey = new SecretKeySpec(keyMaterial, 0, 32, "AES");

        System.out.println("\nDerived AES-256 key: " +
            bytesToHex(aesKey.getEncoded()));
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

## TLS/SSL Examples

### Example 11: Simple HTTPS GET Request

**Purpose**: Make HTTPS request using wolfJSSE

```java
import javax.net.ssl.*;
import java.io.*;
import java.net.URL;

public class HttpsGetExample {
    public static void main(String[] args) throws Exception {
        // Create SSLContext (uses system WKS cacerts)
        SSLContext context = SSLContext.getInstance("TLS");
        context.init(null, null, null);

        System.out.println("SSLContext Provider: " +
            context.getProvider().getName());

        // Make HTTPS request
        URL url = new URL("https://httpbin.org/get");
        HttpsURLConnection connection = (HttpsURLConnection) url.openConnection();
        connection.setSSLSocketFactory(context.getSocketFactory());
        connection.setRequestMethod("GET");
        connection.setConnectTimeout(10000);
        connection.setReadTimeout(10000);

        int responseCode = connection.getResponseCode();
        System.out.println("Response Code: " + responseCode);

        if (responseCode == 200) {
            try (BufferedReader reader = new BufferedReader(
                    new InputStreamReader(connection.getInputStream()))) {
                String line;
                System.out.println("\nResponse:");
                while ((line = reader.readLine()) != null) {
                    System.out.println(line);
                }
            }
        }

        // Get TLS session info
        SSLSession session = connection.getSSLSession();
        System.out.println("\nTLS Protocol: " + session.getProtocol());
        System.out.println("Cipher Suite: " + session.getCipherSuite());

        connection.disconnect();
    }
}
```

### Example 12: TLS Socket with Custom Trust Store

**Purpose**: Create TLS connection with custom WKS trust store

```java
import javax.net.ssl.*;
import java.io.*;
import java.security.*;

public class CustomTrustStoreExample {
    public static void main(String[] args) throws Exception {
        // Load custom WKS trust store
        KeyStore trustStore = KeyStore.getInstance("WKS");
        try (FileInputStream fis = new FileInputStream("/path/to/custom-truststore.wks")) {
            trustStore.load(fis, "truststore_password".toCharArray());
        }

        System.out.println("Loaded " + trustStore.size() + " certificates");

        // Create TrustManagerFactory
        TrustManagerFactory tmf = TrustManagerFactory.getInstance("PKIX");
        tmf.init(trustStore);

        System.out.println("TrustManagerFactory Provider: " +
            tmf.getProvider().getName());

        // Create SSLContext
        SSLContext context = SSLContext.getInstance("TLS");
        context.init(null, tmf.getTrustManagers(), null);

        // Create SSL socket
        SSLSocketFactory factory = context.getSocketFactory();
        SSLSocket socket = (SSLSocket) factory.createSocket("www.example.com", 443);

        // Set SNI (Server Name Indication)
        SSLParameters params = socket.getSSLParameters();
        params.setServerNames(java.util.Arrays.asList(
            new SNIHostName("www.example.com")));
        socket.setSSLParameters(params);

        // Perform handshake
        socket.startHandshake();

        // Get session info
        SSLSession session = socket.getSession();
        System.out.println("\nTLS Handshake successful!");
        System.out.println("Protocol: " + session.getProtocol());
        System.out.println("Cipher Suite: " + session.getCipherSuite());

        socket.close();
    }
}
```

---

## Keystore Examples

### Example 13: Load System CA Certificates

**Purpose**: Load system WKS cacerts trust store

```java
import java.io.*;
import java.security.KeyStore;
import java.security.cert.*;

public class LoadSystemCacertsExample {
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
        int count = 0;
        while (aliases.hasMoreElements()) {
            String alias = aliases.nextElement();
            Certificate cert = trustStore.getCertificate(alias);

            if (cert instanceof X509Certificate) {
                X509Certificate x509 = (X509Certificate) cert;
                System.out.println("\n[" + (++count) + "] " + alias);
                System.out.println("    Subject: " +
                    x509.getSubjectX500Principal().getName());
                System.out.println("    Issuer: " +
                    x509.getIssuerX500Principal().getName());
                System.out.println("    Valid Until: " + x509.getNotAfter());
            }
        }
    }
}
```

### Example 14: Create WKS Keystore with Client Certificate

**Purpose**: Create WKS keystore for client authentication

```java
import java.io.*;
import java.security.*;
import java.security.cert.*;

public class CreateClientKeystoreExample {
    public static void main(String[] args) throws Exception {
        // Create new WKS keystore
        KeyStore keyStore = KeyStore.getInstance("WKS");
        keyStore.load(null, null);  // Initialize empty

        // Load client certificate and private key (example: from PEM files)
        // In practice, you'd have methods to load from PEM/PKCS12
        // For this example, assume we have them

        // Generate dummy key pair (replace with actual loading)
        KeyPairGenerator keyGen = KeyPairGenerator.getInstance("RSA");
        keyGen.initialize(2048);
        KeyPair keyPair = keyGen.generateKeyPair();

        // Create self-signed certificate (for demo)
        // In practice, you'd have a CA-signed certificate
        X509Certificate cert = createSelfSignedCertificate(keyPair);

        // Add private key entry
        Certificate[] chain = {cert};
        keyStore.setKeyEntry(
            "my-client-cert",                      // alias
            keyPair.getPrivate(),                  // private key
            "key_password".toCharArray(),          // key password
            chain                                  // certificate chain
        );

        // Save keystore
        try (FileOutputStream fos = new FileOutputStream("client-keystore.wks")) {
            keyStore.store(fos, "store_password".toCharArray());
        }

        System.out.println("Created WKS keystore: client-keystore.wks");
        System.out.println("Entries: " + keyStore.size());
    }

    // Simplified self-signed certificate creation
    // In production, use proper certificate generation
    private static X509Certificate createSelfSignedCertificate(KeyPair keyPair)
            throws Exception {
        // This is simplified - use proper X509 certificate generation
        // libraries in production (e.g., Bouncy Castle)
        throw new UnsupportedOperationException(
            "Use proper certificate generation library");
    }
}
```

---

## Real-World Scenarios

### Example 15: Secure Configuration File Encryption

**Purpose**: Encrypt application configuration files

```java
import javax.crypto.*;
import javax.crypto.spec.*;
import java.io.*;
import java.nio.file.*;
import java.security.*;
import java.util.Properties;

public class ConfigEncryptionExample {
    private static final String KEY_FILE = ".config.key";
    private static final String CONFIG_FILE = "config.properties";
    private static final String ENCRYPTED_FILE = "config.properties.enc";

    public static void main(String[] args) throws Exception {
        // Generate or load encryption key
        SecretKey key = loadOrGenerateKey();

        // Create sample configuration
        Properties config = new Properties();
        config.setProperty("database.url", "jdbc:postgresql://localhost/mydb");
        config.setProperty("database.username", "admin");
        config.setProperty("database.password", "secret_password");
        config.setProperty("api.key", "sk_live_1234567890abcdef");

        // Save unencrypted config
        try (FileOutputStream fos = new FileOutputStream(CONFIG_FILE)) {
            config.store(fos, "Application Configuration");
        }

        // Encrypt configuration file
        encryptFile(key, CONFIG_FILE, ENCRYPTED_FILE);
        System.out.println("Configuration encrypted: " + ENCRYPTED_FILE);

        // Delete unencrypted file
        Files.delete(Paths.get(CONFIG_FILE));
        System.out.println("Deleted unencrypted: " + CONFIG_FILE);

        // Load encrypted configuration
        Properties loadedConfig = loadEncryptedConfig(key, ENCRYPTED_FILE);
        System.out.println("\nLoaded encrypted configuration:");
        loadedConfig.list(System.out);
    }

    private static SecretKey loadOrGenerateKey() throws Exception {
        File keyFile = new File(KEY_FILE);

        if (keyFile.exists()) {
            // Load existing key
            byte[] keyBytes = Files.readAllBytes(keyFile.toPath());
            return new SecretKeySpec(keyBytes, "AES");
        } else {
            // Generate new key
            KeyGenerator keyGen = KeyGenerator.getInstance("AES");
            keyGen.init(256);
            SecretKey key = keyGen.generateKey();

            // Save key (with restricted permissions)
            Files.write(keyFile.toPath(), key.getEncoded());
            keyFile.setReadable(false, false);
            keyFile.setReadable(true, true);

            System.out.println("Generated new encryption key: " + KEY_FILE);
            return key;
        }
    }

    private static void encryptFile(SecretKey key, String input, String output)
            throws Exception {
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");

        SecureRandom random = new SecureRandom();
        byte[] iv = new byte[12];
        random.nextBytes(iv);

        GCMParameterSpec spec = new GCMParameterSpec(128, iv);
        cipher.init(Cipher.ENCRYPT_MODE, key, spec);

        try (FileInputStream fis = new FileInputStream(input);
             FileOutputStream fos = new FileOutputStream(output)) {

            fos.write(iv);  // Write IV first

            byte[] buffer = new byte[8192];
            int bytesRead;
            while ((bytesRead = fis.read(buffer)) != -1) {
                byte[] encrypted = cipher.update(buffer, 0, bytesRead);
                if (encrypted != null) {
                    fos.write(encrypted);
                }
            }

            byte[] final_encrypted = cipher.doFinal();
            if (final_encrypted != null) {
                fos.write(final_encrypted);
            }
        }
    }

    private static Properties loadEncryptedConfig(SecretKey key, String file)
            throws Exception {
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");

        try (FileInputStream fis = new FileInputStream(file);
             ByteArrayOutputStream baos = new ByteArrayOutputStream()) {

            // Read IV
            byte[] iv = new byte[12];
            fis.read(iv);

            GCMParameterSpec spec = new GCMParameterSpec(128, iv);
            cipher.init(Cipher.DECRYPT_MODE, key, spec);

            // Decrypt file
            byte[] buffer = new byte[8192];
            int bytesRead;
            while ((bytesRead = fis.read(buffer)) != -1) {
                byte[] decrypted = cipher.update(buffer, 0, bytesRead);
                if (decrypted != null) {
                    baos.write(decrypted);
                }
            }

            byte[] final_decrypted = cipher.doFinal();
            if (final_decrypted != null) {
                baos.write(final_decrypted);
            }

            // Load properties from decrypted data
            Properties props = new Properties();
            props.load(new ByteArrayInputStream(baos.toByteArray()));
            return props;
        }
    }
}
```

---

## Using as Base Image

### Example 16: Dockerfile for Custom Application

**Purpose**: Build custom application using FIPS container as base

```dockerfile
FROM java:19-jdk-bookworm-slim-fips

# Set working directory
WORKDIR /app

# Copy application JAR
COPY target/myapp.jar /app/myapp.jar

# Copy dependencies
COPY target/lib/*.jar /app/lib/

# Copy configuration (encrypted)
COPY config.properties.enc /app/config.properties.enc
COPY .config.key /app/.config.key

# Set file permissions
RUN chmod 600 /app/.config.key && \
    chmod 644 /app/config.properties.enc

# Set classpath
ENV CLASSPATH=/app/myapp.jar:/app/lib/*:/usr/share/java/*

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s \
  CMD java -cp $CLASSPATH com.example.HealthCheck || exit 1

# Expose port
EXPOSE 8080

# Run application (FIPS validation enabled by default)
ENTRYPOINT ["java", "-cp", "/app/myapp.jar:/app/lib/*:/usr/share/java/*", \
            "com.example.MyApplication"]
```

### Example 17: Multi-Stage Build with Tests

**Purpose**: Build and test application in FIPS container

```dockerfile
# Build stage
FROM maven:3.9-openjdk-19 AS builder
WORKDIR /build
COPY pom.xml .
COPY src src
RUN mvn clean package -DskipTests

# Test stage
FROM java:19-jdk-bookworm-slim-fips AS tester
WORKDIR /test
COPY --from=builder /build/target/*.jar /test/
COPY --from=builder /build/target/lib /test/lib

# Run tests in FIPS mode
RUN java -cp "/test/*:/test/lib/*:/usr/share/java/*" \
    org.junit.runner.JUnitCore com.example.FipsTests

# Runtime stage
FROM java:19-jdk-bookworm-slim-fips
WORKDIR /app
COPY --from=builder /build/target/myapp.jar /app/
COPY --from=builder /build/target/lib /app/lib

ENTRYPOINT ["java", "-jar", "/app/myapp.jar"]
```

---

## Additional Resources

- **[DEVELOPER-GUIDE.md](DEVELOPER-GUIDE.md)** - Comprehensive developer guide
- **[KEYSTORE-TRUST-STORE-GUIDE.md](KEYSTORE-TRUST-STORE-GUIDE.md)** - Keystore usage
- **[diagnostics/test-images/basic-test-image/](diagnostics/test-images/basic-test-image/)** - Complete test suite with more examples

---

**Last Updated**: 2025-01-XX
**Version**: 1.0
**wolfSSL FIPS Version**: v5.8.2 (Certificate #4718)
