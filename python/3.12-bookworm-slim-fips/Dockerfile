#
# Dockerfile for Python 3.12 with wolfSSL FIPS 140-3 support
# Based on wolfSSL provider approach with Debian Bookworm Slim
# Follows the architecture from wolfssl-containers/python/Dockerfile.provider
# FIPS Certificate: #4718 (wolfSSL 5.8.2)
#

FROM debian:bookworm-slim

# Ensure local python is preferred over distribution python
ENV PATH=/usr/local/bin:$PATH

# Locale setting (required for Python)
ENV LANG=C.UTF-8

# Runtime dependencies
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		ca-certificates \
		tzdata \
	; \
	rm -rf /var/lib/apt/lists/*

# Python and wolfSSL version information
ENV GPG_KEY=7169605F62C751356D054A26A821E680E5FA6305
ENV PYTHON_VERSION=3.12.11
ENV PYTHON_SHA256=c30bb24b7f1e9a19b11b55a546434f74e739bb4c271a3e3a80ff4380d49f7adb
ENV WOLFSSL_URL=https://www.wolfssl.com/comm/wolfssl/wolfssl-5.8.2-commercial-fips-v5.2.3.7z
ENV WOLFPROVIDER_URL=https://github.com/wolfSSL/wolfProvider/archive/refs/tags/v1.0.2.tar.gz

COPY test-fips.c /test-fips.c

# Build wolfSSL, wolfProvider, and Python from source
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
		tar \
		xz-utils \
		\
		build-essential \
		gcc \
		make \
		dpkg-dev \
		libbluetooth-dev \
		libbz2-dev \
		libffi-dev \
		libgdbm-dev \
		liblzma-dev \
		libncurses-dev \
		libreadline-dev \
		libsqlite3-dev \
		libssl-dev \
		libtool \
		pkg-config \
		tk-dev \
		uuid-dev \
		zlib1g-dev \
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
	# *** CRITICAL PATCH *** Prevent wolfSSL from enabling WOLFSSL_OLD_OID_SUM (no longer needed)
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
	./configure --prefix=/usr/local; \
	make -j "$(nproc)"; \
	make install; \
	ldconfig; \
	cd /; \
	rm -rf /usr/src/wolfProvider; \
	\
	# Download and verify Python source
	wget -O python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz"; \
	echo "$PYTHON_SHA256 *python.tar.xz" | sha256sum -c -; \
	wget -O python.tar.xz.asc "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz.asc"; \
	GNUPGHOME="$(mktemp -d)"; export GNUPGHOME; \
	gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "$GPG_KEY"; \
	gpg --batch --verify python.tar.xz.asc python.tar.xz; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" python.tar.xz.asc; \
	mkdir -p /usr/src/python; \
	tar --extract --directory /usr/src/python --strip-components=1 --file python.tar.xz; \
	rm python.tar.xz; \
	\
	# Compile and install Python
	cd /usr/src/python; \
	# *** CRITICAL PATCH *** Remove scrypt support (not available in wolfSSL)
	sed -i 's/#define PY_OPENSSL_HAS_SCRYPT 1//g' Modules/_hashopenssl.c; \
	gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
	./configure \
		--build="$gnuArch" \
		--enable-loadable-sqlite-extensions \
		--enable-option-checking=fatal \
		--enable-shared \
		--with-lto \
		--with-ensurepip \
	; \
	nproc="$(nproc)"; \
	# Set thread stack size to 1MB so we don't segfault before hitting recursion limit
	EXTRA_CFLAGS="-DTHREAD_STACK_SIZE=0x100000"; \
	LDFLAGS="${LDFLAGS:--Wl},--strip-all"; \
	make -j "$nproc" \
		"EXTRA_CFLAGS=${EXTRA_CFLAGS:-}" \
		"LDFLAGS=${LDFLAGS:-}" \
	; \
	# Prevent accidental usage of system installed libpython of same version
	rm python; \
	make -j "$nproc" \
		"EXTRA_CFLAGS=${EXTRA_CFLAGS:-}" \
		"LDFLAGS=${LDFLAGS:--Wl},-rpath='\$\$ORIGIN/../lib'" \
		python \
	; \
	make install; \
	\
	cd /; \
	rm -rf /usr/src/python; \
	\
	# Cleanup: remove test files, bytecode, and static libraries
	find /usr/local -depth \
		\( \
			\( -type d -a \( -name test -o -name tests -o -name idle_test \) \) \
			-o \( -type f -a \( -name '*.pyc' -o -name '*.pyo' -o -name 'libpython*.a' \) \) \
		\) -exec rm -rf '{}' + \
	; \
	\
	# Remove build dependencies but keep minimal runtime dependencies
	# Note: tar cannot be removed as it's required by dpkg
	apt-get purge -y --auto-remove \
		p7zip-full \
		autoconf \
		autoconf-archive \
		automake \
		gnupg \
		dirmngr \
		wget \
		xz-utils \
		build-essential \
		gcc \
		make \
		dpkg-dev \
		libtool \
		pkg-config \
	; \
	apt-get clean; \
	rm -rf /var/lib/apt/lists/*; \
	\
	# Verify Python installation
	export PYTHONDONTWRITEBYTECODE=1; \
	python3 --version; \
	pip3 --version

# Make some useful symlinks that are expected to exist
RUN set -eux; \
	for src in idle3 pip3 pydoc3 python3 python3-config; do \
		dst="$(echo "$src" | tr -d 3)"; \
		[ -s "/usr/local/bin/$src" ]; \
		[ ! -e "/usr/local/bin/$dst" ]; \
		ln -svT "$src" "/usr/local/bin/$dst"; \
	done

# Copy OpenSSL configuration for wolfProvider
COPY openssl.cnf /etc/ssl/openssl.cnf

# Set OpenSSL configuration environment variable
ENV OPENSSL_CONF=/etc/ssl/openssl.cnf
ENV OPENSSL_MODULES=/usr/local/lib

# Copy and setup Python FIPS verification script
RUN mkdir -p /opt/wolfssl-fips/bin
COPY src/fips_init_check.py /opt/wolfssl-fips/bin/fips_init_check.py
RUN chmod +x /opt/wolfssl-fips/bin/fips_init_check.py

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
CMD ["python3"]

# Labels for image metadata
LABEL maintainer="root.io Inc."
LABEL description="Python 3.12 with wolfSSL FIPS 140-3 (Cert #4718) using wolfProvider"
LABEL version="1.0"
LABEL wolfssl.version="5.8.2"
LABEL python.version="3.12.11"
LABEL base="debian:bookworm-slim"

# Health check to verify Python and wolfSSL integration
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
	CMD python3 -c "import ssl; print('SSL:', ssl.OPENSSL_VERSION)" || exit 1
