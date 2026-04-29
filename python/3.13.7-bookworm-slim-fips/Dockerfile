#
# Dockerfile for Python 3.13.7 with wolfSSL FIPS 140-3 support
# Multi-stage build for minimal runtime image
# Based on wolfProvider approach with Debian Bookworm Slim
# FIPS Certificate: #4718 (wolfSSL 5.8.2)
#
# Build command:
#   docker build --secret id=wolfssl_password,src=wolfssl_password.txt \
#     -t cr.root.io/python:3.13.7-bookworm-slim-fips \
#     -f Dockerfile .
#
# Optional: Add Root.io repository access for patched packages
#   docker build --secret id=wolfssl_password,src=wolfssl_password.txt \
#     --secret id=rootio_api_key,src=rootio_api_key.txt \
#     -t cr.root.io/python:3.13.7-bookworm-slim-fips \
#     -f Dockerfile .
#

################################################################################
# Stage 1: Builder - Build wolfSSL FIPS v5, wolfProvider, and Python
################################################################################
FROM cr.root.io/debian:bookworm-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8

# Python and wolfSSL version information
ENV GPG_KEY=7169605F62C751356D054A26A821E680E5FA6305
ENV PYTHON_VERSION=3.13.7
ENV PYTHON_SHA256=5462f9099dfd30e238def83c71d91897d8caa5ff6ebc7a50f14d4802cdaaa79a
ENV WOLFSSL_URL=https://www.wolfssl.com/comm/wolfssl/wolfssl-5.8.2-commercial-fips-v5.2.3.7z
ENV WOLFPROVIDER_URL=https://github.com/wolfSSL/wolfProvider/archive/refs/tags/v1.0.2.tar.gz

# Installation paths
ENV WOLFSSL_PREFIX=/usr/local
ENV WOLFPROV_PREFIX=/usr/local

# Copy test-fips.c for FIPS verification
COPY test-fips.c /tmp/test-fips.c

# Install build dependencies
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		ca-certificates \
		p7zip-full \
		autoconf \
		autoconf-archive \
		automake \
		gnupg \
		dirmngr \
		wget \
		tar \
		xz-utils \
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
	update-ca-certificates; \
	rm -rf /var/lib/apt/lists/*

################################################################################
# Build wolfSSL FIPS v5.8.2
################################################################################
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
	make -j "$(nproc)"; \
	./fips-hash.sh; \
	make -j "$(nproc)"; \
	make install; \
	ldconfig; \
	cd /; \
	rm -rf /usr/src/wolfssl; \
	echo "wolfSSL FIPS v5.8.2 installed successfully"

# Update library path for wolfSSL
ENV LD_LIBRARY_PATH="${WOLFSSL_PREFIX}/lib"

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
		--with-wolfssl=${WOLFSSL_PREFIX} \
	; \
	make -j "$(nproc)"; \
	make install; \
	ldconfig; \
	cd /; \
	rm -rf /usr/src/wolfProvider; \
	echo "wolfProvider installed successfully"

################################################################################
# Build Python 3.13.7
################################################################################
RUN set -eux; \
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
	# Verify Python installation
	export PYTHONDONTWRITEBYTECODE=1; \
	python3 --version; \
	pip3 --version; \
	echo "Python ${PYTHON_VERSION} built successfully"

################################################################################
# Stage 2: Runtime - Minimal Debian Bookworm with Python and FIPS libraries
################################################################################
FROM cr.root.io/debian:bookworm-slim AS runtime

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8

# Metadata labels
LABEL maintainer="root.io Inc." \
	org.opencontainers.image.title="python-fips" \
	org.opencontainers.image.description="Python 3.13.7 with wolfSSL FIPS 140-3 (Certificate #4718)" \
	org.opencontainers.image.version="3.13.7-fips" \
	org.opencontainers.image.vendor="root.io Inc." \
	wolfssl.version="5.8.2" \
	python.version="3.13.7" \
	base="cr.root.io/debian:bookworm-slim"

# Python version
ENV PYTHON_VERSION=3.13.7

# Ensure local python is preferred over distribution python
ENV PATH=/usr/local/bin:$PATH

# Install runtime dependencies
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		ca-certificates \
		tzdata \
	; \
	rm -rf /var/lib/apt/lists/*

# Install additional packages from Root.io repository (optional)
# Note: If rootio_api_key secret is not provided, falls back to default Debian packages
COPY scripts/install-runtime-packages.sh /tmp/install-runtime-packages.sh
RUN --mount=type=secret,id=rootio_api_key,required=false \
	chmod +x /tmp/install-runtime-packages.sh && \
	/tmp/install-runtime-packages.sh && \
	rm /tmp/install-runtime-packages.sh

# Copy FIPS components from builder
COPY --from=builder /usr/local/lib/libwolfssl.so* /usr/local/lib/
COPY --from=builder /usr/local/lib/libwolfprov.so* /usr/local/lib/
COPY --from=builder /usr/local/include/wolfssl /usr/local/include/wolfssl
COPY --from=builder /usr/local/bin/test-fips /test-fips

# Copy Python from builder
COPY --from=builder /usr/local/bin/python3* /usr/local/bin/
COPY --from=builder /usr/local/bin/pip3* /usr/local/bin/
COPY --from=builder /usr/local/bin/pydoc3* /usr/local/bin/
COPY --from=builder /usr/local/bin/idle3* /usr/local/bin/
COPY --from=builder /usr/local/lib/python3.13 /usr/local/lib/python3.13
COPY --from=builder /usr/local/lib/libpython3.13.so* /usr/local/lib/
COPY --from=builder /usr/local/include/python3.13 /usr/local/include/python3.13

# Update ldconfig for shared libraries
RUN set -eux; \
	echo "/usr/local/lib" > /etc/ld.so.conf.d/fips-libs.conf; \
	ldconfig; \
	echo "Libraries configured successfully"

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

# Set OpenSSL configuration environment variables
ENV OPENSSL_CONF=/etc/ssl/openssl.cnf
ENV OPENSSL_MODULES=/usr/local/lib
ENV LD_LIBRARY_PATH=/usr/local/lib

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
WORKDIR /app

# Set entrypoint
ENTRYPOINT ["/docker-entrypoint.sh"]

# Default command
CMD ["python3"]

# Health check to verify Python and wolfSSL integration
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
	CMD python3 -c "import ssl; print('SSL:', ssl.OPENSSL_VERSION)" || exit 1
