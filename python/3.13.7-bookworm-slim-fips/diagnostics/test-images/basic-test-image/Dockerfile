#
# Test Image for Python wolfSSL FIPS
# Extends the base FIPS image with comprehensive test suites
#

ARG BASE_IMAGE=python:3.13.7-bookworm-slim-fips
FROM ${BASE_IMAGE}

LABEL description="Python wolfSSL FIPS Test Image with comprehensive test suites"

# Switch to root for setup (base image runs as appuser)
USER root

# Install test dependencies
RUN pip3 install --no-cache-dir \
    requests==2.32.3 \
    urllib3==2.2.3

# Create test directories
RUN mkdir -p /tests

# Copy test suite files
COPY src/fips_user_application.py /tests/fips_user_application.py
COPY src/crypto_test_suite.py /tests/crypto_test_suite.py
COPY src/tls_test_suite.py /tests/tls_test_suite.py

# Make test files executable
RUN chmod +x /tests/*.py

# Set working directory
WORKDIR /tests

# Switch back to non-root user for test execution
USER appuser

# Default command runs the main test application
CMD ["python3", "fips_user_application.py"]
