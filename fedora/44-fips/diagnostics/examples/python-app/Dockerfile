#
# Multi-Stage Build Example: Python on Fedora 44 FIPS Base
#
# This Dockerfile demonstrates how to build a FIPS-compliant
# Python application using the Fedora 44 FIPS base image
#

FROM cr.root.io/fedora:44-fips

# Install Python and pip
RUN set -eux; \
    dnf install -y \
        python3 \
        python3-pip \
        python3-cryptography \
    ; \
    dnf clean all; \
    rm -rf /var/cache/dnf

# Verify Python installation
RUN python3 --version && pip3 --version

# Upgrade pip
RUN pip3 install --no-cache-dir --upgrade pip

# Set working directory
WORKDIR /app

# Copy requirements file
# COPY requirements.txt ./
# RUN pip3 install --no-cache-dir -r requirements.txt

# Copy application code
# COPY . .

# Non-root user (inherited from base image)
USER appuser

# Example: Run application
# CMD ["python3", "app.py"]

# For this example, just start a shell
CMD ["/bin/bash"]

# Labels
LABEL maintainer="root.io Inc."
LABEL description="Python 3 on Fedora 44 FIPS base image"
LABEL python.version="3.x"
LABEL fips.enabled="true"
