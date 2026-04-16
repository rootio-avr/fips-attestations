#
# Test Image for Node.js wolfSSL FIPS
# Extends the base FIPS image with comprehensive test suites
#

ARG BASE_IMAGE=node:24.14.0-trixie-slim-fips
FROM ${BASE_IMAGE}

LABEL description="Node.js wolfSSL FIPS Test Image with comprehensive test suites"

# Switch to root for setup (base image runs as appuser)
USER root

# Create test directories
RUN mkdir -p /tests

# Copy test suite files
COPY src/fips_user_application.js /tests/fips_user_application.js
COPY src/crypto_test_suite.js /tests/crypto_test_suite.js
COPY src/tls_test_suite.js /tests/tls_test_suite.js

# Make test files executable
RUN chmod +x /tests/*.js

# Set working directory
WORKDIR /tests

# Switch back to non-root user for test execution
USER appuser

# Default command runs the main test application
CMD ["node", "fips_user_application.js"]
