#!/bin/bash
################################################################################
# Redis 7.2.4 Alpine FIPS - Build Validation Script
#
# This script performs pre-build validation checks without running the full
# Docker build. It verifies:
# - Prerequisites are met
# - Files are in place
# - Patch applies cleanly to Redis source
# - Dockerfile syntax is valid
#
# Usage:
#   ./test-build.sh [--full]
#
# Options:
#   --full    Also download Redis source and test patch application
################################################################################

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

FULL_TEST=false
if [[ "$1" == "--full" ]]; then
    FULL_TEST=true
fi

REDIS_VERSION="7.2.4"
PATCH_FILE="patches/redis-fips-sha256-redis7.2.4.patch"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Redis FIPS Build Validation${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNINGS=0

################################################################################
# Check functions
################################################################################
check_pass() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    echo -e "${GREEN}[PASS]${NC} $1"
}

check_fail() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    echo -e "${RED}[FAIL]${NC} $1"
}

check_warn() {
    WARNINGS=$((WARNINGS + 1))
    echo -e "${YELLOW}[WARN]${NC} $1"
}

check_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

################################################################################
# Check 1: Docker availability
################################################################################
echo -e "${BLUE}[CHECK 1]${NC} Docker prerequisites"
if command -v docker &> /dev/null; then
    check_pass "Docker installed: $(docker --version)"

    if docker buildx version &> /dev/null 2>&1; then
        check_pass "Docker BuildKit available"
    else
        check_warn "Docker BuildKit not available (recommended for secrets)"
    fi
else
    check_fail "Docker not found in PATH"
fi
echo ""

################################################################################
# Check 2: Required files
################################################################################
echo -e "${BLUE}[CHECK 2]${NC} Required files present"

required_files=(
    "Dockerfile"
    "build.sh"
    "openssl.cnf"
    "docker-entrypoint.sh"
    "test-fips.c"
    "fips-startup-check.c"
    "wolfssl_password.txt"
    "$PATCH_FILE"
)

for file in "${required_files[@]}"; do
    if [[ -f "$file" ]]; then
        check_pass "File exists: $file"
    else
        check_fail "File missing: $file"
    fi
done
echo ""

################################################################################
# Check 3: Password file validation
################################################################################
echo -e "${BLUE}[CHECK 3]${NC} wolfSSL password file validation"

if [[ -f "wolfssl_password.txt" ]]; then
    if [[ -s "wolfssl_password.txt" ]]; then
        if grep -q "your-wolfssl-commercial-password-here" wolfssl_password.txt; then
            check_fail "Password file contains template text"
            echo -e "  ${YELLOW}Action required:${NC} Replace with actual wolfSSL commercial password"
            echo -e "  ${YELLOW}Edit:${NC} wolfssl_password.txt"
        else
            check_pass "Password file configured"
        fi
    else
        check_fail "Password file is empty"
    fi
else
    check_fail "Password file not found"
fi
echo ""

################################################################################
# Check 4: Dockerfile syntax
################################################################################
echo -e "${BLUE}[CHECK 4]${NC} Dockerfile syntax validation"

if [[ -f "Dockerfile" ]]; then
    # Check for common syntax issues
    if grep -q "^FROM " Dockerfile; then
        check_pass "Dockerfile has valid FROM statement"
    else
        check_fail "Dockerfile missing FROM statement"
    fi

    if grep -q "COPY.*redis-fips-sha256.patch" Dockerfile; then
        check_pass "Dockerfile references FIPS patch"
    else
        check_fail "Dockerfile doesn't copy FIPS patch"
    fi

    if grep -q "patch -p1" Dockerfile; then
        check_pass "Dockerfile applies patch"
    else
        check_warn "Dockerfile may not apply patch"
    fi

    # Check file references
    missing_refs=false
    for file in openssl.cnf docker-entrypoint.sh test-fips.c fips-startup-check.c; do
        if grep -q "COPY.*$file" Dockerfile; then
            check_pass "Dockerfile references: $file"
        else
            check_fail "Dockerfile missing reference: $file"
            missing_refs=true
        fi
    done
else
    check_fail "Dockerfile not found"
fi
echo ""

################################################################################
# Check 5: Script permissions
################################################################################
echo -e "${BLUE}[CHECK 5]${NC} Script file permissions"

executable_files=(
    "build.sh"
    "docker-entrypoint.sh"
)

for file in "${executable_files[@]}"; do
    if [[ -f "$file" ]]; then
        if [[ -x "$file" ]]; then
            check_pass "Executable: $file"
        else
            check_warn "Not executable: $file (chmod +x $file)"
        fi
    fi
done
echo ""

################################################################################
# Check 6: Patch file validation
################################################################################
echo -e "${BLUE}[CHECK 6]${NC} Patch file validation"

if [[ -f "$PATCH_FILE" ]]; then
    # Check patch file size
    patch_size=$(wc -c < "$PATCH_FILE")
    if [[ $patch_size -gt 1000 ]]; then
        check_pass "Patch file size: $patch_size bytes"
    else
        check_warn "Patch file seems small: $patch_size bytes"
    fi

    # Check patch format
    if grep -q "^diff --git" "$PATCH_FILE"; then
        check_pass "Patch has git diff format"
    else
        check_warn "Patch format may not be git diff"
    fi

    # Check expected files are patched
    expected_patches=("src/debug.c" "src/eval.c" "src/server.h")
    for expected in "${expected_patches[@]}"; do
        if grep -q "$expected" "$PATCH_FILE"; then
            check_pass "Patch modifies: $expected"
        else
            check_fail "Patch missing modification: $expected"
        fi
    done
else
    check_fail "Patch file not found: $PATCH_FILE"
fi
echo ""

################################################################################
# Check 7: Full test - Download Redis and test patch (optional)
################################################################################
if [[ "$FULL_TEST" == "true" ]]; then
    echo -e "${BLUE}[CHECK 7]${NC} Redis source download and patch test"

    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT

    check_info "Downloading Redis $REDIS_VERSION source..."
    if wget -q -O "$TEMP_DIR/redis-${REDIS_VERSION}.tar.gz" \
        "http://download.redis.io/releases/redis-${REDIS_VERSION}.tar.gz" 2>&1; then
        check_pass "Redis source downloaded"

        check_info "Extracting source..."
        if tar -xzf "$TEMP_DIR/redis-${REDIS_VERSION}.tar.gz" -C "$TEMP_DIR" 2>&1; then
            check_pass "Redis source extracted"

            check_info "Testing patch application..."
            cd "$TEMP_DIR/redis-${REDIS_VERSION}"

            if patch -p1 --dry-run < "$OLDPWD/$PATCH_FILE" > /dev/null 2>&1; then
                check_pass "Patch applies cleanly (dry-run)"

                # Show what files will be modified
                check_info "Files to be modified:"
                patch -p1 --dry-run < "$OLDPWD/$PATCH_FILE" 2>&1 | grep "^patching" | while read line; do
                    echo -e "  ${GREEN}✓${NC} $line"
                done
            else
                check_fail "Patch does not apply cleanly"
                echo -e "  ${RED}Patch output:${NC}"
                patch -p1 --dry-run < "$OLDPWD/$PATCH_FILE" 2>&1 | head -20
            fi

            cd - > /dev/null
        else
            check_fail "Failed to extract Redis source"
        fi
    else
        check_fail "Failed to download Redis source"
    fi

    echo ""
fi

################################################################################
# Summary
################################################################################
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Validation Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Total checks: $TOTAL_CHECKS"
echo -e "${GREEN}Passed: $PASSED_CHECKS${NC}"
if [[ $FAILED_CHECKS -gt 0 ]]; then
    echo -e "${RED}Failed: $FAILED_CHECKS${NC}"
fi
if [[ $WARNINGS -gt 0 ]]; then
    echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
fi
echo ""

################################################################################
# Blockers and recommendations
################################################################################
if [[ $FAILED_CHECKS -gt 0 ]]; then
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}BLOCKERS DETECTED${NC}"
    echo -e "${RED}========================================${NC}"
    echo -e "The build ${RED}WILL FAIL${NC} with the current configuration."
    echo ""
    echo -e "${YELLOW}Required actions:${NC}"

    if grep -q "your-wolfssl-commercial-password-here" wolfssl_password.txt 2>/dev/null; then
        echo -e "  1. ${YELLOW}Set wolfSSL password:${NC}"
        echo -e "     echo 'your-actual-password' > wolfssl_password.txt"
        echo -e "     chmod 600 wolfssl_password.txt"
        echo ""
    fi

    echo -e "  2. Fix failed checks listed above"
    echo ""
    exit 1
else
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✓ PRE-BUILD VALIDATION PASSED${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""

    if [[ $WARNINGS -gt 0 ]]; then
        echo -e "${YELLOW}Note: $WARNINGS warning(s) detected but build should proceed${NC}"
        echo ""
    fi

    echo -e "${BLUE}Ready to build!${NC}"
    echo ""
    echo -e "To build the image:"
    echo -e "  ${GREEN}./build.sh${NC}"
    echo ""
    echo -e "Or with manual Docker command:"
    echo -e "  ${GREEN}DOCKER_BUILDKIT=1 docker build --secret id=wolfssl_password,src=wolfssl_password.txt -t cr.root.io/redis:7.2.4-alpine-fips .${NC}"
    echo ""

    if [[ "$FULL_TEST" != "true" ]]; then
        echo -e "${BLUE}Tip:${NC} Run with ${YELLOW}--full${NC} to test patch application:"
        echo -e "  ./test-build.sh --full"
        echo ""
    fi

    exit 0
fi
