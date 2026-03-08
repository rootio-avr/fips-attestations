package main

import (
	"crypto/md5"
	"crypto/sha1"
	"crypto/sha256"
	"crypto/sha512"
	"fmt"
	"os"
	"runtime"
)

// FIPS Reference Application - Go Crypto Demo
//
// Purpose: Minimal Go application that demonstrates FIPS cryptographic operations
//
// This program:
//   - Tests non-FIPS algorithms (MD5, SHA1)
//   - Tests FIPS-approved algorithms (SHA-256, SHA-384, SHA-512)
//   - Returns exit code 0 on success, 1 on failure
//
// Note: When compiled with golang-fips/go, non-FIPS algorithms will panic/fail.
//       With standard Go, all algorithms work (but shows warnings).

const testData = "FIPS Reference Application - Test Data"

var (
	passedTests = 0
	failedTests = 0
	warnTests   = 0
)

func main() {
	fmt.Println("================================================================================")
	fmt.Println("FIPS Reference Application - Go Crypto Demo")
	fmt.Println("================================================================================")
	fmt.Println()
	fmt.Println("Purpose: Demonstrate FIPS-compliant cryptographic operations in Go")
	fmt.Println()

	// Display Go environment
	fmt.Println("[Environment Information]")
	fmt.Println("--------------------------------------------------------------------------------")
	fmt.Printf("Go Version: %s\n", runtime.Version())
	fmt.Printf("Go Root: %s\n", runtime.GOROOT())
	fmt.Printf("Compiler: %s\n", runtime.Compiler)
	fmt.Printf("Architecture: %s/%s\n", runtime.GOOS, runtime.GOARCH)

	// Check if FIPS-enabled
	fmt.Println()
	fmt.Print("FIPS Mode: ")
	// Note: golang-fips/go sets GOLANG_FIPS env var
	if os.Getenv("GOLANG_FIPS") == "1" {
		fmt.Println("ENABLED (golang-fips/go)")
	} else {
		fmt.Println("NOT DETECTED (standard Go)")
	}

	fmt.Println()
	fmt.Println("================================================================================")
	fmt.Println()

	// Test Suite 1: Non-FIPS Algorithms
	fmt.Println("[Test Suite 1] Non-FIPS Algorithms")
	fmt.Println("--------------------------------------------------------------------------------")
	fmt.Println("Testing deprecated/non-FIPS algorithms:")
	fmt.Println()
	testMD5()
	testSHA1()
	fmt.Println()

	// Test Suite 2: FIPS-Approved Algorithms
	fmt.Println("[Test Suite 2] FIPS-Approved Algorithms")
	fmt.Println("--------------------------------------------------------------------------------")
	fmt.Println("Testing FIPS-approved algorithms:")
	fmt.Println()
	testSHA256()
	testSHA384()
	testSHA512()
	fmt.Println()

	// Results
	fmt.Println("================================================================================")
	fmt.Println("Test Results")
	fmt.Println("================================================================================")
	fmt.Printf("Total Tests: %d\n", passedTests+failedTests+warnTests)
	fmt.Printf("Passed: %d\n", passedTests)
	fmt.Printf("Failed: %d\n", failedTests)
	fmt.Printf("Warnings: %d\n", warnTests)
	fmt.Println()

	if failedTests > 0 {
		fmt.Println("Status: FAILED")
		fmt.Println()
		fmt.Println("Some critical tests failed. Review output above.")
		os.Exit(1)
	} else if warnTests > 0 {
		fmt.Println("Status: PASSED (with warnings)")
		fmt.Println()
		fmt.Println("FIPS-approved algorithms work correctly.")
		fmt.Println("Non-FIPS algorithms show warnings (using standard Go).")
		fmt.Println()
		fmt.Println("Note: For full FIPS enforcement, use golang-fips/go compiler:")
		fmt.Println("  https://github.com/golang-fips/go")
		os.Exit(0)
	} else {
		fmt.Println("Status: PASSED")
		fmt.Println()
		fmt.Println("All FIPS tests passed successfully!")
		fmt.Println("Non-FIPS algorithms properly blocked (golang-fips/go active).")
		os.Exit(0)
	}
}

func testMD5() {
	fmt.Print("  [1/2] MD5 (deprecated) ... ")

	// Use defer to catch panic from golang-fips/go
	defer func() {
		if r := recover(); r != nil {
			fmt.Println("BLOCKED (good - golang-fips/go active)")
			passedTests++
		}
	}()

	h := md5.New()
	h.Write([]byte(testData))
	hash := h.Sum(nil)

	if len(hash) == 16 {
		fmt.Println("WARNING (available but deprecated)")
		fmt.Println("        Note: golang-fips/go would block this")
		warnTests++
	} else {
		fmt.Println("FAIL (invalid hash length)")
		failedTests++
	}
}

func testSHA1() {
	fmt.Print("  [2/2] SHA1 (deprecated) ... ")
	

	// Use defer to catch panic from golang-fips/go
	defer func() {
		if r := recover(); r != nil {
			fmt.Println("BLOCKED (good - golang-fips/go active)")
			passedTests++
		}
	}()

	h := sha1.New()
	h.Write([]byte(testData))
	hash := h.Sum(nil)

	if len(hash) == 20 {
		fmt.Println("WARNING (available but deprecated)")
		fmt.Println("        Note: golang-fips/go would block this")
		warnTests++
	} else {
		fmt.Println("FAIL (invalid hash length)")
		failedTests++
	}
}

func testSHA256() {
	fmt.Print("  [1/3] SHA-256 (FIPS-approved) ... ")

	defer func() {
		if r := recover(); r != nil {
			fmt.Printf("FAIL (panic: %v)\n", r)
			failedTests++
		}
	}()

	h := sha256.New()
	h.Write([]byte(testData))
	hash := h.Sum(nil)

	if len(hash) == 32 {
		fmt.Printf("PASS (hash: %02x%02x%02x%02x...)\n", hash[0], hash[1], hash[2], hash[3])
		passedTests++
	} else {
		fmt.Println("FAIL (invalid hash length)")
		failedTests++
	}
}

func testSHA384() {
	fmt.Print("  [2/3] SHA-384 (FIPS-approved) ... ")

	defer func() {
		if r := recover(); r != nil {
			fmt.Printf("FAIL (panic: %v)\n", r)
			failedTests++
		}
	}()

	h := sha512.New384()
	h.Write([]byte(testData))
	hash := h.Sum(nil)

	if len(hash) == 48 {
		fmt.Printf("PASS (hash: %02x%02x%02x%02x...)\n", hash[0], hash[1], hash[2], hash[3])
		passedTests++
	} else {
		fmt.Println("FAIL (invalid hash length)")
		failedTests++
	}
}

func testSHA512() {
	fmt.Print("  [3/3] SHA-512 (FIPS-approved) ... ")

	defer func() {
		if r := recover(); r != nil {
			fmt.Printf("FAIL (panic: %v)\n", r)
			failedTests++
		}
	}()

	h := sha512.New()
	h.Write([]byte(testData))
	hash := h.Sum(nil)

	if len(hash) == 64 {
		fmt.Printf("PASS (hash: %02x%02x%02x%02x...)\n", hash[0], hash[1], hash[2], hash[3])
		passedTests++
	} else {
		fmt.Println("FAIL (invalid hash length)")
		failedTests++
	}
}
