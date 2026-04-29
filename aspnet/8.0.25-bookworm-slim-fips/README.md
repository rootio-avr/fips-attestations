# ASP.NET Core 8.0.25 with wolfSSL FIPS 140-3

**Docker container providing FIPS 140-3 validated cryptography for ASP.NET Core applications**

- **ASP.NET Version**: 8.0.25
- **Base Image**: mcr.microsoft.com/dotnet/aspnet:8.0.25-bookworm-slim
- **FIPS Module**: wolfSSL 5.8.2 (Certificate #4718)
- **Architecture**: Provider-based (OpenSSL 3.3.7 + wolfProvider)
- **Status**: Production-ready (65/65 tests passing)

> **Note:** The published `cr.root.io` image reflects this configuration; run `/app/diagnostic.sh` to verify on your digest.

---

## Overview

This container image provides ASP.NET Core 8.0.25 with FIPS 140-3 validated cryptography using the wolfSSL FIPS module through the OpenSSL 3.3.7 provider interface. Unlike approaches that require custom .NET crypto implementations or wolfSSL .NET bindings, this implementation uses:

- **Standard .NET Crypto APIs** (System.Security.Cryptography)
- **No code changes required** - Works with any ASP.NET Core application
- **wolfProvider** to route crypto operations to wolfSSL FIPS
- **OpenSSL 3.3.7 provider architecture** for seamless integration
- **Dynamic linker configuration** to ensure .NET loads FIPS OpenSSL

### Key Features

✅ **FIPS 140-3 Validated**: wolfSSL 5.8.2 Certificate #4718
✅ **No Code Changes**: Standard .NET crypto APIs work transparently
✅ **Drop-in Compliance**: Any ASP.NET Core app is FIPS-compliant
✅ **TLS 1.2/1.3 Support**: Kestrel uses FIPS-approved ciphers
✅ **Data Protection API**: Works with FIPS crypto automatically
✅ **100% Test Pass Rate**: 65/65 diagnostic tests passing
✅ **Fast Build**: ~15 minutes (multi-stage build)

---

## Quick Start

### 1. Prerequisites

- Docker 20.10+ with BuildKit support
- wolfSSL FIPS 5.8.2 package password

### 2. Setup

Create the wolfSSL password file:
```bash
echo 'YOUR_WOLFSSL_PASSWORD' > wolfssl_password.txt
```

### 3. Build

```bash
./build.sh
```

Build time: ~15 minutes

### 4. Run

```bash
# Interactive shell
docker run --rm -it cr.root.io/aspnet:8.0.25-bookworm-slim-fips

# Run your ASP.NET application
docker run --rm -p 8080:8080 -v $(pwd)/app:/app -w /app \
    cr.root.io/aspnet:8.0.25-bookworm-slim-fips \
    dotnet MyWebApp.dll

# Run FIPS validation
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips /usr/local/bin/fips-startup-check

# Run diagnostic suite
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips /app/diagnostic.sh
```

### 5. Validate

```bash
# Run full diagnostic suite (65 tests)
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips /app/diagnostic.sh

# Quick status check (10 tests)
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips /app/diagnostic.sh --status

# Crypto operations only (20 tests)
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips /app/diagnostic.sh --crypto

# Verify FIPS components
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips openssl list -providers
# Expected: wolfProvider (wolfSSL Provider FIPS v1.1.0, status: active)
```

---

## Environment Variables

**All environment variables are AUTOMATICALLY configured** - you don't need to set them manually!

The container automatically sets the required FIPS environment variables through the `docker-entrypoint.sh` script. This ensures correct FIPS operation without any user intervention.

### Required Variables

| Variable | Purpose | Default Value | Set By |
|----------|---------|---------------|--------|
| `OPENSSL_CONF` | Points to OpenSSL config that loads wolfProvider | `/usr/local/openssl/ssl/openssl.cnf` | docker-entrypoint.sh |
| `OPENSSL_MODULES` | Directory containing wolfProvider module | `/usr/local/openssl/lib/ossl-modules` | Dockerfile (ENV) |
| `LD_LIBRARY_PATH` | Ensures FIPS OpenSSL libraries are loaded first | `/usr/local/openssl/lib:/usr/local/lib` | docker-entrypoint.sh |
| `PATH` | Includes FIPS OpenSSL binary directory | `/usr/local/openssl/bin:...` | Dockerfile (ENV) |

### Variable Details

**`OPENSSL_CONF`**
- Configures OpenSSL to use the wolfSSL FIPS provider
- Points to the configuration file that activates wolfProvider
- Set at runtime by entrypoint to avoid .NET startup interference

**`OPENSSL_MODULES`**
- Directory where OpenSSL searches for provider modules
- Contains `libwolfprov.so` (the wolfSSL FIPS provider)
- Set in Dockerfile and available at both build and runtime

**`LD_LIBRARY_PATH`**
- Ensures FIPS OpenSSL libraries are found before system OpenSSL
- Works with `/etc/ld.so.conf.d/00-fips-openssl.conf` for priority
- Set at runtime to avoid build-time conflicts

**`PATH`**
- Ensures `openssl` command uses FIPS-enabled OpenSSL 3.3.7
- Allows you to run FIPS-compliant OpenSSL commands directly
- Set in Dockerfile for consistent access

### Verification

**View current environment variables:**
```bash
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips env | grep OPENSSL
```

**Get detailed help about environment variables:**
```bash
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips fips-env-help
```

**Validate environment is correctly configured:**
```bash
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips verify-fips-env
```

Expected output:
```
================================================================================
  FIPS Environment Validation
================================================================================

Checking OPENSSL_CONF... OK (/usr/local/openssl/ssl/openssl.cnf)
Checking OPENSSL_MODULES... OK (/usr/local/openssl/lib/ossl-modules)
  ✓ libwolfprov.so found
Checking LD_LIBRARY_PATH... OK (/usr/local/openssl/lib:/usr/local/lib)
  ✓ FIPS OpenSSL lib in path
Checking PATH for OpenSSL... OK
  ✓ FIPS OpenSSL bin in PATH
Checking OpenSSL binary... OK (OpenSSL 3.3.7 7 Apr 2026)
Checking wolfSSL library... OK (/usr/local/lib/libwolfssl.so.43.2.2)
Checking dynamic linker config... OK
  ✓ FIPS OpenSSL has priority

================================================================================
  Summary
================================================================================

✓ All checks passed - FIPS environment is correctly configured
```

### When to Override

Most users **do NOT need to override** these variables. The container handles everything automatically.

Override only in these scenarios:

**Debugging with custom configuration:**
```bash
docker run -e OPENSSL_CONF=/custom/openssl.cnf cr.root.io/aspnet:8.0.25-bookworm-slim-fips
```

**Using a different FIPS module location:**
```bash
docker run -e OPENSSL_MODULES=/custom/modules cr.root.io/aspnet:8.0.25-bookworm-slim-fips
```

**Disabling FIPS validation (development/testing only):**
```bash
docker run -e FIPS_CHECK=false cr.root.io/aspnet:8.0.25-bookworm-slim-fips
```

⚠️ **Warning:** Overriding environment variables may break FIPS compliance. Only do this if you understand the implications.

### Troubleshooting

**Issue: Environment variable not set**
```bash
# This is expected if checking before container starts
# Variables are set by docker-entrypoint.sh when container runs normally
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips verify-fips-env
```

**Issue: Wrong OpenSSL version**
```bash
# Verify FIPS OpenSSL has priority
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips ldconfig -p | grep libssl.so.3 | head -1
# Should show: /usr/local/openssl/lib/libssl.so.3 (not /lib/x86_64-linux-gnu)
```

**Issue: wolfProvider not loaded**
```bash
# Check OPENSSL_CONF and OPENSSL_MODULES are set correctly
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips fips-env-help
```

For more details, see the [docker-entrypoint.sh](docker-entrypoint.sh) script and [ARCHITECTURE.md](ARCHITECTURE.md).

---

## FIPS Compliance

### Validated Cryptography

**FIPS-Approved Algorithms:**
- ✅ SHA-256, SHA-384, SHA-512 (hashing)
- ✅ AES-CBC, AES-GCM (128, 192, 256-bit) encryption
- ✅ ECDSA (P-256, P-384, P-521) signatures
- ✅ RSA (2048+ bit) signatures and encryption
- ✅ HMAC-SHA-256/384/512
- ✅ PBKDF2 key derivation
- ✅ ECDH key exchange

**TLS/HTTPS:**
- ✅ TLS 1.2 (with FIPS-approved ciphers)
- ✅ TLS 1.3 (recommended)
- ✅ Available cipher suites: FIPS-approved only

**Example FIPS-Approved Ciphers:**
- `TLS_AES_256_GCM_SHA384`
- `TLS_AES_128_GCM_SHA256`
- `ECDHE-RSA-AES256-GCM-SHA384`
- `ECDHE-RSA-AES128-GCM-SHA256`

### Certificate Details

**CMVP Certificate:** #4718
**Module:** wolfSSL Cryptographic Module v5.8.2
**Security Level:** 1
**Validation:** FIPS 140-3 (2024)

---

## Usage Examples

### Basic ASP.NET Core HTTPS API

```csharp
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;

var builder = WebApplication.CreateBuilder(args);

// Configure Kestrel to use HTTPS (automatically uses FIPS crypto)
builder.WebHost.ConfigureKestrel(options =>
{
    options.ListenAnyIP(8443, listenOptions =>
    {
        listenOptions.UseHttps();  // Uses FIPS-approved TLS
    });
});

var app = builder.Build();

app.MapGet("/", () => "FIPS-compliant ASP.NET Core API");
app.Run();
```

### SHA-256 Hashing

```csharp
using System.Security.Cryptography;
using System.Text;

// FIPS-approved: SHA-256
var data = Encoding.UTF8.GetBytes("FIPS test data");
var hash = SHA256.HashData(data);
Console.WriteLine($"SHA-256: {Convert.ToHexString(hash)}");

// FIPS-approved: SHA-512
var hash512 = SHA512.HashData(data);
Console.WriteLine($"SHA-512: {Convert.ToHexString(hash512)}");
```

### AES-256-GCM Encryption

```csharp
using System.Security.Cryptography;

// Generate FIPS-compliant random key and IV
var key = RandomNumberGenerator.GetBytes(32);  // 256-bit key
var nonce = RandomNumberGenerator.GetBytes(12); // 96-bit nonce for GCM
var tag = new byte[16]; // 128-bit authentication tag

// Encrypt with AES-256-GCM (FIPS-approved)
using (var aes = new AesGcm(key))
{
    var plaintext = Encoding.UTF8.GetBytes("Hello, FIPS!");
    var ciphertext = new byte[plaintext.Length];

    aes.Encrypt(nonce, plaintext, ciphertext, tag);

    Console.WriteLine($"Encrypted: {Convert.ToHexString(ciphertext)}");
    Console.WriteLine($"Tag: {Convert.ToHexString(tag)}");

    // Decrypt
    var decrypted = new byte[ciphertext.Length];
    aes.Decrypt(nonce, ciphertext, tag, decrypted);

    Console.WriteLine($"Decrypted: {Encoding.UTF8.GetString(decrypted)}");
    // Output: Decrypted: Hello, FIPS!
}
```

### Data Protection API with FIPS

```csharp
using Microsoft.AspNetCore.DataProtection;
using Microsoft.Extensions.DependencyInjection;

var services = new ServiceCollection();

// Data Protection automatically uses FIPS crypto
services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo("/keys"))
    .SetApplicationName("MyFipsApp");

var provider = services.BuildServiceProvider();
var protector = provider.GetDataProtectionProvider()
    .CreateProtector("MyProtector");

// Protect data (uses FIPS-compliant AES-256-GCM)
var plaintext = "Sensitive data";
var protected = protector.Protect(plaintext);
Console.WriteLine($"Protected: {protected}");

// Unprotect
var unprotected = protector.Unprotect(protected);
Console.WriteLine($"Unprotected: {unprotected}");
```

### HMAC-SHA256

```csharp
using System.Security.Cryptography;
using System.Text;

// FIPS-approved HMAC-SHA256
var key = RandomNumberGenerator.GetBytes(32);
var data = Encoding.UTF8.GetBytes("Message to authenticate");

using (var hmac = new HMACSHA256(key))
{
    var hash = hmac.ComputeHash(data);
    Console.WriteLine($"HMAC-SHA256: {Convert.ToHexString(hash)}");
}
```

### RSA Digital Signature

```csharp
using System.Security.Cryptography;

// Generate FIPS-compliant RSA 2048-bit key pair
using (var rsa = RSA.Create(2048))
{
    var data = Encoding.UTF8.GetBytes("Document to sign");

    // Sign with RSA-SHA256 (FIPS-approved)
    var signature = rsa.SignData(data, HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1);
    Console.WriteLine($"Signature: {Convert.ToHexString(signature)}");

    // Verify
    bool isValid = rsa.VerifyData(data, signature, HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1);
    Console.WriteLine($"Signature valid: {isValid}");
}
```

### ASP.NET Core Authentication with FIPS

```csharp
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

// JWT authentication (uses FIPS crypto for signature validation)
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = "https://api.example.com",
            ValidAudience = "https://api.example.com",
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes("your-256-bit-secret-key-here"))
        };
    });

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();
app.Run();
```

---

## Architecture

### Component Stack

```
ASP.NET Core 8.0.25 Application
         ↓
.NET Runtime 8.0.25 (System.Security.Cryptography)
         ↓
libSystem.Security.Cryptography.Native.OpenSsl.so
         ↓
OpenSSL 3.3.7 (libssl, libcrypto)
         ↓
wolfProvider v1.1.0 (provider interface)
         ↓
wolfSSL 5.8.2 FIPS Module (Certificate #4718)
```

### Dynamic Linker Configuration (Critical)

The key to FIPS enforcement is ensuring .NET loads FIPS OpenSSL:

**Configuration File:** `/etc/ld.so.conf.d/00-fips-openssl.conf`
```
/usr/local/openssl/lib
/usr/local/lib
```

This ensures when .NET calls `dlopen("libssl.so.3")`, the dynamic linker finds FIPS OpenSSL first.

**Verification:**
```bash
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips ldconfig -p | grep libssl.so.3 | head -1
# Expected: libssl.so.3 => /usr/local/openssl/lib/libssl.so.3 (FIPS)
```

### OpenSSL Configuration

**Configuration File:** `/usr/local/openssl/ssl/openssl.cnf`
```ini
openssl_conf = openssl_init

[openssl_init]
providers = provider_sect

[provider_sect]
wolfProvider = wolfProvider_sect

[wolfProvider_sect]
activate = 1
```

**Environment Variables:**
- `OPENSSL_CONF=/usr/local/openssl/ssl/openssl.cnf`
- `OPENSSL_MODULES=/usr/local/openssl/lib/ossl-modules`
- `LD_LIBRARY_PATH=/usr/local/openssl/lib:/usr/local/lib`

---

## Diagnostics

### Run All Tests

```bash
# Full diagnostic suite (65 tests)
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips /app/diagnostic.sh

# Quick status check (10 tests)
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips /app/diagnostic.sh --status

# Crypto operations only (20 tests)
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips /app/diagnostic.sh --crypto

# With verbose output
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips /app/diagnostic.sh --verbose
```

### Test Suites

1. **FIPS Status Check** (10 tests)
   - Environment variables
   - Dynamic linker configuration
   - OpenSSL binary version
   - wolfProvider loading
   - wolfSSL FIPS library
   - .NET runtime version
   - .NET OpenSSL interop
   - FIPS module files
   - OpenSSL configuration
   - FIPS startup utility

2. **Backend Verification** (10 tests)
   - OpenSSL version detection
   - Library path verification
   - OpenSSL provider enumeration
   - FIPS module presence
   - Dynamic linker configuration
   - Environment variables
   - .NET → OpenSSL interop layer
   - Certificate store access
   - Cipher suite availability
   - OpenSSL command execution

3. **FIPS Verification** (10 tests)
   - FIPS mode detection
   - wolfSSL FIPS module version
   - CMVP certificate validation (#4718)
   - FIPS POST verification
   - FIPS-approved algorithms
   - Non-approved algorithm blocking
   - Configuration file validation
   - wolfProvider FIPS mode
   - FIPS error handling
   - Cryptographic boundary validation

4. **Cryptographic Operations** (20 tests)
   - SHA-256, SHA-384, SHA-512 hashing
   - AES-128-GCM, AES-256-GCM encryption
   - AES-256-CBC encryption/decryption
   - RSA-2048 key generation
   - RSA-2048 encrypt/decrypt
   - RSA-2048 digital signature
   - ECDSA P-256 key generation
   - ECDSA P-256/P-384 sign/verify
   - HMAC-SHA256/SHA512
   - PBKDF2 key derivation
   - Random number generation
   - ECDH P-256/P-384 key exchange
   - RSA-PSS signature
   - Multi-algorithm chain test

5. **TLS/HTTPS Connectivity** (15 tests)
   - Basic HTTPS GET/POST
   - Custom headers
   - TLS 1.2/1.3 protocol detection
   - Certificate chain validation
   - Concurrent connections
   - Timeout handling
   - Redirect following
   - Compression
   - Response headers
   - Large responses
   - Query parameters
   - Connection reuse
   - Content types (JSON/HTML/XML)
   - TLS SNI support

### Expected Results

- ✅ FIPS Status: 10/10 tests passing
- ✅ Backend Verification: 10/10 tests passing
- ✅ FIPS Verification: 10/10 tests passing
- ✅ Crypto Operations: 20/20 tests passing
- ✅ Connectivity: 15/15 tests passing

**Overall: 65/65 tests passing (100% pass rate)**

### Test Results

All test results are saved in JSON format:
- `backend-verification-results.json`
- `fips-verification-results.json`
- `crypto-operations-results.json`
- `connectivity-results.json`

---

## Build Details

### Build Process

1. **Stage 1: Builder**
   - Build OpenSSL 3.3.7 with FIPS support
   - Build wolfSSL FIPS v5.8.2
   - Build wolfProvider v1.1.0

2. **Stage 2: Runtime**
   - Start from `mcr.microsoft.com/dotnet/aspnet:8.0.25-bookworm-slim`
   - Copy FIPS components from builder
   - Configure dynamic linker (`/etc/ld.so.conf.d/00-fips-openssl.conf`)
   - Install .NET SDK and dotnet-script (for diagnostics)
   - Copy OpenSSL configuration
   - Copy diagnostic suite

### Build Command

```bash
docker build \
    --secret id=wolfssl_password,src=wolfssl_password.txt \
    -t cr.root.io/aspnet:8.0.25-bookworm-slim-fips \
    -f Dockerfile .
```

### Build Options

```bash
# Default build
./build.sh

# Build without cache
./build.sh --no-cache

# Build for specific platform
docker buildx build --platform linux/amd64 ...
```

### Build Time

- **OpenSSL**: ~3 minutes
- **wolfSSL FIPS**: ~5 minutes
- **wolfProvider**: ~2 minutes
- **.NET SDK**: ~3 minutes
- **Assembly**: ~2 minutes
- **Total**: ~15 minutes

### Image Size

- **Final Image**: ~960MB (includes .NET SDK for diagnostics)
- **ASP.NET Runtime**: 8.0.25
- **.NET SDK**: 8.0.420 (for diagnostics)

---

## Security

### Startup Validation

On container start, the entrypoint performs:
1. **FIPS component verification**
2. **wolfSSL FIPS POST** (Power-On Self Test)
3. **Environment configuration check**
4. **OpenSSL provider loading**

### FIPS Startup Check

```bash
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips /usr/local/bin/fips-startup-check

# Expected output:
# wolfSSL Version: 5.8.2
# ✓ FIPS mode: ENABLED
# ✓ FIPS POST completed successfully
# ✓ AES-GCM encryption successful
# ✓ wolfSSL FIPS module: OPERATIONAL
# Certificate: #4718
```

### FIPS Mode Verification

```bash
# Verify OpenSSL version
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips openssl version
# Expected: OpenSSL 3.3.7 7 Apr 2026 (Library: OpenSSL 3.3.7 7 Apr 2026)

# Verify wolfProvider is loaded
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips openssl list -providers
# Expected: wolfProvider (wolfSSL Provider FIPS v1.1.0, status: active)

# Verify dynamic linker configuration
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips \
    bash -c "ldconfig -p | grep libssl.so.3 | head -1"
# Expected: libssl.so.3 => /usr/local/openssl/lib/libssl.so.3
```

### Skip Validation (Development Only)

```bash
docker run --rm -e FIPS_CHECK=false cr.root.io/aspnet:8.0.25-bookworm-slim-fips
```

---

## Documentation

- **README.md** - This file (Quick start guide)
- **ARCHITECTURE.md** - Detailed architecture documentation
- **diagnostics/README.md** - Diagnostic suite documentation
- **diagnostics/IMPLEMENTATION-GUIDE.md** - Implementation details

---

## Known Limitations

1. **.NET 8 Support**: .NET 8 is supported until November 2026 (LTS)
2. **Image Size**: Larger than runtime-only images due to .NET SDK (for diagnostics)
3. **Third-party Libraries**: Libraries directly calling OpenSSL may need verification
4. **Performance**: Slight overhead from provider architecture (~5-10%)

---

## Troubleshooting

### Build Fails

**Issue**: wolfSSL password error
```bash
echo 'YOUR_ACTUAL_PASSWORD' > wolfssl_password.txt
./build.sh
```

**Issue**: Network timeout during build
```bash
docker build --build-arg HTTP_PROXY=http://proxy:8080 ...
```

**Issue**: .NET SDK installation fails
```bash
# Check available disk space
df -h
```

### Runtime Issues

**Issue**: "Provider could not be loaded"
```bash
# Check OpenSSL configuration
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips \
    cat /usr/local/openssl/ssl/openssl.cnf

# Check provider library exists
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips \
    ls -la /usr/local/openssl/lib/ossl-modules/libwolfprov.so
```

**Issue**: ".NET loads wrong OpenSSL"
```bash
# Verify dynamic linker priority
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips \
    ldconfig -p | grep libssl.so.3

# First entry should be /usr/local/openssl/lib/libssl.so.3
```

**Issue**: "FIPS self-test failed"
```bash
# Run FIPS tests manually
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips \
    /usr/local/bin/fips-startup-check
```

**Issue**: "Diagnostic tests fail"
```bash
# Check if dotnet-script is available
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips dotnet-script --version

# Check environment variables
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips env | grep OPENSSL
```

### Validation Issues

**Issue**: Backend verification tests fail
```bash
# Check if NuGet packages are cached
docker run --rm cr.root.io/aspnet:8.0.25-bookworm-slim-fips \
    ls -la /.cache/dotnet-script/

# Rebuild with --no-cache to refresh packages
./build.sh --no-cache
```

---

## Support

For issues and questions:
- Review diagnostics output: `/app/diagnostic.sh`
- Check logs: `docker logs <container-id>`
- See **ARCHITECTURE.md** for detailed technical information
- Review diagnostic suite documentation in `diagnostics/README.md`

---

## License

- wolfSSL FIPS 5.8.2 - Commercial license required
- wolfProvider v1.1.0 - GPLv3 / Commercial license
- ASP.NET Core 8.0.25 - MIT License
- Container implementation - As per your organization's license

---

## References

- [wolfSSL FIPS 140-3](https://www.wolfssl.com/license/fips/)
- [wolfProvider GitHub](https://github.com/wolfSSL/wolfProvider)
- [ASP.NET Core Documentation](https://learn.microsoft.com/en-us/aspnet/core/)
- [.NET Cryptography](https://learn.microsoft.com/en-us/dotnet/standard/security/cryptography-model)
- [OpenSSL Providers](https://www.openssl.org/docs/man3.0/man7/provider.html)
- [FIPS 140-3 Implementation Guidance](https://csrc.nist.gov/publications/detail/fips/140/3/final)
- [FIPS 140-3 Certificate #4718](https://csrc.nist.gov/projects/cryptographic-module-validation-program/certificate/4718)

---

**Document Version:** 1.0
**Last Updated:** 2026-04-22
**Image:** cr.root.io/aspnet:8.0.25-bookworm-slim-fips
