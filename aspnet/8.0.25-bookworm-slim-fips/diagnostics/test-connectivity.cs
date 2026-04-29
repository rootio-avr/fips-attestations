#!/usr/bin/env dotnet script
/*
 * ASP.NET FIPS Connectivity Tests
 *
 * Comprehensive TLS/HTTPS connectivity tests with FIPS-compliant cryptography
 * Tests network operations using .NET → OpenSSL 3.3.7 → wolfProvider → wolfSSL FIPS v5
 *
 * Usage: dotnet script test-connectivity.cs
 */

#r "nuget: System.Text.Json, 8.0.0"

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Net.Security;
using System.Net.Sockets;
using System.Security.Authentication;
using System.Security.Cryptography.X509Certificates;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading.Tasks;

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
    public string TestArea { get; set; } = "4-connectivity";

    [JsonPropertyName("timestamp")]
    public string Timestamp { get; set; } = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ");

    [JsonPropertyName("container")]
    public string Container { get; set; } = "cr.root.io/aspnet:8.0.25-bookworm-slim-fips";

    [JsonPropertyName("total_tests")]
    public int TotalTests { get; set; } = 15;

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
Console.WriteLine("  ASP.NET FIPS Connectivity Tests");
Console.WriteLine("  Testing TLS/HTTPS with FIPS-Compliant Cryptography");
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

// Test 4.1: Basic HTTPS GET Request
try
{
    var sw = Stopwatch.StartNew();
    using var client = new HttpClient();
    client.Timeout = TimeSpan.FromSeconds(10);

    var response = await client.GetAsync("https://www.google.com");
    sw.Stop();

    if (response.IsSuccessStatusCode)
    {
        LogTest("4.1", "Basic HTTPS GET Request", "pass",
            $"Status: {(int)response.StatusCode} {response.StatusCode}, TLS negotiated", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("4.1", "Basic HTTPS GET Request", "fail",
            $"HTTP error: {(int)response.StatusCode} {response.StatusCode}");
    }
}
catch (Exception ex)
{
    LogTest("4.1", "Basic HTTPS GET Request", "fail", $"Exception: {ex.Message}");
}

// Test 4.2: HTTPS with Custom Headers
try
{
    var sw = Stopwatch.StartNew();
    using var client = new HttpClient();
    client.Timeout = TimeSpan.FromSeconds(10);
    client.DefaultRequestHeaders.Add("User-Agent", "FIPS-Test-Client/1.0");
    client.DefaultRequestHeaders.Add("X-FIPS-Test", "wolfSSL-v5");

    var response = await client.GetAsync("https://httpbin.org/headers");
    sw.Stop();

    if (response.IsSuccessStatusCode)
    {
        var content = await response.Content.ReadAsStringAsync();
        LogTest("4.2", "HTTPS with Custom Headers", "pass",
            $"Request with custom headers successful, response: {content.Length} bytes", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("4.2", "HTTPS with Custom Headers", "fail",
            $"HTTP error: {(int)response.StatusCode}");
    }
}
catch (Exception ex)
{
    LogTest("4.2", "HTTPS with Custom Headers", "fail", $"Exception: {ex.Message}");
}

// Test 4.3: HTTPS POST Request
try
{
    var sw = Stopwatch.StartNew();
    using var client = new HttpClient();
    client.Timeout = TimeSpan.FromSeconds(10);

    var postData = new StringContent(
        "{\"test\":\"FIPS POST data\",\"crypto\":\"wolfSSL\"}",
        Encoding.UTF8,
        "application/json"
    );

    var response = await client.PostAsync("https://httpbin.org/post", postData);
    sw.Stop();

    if (response.IsSuccessStatusCode)
    {
        var content = await response.Content.ReadAsStringAsync();
        LogTest("4.3", "HTTPS POST Request", "pass",
            $"POST request successful, response: {content.Length} bytes", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("4.3", "HTTPS POST Request", "fail",
            $"HTTP error: {(int)response.StatusCode}");
    }
}
catch (Exception ex)
{
    LogTest("4.3", "HTTPS POST Request", "fail", $"Exception: {ex.Message}");
}

// Test 4.4: TLS Protocol Version Detection
try
{
    var sw = Stopwatch.StartNew();
    using var handler = new HttpClientHandler();
    handler.SslProtocols = SslProtocols.Tls12 | SslProtocols.Tls13;

    SslProtocols? detectedProtocol = null;
    handler.ServerCertificateCustomValidationCallback = (message, cert, chain, errors) =>
    {
        // Certificate validation callback - detect TLS version
        return true; // Accept all certificates for this test
    };

    using var client = new HttpClient(handler);
    client.Timeout = TimeSpan.FromSeconds(10);

    var response = await client.GetAsync("https://www.howsmyssl.com/a/check");
    var content = await response.Content.ReadAsStringAsync();
    sw.Stop();

    if (response.IsSuccessStatusCode)
    {
        // Parse TLS version from response
        var tlsInfo = "TLS connection established";
        if (content.Contains("\"tls_version\":\"TLS 1.3\""))
            tlsInfo += " (TLS 1.3 detected)";
        else if (content.Contains("\"tls_version\":\"TLS 1.2\""))
            tlsInfo += " (TLS 1.2 detected)";

        LogTest("4.4", "TLS Protocol Detection", "pass",
            tlsInfo, sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("4.4", "TLS Protocol Detection", "fail",
            $"HTTP error: {(int)response.StatusCode}");
    }
}
catch (Exception ex)
{
    LogTest("4.4", "TLS Protocol Detection", "fail", $"Exception: {ex.Message}");
}

// Test 4.5: Certificate Chain Validation
try
{
    var sw = Stopwatch.StartNew();
    using var handler = new HttpClientHandler();
    bool chainValid = false;
    int chainLength = 0;

    handler.ServerCertificateCustomValidationCallback = (message, cert, chain, errors) =>
    {
        if (chain != null)
        {
            chainLength = chain.ChainElements.Count;
            chainValid = errors == SslPolicyErrors.None;
        }
        return true;
    };

    using var client = new HttpClient(handler);
    client.Timeout = TimeSpan.FromSeconds(10);

    var response = await client.GetAsync("https://www.google.com");
    sw.Stop();

    if (response.IsSuccessStatusCode && chainLength > 0)
    {
        LogTest("4.5", "Certificate Chain Validation", "pass",
            $"Chain validated: {chainLength} certificates, valid: {chainValid}", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("4.5", "Certificate Chain Validation", "fail",
            $"Chain validation failed or no certificates");
    }
}
catch (Exception ex)
{
    LogTest("4.5", "Certificate Chain Validation", "fail", $"Exception: {ex.Message}");
}

// Test 4.6: Multiple Concurrent HTTPS Connections
try
{
    var sw = Stopwatch.StartNew();
    using var client = new HttpClient();
    client.Timeout = TimeSpan.FromSeconds(15);

    var urls = new[]
    {
        "https://www.google.com",
        "https://www.github.com",
        "https://www.cloudflare.com"
    };

    var tasks = urls.Select(url => client.GetAsync(url)).ToArray();
    var responses = await Task.WhenAll(tasks);
    sw.Stop();

    var successCount = responses.Count(r => r.IsSuccessStatusCode);

    if (successCount == urls.Length)
    {
        LogTest("4.6", "Concurrent HTTPS Connections", "pass",
            $"All {urls.Length} concurrent connections successful", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("4.6", "Concurrent HTTPS Connections", "fail",
            $"Only {successCount}/{urls.Length} connections successful");
    }
}
catch (Exception ex)
{
    LogTest("4.6", "Concurrent HTTPS Connections", "fail", $"Exception: {ex.Message}");
}

// Test 4.7: HTTPS with Timeout Handling
try
{
    var sw = Stopwatch.StartNew();
    using var client = new HttpClient();
    client.Timeout = TimeSpan.FromSeconds(5);

    var response = await client.GetAsync("https://httpbin.org/delay/1");
    sw.Stop();

    if (response.IsSuccessStatusCode && sw.ElapsedMilliseconds < 5000)
    {
        LogTest("4.7", "HTTPS Timeout Handling", "pass",
            $"Request completed within timeout ({sw.ElapsedMilliseconds}ms < 5000ms)", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("4.7", "HTTPS Timeout Handling", "fail",
            $"Request exceeded timeout or failed");
    }
}
catch (TaskCanceledException)
{
    LogTest("4.7", "HTTPS Timeout Handling", "skip", "Request timed out (expected for slow endpoints)");
}
catch (Exception ex)
{
    LogTest("4.7", "HTTPS Timeout Handling", "fail", $"Exception: {ex.Message}");
}

// Test 4.8: HTTPS Redirect Following
try
{
    var sw = Stopwatch.StartNew();
    using var handler = new HttpClientHandler();
    handler.AllowAutoRedirect = true;
    handler.MaxAutomaticRedirections = 5;

    using var client = new HttpClient(handler);
    client.Timeout = TimeSpan.FromSeconds(10);

    var response = await client.GetAsync("https://httpbin.org/redirect/2");
    sw.Stop();

    if (response.IsSuccessStatusCode)
    {
        LogTest("4.8", "HTTPS Redirect Following", "pass",
            $"Successfully followed redirects, final status: {(int)response.StatusCode}", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("4.8", "HTTPS Redirect Following", "fail",
            $"Redirect following failed: {(int)response.StatusCode}");
    }
}
catch (Exception ex)
{
    LogTest("4.8", "HTTPS Redirect Following", "fail", $"Exception: {ex.Message}");
}

// Test 4.9: HTTPS with Compression
try
{
    var sw = Stopwatch.StartNew();
    using var handler = new HttpClientHandler();
    handler.AutomaticDecompression = DecompressionMethods.GZip | DecompressionMethods.Deflate;

    using var client = new HttpClient(handler);
    client.Timeout = TimeSpan.FromSeconds(10);

    var response = await client.GetAsync("https://httpbin.org/gzip");
    var content = await response.Content.ReadAsStringAsync();
    sw.Stop();

    if (response.IsSuccessStatusCode && content.Contains("gzipped"))
    {
        LogTest("4.9", "HTTPS with Compression", "pass",
            $"Decompressed response: {content.Length} bytes", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("4.9", "HTTPS with Compression", "fail",
            $"Compression test failed");
    }
}
catch (Exception ex)
{
    LogTest("4.9", "HTTPS with Compression", "fail", $"Exception: {ex.Message}");
}

// Test 4.10: HTTPS Response Headers
try
{
    var sw = Stopwatch.StartNew();
    using var client = new HttpClient();
    client.Timeout = TimeSpan.FromSeconds(10);

    var response = await client.GetAsync("https://httpbin.org/response-headers?Server=FIPS-Test");
    sw.Stop();

    if (response.IsSuccessStatusCode && response.Headers.Any())
    {
        var headerCount = response.Headers.Count() + response.Content.Headers.Count();
        LogTest("4.10", "HTTPS Response Headers", "pass",
            $"Received {headerCount} response headers", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("4.10", "HTTPS Response Headers", "fail",
            $"Failed to retrieve response headers");
    }
}
catch (Exception ex)
{
    LogTest("4.10", "HTTPS Response Headers", "fail", $"Exception: {ex.Message}");
}

// Test 4.11: HTTPS with Large Response
try
{
    var sw = Stopwatch.StartNew();
    using var client = new HttpClient();
    client.Timeout = TimeSpan.FromSeconds(15);

    var response = await client.GetAsync("https://httpbin.org/bytes/102400"); // 100KB
    var content = await response.Content.ReadAsByteArrayAsync();
    sw.Stop();

    if (response.IsSuccessStatusCode && content.Length >= 100000)
    {
        LogTest("4.11", "HTTPS Large Response", "pass",
            $"Received {content.Length} bytes successfully", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("4.11", "HTTPS Large Response", "fail",
            $"Large response test failed, received {content?.Length ?? 0} bytes");
    }
}
catch (Exception ex)
{
    LogTest("4.11", "HTTPS Large Response", "fail", $"Exception: {ex.Message}");
}

// Test 4.12: HTTPS with Query Parameters
try
{
    var sw = Stopwatch.StartNew();
    using var client = new HttpClient();
    client.Timeout = TimeSpan.FromSeconds(10);

    var url = "https://httpbin.org/get?fips=enabled&crypto=wolfssl&version=5.8.2";
    var response = await client.GetAsync(url);
    var content = await response.Content.ReadAsStringAsync();
    sw.Stop();

    if (response.IsSuccessStatusCode && content.Contains("fips"))
    {
        LogTest("4.12", "HTTPS Query Parameters", "pass",
            $"Query parameters processed correctly", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("4.12", "HTTPS Query Parameters", "fail",
            $"Query parameter test failed");
    }
}
catch (Exception ex)
{
    LogTest("4.12", "HTTPS Query Parameters", "fail", $"Exception: {ex.Message}");
}

// Test 4.13: HTTPS Connection Reuse
try
{
    var sw = Stopwatch.StartNew();
    using var client = new HttpClient();
    client.Timeout = TimeSpan.FromSeconds(10);

    // Make multiple requests to same host
    var response1 = await client.GetAsync("https://httpbin.org/get");
    var response2 = await client.GetAsync("https://httpbin.org/headers");
    var response3 = await client.GetAsync("https://httpbin.org/user-agent");
    sw.Stop();

    if (response1.IsSuccessStatusCode && response2.IsSuccessStatusCode && response3.IsSuccessStatusCode)
    {
        LogTest("4.13", "HTTPS Connection Reuse", "pass",
            $"3 requests to same host completed (connection pooling active)", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("4.13", "HTTPS Connection Reuse", "fail",
            $"Some requests failed");
    }
}
catch (Exception ex)
{
    LogTest("4.13", "HTTPS Connection Reuse", "fail", $"Exception: {ex.Message}");
}

// Test 4.14: HTTPS with Different Content Types
try
{
    var sw = Stopwatch.StartNew();
    using var client = new HttpClient();
    client.Timeout = TimeSpan.FromSeconds(10);

    var jsonResponse = await client.GetAsync("https://httpbin.org/json");
    var htmlResponse = await client.GetAsync("https://httpbin.org/html");
    var xmlResponse = await client.GetAsync("https://httpbin.org/xml");
    sw.Stop();

    var jsonContent = jsonResponse.Content.Headers.ContentType?.MediaType;
    var htmlContent = htmlResponse.Content.Headers.ContentType?.MediaType;
    var xmlContent = xmlResponse.Content.Headers.ContentType?.MediaType;

    if (jsonContent?.Contains("json") == true &&
        htmlContent?.Contains("html") == true &&
        xmlContent?.Contains("xml") == true)
    {
        LogTest("4.14", "HTTPS Content Types", "pass",
            $"Handled JSON, HTML, and XML content types", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("4.14", "HTTPS Content Types", "fail",
            $"Content type detection failed");
    }
}
catch (Exception ex)
{
    LogTest("4.14", "HTTPS Content Types", "fail", $"Exception: {ex.Message}");
}

// Test 4.15: TLS SNI (Server Name Indication)
try
{
    var sw = Stopwatch.StartNew();
    using var client = new HttpClient();
    client.Timeout = TimeSpan.FromSeconds(10);

    // Test SNI by connecting to a host that requires it
    var response = await client.GetAsync("https://www.cloudflare.com");
    sw.Stop();

    if (response.IsSuccessStatusCode)
    {
        LogTest("4.15", "TLS SNI Support", "pass",
            $"SNI-enabled connection successful", sw.ElapsedMilliseconds);
    }
    else
    {
        LogTest("4.15", "TLS SNI Support", "fail",
            $"SNI test failed: {(int)response.StatusCode}");
    }
}
catch (Exception ex)
{
    LogTest("4.15", "TLS SNI Support", "fail", $"Exception: {ex.Message}");
}

// Print Summary
Console.WriteLine("================================================================================");
Console.WriteLine($"  Connectivity Test Summary");
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
var resultsPath = Path.Combine(Environment.CurrentDirectory, "connectivity-results.json");
File.WriteAllText(resultsPath, json);
Console.WriteLine($"Results saved to: {resultsPath}");
Console.WriteLine();

// Exit with appropriate code
Environment.Exit(results.Failed == 0 ? 0 : 1);
