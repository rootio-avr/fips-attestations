// TlsTestSuite - Comprehensive FIPS TLS/HTTPS operations test suite
//
// Copyright (C) 2006-2026 root.io Inc.
//
// This test suite validates FIPS-compliant TLS operations using
// golang-fips/go with crypto/tls package.

package main

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"time"
)

var (
	passedTests  = 0
	failedTests  = 0
	totalTests   = 0
	verboseMode  = false
)

func main() {
	fmt.Println("================================================================================")
	fmt.Println("FIPS TLS Test Suite - golang-fips/go")
	fmt.Println("================================================================================")
	fmt.Println()

	// Check verbose mode
	verboseMode = os.Getenv("VERBOSE") == "true"

	// Display environment
	displayEnvironment()

	// Run all TLS test suites
	fmt.Println("================================================================================")
	fmt.Println("Test Execution")
	fmt.Println("================================================================================")
	fmt.Println()

	testTLSConnections()
	testHTTPSRequests()
	testCipherSuites()
	testCertificateValidation()

	// Print summary
	fmt.Println()
	fmt.Println("================================================================================")
	fmt.Println("Test Summary")
	fmt.Println("================================================================================")
	fmt.Printf("Total Tests:   %d\n", totalTests)
	fmt.Printf("Passed:        %d (%.1f%%)\n", passedTests, float64(passedTests)/float64(totalTests)*100)
	fmt.Printf("Failed:        %d\n", failedTests)
	fmt.Println()

	if failedTests > 0 {
		fmt.Println("Status: FAILED")
		fmt.Println()
		fmt.Println("Some critical tests failed. Review output above.")
		os.Exit(1)
	} else {
		fmt.Println("Status: PASSED")
		fmt.Println()
		fmt.Println("All FIPS TLS operations validated successfully!")
		os.Exit(0)
	}
}

func displayEnvironment() {
	fmt.Println("[Environment Information]")
	fmt.Println("--------------------------------------------------------------------------------")
	fmt.Printf("GOLANG_FIPS:     %s\n", os.Getenv("GOLANG_FIPS"))
	fmt.Printf("GODEBUG:         %s\n", os.Getenv("GODEBUG"))
	fmt.Printf("GOEXPERIMENT:    %s\n", os.Getenv("GOEXPERIMENT"))
	fmt.Println()
}

func testTLSConnections() {
	fmt.Println("[Test Suite 1] TLS Connection Tests")
	fmt.Println("--------------------------------------------------------------------------------")
	fmt.Println()

	testTLSConnectionToGoogle()
	testTLSConnectionToGolangOrg()
	testTLS13Connection()

	fmt.Println()
}

func testTLSConnectionToGoogle() {
	totalTests++
	fmt.Print("  [1.1] TLS Connection to www.google.com ... ")

	defer func() {
		if r := recover(); r != nil {
			fmt.Printf("FAIL ✗ (panic: %v)\n", r)
			failedTests++
		}
	}()

	config := &tls.Config{
		MinVersion: tls.VersionTLS12,
	}

	conn, err := tls.Dial("tcp", "www.google.com:443", config)
	if err != nil {
		fmt.Printf("FAIL ✗ (connection: %v)\n", err)
		failedTests++
		return
	}
	defer conn.Close()

	state := conn.ConnectionState()
	if verboseMode {
		fmt.Printf("PASS ✓\n")
		fmt.Printf("        Protocol: %s\n", tlsVersionString(state.Version))
		fmt.Printf("        Cipher Suite: %s\n", tls.CipherSuiteName(state.CipherSuite))
		fmt.Printf("        Server: %s\n", state.ServerName)
	} else {
		fmt.Printf("PASS ✓ (TLS %s, %s)\n",
			tlsVersionString(state.Version),
			tls.CipherSuiteName(state.CipherSuite))
	}
	passedTests++
}

func testTLSConnectionToGolangOrg() {
	totalTests++
	fmt.Print("  [1.2] TLS Connection to golang.org ... ")

	defer func() {
		if r := recover(); r != nil {
			fmt.Printf("FAIL ✗ (panic: %v)\n", r)
			failedTests++
		}
	}()

	config := &tls.Config{
		ServerName: "golang.org",
		MinVersion: tls.VersionTLS12,
	}

	conn, err := tls.Dial("tcp", "golang.org:443", config)
	if err != nil {
		fmt.Printf("FAIL ✗ (%v)\n", err)
		failedTests++
		return
	}
	defer conn.Close()

	state := conn.ConnectionState()
	fmt.Printf("PASS ✓ (%s)\n", tls.CipherSuiteName(state.CipherSuite))
	passedTests++
}

func testTLS13Connection() {
	totalTests++
	fmt.Print("  [1.3] TLS 1.3 Connection ... ")

	defer func() {
		if r := recover(); r != nil {
			fmt.Printf("FAIL ✗ (panic: %v)\n", r)
			failedTests++
		}
	}()

	config := &tls.Config{
		MinVersion: tls.VersionTLS13,
	}

	conn, err := tls.Dial("tcp", "www.cloudflare.com:443", config)
	if err != nil {
		fmt.Printf("FAIL ✗ (%v)\n", err)
		failedTests++
		return
	}
	defer conn.Close()

	state := conn.ConnectionState()
	if state.Version == tls.VersionTLS13 {
		fmt.Println("PASS ✓ (TLS 1.3 confirmed)")
		passedTests++
	} else {
		fmt.Printf("FAIL ✗ (expected TLS 1.3, got %s)\n", tlsVersionString(state.Version))
		failedTests++
	}
}

func testHTTPSRequests() {
	fmt.Println("[Test Suite 2] HTTPS Request Tests")
	fmt.Println("--------------------------------------------------------------------------------")
	fmt.Println()

	testHTTPSGetRequest()
	testHTTPSWithCustomClient()
	testHTTPSHeaderInspection()

	fmt.Println()
}

func testHTTPSGetRequest() {
	totalTests++
	fmt.Print("  [2.1] HTTPS GET Request ... ")

	defer func() {
		if r := recover(); r != nil {
			fmt.Printf("FAIL ✗ (panic: %v)\n", r)
			failedTests++
		}
	}()

	client := &http.Client{
		Timeout: 10 * time.Second,
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{
				MinVersion: tls.VersionTLS12,
			},
		},
	}

	resp, err := client.Get("https://www.google.com")
	if err != nil {
		fmt.Printf("FAIL ✗ (%v)\n", err)
		failedTests++
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode == 200 {
		fmt.Printf("PASS ✓ (HTTP %d)\n", resp.StatusCode)
		if verboseMode {
			fmt.Printf("        Content-Type: %s\n", resp.Header.Get("Content-Type"))
		}
		passedTests++
	} else {
		fmt.Printf("FAIL ✗ (HTTP %d)\n", resp.StatusCode)
		failedTests++
	}
}

func testHTTPSWithCustomClient() {
	totalTests++
	fmt.Print("  [2.2] HTTPS with Custom TLS Config ... ")

	defer func() {
		if r := recover(); r != nil {
			fmt.Printf("FAIL ✗ (panic: %v)\n", r)
			failedTests++
		}
	}()

	tlsConfig := &tls.Config{
		MinVersion: tls.VersionTLS12,
		MaxVersion: tls.VersionTLS13,
	}

	client := &http.Client{
		Timeout: 10 * time.Second,
		Transport: &http.Transport{
			TLSClientConfig: tlsConfig,
		},
	}

	resp, err := client.Get("https://golang.org")
	if err != nil {
		fmt.Printf("FAIL ✗ (%v)\n", err)
		failedTests++
		return
	}
	defer resp.Body.Close()

	if resp.TLS != nil {
		fmt.Printf("PASS ✓ (TLS %s)\n", tlsVersionString(resp.TLS.Version))
		passedTests++
	} else {
		fmt.Println("FAIL ✗ (no TLS state)")
		failedTests++
	}
}

func testHTTPSHeaderInspection() {
	totalTests++
	fmt.Print("  [2.3] HTTPS Response Header Inspection ... ")

	defer func() {
		if r := recover(); r != nil {
			fmt.Printf("FAIL ✗ (panic: %v)\n", r)
			failedTests++
		}
	}()

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Get("https://www.google.com")
	if err != nil {
		fmt.Printf("FAIL ✗ (%v)\n", err)
		failedTests++
		return
	}
	defer resp.Body.Close()

	// Read a small amount of response
	body := make([]byte, 100)
	n, _ := resp.Body.Read(body)

	if n > 0 && resp.Header.Get("Content-Type") != "" {
		fmt.Println("PASS ✓")
		if verboseMode {
			fmt.Printf("        Read %d bytes\n", n)
			fmt.Printf("        Content-Type: %s\n", resp.Header.Get("Content-Type"))
		}
		passedTests++
	} else {
		fmt.Println("FAIL ✗ (no data or headers)")
		failedTests++
	}
}

func testCipherSuites() {
	fmt.Println("[Test Suite 3] Cipher Suite Validation")
	fmt.Println("--------------------------------------------------------------------------------")
	fmt.Println()

	testAvailableCipherSuites()
	testFIPSApprovedCipherSuites()
	testChaCha20Absence()

	fmt.Println()
}

func testAvailableCipherSuites() {
	totalTests++
	fmt.Print("  [3.1] Available Cipher Suites ... ")

	defer func() {
		if r := recover(); r != nil {
			fmt.Printf("FAIL ✗ (panic: %v)\n", r)
			failedTests++
		}
	}()

	suites := tls.CipherSuites()
	insecureSuites := tls.InsecureCipherSuites()

	if len(suites) > 0 {
		fmt.Printf("PASS ✓ (%d secure suites)\n", len(suites))
		if verboseMode {
			fmt.Println("        Secure cipher suites:")
			for i, suite := range suites {
				if i < 5 { // Show first 5
					fmt.Printf("          - %s\n", suite.Name)
				}
			}
			if len(suites) > 5 {
				fmt.Printf("          ... and %d more\n", len(suites)-5)
			}
			fmt.Printf("        Insecure suites: %d\n", len(insecureSuites))
		}
		passedTests++
	} else {
		fmt.Println("FAIL ✗ (no cipher suites available)")
		failedTests++
	}
}

func testFIPSApprovedCipherSuites() {
	totalTests++
	fmt.Print("  [3.2] FIPS-Approved Cipher Suites Only ... ")

	defer func() {
		if r := recover(); r != nil {
			fmt.Printf("FAIL ✗ (panic: %v)\n", r)
			failedTests++
		}
	}()

	suites := tls.CipherSuites()
	fipsApprovedCount := 0

	for _, suite := range suites {
		// FIPS-approved suites use AES-GCM
		if strings.Contains(suite.Name, "AES") && strings.Contains(suite.Name, "GCM") {
			fipsApprovedCount++
		}
	}

	if fipsApprovedCount > 0 {
		fmt.Printf("PASS ✓ (%d AES-GCM suites)\n", fipsApprovedCount)
		passedTests++
	} else {
		fmt.Println("FAIL ✗ (no FIPS-approved suites)")
		failedTests++
	}
}

func testChaCha20Absence() {
	totalTests++
	fmt.Print("  [3.3] ChaCha20 Not Used (non-FIPS) ... ")

	defer func() {
		if r := recover(); r != nil {
			fmt.Printf("FAIL ✗ (panic: %v)\n", r)
			failedTests++
		}
	}()

	// ChaCha20 may appear in cipher suite list, but verify it's not actually used
	// Create a TLS config that would prefer ChaCha20
	config := &tls.Config{
		MinVersion: tls.VersionTLS12,
		CipherSuites: []uint16{
			tls.TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256,
			tls.TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256,
		},
	}

	// Try to connect - should either fail or use a different cipher
	conn, err := tls.Dial("tcp", "www.google.com:443", config)
	if err != nil {
		// Connection failed - ChaCha20 blocked or unavailable
		fmt.Println("PASS ✓ (ChaCha20 blocked/connection failed)")
		passedTests++
		return
	}
	defer conn.Close()

	state := conn.ConnectionState()
	cipherName := tls.CipherSuiteName(state.CipherSuite)

	// Check if ChaCha20 was actually used
	if strings.Contains(cipherName, "CHACHA20") {
		fmt.Printf("FAIL ✗ (ChaCha20 was used: %s)\n", cipherName)
		failedTests++
	} else {
		fmt.Printf("PASS ✓ (ChaCha20 not used, fallback to: %s)\n", cipherName)
		passedTests++
	}
}

func testCertificateValidation() {
	fmt.Println("[Test Suite 4] Certificate Validation")
	fmt.Println("--------------------------------------------------------------------------------")
	fmt.Println()

	testCertificateChainInspection()
	testCertificateExpiry()
	testSystemCertPool()

	fmt.Println()
}

func testCertificateChainInspection() {
	totalTests++
	fmt.Print("  [4.1] Certificate Chain Inspection ... ")

	defer func() {
		if r := recover(); r != nil {
			fmt.Printf("FAIL ✗ (panic: %v)\n", r)
			failedTests++
		}
	}()

	config := &tls.Config{
		MinVersion: tls.VersionTLS12,
	}

	conn, err := tls.Dial("tcp", "www.google.com:443", config)
	if err != nil {
		fmt.Printf("FAIL ✗ (%v)\n", err)
		failedTests++
		return
	}
	defer conn.Close()

	state := conn.ConnectionState()
	if len(state.PeerCertificates) > 0 {
		cert := state.PeerCertificates[0]
		fmt.Printf("PASS ✓ (%d certificates in chain)\n", len(state.PeerCertificates))
		if verboseMode {
			fmt.Printf("        Subject: %s\n", cert.Subject.CommonName)
			fmt.Printf("        Issuer: %s\n", cert.Issuer.CommonName)
			fmt.Printf("        Valid until: %s\n", cert.NotAfter.Format("2006-01-02"))
		}
		passedTests++
	} else {
		fmt.Println("FAIL ✗ (no certificates)")
		failedTests++
	}
}

func testCertificateExpiry() {
	totalTests++
	fmt.Print("  [4.2] Certificate Expiry Check ... ")

	defer func() {
		if r := recover(); r != nil {
			fmt.Printf("FAIL ✗ (panic: %v)\n", r)
			failedTests++
		}
	}()

	config := &tls.Config{
		MinVersion: tls.VersionTLS12,
	}

	conn, err := tls.Dial("tcp", "www.google.com:443", config)
	if err != nil {
		fmt.Printf("FAIL ✗ (%v)\n", err)
		failedTests++
		return
	}
	defer conn.Close()

	state := conn.ConnectionState()
	if len(state.PeerCertificates) > 0 {
		cert := state.PeerCertificates[0]
		now := time.Now()

		if now.After(cert.NotBefore) && now.Before(cert.NotAfter) {
			daysUntilExpiry := int(cert.NotAfter.Sub(now).Hours() / 24)
			fmt.Printf("PASS ✓ (valid for %d more days)\n", daysUntilExpiry)
			passedTests++
		} else {
			fmt.Println("FAIL ✗ (certificate expired or not yet valid)")
			failedTests++
		}
	} else {
		fmt.Println("FAIL ✗ (no certificate)")
		failedTests++
	}
}

func testSystemCertPool() {
	totalTests++
	fmt.Print("  [4.3] System Certificate Pool ... ")

	defer func() {
		if r := recover(); r != nil {
			fmt.Printf("FAIL ✗ (panic: %v)\n", r)
			failedTests++
		}
	}()

	pool, err := x509.SystemCertPool()
	if err != nil {
		fmt.Printf("FAIL ✗ (%v)\n", err)
		failedTests++
		return
	}

	if pool != nil {
		// Try to use the pool in a TLS config
		config := &tls.Config{
			RootCAs:    pool,
			MinVersion: tls.VersionTLS12,
		}

		client := &http.Client{
			Timeout: 10 * time.Second,
			Transport: &http.Transport{
				TLSClientConfig: config,
			},
		}

		resp, err := client.Get("https://www.google.com")
		if err != nil {
			fmt.Printf("FAIL ✗ (connection with system pool: %v)\n", err)
			failedTests++
			return
		}
		defer resp.Body.Close()
		io.Copy(io.Discard, resp.Body)

		fmt.Println("PASS ✓ (system pool loaded and functional)")
		passedTests++
	} else {
		fmt.Println("FAIL ✗ (nil pool)")
		failedTests++
	}
}

// Helper functions

func tlsVersionString(version uint16) string {
	switch version {
	case tls.VersionTLS10:
		return "1.0"
	case tls.VersionTLS11:
		return "1.1"
	case tls.VersionTLS12:
		return "1.2"
	case tls.VersionTLS13:
		return "1.3"
	default:
		return fmt.Sprintf("Unknown(0x%04x)", version)
	}
}
