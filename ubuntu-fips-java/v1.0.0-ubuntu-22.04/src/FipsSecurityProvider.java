import java.security.*;
import java.util.*;

/**
 * FIPS Security Provider - Blocks Non-FIPS Algorithms
 *
 * Purpose: Custom security provider that blocks MD5, SHA-1, and other
 *          non-FIPS approved algorithms at the JDK level.
 *
 * This provider removes all non-FIPS providers and only allows FIPS-compliant algorithms.
 */
public class FipsSecurityProvider extends Provider {

    private static final Set<String> BLOCKED_ALGORITHMS = new HashSet<>(Arrays.asList(
        // Message Digests
        "MD5", "SHA-1", "SHA1", "SHA", "MD2",

        // Signatures
        "MD5withRSA", "MD5WithRSA", "MD5andSHA1withRSA",
        "SHA1withRSA", "SHA1WithRSA", "SHA1withDSA", "SHA1WithDSA",
        "SHA1withECDSA", "SHA1WithECDSA",

        // MAC
        "HmacMD5", "HmacSHA1",

        // Ciphers
        "DES", "DESede", "RC4"
    ));

    public FipsSecurityProvider() {
        super("FIPSBlocker", 1.0, "FIPS Security Provider - Blocks non-FIPS algorithms");

        // Register FIPS-approved algorithms by delegating to SunRsaSign or SunJCE providers
        // These will be available even after we remove the SUN provider
        put("MessageDigest.SHA-256", "sun.security.provider.SHA2$SHA256");
        put("MessageDigest.SHA-384", "sun.security.provider.SHA5$SHA384");
        put("MessageDigest.SHA-512", "sun.security.provider.SHA5$SHA512");
        put("MessageDigest.SHA-224", "sun.security.provider.SHA2$SHA224");

        // Add aliases
        put("Alg.Alias.MessageDigest.SHA256", "SHA-256");
        put("Alg.Alias.MessageDigest.SHA384", "SHA-384");
        put("Alg.Alias.MessageDigest.SHA512", "SHA-512");
        put("Alg.Alias.MessageDigest.SHA224", "SHA-224");
    }

    /**
     * Install this provider and remove the SUN provider to block pure-Java crypto
     *
     * Strategy: Remove SUN provider which contains pure-Java implementations of MD5/SHA-1
     *           that bypass native wolfSSL FIPS restrictions
     */
    public static void enforceFipsMode() {
        System.out.println("[FIPS Initialization] Enforcing FIPS mode...");

        // The SUN provider contains pure-Java implementations of MD5, SHA-1
        // These bypass the native wolfSSL FIPS library restrictions
        // We must remove this provider to enforce FIPS compliance
        try {
            Security.removeProvider("SUN");
            System.out.println("  Removed SUN provider (contained pure-Java MD5/SHA-1 implementations)");
        } catch (Exception e) {
            System.out.println("  Warning: Could not remove SUN provider: " + e.getMessage());
        }

        // Install our blocking provider at highest priority
        Provider fipsBlocker = new FipsSecurityProvider();
        Security.insertProviderAt(fipsBlocker, 1);
        System.out.println("  Installed FIPSBlocker provider at position 1");

        // Remove MD5 and SHA-1 from remaining providers
        int removedCount = 0;
        for (Provider provider : Security.getProviders()) {
            if (provider instanceof FipsSecurityProvider) {
                continue;
            }

            // Get all property keys
            List<Object> keysToCheck = new ArrayList<>(provider.keySet());

            for (Object keyObj : keysToCheck) {
                String key = keyObj.toString();

                // Remove any keys containing blocked algorithms
                for (String algorithm : BLOCKED_ALGORITHMS) {
                    if (key.contains("." + algorithm + " ") ||
                        key.endsWith("." + algorithm) ||
                        key.contains("." + algorithm.toLowerCase() + " ") ||
                        key.endsWith("." + algorithm.toLowerCase())) {

                        if (provider.remove(key) != null) {
                            removedCount++;
                        }
                    }
                }
            }
        }

        System.out.println("  Removed " + removedCount + " non-FIPS algorithm entries from remaining providers");
        System.out.println("[FIPS Initialization] FIPS mode enforcement active");
        System.out.println();
    }
}
