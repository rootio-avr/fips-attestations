#
# Multi-Stage Build Example: Node.js on Fedora 44 FIPS Base
#
# This Dockerfile demonstrates how to build a FIPS-compliant
# Node.js application using the Fedora 44 FIPS base image
#

FROM cr.root.io/fedora:44-fips

# Install Node.js from NodeSource repository
RUN set -eux; \
    # Install curl for NodeSource script
    dnf install -y curl; \
    # Add NodeSource repository
    curl -fsSL https://rpm.nodesource.com/setup_22.x | bash -; \
    # Install Node.js
    dnf install -y nodejs; \
    # Clean up
    dnf clean all; \
    rm -rf /var/cache/dnf

# Verify Node.js installation
RUN node --version && npm --version

# Set working directory
WORKDIR /app

# Copy application files
# COPY package.json package-lock.json ./
# RUN npm ci --only=production

# Copy application code
# COPY . .

# Non-root user (inherited from base image)
USER appuser

# Environment variables (FIPS mode inherited from base)
ENV NODE_OPTIONS="--use-openssl-ca"

# Example: Run application
# CMD ["node", "index.js"]

# For this example, just start a shell
CMD ["/bin/bash"]

# Labels
LABEL maintainer="root.io Inc."
LABEL description="Node.js 22.x on Fedora 44 FIPS base image"
LABEL nodejs.version="22.x"
LABEL fips.enabled="true"
