################################################################################
# Gotenberg FIPS Test Image
#
# Purpose: Test application image to validate Gotenberg FIPS functionality
#
# Base Image: cr.root.io/gotenberg:8.26.0-trixie-slim-fips
# Go Compiler: local/golang-fips:latest (FIPS-enabled)
#
# Test Coverage:
#   - OpenSSL 3.5.0 with wolfSSL FIPS provider verification
#   - HTML → PDF conversion via Gotenberg API
#   - Office document → PDF conversion
#   - FIPS-approved TLS cipher validation
#   - PDF manipulation operations
#
################################################################################

# Stage 1: Download Go dependencies with standard Go (avoid FIPS ECDSA verification issues)
FROM golang:1.23-bookworm AS downloader

WORKDIR /build

# Copy entire test-app source (needed for go mod tidy to work properly)
COPY test-app/ ./

# Download dependencies and ensure go.sum is complete
RUN go mod download && go mod tidy

# Stage 2: Build test application with FIPS-enabled Go compiler
FROM local/golang-fips:latest AS builder

WORKDIR /build

# Copy downloaded modules from downloader
COPY --from=downloader /go/pkg/mod /go/pkg/mod

# Copy test application source
COPY test-app/ .

# Copy go.sum from downloader (needed for module verification)
COPY --from=downloader /build/go.sum ./go.sum

# Build test application with CGO enabled for FIPS support
# Use downloaded modules without re-downloading
RUN CGO_ENABLED=1 go build -o gotenberg-test-suite ./main.go

################################################################################
# Stage 3: Runtime image based on Gotenberg FIPS
################################################################################
FROM cr.root.io/gotenberg:8.26.0-trixie-slim-fips

# Install curl for API testing
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy test binary from builder
COPY --from=builder /build/gotenberg-test-suite /usr/local/bin/gotenberg-test-suite

# Ensure test binary is executable
RUN chmod +x /usr/local/bin/gotenberg-test-suite

# Switch back to gotenberg user
USER gotenberg

# Set working directory
WORKDIR /workspace

# Default command: Run test suite
ENTRYPOINT ["/usr/local/bin/gotenberg-test-suite"]
CMD ["--help"]
