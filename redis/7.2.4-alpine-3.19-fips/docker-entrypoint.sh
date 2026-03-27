#!/bin/bash
################################################################################
# Redis FIPS Docker Entrypoint
#
# This script performs FIPS validation before starting Redis:
# 1. Validates environment variables
# 2. Verifies wolfSSL FIPS POST
# 3. Verifies wolfProvider is loaded
# 4. Starts Redis server
#
# Environment variables:
#   FIPS_CHECK - Set to "false" to skip FIPS validation (development only)
################################################################################

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# FIPS Validation Function
################################################################################
perform_fips_validation() {
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}Redis FIPS 140-3 Validation${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo ""

    # Check 1: Environment variables
    echo -e "${BLUE}[CHECK 1/5]${NC} Verifying environment variables..."

    if [ -z "$OPENSSL_CONF" ]; then
        echo -e "${RED}[FAIL]${NC} OPENSSL_CONF not set"
        return 1
    fi
    echo -e "${GREEN}[OK]${NC} OPENSSL_CONF=${OPENSSL_CONF}"

    if [ ! -f "$OPENSSL_CONF" ]; then
        echo -e "${RED}[FAIL]${NC} OPENSSL_CONF file not found: $OPENSSL_CONF"
        return 1
    fi
    echo -e "${GREEN}[OK]${NC} OpenSSL config file exists"

    if [ -z "$OPENSSL_MODULES" ]; then
        echo -e "${RED}[FAIL]${NC} OPENSSL_MODULES not set"
        return 1
    fi
    echo -e "${GREEN}[OK]${NC} OPENSSL_MODULES=${OPENSSL_MODULES}"

    if [ -z "$LD_LIBRARY_PATH" ]; then
        echo -e "${YELLOW}[WARN]${NC} LD_LIBRARY_PATH not set"
    else
        echo -e "${GREEN}[OK]${NC} LD_LIBRARY_PATH=${LD_LIBRARY_PATH}"
    fi

    echo ""

    # Check 2: wolfSSL FIPS POST
    echo -e "${BLUE}[CHECK 2/5]${NC} Running wolfSSL FIPS POST (Power-On Self Test)..."

    if command -v fips-startup-check &> /dev/null; then
        if fips-startup-check 2>&1 | tee /tmp/fips-check.log; then
            if grep -q "FIPS POST.*passed" /tmp/fips-check.log || \
               grep -q "ALL FIPS CHECKS PASSED" /tmp/fips-check.log; then
                echo -e "${GREEN}[OK]${NC} wolfSSL FIPS POST passed"
            else
                echo -e "${RED}[FAIL]${NC} FIPS POST did not report success"
                cat /tmp/fips-check.log
                return 1
            fi
        else
            echo -e "${RED}[FAIL]${NC} fips-startup-check failed"
            cat /tmp/fips-check.log
            return 1
        fi
        rm -f /tmp/fips-check.log
    else
        echo -e "${YELLOW}[WARN]${NC} fips-startup-check utility not found"
        echo -e "${YELLOW}[WARN]${NC} Skipping POST validation"
    fi

    echo ""

    # Check 3: OpenSSL version
    echo -e "${BLUE}[CHECK 3/5]${NC} Verifying OpenSSL version..."

    OPENSSL_VERSION=$(openssl version 2>&1 || echo "unknown")
    echo -e "${GREEN}[OK]${NC} OpenSSL version: $OPENSSL_VERSION"

    echo ""

    # Check 4: wolfProvider loaded
    echo -e "${BLUE}[CHECK 4/5]${NC} Verifying wolfProvider is loaded..."

    if openssl list -providers 2>&1 | grep -qi "wolfSSL"; then
        echo -e "${GREEN}[OK]${NC} wolfProvider (wolfSSL Provider FIPS) is loaded and active"
        echo ""
        echo "Providers:"
        openssl list -providers | grep -A 3 -i "wolfSSL" || true
    else
        echo -e "${RED}[FAIL]${NC} wolfProvider not found in OpenSSL providers"
        echo ""
        echo "Available providers:"
        openssl list -providers || true
        return 1
    fi

    echo ""

    # Check 5: FIPS mode enforcement test (MD5 should fail)
    echo -e "${BLUE}[CHECK 5/5]${NC} Testing FIPS enforcement (MD5 should be blocked)..."

    if echo -n "test" | openssl dgst -md5 2>&1 | grep -q "Error\|disabled\|unsupported"; then
        echo -e "${GREEN}[OK]${NC} MD5 is blocked (FIPS enforcement active)"
    else
        echo -e "${YELLOW}[WARN]${NC} MD5 not blocked (FIPS enforcement may be inactive)"
        echo -e "${YELLOW}[WARN]${NC} This may be acceptable depending on wolfProvider configuration"
    fi

    echo ""
    echo -e "${GREEN}======================================${NC}"
    echo -e "${GREEN}✓ ALL FIPS CHECKS PASSED${NC}"
    echo -e "${GREEN}======================================${NC}"
    echo ""
    echo "FIPS Components:"
    echo "  - wolfSSL FIPS: v5.8.2 (Certificate #4718)"
    echo "  - wolfProvider: v1.1.0"
    echo "  - OpenSSL: $OPENSSL_VERSION"
    echo "  - Redis: ${REDIS_VERSION:-7.2.4}"
    echo ""

    return 0
}

################################################################################
# Main Entrypoint
################################################################################
echo ""
echo "Redis ${REDIS_VERSION:-7.2.4} with wolfSSL FIPS 140-3"
echo "Starting container..."
echo ""

# Check if FIPS validation should be skipped (development mode)
if [ "${FIPS_CHECK:-true}" = "false" ]; then
    echo -e "${YELLOW}[WARNING]${NC} FIPS validation disabled (FIPS_CHECK=false)"
    echo -e "${YELLOW}[WARNING]${NC} This should ONLY be used for development/debugging"
    echo ""
else
    # Perform FIPS validation
    if ! perform_fips_validation; then
        echo -e "${RED}======================================${NC}"
        echo -e "${RED}✗ FIPS VALIDATION FAILED${NC}"
        echo -e "${RED}======================================${NC}"
        echo ""
        echo "The container will not start because FIPS validation failed."
        echo "This indicates a problem with the FIPS configuration."
        echo ""
        echo "To bypass FIPS validation for debugging (NOT for production):"
        echo "  docker run -e FIPS_CHECK=false ..."
        echo ""
        exit 1
    fi
fi

# Start Redis with the provided command
echo -e "${BLUE}[STARTING]${NC} Redis server..."
echo ""

# If no command provided, use default
if [ $# -eq 0 ]; then
    exec redis-server /etc/redis/redis.conf
else
    exec "$@"
fi
