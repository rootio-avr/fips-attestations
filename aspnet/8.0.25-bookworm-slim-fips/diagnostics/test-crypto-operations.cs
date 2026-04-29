#!/usr/bin/env dotnet script
/*
 * ASP.NET FIPS Crypto Operations Tests
 *
 * Comprehensive tests for all .NET cryptographic operations with FIPS compliance
 * Tests the complete crypto stack: .NET → OpenSSL 3.3.7 → wolfProvider → wolfSSL FIPS v5
 *
 * Usage: dotnet script test-crypto-operations.cs
 */

#r "nuget: System.Text.Json, 8.0.0"

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

// Test result classes
public class TestResult
{
    [JsonPropertyName("id")]
    public string Id { get; set; }

    [JsonPropertyName("name")]
    public string Name { get; set; }

    [JsonPropertyName("status")]
    public string Status { get; set; }

    [JsonPropertyName("duration_ms")]
    public long DurationMs { get; set; }

    [JsonPropertyName("details")]
    public string Details { get; set; }
}

public class TestSuiteResults
{
    [JsonPropertyName("test_area")]
    public string TestArea { get; set; } = "3-crypto-operations";

    [JsonPropertyName("timestamp")]
    public string Timestamp { get; set; } = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ");

    [JsonPropertyName("container")]
    public string Container { get; set; } = "cr.root.io/aspnet:8.0.25-bookworm-slim-fips";

    [JsonPropertyName("total_tests")]
    public int TotalTests { get; set; } = 20;

    [JsonPropertyName("passed")]
    public int Passed { get; set; }

    [JsonPropertyName("failed")]
    public int Failed { get; set; }

    [JsonPropertyName("skipped")]
    public int Skipped { get; set; }

    [JsonPropertyName("tests")]
    public List<TestResult> Tests { get; set; } = new List<TestResult>();
}

var results = new TestSuiteResults();

Console.WriteLine();
Console.WriteLine("================================================================================");
Console.WriteLine("  ASP.NET FIPS Cryptographic Operations Tests");
Console.WriteLine("  Testing FIPS-Compliant Crypto via .NET → OpenSSL → wolfSSL");
Console.WriteLine("================================================================================");
Console.WriteLine();

// Helper methods
void LogTest(string id, string name, string status, string details = "", long durationMs = 0)
{
    var result = new TestResult
    {
        Id = id,
        Name = name,
        Status = status,
        DurationMs = durationMs,
        Details = details
    };
    results.Tests.Add(result);

    var emoji = status == "pass" ? "✅" : status == "fail" ? "❌" : "⏭️";
    Console.WriteLine($"{emoji} {id} {name}: {status.ToUpper()}");
    if (!string.IsNullOrEmpty(details))
        Console.WriteLine($"   Details: {details}");
    Console.WriteLine();

    if (status == "pass") results.Passed++;
    else if (status == "fail") results.Failed++;
    else results.Skipped++;
}

// Test 3.1: SHA-256 Hashing
try
{
    var sw = Stopwatch.StartNew();
    using var sha256 = SHA256.Create();
    var testData = Encoding.UTF8.GetBytes("FIPS 140-3 Test Data");
    var hash = sha256.ComputeHash(testData);
    sw.Stop();

    if (hash.Length == 32)
    {
        var hashHex = BitConverter.ToString(hash).Replace("-", "").ToLower();
        LogTest("3.1", "SHA-256 Hashing", "pass",
            $"Hash computed: {hashHex.Substring(0, 16)}... (32 bytes)", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("3.1", "SHA-256 Hashing", "fail", $"Unexpected hash length: {hash.Length}");
    }
}
catch (Exception ex)
{
    LogTest("3.1", "SHA-256 Hashing", "fail", $"Exception: {ex.Message}");
}

// Test 3.2: SHA-384 Hashing
try
{
    var sw = Stopwatch.StartNew();
    using var sha384 = SHA384.Create();
    var testData = Encoding.UTF8.GetBytes("FIPS 140-3 Test Data");
    var hash = sha384.ComputeHash(testData);
    sw.Stop();

    if (hash.Length == 48)
    {
        var hashHex = BitConverter.ToString(hash).Replace("-", "").ToLower();
        LogTest("3.2", "SHA-384 Hashing", "pass",
            $"Hash computed: {hashHex.Substring(0, 16)}... (48 bytes)", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("3.2", "SHA-384 Hashing", "fail", $"Unexpected hash length: {hash.Length}");
    }
}
catch (Exception ex)
{
    LogTest("3.2", "SHA-384 Hashing", "fail", $"Exception: {ex.Message}");
}

// Test 3.3: SHA-512 Hashing
try
{
    var sw = Stopwatch.StartNew();
    using var sha512 = SHA512.Create();
    var testData = Encoding.UTF8.GetBytes("FIPS 140-3 Test Data");
    var hash = sha512.ComputeHash(testData);
    sw.Stop();

    if (hash.Length == 64)
    {
        var hashHex = BitConverter.ToString(hash).Replace("-", "").ToLower();
        LogTest("3.3", "SHA-512 Hashing", "pass",
            $"Hash computed: {hashHex.Substring(0, 16)}... (64 bytes)", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("3.3", "SHA-512 Hashing", "fail", $"Unexpected hash length: {hash.Length}");
    }
}
catch (Exception ex)
{
    LogTest("3.3", "SHA-512 Hashing", "fail", $"Exception: {ex.Message}");
}

// Test 3.4: AES-128-GCM Encryption
try
{
    var sw = Stopwatch.StartNew();
    using var aes = new AesGcm(new byte[16]); // 128-bit key
    var plaintext = Encoding.UTF8.GetBytes("FIPS Test Message");
    var nonce = new byte[AesGcm.NonceByteSizes.MaxSize];
    var ciphertext = new byte[plaintext.Length];
    var tag = new byte[AesGcm.TagByteSizes.MaxSize];

    RandomNumberGenerator.Fill(nonce);
    aes.Encrypt(nonce, plaintext, ciphertext, tag);
    sw.Stop();

    LogTest("3.4", "AES-128-GCM Encryption", "pass",
        $"Encrypted {plaintext.Length} bytes, tag: {tag.Length} bytes", sw.ElapsedMilliseconds);
}
catch (Exception ex)
{
    LogTest("3.4", "AES-128-GCM Encryption", "fail", $"Exception: {ex.Message}");
}

// Test 3.5: AES-256-GCM Encryption/Decryption
try
{
    var sw = Stopwatch.StartNew();
    var key = new byte[32]; // 256-bit key
    RandomNumberGenerator.Fill(key);

    using var aes = new AesGcm(key);
    var plaintext = Encoding.UTF8.GetBytes("FIPS 140-3 Test Message for AES-256-GCM");
    var nonce = new byte[AesGcm.NonceByteSizes.MaxSize];
    var ciphertext = new byte[plaintext.Length];
    var tag = new byte[AesGcm.TagByteSizes.MaxSize];

    RandomNumberGenerator.Fill(nonce);
    aes.Encrypt(nonce, plaintext, ciphertext, tag);

    // Decrypt
    var decrypted = new byte[plaintext.Length];
    aes.Decrypt(nonce, ciphertext, tag, decrypted);
    sw.Stop();

    if (plaintext.SequenceEqual(decrypted))
    {
        LogTest("3.5", "AES-256-GCM Encrypt/Decrypt", "pass",
            $"Encrypted and decrypted {plaintext.Length} bytes successfully", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("3.5", "AES-256-GCM Encrypt/Decrypt", "fail", "Decrypted data does not match plaintext");
    }
}
catch (Exception ex)
{
    LogTest("3.5", "AES-256-GCM Encrypt/Decrypt", "fail", $"Exception: {ex.Message}");
}

// Test 3.6: AES-CBC Encryption/Decryption
try
{
    var sw = Stopwatch.StartNew();
    using var aes = Aes.Create();
    aes.KeySize = 256;
    aes.Mode = CipherMode.CBC;
    aes.Padding = PaddingMode.PKCS7;
    aes.GenerateKey();
    aes.GenerateIV();

    var plaintext = Encoding.UTF8.GetBytes("FIPS 140-3 Test Message for AES-CBC");

    // Encrypt
    byte[] ciphertext;
    using (var encryptor = aes.CreateEncryptor())
    using (var ms = new MemoryStream())
    using (var cs = new CryptoStream(ms, encryptor, CryptoStreamMode.Write))
    {
        cs.Write(plaintext, 0, plaintext.Length);
        cs.FlushFinalBlock();
        ciphertext = ms.ToArray();
    }

    // Decrypt
    byte[] decrypted;
    using (var decryptor = aes.CreateDecryptor())
    using (var ms = new MemoryStream(ciphertext))
    using (var cs = new CryptoStream(ms, decryptor, CryptoStreamMode.Read))
    using (var resultStream = new MemoryStream())
    {
        cs.CopyTo(resultStream);
        decrypted = resultStream.ToArray();
    }
    sw.Stop();

    if (plaintext.SequenceEqual(decrypted))
    {
        LogTest("3.6", "AES-256-CBC Encrypt/Decrypt", "pass",
            $"Encrypted and decrypted {plaintext.Length} bytes successfully", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("3.6", "AES-256-CBC Encrypt/Decrypt", "fail", "Decrypted data does not match plaintext");
    }
}
catch (Exception ex)
{
    LogTest("3.6", "AES-256-CBC Encrypt/Decrypt", "fail", $"Exception: {ex.Message}");
}

// Test 3.7: RSA-2048 Key Generation
try
{
    var sw = Stopwatch.StartNew();
    using var rsa = RSA.Create(2048);
    var publicKey = rsa.ExportRSAPublicKey();
    sw.Stop();

    if (publicKey.Length > 0)
    {
        LogTest("3.7", "RSA-2048 Key Generation", "pass",
            $"Generated 2048-bit RSA key pair, public key: {publicKey.Length} bytes", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("3.7", "RSA-2048 Key Generation", "fail", "Public key export failed");
    }
}
catch (Exception ex)
{
    LogTest("3.7", "RSA-2048 Key Generation", "fail", $"Exception: {ex.Message}");
}

// Test 3.8: RSA-2048 Encryption/Decryption
try
{
    var sw = Stopwatch.StartNew();
    using var rsa = RSA.Create(2048);
    var plaintext = Encoding.UTF8.GetBytes("FIPS Test Data");

    // Encrypt
    var ciphertext = rsa.Encrypt(plaintext, RSAEncryptionPadding.OaepSHA256);

    // Decrypt
    var decrypted = rsa.Decrypt(ciphertext, RSAEncryptionPadding.OaepSHA256);
    sw.Stop();

    if (plaintext.SequenceEqual(decrypted))
    {
        LogTest("3.8", "RSA-2048 Encrypt/Decrypt", "pass",
            $"Encrypted and decrypted {plaintext.Length} bytes with OAEP-SHA256", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("3.8", "RSA-2048 Encrypt/Decrypt", "fail", "Decrypted data does not match plaintext");
    }
}
catch (Exception ex)
{
    LogTest("3.8", "RSA-2048 Encrypt/Decrypt", "fail", $"Exception: {ex.Message}");
}

// Test 3.9: RSA-2048 Digital Signature
try
{
    var sw = Stopwatch.StartNew();
    using var rsa = RSA.Create(2048);
    var data = Encoding.UTF8.GetBytes("FIPS Test Document");

    // Sign
    var signature = rsa.SignData(data, HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1);

    // Verify
    var verified = rsa.VerifyData(data, signature, HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1);
    sw.Stop();

    if (verified)
    {
        LogTest("3.9", "RSA-2048 Digital Signature", "pass",
            $"Signed and verified {data.Length} bytes, signature: {signature.Length} bytes", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("3.9", "RSA-2048 Digital Signature", "fail", "Signature verification failed");
    }
}
catch (Exception ex)
{
    LogTest("3.9", "RSA-2048 Digital Signature", "fail", $"Exception: {ex.Message}");
}

// Test 3.10: ECDSA P-256 Key Generation
try
{
    var sw = Stopwatch.StartNew();
    using var ecdsa = ECDsa.Create(ECCurve.NamedCurves.nistP256);
    var publicKey = ecdsa.ExportSubjectPublicKeyInfo();
    sw.Stop();

    if (publicKey.Length > 0)
    {
        LogTest("3.10", "ECDSA P-256 Key Generation", "pass",
            $"Generated P-256 EC key pair, public key: {publicKey.Length} bytes", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("3.10", "ECDSA P-256 Key Generation", "fail", "Public key export failed");
    }
}
catch (Exception ex)
{
    LogTest("3.10", "ECDSA P-256 Key Generation", "fail", $"Exception: {ex.Message}");
}

// Test 3.11: ECDSA P-256 Digital Signature
try
{
    var sw = Stopwatch.StartNew();
    using var ecdsa = ECDsa.Create(ECCurve.NamedCurves.nistP256);
    var data = Encoding.UTF8.GetBytes("FIPS Test Document for ECDSA");

    // Sign
    var signature = ecdsa.SignData(data, HashAlgorithmName.SHA256);

    // Verify
    var verified = ecdsa.VerifyData(data, signature, HashAlgorithmName.SHA256);
    sw.Stop();

    if (verified)
    {
        LogTest("3.11", "ECDSA P-256 Sign/Verify", "pass",
            $"Signed and verified {data.Length} bytes with P-256", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("3.11", "ECDSA P-256 Sign/Verify", "fail", "Signature verification failed");
    }
}
catch (Exception ex)
{
    LogTest("3.11", "ECDSA P-256 Sign/Verify", "fail", $"Exception: {ex.Message}");
}

// Test 3.12: ECDSA P-384 Digital Signature
try
{
    var sw = Stopwatch.StartNew();
    using var ecdsa = ECDsa.Create(ECCurve.NamedCurves.nistP384);
    var data = Encoding.UTF8.GetBytes("FIPS Test Document for ECDSA P-384");

    // Sign
    var signature = ecdsa.SignData(data, HashAlgorithmName.SHA384);

    // Verify
    var verified = ecdsa.VerifyData(data, signature, HashAlgorithmName.SHA384);
    sw.Stop();

    if (verified)
    {
        LogTest("3.12", "ECDSA P-384 Sign/Verify", "pass",
            $"Signed and verified {data.Length} bytes with P-384", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("3.12", "ECDSA P-384 Sign/Verify", "fail", "Signature verification failed");
    }
}
catch (Exception ex)
{
    LogTest("3.12", "ECDSA P-384 Sign/Verify", "fail", $"Exception: {ex.Message}");
}

// Test 3.13: HMAC-SHA256
try
{
    var sw = Stopwatch.StartNew();
    var key = new byte[32];
    RandomNumberGenerator.Fill(key);

    using var hmac = new HMACSHA256(key);
    var data = Encoding.UTF8.GetBytes("FIPS Test Message for HMAC");
    var mac = hmac.ComputeHash(data);
    sw.Stop();

    if (mac.Length == 32)
    {
        var macHex = BitConverter.ToString(mac).Replace("-", "").ToLower();
        LogTest("3.13", "HMAC-SHA256", "pass",
            $"Computed HMAC: {macHex.Substring(0, 16)}... (32 bytes)", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("3.13", "HMAC-SHA256", "fail", $"Unexpected MAC length: {mac.Length}");
    }
}
catch (Exception ex)
{
    LogTest("3.13", "HMAC-SHA256", "fail", $"Exception: {ex.Message}");
}

// Test 3.14: HMAC-SHA512
try
{
    var sw = Stopwatch.StartNew();
    var key = new byte[64];
    RandomNumberGenerator.Fill(key);

    using var hmac = new HMACSHA512(key);
    var data = Encoding.UTF8.GetBytes("FIPS Test Message for HMAC-SHA512");
    var mac = hmac.ComputeHash(data);
    sw.Stop();

    if (mac.Length == 64)
    {
        var macHex = BitConverter.ToString(mac).Replace("-", "").ToLower();
        LogTest("3.14", "HMAC-SHA512", "pass",
            $"Computed HMAC: {macHex.Substring(0, 16)}... (64 bytes)", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("3.14", "HMAC-SHA512", "fail", $"Unexpected MAC length: {mac.Length}");
    }
}
catch (Exception ex)
{
    LogTest("3.14", "HMAC-SHA512", "fail", $"Exception: {ex.Message}");
}

// Test 3.15: PBKDF2 Key Derivation
try
{
    var sw = Stopwatch.StartNew();
    var password = "FIPSTestPassword123!";
    var salt = new byte[16];
    RandomNumberGenerator.Fill(salt);

    using var pbkdf2 = new Rfc2898DeriveBytes(password, salt, 100000, HashAlgorithmName.SHA256);
    var derivedKey = pbkdf2.GetBytes(32);
    sw.Stop();

    if (derivedKey.Length == 32)
    {
        var keyHex = BitConverter.ToString(derivedKey).Replace("-", "").ToLower();
        LogTest("3.15", "PBKDF2-SHA256 Key Derivation", "pass",
            $"Derived 256-bit key: {keyHex.Substring(0, 16)}...", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("3.15", "PBKDF2-SHA256 Key Derivation", "fail", $"Unexpected key length: {derivedKey.Length}");
    }
}
catch (Exception ex)
{
    LogTest("3.15", "PBKDF2-SHA256 Key Derivation", "fail", $"Exception: {ex.Message}");
}

// Test 3.16: Random Number Generation
try
{
    var sw = Stopwatch.StartNew();
    var random1 = new byte[32];
    var random2 = new byte[32];

    RandomNumberGenerator.Fill(random1);
    RandomNumberGenerator.Fill(random2);
    sw.Stop();

    if (!random1.SequenceEqual(random2))
    {
        var hex1 = BitConverter.ToString(random1).Replace("-", "").ToLower();
        LogTest("3.16", "Random Number Generation", "pass",
            $"Generated 32 random bytes: {hex1.Substring(0, 16)}...", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("3.16", "Random Number Generation", "fail", "Generated identical random values (highly improbable)");
    }
}
catch (Exception ex)
{
    LogTest("3.16", "Random Number Generation", "fail", $"Exception: {ex.Message}");
}

// Test 3.17: ECDH Key Exchange (P-256)
try
{
    var sw = Stopwatch.StartNew();
    using var alice = ECDiffieHellman.Create(ECCurve.NamedCurves.nistP256);
    using var bob = ECDiffieHellman.Create(ECCurve.NamedCurves.nistP256);

    var alicePublic = alice.PublicKey;
    var bobPublic = bob.PublicKey;

    var aliceShared = alice.DeriveKeyMaterial(bobPublic);
    var bobShared = bob.DeriveKeyMaterial(alicePublic);
    sw.Stop();

    if (aliceShared.SequenceEqual(bobShared))
    {
        var sharedHex = BitConverter.ToString(aliceShared).Replace("-", "").ToLower();
        LogTest("3.17", "ECDH P-256 Key Exchange", "pass",
            $"Derived shared secret: {sharedHex.Substring(0, 16)}... ({aliceShared.Length} bytes)", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("3.17", "ECDH P-256 Key Exchange", "fail", "Shared secrets do not match");
    }
}
catch (Exception ex)
{
    LogTest("3.17", "ECDH P-256 Key Exchange", "fail", $"Exception: {ex.Message}");
}

// Test 3.18: ECDH Key Exchange (P-384)
try
{
    var sw = Stopwatch.StartNew();
    using var alice = ECDiffieHellman.Create(ECCurve.NamedCurves.nistP384);
    using var bob = ECDiffieHellman.Create(ECCurve.NamedCurves.nistP384);

    var alicePublic = alice.PublicKey;
    var bobPublic = bob.PublicKey;

    var aliceShared = alice.DeriveKeyMaterial(bobPublic);
    var bobShared = bob.DeriveKeyMaterial(alicePublic);
    sw.Stop();

    if (aliceShared.SequenceEqual(bobShared))
    {
        var sharedHex = BitConverter.ToString(aliceShared).Replace("-", "").ToLower();
        LogTest("3.18", "ECDH P-384 Key Exchange", "pass",
            $"Derived shared secret: {sharedHex.Substring(0, 16)}... ({aliceShared.Length} bytes)", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("3.18", "ECDH P-384 Key Exchange", "fail", "Shared secrets do not match");
    }
}
catch (Exception ex)
{
    LogTest("3.18", "ECDH P-384 Key Exchange", "fail", $"Exception: {ex.Message}");
}

// Test 3.19: RSA-PSS Signature
try
{
    var sw = Stopwatch.StartNew();
    using var rsa = RSA.Create(2048);
    var data = Encoding.UTF8.GetBytes("FIPS Test Document for RSA-PSS");

    // Sign with PSS padding
    var signature = rsa.SignData(data, HashAlgorithmName.SHA256, RSASignaturePadding.Pss);

    // Verify
    var verified = rsa.VerifyData(data, signature, HashAlgorithmName.SHA256, RSASignaturePadding.Pss);
    sw.Stop();

    if (verified)
    {
        LogTest("3.19", "RSA-PSS Signature", "pass",
            $"Signed and verified {data.Length} bytes with PSS padding", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("3.19", "RSA-PSS Signature", "fail", "Signature verification failed");
    }
}
catch (Exception ex)
{
    LogTest("3.19", "RSA-PSS Signature", "fail", $"Exception: {ex.Message}");
}

// Test 3.20: Multiple Algorithm Chaining
try
{
    var sw = Stopwatch.StartNew();

    // 1. Generate random password
    var password = new byte[16];
    RandomNumberGenerator.Fill(password);
    var passwordStr = Convert.ToBase64String(password);

    // 2. Derive key with PBKDF2
    var salt = new byte[16];
    RandomNumberGenerator.Fill(salt);
    using var pbkdf2 = new Rfc2898DeriveBytes(passwordStr, salt, 10000, HashAlgorithmName.SHA256);
    var key = pbkdf2.GetBytes(32);

    // 3. Encrypt data with AES-GCM
    using var aes = new AesGcm(key);
    var plaintext = Encoding.UTF8.GetBytes("FIPS Test: Chained Operations");
    var nonce = new byte[AesGcm.NonceByteSizes.MaxSize];
    var ciphertext = new byte[plaintext.Length];
    var tag = new byte[AesGcm.TagByteSizes.MaxSize];
    RandomNumberGenerator.Fill(nonce);
    aes.Encrypt(nonce, plaintext, ciphertext, tag);

    // 4. Compute HMAC of ciphertext
    using var hmac = new HMACSHA256(key);
    var mac = hmac.ComputeHash(ciphertext);

    sw.Stop();

    LogTest("3.20", "Multi-Algorithm Chain Test", "pass",
        $"Successfully chained: RNG → PBKDF2 → AES-GCM → HMAC-SHA256 ({sw.ElapsedMilliseconds}ms)", sw.ElapsedMilliseconds);
}
catch (Exception ex)
{
    LogTest("3.20", "Multi-Algorithm Chain Test", "fail", $"Exception: {ex.Message}");
}

// Print Summary
Console.WriteLine("================================================================================");
Console.WriteLine($"  Cryptographic Operations Test Summary");
Console.WriteLine("================================================================================");
Console.WriteLine($"Total Tests:  {results.TotalTests}");
Console.WriteLine($"Passed:       {results.Passed} ✅");
Console.WriteLine($"Failed:       {results.Failed} ❌");
Console.WriteLine($"Skipped:      {results.Skipped} ⏭️");
Console.WriteLine("================================================================================");
Console.WriteLine();

// Save JSON results
var jsonOptions = new JsonSerializerOptions { WriteIndented = true };
var json = JsonSerializer.Serialize(results, jsonOptions);
var resultsPath = Path.Combine(Environment.CurrentDirectory, "crypto-operations-results.json");
File.WriteAllText(resultsPath, json);
Console.WriteLine($"Results saved to: {resultsPath}");
Console.WriteLine();

// Exit with appropriate code
Environment.Exit(results.Failed == 0 ? 0 : 1);
