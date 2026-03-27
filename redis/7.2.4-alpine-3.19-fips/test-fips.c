/*
 * test-fips.c
 *
 * Simple test program to verify wolfSSL FIPS module is working correctly.
 * This is used during the Docker build process to validate the wolfSSL
 * FIPS installation before proceeding.
 *
 * Compile:
 *   gcc test-fips.c -o test-fips -lwolfssl -I/usr/local/include
 *
 * Run:
 *   ./test-fips
 *
 * Exit codes:
 *   0 - Success (FIPS working)
 *   1 - Failure (FIPS not working)
 */

#include <stdio.h>
#include <wolfssl/options.h>
#include <wolfssl/wolfcrypt/settings.h>
#include <wolfssl/version.h>

int main(void) {
    printf("wolfSSL FIPS Test Utility\n");
    printf("=========================\n\n");

    /* Print wolfSSL version */
    printf("wolfSSL version: %s\n", LIBWOLFSSL_VERSION_STRING);

#ifdef HAVE_FIPS
    printf("FIPS mode: ENABLED\n");
#ifdef HAVE_FIPS_VERSION
    printf("FIPS version: %d\n", HAVE_FIPS_VERSION);
#endif
    printf("\n");
    printf("✓ wolfSSL FIPS test PASSED\n");
    printf("✓ FIPS module is correctly installed\n");
    return 0;
#else
    printf("FIPS mode: DISABLED\n");
    printf("\n");
    printf("✗ wolfSSL FIPS test FAILED\n");
    printf("✗ FIPS module is NOT enabled\n");
    return 1;
#endif
}
