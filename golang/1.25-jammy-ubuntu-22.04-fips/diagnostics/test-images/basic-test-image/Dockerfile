# Simple FIPS Test Application Docker Image
# Extends the golang-fips base image to provide basic testing
# of cryptographic operations and TLS functionality

ARG BASE_IMAGE=golang:1.25-jammy-ubuntu-22.04-fips
FROM ${BASE_IMAGE}

LABEL maintainer="Root User"
LABEL description="FIPS-compliant Go test application demonstrating crypto/* and crypto/tls usage"

# Compile the test applications
WORKDIR /app/test

COPY src/*.go /app/test/

# Build all test applications using golang-fips/go with strict FIPS mode
# - crypto_test_suite: Comprehensive crypto/* package tests
# - tls_test_suite: TLS and HTTPS connection tests
# - fips_user_application: Combined test suite with real-world scenarios
RUN set -eux; \
    echo "Building Go FIPS test applications..."; \
    go build -o crypto_test_suite crypto_test_suite.go; \
    go build -o tls_test_suite tls_test_suite.go; \
    go build -o fips_user_application fips_user_application.go; \
    chmod +x crypto_test_suite tls_test_suite fips_user_application; \
    echo "✓ All test applications built successfully"

# Set the working directory back to /app
WORKDIR /app

# Default command runs the comprehensive FIPS test suite
# Users can override this to run individual test applications
CMD ["/app/test/fips_user_application"]

# Alternative commands for running specific test suites:
# docker run golang-1.25-jammy-ubuntu-22.04-fips-test-image:latest /app/test/crypto_test_suite
# docker run golang-1.25-jammy-ubuntu-22.04-fips-test-image:latest /app/test/tls_test_suite
