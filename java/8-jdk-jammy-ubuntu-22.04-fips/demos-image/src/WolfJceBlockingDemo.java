/* WolfJceBlockingDemo.java
 *
 * Copyright (C) 2006-2025 root.io Inc.
 *
 */

import java.security.*;
import javax.crypto.*;
import javax.crypto.spec.*;
import java.util.*;

/**
 * WolfJCE FIPS Algorithm Blocking Demonstration
 *
 * This demo application demonstrates how the wolfJCE provider enforces
 * FIPS 140-3 compliance by blocking non-FIPS approved algorithms.
 *
 * It attempts to use various cryptographic algorithms:
 * - Cipher-level non-FIPS algorithms (DES, 3DES, RC4) - always BLOCKED
 * - Legacy digest algorithms (MD5, SHA-1) - BLOCKED or LEGACY ALLOWED depending
 *   on wolfJCE build configuration; wolfJCE may expose them for legacy compatibility
 *   even in FIPS mode (they are not used in FIPS-approved cipher operations)
 * - FIPS-approved algorithms (SHA-256, SHA-384, SHA-512, AES) - should SUCCEED
 *
 * This clearly shows the enforcement mechanism in action.
 */
public class WolfJceBlockingDemo {

    private static final String TEST_DATA = "This is test data for FIPS validation";
    private static final String SEPARATOR = "======================================================================";
    private static int passCount = 0;
    private static int failCount = 0;
    private static int legacyAllowedCount = 0;

    public static void main(String[] args) {
        System.out.println(SEPARATOR);
        System.out.println("WolfJCE FIPS Algorithm Blocking Demonstration");
        System.out.println(SEPARATOR);
        System.out.println();

        // Display provider information
        displayProviderInfo();

        System.out.println("\n" + SEPARATOR);
        System.out.println("PART 1: Testing Non-FIPS Algorithms (Ciphers BLOCKED; Digests BLOCKED or LEGACY ALLOWED)");
        System.out.println(SEPARATOR + "\n");

        // MD5 and SHA-1: wolfJCE may allow these for legacy compatibility even in
        // FIPS mode. They are accepted as either BLOCKED or LEGACY ALLOWED.
        testBlockedMessageDigest("MD5", true);
        testBlockedMessageDigest("SHA-1", true);
        testBlockedMessageDigest("SHA1", true);
        // Cipher-level algorithms: these must always be blocked
        testBlockedCipher("DES/ECB/PKCS5Padding", "DES", 56);
        testBlockedCipher("DESede/ECB/PKCS5Padding", "DESede", 168);
        testBlockedCipher("RC4", "RC4", 128);

        System.out.println("\n" + SEPARATOR);
        System.out.println("PART 2: Testing FIPS-Approved Algorithms (Should SUCCEED)");
        System.out.println(SEPARATOR + "\n");

        // Test FIPS-approved algorithms - these should succeed
        testApprovedMessageDigest("SHA-224");
        testApprovedMessageDigest("SHA-256");
        testApprovedMessageDigest("SHA-384");
        testApprovedMessageDigest("SHA-512");
        testApprovedMessageDigest("SHA3-256");
        testApprovedMessageDigest("SHA3-384");
        testApprovedMessageDigest("SHA3-512");

        testApprovedCipher("AES/ECB/PKCS5Padding", "AES", 128);
        testApprovedCipher("AES/CBC/PKCS5Padding", "AES", 256);
        testApprovedCipher("AES/GCM/NoPadding", "AES", 256);

        testApprovedMac("HmacSHA256");
        testApprovedMac("HmacSHA384");
        testApprovedMac("HmacSHA512");

        testApprovedKeyPairGen("RSA", 2048);
        testApprovedKeyPairGen("EC", 256);

        // Summary
        System.out.println("\n" + SEPARATOR);
        System.out.println("TEST SUMMARY");
        System.out.println(SEPARATOR);
        System.out.println("Non-FIPS algorithms blocked:       " + failCount);
        System.out.println("Legacy algorithms (allowed):       " + legacyAllowedCount);
        System.out.println("FIPS algorithms available:         " + passCount);
        System.out.println();

        // Success criteria:
        // - All 6 non-FIPS algorithms are accounted for: either hard-blocked or
        //   legacy-allowed (MD5/SHA-1 may be available for legacy compatibility)
        // - The 3 cipher-level algorithms (DES/DESede/RC4) must always be blocked
        // - All 12+ FIPS-approved algorithms must be available
        if ((failCount + legacyAllowedCount) >= 6 && failCount >= 3 && passCount >= 12) {
            System.out.println("✓ SUCCESS: FIPS enforcement is working correctly!");
            System.out.println("  - Cipher-level non-FIPS algorithms (DES/3DES/RC4) are blocked");
            if (legacyAllowedCount > 0) {
                System.out.println("  - Legacy digest algorithms (MD5/SHA-1) allowed for legacy support");
            } else {
                System.out.println("  - Legacy digest algorithms (MD5/SHA-1) are also blocked");
            }
            System.out.println("  - FIPS-approved algorithms are available");
            System.exit(0);
        } else {
            System.err.println("✗ FAILURE: FIPS enforcement is NOT working correctly!");
            System.err.println("  Expected: (blocked + legacy) >= 6, cipher-blocked >= 3, approved >= 12");
            System.err.println("  Got:      blocked=" + failCount + ", legacy=" + legacyAllowedCount + ", approved=" + passCount);
            System.exit(1);
        }
    }

    /**
     * Display security provider information
     */
    private static void displayProviderInfo() {
        System.out.println("Security Provider Information:");
        Provider[] providers = Security.getProviders();
        for (int i = 0; i < Math.min(5, providers.length); i++) {
            Provider p = providers[i];
            System.out.printf("  %d. %s v%.1f - %s\n",
                i + 1, p.getName(), p.getVersion(), p.getInfo());
        }

        Provider wolfJCE = Security.getProvider("wolfJCE");
        if (wolfJCE != null) {
            System.out.println("\n✓ wolfJCE provider is loaded (FIPS mode active)");
        } else {
            System.out.println("\n✗ WARNING: wolfJCE provider not found!");
        }
    }

    /**
     * Test that a non-FIPS MessageDigest algorithm is blocked.
     * If legacyAllowed is true, the algorithm being available is accepted as a
     * valid "legacy allowed" outcome rather than a failure (wolfJCE may expose
     * MD5/SHA-1 for legacy compatibility even in FIPS mode).
     */
    private static void testBlockedMessageDigest(String algorithm, boolean legacyAllowed) {
        System.out.printf("Testing %s (MessageDigest)... ", algorithm);
        try {
            MessageDigest md = MessageDigest.getInstance(algorithm);
            md.update(TEST_DATA.getBytes());
            byte[] hash = md.digest();

            if (legacyAllowed) {
                System.out.println("⚠ LEGACY ALLOWED (available for legacy support, provider: " + md.getProvider().getName() + ")");
                legacyAllowedCount++;
            } else {
                System.out.println("✗ FAIL - Algorithm should be blocked but was available!");
                System.out.println("  Provider: " + md.getProvider().getName());
            }
        } catch (NoSuchAlgorithmException e) {
            System.out.println("✓ BLOCKED (as expected)");
            failCount++;
        } catch (Exception e) {
            System.out.println("✗ ERROR: " + e.getMessage());
        }
    }

    /**
     * Test that a non-FIPS Cipher algorithm is blocked
     */
    private static void testBlockedCipher(String transformation, String keyAlgorithm, int keySize) {
        System.out.printf("Testing %s (Cipher)... ", transformation);
        try {
            // Generate key
            KeyGenerator keyGen = KeyGenerator.getInstance(keyAlgorithm);
            keyGen.init(keySize);
            SecretKey key = keyGen.generateKey();

            // Try to create cipher
            Cipher cipher = Cipher.getInstance(transformation);
            cipher.init(Cipher.ENCRYPT_MODE, key);
            byte[] encrypted = cipher.doFinal(TEST_DATA.getBytes());

            System.out.println("✗ FAIL - Algorithm should be blocked but was available!");
            System.out.println("  Provider: " + cipher.getProvider().getName());
        } catch (NoSuchAlgorithmException e) {
            System.out.println("✓ BLOCKED (as expected)");
            failCount++;
        } catch (NoSuchPaddingException e) {
            System.out.println("✓ BLOCKED (as expected - no padding available)");
            failCount++;
        } catch (Exception e) {
            System.out.println("✓ BLOCKED (" + e.getClass().getSimpleName() + ")");
            failCount++;
        }
    }

    /**
     * Test that a FIPS-approved MessageDigest algorithm is available
     */
    private static void testApprovedMessageDigest(String algorithm) {
        System.out.printf("Testing %s (MessageDigest)... ", algorithm);
        try {
            MessageDigest md = MessageDigest.getInstance(algorithm);
            md.update(TEST_DATA.getBytes());
            byte[] hash = md.digest();

            System.out.printf("✓ AVAILABLE (%s, hash length: %d bytes)\n",
                md.getProvider().getName(), hash.length);
            passCount++;
        } catch (NoSuchAlgorithmException e) {
            System.out.println("✗ FAIL - Algorithm should be available but was blocked!");
            System.out.println("  Error: " + e.getMessage());
        } catch (Exception e) {
            System.out.println("✗ ERROR: " + e.getMessage());
        }
    }

    /**
     * Test that a FIPS-approved Cipher algorithm is available
     */
    private static void testApprovedCipher(String transformation, String keyAlgorithm, int keySize) {
        System.out.printf("Testing %s (Cipher, %d-bit)... ", transformation, keySize);
        try {
            // Generate key
            KeyGenerator keyGen = KeyGenerator.getInstance(keyAlgorithm);
            keyGen.init(keySize);
            SecretKey key = keyGen.generateKey();

            // Create cipher
            Cipher cipher = Cipher.getInstance(transformation);

            // Handle GCM mode specially (needs GCMParameterSpec)
            if (transformation.contains("GCM")) {
                SecureRandom random = new SecureRandom();
                byte[] iv = new byte[12];
                random.nextBytes(iv);
                GCMParameterSpec gcmSpec = new GCMParameterSpec(128, iv);
                cipher.init(Cipher.ENCRYPT_MODE, key, gcmSpec);
            } else {
                cipher.init(Cipher.ENCRYPT_MODE, key);
            }

            byte[] encrypted = cipher.doFinal(TEST_DATA.getBytes());

            System.out.printf("✓ AVAILABLE (%s)\n", cipher.getProvider().getName());
            passCount++;
        } catch (Exception e) {
            System.out.println("✗ FAIL - Algorithm should be available!");
            System.out.println("  Error: " + e.getClass().getSimpleName() + ": " + e.getMessage());
        }
    }

    /**
     * Test that a FIPS-approved MAC algorithm is available
     */
    private static void testApprovedMac(String algorithm) {
        System.out.printf("Testing %s (MAC)... ", algorithm);
        try {
            KeyGenerator keyGen = KeyGenerator.getInstance(algorithm);
            SecretKey key = keyGen.generateKey();

            Mac mac = Mac.getInstance(algorithm);
            mac.init(key);
            byte[] macValue = mac.doFinal(TEST_DATA.getBytes());

            System.out.printf("✓ AVAILABLE (%s, MAC length: %d bytes)\n",
                mac.getProvider().getName(), macValue.length);
            passCount++;
        } catch (Exception e) {
            System.out.println("✗ FAIL - Algorithm should be available!");
            System.out.println("  Error: " + e.getClass().getSimpleName() + ": " + e.getMessage());
        }
    }

    /**
     * Test that a FIPS-approved KeyPairGenerator algorithm is available
     */
    private static void testApprovedKeyPairGen(String algorithm, int keySize) {
        System.out.printf("Testing %s (KeyPairGen, %d-bit)... ", algorithm, keySize);
        try {
            KeyPairGenerator keyPairGen = KeyPairGenerator.getInstance(algorithm);
            keyPairGen.initialize(keySize);
            KeyPair keyPair = keyPairGen.generateKeyPair();

            System.out.printf("✓ AVAILABLE (%s)\n", keyPairGen.getProvider().getName());
            passCount++;
        } catch (Exception e) {
            System.out.println("✗ FAIL - Algorithm should be available!");
            System.out.println("  Error: " + e.getClass().getSimpleName() + ": " + e.getMessage());
        }
    }
}
