FROM cr.root.io/nginx:1.27.3-debian-bookworm-fips

# Install test dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Copy test scripts
COPY src/ /opt/tests/

# Make test scripts executable
RUN chmod +x /opt/tests/*.sh

# Set working directory
WORKDIR /opt/tests

# Default command: run all tests
CMD ["./run_all_tests.sh"]
