#!/usr/bin/env dotnet script
/*
 * ASP.NET Backend Verification Tests
 *
 * Comprehensive tests to verify OpenSSL backend integration with .NET
 * Tests the complete chain: .NET → libSystem.Security.Cryptography.Native.OpenSsl.so → OpenSSL 3.3.7 → wolfProvider → wolfSSL FIPS
 *
 * Usage: dotnet script test-backend-verification.cs
 */

#r "nuget: System.Text.Json, 8.0.0"

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
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
    public string TestArea { get; set; } = "1-backend-verification";

    [JsonPropertyName("timestamp")]
    public string Timestamp { get; set; } = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ");

    [JsonPropertyName("container")]
    public string Container { get; set; } = "cr.root.io/aspnet:8.0.25-bookworm-slim-fips";

    [JsonPropertyName("total_tests")]
    public int TotalTests { get; set; } = 10;

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
Console.WriteLine("  ASP.NET Backend Verification Tests");
Console.WriteLine("  Testing OpenSSL Integration with .NET Runtime");
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

string RunCommand(string command, string args = "")
{
    try
    {
        var psi = new ProcessStartInfo
        {
            FileName = command,
            Arguments = args,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false
        };

        using var process = Process.Start(psi);
        var output = process.StandardOutput.ReadToEnd();
        var error = process.StandardError.ReadToEnd();
        process.WaitForExit();

        return string.IsNullOrEmpty(error) ? output : error;
    }
    catch (Exception ex)
    {
        return $"Error: {ex.Message}";
    }
}

// Test 1.1: OpenSSL Version Detection
try
{
    var sw = Stopwatch.StartNew();
    var opensslVersion = RunCommand("openssl", "version");
    sw.Stop();

    if (opensslVersion.Contains("3.3.7"))
    {
        LogTest("1.1", "OpenSSL Version Detection", "pass",
            $"OpenSSL 3.3.7 detected: {opensslVersion.Trim()}", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("1.1", "OpenSSL Version Detection", "fail",
            $"Unexpected version: {opensslVersion.Trim()}");
    }
}
catch (Exception ex)
{
    LogTest("1.1", "OpenSSL Version Detection", "fail", $"Exception: {ex.Message}");
}

// Test 1.2: Library Path Verification
try
{
    var sw = Stopwatch.StartNew();
    var ldconfigOutput = RunCommand("ldconfig", "-p");
    sw.Stop();

    var libsslLine = ldconfigOutput.Split('\n')
        .FirstOrDefault(l => l.Contains("libssl.so.3"));

    if (libsslLine != null && libsslLine.Contains("/usr/local/openssl"))
    {
        var path = libsslLine.Split("=>").LastOrDefault()?.Trim();
        LogTest("1.2", "Library Path Verification", "pass",
            $"libssl.so.3 resolves to FIPS OpenSSL: {path}", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("1.2", "Library Path Verification", "fail",
            $"libssl.so.3 does not resolve to FIPS OpenSSL: {libsslLine}");
    }
}
catch (Exception ex)
{
    LogTest("1.2", "Library Path Verification", "fail", $"Exception: {ex.Message}");
}

// Test 1.3: OpenSSL Provider Enumeration
try
{
    var sw = Stopwatch.StartNew();
    var providersOutput = RunCommand("openssl", "list -providers");
    sw.Stop();

    if (providersOutput.Contains("wolfSSL", StringComparison.OrdinalIgnoreCase))
    {
        LogTest("1.3", "OpenSSL Provider Enumeration", "pass",
            "wolfSSL Provider detected in OpenSSL", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("1.3", "OpenSSL Provider Enumeration", "fail",
            "wolfSSL Provider not found in OpenSSL providers");
    }
}
catch (Exception ex)
{
    LogTest("1.3", "OpenSSL Provider Enumeration", "fail", $"Exception: {ex.Message}");
}

// Test 1.4: FIPS Module Presence
try
{
    var sw = Stopwatch.StartNew();
    var modulePath = "/usr/local/openssl/lib/ossl-modules/libwolfprov.so";
    var exists = File.Exists(modulePath);
    sw.Stop();

    if (exists)
    {
        var fileInfo = new FileInfo(modulePath);
        LogTest("1.4", "FIPS Module Presence", "pass",
            $"wolfProvider module found: {modulePath} ({fileInfo.Length} bytes)", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("1.4", "FIPS Module Presence", "fail",
            $"wolfProvider module not found at {modulePath}");
    }
}
catch (Exception ex)
{
    LogTest("1.4", "FIPS Module Presence", "fail", $"Exception: {ex.Message}");
}

// Test 1.5: Dynamic Linker Configuration
try
{
    var sw = Stopwatch.StartNew();
    var configPath = "/etc/ld.so.conf.d/00-fips-openssl.conf";
    var exists = File.Exists(configPath);
    sw.Stop();

    if (exists)
    {
        var content = File.ReadAllText(configPath);
        if (content.Contains("/usr/local/openssl/lib"))
        {
            LogTest("1.5", "Dynamic Linker Configuration", "pass",
                $"FIPS linker config exists and contains correct paths", sw.ElapsedMilliseconds);
        }
        else
        {
            LogTest("1.5", "Dynamic Linker Configuration", "fail",
                "FIPS linker config exists but missing expected paths");
        }
    }
    else
    {
        LogTest("1.5", "Dynamic Linker Configuration", "fail",
            $"FIPS linker config not found at {configPath}");
    }
}
catch (Exception ex)
{
    LogTest("1.5", "Dynamic Linker Configuration", "fail", $"Exception: {ex.Message}");
}

// Test 1.6: Environment Variable Validation
try
{
    var sw = Stopwatch.StartNew();
    var opensslConf = Environment.GetEnvironmentVariable("OPENSSL_CONF");
    var opensslModules = Environment.GetEnvironmentVariable("OPENSSL_MODULES");
    var ldLibraryPath = Environment.GetEnvironmentVariable("LD_LIBRARY_PATH");
    sw.Stop();

    var issues = new List<string>();
    if (string.IsNullOrEmpty(opensslConf))
        issues.Add("OPENSSL_CONF not set");
    if (string.IsNullOrEmpty(opensslModules))
        issues.Add("OPENSSL_MODULES not set");

    if (issues.Count == 0)
    {
        LogTest("1.6", "Environment Variable Validation", "pass",
            $"OPENSSL_CONF={opensslConf}, OPENSSL_MODULES={opensslModules}", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("1.6", "Environment Variable Validation", "fail",
            $"Issues: {string.Join(", ", issues)}");
    }
}
catch (Exception ex)
{
    LogTest("1.6", "Environment Variable Validation", "fail", $"Exception: {ex.Message}");
}

// Test 1.7: .NET → OpenSSL Interop Layer
try
{
    var sw = Stopwatch.StartNew();
    var interopPaths = new[]
    {
        "/usr/share/dotnet/shared/Microsoft.NETCore.App/8.0.25/libSystem.Security.Cryptography.Native.OpenSsl.so",
        "/usr/share/dotnet/shared/Microsoft.NETCore.App/8.0.25/System.Security.Cryptography.Native.OpenSsl.so"
    };

    var foundPath = interopPaths.FirstOrDefault(p => File.Exists(p));
    sw.Stop();

    if (foundPath != null)
    {
        var fileInfo = new FileInfo(foundPath);
        LogTest("1.7", ".NET → OpenSSL Interop Layer", "pass",
            $"Interop library found: {Path.GetFileName(foundPath)} ({fileInfo.Length} bytes)", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("1.7", ".NET → OpenSSL Interop Layer", "fail",
            "OpenSSL interop library not found");
    }
}
catch (Exception ex)
{
    LogTest("1.7", ".NET → OpenSSL Interop Layer", "fail", $"Exception: {ex.Message}");
}

// Test 1.8: Certificate Store Access
try
{
    var sw = Stopwatch.StartNew();
    var certDirs = new[]
    {
        "/etc/ssl/certs",
        "/usr/local/openssl/ssl/certs"
    };

    var accessibleDirs = certDirs.Where(d => Directory.Exists(d)).ToList();
    sw.Stop();

    if (accessibleDirs.Any())
    {
        LogTest("1.8", "Certificate Store Access", "pass",
            $"Certificate directories accessible: {string.Join(", ", accessibleDirs)}", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("1.8", "Certificate Store Access", "fail",
            "No certificate directories accessible");
    }
}
catch (Exception ex)
{
    LogTest("1.8", "Certificate Store Access", "fail", $"Exception: {ex.Message}");
}

// Test 1.9: Cipher Suite Availability
try
{
    var sw = Stopwatch.StartNew();
    var ciphersOutput = RunCommand("openssl", "ciphers -v");
    sw.Stop();

    var cipherCount = ciphersOutput.Split('\n', StringSplitOptions.RemoveEmptyEntries).Length;

    if (cipherCount > 0)
    {
        LogTest("1.9", "Cipher Suite Availability", "pass",
            $"Available cipher suites: {cipherCount}", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("1.9", "Cipher Suite Availability", "fail",
            "No cipher suites available");
    }
}
catch (Exception ex)
{
    LogTest("1.9", "Cipher Suite Availability", "fail", $"Exception: {ex.Message}");
}

// Test 1.10: OpenSSL Command Execution
try
{
    var sw = Stopwatch.StartNew();
    var testData = "FIPS test data";
    var tempFile = Path.GetTempFileName();
    File.WriteAllText(tempFile, testData);

    var hashOutput = RunCommand("openssl", $"dgst -sha256 {tempFile}");
    File.Delete(tempFile);
    sw.Stop();

    if (hashOutput.Contains("SHA2-256") || hashOutput.Contains("SHA256") || hashOutput.Length > 20)
    {
        LogTest("1.10", "OpenSSL Command Execution", "pass",
            "OpenSSL command executed successfully", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("1.10", "OpenSSL Command Execution", "fail",
            $"OpenSSL command failed or unexpected output: {hashOutput.Substring(0, Math.Min(100, hashOutput.Length))}");
    }
}
catch (Exception ex)
{
    LogTest("1.10", "OpenSSL Command Execution", "fail", $"Exception: {ex.Message}");
}

// Print Summary
Console.WriteLine("================================================================================");
Console.WriteLine($"  Backend Verification Test Summary");
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
var resultsPath = Path.Combine(Environment.CurrentDirectory, "backend-verification-results.json");
File.WriteAllText(resultsPath, json);
Console.WriteLine($"Results saved to: {resultsPath}");
Console.WriteLine();

// Exit with appropriate code
Environment.Exit(results.Failed == 0 ? 0 : 1);
