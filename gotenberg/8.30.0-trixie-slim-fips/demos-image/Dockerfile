################################################################################
# Gotenberg FIPS Demos Image
#
# Purpose: Demonstration image with sample applications showcasing Gotenberg
#          FIPS functionality
#
# Base Image: cr.root.io/gotenberg:8.30.0-trixie-slim-fips
#
# Included Demos:
#   - html-to-pdf: HTML to PDF conversion examples
#   - office-to-pdf: Office documents to PDF conversion
#   - webhook-demo: Async conversion with webhook callbacks
#   - fips-verification: FIPS provider runtime verification
#
################################################################################

FROM cr.root.io/gotenberg:8.30.0-trixie-slim-fips

# Switch to root for package installation
USER root

# Install demo dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        jq \
        python3 \
        python3-pip \
        python3-venv \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create demo directories
RUN mkdir -p /demos

# Copy demo scripts and files
COPY demos/ /demos/

# Make all demo scripts executable
RUN find /demos -name "*.sh" -exec chmod +x {} \; && \
    find /demos -name "*.py" -exec chmod +x {} \;

# Set proper ownership
RUN chown -R gotenberg:gotenberg /demos

# Switch back to gotenberg user
USER gotenberg

# Set working directory
WORKDIR /demos

# Override the Gotenberg ENTRYPOINT (we don't want to start Gotenberg service)
ENTRYPOINT []

# Default command: List available demos
CMD ["sh", "-c", "echo 'Available Demos:' && echo '' && ls -1 /demos && echo '' && echo 'Run a demo: docker run --rm gotenberg-demos:8.30.0-trixie-slim-fips /demos/<demo-name>/run.sh'"]
