#
# Test Image for ASP.NET wolfSSL FIPS
# Extends the base FIPS image with comprehensive test suites
#

ARG BASE_IMAGE=cr.root.io/aspnet:8.0.25-bookworm-slim-fips
FROM ${BASE_IMAGE}

LABEL description="ASP.NET Core wolfSSL FIPS Test Image with comprehensive test suites"

# Create test directories
RUN mkdir -p /tests

# Copy test suite files
COPY src/FipsUserApplication.cs /tests/FipsUserApplication.cs
COPY src/CryptoTestSuite.cs /tests/CryptoTestSuite.cs
COPY src/TlsTestSuite.cs /tests/TlsTestSuite.cs

# Set working directory
WORKDIR /tests

# Pre-warm dotnet-script cache by running scripts during build
# This ensures NuGet packages are restored and cached in the image
RUN set -eux; \
    export DOTNET_CLI_TELEMETRY_OPTOUT=1; \
    export LD_LIBRARY_PATH="/usr/local/openssl/lib:/usr/local/lib"; \
    export OPENSSL_CONF="/usr/local/openssl/ssl/openssl.cnf"; \
    echo "Pre-warming dotnet-script cache..."; \
    timeout 30 dotnet-script FipsUserApplication.cs 2>&1 || echo "  Cache warming completed"; \
    echo "✓ dotnet-script cache pre-warmed"

# Default command runs the main test application
CMD ["dotnet-script", "FipsUserApplication.cs"]
