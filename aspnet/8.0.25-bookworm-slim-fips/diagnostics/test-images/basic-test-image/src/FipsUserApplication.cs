#!/usr/bin/env dotnet-script
/**
 * FIPS User Application - Main Test Orchestrator
 *
 * This application orchestrates comprehensive testing of ASP.NET wolfSSL FIPS integration.
 * It runs crypto and TLS test suites and aggregates results.
 */

#load "CryptoTestSuite.cs"
#load "TlsTestSuite.cs"

using System;
using System.Diagnostics;

public class FipsUserApplication
{
    private Stopwatch stopwatch;
    private int totalSuites = 0;
    private int passedSuites = 0;
    private int failedSuites = 0;
    private List<(string Name, string Status, int ExitCode)> suiteResults = new List<(string, string, int)>();

    public FipsUserApplication()
    {
        stopwatch = new Stopwatch();
    }

    public void PrintHeader()
    {
        Console.WriteLine();
        Console.WriteLine(new string('=', 80));
        Console.WriteLine("  ASP.NET wolfSSL FIPS 140-3 User Application Test");
        Console.WriteLine("  Comprehensive Cryptographic and TLS Test Suite");
        Console.WriteLine(new string('=', 80));
        Console.WriteLine();
    }

    public int RunSuite(string suiteName, Func<int> suiteRunner)
    {
        Console.WriteLine();
        Console.WriteLine(new string('=', 80));
        Console.WriteLine($"  Running: {suiteName}");
        Console.WriteLine(new string('=', 80));
        Console.WriteLine();

        int exitCode = 0;
        try
        {
            exitCode = suiteRunner();

            totalSuites++;
            string status = exitCode == 0 ? "PASS" : "FAIL";

            suiteResults.Add((suiteName, status, exitCode));

            if (exitCode == 0)
            {
                passedSuites++;
                Console.ForegroundColor = ConsoleColor.Green;
                Console.WriteLine($"✓ {suiteName}: PASSED");
                Console.ResetColor();
            }
            else
            {
                failedSuites++;
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine($"✗ {suiteName}: FAILED (exit code: {exitCode})");
                Console.ResetColor();
            }

            return exitCode;
        }
        catch (Exception ex)
        {
            totalSuites++;
            failedSuites++;

            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine($"✗ {suiteName}: EXCEPTION - {ex.Message}");
            Console.ResetColor();

            suiteResults.Add((suiteName, "EXCEPTION", 1));

            return 1;
        }
    }

    public void PrintSummary()
    {
        var duration = stopwatch.Elapsed.TotalSeconds;

        Console.WriteLine();
        Console.WriteLine(new string('=', 80));
        Console.WriteLine("  FINAL TEST SUMMARY");
        Console.WriteLine(new string('=', 80));
        Console.WriteLine();
        Console.WriteLine($"  Total Test Suites: {totalSuites}");

        Console.ForegroundColor = ConsoleColor.Green;
        Console.WriteLine($"  Passed: {passedSuites}");
        Console.ResetColor();

        if (failedSuites > 0)
        {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine($"  Failed: {failedSuites}");
            Console.ResetColor();
        }
        else
        {
            Console.WriteLine($"  Failed: {failedSuites}");
        }

        Console.WriteLine($"  Duration: {duration:F2} seconds");
        Console.WriteLine();

        // Print suite results
        foreach (var result in suiteResults)
        {
            var statusSymbol = result.Status == "PASS" ? "✓" : "✗";
            var color = result.Status == "PASS" ? ConsoleColor.Green : ConsoleColor.Red;

            Console.ForegroundColor = color;
            Console.WriteLine($"  {statusSymbol} {result.Name}: {result.Status}");
            Console.ResetColor();
        }

        Console.WriteLine();

        if (failedSuites == 0)
        {
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("  ✓ ALL TESTS PASSED - ASP.NET wolfSSL FIPS is production ready");
            Console.ResetColor();
        }
        else
        {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine("  ✗ SOME TESTS FAILED - Review results above");
            Console.ResetColor();
        }

        Console.WriteLine();
        Console.WriteLine(new string('=', 80));
        Console.WriteLine();
    }

    public int Run()
    {
        stopwatch.Start();

        PrintHeader();

        // Run test suites
        RunSuite("Cryptographic Operations Test Suite", () =>
        {
            var suite = new CryptoTestSuite();
            return suite.Run();
        });

        RunSuite("TLS/SSL Test Suite", () =>
        {
            var suite = new TlsTestSuite();
            return suite.Run();
        });

        stopwatch.Stop();

        PrintSummary();

        // Return exit code based on results
        if (failedSuites == 0)
            return 0;  // All tests passed
        else if (failedSuites == 1)
            return 1;  // Partial success
        else
            return 2;  // Multiple failures
    }
}

// Main execution
var app = new FipsUserApplication();
Environment.Exit(app.Run());
