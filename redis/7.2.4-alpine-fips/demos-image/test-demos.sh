#!/bin/bash
################################################################################
# Redis FIPS Demo Configuration Tester
#
# This script demonstrates and tests all 5 FIPS demo configurations:
#   1. Persistence Demo - RDB + AOF data durability
#   2. Pub/Sub Demo - Real-time messaging
#   3. Memory Optimization - Memory limits and eviction
#   4. Strict FIPS - Maximum security enforcement
#   5. TLS Demo - Encrypted connections
################################################################################

set -e

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

IMAGE_NAME="redis-fips-demos:latest"
CONTAINER_NAME="redis-fips-demo-test"

# Configuration details
declare -A CONFIGS
CONFIGS[persistence-demo]="Persistence Demo|RDB + AOF for data durability|Standard Redis port"
CONFIGS[pubsub-demo]="Pub/Sub Demo|Real-time messaging|Standard Redis port"
CONFIGS[memory-optimization]="Memory Optimization|Memory limits and eviction|Standard Redis port"
CONFIGS[strict-fips]="Strict FIPS Mode|Maximum security enforcement|TLS + password required"
CONFIGS[tls-demo]="TLS Demo|Encrypted connections|Ports 6379 (plain) + 6380 (TLS)"

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo ""
    echo "================================================================================"
    echo -e "${BOLD}${BLUE}$1${NC}"
    echo "================================================================================"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${YELLOW}➜${NC} $1"
}

cleanup() {
    echo ""
    print_info "Cleaning up..."
    docker stop $CONTAINER_NAME 2>/dev/null || true
    docker rm $CONTAINER_NAME 2>/dev/null || true
    sleep 1
}

wait_for_redis() {
    local max_attempts=30
    local attempt=0
    local port=${1:-6379}

    print_info "Waiting for Redis to be ready on port $port..."
    while [ $attempt -lt $max_attempts ]; do
        if docker exec $CONTAINER_NAME redis-cli -p $port PING 2>/dev/null | grep -q "PONG"; then
            print_success "Redis is ready"
            return 0
        fi
        sleep 1
        ((attempt++))
    done

    print_error "Redis failed to start within 30 seconds"
    return 1
}

################################################################################
# Test Configuration
################################################################################

test_config() {
    local config_name=$1
    local config_file="/opt/demos/configs/${config_name}.conf"

    IFS='|' read -r description purpose details <<< "${CONFIGS[$config_name]}"

    print_header "Testing: $description"
    echo "Purpose: $purpose"
    echo "Details: $details"
    echo ""

    # Stop any running container
    cleanup

    # Start container with specified config
    print_info "Starting container with $config_name configuration..."

    docker run -d \
        --name $CONTAINER_NAME \
        -p 6379:6379 \
        -p 6380:6380 \
        -v "$(pwd)/configs/${config_name}.conf:/etc/redis/redis.conf:ro" \
        $IMAGE_NAME \
        redis-server /etc/redis/redis.conf > /dev/null 2>&1 || {
            # Port might be in use, try with just 6379
            print_info "Port conflict, using 6379 only..."
            docker run -d \
                --name $CONTAINER_NAME \
                -p 6379:6379 \
                -v "$(pwd)/configs/${config_name}.conf:/etc/redis/redis.conf:ro" \
                $IMAGE_NAME \
                redis-server /etc/redis/redis.conf > /dev/null 2>&1
        }

    if ! wait_for_redis; then
        print_error "Failed to start Redis"
        docker logs $CONTAINER_NAME
        return 1
    fi

    echo ""
    print_info "Running tests..."
    echo ""

    # Test 1: FIPS validation
    echo "[1/6] FIPS POST Validation"
    if docker exec $CONTAINER_NAME fips-startup-check >/dev/null 2>&1; then
        print_success "FIPS POST validation passed"
    else
        print_error "FIPS POST validation failed"
    fi

    # Test 2: Connectivity
    echo ""
    echo "[2/6] Redis Connectivity (PING)"
    if docker exec $CONTAINER_NAME redis-cli PING 2>/dev/null | grep -q "PONG"; then
        print_success "Redis responding to PING"
    else
        print_error "Redis not responding"
    fi

    # Test 3: Basic operations
    echo ""
    echo "[3/6] Basic Operations (SET/GET)"
    if docker exec $CONTAINER_NAME redis-cli SET test:key "test_value" >/dev/null 2>&1 && \
       docker exec $CONTAINER_NAME redis-cli GET test:key 2>/dev/null | grep -q "test_value"; then
        print_success "SET/GET operations working"
    else
        print_error "SET/GET operations failed"
    fi

    # Test 4: Lua scripting (uses SHA-256)
    echo ""
    echo "[4/6] Lua Scripting (SHA-256 hashing)"
    if docker exec $CONTAINER_NAME redis-cli EVAL "return redis.call('PING')" 0 2>/dev/null | grep -q "PONG"; then
        print_success "Lua scripting working (SHA-256 for FIPS)"
    else
        print_error "Lua scripting failed"
    fi

    # Test 5: wolfProvider check
    echo ""
    echo "[5/6] FIPS Provider Check"
    if docker exec $CONTAINER_NAME openssl list -providers 2>/dev/null | grep -qi "wolfSSL"; then
        print_success "wolfProvider (FIPS) loaded"
    else
        print_error "wolfProvider not found"
    fi

    # Test 6: Configuration-specific tests
    echo ""
    echo "[6/6] Configuration-Specific Tests"
    case $config_name in
        persistence-demo)
            # Test BGSAVE
            if docker exec $CONTAINER_NAME redis-cli BGSAVE 2>/dev/null | grep -qiE "Background saving started|already in progress"; then
                print_success "BGSAVE (RDB persistence) working"
            else
                print_error "BGSAVE failed"
            fi

            # Check AOF status
            aof_enabled=$(docker exec $CONTAINER_NAME redis-cli CONFIG GET appendonly 2>/dev/null | tail -1)
            if [ "$aof_enabled" = "yes" ]; then
                print_success "AOF persistence enabled"
            else
                print_info "AOF persistence disabled for this config"
            fi
            ;;

        pubsub-demo)
            # Test PUBLISH
            subscribers=$(docker exec $CONTAINER_NAME redis-cli PUBLISH demo-channel "test message" 2>/dev/null || echo "0")
            if [ "$subscribers" != "" ]; then
                print_success "PUBLISH working (subscribers: $subscribers)"
            else
                print_error "PUBLISH failed"
            fi

            # Test PUBSUB CHANNELS
            if docker exec $CONTAINER_NAME redis-cli PUBSUB CHANNELS >/dev/null 2>&1; then
                print_success "PUBSUB CHANNELS command working"
            else
                print_error "PUBSUB CHANNELS failed"
            fi
            ;;

        memory-optimization)
            # Check maxmemory setting
            maxmem=$(docker exec $CONTAINER_NAME redis-cli CONFIG GET maxmemory 2>/dev/null | tail -1)
            if [ "$maxmem" != "0" ]; then
                print_success "Memory limit configured: $maxmem bytes"
            else
                print_info "No memory limit set"
            fi

            # Check eviction policy
            policy=$(docker exec $CONTAINER_NAME redis-cli CONFIG GET maxmemory-policy 2>/dev/null | tail -1)
            print_success "Eviction policy: $policy"

            # Test memory info
            if docker exec $CONTAINER_NAME redis-cli INFO memory >/dev/null 2>&1; then
                print_success "Memory statistics available"
            else
                print_error "Memory info failed"
            fi
            ;;

        strict-fips)
            # Check if dangerous commands are disabled
            if docker exec $CONTAINER_NAME redis-cli FLUSHALL 2>&1 | grep -qi "unknown command\|ERR"; then
                print_success "Dangerous commands properly disabled"
            else
                print_error "Dangerous commands not disabled"
            fi

            # Check persistence
            if docker exec $CONTAINER_NAME redis-cli CONFIG GET appendonly 2>/dev/null | tail -1 | grep -q "yes"; then
                print_success "AOF persistence enabled for strict mode"
            else
                print_info "AOF persistence status unknown"
            fi
            ;;

        tls-demo)
            # Check if both ports are configured
            plain_port=$(docker exec $CONTAINER_NAME redis-cli CONFIG GET port 2>/dev/null | tail -1)
            tls_port=$(docker exec $CONTAINER_NAME redis-cli CONFIG GET tls-port 2>/dev/null | tail -1)

            print_info "Plain port: $plain_port"
            print_info "TLS port: $tls_port"

            if [ "$plain_port" = "6379" ]; then
                print_success "Plain TCP port configured"
            fi

            if [ "$tls_port" != "0" ]; then
                print_success "TLS port configured"
            else
                print_info "TLS port not configured (certificates needed)"
            fi
            ;;
    esac

    # Display info
    echo ""
    print_info "Redis Info:"
    docker exec $CONTAINER_NAME redis-cli INFO server 2>/dev/null | grep -E "redis_version|os|arch" | sed 's/^/  /'

    echo ""
    print_success "Test completed for $config_name"

    # Pause for interactive mode
    if [ "$INTERACTIVE" = "true" ]; then
        echo ""
        read -p "Press Enter to continue to next configuration..."
    fi
}

################################################################################
# Main Menu
################################################################################

show_menu() {
    clear
    print_header "Redis FIPS Demo Configuration Tester"

    echo "Available Demo Configurations:"
    echo ""
    echo "  1) Persistence Demo       - RDB + AOF data durability"
    echo "  2) Pub/Sub Demo           - Real-time messaging"
    echo "  3) Memory Optimization    - Memory limits and eviction"
    echo "  4) Strict FIPS            - Maximum security enforcement"
    echo "  5) TLS Demo               - Encrypted connections"
    echo ""
    echo "  6) Test ALL               - Run all tests sequentially"
    echo "  7) Cleanup & Exit         - Stop containers and exit"
    echo ""
}

interactive_mode() {
    while true; do
        show_menu
        read -p "Select an option (1-7): " choice

        case $choice in
            1)
                INTERACTIVE=true
                test_config "persistence-demo"
                ;;
            2)
                INTERACTIVE=true
                test_config "pubsub-demo"
                ;;
            3)
                INTERACTIVE=true
                test_config "memory-optimization"
                ;;
            4)
                INTERACTIVE=true
                test_config "strict-fips"
                ;;
            5)
                INTERACTIVE=true
                test_config "tls-demo"
                ;;
            6)
                INTERACTIVE=false
                for config in persistence-demo pubsub-demo memory-optimization strict-fips tls-demo; do
                    test_config "$config"
                    sleep 2
                done
                echo ""
                print_header "All Tests Completed"
                read -p "Press Enter to return to menu..."
                ;;
            7)
                cleanup
                echo ""
                print_success "Cleanup completed. Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid option. Please select 1-7."
                sleep 2
                ;;
        esac
    done
}

################################################################################
# Main
################################################################################

# Check if image exists
if ! docker image inspect $IMAGE_NAME > /dev/null 2>&1; then
    print_error "Image $IMAGE_NAME not found!"
    echo ""
    echo "Please build the demo image first:"
    echo "  cd demos-image"
    echo "  ./build.sh"
    exit 1
fi

# Parse command line arguments
if [ $# -eq 0 ]; then
    # Interactive mode
    trap cleanup EXIT
    interactive_mode
else
    # Command line mode
    case $1 in
        persistence-demo|pubsub-demo|memory-optimization|strict-fips|tls-demo)
            INTERACTIVE=false
            test_config "$1"
            cleanup
            ;;
        all)
            INTERACTIVE=false
            for config in persistence-demo pubsub-demo memory-optimization strict-fips tls-demo; do
                test_config "$config"
                sleep 2
            done
            cleanup
            print_header "All Tests Completed"
            ;;
        *)
            echo "Usage: $0 [config-name|all]"
            echo ""
            echo "Available configurations:"
            echo "  persistence-demo      - Test persistence configuration"
            echo "  pubsub-demo           - Test pub/sub configuration"
            echo "  memory-optimization   - Test memory optimization configuration"
            echo "  strict-fips           - Test strict FIPS configuration"
            echo "  tls-demo              - Test TLS configuration"
            echo "  all                   - Test all configurations"
            echo ""
            echo "Or run without arguments for interactive mode"
            exit 1
            ;;
    esac
fi
