#
# Dockerfile for Node.js 18 with wolfSSL FIPS 140-3 support
# Based on wolfSSL provider approach with Debian Bookworm Slim
# Uses pre-built Node.js binaries (NO source compilation needed)
# FIPS Certificate: #4718 (wolfSSL 5.8.2)
#

FROM debian:bookworm-slim

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
ENV NODE_VERSION=18.20.8
ENV WOLFSSL_URL=https://www.wolfssl.com/comm/wolfssl/wolfssl-5.8.2-commercial-fips-v5.2.3.7z
ENV WOLFPROVIDER_URL=https://github.com/wolfSSL/wolfProvider/archive/refs/tags/v1.0.2.tar.gz

COPY test-fips.c /test-fips.c

# Build wolfSSL, wolfProvider, and install Node.js
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
	; \
	\
	# Download wolfSSL FIPS source code
	mkdir -p /usr/src; \
	wget -O wolfssl.7z "${WOLFSSL_URL}"; \
	cat /run/secrets/wolfssl_password | 7z x wolfssl.7z -o/usr/src; \
	rm wolfssl.7z; \
	mv /usr/src/wolfssl* /usr/src/wolfssl; \
	\
	# Compile and install wolfSSL with FIPS
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
	# Download wolfProvider source code
	wget -O wolfprovider.tar.gz ${WOLFPROVIDER_URL}; \
	tar --extract --directory /usr/src --file wolfprovider.tar.gz; \
	rm wolfprovider.tar.gz; \
	mv /usr/src/wolfProvider* /usr/src/wolfProvider; \
	# Compile and install wolfProvider
	cd /usr/src/wolfProvider; \
	autoreconf -ivf; \
	./configure --prefix=/usr/local --with-openssl=/usr; \
	make -j "$(nproc)"; \
	make install; \
	ldconfig; \
	cd /; \
	rm -rf /usr/src/wolfProvider; \
	\
	# Install Node.js from NodeSource repository
	# NodeSource provides pre-built Node.js binaries dynamically linked to system OpenSSL
	curl -fsSL https://deb.nodesource.com/setup_18.x | bash -; \
	apt-get install -y nodejs; \
	\
	# Verify Node.js installation
	node --version; \
	npm --version; \
	\
	# CVE-2026-23745: Upgrade to npm 10.9.7 (latest npm 10.x compatible with Node.js 18)
	# npm 10.8.2 bundles vulnerable tar 7.5.2; npm 10.9.7 released March 2026 (after CVE)
	npm install -g npm@10.9.7; \
	npm --version; \
	\
	# Cleanup: Remove build dependencies
	# Note: tar cannot be removed as it's required by dpkg (Node.js is installed via apt)
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
	; \
	apt-get clean; \
	rm -rf /var/lib/apt/lists/*

# Copy OpenSSL configuration for wolfProvider
COPY openssl.cnf /etc/ssl/openssl.cnf

# Set OpenSSL configuration environment variables
ENV OPENSSL_CONF=/etc/ssl/openssl.cnf
ENV OPENSSL_MODULES=/usr/local/lib
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
	sha256sum /usr/local/lib/libwolfprov.so* > /opt/wolfssl-fips/checksums/libwolfprov.sha256 && \
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

# Set entrypoint
ENTRYPOINT ["/docker-entrypoint.sh"]

# Default command
CMD ["node"]

# Labels for image metadata
LABEL maintainer="root.io Inc."
LABEL description="Node.js 18 with wolfSSL FIPS 140-3 (Cert #4718) using wolfProvider"
LABEL version="1.0"
LABEL wolfssl.version="5.8.2"
LABEL node.version="18.20.8"
LABEL base="debian:bookworm-slim"

# Health check to verify Node.js and OpenSSL integration
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
	CMD node -e "console.log('Node.js:', process.version)" || exit 1
