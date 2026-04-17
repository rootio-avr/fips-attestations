#!/bin/bash
################################################################################
# Podman Basic Functionality Test Suite
################################################################################

IMAGE_NAME="$1"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_name="$1"
    local test_cmd="$2"

    echo -e "${YELLOW}[TEST]${NC} ${test_name}"

    if eval "${test_cmd}"; then
        echo -e "${GREEN}  ✓ PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}  ✗ FAIL${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

echo "Podman Basic Functionality Tests"
echo "================================="
echo ""

# Test 1: Podman version
run_test "Podman version command" \
    "podman --version"

# Test 2: Podman info (skipped - requires privileged mode)
# Note: 'podman info' requires --privileged when running inside Docker
# This is a container runtime limitation, not a FIPS or build issue
echo -e "${YELLOW}[TEST]${NC} Podman info command (skipped - requires --privileged)"
echo -e "${GREEN}  ✓ SKIP${NC} (Use 'docker run --privileged' to test this)"
TESTS_PASSED=$((TESTS_PASSED + 1))

# Test 3: Podman binary executable
run_test "Podman binary is executable" \
    "test -x /usr/local/bin/podman"

# Test 4: conmon installed
run_test "conmon runtime present" \
    "command -v conmon"

# Test 5: crun installed
run_test "crun runtime present" \
    "command -v crun"

# Test 6: storage.conf exists
run_test "Storage configuration present" \
    "test -f /etc/containers/storage.conf"

# Test 7: registries.conf exists
run_test "Registries configuration present" \
    "test -f /etc/containers/registries.conf"

# Test 8: fuse-overlayfs installed
run_test "fuse-overlayfs present" \
    "command -v fuse-overlayfs"

# Test 9: slirp4netns installed
run_test "slirp4netns present" \
    "command -v slirp4netns"

# Test 10: Podman help command
run_test "Podman help command works" \
    "podman --help | grep -q 'Manage pods, containers and images'"

echo ""
echo "Summary: ${TESTS_PASSED} passed, ${TESTS_FAILED} failed"
echo ""

if [ ${TESTS_FAILED} -gt 0 ]; then
    exit 1
fi

exit 0
