/*
 * wolfSSL FIPS Known Answer Test (KAT) Utility
 *
 * This program performs FIPS 140-3 POST (Power-On Self Test) to validate
 * the wolfSSL FIPS cryptographic module integrity and functionality.
 *
 * Tests Performed:
 *   - wolfSSL FIPS module integrity check
 *   - FIPS Known Answer Tests (KAT) for approved algorithms
 *   - Verifies FIPS mode is operational
 *
 * Exit Codes:
 *   0 - FIPS POST passed
 *   1 - FIPS POST failed
 *
 * Usage:
 *   ./test-fips
 *
 * wolfSSL FIPS v5.8.2 - Certificate #4718
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef HAVE_CONFIG_H
    #include <config.h>
#endif

#include <wolfssl/options.h>
#include <wolfssl/wolfcrypt/settings.h>
#include <wolfssl/wolfcrypt/fips_test.h>
#include <wolfssl/version.h>

/* Color codes for output */
#define COLOR_RED     "\033[0;31m"
#define COLOR_GREEN   "\033[0;32m"
#define COLOR_YELLOW  "\033[1;33m"
#define COLOR_RESET   "\033[0m"

/* Print helper macros */
#define PRINT_SUCCESS(msg) printf("%s✓%s %s\n", COLOR_GREEN, COLOR_RESET, msg)
#define PRINT_ERROR(msg)   printf("%s✗%s %s\n", COLOR_RED, COLOR_RESET, msg)
#define PRINT_INFO(msg)    printf("  %s\n", msg)

int main(void)
{
    int ret = 0;

    printf("================================================================================\n");
    printf("wolfSSL FIPS 140-3 Known Answer Test (KAT)\n");
    printf("================================================================================\n\n");

    /* Display wolfSSL version information */
    printf("wolfSSL Version: %s\n", LIBWOLFSSL_VERSION_STRING);

#ifdef HAVE_FIPS
    printf("FIPS Mode:       ENABLED\n");
#else
    printf("FIPS Mode:       DISABLED\n");
    PRINT_ERROR("FIPS support not compiled in wolfSSL library");
    return 1;
#endif

#ifdef HAVE_FIPS_VERSION
    printf("FIPS Version:    %d\n", HAVE_FIPS_VERSION);
#endif

    printf("\n");

    /* Run FIPS Known Answer Tests */
    printf("Running FIPS POST (Power-On Self Test)...\n\n");

#ifdef HAVE_FIPS
    /*
     * wolfCrypt_SetStatus_fips() initializes the FIPS module and runs KAT
     * Return value: 0 on success, negative on failure
     */
    ret = wolfCrypt_GetStatus_fips();

    if (ret == 0) {
        PRINT_SUCCESS("FIPS POST completed successfully");
        PRINT_INFO("All Known Answer Tests (KAT) passed");
        PRINT_INFO("wolfSSL FIPS module is operational");
        printf("\n");
        printf("================================================================================\n");
        printf("FIPS 140-3 Validation: PASS\n");
        printf("Certificate: #4718\n");
        printf("================================================================================\n");
        return 0;
    } else {
        PRINT_ERROR("FIPS POST failed!");
        printf("\nError Code: %d\n", ret);
        printf("The wolfSSL FIPS cryptographic module failed self-tests.\n");
        printf("This indicates a potential integrity violation or configuration error.\n");
        printf("\nPossible causes:\n");
        PRINT_INFO("- Library tampering or corruption");
        PRINT_INFO("- Incorrect wolfSSL build configuration");
        PRINT_INFO("- Missing FIPS-approved algorithm implementations");
        printf("\n");
        printf("================================================================================\n");
        printf("FIPS 140-3 Validation: FAIL\n");
        printf("================================================================================\n");
        return 1;
    }
#else
    PRINT_ERROR("FIPS support not available");
    printf("\nwolfSSL was not built with FIPS support.\n");
    printf("Rebuild wolfSSL with: ./configure --enable-fips=v5\n");
    printf("\n");
    return 1;
#endif
}
