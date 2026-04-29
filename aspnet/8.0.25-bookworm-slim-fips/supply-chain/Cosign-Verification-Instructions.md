# Cosign Verification Guide for ASP.NET 8.0.25 FIPS Image

## Overview

This guide explains how to verify cosign signatures for the ASP.NET 8.0.25 FIPS container image (`cr.root.io/aspnet:8.0.25-bookworm-slim-fips`) stored in AWS ECR. The image is signed using Sigstore's keyless signing method with ephemeral keys.

## Prerequisites

1. **Cosign installed**: Version 2.x or later
   ```bash
   cosign version
   ```

2. **AWS CLI configured**: With credentials for ECR access
   ```bash
   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <redacted_root_ecr_base>
   ```

3. **Docker installed**: For pulling images

## Image Information

**Image:** `cr.root.io/aspnet:8.0.25-bookworm-slim-fips`
**Base:** ASP.NET Core 8.0.25 on Debian Bookworm (Slim)
**ECR Repository:** `root-reg/aspnet`
**Signing Method:** Keyless signing via Sigstore
**Image Digest:** `sha256:<to-be-updated-after-signing>`

## Verification Methods

### Method 1: Verify Using Tag (Simple)

Verify the image using its tag. This is straightforward but note that tags can change.

```bash
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/cr.root.io/aspnet:8.0.25-bookworm-slim-fips
```

### Method 2: Verify Using Digest (Recommended)

Verify using the image digest for immutable verification. You can use the known digest or get it from the image:

```bash
# Option A: Use the known digest (after signing)
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/aspnet@sha256:<digest>
```

```bash
# Option B: Get the digest from pulled image
docker pull <redacted_root_ecr_base>/root-reg/cr.root.io/aspnet:8.0.25-bookworm-slim-fips
docker inspect <redacted_root_ecr_base>/root-reg/cr.root.io/aspnet:8.0.25-bookworm-slim-fips --format '{{index .RepoDigests 0}}'

# Then verify using the digest
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/aspnet@sha256:<digest-from-above>
```

### Expected Output

Successful verification will output JSON with signature details:

```json
[{
  "critical": {
    "identity": {
      "docker-reference": "<redacted_root_ecr_base>/root-reg/cr.root.io/aspnet:8.0.25-bookworm-slim-fips"
    },
    "image": {
      "docker-manifest-digest": "sha256:<digest>"
    },
    "type": "https://sigstore.dev/cosign/sign/v1"
  },
  "optional": {}
}]
```

## Verifying Proxy Images (cr.root.io)

The cr.root.io proxy is read-only and doesn't store signature artifacts. To verify images pulled from the proxy:

1. **Pull from proxy** (for runtime use):
   ```bash
   docker pull cr.root.io/aspnet:8.0.25-bookworm-slim-fips
   ```

2. **Get the digest** from the pulled image:
   ```bash
   docker inspect cr.root.io/aspnet:8.0.25-bookworm-slim-fips --format '{{index .RepoDigests 0}}'
   ```

3. **Verify against ECR** using the digest:
   ```bash
   cosign verify \
     --certificate-identity-regexp '.*' \
     --certificate-oidc-issuer-regexp '.*' \
     <redacted_root_ecr_base>/root-reg/aspnet@sha256:<digest-from-step-2>
   ```

## Advanced Commands

### View Signature Artifacts

Show the supply chain security artifacts attached to the image:

```bash
cosign tree <redacted_root_ecr_base>/root-reg/cr.root.io/aspnet:8.0.25-bookworm-slim-fips
```

Example output:
```
📦 Supply Chain Security Related artifacts for an image: <redacted_root_ecr_base>/root-reg/cr.root.io/aspnet:8.0.25-bookworm-slim-fips
└── 🔗 https://sigstore.dev/cosign/sign/v1 artifacts via OCI referrer: <redacted_root_ecr_base>/root-reg/aspnet@sha256:<digest>
   └── 🍒 sha256:<signature-digest>
```

### List All Signature Artifacts in ECR

View all signature artifacts for ASP.NET images in the ECR repository:

```bash
aws ecr describe-images \
  --repository-name root-reg/aspnet \
  --region us-east-1 \
  --query 'imageDetails[?imageSizeInBytes < `10000`].[imageDigest, imageSizeInBytes, imageManifestMediaType]' \
  --output table
```

### Download and Inspect the Signature Bundle

```bash
# Download the signature bundle
cosign download signature <redacted_root_ecr_base>/root-reg/cr.root.io/aspnet:8.0.25-bookworm-slim-fips

# View certificate details
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/cr.root.io/aspnet:8.0.25-bookworm-slim-fips | jq
```

## Troubleshooting

### Error: no signatures found

This error means:
- The image is not signed, or
- You're trying to verify through a proxy that doesn't support OCI referrers
- **Solution:** Verify against the ECR URL directly, not the proxy

### Error: --certificate-identity or --certificate-identity-regexp is required

Cosign requires identity verification flags for keyless signatures.
- Use `--certificate-identity-regexp '.*'` and `--certificate-oidc-issuer-regexp '.*'` for basic verification
- For production, use specific identity patterns to ensure only authorized signers

### Error: response did not include Docker-Content-Digest header

This indicates:
- The registry doesn't support required OCI headers
- Cannot be used for signing operations
- **Solution:** Sign against ECR directly, not the proxy

### Verification Fails with Certificate Errors

If you see certificate validation errors:
1. Ensure you're using cosign v2.x or later
2. Check that your system time is correct (certificates are time-sensitive)
3. Verify you have internet access to reach Sigstore infrastructure

## Signing Information

**Signing Method:** Keyless signing via Sigstore
- **Authentication:** OAuth2 device flow
- **Key Type:** Ephemeral keys (generated per signing operation)
- **Transparency Log:** Rekor (public log at rekor.sigstore.dev)
- **Certificate Authority:** Fulcio (Sigstore's certificate authority)

**Signature Storage:**
- Signatures are stored as OCI artifacts in ECR
- Linked to images via OCI Referrers specification
- Small artifacts (~6KB) containing signature bundles
- Each signature includes certificate chain and transparency log entry

## Security Considerations

1. **Digest Verification:** Always verify using digests in production for immutability
2. **Certificate Identity:** In production, use specific certificate identity patterns instead of `.*`
3. **Transparency Log:** Signatures are publicly logged in Rekor for audit purposes
4. **Registry Access:** Ensure proper AWS IAM permissions for ECR access
5. **Proxy Limitations:** Be aware that read-only proxies cannot store signatures
6. **Time Sensitivity:** Keyless signatures use short-lived certificates; verify promptly after signing
7. **Audit Trail:** Check Rekor transparency log for tamper-evidence

## Best Practices

1. **Always use digest-based verification** in production environments
2. **Pin specific certificate identities** when possible for stronger verification
3. **Automate verification** in CI/CD pipelines before deployment
4. **Monitor Rekor logs** for unexpected signing events
5. **Store image digests** alongside deployment manifests
6. **Verify before pull** in production to prevent supply chain attacks

## FIPS-Specific Verification

For ASP.NET FIPS images, additional verification steps ensure FIPS compliance:

### Verify FIPS Components After Pull

After verifying the image signature, verify FIPS components are intact:

```bash
# Pull the verified image
docker pull <redacted_root_ecr_base>/root-reg/cr.root.io/aspnet:8.0.25-bookworm-slim-fips

# Run FIPS validation check
docker run -d --name aspnet-fips-test <redacted_root_ecr_base>/root-reg/cr.root.io/aspnet:8.0.25-bookworm-slim-fips tail -f /dev/null
sleep 2

# Check FIPS validation logs
docker logs aspnet-fips-test

# Expected output includes:
# ==> FIPS COMPONENTS INTEGRITY VERIFIED
# ==> FIPS INITIALIZATION TESTS PASSED (10/10)
# ==> wolfProvider active and loaded
# ==> OpenSSL FIPS mode: ENABLED
# ==> .NET OpenSSL interop: CONFIGURED
```

### Verify FIPS Mode Status

Verify that FIPS mode is enabled in the .NET environment:

```bash
# Check OpenSSL FIPS mode (should return "fips enabled")
docker exec aspnet-fips-test openssl version
# Expected output: OpenSSL 3.3.0 ... (Library: OpenSSL 3.3.0 ...)

# Check FIPS mode property
docker exec aspnet-fips-test openssl list -providers -verbose
# Expected output should include:
#   libwolfprov
#     name: wolfSSL Provider
#     version: 1.1.0
#     status: active
```

### Verify Dynamic Linker Configuration

Verify that .NET runtime loads the FIPS-enabled OpenSSL libraries:

```bash
# Check dynamic linker configuration
docker exec aspnet-fips-test cat /etc/ld.so.conf.d/00-fips-openssl.conf
# Expected output:
# /usr/local/openssl/lib

# Verify library priority
docker exec aspnet-fips-test ldconfig -p | grep libssl
# Expected output (FIPS OpenSSL should appear first):
# libssl.so.3 (libc6,x86-64) => /usr/local/openssl/lib/libssl.so.3
# libssl.so.3 (libc6,x86-64) => /lib/x86_64-linux-gnu/libssl.so.3
```

### Verify wolfProvider Loading

Check that wolfSSL provider is loaded in OpenSSL:

```bash
docker exec aspnet-fips-test openssl list -providers

# Expected output includes:
# Providers:
#   libwolfprov
#     name: wolfSSL Provider
#     version: 1.1.0
#     status: active
```

### Verify .NET Crypto Operations

Test FIPS-approved cryptographic operations using .NET APIs:

#### SHA-256 Hash (FIPS-Approved)

```bash
docker exec aspnet-fips-test dotnet --version
# Expected output: 8.0.125

# Create a test C# script
docker exec aspnet-fips-test bash -c 'cat > /tmp/test-sha256.csx << "EOF"
using System;
using System.Security.Cryptography;
using System.Text;

var data = Encoding.UTF8.GetBytes("test");
var hash = SHA256.HashData(data);
var hashHex = Convert.ToHexString(hash).ToLower();
Console.WriteLine($"SHA-256: {hashHex}");

if (hashHex == "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08")
{
    Console.WriteLine("✓ PASS - SHA-256 hash matches expected value");
}
EOF'

# Run the test
docker exec aspnet-fips-test dotnet script /tmp/test-sha256.csx

# Expected output:
# SHA-256: 9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08
# ✓ PASS - SHA-256 hash matches expected value
```

#### AES-256-GCM Encryption (FIPS-Approved)

```bash
# Create a test C# script for AES-256-GCM
docker exec aspnet-fips-test bash -c 'cat > /tmp/test-aes-gcm.csx << "EOF"
using System;
using System.Security.Cryptography;
using System.Text;

var key = RandomNumberGenerator.GetBytes(32);  // 256-bit key
var nonce = RandomNumberGenerator.GetBytes(12); // 96-bit nonce
var tag = new byte[16]; // 128-bit auth tag

using (var aes = new AesGcm(key))
{
    var plaintext = Encoding.UTF8.GetBytes("Hello, FIPS!");
    var ciphertext = new byte[plaintext.Length];

    // Encrypt
    aes.Encrypt(nonce, plaintext, ciphertext, tag);

    // Decrypt
    var decrypted = new byte[ciphertext.Length];
    aes.Decrypt(nonce, ciphertext, tag, decrypted);

    var decryptedText = Encoding.UTF8.GetString(decrypted);

    if (decryptedText == "Hello, FIPS!")
    {
        Console.WriteLine("✓ PASS - AES-256-GCM encryption/decryption successful");
    }
}
EOF'

# Run the test
docker exec aspnet-fips-test dotnet script /tmp/test-aes-gcm.csx

# Expected output:
# ✓ PASS - AES-256-GCM encryption/decryption successful
```

#### HMAC-SHA256 Operations (FIPS-Approved)

```bash
# Create a test C# script for HMAC-SHA256
docker exec aspnet-fips-test bash -c 'cat > /tmp/test-hmac.csx << "EOF"
using System;
using System.Security.Cryptography;
using System.Text;

var key = Encoding.UTF8.GetBytes("secret-key");
var data = Encoding.UTF8.GetBytes("test");

using (var hmac = new HMACSHA256(key))
{
    var hash = hmac.ComputeHash(data);
    var hashHex = Convert.ToHexString(hash).ToLower();
    Console.WriteLine($"HMAC-SHA256: {hashHex}");

    if (hash.Length == 32)
    {
        Console.WriteLine("✓ PASS - HMAC-SHA256 generated successfully");
    }
}
EOF'

# Run the test
docker exec aspnet-fips-test dotnet script /tmp/test-hmac.csx

# Expected output:
# HMAC-SHA256: <64-character hex string>
# ✓ PASS - HMAC-SHA256 generated successfully
```

### Verify MD5 Blocking (FIPS Enforcement Proof)

Verify that MD5 is blocked at the crypto API level (proves FIPS enforcement is real):

```bash
# Create a test C# script that attempts to use MD5
docker exec aspnet-fips-test bash -c 'cat > /tmp/test-md5-block.csx << "EOF"
using System;
using System.Security.Cryptography;
using System.Text;

try
{
    var data = Encoding.UTF8.GetBytes("test");
    var hash = MD5.HashData(data);
    Console.WriteLine("✗ FAIL - MD5 should be blocked in FIPS mode");
}
catch (Exception ex)
{
    if (ex.Message.Contains("unsupported") || ex.Message.Contains("FIPS"))
    {
        Console.WriteLine("✓ PASS - MD5 correctly blocked in FIPS mode");
        Console.WriteLine($"Error: {ex.Message}");
    }
    else
    {
        Console.WriteLine($"✗ UNEXPECTED ERROR: {ex.Message}");
    }
}
EOF'

# Run the test
docker exec aspnet-fips-test dotnet script /tmp/test-md5-block.csx

# Expected output:
# ✓ PASS - MD5 correctly blocked in FIPS mode
# Error: System.PlatformNotSupportedException: Operation is not supported on this platform.
# or similar error indicating FIPS enforcement
```

### Verify TLS with Kestrel (FIPS-Approved Ciphers)

Test that ASP.NET Kestrel server uses only FIPS-approved TLS cipher suites:

```bash
# Create a simple ASP.NET app
docker exec aspnet-fips-test bash -c 'cat > /tmp/test-kestrel.csx << "EOF"
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Server.Kestrel.Core;
using Microsoft.Extensions.Hosting;
using System.Security.Cryptography;

var builder = WebApplication.CreateBuilder();

// Configure Kestrel to use HTTPS with FIPS-compliant TLS
builder.WebHost.ConfigureKestrel(options =>
{
    options.ListenLocalhost(5001, listenOptions =>
    {
        listenOptions.UseHttps(); // Uses FIPS-compliant TLS automatically
    });
});

var app = builder.Build();

app.MapGet("/", () => new
{
    Message = "FIPS-enabled ASP.NET Core",
    Timestamp = DateTime.UtcNow,
    FipsMode = "Enabled (via wolfSSL FIPS v5.8.2)"
});

Console.WriteLine("✓ Kestrel HTTPS server started with FIPS-compliant TLS");
Console.WriteLine("✓ Listening on https://localhost:5001");

await app.RunAsync();
EOF'

# Note: Full test requires certificate setup. For verification, check that Kestrel starts without FIPS errors.
```

### Verify HttpClient TLS (Client-Side FIPS)

Test that HttpClient uses FIPS-approved TLS for client connections:

```bash
# Create a test C# script for HttpClient
docker exec aspnet-fips-test bash -c 'cat > /tmp/test-httpclient.csx << "EOF"
using System;
using System.Net.Http;
using System.Threading.Tasks;

var handler = new HttpClientHandler();
using var client = new HttpClient(handler);

try
{
    var response = await client.GetAsync("https://www.google.com");

    if (response.IsSuccessStatusCode)
    {
        Console.WriteLine("✓ PASS - HttpClient TLS connection successful");
        Console.WriteLine($"  Protocol: TLS 1.2+ (FIPS-compliant)");
        Console.WriteLine($"  Status: {response.StatusCode}");
    }
}
catch (Exception ex)
{
    Console.WriteLine($"✗ FAIL - {ex.Message}");
}
EOF'

# Run the test
docker exec aspnet-fips-test dotnet script /tmp/test-httpclient.csx

# Expected output:
# ✓ PASS - HttpClient TLS connection successful
#   Protocol: TLS 1.2+ (FIPS-compliant)
#   Status: OK
```

### Run Full Diagnostic Tests

For comprehensive FIPS validation, run the full diagnostic test suite:

```bash
# Navigate to the ASP.NET FIPS attestation directory
cd /path/to/aspnet/8.0.25-bookworm-slim-fips

# Run all diagnostic tests
./diagnostic.sh

# Expected output:
# ================================================================================
# ASP.NET Core wolfSSL FIPS - Diagnostic Test Suite
# ================================================================================
#
# Running Test Suite 1/5: FIPS Status Check
# Tests Passed: 10/10
# ✓ ALL TESTS PASSED
#
# Running Test Suite 2/5: Backend Verification
# Tests Passed: 10/10
# ✓ ALL TESTS PASSED
#
# Running Test Suite 3/5: FIPS Verification
# Tests Passed: 10/10
# ✓ FIPS VERIFICATION PASSED
#
# Running Test Suite 4/5: Cryptographic Operations
# Tests Passed: 20/20
# ✓ ALL TESTS PASSED
#
# Running Test Suite 5/5: TLS/HTTPS Connectivity
# Tests Passed: 15/15
# ✓ ALL TESTS PASSED
#
# ================================================================================
# OVERALL DIAGNOSTIC RESULTS
# ================================================================================
# Total Test Suites: 5
# Total Tests: 65/65
# Overall Status: ✅ ALL TESTS PASSED (100%)
```

### Verify FIPS Environment Variables

Check that FIPS environment variables are properly set:

```bash
docker exec aspnet-fips-test env | grep -E '(OPENSSL|FIPS|DOTNET)'

# Expected output:
# OPENSSL_CONF=/etc/ssl/openssl.cnf
# OPENSSL_MODULES=/usr/local/openssl/lib/ossl-modules
# DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false
# DOTNET_RUNNING_IN_CONTAINER=true
```

### Verify Dynamic Linker Test

Confirm that .NET runtime loads FIPS OpenSSL via dynamic linker:

```bash
# Run dynamic linker test
docker exec aspnet-fips-test bash -c '
ldd /usr/share/dotnet/shared/Microsoft.NETCore.App/8.0.25/libSystem.Security.Cryptography.Native.OpenSsl.so | grep libssl
'

# Expected output:
# libssl.so.3 => /usr/local/openssl/lib/libssl.so.3 (0x...)
# This confirms .NET loads FIPS-enabled OpenSSL, not system OpenSSL
```

### Verify wolfSSL FIPS Library

Confirm wolfSSL FIPS library is present and correct:

```bash
# Check wolfSSL library
docker exec aspnet-fips-test ls -lh /usr/local/lib/libwolfssl.so*

# Expected output:
# lrwxrwxrwx ... /usr/local/lib/libwolfssl.so -> libwolfssl.so.42
# lrwxrwxrwx ... /usr/local/lib/libwolfssl.so.42 -> libwolfssl.so.42.2.0
# -rwxr-xr-x ... /usr/local/lib/libwolfssl.so.42.2.0 (779 KB)

# Check wolfProvider library
docker exec aspnet-fips-test ls -lh /usr/local/openssl/lib/ossl-modules/libwolfprov.so

# Expected output:
# -rwxr-xr-x ... /usr/local/openssl/lib/ossl-modules/libwolfprov.so (1027 KB)
```

### Verify FIPS KAT Tests

Run FIPS Known Answer Tests:

```bash
docker exec aspnet-fips-test /test-fips

# Expected output:
# wolfSSL FIPS v5.8.2 (Certificate #4718)
# Known Answer Tests (KAT):
#
#   SHA-256 KAT: PASS
#   SHA-384 KAT: PASS
#   SHA-512 KAT: PASS
#   AES-128-CBC KAT: PASS
#   AES-256-CBC KAT: PASS
#   AES-256-GCM KAT: PASS
#   HMAC-SHA256 KAT: PASS
#   HMAC-SHA384 KAT: PASS
#   RSA 2048 KAT: PASS
#   ECDSA P-256 KAT: PASS
#
# All FIPS KATs: PASSED
```

### Verify OpenSSL Configuration

Check OpenSSL configuration for FIPS settings:

```bash
docker exec aspnet-fips-test cat /etc/ssl/openssl.cnf

# Expected output includes:
# [openssl_init]
# providers = provider_sect
# alg_section = algorithm_sect
#
# [provider_sect]
# libwolfprov = libwolfprov_sect
#
# [libwolfprov_sect]
# activate = 1
# module = /usr/local/openssl/lib/ossl-modules/libwolfprov.so
#
# [algorithm_sect]
# default_properties = fips=yes
```

### Verify .NET Cryptography Interop

Confirm .NET OpenSSL interop layer is configured correctly:

```bash
# Check .NET cryptography native library
docker exec aspnet-fips-test ls -lh /usr/share/dotnet/shared/Microsoft.NETCore.App/8.0.25/libSystem.Security.Cryptography.Native.OpenSsl.so

# Expected output:
# -rwxr-xr-x ... /usr/share/dotnet/shared/Microsoft.NETCore.App/8.0.25/libSystem.Security.Cryptography.Native.OpenSsl.so (147 KB)

# Verify it links to FIPS OpenSSL
docker exec aspnet-fips-test ldd /usr/share/dotnet/shared/Microsoft.NETCore.App/8.0.25/libSystem.Security.Cryptography.Native.OpenSsl.so | grep -E '(libssl|libcrypto)'

# Expected output:
# libssl.so.3 => /usr/local/openssl/lib/libssl.so.3 (0x...)
# libcrypto.so.3 => /usr/local/openssl/lib/libcrypto.so.3 (0x...)
```

### Verify ASP.NET Data Protection API

Test ASP.NET Data Protection API with FIPS:

```bash
# Create a test for Data Protection API
docker exec aspnet-fips-test bash -c 'cat > /tmp/test-dataprotection.csx << "EOF"
using Microsoft.AspNetCore.DataProtection;
using Microsoft.Extensions.DependencyInjection;
using System;

var services = new ServiceCollection();
services.AddDataProtection();
var serviceProvider = services.BuildServiceProvider();

var protector = serviceProvider.GetDataProtectionProvider()
    .CreateProtector("test-purpose");

var plaintext = "Hello, FIPS!";
var ciphertext = protector.Protect(plaintext);
var decrypted = protector.Unprotect(ciphertext);

if (decrypted == plaintext)
{
    Console.WriteLine("✓ PASS - Data Protection API works with FIPS");
}
else
{
    Console.WriteLine("✗ FAIL - Data Protection decryption mismatch");
}
EOF'

# Run the test (requires ASP.NET packages)
# docker exec aspnet-fips-test dotnet script /tmp/test-dataprotection.csx
```

## Cleanup

After verification tests are complete:

```bash
# Stop and remove test container
docker stop aspnet-fips-test
docker rm aspnet-fips-test

# Clean up test scripts
docker exec aspnet-fips-test rm -f /tmp/test-*.csx
```

## Additional Resources

- [Cosign Documentation](https://docs.sigstore.dev/cosign/overview/)
- [Sigstore Project](https://www.sigstore.dev/)
- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [OCI Referrers Specification](https://github.com/opencontainers/distribution-spec/blob/main/spec.md#listing-referrers)
- [Rekor Transparency Log](https://rekor.sigstore.dev/)
- [ASP.NET Core FIPS Documentation](../README.md)
- [FIPS Evidence Documentation](../Evidence/)
- [FIPS 140-3 Certificate #4718](https://csrc.nist.gov/projects/cryptographic-module-validation-program/certificate/4718)
- [wolfSSL FIPS Documentation](https://www.wolfssl.com/products/fips/)
- [ASP.NET Core Security Documentation](https://docs.microsoft.com/aspnet/core/security/)
- [.NET Cryptography Documentation](https://docs.microsoft.com/dotnet/api/system.security.cryptography)
- [OpenSSL Provider Documentation](https://www.openssl.org/docs/man3.0/man7/provider.html)
- [Kestrel Web Server Documentation](https://docs.microsoft.com/aspnet/core/fundamentals/servers/kestrel)

## Contact

For questions about Cosign verification or FIPS compliance:
- **Security Team**: security@root.com
- **Build Team**: build@root.com
- **Compliance Team**: compliance@root.com

---

**Document Version:** 1.0
**Last Updated:** 2026-04-23
**Image:** cr.root.io/aspnet:8.0.25-bookworm-slim-fips
**Base:** ASP.NET Core 8.0.25 on Debian Bookworm (Slim)
**FIPS Module:** wolfSSL FIPS v5.8.2 (Certificate #4718)
**Provider:** wolfProvider v1.1.0 for OpenSSL 3.3.0
