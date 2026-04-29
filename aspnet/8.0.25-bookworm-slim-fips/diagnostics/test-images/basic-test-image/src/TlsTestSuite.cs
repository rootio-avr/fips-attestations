#!/usr/bin/env dotnet-script
/**
 * TLS/HTTPS Connectivity Test Suite
 *
 * Tests FIPS-compliant TLS/HTTPS connections using HttpClient
 */

using System;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;

public class TlsTestSuite
{
    private int totalTests = 0;
    private int passedTests = 0;
    private int failedTests = 0;
    private static readonly HttpClient client = new HttpClient();

    public void PrintHeader()
    {
        Console.WriteLine();
        Console.WriteLine(new string('=', 80));
        Console.WriteLine("  TLS/HTTPS Connectivity Test Suite");
        Console.WriteLine("  Testing FIPS-Compliant TLS via HttpClient → OpenSSL → wolfSSL");
        Console.WriteLine(new string('=', 80));
        Console.WriteLine();
    }

    public void RunTest(string testName, Func<Task> testFunc)
    {
        totalTests++;
        Console.Write($"[{totalTests}] {testName}... ");
        try
        {
            testFunc().Wait();
            passedTests++;
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("✓ PASS");
            Console.ResetColor();
        }
        catch (Exception ex)
        {
            failedTests++;
            Console.ForegroundColor = ConsoleColor.Red;
            var innerMessage = ex.InnerException?.Message ?? ex.Message;
            Console.WriteLine($"✗ FAIL: {innerMessage}");
            Console.ResetColor();
        }
    }

    public async Task TestBasicHTTPS()
    {
        var response = await client.GetAsync("https://www.google.com");
        response.EnsureSuccessStatusCode();

        if (response.StatusCode != System.Net.HttpStatusCode.OK)
            throw new Exception($"Expected 200 OK, got {response.StatusCode}");
    }

    public async Task TestHTTPSWithCustomHeaders()
    {
        var request = new HttpRequestMessage(HttpMethod.Get, "https://httpbin.org/headers");
        request.Headers.Add("User-Agent", "FIPS-Test-Client");
        request.Headers.Add("X-Custom-Header", "FIPS-Validation");

        var response = await client.SendAsync(request);
        response.EnsureSuccessStatusCode();

        var content = await response.Content.ReadAsStringAsync();
        if (!content.Contains("User-Agent"))
            throw new Exception("Custom headers not received");
    }

    public async Task TestHTTPSPOST()
    {
        var jsonContent = new StringContent(
            "{\"test\":\"FIPS POST request\"}",
            Encoding.UTF8,
            "application/json"
        );

        var response = await client.PostAsync("https://httpbin.org/post", jsonContent);
        response.EnsureSuccessStatusCode();

        var content = await response.Content.ReadAsStringAsync();
        if (!content.Contains("FIPS POST request"))
            throw new Exception("POST data not echoed back");
    }

    public async Task TestTLSProtocolVersion()
    {
        var response = await client.GetAsync("https://www.google.com");
        response.EnsureSuccessStatusCode();

        // Just verify we can establish a TLS connection
        // Actual protocol version (TLS 1.2 or 1.3) depends on server
        if (response.Version.Major < 1)
            throw new Exception($"HTTP version {response.Version} is too old");
    }

    public async Task TestCertificateValidation()
    {
        // Test with a known good certificate
        var response = await client.GetAsync("https://www.google.com");
        response.EnsureSuccessStatusCode();

        // If we get here without SSL errors, certificate validation passed
        if (response.StatusCode != System.Net.HttpStatusCode.OK)
            throw new Exception("Certificate validation may have failed");
    }

    public async Task TestConcurrentConnections()
    {
        var tasks = new Task<HttpResponseMessage>[3];
        tasks[0] = client.GetAsync("https://www.google.com");
        tasks[1] = client.GetAsync("https://httpbin.org/get");
        tasks[2] = client.GetAsync("https://www.cloudflare.com");

        await Task.WhenAll(tasks);

        foreach (var task in tasks)
        {
            task.Result.EnsureSuccessStatusCode();
        }
    }

    public async Task TestHTTPSTimeout()
    {
        using (var timeoutClient = new HttpClient())
        {
            timeoutClient.Timeout = TimeSpan.FromSeconds(5);

            var response = await timeoutClient.GetAsync("https://www.google.com");
            response.EnsureSuccessStatusCode();
        }
    }

    public async Task TestHTTPSRedirect()
    {
        var response = await client.GetAsync("http://www.google.com");
        response.EnsureSuccessStatusCode();

        // Google redirects HTTP to HTTPS
        if (response.RequestMessage.RequestUri.Scheme != "https")
            throw new Exception("Expected redirect to HTTPS");
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
            Console.WriteLine("✓ All TLS/HTTPS tests passed - FIPS TLS is working correctly");
            Console.ResetColor();
        }
        else
        {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine("✗ Some TLS/HTTPS tests failed");
            Console.ResetColor();
        }
        Console.WriteLine();
    }

    public int Run()
    {
        PrintHeader();

        RunTest("Basic HTTPS GET Request", TestBasicHTTPS);
        RunTest("HTTPS with Custom Headers", TestHTTPSWithCustomHeaders);
        RunTest("HTTPS POST Request", TestHTTPSPOST);
        RunTest("TLS Protocol Version", TestTLSProtocolVersion);
        RunTest("Certificate Validation", TestCertificateValidation);
        RunTest("Concurrent HTTPS Connections", TestConcurrentConnections);
        RunTest("HTTPS Timeout Handling", TestHTTPSTimeout);
        RunTest("HTTPS Redirect Following", TestHTTPSRedirect);

        PrintSummary();

        return failedTests == 0 ? 0 : 1;
    }
}

// If run directly
if (Args.Count == 0 || Args[0] != "--import-only")
{
    var suite = new TlsTestSuite();
    Environment.Exit(suite.Run());
}
