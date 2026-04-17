#
# Test Image for Podman 5.8.1 wolfSSL FIPS
# Extends the base FIPS image with a simple Podman test suite
#

ARG BASE_IMAGE=podman:5.8.1-fedora-44-fips
FROM ${BASE_IMAGE}

LABEL description="Podman wolfSSL FIPS Test Image with simple validation suite"

# Switch to root for setup
USER root

# Create test directories
RUN mkdir -p /tests

# Copy test suite files
COPY src/podman_fips_test.sh /tests/podman_fips_test.sh

# Make test files executable
RUN chmod +x /tests/*.sh

# Set working directory
WORKDIR /tests

# Default command runs the test application
CMD ["bash", "podman_fips_test.sh"]
