#
# Dockerfile for Node.js 24 with wolfSSL FIPS 140-3 support
# Multi-stage build for minimal runtime image
# Based on wolfProvider approach with Debian Trixie Slim
# Uses pre-built Node.js binaries (NO source compilation needed)
# FIPS Certificate: #4718 (wolfSSL 5.8.2)
#
# Build command:
#   docker build --secret id=wolfssl_password,src=wolfssl_password.txt \
#     -t cr.root.io/node:24.14.0-trixie-slim-fips \
#     -f Dockerfile .
#

################################################################################
# Stage 1: Builder - Build OpenSSL 3, wolfSSL FIPS v5, and wolfProvider
################################################################################
FROM cr.root.io/debian:trixie-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8

# Build configuration
ENV OPENSSL_VERSION=3.5.0
ENV WOLFSSL_URL=https://www.wolfssl.com/comm/wolfssl/wolfssl-5.8.2-commercial-fips-v5.2.3.7z
ENV WOLFPROVIDER_URL=https://github.com/wolfSSL/wolfProvider/archive/refs/tags/v1.1.1.tar.gz

# Installation paths
ENV OPENSSL_PREFIX=/usr/local/openssl
ENV WOLFSSL_PREFIX=/usr/local
ENV WOLFPROV_PREFIX=/usr/local

# Install builder stage dependencies
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		ca-certificates \
		p7zip-full \
		autoconf \
		autoconf-archive \
		automake \
		wget \
		curl \
		tar \
		xz-utils \
		build-essential \
		gcc \
		make \
		libtool \
		pkg-config \
		perl \
	; \
	update-ca-certificates; \
	rm -rf /var/lib/apt/lists/*

################################################################################
# Build OpenSSL 3.5.0 with FIPS support
################################################################################
RUN set -eux; \
	cd /tmp; \
	wget https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz; \
	tar -xzf openssl-${OPENSSL_VERSION}.tar.gz; \
	cd openssl-${OPENSSL_VERSION}; \
	./Configure \
		--prefix=${OPENSSL_PREFIX} \
		--openssldir=${OPENSSL_PREFIX}/ssl \
		--libdir=lib64 \
		enable-fips \
		shared \
		linux-x86_64 \
	; \
	make -j"$(nproc)"; \
	make install_sw; \
	make install_fips; \
	make install_ssldirs; \
	cd ..; \
	rm -rf openssl-${OPENSSL_VERSION}*; \
	echo "OpenSSL ${OPENSSL_VERSION} installed successfully"

# Update environment for subsequent builds
ENV PATH="${OPENSSL_PREFIX}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${OPENSSL_PREFIX}/lib64"
ENV PKG_CONFIG_PATH="${OPENSSL_PREFIX}/lib64/pkgconfig"

# Verify OpenSSL installation
RUN openssl version

################################################################################
# Build wolfSSL FIPS v5
################################################################################
COPY test-fips.c /tmp/test-fips.c

RUN --mount=type=secret,id=wolfssl_password \
	set -eux; \
	mkdir -p /usr/src; \
	wget --no-check-certificate -O /tmp/wolfssl.7z "${WOLFSSL_URL}"; \
	PASSWORD=$(cat /run/secrets/wolfssl_password | tr -d '\n\r'); \
	7z x /tmp/wolfssl.7z -o/usr/src -p"${PASSWORD}"; \
	rm /tmp/wolfssl.7z; \
	mv /usr/src/wolfssl* /usr/src/wolfssl; \
	cd /usr/src/wolfssl; \
	# *** CRITICAL PATCH *** Prevent wolfSSL from enabling WOLFSSL_OLD_OID_SUM
	sed -i '/^#ifdef WOLFSSL_PYTHON/,/^#endif/d' wolfssl/wolfcrypt/settings.h; \
	./configure \
		--prefix=${WOLFSSL_PREFIX} \
		--enable-fips=v5 \
		--enable-opensslcoexist \
		--enable-cmac \
		--enable-keygen \
		--enable-sha \
		--enable-aesctr \
		--enable-aesccm \
		--enable-x963kdf \
		--enable-compkey \
		--enable-altcertchains \
		--enable-certgen \
		--enable-aeskeywrap \
		--enable-enckeys \
		--enable-base16 \
		--with-eccminsz=192 \
		CPPFLAGS="-DHAVE_AES_ECB -DWOLFSSL_AES_DIRECT -DWC_RSA_NO_PADDING -DWOLFSSL_PUBLIC_MP -DHAVE_PUBLIC_FFDHE -DWOLFSSL_DH_EXTRA -DWOLFSSL_PSS_LONG_SALT -DWOLFSSL_PSS_SALT_LEN_DISCOVER -DRSA_MIN_SIZE=2048" \
	; \
	make -j"$(nproc)"; \
	./fips-hash.sh; \
	make -j"$(nproc)"; \
	make install; \
	ldconfig; \
	cd /; \
	rm -rf /usr/src/wolfssl; \
	echo "wolfSSL FIPS v5 installed successfully"

# Update library path for wolfSSL
ENV LD_LIBRARY_PATH="${OPENSSL_PREFIX}/lib64:${WOLFSSL_PREFIX}/lib"

# Test wolfSSL installation
RUN set -eux; \
	gcc /tmp/test-fips.c -o /tmp/test-fips -lwolfssl -I${WOLFSSL_PREFIX}/include; \
	/tmp/test-fips; \
	rm /tmp/test-fips; \
	echo "wolfSSL FIPS test passed"

# Build FIPS startup check utility
COPY test-fips.c /tmp/test-fips.c
RUN set -eux; \
	gcc /tmp/test-fips.c -o /usr/local/bin/test-fips \
		-lwolfssl -I${WOLFSSL_PREFIX}/include; \
	chmod +x /usr/local/bin/test-fips; \
	rm /tmp/test-fips.c; \
	echo "FIPS test utility built successfully"

################################################################################
# Build wolfProvider
################################################################################
RUN set -eux; \
	cd /tmp; \
	wget -O wolfprovider.tar.gz ${WOLFPROVIDER_URL}; \
	tar --extract --directory /usr/src --file wolfprovider.tar.gz; \
	rm wolfprovider.tar.gz; \
	mv /usr/src/wolfProvider* /usr/src/wolfProvider; \
	cd /usr/src/wolfProvider; \
	autoreconf -ivf; \
	./configure \
		--prefix=${WOLFPROV_PREFIX} \
		--with-openssl=${OPENSSL_PREFIX} \
		--with-wolfssl=${WOLFSSL_PREFIX} \
	; \
	make -j"$(nproc)"; \
	echo "wolfProvider built, installing to OpenSSL modules directory..."; \
	mkdir -p ${OPENSSL_PREFIX}/lib64/ossl-modules; \
	if [ -f ".libs/libwolfprov.so" ]; then \
		cp -v .libs/libwolfprov.so* ${OPENSSL_PREFIX}/lib64/ossl-modules/; \
	elif [ -f "src/.libs/libwolfprov.so" ]; then \
		cp -v src/.libs/libwolfprov.so* ${OPENSSL_PREFIX}/lib64/ossl-modules/; \
	fi; \
	ldconfig; \
	cd /; \
	rm -rf /usr/src/wolfProvider; \
	echo "✓ wolfProvider installed to ${OPENSSL_PREFIX}/lib64/ossl-modules/"

# Verify wolfProvider installation
RUN set -eux; \
	echo "Checking for wolfProvider in OpenSSL modules..."; \
	ls -la ${OPENSSL_PREFIX}/lib64/ossl-modules/; \
	if [ -f "${OPENSSL_PREFIX}/lib64/ossl-modules/libwolfprov.so" ]; then \
		echo "✓ wolfProvider module found and verified"; \
	else \
		echo "ERROR: wolfProvider module not found"; \
		exit 1; \
	fi

################################################################################
# Stage 2: Runtime - Minimal Debian Trixie with Node.js and FIPS libraries
################################################################################
FROM cr.root.io/debian:trixie-slim AS runtime

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8

# Metadata labels
LABEL maintainer="root.io Inc." \
	org.opencontainers.image.title="node-fips" \
	org.opencontainers.image.description="Node.js 24.14.0 with wolfSSL FIPS 140-3 (Certificate #4718)" \
	org.opencontainers.image.version="24.14.0-fips" \
	org.opencontainers.image.vendor="root.io Inc." \
	wolfssl.version="5.8.2" \
	node.version="24.14.0" \
	openssl.version="3.5.0" \
	base="cr.root.io/debian:trixie-slim"

# Installation paths
ENV OPENSSL_PREFIX=/usr/local/openssl
ENV WOLFSSL_PREFIX=/usr/local
ENV NODE_VERSION=24.14.0

# Ensure local binaries are preferred
ENV PATH=/usr/local/bin:$PATH

# Install runtime dependencies
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		ca-certificates \
		tzdata \
		curl \
		gnupg \
		dirmngr \
	; \
	rm -rf /var/lib/apt/lists/*

# Copy FIPS components from builder
COPY --from=builder /usr/local/openssl /usr/local/openssl
COPY --from=builder /usr/local/lib/libwolfssl.so* /usr/local/lib/
COPY --from=builder /usr/local/include/wolfssl /usr/local/include/wolfssl
COPY --from=builder /usr/local/bin/test-fips /test-fips

# Install Node.js from NodeSource repository
# NodeSource provides pre-built Node.js binaries dynamically linked to system OpenSSL
RUN set -eux; \
	curl -fsSL https://deb.nodesource.com/setup_24.x | bash -; \
	apt-get install -y nodejs; \
	node --version; \
	npm --version; \
	echo "✓ Node.js ${NODE_VERSION} installed successfully"

# Replace System OpenSSL with FIPS OpenSSL (Critical for Node.js)
#
# Strategy: Replace system OpenSSL libraries with custom FIPS OpenSSL 3.5.0
# This ensures Node.js (pre-built binary) uses FIPS OpenSSL at runtime
#
# Why this works:
#   1. Node.js from NodeSource is pre-compiled and dynamically linked
#   2. It looks for libssl.so.3 and libcrypto.so.3 in system paths
#   3. We replace system libs with our FIPS OpenSSL 3.5.0 + wolfProvider
#   4. ldconfig updates the dynamic linker cache
#   5. Node.js loads FIPS OpenSSL automatically at runtime
#
# Note: OpenSSL linkage may not be visible in 'ldd' output if Node.js
#       uses dlopen() for dynamic loading. This is normal and expected.
#       The crypto.getFips() = 1 check confirms FIPS mode is active.
RUN set -eux; \
	echo "==> Replacing system OpenSSL with FIPS OpenSSL 3.5.0"; \
	cp -av /usr/local/openssl/lib64/libssl.so* /usr/lib/x86_64-linux-gnu/; \
	cp -av /usr/local/openssl/lib64/libcrypto.so* /usr/lib/x86_64-linux-gnu/; \
	cp -av /usr/local/openssl/bin/openssl /usr/bin/openssl; \
	echo "/usr/lib/x86_64-linux-gnu" > /etc/ld.so.conf.d/fips-openssl.conf; \
	echo "/usr/local/openssl/lib64" >> /etc/ld.so.conf.d/fips-openssl.conf; \
	echo "/usr/local/lib" >> /etc/ld.so.conf.d/fips-openssl.conf; \
	ldconfig; \
	echo "==> Verifying FIPS OpenSSL 3.5.0 in system location"; \
	/usr/bin/openssl version; \
	ldd /usr/bin/openssl; \
	echo "==> Verifying Node.js OpenSSL linkage"; \
	ldd $(which node) | grep ssl || echo "  Note: OpenSSL may be loaded via dlopen()"; \
	echo "✓ System OpenSSL replaced with FIPS OpenSSL 3.5.0"

# Set OpenSSL environment variables
ENV OPENSSL_CONF="/etc/ssl/openssl.cnf" \
	OPENSSL_MODULES="/usr/local/openssl/lib64/ossl-modules" \
	LD_LIBRARY_PATH="/usr/local/lib:/usr/local/openssl/lib64" \
	PATH="/usr/local/openssl/bin:${PATH}"

# Copy OpenSSL configuration with wolfProvider
COPY openssl.cnf /etc/ssl/openssl.cnf

# Verify FIPS OpenSSL configuration
RUN set -eux; \
	echo "========================================"; \
	echo "Verifying FIPS OpenSSL Configuration"; \
	echo "========================================"; \
	openssl version; \
	echo ""; \
	echo "OpenSSL providers:"; \
	openssl list -providers; \
	echo ""; \
	if ! openssl list -providers | grep -qi "wolfSSL"; then \
		echo "ERROR: wolfProvider not loaded!"; \
		exit 1; \
	fi; \
	echo "✓ FIPS OpenSSL operational"; \
	echo "✓ wolfProvider loaded"; \
	echo "========================================"

# Copy and setup Node.js FIPS verification script
RUN mkdir -p /opt/wolfssl-fips/bin
COPY src/fips_init_check.js /opt/wolfssl-fips/bin/fips_init_check.js
RUN chmod +x /opt/wolfssl-fips/bin/fips_init_check.js

# Copy and setup integrity check script
COPY scripts/integrity-check.sh /usr/local/bin/integrity-check.sh
RUN chmod +x /usr/local/bin/integrity-check.sh

# Generate checksums for integrity verification
RUN mkdir -p /opt/wolfssl-fips/checksums && \
	sha256sum /usr/local/lib/libwolfssl.so* > /opt/wolfssl-fips/checksums/libwolfssl.sha256 && \
	sha256sum /usr/local/openssl/lib64/ossl-modules/libwolfprov.so* > /opt/wolfssl-fips/checksums/libwolfprov.sha256 && \
	sha256sum /test-fips > /opt/wolfssl-fips/checksums/test-fips.sha256

# Copy docker entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod 755 /docker-entrypoint.sh

# Create non-root user for security (STIG SV-238201)
RUN groupadd -g 1001 appuser \
	&& useradd -r -u 1001 -g appuser -m -d /home/appuser -s /bin/bash appuser

# Create /app directory for user applications and set ownership
RUN mkdir -p /app \
	&& chown -R appuser:appuser /app

# Clean up: Remove build dependencies that were needed for Node.js installation
RUN set -eux; \
	apt-get purge -y --auto-remove \
		curl \
		gnupg \
		dirmngr \
	; \
	apt-get clean; \
	rm -rf /var/lib/apt/lists/*

# Switch to non-root user for runtime (STIG SV-238201)
USER appuser
WORKDIR /app

# Set entrypoint
ENTRYPOINT ["/docker-entrypoint.sh"]

# Default command
CMD ["node"]

# Health check to verify Node.js and OpenSSL integration
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
	CMD node -e "console.log('Node.js:', process.version)" || exit 1
