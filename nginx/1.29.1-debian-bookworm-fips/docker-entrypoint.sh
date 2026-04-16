#!/bin/bash
################################################################################
# Nginx FIPS Docker Entrypoint
#
# This script performs FIPS validation before starting Nginx server.
#
# Validation Steps:
#   1. FIPS startup check (wolfSSL FIPS POST)
#   2. OpenSSL provider verification (wolfProvider loaded)
#   3. Library integrity verification
#   4. Nginx configuration test
#
# Environment Variables:
#   FIPS_CHECK=false    Skip FIPS validation (development only)
#   NGINX_CONF          Path to nginx.conf (default: /etc/nginx/nginx.conf)
#
################################################################################

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
FIPS_CHECK="${FIPS_CHECK:-true}"
NGINX_CONF="${NGINX_CONF:-/etc/nginx/nginx.conf}"

# Helper functions
log_info() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_section() {
    echo -e "\n${BLUE}==>${NC} ${1}"
}

# FIPS validation function
perform_fips_validation() {
    log_section "FIPS 140-3 Validation"

    # Step 1: wolfSSL FIPS POST
    if command -v fips-startup-check &> /dev/null; then
        log_info "Running wolfSSL FIPS POST (Known Answer Tests)..."
        if fips-startup-check; then
            log_info "FIPS POST completed successfully"
        else
            log_error "FIPS POST failed! Container will terminate."
            exit 1
        fi
    else
        log_warn "FIPS startup check utility not found (skipping POST)"
    fi

    # Step 2: OpenSSL provider verification
    log_info "Verifying OpenSSL provider configuration..."
    if openssl list -providers | grep -qi "wolfSSL"; then
        log_info "wolfProvider loaded and active"
    else
        log_error "wolfProvider not found in OpenSSL providers"
        echo ""
        echo "Available providers:"
        openssl list -providers || true
        exit 1
    fi

    # Step 3: OpenSSL version
    OPENSSL_VERSION=$(openssl version)
    log_info "OpenSSL version: $OPENSSL_VERSION"

    # Step 4: Check FIPS properties
    if grep -q "fips=yes" /etc/ssl/fips_properties.cnf 2>/dev/null; then
        log_info "FIPS enforcement enabled (fips=yes)"
    else
        log_warn "FIPS properties file not found or FIPS not enforced"
    fi

    # Step 5: Library integrity (if available)
    if [[ -x /usr/local/bin/verify-integrity.sh ]]; then
        log_info "Verifying library integrity..."
        if /usr/local/bin/verify-integrity.sh; then
            log_info "Library integrity verified"
        else
            log_warn "Library integrity check failed (non-fatal)"
        fi
    fi

    log_info "FIPS validation completed successfully"
}

# Nginx configuration validation
validate_nginx_config() {
    log_section "Nginx Configuration Validation"

    if [[ -f "$NGINX_CONF" ]]; then
        log_info "Testing Nginx configuration: $NGINX_CONF"
        if nginx -t -c "$NGINX_CONF" 2>&1 | grep -q "successful"; then
            log_info "Nginx configuration is valid"
        else
            log_error "Nginx configuration test failed"
            nginx -t -c "$NGINX_CONF" || true
            exit 1
        fi
    else
        log_warn "Nginx configuration not found: $NGINX_CONF"
        log_warn "Nginx will use default configuration"
    fi
}

# Display runtime environment
display_environment() {
    log_section "Runtime Environment"
    echo "FIPS_CHECK:    $FIPS_CHECK"
    echo "NGINX_CONF:    $NGINX_CONF"
    echo "OPENSSL_CONF:  ${OPENSSL_CONF:-/etc/ssl/openssl.cnf}"
    echo "LD_LIBRARY_PATH: ${LD_LIBRARY_PATH:-<not set>}"
}

# Main execution
main() {
    echo "================================================================================"
    echo "Nginx 1.29.1 with wolfSSL FIPS 140-3 (Certificate #4718)"
    echo "================================================================================"

    display_environment

    # Run FIPS validation if enabled
    if [[ "$FIPS_CHECK" == "true" ]]; then
        perform_fips_validation
    else
        log_warn "FIPS validation SKIPPED (FIPS_CHECK=false)"
        log_warn "This configuration is for development only!"
    fi

    # Validate Nginx configuration
    validate_nginx_config

    echo ""
    log_info "Initialization complete. Starting Nginx..."
    echo "================================================================================"
    echo ""

    # Execute the command passed to docker run (or default CMD)
    if [[ $# -eq 0 ]]; then
        # No arguments - run Nginx in foreground
        exec nginx -g "daemon off;" -c "$NGINX_CONF"
    else
        # Arguments provided - execute them
        exec "$@"
    fi
}

# Run main function
main "$@"
