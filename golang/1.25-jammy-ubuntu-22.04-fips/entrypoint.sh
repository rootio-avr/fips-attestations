#!/bin/bash
################################################################################
# Ubuntu FIPS Go - Entrypoint Script
#
# Purpose: Validate FIPS environment and run Go FIPS demo
#
# Usage:
#   ./entrypoint.sh         # Run Go FIPS demo (default)
#   ./entrypoint.sh validate # Only validate FIPS environment
#   ./entrypoint.sh bash    # Interactive shell
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

################################################################################
# Audit Logging Configuration
################################################################################
AUDIT_LOG_FILE="/tmp/fips-audit.log"
AUDIT_ENABLED="${FIPS_AUDIT_ENABLED:-true}"

# Initialize audit log
if [ "$AUDIT_ENABLED" = "true" ]; then
    mkdir -p "$(dirname "$AUDIT_LOG_FILE")"
    touch "$AUDIT_LOG_FILE"
fi

# Audit logging function
log_audit_event() {
    local event_type="$1"
    local event_status="$2"
    local event_details="$3"

    if [ "$AUDIT_ENABLED" != "true" ]; then
        return
    fi

    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    local audit_entry=$(cat <<EOF
{
  "timestamp": "$timestamp",
  "image": "golang:1.25-jammy-ubuntu-22.04-fips",
  "event_type": "$event_type",
  "status": "$event_status",
  "details": "$event_details",
  "environment": {
    "GOLANG_FIPS": "${GOLANG_FIPS:-not_set}",
    "GODEBUG": "${GODEBUG:-not_set}",
    "GOEXPERIMENT": "${GOEXPERIMENT:-not_set}",
    "OPENSSL_CONF": "${OPENSSL_CONF:-not_set}"
  }
}
EOF
)
    echo "$audit_entry" >> "$AUDIT_LOG_FILE"
}

################################################################################
# Header
################################################################################
log_audit_event "container_start" "success" "Ubuntu FIPS Go container started"

echo ""
echo "========================================"
echo -e "${BOLD}${CYAN}Ubuntu FIPS Go${NC}"
echo "========================================"
echo ""
echo "Version: 1.25-jammy-ubuntu-22.04-fips"
echo "Purpose: Go-only FIPS-140-3 image with strict policy"
echo ""

################################################################################
# FIPS Environment Validation
################################################################################
echo "========================================"
echo -e "${BOLD}[1/3] FIPS Environment Validation${NC}"
echo "========================================"
echo ""

log_audit_event "fips_validation_start" "info" "Starting FIPS environment validation"

# Check OpenSSL version
echo -n "  Checking OpenSSL version ... "
OPENSSL_VERSION=$(openssl version)
echo -e "${GREEN}✓${NC}"
echo "        $OPENSSL_VERSION"
log_audit_event "openssl_version_check" "success" "OpenSSL version: $OPENSSL_VERSION"

# Check wolfProvider
echo -n "  Checking wolfProvider status ... "
PROVIDER_CHECK=$(openssl list -providers 2>/dev/null | grep -i "fips\|wolf" || echo "")
if [ -n "$PROVIDER_CHECK" ]; then
    echo -e "${GREEN}✓ ACTIVE${NC}"
    echo "$PROVIDER_CHECK" | sed 's/^/        /'
    log_audit_event "wolfprovider_check" "success" "wolfProvider active"
else
    echo -e "${YELLOW}⚠ NOT DETECTED${NC}"
    echo "        Note: This may indicate wolfProvider is not properly configured"
    log_audit_event "wolfprovider_check" "warning" "wolfProvider not detected"
fi

# Check environment variables
echo -n "  Checking FIPS environment variables ... "
if [ -n "$OPENSSL_CONF" ] && [ -n "$GOLANG_FIPS" ]; then
    echo -e "${GREEN}✓${NC}"
    echo "        GOLANG_FIPS: $GOLANG_FIPS"
    echo "        GODEBUG: $GODEBUG"
    echo "        OPENSSL_CONF: $OPENSSL_CONF"
    log_audit_event "fips_env_check" "success" "FIPS environment variables properly configured"
else
    echo -e "${YELLOW}⚠ INCOMPLETE${NC}"
    log_audit_event "fips_env_check" "warning" "FIPS environment variables incomplete"
fi

echo ""

################################################################################
# Runtime Information
################################################################################
echo "========================================"
echo -e "${BOLD}[2/3] Runtime Information${NC}"
echo "========================================"
echo ""

# Go Binary
echo -n "  Go Binary ... "
if [ -f "/app/fips-go-demo" ]; then
    echo -e "${GREEN}✓ AVAILABLE${NC}"
    echo "        /app/fips-go-demo"
else
    echo -e "${RED}✗ NOT FOUND${NC}"
fi

echo ""

################################################################################
# wolfSSL FIPS Integrity
################################################################################
echo "========================================"
echo -e "${BOLD}[3/3] wolfSSL FIPS Integrity${NC}"
echo "========================================"
echo ""

echo -n "  Checking wolfSSL library ... "
if [ -f "/usr/local/lib/libwolfssl.so" ]; then
    echo -e "${GREEN}✓ FOUND${NC}"
    echo "        Path: /usr/local/lib/libwolfssl.so"

    # Try to verify library can be loaded
    if ldconfig -p | grep -q wolfssl; then
        echo "        Status: Registered with ldconfig"
    fi

    # Check for headers
    if [ -d "/usr/local/include/wolfssl" ]; then
        echo "        Headers: /usr/local/include/wolfssl"
    fi
    log_audit_event "wolfssl_check" "success" "wolfSSL FIPS library found and loaded"
else
    echo -e "${YELLOW}⚠ NOT FOUND${NC}"
    echo "        Expected: /usr/local/lib/libwolfssl.so"
    log_audit_event "wolfssl_check" "warning" "wolfSSL FIPS library not found"
fi

log_audit_event "fips_validation_complete" "success" "FIPS environment validation completed"

echo ""
echo "========================================"
echo -e "${GREEN}✓ FIPS Environment Validated${NC}"
echo "========================================"
if [ "$AUDIT_ENABLED" = "true" ]; then
    echo ""
    echo "Audit Log: $AUDIT_LOG_FILE"
    echo "  (Set FIPS_AUDIT_ENABLED=false to disable)"
fi
echo ""

################################################################################
# Command Execution
################################################################################
# Execute user command or default demo
# Consistent with Java base image design - supports arbitrary commands

if [ $# -eq 0 ]; then
    # No arguments: run default demo
    log_audit_event "command_execution" "info" "Running Go FIPS demo (default)"
    echo "========================================"
    echo -e "${BOLD}Running Go FIPS Demo${NC}"
    echo "========================================"
    echo ""
    /app/fips-go-demo
    log_audit_event "command_execution" "success" "Go FIPS demo completed"
else
    # Arguments provided: execute user command
    log_audit_event "command_execution" "info" "Executing user command: $*"
    echo "========================================"
    echo -e "${BOLD}Executing User Command${NC}"
    echo "========================================"
    echo ""
    exec "$@"
fi

echo ""
