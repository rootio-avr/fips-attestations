#!/usr/bin/env dotnet-script
/**
 * Cryptographic Operations Test Suite
 *
 * Tests FIPS-approved cryptographic operations using standard .NET APIs
 */

using System;
using System.Security.Cryptography;
using System.Text;

public class CryptoTestSuite
{
    private int totalTests = 0;
    private int passedTests = 0;
    private int failedTests = 0;

    public void PrintHeader()
    {
        Console.WriteLine();
        Console.WriteLine(new string('=', 80));
        Console.WriteLine("  Cryptographic Operations Test Suite");
        Console.WriteLine("  Testing FIPS-Compliant Crypto via .NET → OpenSSL → wolfSSL");
        Console.WriteLine(new string('=', 80));
        Console.WriteLine();
    }

    public void RunTest(string testName, Action testFunc)
    {
        totalTests++;
        Console.Write($"[{totalTests}] {testName}... ");
        try
        {
            testFunc();
            passedTests++;
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("✓ PASS");
            Console.ResetColor();
        }
        catch (Exception ex)
        {
            failedTests++;
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine($"✗ FAIL: {ex.Message}");
            Console.ResetColor();
        }
    }

    public void TestSHA256()
    {
        var data = Encoding.UTF8.GetBytes("FIPS test data");
        var hash = SHA256.HashData(data);
        if (hash.Length != 32)
            throw new Exception($"Expected 32 bytes, got {hash.Length}");
    }

    public void TestSHA384()
    {
        var data = Encoding.UTF8.GetBytes("FIPS test data");
        var hash = SHA384.HashData(data);
        if (hash.Length != 48)
            throw new Exception($"Expected 48 bytes, got {hash.Length}");
    }

    public void TestSHA512()
    {
        var data = Encoding.UTF8.GetBytes("FIPS test data");
        var hash = SHA512.HashData(data);
        if (hash.Length != 64)
            throw new Exception($"Expected 64 bytes, got {hash.Length}");
    }

    public void TestAES256GCM()
    {
        var key = RandomNumberGenerator.GetBytes(32);
        var nonce = RandomNumberGenerator.GetBytes(12);
        var plaintext = Encoding.UTF8.GetBytes("Hello, FIPS!");
        var ciphertext = new byte[plaintext.Length];
        var tag = new byte[16];

        using (var aes = new AesGcm(key))
        {
            aes.Encrypt(nonce, plaintext, ciphertext, tag);

            var decrypted = new byte[ciphertext.Length];
            aes.Decrypt(nonce, ciphertext, tag, decrypted);

            var decryptedText = Encoding.UTF8.GetString(decrypted);
            if (decryptedText != "Hello, FIPS!")
                throw new Exception($"Decryption failed: {decryptedText}");
        }
    }

    public void TestAES256CBC()
    {
        using (var aes = Aes.Create())
        {
            aes.KeySize = 256;
            aes.Mode = CipherMode.CBC;
            aes.Padding = PaddingMode.PKCS7;
            aes.GenerateKey();
            aes.GenerateIV();

            var plaintext = Encoding.UTF8.GetBytes("FIPS CBC encryption test");

            byte[] ciphertext;
            using (var encryptor = aes.CreateEncryptor())
            using (var ms = new System.IO.MemoryStream())
            using (var cs = new CryptoStream(ms, encryptor, CryptoStreamMode.Write))
            {
                cs.Write(plaintext, 0, plaintext.Length);
                cs.FlushFinalBlock();
                ciphertext = ms.ToArray();
            }

            byte[] decrypted;
            using (var decryptor = aes.CreateDecryptor())
            using (var ms = new System.IO.MemoryStream(ciphertext))
            using (var cs = new CryptoStream(ms, decryptor, CryptoStreamMode.Read))
            using (var reader = new System.IO.StreamReader(cs))
            {
                decrypted = Encoding.UTF8.GetBytes(reader.ReadToEnd());
            }

            if (!plaintext.SequenceEqual(decrypted))
                throw new Exception("CBC decryption failed");
        }
    }

    public void TestHMACSHA256()
    {
        var key = RandomNumberGenerator.GetBytes(32);
        var data = Encoding.UTF8.GetBytes("Message to authenticate");

        using (var hmac = new HMACSHA256(key))
        {
            var hash = hmac.ComputeHash(data);
            if (hash.Length != 32)
                throw new Exception($"Expected 32 bytes, got {hash.Length}");
        }
    }

    public void TestRandomNumberGeneration()
    {
        var random1 = RandomNumberGenerator.GetBytes(32);
        var random2 = RandomNumberGenerator.GetBytes(32);

        if (random1.Length != 32 || random2.Length != 32)
            throw new Exception("Random generation failed");

        if (random1.SequenceEqual(random2))
            throw new Exception("Random numbers are identical (very unlikely!)");
    }

    public void TestRSA2048()
    {
        using (var rsa = RSA.Create(2048))
        {
            var data = Encoding.UTF8.GetBytes("Document to sign");

            // Sign
            var signature = rsa.SignData(data, HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1);

            // Verify
            bool isValid = rsa.VerifyData(data, signature, HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1);

            if (!isValid)
                throw new Exception("RSA signature verification failed");
        }
    }

    public void TestECDSA()
    {
        using (var ecdsa = ECDsa.Create(ECCurve.NamedCurves.nistP256))
        {
            var data = Encoding.UTF8.GetBytes("Data to sign with ECDSA");

            // Sign
            var signature = ecdsa.SignData(data, HashAlgorithmName.SHA256);

            // Verify
            bool isValid = ecdsa.VerifyData(data, signature, HashAlgorithmName.SHA256);

            if (!isValid)
                throw new Exception("ECDSA signature verification failed");
        }
    }

    public void TestPBKDF2()
    {
        var password = "SecurePassword123";
        var salt = RandomNumberGenerator.GetBytes(16);

        using (var pbkdf2 = new Rfc2898DeriveBytes(password, salt, 10000, HashAlgorithmName.SHA256))
        {
            var key = pbkdf2.GetBytes(32);

            if (key.Length != 32)
                throw new Exception($"Expected 32 bytes, got {key.Length}");
        }
    }

    public void PrintSummary()
    {
        Console.WriteLine();
        Console.WriteLine(new string('=', 80));
        Console.WriteLine("  Test Summary");
        Console.WriteLine(new string('=', 80));
        Console.WriteLine($"  Total Tests:  {totalTests}");

        Console.ForegroundColor = ConsoleColor.Green;
        Console.WriteLine($"  Passed:       {passedTests} ✓");
        Console.ResetColor();

        if (failedTests > 0)
        {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine($"  Failed:       {failedTests} ✗");
            Console.ResetColor();
        }
        else
        {
            Console.WriteLine($"  Failed:       {failedTests}");
        }

        Console.WriteLine(new string('=', 80));
        Console.WriteLine();

        if (failedTests == 0)
        {
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("✓ All cryptographic tests passed - FIPS crypto is working correctly");
            Console.ResetColor();
        }
        else
        {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine("✗ Some cryptographic tests failed");
            Console.ResetColor();
        }
        Console.WriteLine();
    }

    public int Run()
    {
        PrintHeader();

        RunTest("SHA-256 Hashing", TestSHA256);
        RunTest("SHA-384 Hashing", TestSHA384);
        RunTest("SHA-512 Hashing", TestSHA512);
        RunTest("AES-256-GCM Encryption/Decryption", TestAES256GCM);
        RunTest("AES-256-CBC Encryption/Decryption", TestAES256CBC);
        RunTest("HMAC-SHA256", TestHMACSHA256);
        RunTest("Random Number Generation", TestRandomNumberGeneration);
        RunTest("RSA-2048 Sign/Verify", TestRSA2048);
        RunTest("ECDSA P-256 Sign/Verify", TestECDSA);
        RunTest("PBKDF2-SHA256 Key Derivation", TestPBKDF2);

        PrintSummary();

        return failedTests == 0 ? 0 : 1;
    }
}

// If run directly
if (Args.Count == 0 || Args[0] != "--import-only")
{
    var suite = new CryptoTestSuite();
    Environment.Exit(suite.Run());
}
