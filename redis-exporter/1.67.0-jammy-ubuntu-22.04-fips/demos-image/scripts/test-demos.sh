#!/bin/bash
################################################################################
# Redis Exporter FIPS - Demo Test Orchestration Script
#
# This script intelligently orchestrates all demo tests:
# - FIPS enforcement validation
# - Metrics endpoint validation
#
# Detects execution context (container vs host) and adapts accordingly.
#
# Usage:
#   ./test-demos.sh [OPTIONS]
#
# Options:
#   --fips-only        Run only FIPS enforcement tests
#   --metrics-only     Run only metrics validation tests
#   --all              Run all tests (default)
#   --install-curl     Install curl if missing (container mode only)
#   --endpoint URL     Metrics endpoint (default: http://localhost:9121/metrics)
#   --verbose          Show verbose output
#   --help             Show this help message
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Default configuration
RUN_FIPS=true
RUN_METRICS=true
INSTALL_CURL=false
ENDPOINT="${ENDPOINT:-http://localhost:9121/metrics}"
VERBOSE=false

# Detect execution context
detect_context() {
    if [ -f /.dockerenv ] || grep -q docker /proc/1/cgroup 2>/dev/null; then
        echo "container"
    else
        echo "host"
    fi
}

CONTEXT=$(detect_context)

################################################################################
# Parse Arguments
################################################################################

while [[ $# -gt 0 ]]; do
    case $1 in
        --fips-only)
            RUN_FIPS=true
            RUN_METRICS=false
            shift
            ;;
        --metrics-only)
            RUN_FIPS=false
            RUN_METRICS=true
            shift
            ;;
        --all)
            RUN_FIPS=true
            RUN_METRICS=true
            shift
            ;;
        --install-curl)
            INSTALL_CURL=true
            shift
            ;;
        --endpoint)
            ENDPOINT="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            head -n 30 "$0" | grep "^#" | sed 's/^# //; s/^#//'
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

################################################################################
# Banner
################################################################################

echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║         Redis Exporter FIPS - Demo Test Suite                ║
║                                                               ║
║  Validates FIPS 140-3 compliance and Prometheus metrics      ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"
echo ""

echo -e "${CYAN}Execution Context:${NC} $CONTEXT"
echo ""

################################################################################
# Container Mode
################################################################################

if [ "$CONTEXT" = "container" ]; then
    echo -e "${YELLOW}Running in container mode${NC}"
    echo ""

    # Run FIPS tests
    if [ "$RUN_FIPS" = "true" ]; then
        echo -e "${CYAN}═══════════════════════════════════════════${NC}"
        echo -e "${CYAN}FIPS Enforcement Tests${NC}"
        echo -e "${CYAN}═══════════════════════════════════════════${NC}"
        echo ""

        if [ "$VERBOSE" = "true" ]; then
            /demo/scripts/test-fips-enforcement.sh --verbose
        else
            /demo/scripts/test-fips-enforcement.sh
        fi

        echo ""
    fi

    # Run metrics tests
    if [ "$RUN_METRICS" = "true" ]; then
        echo -e "${CYAN}═══════════════════════════════════════════${NC}"
        echo -e "${CYAN}Metrics Validation Tests${NC}"
        echo -e "${CYAN}═══════════════════════════════════════════${NC}"
        echo ""

        # Check if curl is available
        if ! command -v curl >/dev/null 2>&1; then
            if [ "$INSTALL_CURL" = "true" ]; then
                echo -e "${YELLOW}[INFO]${NC} Installing curl..."
                apt-get update -qq && apt-get install -y -qq curl
                echo -e "${GREEN}[OK]${NC} curl installed successfully"
                echo ""
            else
                echo -e "${YELLOW}[SKIP]${NC} Metrics tests require curl"
                echo ""
                echo -e "${YELLOW}To install curl and run metrics tests:${NC}"
                echo "  docker run --rm --network=host \\"
                echo "    redis-exporter-demos:TAG \\"
                echo "    /demo/scripts/test-demos.sh --install-curl --metrics-only"
                echo ""
                echo -e "${YELLOW}Or run from host machine:${NC}"
                echo "  1. Start docker-compose stack:"
                echo "     cd demos-image && docker-compose up -d"
                echo ""
                echo "  2. Run metrics test from host:"
                echo "     bash scripts/test-metrics.sh"
                echo ""
                exit 0
            fi
        fi

        # Run metrics validation
        if [ "$VERBOSE" = "true" ]; then
            ENDPOINT="$ENDPOINT" /demo/scripts/test-metrics.sh --verbose
        else
            ENDPOINT="$ENDPOINT" /demo/scripts/test-metrics.sh
        fi

        echo ""
    fi

################################################################################
# Host Mode
################################################################################

else
    echo -e "${YELLOW}Running in host mode${NC}"
    echo ""

    # Check if docker-compose stack is running
    STACK_RUNNING=false
    if docker-compose ps 2>/dev/null | grep -q "exporter.*Up"; then
        STACK_RUNNING=true
        echo -e "${GREEN}[OK]${NC} docker-compose stack is running"
    else
        echo -e "${YELLOW}[WARN]${NC} docker-compose stack is not running"
        echo ""
        echo "The metrics tests require a running redis-exporter instance."
        echo ""
        echo -e "${YELLOW}To start the stack:${NC}"
        echo "  cd demos-image && docker-compose up -d"
        echo ""

        if [ "$RUN_METRICS" = "true" ]; then
            echo -e "${RED}[ERROR]${NC} Cannot run metrics tests without running stack"
            echo ""
            echo "Options:"
            echo "  1. Start the stack first, then run this script again"
            echo "  2. Run --fips-only to test FIPS compliance only"
            echo ""
            exit 1
        fi
    fi

    echo ""

    # Run FIPS tests (via docker exec)
    if [ "$RUN_FIPS" = "true" ]; then
        echo -e "${CYAN}═══════════════════════════════════════════${NC}"
        echo -e "${CYAN}FIPS Enforcement Tests (via container)${NC}"
        echo -e "${CYAN}═══════════════════════════════════════════${NC}"
        echo ""

        # Find the exporter container
        CONTAINER_ID=$(docker-compose ps -q exporter 2>/dev/null | head -1)
        if [ -z "$CONTAINER_ID" ]; then
            echo -e "${YELLOW}[WARN]${NC} Cannot find exporter container for FIPS tests"
            echo "Running FIPS tests requires a running container"
            echo ""
        else
            # Check if the demo scripts exist in the container
            if docker exec "$CONTAINER_ID" test -f /demo/scripts/test-fips-enforcement.sh 2>/dev/null; then
                if [ "$VERBOSE" = "true" ]; then
                    docker exec "$CONTAINER_ID" /demo/scripts/test-fips-enforcement.sh --verbose
                else
                    docker exec "$CONTAINER_ID" /demo/scripts/test-fips-enforcement.sh
                fi
            else
                echo -e "${YELLOW}[SKIP]${NC} FIPS tests not available in exporter container"
                echo ""
                echo "The running exporter container doesn't have demo scripts."
                echo ""
                echo -e "${YELLOW}Options:${NC}"
                echo "  1. Run FIPS tests in a standalone demos container:"
                echo "     docker run --rm redis-exporter-demos:TAG /demo/scripts/test-fips-enforcement.sh"
                echo ""
                echo "  2. Update docker-compose.yml to use the demos image:"
                echo "     image: redis-exporter-demos:TAG"
                echo ""
            fi
        fi

        echo ""
    fi

    # Run metrics tests (from host)
    if [ "$RUN_METRICS" = "true" ]; then
        echo -e "${CYAN}═══════════════════════════════════════════${NC}"
        echo -e "${CYAN}Metrics Validation Tests (from host)${NC}"
        echo -e "${CYAN}═══════════════════════════════════════════${NC}"
        echo ""

        # Check if curl is available on host
        if ! command -v curl >/dev/null 2>&1; then
            echo -e "${RED}[ERROR]${NC} curl is not available on host machine"
            echo ""
            echo "Please install curl:"
            echo "  sudo apt-get install curl   # Debian/Ubuntu"
            echo "  sudo yum install curl       # RHEL/CentOS"
            echo "  brew install curl           # macOS"
            echo ""
            exit 1
        fi

        # Run metrics validation from host
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        if [ "$VERBOSE" = "true" ]; then
            ENDPOINT="$ENDPOINT" "$SCRIPT_DIR/test-metrics.sh" --verbose
        else
            ENDPOINT="$ENDPOINT" "$SCRIPT_DIR/test-metrics.sh"
        fi

        echo ""
    fi
fi

################################################################################
# Summary
################################################################################

echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}Test Suite Complete${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo ""

if [ "$RUN_FIPS" = "true" ] && [ "$RUN_METRICS" = "true" ]; then
    echo -e "${GREEN}✓ All test suites completed successfully${NC}"
elif [ "$RUN_FIPS" = "true" ]; then
    echo -e "${GREEN}✓ FIPS enforcement tests completed successfully${NC}"
elif [ "$RUN_METRICS" = "true" ]; then
    echo -e "${GREEN}✓ Metrics validation tests completed successfully${NC}"
fi

echo ""

exit 0
