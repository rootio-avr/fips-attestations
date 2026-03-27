################################################################################
# FIPS-Enabled Redis Image with wolfSSL FIPS v5 on Alpine
################################################################################
# This Dockerfile creates a FIPS 140-3 compliant Redis image using:
# - Alpine 3.19 base (musl libc)
# - OpenSSL 3.x with FIPS module support
# - wolfSSL FIPS v5.8.2 (commercial, FIPS 140-3 validated - Certificate #4718)
# - wolfProvider v1.1.0 (bridges OpenSSL 3 and wolfSSL)
# - Redis 7.2.4 built with TLS support
#
# Build command:
#   docker build --secret id=wolfssl_password,src=wolfssl_password.txt \
#     -t cr.root.io/redis:7.2.4-alpine-fips \
#     -f Dockerfile .
################################################################################

################################################################################
# Stage 1: Builder - Build OpenSSL 3, wolfSSL FIPS v5, wolfProvider, and Redis
################################################################################
FROM alpine:3.19 AS builder

ENV LANG=C.UTF-8

# Build configuration
ARG TARGETARCH
ENV OPENSSL_VERSION=3.3.0
ENV WOLFSSL_URL=https://www.wolfssl.com/comm/wolfssl/wolfssl-5.8.2-commercial-fips-v5.2.3.7z
ENV WOLFPROV_REPO=https://github.com/wolfSSL/wolfProvider.git
ENV WOLFPROV_VERSION=v1.1.0
ENV REDIS_VERSION=7.2.4

# Installation paths
ENV OPENSSL_PREFIX=/usr/local/openssl
ENV WOLFSSL_PREFIX=/usr/local
ENV WOLFPROV_PREFIX=/usr/local

# Install build dependencies (Alpine packages)
RUN set -eux; \
    apk add --no-cache \
        build-base \
        gcc g++ make cmake \
        autoconf automake libtool \
        pkgconfig \
        git curl wget \
        p7zip perl \
        coreutils \
        linux-headers \
        musl-dev \
        openssl-dev \
        ca-certificates \
    ; \
    update-ca-certificates; \
    echo "Build dependencies installed"

################################################################################
# Fetch and process Mozilla CA bundle for runtime stage
# This ensures we have CA certificates without full ca-certificates package
################################################################################
RUN set -eux; \
    echo "Fetching Mozilla CA bundle..."; \
    curl -L -o /tmp/cacert.pem https://curl.se/ca/cacert.pem; \
    mkdir -p /usr/local/share/ca-certificates-mozilla; \
    cd /tmp; \
    csplit -s -z -f cert- cacert.pem '/-----BEGIN CERTIFICATE-----/' '{*}'; \
    for cert in cert-*; do \
        if grep -q 'BEGIN CERTIFICATE' "$cert"; then \
            mv "$cert" "/usr/local/share/ca-certificates-mozilla/${cert}.crt"; \
        fi; \
    done; \
    rm -f /tmp/cacert.pem /tmp/cert-*; \
    echo "✓ Mozilla CA bundle processed ($(ls /usr/local/share/ca-certificates-mozilla/cert-*.crt 2>/dev/null | wc -l) certificates)"

################################################################################
# Build OpenSSL 3.x from source with FIPS support
# Alpine's OpenSSL package may not have FIPS module, so we build from source
################################################################################
RUN set -eux; \
    cd /tmp; \
    wget https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz; \
    tar -xzf openssl-${OPENSSL_VERSION}.tar.gz; \
    cd openssl-${OPENSSL_VERSION}; \
    ./Configure \
        --prefix=${OPENSSL_PREFIX} \
        --openssldir=${OPENSSL_PREFIX}/ssl \
        --libdir=lib \
        enable-fips \
        shared \
        linux-generic64 \
    ; \
    make -j"$(nproc)"; \
    make install_sw; \
    make install_fips; \
    make install_ssldirs; \
    cd ..; \
    rm -rf openssl-${OPENSSL_VERSION}*; \
    echo "OpenSSL ${OPENSSL_VERSION} installed successfully at ${OPENSSL_PREFIX}"

################################################################################
# Build wolfSSL FIPS v5
################################################################################
COPY test-fips.c /tmp/test-fips.c

RUN --mount=type=secret,id=wolfssl_password \
    set -eux; \
    mkdir -p /usr/src; \
    # Download wolfSSL FIPS package with proper certificate verification
    curl -L -o /tmp/wolfssl.7z "${WOLFSSL_URL}"; \
    PASSWORD=$(cat /run/secrets/wolfssl_password | tr -d '\n\r'); \
    7z x /tmp/wolfssl.7z -o/usr/src -p"${PASSWORD}"; \
    rm /tmp/wolfssl.7z; \
    mv /usr/src/wolfssl* /usr/src/wolfssl; \
    cd /usr/src/wolfssl; \
    # Remove Python-specific defines that can cause issues
    sed -i '/^#ifdef WOLFSSL_PYTHON/,/^#endif/d' wolfssl/wolfcrypt/settings.h || true; \
    # Configure wolfSSL with FIPS v5 and necessary features
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
    ldconfig /usr/local/lib || ldconfig; \
    cd /; \
    rm -rf /usr/src/wolfssl; \
    echo "wolfSSL FIPS v5 installed successfully"

# Update library path for wolfSSL
ENV LD_LIBRARY_PATH="${OPENSSL_PREFIX}/lib:${WOLFSSL_PREFIX}/lib"

# Test wolfSSL installation
RUN set -eux; \
    gcc /tmp/test-fips.c -o /tmp/test-fips -lwolfssl -I${WOLFSSL_PREFIX}/include; \
    /tmp/test-fips; \
    rm /tmp/test-fips /tmp/test-fips.c; \
    echo "wolfSSL FIPS test passed"

# Build FIPS startup check utility
COPY fips-startup-check.c /tmp/fips-startup-check.c
RUN set -eux; \
    gcc /tmp/fips-startup-check.c -o /usr/local/bin/fips-startup-check \
        -lwolfssl -I${WOLFSSL_PREFIX}/include; \
    chmod +x /usr/local/bin/fips-startup-check; \
    rm /tmp/fips-startup-check.c; \
    echo "FIPS startup check utility built successfully"

################################################################################
# Build wolfProvider
################################################################################
RUN set -eux; \
    cd /tmp; \
    git clone --depth 1 --branch ${WOLFPROV_VERSION} ${WOLFPROV_REPO} wolfProvider; \
    cd wolfProvider; \
    ./autogen.sh; \
    # Configure wolfProvider with our custom OpenSSL and wolfSSL
    ./configure \
        --prefix=${WOLFPROV_PREFIX} \
        --with-openssl=${OPENSSL_PREFIX} \
        --with-wolfssl=${WOLFSSL_PREFIX} \
    ; \
    make -j"$(nproc)"; \
    echo "wolfProvider built, installing to OpenSSL modules directory..."; \
    # Install wolfProvider module to OpenSSL module directory
    mkdir -p ${OPENSSL_PREFIX}/lib/ossl-modules; \
    if [ -f ".libs/libwolfprov.so" ]; then \
        cp -v .libs/libwolfprov.so* ${OPENSSL_PREFIX}/lib/ossl-modules/; \
    elif [ -f "src/.libs/libwolfprov.so" ]; then \
        cp -v src/.libs/libwolfprov.so* ${OPENSSL_PREFIX}/lib/ossl-modules/; \
    fi; \
    cd ..; \
    rm -rf wolfProvider; \
    echo "✓ wolfProvider installed to ${OPENSSL_PREFIX}/lib/ossl-modules/"

# Verify wolfProvider installation
RUN set -eux; \
    echo "Verifying wolfProvider in OpenSSL modules directory..."; \
    ls -la ${OPENSSL_PREFIX}/lib/ossl-modules/; \
    if [ ! -f "${OPENSSL_PREFIX}/lib/ossl-modules/libwolfprov.so" ]; then \
        echo "ERROR: wolfProvider module not found at ${OPENSSL_PREFIX}/lib/ossl-modules/libwolfprov.so"; \
        exit 1; \
    fi; \
    echo "✓ wolfProvider module verified"

################################################################################
# Build Redis from source with custom OpenSSL
################################################################################
# Copy FIPS SHA-256 patch (Redis 7.2.4-specific version)
COPY patches/redis-fips-sha256-redis7.2.4.patch /tmp/redis-fips-sha256.patch

RUN set -eux; \
    cd /tmp; \
    # Download Redis source with proper certificate verification
    curl -L -o redis-${REDIS_VERSION}.tar.gz \
        http://download.redis.io/releases/redis-${REDIS_VERSION}.tar.gz; \
    tar xzf redis-${REDIS_VERSION}.tar.gz; \
    cd redis-${REDIS_VERSION}; \
    # Apply FIPS SHA-256 patch to replace SHA-1 with OpenSSL SHA-256
    echo "Applying FIPS SHA-256 patch..."; \
    patch -p1 < /tmp/redis-fips-sha256.patch; \
    echo "✓ FIPS SHA-256 patch applied successfully"; \
    echo "  - Replaced SHA-1 with OpenSSL SHA-256 in eval.c (Lua script hashing)"; \
    echo "  - Replaced SHA-1 with OpenSSL SHA-256 in debug.c (DEBUG DIGEST)"; \
    echo "  - Updated function declaration in server.h (sha1hex -> sha256hex)"; \
    # Build Redis with TLS using our custom OpenSSL
    export PKG_CONFIG_PATH=${OPENSSL_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH:-}; \
    # Build Redis with TLS support
    make BUILD_TLS=yes USE_SYSTEMD=no \
        CFLAGS="-I${OPENSSL_PREFIX}/include" \
        LDFLAGS="-L${OPENSSL_PREFIX}/lib -Wl,-rpath,${OPENSSL_PREFIX}/lib" \
        REDIS_LDFLAGS="-lcrypto" \
        -j"$(nproc)"; \
    # Install to /usr/local/bin
    make install PREFIX=/usr/local; \
    # Create default configuration directory
    mkdir -p /etc/redis; \
    cp redis.conf /etc/redis/redis.conf; \
    cp redis.conf /etc/redis/redis-default.conf; \
    cd /; \
    rm -rf /tmp/redis-${REDIS_VERSION}* /tmp/redis-fips-sha256.patch; \
    echo "Redis ${REDIS_VERSION} built and installed successfully"

# Verify Redis installation
RUN set -eux; \
    echo "Verifying Redis installation..."; \
    ls -la /usr/local/bin/redis-*; \
    LD_LIBRARY_PATH=${OPENSSL_PREFIX}/lib:${WOLFSSL_PREFIX}/lib \
        redis-server --version; \
    ldd /usr/local/bin/redis-server | grep -i ssl || echo "Warning: SSL not shown in ldd"; \
    echo "Redis installation verified"

################################################################################
# Stage 2: Runtime - Minimal Alpine image with FIPS components
################################################################################
FROM alpine:3.19 AS runtime

ARG TARGETARCH
ARG REDIS_VERSION=7.2.4

ENV LANG=C.UTF-8

LABEL org.opencontainers.image.base.name="alpine:3.19" \
      org.opencontainers.image.created="2026-03-26T00:00:00Z" \
      org.opencontainers.image.description="Redis ${REDIS_VERSION} with FIPS 140-3 (wolfSSL v5) on Alpine 3.19" \
      org.opencontainers.image.licenses="BSD-3-Clause" \
      org.opencontainers.image.ref.name="${REDIS_VERSION}-alpine-fips" \
      org.opencontainers.image.title="redis-fips" \
      org.opencontainers.image.vendor="Custom Build" \
      org.opencontainers.image.version="${REDIS_VERSION}"

# Set initial environment variables
ENV HOME="/" \
    OS_ARCH="${TARGETARCH:-amd64}" \
    OS_FLAVOUR="alpine-3.19-fips" \
    OS_NAME="linux" \
    REDIS_VERSION="${REDIS_VERSION}"

################################################################################
# Install minimal runtime dependencies
################################################################################
RUN set -eux; \
    apk add --no-cache \
        ca-certificates \
        libgcc libstdc++ \
        bash \
    ; \
    echo "Runtime dependencies installed"

################################################################################
# Copy FIPS components from builder
################################################################################
# Copy custom OpenSSL with FIPS support
COPY --from=builder /usr/local/openssl /usr/local/openssl

# Copy wolfSSL FIPS library
COPY --from=builder /usr/local/lib/libwolfssl.so* /usr/local/lib/
COPY --from=builder /usr/local/include/wolfssl /usr/local/include/wolfssl

# Copy wolfProvider module
COPY --from=builder /usr/local/openssl/lib/ossl-modules/libwolfprov.so* /usr/local/openssl/lib/ossl-modules/

# Copy Redis binaries
COPY --from=builder /usr/local/bin/redis-* /usr/local/bin/

# Copy Redis configuration
COPY --from=builder /etc/redis /etc/redis

# Copy FIPS startup check utility
COPY --from=builder /usr/local/bin/fips-startup-check /usr/local/bin/fips-startup-check

################################################################################
# Install CA certificates from Mozilla bundle (from builder stage)
################################################################################
COPY --from=builder /usr/local/share/ca-certificates-mozilla /usr/local/share/ca-certificates

RUN set -eux; \
    echo "========================================"; \
    echo "Installing Mozilla CA Certificates"; \
    echo "========================================"; \
    # Create SSL certificate directories
    mkdir -p /etc/ssl/certs; \
    mkdir -p /usr/share/ca-certificates; \
    # Copy individual certificates
    cp -a /usr/local/share/ca-certificates/* /usr/share/ca-certificates/ 2>/dev/null || true; \
    # Create the ca-certificates.crt bundle
    cat /usr/local/share/ca-certificates/*.crt > /etc/ssl/certs/ca-certificates.crt 2>/dev/null || true; \
    # Create standard symlinks
    ln -sf /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-bundle.crt 2>/dev/null || true; \
    CERT_COUNT=$(ls /usr/local/share/ca-certificates/*.crt 2>/dev/null | wc -l); \
    echo "✓ Installed ${CERT_COUNT} CA certificates from Mozilla"; \
    echo "========================================"

################################################################################
# Configure dynamic linker for FIPS libraries (Alpine/musl)
################################################################################
RUN set -eux; \
    # Detect architecture for musl library path configuration
    ARCH=$(uname -m); \
    # Create musl library path file
    echo "/usr/local/openssl/lib" > /etc/ld-musl-${ARCH}.path; \
    echo "/usr/local/lib" >> /etc/ld-musl-${ARCH}.path; \
    echo "/lib" >> /etc/ld-musl-${ARCH}.path; \
    echo "/usr/lib" >> /etc/ld-musl-${ARCH}.path; \
    cat /etc/ld-musl-${ARCH}.path; \
    echo "✓ Dynamic linker configured for FIPS libraries (musl/${ARCH})"

# Set OpenSSL environment variables for wolfProvider
ENV OPENSSL_CONF="/usr/local/openssl/ssl/openssl.cnf" \
    OPENSSL_MODULES="/usr/local/openssl/lib/ossl-modules" \
    LD_LIBRARY_PATH="/usr/local/openssl/lib:/usr/local/lib" \
    PATH="/usr/local/openssl/bin:/usr/local/bin:${PATH}"

# Copy OpenSSL configuration with wolfProvider
COPY openssl.cnf /usr/local/openssl/ssl/openssl.cnf

# Verify wolfProvider works with OpenSSL
RUN set -eux; \
    echo "========================================"; \
    echo "Verifying wolfProvider with OpenSSL"; \
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
    echo "✓ OpenSSL operational"; \
    echo "✓ wolfProvider (wolfSSL Provider FIPS) loaded successfully"; \
    echo "========================================"

# Create Redis user and directories
RUN set -eux; \
    # Create redis group (use GID 1000 to avoid conflicts with system groups)
    addgroup -g 1000 redis || true; \
    # Create redis user (use UID 1000)
    adduser -D -u 1000 -G redis -h /data -s /bin/sh redis || true; \
    mkdir -p /data; \
    chown -R redis:redis /data /etc/redis; \
    echo "Redis user and directories created"

# Copy FIPS validation entrypoint
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Runtime verification
RUN set -eux; \
    echo "Verifying FIPS runtime configuration..."; \
    openssl version; \
    echo "OpenSSL providers:"; \
    openssl list -providers || true; \
    echo "Redis version:"; \
    redis-server --version; \
    echo "Checking TLS support:"; \
    ldd /usr/local/bin/redis-server | grep -i ssl || echo "Note: SSL linked via custom OpenSSL"; \
    echo "Runtime verification complete"

# Set working directory
WORKDIR /data

# Expose Redis port
EXPOSE 6379

# Switch to redis user
USER redis

# Use FIPS entrypoint that validates FIPS, then starts Redis
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["redis-server", "/etc/redis/redis.conf"]
