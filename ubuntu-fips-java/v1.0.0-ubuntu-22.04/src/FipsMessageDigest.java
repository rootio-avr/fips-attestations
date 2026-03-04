import java.security.*;

/**
 * FIPS Message Digest Wrapper
 *
 * Purpose: Wrapper for MessageDigest that blocks non-FIPS algorithms
 *
 * Usage: Replace MessageDigest.getInstance() calls with FipsMessageDigest.getInstance()
 */
public class FipsMessageDigest {

    private static final String[] BLOCKED_ALGORITHMS = {
        "MD5", "SHA-1", "SHA1", "SHA", "MD2"
    };

    /**
     * Get a MessageDigest instance, blocking non-FIPS algorithms
     */
    public static MessageDigest getInstance(String algorithm) throws NoSuchAlgorithmException {
        // Check if algorithm is blocked
        for (String blocked : BLOCKED_ALGORITHMS) {
            if (algorithm.equalsIgnoreCase(blocked)) {
                throw new NoSuchAlgorithmException(
                    "Algorithm " + algorithm + " is not allowed in FIPS mode. " +
                    "This algorithm has been blocked by FIPS security policy. " +
                    "Use FIPS-approved algorithms like SHA-256, SHA-384, or SHA-512."
                );
            }
        }

        // Algorithm is allowed, delegate to real MessageDigest
        return MessageDigest.getInstance(algorithm);
    }
}
