import java.security.*;
import java.util.*;

/**
 * FIPS Reference Application - Java Crypto Demo
 *
 * Purpose: Minimal Java application that demonstrates FIPS cryptographic operations
 *
 * This program:
 *   - Removes MD5 and SHA-1 from all security providers (FIPS enforcement)
 *   - Lists available security providers
 *   - Tests non-FIPS algorithms (MD5, SHA1) - should be blocked
 *   - Tests FIPS-approved algorithms (SHA-256, SHA-384, SHA-512)
 *   - Returns exit code 0 on success, 1 on failure
 *
 * FIPS Enforcement:
 *   - MD5 and SHA-1 are removed from security providers at startup
 *   - Attempts to use blocked algorithms will throw NoSuchAlgorithmException
 *   - wolfSSL FIPS v5.8.2 provides FIPS 140-3 validated crypto operations
 */
public class FipsDemoApp {

    private static int passedTests = 0;
    private static int failedTests = 0;
    private static int warnTests = 0;

    private static final String TEST_DATA = "FIPS Reference Application - Test Data";

    // Static block to enforce FIPS by installing FipsSecurityProvider
    static {
        try {
            FipsSecurityProvider.enforceFipsMode();
        } catch (Exception e) {
            System.err.println("[FIPS Initialization] ERROR: Failed to configure FIPS mode");
            System.err.println("  " + e.getMessage());
            e.printStackTrace();
            System.exit(1);
        }
    }

    public static void main(String[] args) {
        System.out.println("================================================================================");
        System.out.println("FIPS Reference Application - Java Crypto Demo");
        System.out.println("================================================================================");
        System.out.println();
        System.out.println("Purpose: Demonstrate FIPS-compliant cryptographic operations in Java");
        System.out.println();

        // Display Java environment
        System.out.println("[Environment Information]");
        System.out.println("--------------------------------------------------------------------------------");
        System.out.println("Java Version: " + System.getProperty("java.version"));
        System.out.println("Java Vendor: " + System.getProperty("java.vendor"));
        System.out.println("Java Home: " + System.getProperty("java.home"));
        System.out.println();

        // List security providers
        System.out.println("Security Providers:");
        Provider[] providers = Security.getProviders();
        for (int i = 0; i < providers.length; i++) {
            System.out.println("  " + (i+1) + ". " + providers[i].getName() + " " + providers[i].getVersion());
        }
        System.out.println();
        System.out.println("================================================================================");
        System.out.println();

        // Test Suite 1: Non-FIPS Algorithms
        System.out.println("[Test Suite 1] Non-FIPS Algorithms");
        System.out.println("--------------------------------------------------------------------------------");
        System.out.println("Testing deprecated/non-FIPS algorithms:");
        System.out.println();
        testMD5();
        testSHA1();
        System.out.println();

        // Test Suite 2: FIPS-Approved Algorithms
        System.out.println("[Test Suite 2] FIPS-Approved Algorithms");
        System.out.println("--------------------------------------------------------------------------------");
        System.out.println("Testing FIPS-approved algorithms:");
        System.out.println();
        testSHA256();
        testSHA384();
        testSHA512();
        System.out.println();

        // Results
        System.out.println("================================================================================");
        System.out.println("Test Results");
        System.out.println("================================================================================");
        System.out.println("Total Tests: " + (passedTests + failedTests));
        System.out.println("Passed: " + passedTests);
        System.out.println("Failed: " + failedTests);
        System.out.println();

        if (failedTests > 0) {
            System.out.println("Status: FAILED");
            System.out.println();
            System.out.println("Some critical tests failed. Review output above.");
            System.exit(1);
        } else {
            System.out.println("Status: PASSED");
            System.out.println();
            System.out.println("All FIPS tests passed successfully!");
            System.out.println("Non-FIPS algorithms (MD5, SHA-1) properly blocked (FIPS mode active).");
            System.out.println("FIPS-approved algorithms (SHA-256, SHA-384, SHA-512) work correctly.");
            System.exit(0);
        }
    }

    private static void testMD5() {
        System.out.print("  [1/2] MD5 (deprecated) ... ");
        try {
            MessageDigest md = MessageDigest.getInstance("MD5");
            md.update(TEST_DATA.getBytes());
            byte[] hash = md.digest();

            // If we get here, MD5 was not blocked - this is a FAILURE
            System.out.println("FAIL (MD5 should be blocked in FIPS mode)");
            System.out.println("        Error: Algorithm was available but should be blocked by FIPS");
            failedTests++;
        } catch (NoSuchAlgorithmException e) {
            System.out.println("BLOCKED (good - FIPS mode active)");
            passedTests++;
        } catch (Exception e) {
            System.out.println("ERROR: " + e.getMessage());
            failedTests++;
        }
    }

    private static void testSHA1() {
        System.out.print("  [2/2] SHA1 (deprecated) ... ");
        try {
            MessageDigest md = MessageDigest.getInstance("SHA1");
            md.update(TEST_DATA.getBytes());
            byte[] hash = md.digest();

            // If we get here, SHA-1 was not blocked - this is a FAILURE
            System.out.println("FAIL (SHA-1 should be blocked in FIPS mode)");
            System.out.println("        Error: Algorithm was available but should be blocked by FIPS");
            failedTests++;
        } catch (NoSuchAlgorithmException e) {
            System.out.println("BLOCKED (good - FIPS mode active)");
            passedTests++;
        } catch (Exception e) {
            System.out.println("ERROR: " + e.getMessage());
            failedTests++;
        }
    }

    private static void testSHA256() {
        System.out.print("  [1/3] SHA-256 (FIPS-approved) ... ");
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            md.update(TEST_DATA.getBytes());
            byte[] hash = md.digest();

            if (hash.length == 32) {
                System.out.printf("PASS (hash: %02x%02x%02x%02x...)%n",
                    hash[0], hash[1], hash[2], hash[3]);
                passedTests++;
            } else {
                System.out.println("FAIL (invalid hash length)");
                failedTests++;
            }
        } catch (Exception e) {
            System.out.println("FAIL: " + e.getMessage());
            failedTests++;
        }
    }

    private static void testSHA384() {
        System.out.print("  [2/3] SHA-384 (FIPS-approved) ... ");
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-384");
            md.update(TEST_DATA.getBytes());
            byte[] hash = md.digest();

            if (hash.length == 48) {
                System.out.printf("PASS (hash: %02x%02x%02x%02x...)%n",
                    hash[0], hash[1], hash[2], hash[3]);
                passedTests++;
            } else {
                System.out.println("FAIL (invalid hash length)");
                failedTests++;
            }
        } catch (Exception e) {
            System.out.println("FAIL: " + e.getMessage());
            failedTests++;
        }
    }

    private static void testSHA512() {
        System.out.print("  [3/3] SHA-512 (FIPS-approved) ... ");
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-512");
            md.update(TEST_DATA.getBytes());
            byte[] hash = md.digest();

            if (hash.length == 64) {
                System.out.printf("PASS (hash: %02x%02x%02x%02x...)%n",
                    hash[0], hash[1], hash[2], hash[3]);
                passedTests++;
            } else {
                System.out.println("FAIL (invalid hash length)");
                failedTests++;
            }
        } catch (Exception e) {
            System.out.println("FAIL: " + e.getMessage());
            failedTests++;
        }
    }
}
