/*
 * FIPS Validation Utility for wolfSSL FIPS v5.8.2
 *
 * This program runs the wolfSSL FIPS POST (Power-On Self Test)
 * and validates that FIPS mode is active.
 */

#include <stdio.h>
#include <wolfssl/options.h>
#include <wolfssl/wolfcrypt/settings.h>
#include <wolfssl/wolfcrypt/fips_test.h>

int main(void) {
    int ret;

    printf("===============================================\n");
    printf("wolfSSL FIPS 140-3 Validation\n");
    printf("===============================================\n\n");

    /* Run FIPS POST (Power-On Self Test) */
    printf("[CHECK 1/2] Running FIPS POST...\n");
    ret = wolfCrypt_GetStatus_fips();

    if (ret == 0) {
        printf("[OK] FIPS POST passed successfully\n");
        printf("     All Known Answer Tests (KAT) passed\n\n");
    } else {
        printf("[FAIL] FIPS POST failed with code: %d\n", ret);
        printf("       FIPS validation FAILED\n\n");
        return 1;
    }

    /* Verify FIPS build */
    printf("[CHECK 2/2] Verifying FIPS build...\n");
#ifdef HAVE_FIPS
    printf("[OK] FIPS build detected\n");
    printf("     wolfSSL FIPS v5.8.2 (Certificate #4718)\n\n");
#else
    printf("[FAIL] Non-FIPS build detected\n\n");
    return 1;
#endif

    printf("===============================================\n");
    printf("✓ ALL FIPS CHECKS PASSED\n");
    printf("===============================================\n");

    return 0;
}
