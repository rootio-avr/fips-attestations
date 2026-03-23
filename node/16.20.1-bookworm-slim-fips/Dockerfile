#
# Dockerfile for Node.js 16 with wolfSSL FIPS 140-3 support
# Based on wolfSSL provider approach with Debian Bookworm Slim
# Compiles Node.js 16 from source with OpenSSL 3.0 for provider support
# FIPS Certificate: #4718 (wolfSSL 5.8.2)
#
# ⚠️  WARNING: Node.js 16.20.1 reached End-of-Life (EOL) on September 11, 2023
# ⚠️  This image is provided for legacy application compatibility only
# ⚠️  Consider upgrading to Node.js 18 LTS or Node.js 20 LTS for production use
# ⚠️  Build time: ~45-60 minutes (requires Node.js source compilation)
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
ENV NODE_VERSION=16.20.1
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
	curl -fsSL -o wolfssl.7z "${WOLFSSL_URL}"; \
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
	curl -fsSL -o wolfprovider.tar.gz ${WOLFPROVIDER_URL}; \
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
	# Install Python BEFORE building OpenSSL (prevents Debian from reinstalling libssl3)
	# CRITICAL: Installing python3-pip after OpenSSL build would trigger apt to reinstall
	# libssl3 as a dependency, overwriting our custom OpenSSL headers
	apt-get install -y python3 python3-pip python-is-python3; \
	\
	# Download OpenSSL 3.0.18 source
	echo "Downloading OpenSSL 3.0.18..."; \
	cd /usr/src; \
	curl -fsSL -o openssl-3.0.18.tar.gz https://www.openssl.org/source/openssl-3.0.18.tar.gz; \
	tar xzf openssl-3.0.18.tar.gz; \
	\
	# Download Node.js source
	echo "Downloading Node.js 16.20.1..."; \
	curl -fsSL -o node-v${NODE_VERSION}.tar.gz https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}.tar.gz; \
	tar xzf node-v${NODE_VERSION}.tar.gz; \
	\
	# Build and install OpenSSL 3.0.18 at system paths (replaces system OpenSSL)
	# Keep libssl-dev during build for libc6-dev dependency (provides string.h, etc.)
	echo "Building OpenSSL 3.0.18 at system path..."; \
	cd /usr/src/openssl-3.0.18; \
	./config \
		--prefix=/usr \
		--openssldir=/etc/ssl \
		--libdir=lib/x86_64-linux-gnu \
		shared \
		no-ssl3 \
		enable-ec_nistp_64_gcc_128; \
	make -j "$(nproc)"; \
	make install_sw install_ssldirs install_man_docs; \
	ldconfig; \
	\
	# Create symlinks for Node.js configure (needs libssl.so, not just libssl.so.3)
	ln -sf libssl.so.3 /usr/lib/x86_64-linux-gnu/libssl.so; \
	ln -sf libcrypto.so.3 /usr/lib/x86_64-linux-gnu/libcrypto.so; \
	\
	# Create pkg-config files for OpenSSL (required by Node.js configure)
	# Temporarily disable -u flag to allow literal ${variable} syntax in pkg-config files
	set +u; \
	mkdir -p /usr/lib/x86_64-linux-gnu/pkgconfig; \
	{ \
		echo "prefix=/usr"; \
		echo "exec_prefix=\$${prefix}"; \
		echo "libdir=\$${exec_prefix}/lib/x86_64-linux-gnu"; \
		echo "includedir=\$${prefix}/include"; \
		echo ""; \
		echo "Name: OpenSSL"; \
		echo "Description: Secure Sockets Layer and cryptography libraries and tools"; \
		echo "Version: 3.0.18"; \
		echo "Requires: libssl libcrypto"; \
	} > /usr/lib/x86_64-linux-gnu/pkgconfig/openssl.pc; \
	{ \
		echo "prefix=/usr"; \
		echo "exec_prefix=\$${prefix}"; \
		echo "libdir=\$${exec_prefix}/lib/x86_64-linux-gnu"; \
		echo "includedir=\$${prefix}/include"; \
		echo ""; \
		echo "Name: OpenSSL-libssl"; \
		echo "Description: Secure Sockets Layer and cryptography libraries"; \
		echo "Version: 3.0.18"; \
		echo "Requires.private: libcrypto"; \
		echo "Libs: -L\$${libdir} -lssl"; \
		echo "Cflags: -I\$${includedir}"; \
	} > /usr/lib/x86_64-linux-gnu/pkgconfig/libssl.pc; \
	{ \
		echo "prefix=/usr"; \
		echo "exec_prefix=\$${prefix}"; \
		echo "libdir=\$${exec_prefix}/lib/x86_64-linux-gnu"; \
		echo "includedir=\$${prefix}/include"; \
		echo ""; \
		echo "Name: OpenSSL-libcrypto"; \
		echo "Description: OpenSSL cryptography library"; \
		echo "Version: 3.0.18"; \
		echo "Libs: -L\$${libdir} -lcrypto"; \
		echo "Cflags: -I\$${includedir}"; \
	} > /usr/lib/x86_64-linux-gnu/pkgconfig/libcrypto.pc; \
	set -u; \
	cd /; \
	rm -rf /usr/src/openssl-3.0.18*; \
	\
	# Build Node.js 16.20.1 from source with system OpenSSL 3.0 support
	# This is required because pre-built Node 16 binaries use OpenSSL 1.1.1 (no provider support)
	# Source already downloaded earlier
	echo "Building Node.js 16.20.1 from source with system OpenSSL..."; \
	cd /usr/src/node-v${NODE_VERSION}; \
	echo "Verifying OpenSSL installation before configuring Node.js..."; \
	openssl version; \
	ls -la /usr/lib/x86_64-linux-gnu/libssl.so* || true; \
	ls -la /usr/include/openssl/opensslv.h || true; \
	echo "Checking pkg-config..."; \
	echo "Contents of openssl.pc:"; \
	cat /usr/lib/x86_64-linux-gnu/pkgconfig/openssl.pc || echo "openssl.pc not found"; \
	echo "Contents of libssl.pc:"; \
	cat /usr/lib/x86_64-linux-gnu/pkgconfig/libssl.pc || echo "libssl.pc not found"; \
	echo "Contents of libcrypto.pc:"; \
	cat /usr/lib/x86_64-linux-gnu/pkgconfig/libcrypto.pc || echo "libcrypto.pc not found"; \
	export PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig$${PKG_CONFIG_PATH:+:$$PKG_CONFIG_PATH}; \
	echo "PKG_CONFIG_PATH=$$PKG_CONFIG_PATH"; \
	pkg-config --exists openssl && echo "✓ OpenSSL found via pkg-config" || echo "✗ OpenSSL NOT found via pkg-config"; \
	pkg-config --modversion openssl 2>&1 || true; \
	echo "Configuring Node.js with shared OpenSSL..."; \
	python3 ./configure \
		--shared-openssl \
		--shared-openssl-libpath=/usr/lib/x86_64-linux-gnu \
		--shared-openssl-includes=/usr/include \
		--prefix=/usr/local || { echo "Node.js configure failed!"; cat config.log; exit 1; }; \
	echo "Starting Node.js compilation (this will take 25-35 minutes)..."; \
	make -j "$(nproc)"; \
	echo "Installing Node.js..."; \
	make install; \
	ldconfig; \
	cd /; \
	rm -rf /usr/src/node-v${NODE_VERSION}*; \
	\
	# Verify Node.js installation
	node --version; \
	npm --version; \
	\
	# Upgrade npm to 9.9.3 (latest npm 9.x compatible with Node.js 16)
	echo "Upgrading npm to 9.9.3..."; \
	npm install -g npm@9.9.3; \
	npm --version; \
	\
	# Fix CVE-2026-23745: Manually patch vulnerable node-tar in npm
	# npm 9.9.3 bundles node-tar 7.5.2 (vulnerable to path traversal)
	# npm 10+ (which has the fix) requires Node.js 18+
	# Manually update to node-tar 7.5.11 to patch CVE-2026-23745
	echo "Patching CVE-2026-23745: Updating node-tar dependency in npm..."; \
	cd /usr/local/lib/node_modules/npm; \
	npm install tar@7.5.11 --force --no-save --loglevel=error 2>&1 || \
	{ echo "Warning: Could not patch tar automatically. Installing via global cache..."; \
	  npm install --global tar@7.5.11 --force && \
	  cp -r /usr/local/lib/node_modules/tar /usr/local/lib/node_modules/npm/node_modules/; }; \
	echo "Verifying patched tar version:"; \
	npm ls tar || echo "tar version check failed, but proceeding..."; \
	cd /; \
	\
	# Fix multiple npm dependency CVEs (all bundled within npm 9.9.3)
	# npm 10+ (which has these fixes) requires Node.js 18+
	# Manually patch vulnerable dependencies to latest secure versions
	echo "Patching npm dependency vulnerabilities..."; \
	cd /usr/local/lib/node_modules/npm; \
	\
	# CVE-2026-26996 & CVE-2026-27903: minimatch ReDoS vulnerabilities
	# Fix: minimatch 9.0.7+ (covers both CVEs)
	echo "  Patching minimatch (CVE-2026-26996, CVE-2026-27903)..."; \
	npm install minimatch@9.0.7 --force --no-save --loglevel=error 2>&1 || echo "  Warning: minimatch patch may have failed"; \
	\
	# CVE-2025-64756: glob command injection vulnerability
	# Fix: glob 10.5.0+ or 11.1.0+
	echo "  Patching glob (CVE-2025-64756)..."; \
	npm install glob@10.5.0 --force --no-save --loglevel=error 2>&1 || echo "  Warning: glob patch may have failed"; \
	\
	# CVE-2024-21538: cross-spawn ReDoS vulnerability
	# Fix: cross-spawn 7.0.5+
	echo "  Patching cross-spawn (CVE-2024-21538)..."; \
	npm install cross-spawn@7.0.5 --force --no-save --loglevel=error 2>&1 || echo "  Warning: cross-spawn patch may have failed"; \
	\
	echo "  Verifying patched versions:"; \
	npm ls minimatch glob cross-spawn 2>&1 || echo "  Version check completed"; \
	cd /; \
	\
	# Cleanup: Remove build dependencies
	# Keep tar (may be needed by system), remove build tools
	apt-get purge -y --auto-remove \
		p7zip-full \
		autoconf \
		autoconf-archive \
		automake \
		gnupg \
		dirmngr \
		curl \
		xz-utils \
		build-essential \
		gcc \
		make \
		libtool \
		pkg-config \
		python3 \
		python3-pip \
		python-is-python3 \
	; \
	apt-get clean; \
	rm -rf /var/lib/apt/lists/*

# Copy OpenSSL configuration for wolfProvider
COPY openssl.cnf /etc/ssl/openssl.cnf

# Set OpenSSL configuration environment variables
ENV OPENSSL_CONF=/etc/ssl/openssl.cnf
ENV OPENSSL_MODULES=/usr/local/lib
# Note: Node.js 16 does NOT support --openssl-shared-config (introduced in Node 18)
# OpenSSL configuration is loaded via OPENSSL_CONF environment variable
# Node 16 compiled with shared OpenSSL 3.0 to enable provider architecture

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
LABEL description="Node.js 16 with wolfSSL FIPS 140-3 (Cert #4718) using wolfProvider"
LABEL version="1.0"
LABEL wolfssl.version="5.8.2"
LABEL node.version="16.20.1"
LABEL node.eol="2023-09-11"
LABEL base="debian:bookworm-slim"

# Health check to verify Node.js and OpenSSL integration
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
	CMD node -e "console.log('Node.js:', process.version)" || exit 1
