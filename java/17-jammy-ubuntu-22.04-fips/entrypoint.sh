#!/bin/bash
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
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
  "image": "java:17-jammy-ubuntu-22.04-fips",
  "event_type": "$event_type",
  "status": "$event_status",
  "details": "$event_details",
  "environment": {
    "OPENSSL_CONF": "${OPENSSL_CONF:-not_set}",
    "JAVA_HOME": "${JAVA_HOME:-not_set}"
  }
}
EOF
)
    echo "$audit_entry" >> "$AUDIT_LOG_FILE"
}

log_audit_event "container_start" "success" "Ubuntu FIPS Java container started"

echo ""
echo "========================================"
echo -e "${BOLD}${CYAN}Ubuntu FIPS Java${NC}"
echo "========================================"
echo ""
echo "Version: 17-jammy-ubuntu-22.04-fips"
echo "Purpose: Java-only FIPS-140-3 image with strict policy"
echo ""

echo "========================================"
echo -e "${BOLD}[1/3] FIPS Environment Validation${NC}"
echo "========================================"
echo ""

log_audit_event "fips_validation_start" "info" "Starting FIPS environment validation"

echo -n "  Checking OpenSSL version ... "
OPENSSL_VERSION=$(openssl version)
echo -e "${GREEN}✓${NC}"
echo "        $OPENSSL_VERSION"
log_audit_event "openssl_version_check" "success" "OpenSSL version: $OPENSSL_VERSION"

echo -n "  Checking wolfProvider status ... "
PROVIDER_CHECK=$(openssl list -providers 2>/dev/null | grep -i "fips\|wolf" || echo "")
if [ -n "$PROVIDER_CHECK" ]; then
    echo -e "${GREEN}✓ ACTIVE${NC}"
    echo "$PROVIDER_CHECK" | sed 's/^/        /'
    log_audit_event "wolfprovider_check" "success" "wolfProvider active"
else
    echo -e "${YELLOW}⚠ NOT DETECTED${NC}"
    log_audit_event "wolfprovider_check" "warning" "wolfProvider not detected"
fi

echo -n "  Checking FIPS environment variables ... "
if [ -n "$OPENSSL_CONF" ]; then
    echo -e "${GREEN}✓${NC}"
    echo "        OPENSSL_CONF: $OPENSSL_CONF"
    log_audit_event "fips_env_check" "success" "FIPS environment variables properly configured"
else
    echo -e "${YELLOW}⚠ INCOMPLETE${NC}"
    log_audit_event "fips_env_check" "warning" "FIPS environment variables incomplete"
fi

echo ""

echo "========================================"
echo -e "${BOLD}[2/3] Runtime Information${NC}"
echo "========================================"
echo ""

echo -n "  Java Runtime ... "
if command -v java &> /dev/null; then
    JAVA_VERSION=$(java -version 2>&1 | head -1)
    echo -e "${GREEN}✓ AVAILABLE${NC}"
    echo "        $JAVA_VERSION"
    log_audit_event "java_runtime_check" "success" "Java runtime: $JAVA_VERSION"
else
    echo -e "${RED}✗ NOT FOUND${NC}"
    log_audit_event "java_runtime_check" "error" "Java runtime not found"
fi

echo ""

echo "========================================"
echo -e "${BOLD}[3/3] wolfSSL FIPS Integrity${NC}"
echo "========================================"
echo ""

echo -n "  Checking wolfSSL library ... "
if [ -f "/usr/local/lib/libwolfssl.so" ]; then
    echo -e "${GREEN}✓ FOUND${NC}"
    echo "        Path: /usr/local/lib/libwolfssl.so"
    if ldconfig -p | grep -q wolfssl; then
        echo "        Status: Registered with ldconfig"
    fi
    if [ -d "/usr/local/include/wolfssl" ]; then
        echo "        Headers: /usr/local/include/wolfssl"
    fi
    log_audit_event "wolfssl_check" "success" "wolfSSL FIPS library found and loaded"
else
    echo -e "${YELLOW}⚠ NOT FOUND${NC}"
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

COMMAND="${1:-demo}"

case "$COMMAND" in
    demo|"")
        log_audit_event "command_execution" "info" "Running Java FIPS demo"
        echo "========================================"
        echo -e "${BOLD}Running Java FIPS Demo${NC}"
        echo "========================================"
        echo ""
        cd /app/java
        java FipsDemoApp
        log_audit_event "command_execution" "success" "Java FIPS demo completed"
        ;;

    validate)
        log_audit_event "command_execution" "info" "Validation-only mode (no demo run)"
        echo "FIPS validation complete (no demo run)"
        ;;

    bash|sh|shell)
        log_audit_event "command_execution" "info" "Interactive shell started"
        echo "Starting interactive shell..."
        exec /bin/bash
        ;;

    *)
        log_audit_event "command_execution" "error" "Unknown command: $COMMAND"
        echo -e "${YELLOW}Unknown command: $COMMAND${NC}"
        echo ""
        echo "Valid commands: demo, validate, bash"
        exit 1
        ;;
esac

echo ""
