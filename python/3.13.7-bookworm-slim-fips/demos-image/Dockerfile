#
# Demos Image for Python wolfSSL FIPS
# Extends the base FIPS image with demonstration applications
#

ARG BASE_IMAGE=python:3.13.7-bookworm-slim-fips
FROM ${BASE_IMAGE}

LABEL description="Python wolfSSL FIPS Demos Image with FIPS enforcement demonstrations"

# Switch to root for setup (base image runs as appuser)
USER root

# Install demo dependencies
RUN pip3 install --no-cache-dir \
    requests==2.32.3

# Create demos directory
RUN mkdir -p /demos

# Copy demo applications
COPY demos/tls_ssl_client_demo.py /demos/tls_ssl_client_demo.py
COPY demos/hash_algorithm_demo.py /demos/hash_algorithm_demo.py
COPY demos/requests_library_demo.py /demos/requests_library_demo.py
COPY demos/certificate_validation_demo.py /demos/certificate_validation_demo.py

# Make demo files executable
RUN chmod +x /demos/*.py

# Set working directory
WORKDIR /demos

# Switch back to non-root user for demo execution
USER appuser

# Default command shows available demos
CMD ["sh", "-c", "echo 'Available demos:'; echo '  python3 tls_ssl_client_demo.py'; echo '  python3 hash_algorithm_demo.py'; echo '  python3 requests_library_demo.py'; echo '  python3 certificate_validation_demo.py'"]
