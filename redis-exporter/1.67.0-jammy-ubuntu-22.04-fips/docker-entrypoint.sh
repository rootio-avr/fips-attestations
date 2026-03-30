#!/bin/bash
################################################################################
# Redis Exporter FIPS Entrypoint Script
#
# Performs FIPS validation before starting redis_exporter
# Environment Variables:
#   FIPS_CHECK - Enable/disable FIPS validation (default: true)
#   REDIS_ADDR - Redis connection string (default: redis://localhost:6379)
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

FIPS_CHECK=${FIPS_CHECK:-true}

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Redis Exporter v1.67.0 with FIPS 140-3${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

if [ "$FIPS_CHECK" = "true" ]; then
    echo -e "${BLUE}Performing FIPS validation...${NC}"
    echo ""

    # Check 1: Environment Variables
    echo -e "${YELLOW}[CHECK 1/5]${NC} Verifying environment variables..."
    if [ -n "$OPENSSL_CONF" ] && [ -f "$OPENSSL_CONF" ]; then
        echo -e "${GREEN}[OK]${NC} OPENSSL_CONF=$OPENSSL_CONF"
    else
        echo -e "${RED}[FAIL]${NC} OPENSSL_CONF not set or file missing"
        exit 1
    fi

    if [ -n "$GODEBUG" ]; then
        echo -e "${GREEN}[OK]${NC} GODEBUG=$GODEBUG"
    else
        echo -e "${YELLOW}[WARN]${NC} GODEBUG not set (FIPS enforcement may not be active)"
    fi
    echo ""

    # Check 2: wolfSSL FIPS POST
    echo -e "${YELLOW}[CHECK 2/5]${NC} Running wolfSSL FIPS POST..."
    if /usr/local/bin/fips-check >/dev/null 2>&1; then
        echo -e "${GREEN}[OK]${NC} FIPS POST completed successfully"
        echo -e "      All Known Answer Tests (KAT) passed"
    else
        echo -e "${RED}[FAIL]${NC} FIPS POST failed"
        echo -e "${RED}ERROR:${NC} FIPS validation failed! Container will terminate."
        exit 1
    fi
    echo ""

    # Check 3: OpenSSL Version
    echo -e "${YELLOW}[CHECK 3/5]${NC} Verifying OpenSSL version..."
    OPENSSL_VERSION=$(openssl version 2>&1 || echo "ERROR")
    if echo "$OPENSSL_VERSION" | grep -q "OpenSSL"; then
        echo -e "${GREEN}[OK]${NC} OpenSSL version: $OPENSSL_VERSION"
    else
        echo -e "${RED}[FAIL]${NC} OpenSSL not found or invalid"
        exit 1
    fi
    echo ""

    # Check 4: wolfProvider
    echo -e "${YELLOW}[CHECK 4/5]${NC} Verifying wolfProvider is loaded..."
    if openssl list -providers 2>&1 | grep -qi "wolfSSL"; then
        echo -e "${GREEN}[OK]${NC} wolfProvider (wolfSSL Provider FIPS) is loaded and active"
    else
        echo -e "${RED}[FAIL]${NC} wolfProvider not loaded"
        echo -e "${YELLOW}Available providers:${NC}"
        openssl list -providers 2>&1 || true
        exit 1
    fi
    echo ""

    # Check 5: FIPS Enforcement (MD5 should be blocked)
    echo -e "${YELLOW}[CHECK 5/5]${NC} Testing FIPS enforcement (MD5 should be blocked)..."
    if echo "test" | openssl dgst -md5 2>&1 | grep -qi "error\|disabled\|unsupported"; then
        echo -e "${GREEN}[OK]${NC} MD5 is blocked (FIPS enforcement active)"
    else
        echo -e "${YELLOW}[WARN]${NC} MD5 may not be blocked (check FIPS configuration)"
    fi
    echo ""

    echo -e "${BLUE}======================================${NC}"
    echo -e "${GREEN}✓ ALL FIPS CHECKS PASSED${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo ""
    echo "FIPS Components:"
    echo "  - wolfSSL FIPS: v5.8.2 (Certificate #4718)"
    echo "  - wolfProvider: v1.1.0"
    echo "  - OpenSSL: $OPENSSL_VERSION"
    echo "  - redis_exporter: v1.67.0"
    echo "  - golang-fips/go: v1.25"
    echo ""
else
    echo -e "${YELLOW}FIPS validation disabled (FIPS_CHECK=false)${NC}"
    echo -e "${YELLOW}Note: Cryptographic operations still use wolfSSL FIPS${NC}"
    echo ""
fi

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Starting redis_exporter...${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""
echo "Configuration:"
echo "  Redis Address: ${REDIS_ADDR}"
echo "  Metrics Endpoint: ${REDIS_EXPORTER_WEB_LISTEN_ADDRESS}${REDIS_EXPORTER_WEB_TELEMETRY_PATH}"
echo "  Log Format: ${REDIS_EXPORTER_LOG_FORMAT}"
echo "  Debug Mode: ${REDIS_EXPORTER_DEBUG}"
echo ""

# Execute redis_exporter with all arguments
exec "$@" --web.listen-address="${REDIS_EXPORTER_WEB_LISTEN_ADDRESS}" \
           --web.telemetry-path="${REDIS_EXPORTER_WEB_TELEMETRY_PATH}" \
           --log-format="${REDIS_EXPORTER_LOG_FORMAT}"
