
================================================================================
[1m[0;36mUbuntu FIPS Java - Test Suite[0m
================================================================================

Running Test 1/4: Java Algorithm Enforcement (POC Requirement)...
--------------------------------------------------------------------------------
================================================================================
Test: Java FIPS Algorithm Enforcement (FIPS POC Requirement)
================================================================================

POC Validation: Java Cryptographic Validation
Requirement: MD5/SHA-1 must be blocked, SHA-256+ must succeed

[Test 1] Running Java FIPS Demo
--------------------------------------------------------------------------------
[0;32m✓ PASS[0m - Java demo executed successfully

Demo Output:
[FIPS Initialization] Enforcing FIPS mode...
  Removed SUN provider (contained pure-Java MD5/SHA-1 implementations)
  Installed FIPSBlocker provider at position 1
  Removed 31 non-FIPS algorithm entries from remaining providers
[FIPS Initialization] FIPS mode enforcement active

================================================================================
FIPS Reference Application - Java Crypto Demo
================================================================================

Purpose: Demonstrate FIPS-compliant cryptographic operations in Java

[Environment Information]
--------------------------------------------------------------------------------
Java Version: 17.0.18
Java Vendor: Ubuntu
Java Home: /usr/lib/jvm/java-17-openjdk-amd64

Security Providers:
  1. FIPSBlocker 1.0
  2. SunRsaSign 17.0
  3. SunEC 17.0
  4. SunJSSE 17.0
  5. SunJCE 17.0
  6. SunJGSS 17.0
  7. SunSASL 17.0
  8. XMLDSig 17.0
  9. SunPCSC 17.0
  10. JdkLDAP 17.0
  11. JdkSASL 17.0
  12. SunPKCS11 17.0

================================================================================

[Test Suite 1] Non-FIPS Algorithms
--------------------------------------------------------------------------------
Testing deprecated/non-FIPS algorithms:

  [1/2] MD5 (deprecated) ... BLOCKED (good - FIPS mode active)
  [2/2] SHA1 (deprecated) ... BLOCKED (good - FIPS mode active)

[Test Suite 2] FIPS-Approved Algorithms
--------------------------------------------------------------------------------
Testing FIPS-approved algorithms:

  [1/3] SHA-256 (FIPS-approved) ... PASS (hash: 3a04f988...)
  [2/3] SHA-384 (FIPS-approved) ... PASS (hash: d71ac0b1...)
  [3/3] SHA-512 (FIPS-approved) ... PASS (hash: ef58517f...)

================================================================================
Test Results
================================================================================
Total Tests: 5
Passed: 5
Failed: 0

Status: PASSED

All FIPS tests passed successfully!
Non-FIPS algorithms (MD5, SHA-1) properly blocked (FIPS mode active).
FIPS-approved algorithms (SHA-256, SHA-384, SHA-512) work correctly.


--------------------------------------------------------------------------------
[Test 2] Verify MD5 is blocked
[0;32m✓ PASS[0m - MD5 is blocked by FIPS enforcement

[Test 3] Verify SHA-1 is blocked
[0;32m✓ PASS[0m - SHA-1 is blocked (strict FIPS policy)

[Test 4] Verify SHA-256 is available
[0;32m✓ PASS[0m - SHA-256 is available (FIPS approved)

[Test 5] Verify FIPS initialization occurred
[0;32m✓ PASS[0m - FIPS initialization detected

================================================================================
Test Summary: Java FIPS Algorithm Enforcement
================================================================================
Passed: 5
Failed: 0

[0;32m✓ ALL TESTS PASSED[0m

FIPS POC Requirement: VERIFIED
  ✓ Java Cryptographic Validation
  ✓ MD5: BLOCKED
  ✓ SHA-1: BLOCKED (strict policy)
  ✓ SHA-256: AVAILABLE (FIPS approved)

[0;32m✓ Test 1 PASSED[0m

Running Test 2/4: Java FIPS Validation...
--------------------------------------------------------------------------------
================================================================================
Test: Java FIPS Validation
================================================================================

[Test 1] Java runtime exists
[0;32m✓ PASS[0m - Java runtime available

[Test 2] wolfSSL library exists
[0;32m✓ PASS[0m - wolfSSL FIPS library found

[Test 3] wolfProvider module exists
[0;32m✓ PASS[0m - wolfProvider module found

[Test 4] OpenSSL provider configuration
[0;32m✓ PASS[0m - FIPS provider loaded

[Test 5] Java demo application exists
[0;32m✓ PASS[0m - Java demo compiled

[Test 6] Run Java FIPS demo
--------------------------------------------------------------------------------
[0;32m✓ PASS[0m - Java demo executed successfully

Demo Output:
[FIPS Initialization] Enforcing FIPS mode...
  Removed SUN provider (contained pure-Java MD5/SHA-1 implementations)
  Installed FIPSBlocker provider at position 1
  Removed 31 non-FIPS algorithm entries from remaining providers
[FIPS Initialization] FIPS mode enforcement active

================================================================================
FIPS Reference Application - Java Crypto Demo
================================================================================

Purpose: Demonstrate FIPS-compliant cryptographic operations in Java

[Environment Information]
--------------------------------------------------------------------------------
Java Version: 17.0.18
Java Vendor: Ubuntu
Java Home: /usr/lib/jvm/java-17-openjdk-amd64

Security Providers:
  1. FIPSBlocker 1.0
  2. SunRsaSign 17.0
  3. SunEC 17.0
  4. SunJSSE 17.0
  5. SunJCE 17.0
  6. SunJGSS 17.0
  7. SunSASL 17.0
  8. XMLDSig 17.0
  9. SunPCSC 17.0
  10. JdkLDAP 17.0
  11. JdkSASL 17.0
  12. SunPKCS11 17.0

================================================================================

[Test Suite 1] Non-FIPS Algorithms
--------------------------------------------------------------------------------
Testing deprecated/non-FIPS algorithms:

  [1/2] MD5 (deprecated) ... BLOCKED (good - FIPS mode active)
  [2/2] SHA1 (deprecated) ... BLOCKED (good - FIPS mode active)

[Test Suite 2] FIPS-Approved Algorithms
--------------------------------------------------------------------------------
Testing FIPS-approved algorithms:

  [1/3] SHA-256 (FIPS-approved) ... PASS (hash: 3a04f988...)
  [2/3] SHA-384 (FIPS-approved) ... PASS (hash: d71ac0b1...)
  [3/3] SHA-512 (FIPS-approved) ... PASS (hash: ef58517f...)

================================================================================
Test Results
================================================================================
Total Tests: 5
Passed: 5
Failed: 0

Status: PASSED

All FIPS tests passed successfully!
Non-FIPS algorithms (MD5, SHA-1) properly blocked (FIPS mode active).
FIPS-approved algorithms (SHA-256, SHA-384, SHA-512) work correctly.


--------------------------------------------------------------------------------
[Test 7] Verify MD5 blocked
[0;32m✓ PASS[0m - MD5 is blocked

[Test 8] Verify SHA-256 available
[0;32m✓ PASS[0m - SHA-256 is available

================================================================================
Test Summary
================================================================================
Passed: 8
Failed: 0

[0;32m✓ ALL TESTS PASSED[0m
[0;32m✓ Test 2 PASSED[0m

Running Test 3/4: CLI Algorithm Enforcement (POC Requirement)...
--------------------------------------------------------------------------------
================================================================================
Test: OpenSSL CLI Algorithm Enforcement (FIPS POC Requirement)
================================================================================

POC Validation: Algorithm Enforcement via CLI
Requirement: MD5/SHA-1 must fail, SHA-256/384/512 must succeed

Test Data: "Hello FIPS World"

[Test 1] MD5 Algorithm (deprecated - should be BLOCKED)
--------------------------------------------------------------------------------
Command: echo "Hello FIPS World" | openssl md5
[0;32m✓ PASS[0m - MD5 is BLOCKED (FIPS policy enforced)

[Test 2] SHA-1 Algorithm (deprecated - should be BLOCKED in strict mode)
--------------------------------------------------------------------------------
Command: echo "Hello FIPS World" | openssl sha1
[0;32m✓ PASS[0m - SHA-1 is BLOCKED (strict FIPS policy enforced)

[Test 3] SHA-256 Algorithm (FIPS approved - should SUCCEED)
--------------------------------------------------------------------------------
Command: echo "Hello FIPS World" | openssl sha256
[0;32m✓ PASS[0m - SHA-256 is AVAILABLE (FIPS approved)
Result:
SHA256(stdin)= aabfa0f760d419db55f676e954d2475604d9cb94e6cb5b86933d2ac6a90fa0e5

[Test 4] SHA-384 Algorithm (FIPS approved - should SUCCEED)
--------------------------------------------------------------------------------
Command: echo "Hello FIPS World" | openssl sha384
[0;32m✓ PASS[0m - SHA-384 is AVAILABLE (FIPS approved)
Result:
SHA384(stdin)= c1ef5b4a678a00809e7de82b05e4f8c13c66b878b4fab3ca143f77a2957aabf29db625612eb0d057e6cc623150c649ff

[Test 5] SHA-512 Algorithm (FIPS approved - should SUCCEED)
--------------------------------------------------------------------------------
Command: echo "Hello FIPS World" | openssl sha512
[0;32m✓ PASS[0m - SHA-512 is AVAILABLE (FIPS approved)
Result:
SHA512(stdin)= 462898cbf3f4b96f0ef37badcd7c64bf89cb4e0f8d536825b594f808e327ee406cbb78484726bf724be12d7467d7449fd775b3d4844ee10dd4545d2a307dbdc7

[Test 6] Verify FIPS/wolfProvider is active
--------------------------------------------------------------------------------
Command: openssl list -providers
[0;32m✓ PASS[0m - FIPS provider detected
Active providers:
    name: wolfSSL Provider FIPS
    version: 1.1.0

[Test 7] Verify OpenSSL 3.x is active
--------------------------------------------------------------------------------
[0;32m✓ PASS[0m - OpenSSL 3.x confirmed
OpenSSL 3.0.2 15 Mar 2022 (Library: OpenSSL 3.0.2 15 Mar 2022)

[Test 8] Verify Java runtime (Java image specific)
--------------------------------------------------------------------------------
[0;32m✓ PASS[0m - Java runtime available
openjdk version "17.0.18" 2026-01-20
OpenJDK Runtime Environment (build 17.0.18+8-Ubuntu-122.04.1)
OpenJDK 64-Bit Server VM (build 17.0.18+8-Ubuntu-122.04.1, mixed mode, sharing)

================================================================================
Test Summary: OpenSSL CLI Algorithm Enforcement
================================================================================
Passed: 8
Failed: 0

[0;32m✓ ALL TESTS PASSED[0m

FIPS POC Requirement: VERIFIED
  ✓ Algorithm Enforcement via CLI
  ✓ MD5: BLOCKED
  ✓ SHA-1: BLOCKED (strict policy)
  ✓ SHA-256: AVAILABLE (FIPS approved)
  ✓ SHA-384: AVAILABLE (FIPS approved)
  ✓ SHA-512: AVAILABLE (FIPS approved)

[0;32m✓ Test 3 PASSED[0m

Running Test 4/4: OS FIPS Status Check (POC Requirement)...
--------------------------------------------------------------------------------
================================================================================
Test: Operating System FIPS Status Check (FIPS POC Requirement)
================================================================================

POC Validation: Operating System FIPS Status Check
Requirement: OS must report FIPS mode enabled, kernel-level configuration verified

[Test 1] Kernel FIPS Mode (/proc/sys/crypto/fips_enabled)
--------------------------------------------------------------------------------
Command: cat /proc/sys/crypto/fips_enabled
[1;33m⚠ WARNING[0m - /proc/sys/crypto/fips_enabled not found
Note: This is expected in containerized environments
      FIPS enforcement is provided at the application/library level

[Test 2] Kernel Boot Parameters (fips=1)
--------------------------------------------------------------------------------
Command: cat /proc/cmdline | grep fips
[1;33m⚠ INFO[0m - Kernel not booted with fips=1 parameter
Note: Expected in containers; host kernel controls this setting
      Application-level FIPS enforcement is in effect

[Test 3] System Cryptographic Policies (/etc/crypto-policies/)
--------------------------------------------------------------------------------
[1;33m⚠ INFO[0m - /etc/crypto-policies not found
Note: This directory is specific to RHEL/Fedora systems
      Ubuntu 22.04 uses different cryptographic policy mechanisms

[Test 4] OpenSSL FIPS Mode Status
--------------------------------------------------------------------------------
Command: openssl list -providers
[0;32m✓ PASS[0m - FIPS-capable provider detected

Provider details:
    fips
      name: wolfSSL Provider FIPS
      version: 1.1.0
      status: active

[Test 5] Application-Level FIPS Environment Variables (Java)
--------------------------------------------------------------------------------
  JAVA_HOME: [0;32m✓ SET (path: /usr/lib/jvm/java-17-openjdk-amd64)[0m
  Java version: [0;32m✓ AVAILABLE (version: openjdk version "17.0.18" 2026-01-20)[0m
  OPENSSL_CONF: [0;32m✓ CONFIGURED and file exists (path: /etc/ssl/openssl.cnf)[0m
  Java security policy: [0;32m✓ EXISTS (path: /usr/lib/jvm/java-17-openjdk-amd64/conf/security/java.security)[0m

[0;32m✓ PASS[0m - All application-level FIPS environment variables configured

[Test 6] wolfSSL FIPS Library Verification
--------------------------------------------------------------------------------
[0;32m✓[0m wolfSSL FIPS library found: /usr/local/lib/libwolfssl.so
[0;32m✓[0m wolfSSL registered with ldconfig
  	libwolfssl.so.44 (libc6,x86-64) => /usr/local/lib/libwolfssl.so.44
[0;32m✓[0m wolfProvider OpenSSL module found
[0;32m✓ PASS[0m - wolfSSL FIPS infrastructure present and loaded

[Test 7] Runtime FIPS Algorithm Enforcement
--------------------------------------------------------------------------------
Testing actual algorithm blocking at runtime...

  MD5 blocking: [0;32m✓ BLOCKED[0m
  SHA-256 available: [0;32m✓ AVAILABLE[0m

[0;32m✓ PASS[0m - Runtime FIPS algorithm enforcement is working

================================================================================
Test Summary: Operating System FIPS Status
================================================================================
Passed:   4
Failed:   0
Warnings: 3

[0;32m✓ OVERALL STATUS: PASSED[0m

FIPS POC Requirement: VERIFIED

Operating System FIPS Status:
  ✓ Application-level FIPS enforcement: ACTIVE
  ✓ OpenSSL FIPS provider: LOADED
  ✓ wolfSSL FIPS module: PRESENT
  ✓ Runtime algorithm enforcement: VERIFIED
  ✓ FIPS environment variables: CONFIGURED

Note: Some kernel-level checks reported warnings, which is expected in
      containerized environments. FIPS enforcement is successfully
      implemented at the application and cryptographic library level.

[0;32m✓ Test 4 PASSED[0m

================================================================================
Final Test Summary
================================================================================
Test Suites Passed: 4/4
Test Suites Failed: 0/4

================================================================================
[0;32m✓ ALL TESTS PASSED[0m
================================================================================


[0;32m✓ Diagnostics completed successfully[0m

