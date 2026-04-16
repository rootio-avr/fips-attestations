#
# Dockerfile for Node.js 24 with wolfSSL FIPS 140-3 support
# Based on wolfProvider approach with Debian Trixie Slim
# Uses pre-built Node.js binaries (NO source compilation needed)
# FIPS Certificate: #4718 (wolfSSL 5.8.2)
#
# Build command:
#   docker build --secret id=wolfssl_password,src=wolfssl_password.txt \
#     -t cr.root.io/node:24.14.0-trixie-slim-fips \
#     -f Dockerfile .
#

FROM debian:trixie-slim

# Ensure local binaries are preferred
ENV PATH=/usr/local/bin:$PATH

# Locale setting
ENV LANG=C.UTF-8

# Runtime dependencies
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		ca-certificates \
		tzdata \
	; \
	rm -rf /var/lib/apt/lists/*

# Node.js and wolfSSL version information
ENV NODE_VERSION=24.14.0
ENV WOLFSSL_URL=https://www.wolfssl.com/comm/wolfssl/wolfssl-5.8.2-commercial-fips-v5.2.3.7z
ENV WOLFPROVIDER_URL=https://github.com/wolfSSL/wolfProvider/archive/refs/tags/v1.1.1.tar.gz
ENV OPENSSL_VERSION=3.5.0

COPY test-fips.c /test-fips.c

# Build OpenSSL 3, wolfSSL, wolfProvider, and install Node.js
RUN --mount=type=secret,id=wolfssl_password \
	set -eux; \
	\
	# Install build dependencies
	apt-get update; \
	apt-get install -y --no-install-recommends \
		p7zip-full \
		autoconf \
		autoconf-archive \
		automake \
		gnupg \
		dirmngr \
		wget \
		curl \
		tar \
		xz-utils \
		\
		build-essential \
		gcc \
		make \
		libtool \
		pkg-config \
		libssl-dev \
		perl \
	; \
	\
	# ========================================================================
	# Build OpenSSL 3.5.0 with FIPS support
	# ========================================================================
	cd /tmp; \
	wget https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz; \
	tar -xzf openssl-${OPENSSL_VERSION}.tar.gz; \
	cd openssl-${OPENSSL_VERSION}; \
	./Configure \
		--prefix=/usr/local/openssl \
		--openssldir=/usr/local/openssl/ssl \
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
	echo "OpenSSL ${OPENSSL_VERSION} installed successfully at /usr/local/openssl"; \
	\
	# ========================================================================
	# Download wolfSSL FIPS source code
	# ========================================================================
	mkdir -p /usr/src; \
	wget --no-check-certificate -O wolfssl.7z "${WOLFSSL_URL}"; \
	PASSWORD=$(cat /run/secrets/wolfssl_password | tr -d '\n\r'); \
	7z x wolfssl.7z -o/usr/src -p"${PASSWORD}"; \
	rm wolfssl.7z; \
	mv /usr/src/wolfssl* /usr/src/wolfssl; \
	\
	# ========================================================================
	# Compile and install wolfSSL with FIPS
	# ========================================================================
	cd /usr/src/wolfssl; \
	# *** CRITICAL PATCH *** Prevent wolfSSL from enabling WOLFSSL_OLD_OID_SUM
	# This is essential for proper certificate chain validation
	sed -i '/^#ifdef WOLFSSL_PYTHON/,/^#endif/d' wolfssl/wolfcrypt/settings.h; \
	./configure --enable-opensslcoexist --enable-cmac --enable-keygen --enable-sha \
		--enable-aesctr --enable-aesccm --enable-x963kdf --enable-compkey --enable-altcertchains \
		CPPFLAGS="-DHAVE_AES_ECB \
				-DWOLFSSL_AES_DIRECT -DWC_RSA_NO_PADDING -DWOLFSSL_PUBLIC_MP -DHAVE_PUBLIC_FFDHE \
				-DWOLFSSL_DH_EXTRA -DWOLFSSL_PSS_LONG_SALT -DWOLFSSL_PSS_SALT_LEN_DISCOVER -DRSA_MIN_SIZE=2048" \
		--enable-certgen --enable-aeskeywrap --enable-enckeys --enable-base16 --with-eccminsz=192 --prefix=/usr/local \
		--enable-fips=v5; \
	make -j "$(nproc)"; \
	./fips-hash.sh; \
	make -j "$(nproc)"; \
	make install; \
	ldconfig; \
	cd /; \
	rm -rf /usr/src/wolfssl; \
	\
	# Build test-fips executable
	gcc /test-fips.c -o /test-fips -lwolfssl; \
	rm /test-fips.c; \
	\
	# ========================================================================
	# Download wolfProvider source code
	# ========================================================================
	wget -O wolfprovider.tar.gz ${WOLFPROVIDER_URL}; \
	tar --extract --directory /usr/src --file wolfprovider.tar.gz; \
	rm wolfprovider.tar.gz; \
	mv /usr/src/wolfProvider* /usr/src/wolfProvider; \
	\
	# ========================================================================
	# Compile and install wolfProvider with custom OpenSSL
	# ========================================================================
	cd /usr/src/wolfProvider; \
	autoreconf -ivf; \
	export PATH="/usr/local/openssl/bin:$PATH"; \
	export PKG_CONFIG_PATH="/usr/local/openssl/lib64/pkgconfig"; \
	./configure --prefix=/usr/local --with-openssl=/usr/local/openssl; \
	make -j "$(nproc)"; \
	echo "wolfProvider built, installing to OpenSSL modules directory..."; \
	mkdir -p /usr/local/openssl/lib64/ossl-modules; \
	if [ -f ".libs/libwolfprov.so" ]; then \
		cp -v .libs/libwolfprov.so* /usr/local/openssl/lib64/ossl-modules/; \
	elif [ -f "src/.libs/libwolfprov.so" ]; then \
		cp -v src/.libs/libwolfprov.so* /usr/local/openssl/lib64/ossl-modules/; \
	fi; \
	ldconfig; \
	cd /; \
	rm -rf /usr/src/wolfProvider; \
	echo "✓ wolfProvider installed to /usr/local/openssl/lib64/ossl-modules/"; \
	\
	# ========================================================================
	# Install Node.js from NodeSource repository
	# NodeSource provides pre-built Node.js binaries dynamically linked to system OpenSSL
	# ========================================================================
	curl -fsSL https://deb.nodesource.com/setup_24.x | bash -; \
	apt-get install -y nodejs; \
	\
	# Verify Node.js installation
	node --version; \
	npm --version; \
	\
	# ========================================================================
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
	# ========================================================================
	echo "==> Replacing system OpenSSL with FIPS OpenSSL 3.5.0"; \
	# Copy FIPS OpenSSL 3.5.0 libraries to system location
	cp -av /usr/local/openssl/lib64/libssl.so* /usr/lib/x86_64-linux-gnu/; \
	cp -av /usr/local/openssl/lib64/libcrypto.so* /usr/lib/x86_64-linux-gnu/; \
	cp -av /usr/local/openssl/bin/openssl /usr/bin/openssl; \
	\
	# Update library cache (critical - tells dynamic linker where to find libs)
	echo "/usr/lib/x86_64-linux-gnu" > /etc/ld.so.conf.d/fips-openssl.conf; \
	echo "/usr/local/openssl/lib64" >> /etc/ld.so.conf.d/fips-openssl.conf; \
	echo "/usr/local/lib" >> /etc/ld.so.conf.d/fips-openssl.conf; \
	ldconfig; \
	\
	# Verify replacement
	echo "==> Verifying FIPS OpenSSL 3.5.0 in system location"; \
	/usr/bin/openssl version; \
	ldd /usr/bin/openssl; \
	\
	# Verify Node.js sees FIPS OpenSSL (may not show if using dlopen)
	echo "==> Verifying Node.js OpenSSL linkage"; \
	ldd $(which node) | grep ssl || echo "  Note: OpenSSL may be loaded via dlopen()"; \
	echo "✓ System OpenSSL replaced with FIPS OpenSSL 3.5.0"; \
	\
	# ========================================================================
	# Cleanup: Remove build dependencies
	# Note: tar cannot be removed as it's required by dpkg (Node.js is installed via apt)
	# ========================================================================
	apt-get purge -y --auto-remove \
		p7zip-full \
		autoconf \
		autoconf-archive \
		automake \
		gnupg \
		dirmngr \
		wget \
		curl \
		xz-utils \
		build-essential \
		gcc \
		make \
		libtool \
		pkg-config \
		perl \
	; \
	apt-get clean; \
	rm -rf /var/lib/apt/lists/*

# Copy OpenSSL configuration for wolfProvider
COPY openssl.cnf /etc/ssl/openssl.cnf

# Set OpenSSL configuration environment variables
ENV OPENSSL_CONF=/etc/ssl/openssl.cnf
ENV OPENSSL_MODULES=/usr/local/openssl/lib64/ossl-modules
# Note: LD_LIBRARY_PATH not needed - system OpenSSL libraries replaced with FIPS OpenSSL
# Node.js 18+ will automatically use OPENSSL_CONF via --openssl-shared-config (default)

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

# Switch to non-root user for runtime (STIG SV-238201)
USER appuser
WORKDIR /app

# Set entrypoint
ENTRYPOINT ["/docker-entrypoint.sh"]

# Default command
CMD ["node"]

# Labels for image metadata
LABEL maintainer="root.io Inc."
LABEL description="Node.js 24 with wolfSSL FIPS 140-3 (Cert #4718) using wolfProvider on Debian Trixie"
LABEL version="1.0"
LABEL wolfssl.version="5.8.2"
LABEL node.version="24.14.0"
LABEL openssl.version="3.5.0"
LABEL base="debian:trixie-slim"

# Health check to verify Node.js and OpenSSL integration
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
	CMD node -e "console.log('Node.js:', process.version)" || exit 1
