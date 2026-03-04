#!/bin/bash
################################################################################
# Test In-Container Go Compilation
#
# Purpose: Verify golang-fips/go can compile new programs inside the container
################################################################################

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "================================================================================"
echo "Test: In-Container Go Compilation with FIPS Enforcement"
echo "================================================================================"
echo ""

TESTS_PASSED=0
TESTS_FAILED=0
TEST_DIR="/tmp/go-compile-test"

# Cleanup test directory on exit
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

echo "[Test 1] Go compiler availability"
if command -v go >/dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC} - Go compiler found"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    go version
else
    echo -e "${RED}✗ FAIL${NC} - Go compiler not found"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    exit 1
fi

echo ""
echo "[Test 2] FIPS environment variables"
echo "  GOLANG_FIPS: $GOLANG_FIPS"
echo "  GODEBUG: $GODEBUG"
echo "  GOEXPERIMENT: $GOEXPERIMENT"
if [ "$GOLANG_FIPS" = "1" ] && [ "$GODEBUG" = "fips140=only" ]; then
    echo -e "${GREEN}✓ PASS${NC} - FIPS environment configured correctly"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - FIPS environment not configured"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "[Test 3] Create test Go program"
mkdir -p "$TEST_DIR"
cat > "$TEST_DIR/test-fips.go" <<'EOF'
package main

import (
	"crypto/sha256"
	"fmt"
)

func main() {
	// Test SHA-256 (FIPS approved)
	data := []byte("Hello FIPS World")
	hash := sha256.Sum256(data)
	fmt.Printf("✓ SHA-256 Hash: %x\n", hash)
	fmt.Println("✓ Go program compiled and executed successfully in FIPS mode!")
}
EOF

if [ -f "$TEST_DIR/test-fips.go" ]; then
    echo -e "${GREEN}✓ PASS${NC} - Test program created"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - Failed to create test program"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    exit 1
fi

echo ""
echo "[Test 4] Compile Go program with golang-fips/go"
echo "--------------------------------------------------------------------------------"
cd "$TEST_DIR"
if GOEXPERIMENT=strictfipsruntime go build -o test-fips test-fips.go 2>&1; then
    echo -e "${GREEN}✓ PASS${NC} - Go program compiled successfully"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - Compilation failed"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    exit 1
fi

echo ""
echo "[Test 5] Execute compiled binary"
echo "--------------------------------------------------------------------------------"
if ./test-fips; then
    echo -e "${GREEN}✓ PASS${NC} - Compiled binary executed successfully"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - Binary execution failed"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "[Test 6] Verify CGO is enabled (required for FIPS)"
if go env CGO_ENABLED | grep -q "1"; then
    echo -e "${GREEN}✓ PASS${NC} - CGO is enabled"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - CGO should be enabled for FIPS mode"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "[Test 7] Verify GOROOT points to golang-fips/go"
if echo "$GOROOT" | grep -q "go-fips"; then
    echo -e "${GREEN}✓ PASS${NC} - GOROOT: $GOROOT"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - GOROOT should point to golang-fips/go"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "[Test 8] Test compilation with dependencies (go mod)"
echo "--------------------------------------------------------------------------------"
mkdir -p "$TEST_DIR/modtest"
cd "$TEST_DIR/modtest"

cat > go.mod <<EOF
module fips-test

go 1.25
EOF

cat > main.go <<'EOF'
package main

import (
	"crypto/sha256"
	"crypto/sha512"
	"fmt"
)

func main() {
	data := []byte("FIPS Module Test")

	h256 := sha256.Sum256(data)
	fmt.Printf("SHA-256: %x\n", h256)

	h512 := sha512.Sum512(data)
	fmt.Printf("SHA-512: %x\n", h512)

	fmt.Println("✓ Module-based compilation successful")
}
EOF

if GOEXPERIMENT=strictfipsruntime go build -o modtest . 2>&1 && ./modtest; then
    echo -e "${GREEN}✓ PASS${NC} - Module-based compilation and execution successful"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC} - Module-based compilation failed"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "================================================================================"
echo "Test Summary"
echo "================================================================================"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ ALL TESTS PASSED${NC}"
    echo ""
    echo "In-Container Go Compilation: VERIFIED"
    echo "  - golang-fips/go compiler is available"
    echo "  - FIPS mode is properly configured"
    echo "  - Programs can be compiled and executed with FIPS enforcement"
    echo "  - Module-based projects are supported"
    exit 0
else
    echo -e "${RED}✗ SOME TESTS FAILED${NC}"
    exit 1
fi
