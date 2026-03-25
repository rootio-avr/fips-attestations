#!/bin/bash
################################################################################
# Nginx FIPS Demo Configuration Tester
#
# This script demonstrates and tests all 4 FIPS demo configurations:
#   1. Reverse Proxy - HTTPS reverse proxy with FIPS TLS
#   2. Static Webserver - HTTPS static file serving with FIPS TLS
#   3. TLS Termination - SSL/TLS offloading (HTTPS→HTTP)
#   4. Strict FIPS - Maximum FIPS enforcement (TLS 1.3 only)
################################################################################

set -e

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

IMAGE_NAME="nginx-fips-demos:latest"
CONTAINER_NAME="nginx-fips-demo-test"

# Configuration details
declare -A CONFIGS
CONFIGS[reverse-proxy]="HTTPS Reverse Proxy|Proxies to httpbin.org|TLSv1.2 + TLSv1.3"
CONFIGS[static-webserver]="Static Webserver|Serves HTML files over HTTPS|TLSv1.2 + TLSv1.3"
CONFIGS[tls-termination]="TLS Termination|SSL offloading (HTTPS→HTTP)|TLSv1.2 + TLSv1.3"
CONFIGS[strict-fips]="Strict FIPS Mode|Maximum security enforcement|TLSv1.3 ONLY"

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
    sleep 1  # Give Docker time to fully remove the container
}

wait_for_nginx() {
    local max_attempts=30
    local attempt=0

    print_info "Waiting for Nginx to be ready..."
    while [ $attempt -lt $max_attempts ]; do
        if curl -k -s https://localhost:443/health > /dev/null 2>&1; then
            print_success "Nginx is ready"
            return 0
        fi
        sleep 1
        ((attempt++))
    done

    print_error "Nginx failed to start within 30 seconds"
    return 1
}

test_tls_version() {
    local version=$1
    local expected=$2  # "success" or "fail"

    local result
    result=$(echo "Q" | timeout 3 openssl s_client -connect localhost:443 -$version 2>&1) || true

    if echo "$RESULT" | grep -q "Cipher is (NONE)\|no suitable digest\|wrong version\|handshake failure"; then
        if [ "$expected" = "fail" ]; then
            print_success "$version blocked (as expected)"
        else
            print_error "$version blocked (unexpected)"
        fi
    elif echo "$result" | grep -qE "Cipher is [^(]"; then
        if [ "$expected" = "success" ]; then
            local cipher=$(echo "$result" | grep "Cipher is" | awk '{print $NF}')
            print_success "$version allowed - Cipher: $cipher"
        else
            print_error "$version allowed (should be blocked)"
        fi
    else
        print_info "$version - Unable to determine (may not be supported by client)"
    fi
}

################################################################################
# Test Configuration
################################################################################

test_config() {
    local config_name=$1
    local config_file="/opt/demos/configs/${config_name}.conf"

    IFS='|' read -r description purpose protocols <<< "${CONFIGS[$config_name]}"

    print_header "Testing: $description"
    echo "Purpose: $purpose"
    echo "Protocols: $protocols"
    echo ""

    # Stop any running container
    cleanup

    # Start container with specified config
    print_info "Starting container with $config_name configuration..."

    # Try with both ports, fall back to 443 only if 80 is in use
    if docker run -d \
        --name $CONTAINER_NAME \
        -p 80:80 \
        -p 443:443 \
        -v "$(pwd)/configs/${config_name}.conf:/etc/nginx/nginx.conf:ro" \
        $IMAGE_NAME > /dev/null 2>&1; then
        print_info "Container started with ports 80 and 443"
    else
        # Port 80 might be in use, remove failed container and try without it
        docker rm -f $CONTAINER_NAME 2>/dev/null || true
        sleep 1
        print_info "Port 80 in use, starting with port 443 only..."
        docker run -d \
            --name $CONTAINER_NAME \
            -p 443:443 \
            -v "$(pwd)/configs/${config_name}.conf:/etc/nginx/nginx.conf:ro" \
            $IMAGE_NAME > /dev/null
        print_info "Container started with port 443 only"
    fi

    if ! wait_for_nginx; then
        print_error "Failed to start Nginx"
        docker logs $CONTAINER_NAME
        return 1
    fi

    echo ""
    print_info "Running tests..."
    echo ""

    # Test 1: Health check
    echo "[1/5] Health Check"
    if curl -k -s https://localhost:443/health | grep -q "Healthy"; then
        print_success "Health check passed"
    else
        print_error "Health check failed"
    fi

    # Test 2: TLS 1.3 support
    echo ""
    echo "[2/5] TLS 1.3 Support"
    test_tls_version "tls1_3" "success"

    # Test 3: TLS 1.2 support (depends on config)
    echo ""
    echo "[3/5] TLS 1.2 Support"
    if [ "$config_name" = "strict-fips" ]; then
        test_tls_version "tls1_2" "fail"
    else
        test_tls_version "tls1_2" "success"
    fi

    # Test 4: Old protocols blocked
    echo ""
    echo "[4/5] Legacy Protocols (should be blocked)"
    test_tls_version "tls1" "fail"
    test_tls_version "tls1_1" "fail"

    # Test 5: Configuration-specific tests
    echo ""
    echo "[5/5] Configuration-Specific Tests"
    case $config_name in
        reverse-proxy)
            if curl -k -s https://localhost:443/ | grep -q "httpbin"; then
                print_success "Reverse proxy to httpbin.org working"
            else
                print_error "Reverse proxy test failed"
            fi
            ;;
        static-webserver)
            if curl -k -s https://localhost:443/ | grep -q "html"; then
                print_success "Static file serving working"
            else
                print_error "Static file serving failed"
            fi
            ;;
        tls-termination)
            if curl -k -s https://localhost:443/ssl-info | grep -q "SSL Protocol"; then
                print_success "TLS termination info endpoint working"
            else
                print_error "TLS termination test failed"
            fi
            ;;
        strict-fips)
            if curl -k -s https://localhost:443/fips-info | grep -q "FIPS Mode: Strict"; then
                print_success "Strict FIPS mode confirmed"
            else
                print_error "Strict FIPS verification failed"
            fi
            # Test HTTP rejection (only if port 80 is exposed)
            if docker port $CONTAINER_NAME 80 > /dev/null 2>&1; then
                if curl -s http://localhost:80/ 2>&1 | grep -q "426\|HTTPS Required"; then
                    print_success "HTTP connections properly rejected (426 status)"
                else
                    print_info "HTTP rejection test inconclusive"
                fi
            else
                print_info "HTTP port not exposed (port 80 in use by another service)"
            fi
            ;;
    esac

    # Show cipher details
    echo ""
    print_info "Cipher Information:"
    echo "Q" | timeout 3 openssl s_client -connect localhost:443 -tls1_3 2>&1 | \
        grep -E "(Protocol|Cipher)" | head -2 | sed 's/^/  /'

    echo ""
    print_success "Test completed for $config_name"

    # Pause to allow review
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
    print_header "Nginx FIPS Demo Configuration Tester"

    echo "Available Demo Configurations:"
    echo ""
    echo "  1) Reverse Proxy      - HTTPS reverse proxy to backend"
    echo "  2) Static Webserver   - HTTPS static file serving"
    echo "  3) TLS Termination    - SSL/TLS offloading"
    echo "  4) Strict FIPS        - Maximum FIPS enforcement (TLS 1.3 only)"
    echo ""
    echo "  5) Test ALL           - Run all tests sequentially"
    echo "  6) Cleanup & Exit     - Stop containers and exit"
    echo ""
}

interactive_mode() {
    while true; do
        show_menu
        read -p "Select an option (1-6): " choice

        case $choice in
            1)
                INTERACTIVE=true
                test_config "reverse-proxy"
                ;;
            2)
                INTERACTIVE=true
                test_config "static-webserver"
                ;;
            3)
                INTERACTIVE=true
                test_config "tls-termination"
                ;;
            4)
                INTERACTIVE=true
                test_config "strict-fips"
                ;;
            5)
                INTERACTIVE=false
                for config in reverse-proxy static-webserver tls-termination strict-fips; do
                    test_config "$config"
                    sleep 2
                done
                echo ""
                print_header "All Tests Completed"
                read -p "Press Enter to return to menu..."
                ;;
            6)
                cleanup
                echo ""
                print_success "Cleanup completed. Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid option. Please select 1-6."
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
        reverse-proxy|static-webserver|tls-termination|strict-fips)
            INTERACTIVE=false
            test_config "$1"
            cleanup
            ;;
        all)
            INTERACTIVE=false
            for config in reverse-proxy static-webserver tls-termination strict-fips; do
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
            echo "  reverse-proxy     - Test reverse proxy configuration"
            echo "  static-webserver  - Test static webserver configuration"
            echo "  tls-termination   - Test TLS termination configuration"
            echo "  strict-fips       - Test strict FIPS configuration"
            echo "  all               - Test all configurations"
            echo ""
            echo "Or run without arguments for interactive mode"
            exit 1
            ;;
    esac
fi
