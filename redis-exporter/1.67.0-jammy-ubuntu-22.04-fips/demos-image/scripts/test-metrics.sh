#!/bin/bash
################################################################################
# Redis Exporter FIPS - Metrics Validation Script
#
# This script validates the exported Prometheus metrics:
# - HTTP endpoint availability
# - Prometheus text format compliance
# - Expected metrics presence
# - Metric value sanity checks
# - Label correctness
#
# Usage:
#   ./test-metrics.sh [OPTIONS]
#
# Options:
#   --endpoint URL  Metrics endpoint (default: http://localhost:9121/metrics)
#   --verbose       Show verbose output
#   --help          Show this help message
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
ENDPOINT="${ENDPOINT:-http://localhost:9121/metrics}"
VERBOSE=false

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

################################################################################
# Parse Arguments
################################################################################

while [[ $# -gt 0 ]]; do
    case $1 in
        --endpoint)
            ENDPOINT="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            head -n 25 "$0" | grep "^#" | sed 's/^# //; s/^#//'
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

################################################################################
# Helper Functions
################################################################################

run_test() {
    local test_name="$1"
    local test_command="$2"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -n "  ✓ $test_name... "

    if eval "$test_command" >/dev/null 2>&1; then
        echo -e "${GREEN}[PASS]${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}[FAIL]${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        if [ "$VERBOSE" = "true" ]; then
            eval "$test_command" || true
        fi
        return 1
    fi
}

################################################################################
# Setup
################################################################################

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Metrics Validation${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Endpoint: $ENDPOINT"
echo ""

# Check if curl is available
if ! command -v curl >/dev/null 2>&1; then
    echo -e "${RED}[ERROR]${NC} curl is not available in this environment"
    echo ""
    echo -e "${YELLOW}Note:${NC} This script requires curl to test the metrics endpoint."
    echo ""
    echo -e "${YELLOW}To run this test:${NC}"
    echo "  1. Ensure docker-compose stack is running:"
    echo "     cd demos-image && docker-compose up -d"
    echo ""
    echo "  2. Run this script from the HOST machine (not in container):"
    echo "     bash scripts/test-metrics.sh"
    echo ""
    echo "  3. Or install curl in your environment"
    echo ""
    exit 1
fi

# Check if endpoint is reachable
echo -e "${YELLOW}Checking endpoint availability...${NC}"
if ! curl -s -o /dev/null -w "%{http_code}" "$ENDPOINT" --connect-timeout 5 --max-time 10 | grep -q "^[0-9]"; then
    echo -e "${RED}[ERROR]${NC} Cannot connect to $ENDPOINT"
    echo ""
    echo -e "${YELLOW}Possible issues:${NC}"
    echo "  1. redis-exporter is not running"
    echo "  2. Wrong endpoint URL"
    echo "  3. Network connectivity issue"
    echo ""
    echo -e "${YELLOW}To fix:${NC}"
    echo "  1. Start the docker-compose stack:"
    echo "     cd demos-image && docker-compose up -d"
    echo ""
    echo "  2. Wait for services to start:"
    echo "     sleep 10"
    echo ""
    echo "  3. Check service status:"
    echo "     docker-compose ps"
    echo ""
    echo "  4. Verify exporter is running:"
    echo "     curl http://localhost:9121/metrics | head -20"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓ Endpoint is reachable${NC}"
echo ""

# Fetch metrics once
METRICS_FILE=$(mktemp)
trap "rm -f $METRICS_FILE" EXIT

################################################################################
# Test Suite 1: HTTP Endpoint
################################################################################

echo -e "${YELLOW}[SUITE 1/5]${NC} HTTP Endpoint Tests"

# Test 1: Endpoint responds
run_test "HTTP 200 response" "curl -s -o /dev/null -w '%{http_code}' $ENDPOINT | grep -q '^200$'"

# Fetch metrics for remaining tests
if ! curl -s -o "$METRICS_FILE" "$ENDPOINT"; then
    echo -e "${RED}[ERROR]${NC} Failed to fetch metrics. Aborting."
    exit 1
fi

# Test 2: Response not empty
run_test "Response not empty" "test -s $METRICS_FILE"

# Test 3: Response time < 5s
run_test "Response time < 5s" "test \$(curl -s -o /dev/null -w '%{time_total}' $ENDPOINT | cut -d. -f1) -lt 5"

echo ""

################################################################################
# Test Suite 2: Prometheus Format
################################################################################

echo -e "${YELLOW}[SUITE 2/5]${NC} Prometheus Format Tests"

# Test 4: Contains HELP lines
run_test "Contains HELP lines" "grep -q '^# HELP' $METRICS_FILE"

# Test 5: Contains TYPE lines
run_test "Contains TYPE lines" "grep -q '^# TYPE' $METRICS_FILE"

# Test 6: Valid metric format
run_test "Valid metric format" "grep -E '^[a-zA-Z_:][a-zA-Z0-9_:]* ' $METRICS_FILE | head -1"

# Test 7: No malformed lines
run_test "No malformed lines" "! grep -E '^[^#a-zA-Z]' $METRICS_FILE | grep -v '^$'"

echo ""

################################################################################
# Test Suite 3: Core Metrics Presence
################################################################################

echo -e "${YELLOW}[SUITE 3/5]${NC} Core Metrics Presence"

# Test 8: redis_up
run_test "redis_up present" "grep -q '^redis_up ' $METRICS_FILE"

# Test 9: redis_connected_clients
run_test "redis_connected_clients present" "grep -q '^redis_connected_clients ' $METRICS_FILE"

# Test 10: redis_memory_used_bytes
run_test "redis_memory_used_bytes present" "grep -q '^redis_memory_used_bytes ' $METRICS_FILE"

# Test 11: redis_commands_total
run_test "redis_commands_total present" "grep -q '^redis_commands_total{' $METRICS_FILE"

# Test 12: redis_db_keys
run_test "redis_db_keys present" "grep -q '^redis_db_keys{' $METRICS_FILE"

# Test 13: redis_uptime_in_seconds
run_test "redis_uptime_in_seconds present" "grep -q '^redis_uptime_in_seconds ' $METRICS_FILE"

# Test 14: redis_exporter_build_info
run_test "redis_exporter_build_info present" "grep -q '^redis_exporter_build_info{' $METRICS_FILE"

echo ""

################################################################################
# Test Suite 4: Metric Value Sanity
################################################################################

echo -e "${YELLOW}[SUITE 4/5]${NC} Metric Value Sanity Tests"

# Test 15: redis_up is 0 or 1
REDIS_UP=$(grep '^redis_up ' "$METRICS_FILE" | awk '{print $2}')
run_test "redis_up is 0 or 1" "echo '$REDIS_UP' | grep -qE '^[01]$'"

# Test 16: redis_connected_clients is non-negative
CONNECTED_CLIENTS=$(grep '^redis_connected_clients ' "$METRICS_FILE" | awk '{print $2}')
run_test "redis_connected_clients >= 0" "test $(echo $CONNECTED_CLIENTS | cut -d. -f1) -ge 0"

# Test 17: redis_memory_used_bytes is positive
MEMORY_USED=$(grep '^redis_memory_used_bytes ' "$METRICS_FILE" | awk '{print $2}')
run_test "redis_memory_used_bytes > 0" "test $(echo $MEMORY_USED | cut -d. -f1) -gt 0"

# Test 18: redis_uptime_in_seconds is positive
UPTIME=$(grep '^redis_uptime_in_seconds ' "$METRICS_FILE" | awk '{print $2}')
run_test "redis_uptime_in_seconds > 0" "test $(echo $UPTIME | cut -d. -f1) -gt 0"

# Test 19: No NaN values
run_test "No NaN values" "! grep -w 'NaN' $METRICS_FILE"

# Test 20: No +Inf values (where inappropriate)
run_test "No inappropriate +Inf" "! grep '^redis_up .*Inf' $METRICS_FILE"

echo ""

################################################################################
# Test Suite 5: Label Correctness
################################################################################

echo -e "${YELLOW}[SUITE 5/5]${NC} Label Correctness Tests"

# Test 21: Labels have proper format
run_test "Labels format correct" "grep -E '{.*=\".*\"}' $METRICS_FILE | head -1"

# Test 22: No empty label values (except err="" which is expected when no error)
run_test "No empty label values" "! grep '=\"\"' $METRICS_FILE | grep -v 'err=\"\"'"

# Test 23: Consistent label usage
run_test "Consistent labels" "grep '^redis_commands_total{' $METRICS_FILE | grep -q 'cmd='"

echo ""

################################################################################
# Summary
################################################################################

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Metrics Validation Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo "Total Tests:  $TOTAL_TESTS"
echo -e "${GREEN}Passed:       $PASSED_TESTS${NC}"

if [ $FAILED_TESTS -gt 0 ]; then
    echo -e "${RED}Failed:       $FAILED_TESTS${NC}"
    echo ""
    echo -e "${RED}✗ SOME TESTS FAILED${NC}"
    exit 1
else
    echo "Failed:       $FAILED_TESTS"
    echo ""
    echo -e "${GREEN}✓ ALL TESTS PASSED${NC}"
fi

echo ""

################################################################################
# Metrics Summary
################################################################################

if [ "$VERBOSE" = "true" ]; then
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Metrics Summary${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    echo "Redis Status:"
    echo "  Up: $REDIS_UP"
    echo "  Connected clients: $CONNECTED_CLIENTS"
    echo "  Memory used: $MEMORY_USED bytes"
    echo "  Uptime: $UPTIME seconds"

    echo ""
    echo "Available Metrics:"
    grep -E '^# TYPE ' "$METRICS_FILE" | wc -l
    echo "  ($(grep -E '^# TYPE ' "$METRICS_FILE" | wc -l) metric types)"

    echo ""
    echo "Sample Metrics:"
    grep '^redis_' "$METRICS_FILE" | head -10

    echo ""
fi

exit 0
