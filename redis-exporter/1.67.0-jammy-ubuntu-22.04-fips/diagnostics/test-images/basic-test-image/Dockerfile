# Redis Exporter FIPS Test Image
#
# Purpose: Comprehensive test suite for redis_exporter FIPS image
# Tests: FIPS validation, Redis connectivity, metrics export, crypto operations
#
# Build: ./build.sh
# Run: docker run --rm redis-exporter-1.67.0-fips-test:latest
#
################################################################################
# WHY IS THIS SO SIMPLE?
################################################################################
#
# The base FIPS image (cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips)
# ALREADY contains everything we need for testing:
#
#   ✓ openssl binary (FIPS-enabled OpenSSL 3.0.19)
#   ✓ fips-check binary (wolfSSL FIPS POST validator)
#   ✓ redis_exporter binary (the application we're testing)
#   ✓ All wolfSSL FIPS libraries (CMVP Certificate #4718)
#   ✓ All environment variables (GOLANG_FIPS, GODEBUG, etc.)
#   ✓ System utilities (ldconfig, grep, echo, etc.)
#
# So we DON'T need to:
#   ✗ Install any packages (curl, redis-tools, etc. - not used in tests)
#   ✗ Copy any binaries (already present)
#   ✗ Set environment variables (already set)
#   ✗ Use multi-stage builds (no dependency conflicts)
#
# All we need to do is:
#   1. Add our test scripts
#   2. Run the tests
#
################################################################################

FROM cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips

# Switch to root to install test files
USER root

################################################################################
# Copy Test Files
################################################################################
# These are the ONLY additional files needed:
#   - test-runner.sh: Main test execution script (runs all test suites)
#   - src/*.go: Go test file stubs (future enhancement, not currently used)
################################################################################

COPY test-runner.sh /app/test-runner.sh
COPY src/*.go /app/tests/

# Make test runner executable
RUN chmod +x /app/test-runner.sh

# Create directory for test results (if tests want to write output files)
RUN mkdir -p /app/test-results && \
    chown -R redis-exporter:redis-exporter /app

################################################################################
# Switch Back to Non-Root User
################################################################################
# Follow security best practice: don't run as root
################################################################################

USER redis-exporter

WORKDIR /app

################################################################################
# Default Command
################################################################################
# Run the test suite by default
# Users can override with: docker run <image> /bin/bash (for debugging)
################################################################################

CMD ["/app/test-runner.sh"]
