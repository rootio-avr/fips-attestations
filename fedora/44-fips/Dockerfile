#
# Dockerfile for Fedora 44 with FIPS 140-3 Support
# Uses Fedora's native crypto-policies system and OpenSSL FIPS provider
#
# Build command:
#   docker build -t cr.root.io/fedora:44-fips -f Dockerfile .
#
# Run command:
#   docker run --rm -it cr.root.io/fedora:44-fips
#

FROM fedora:44

# Set environment variables
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Force OpenSSL to use FIPS mode
# This is a Fedora-specific feature that forces FIPS even without kernel support
ENV OPENSSL_FORCE_FIPS_MODE=1

# Runtime dependencies and crypto packages
RUN set -eux; \
	dnf update -y; \
	dnf install -y \
		ca-certificates \
		tzdata \
		crypto-policies \
		crypto-policies-scripts \
		openssl \
		openssl-libs \
	; \
	dnf clean all; \
	rm -rf /var/cache/dnf

# ========================================================================
# Enable FIPS Mode via Crypto-Policies
#
# Fedora uses a system-wide crypto-policies framework to manage
# cryptographic settings across all applications.
#
# Setting crypto-policies to FIPS mode:
#   1. Configures OpenSSL to use FIPS provider
#   2. Sets system-wide cryptographic policies to FIPS-approved algorithms
#   3. Updates all crypto library configurations (/etc/crypto-policies/back-ends/)
#
# Note: In containers without kernel FIPS support, we use OPENSSL_FORCE_FIPS_MODE
#       to force OpenSSL into FIPS mode at the application level
# ========================================================================
RUN set -eux; \
	\
	# Set crypto-policies to FIPS mode
	echo "FIPS" > /etc/crypto-policies/config; \
	update-crypto-policies --set FIPS || update-crypto-policies; \
	\
	# Verify crypto-policies configuration
	echo "==> Crypto-policies configured to FIPS mode"; \
	cat /etc/crypto-policies/config; \
	\
	# Display OpenSSL configuration
	echo "==> OpenSSL FIPS provider configuration:"; \
	openssl version; \
	openssl list -providers || true

# Copy FIPS verification script (shell-based, no language runtimes needed)
RUN mkdir -p /opt/fips/bin
COPY src/fips_init_check.sh /opt/fips/bin/fips_init_check.sh
RUN chmod +x /opt/fips/bin/fips_init_check.sh

# Copy diagnostics suite (tests and demo applications)
RUN mkdir -p /opt/fips/diagnostics
COPY diagnostics /opt/fips/diagnostics
RUN chmod +x /opt/fips/diagnostics/tests/*.sh /opt/fips/diagnostics/apps/*.sh

# Copy utility scripts
COPY scripts/integrity-check.sh /usr/local/bin/integrity-check.sh
COPY scripts/enable-fips.sh /usr/local/bin/enable-fips.sh
RUN chmod +x /usr/local/bin/integrity-check.sh /usr/local/bin/enable-fips.sh

# Generate checksums for integrity verification
RUN mkdir -p /opt/fips/checksums && \
	sha256sum /opt/fips/bin/* > /opt/fips/checksums/verification-scripts.sha256

# Copy docker entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod 755 /docker-entrypoint.sh

# Create non-root user for security
RUN groupadd -g 1001 appuser \
	&& useradd -r -u 1001 -g appuser -m -d /home/appuser -s /bin/bash appuser

# Create /app directory for user applications and set ownership
RUN mkdir -p /app \
	&& chown -R appuser:appuser /app

# Switch to non-root user for runtime
USER appuser
WORKDIR /app

# Set entrypoint
ENTRYPOINT ["/docker-entrypoint.sh"]

# Default command
CMD ["/bin/bash"]

# Labels for image metadata
LABEL maintainer="root.io Inc."
LABEL description="Fedora 44 with FIPS 140-3 support using crypto-policies and OpenSSL FIPS provider"
LABEL version="1.0"
LABEL fedora.version="44"
LABEL openssl.fips="provider"
LABEL fips.method="crypto-policies"
LABEL base="fedora:44"

# Health check to verify FIPS mode is active
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
	CMD openssl list -providers | grep -i fips || exit 1
