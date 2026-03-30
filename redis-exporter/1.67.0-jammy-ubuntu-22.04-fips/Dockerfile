# Redis Exporter v1.67.0 FIPS Image with golang-fips
#
# Purpose: Redis Exporter FIPS-140-3 image for Prometheus monitoring
#
# Components:
#   - Ubuntu 22.04 (System OpenSSL 3.0.19)
#   - wolfSSL FIPS v5.8.2 (Certificate #4718)
#   - wolfProvider v1.1.0 (OpenSSL provider)
#   - golang-fips/go v1.25 (FIPS-enabled Go compiler and runtime)
#   - redis_exporter v1.67.0 (Prometheus exporter for Redis metrics)
#
# FIPS Architecture:
#   redis_exporter → golang-fips/go runtime → System OpenSSL 3.0.19 → wolfProvider → wolfSSL FIPS v5
#
# FIPS Policy:
#   - MD5: Blocked at Go runtime level (GODEBUG=fips140=only)
#   - SHA-1: Blocked at wolfSSL library level (--disable-sha)
#   - SHA-256+: Allowed (FIPS approved)
#
# Build: docker build -t cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips --secret id=wolfssl_password,src=wolfssl_password.txt .
# Run: docker run --rm -p 9121:9121 -e REDIS_ADDR=redis://redis:6379 cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips

################################################################################
# Stage 1: Build wolfSSL FIPS v5
################################################################################
FROM ubuntu:22.04 AS wolfssl-builder

ENV DEBIAN_FRONTEND=noninteractive

# wolfSSL Configuration
ENV WOLFSSL_URL=https://www.wolfssl.com/comm/wolfssl/wolfssl-5.8.2-commercial-fips-v5.2.3.7z
ENV WOLFSSL_PREFIX=/usr/local

# Install build dependencies
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        git \
        autoconf \
        automake \
        libtool \
        p7zip-full \
        pkg-config \
        perl \
        gzip \
        xz-utils \
    ; \
    rm -rf /var/lib/apt/lists/*

# Build OpenSSL 3.0.19 from source
RUN set -eux; \
    ARCH=$(uname -m); \
    if [ "$ARCH" = "x86_64" ]; then \
        MULTIARCH="x86_64-linux-gnu"; \
    elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then \
        MULTIARCH="aarch64-linux-gnu"; \
    else \
        MULTIARCH="x86_64-linux-gnu"; \
    fi; \
    echo "Building OpenSSL 3.0.19 for architecture: $ARCH ($MULTIARCH)"; \
    curl -fsSL https://www.openssl.org/source/openssl-3.0.19.tar.gz -o /tmp/openssl.tar.gz; \
    tar -xzf /tmp/openssl.tar.gz -C /tmp; \
    cd /tmp/openssl-3.0.19; \
    ./Configure \
        --prefix=/usr \
        --openssldir=/etc/ssl \
        --libdir=lib/${MULTIARCH} \
        shared \
        no-ssl3 \
        no-weak-ssl-ciphers; \
    make -j"$(nproc)"; \
    make install; \
    ldconfig; \
    cd /; \
    rm -rf /tmp/openssl*; \
    openssl version; \
    echo "✓ OpenSSL 3.0.19 installed successfully"

# Download and build wolfSSL FIPS v5
RUN --mount=type=secret,id=wolfssl_password,required=true \
    set -eux; \
    mkdir -p /usr/src; \
    curl -fsSL "${WOLFSSL_URL}" -o /tmp/wolfssl.7z; \
    PASSWORD=$(cat /run/secrets/wolfssl_password | tr -d '\n\r'); \
    7z x /tmp/wolfssl.7z -o/usr/src -p"${PASSWORD}"; \
    rm /tmp/wolfssl.7z; \
    find /usr/src -maxdepth 1 -type d -name "wolfssl*" -exec mv {} /usr/src/wolfssl \;; \
    cd /usr/src/wolfssl; \
    # Configure wolfSSL with FIPS v5 and necessary features
    # STRICT POLICY: --disable-sha blocks SHA-1 at library level
    ./configure \
        --prefix=${WOLFSSL_PREFIX} \
        --enable-fips=v5 \
        --enable-opensslcoexist \
        --enable-cmac \
        --enable-keygen \
        --enable-aesctr \
        --disable-sha \
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
    ldconfig; \
    cd /; \
    rm -rf /usr/src/wolfssl; \
    echo "wolfSSL FIPS v5 installed successfully (SHA-1 disabled)"

################################################################################
# Stage 2: Build wolfProvider
################################################################################
FROM ubuntu:22.04 AS wolfprov-builder

ENV DEBIAN_FRONTEND=noninteractive
ENV WOLFSSL_PREFIX=/usr/local

# Install build dependencies
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        git \
        autoconf \
        automake \
        libtool \
        pkg-config \
    ; \
    rm -rf /var/lib/apt/lists/*

# Copy OpenSSL 3.0.19 from wolfssl-builder stage
COPY --from=wolfssl-builder /usr/lib/*/libssl.* /tmp/openssl-libs/
COPY --from=wolfssl-builder /usr/lib/*/libcrypto.* /tmp/openssl-libs/
COPY --from=wolfssl-builder /usr/include/openssl /usr/include/openssl
COPY --from=wolfssl-builder /usr/bin/openssl /usr/bin/openssl

RUN set -eux; \
    ARCH=$(uname -m); \
    if [ "$ARCH" = "x86_64" ]; then \
        MULTIARCH="x86_64-linux-gnu"; \
    elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then \
        MULTIARCH="aarch64-linux-gnu"; \
    else \
        MULTIARCH="x86_64-linux-gnu"; \
    fi; \
    mkdir -p /usr/lib/${MULTIARCH}; \
    cp -v /tmp/openssl-libs/* /usr/lib/${MULTIARCH}/; \
    rm -rf /tmp/openssl-libs; \
    ldconfig; \
    openssl version; \
    echo "✓ OpenSSL 3.0.19 copied successfully"

# Copy wolfSSL from wolfssl-builder stage
COPY --from=wolfssl-builder ${WOLFSSL_PREFIX}/include/wolfssl ${WOLFSSL_PREFIX}/include/wolfssl
COPY --from=wolfssl-builder ${WOLFSSL_PREFIX}/lib/libwolfssl.* ${WOLFSSL_PREFIX}/lib/

# Register wolfSSL libraries with ldconfig
RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/wolfssl.conf && \
    ldconfig

# Build wolfProvider v1.1.0
RUN set -eux; \
    git clone --depth 1 --branch v1.1.0 \
        https://github.com/wolfSSL/wolfProvider.git /tmp/wolfProvider; \
    cd /tmp/wolfProvider; \
    ARCH=$(uname -m); \
    echo "Building wolfProvider for architecture: $ARCH"; \
    if [ "$ARCH" = "x86_64" ]; then \
        MULTIARCH="x86_64-linux-gnu"; \
    elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then \
        MULTIARCH="aarch64-linux-gnu"; \
    else \
        MULTIARCH="x86_64-linux-gnu"; \
    fi; \
    echo "Using multiarch path: $MULTIARCH"; \
    ./autogen.sh; \
    ./configure \
        --with-openssl=/usr \
        --with-wolfssl=${WOLFSSL_PREFIX} \
        --prefix=/usr/local \
        LDFLAGS="-L${WOLFSSL_PREFIX}/lib -L/usr/lib/${MULTIARCH}"; \
    make -j"$(nproc)"; \
    make install; \
    mkdir -p /usr/lib/${MULTIARCH}/ossl-modules; \
    if [ -f ".libs/libwolfprov.so" ]; then \
        cp -v .libs/libwolfprov.so* /usr/lib/${MULTIARCH}/ossl-modules/; \
    elif [ -f "src/.libs/libwolfprov.so" ]; then \
        cp -v src/.libs/libwolfprov.so* /usr/lib/${MULTIARCH}/ossl-modules/; \
    fi; \
    ls -la /usr/lib/${MULTIARCH}/ossl-modules/; \
    cd /; \
    rm -rf /tmp/wolfProvider; \
    echo "wolfProvider v1.1.0 installed successfully for $ARCH"

# Verify wolfProvider was built
RUN set -eux; \
    ARCH=$(uname -m); \
    if [ "$ARCH" = "x86_64" ]; then MULTIARCH="x86_64-linux-gnu"; \
    elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then MULTIARCH="aarch64-linux-gnu"; \
    else MULTIARCH="x86_64-linux-gnu"; fi; \
    ls -la /usr/lib/${MULTIARCH}/ossl-modules/; \
    if [ -f "/usr/lib/${MULTIARCH}/ossl-modules/libwolfprov.so" ]; then \
        echo "✓ wolfProvider built successfully"; \
    else \
        echo "✗ ERROR: wolfProvider not found!"; \
        exit 1; \
    fi

################################################################################
# Stage 3: Build golang-fips/go and redis_exporter
################################################################################
FROM ubuntu:22.04 AS go-builder

ENV DEBIAN_FRONTEND=noninteractive

# Go Configuration
ENV GOLANG_FIPS_VERSION=go1.25-fips-release
ENV GOLANG_FIPS_REPO=https://github.com/golang-fips/go.git
ENV GOROOT_BOOTSTRAP=/usr/local/go-bootstrap
ENV GOROOT=/usr/local/go-fips
ENV GOTOOLCHAIN=local
ENV WOLFSSL_PREFIX=/usr/local

# redis_exporter Configuration
ENV REDIS_EXPORTER_VERSION=v1.67.0
ENV REDIS_EXPORTER_REPO=https://github.com/oliver006/redis_exporter.git

# Copy OpenSSL 3.0.19 from wolfssl-builder stage
COPY --from=wolfssl-builder /usr/lib/*/libssl.* /tmp/openssl-libs/
COPY --from=wolfssl-builder /usr/lib/*/libcrypto.* /tmp/openssl-libs/
COPY --from=wolfssl-builder /usr/include/openssl /usr/include/openssl
COPY --from=wolfssl-builder /usr/bin/openssl /usr/bin/openssl

# Copy wolfSSL from wolfssl-builder stage
COPY --from=wolfssl-builder ${WOLFSSL_PREFIX}/include/wolfssl ${WOLFSSL_PREFIX}/include/wolfssl
COPY --from=wolfssl-builder ${WOLFSSL_PREFIX}/lib/libwolfssl.* ${WOLFSSL_PREFIX}/lib/

# Copy wolfProvider
COPY --from=wolfprov-builder /usr/lib/*/ossl-modules/libwolfprov.so* /tmp/wolfprov/

RUN set -eux; \
    ARCH=$(uname -m); \
    if [ "$ARCH" = "x86_64" ]; then MULTIARCH="x86_64-linux-gnu"; \
    elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then MULTIARCH="aarch64-linux-gnu"; \
    else MULTIARCH="x86_64-linux-gnu"; fi; \
    mkdir -p /usr/lib/${MULTIARCH}; \
    cp -v /tmp/openssl-libs/* /usr/lib/${MULTIARCH}/; \
    rm -rf /tmp/openssl-libs; \
    mkdir -p /usr/lib/${MULTIARCH}/ossl-modules; \
    cp -v /tmp/wolfprov/* /usr/lib/${MULTIARCH}/ossl-modules/; \
    rm -rf /tmp/wolfprov; \
    ldconfig; \
    openssl version; \
    ls -la /usr/lib/${MULTIARCH}/ossl-modules/

# Install build dependencies
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        git \
        curl \
        pkg-config \
    ; \
    rm -rf /var/lib/apt/lists/*

# Install standard Go 1.22.6 as bootstrap compiler
RUN set -eux; \
    ARCH=$(uname -m); \
    echo "Downloading Go bootstrap compiler for architecture: $ARCH"; \
    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then \
        GO_ARCH="arm64"; \
    else \
        GO_ARCH="amd64"; \
    fi; \
    echo "Using Go architecture: $GO_ARCH"; \
    curl -fsSL https://go.dev/dl/go1.22.6.linux-${GO_ARCH}.tar.gz -o /tmp/go.tar.gz; \
    tar -C /usr/local -xzf /tmp/go.tar.gz; \
    mv /usr/local/go ${GOROOT_BOOTSTRAP}; \
    rm /tmp/go.tar.gz; \
    echo "✓ Go bootstrap 1.22.6 installed for $ARCH"

# Set up library paths
ENV LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu:/usr/lib/aarch64-linux-gnu:${WOLFSSL_PREFIX}/lib"
ENV PKG_CONFIG_PATH="/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/lib/aarch64-linux-gnu/pkgconfig:${WOLFSSL_PREFIX}/lib/pkgconfig"

# Build golang-fips/go from source with ChaCha20 removal
RUN set -eux; \
    unset GOROOT; \
    export PATH="${GOROOT_BOOTSTRAP}/bin:${PATH}"; \
    git config --global user.email "builder@fips.local"; \
    git config --global user.name "FIPS Builder"; \
    git clone --branch ${GOLANG_FIPS_VERSION} ${GOLANG_FIPS_REPO} /tmp/go-fips-repo; \
    cd /tmp/go-fips-repo; \
    git submodule update --init --recursive; \
    ./scripts/full-initialize-repo.sh; \
    echo ""; \
    echo "========================================"; \
    echo "Removing TLS 1.3 ChaCha20-Poly1305 (Non-FIPS)"; \
    echo "========================================"; \
    cd /tmp/go-fips-repo/go; \
    cd src/crypto/tls; \
    for file in *.go; do \
        if [ -f "$file" ]; then \
            sed -i '/TLS_CHACHA20_POLY1305_SHA256/d' "$file"; \
        fi; \
    done; \
    cd ../../..; \
    if grep -r "TLS_CHACHA20_POLY1305_SHA256" src/crypto/tls/ 2>/dev/null; then \
        echo "ERROR: Failed to remove all ChaCha20-Poly1305 references!"; \
        exit 1; \
    fi; \
    echo "✓ ChaCha20-Poly1305 successfully removed"; \
    echo "========================================"; \
    echo ""; \
    cd /tmp/go-fips-repo/go/src; \
    CGO_ENABLED=1 \
    CGO_CFLAGS="-I/usr/include -I${WOLFSSL_PREFIX}/include" \
    CGO_LDFLAGS="-L/usr/lib/x86_64-linux-gnu -L/usr/lib/aarch64-linux-gnu -L${WOLFSSL_PREFIX}/lib" \
    ./make.bash; \
    FINAL_GOROOT=/usr/local/go-fips; \
    mv /tmp/go-fips-repo/go ${FINAL_GOROOT}; \
    rm -rf /tmp/go-fips-repo; \
    ${FINAL_GOROOT}/bin/go version

# Register wolfSSL libraries with ldconfig
RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/wolfssl.conf && \
    ldconfig

# Configure OpenSSL to use wolfProvider
COPY openssl-wolfprov.cnf /tmp/openssl-wolfprov.cnf

RUN set -eux; \
    ARCH=$(uname -m); \
    if [ "$ARCH" = "x86_64" ]; then \
        MULTIARCH="x86_64-linux-gnu"; \
    elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then \
        MULTIARCH="aarch64-linux-gnu"; \
    else \
        MULTIARCH="x86_64-linux-gnu"; \
    fi; \
    cp /etc/ssl/openssl.cnf /etc/ssl/openssl.cnf.backup; \
    sed "s|/usr/lib/x86_64-linux-gnu/|/usr/lib/${MULTIARCH}/|g" /tmp/openssl-wolfprov.cnf > /etc/ssl/openssl.cnf; \
    rm /tmp/openssl-wolfprov.cnf; \
    echo "OpenSSL configured to use wolfProvider from openssl-wolfprov.cnf"

# Set environment for building redis_exporter
ENV OPENSSL_CONF=/etc/ssl/openssl.cnf
ENV LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:/usr/lib/aarch64-linux-gnu:/usr/local/lib:/usr/lib
ENV PATH="${GOROOT}/bin:${PATH}"
ENV CGO_ENABLED=1
ENV GOLANG_FIPS=1
ENV OPENSSL_FORCE_FIPS_MODE=1

# Clone and build redis_exporter with golang-fips/go
RUN set -eux; \
    echo "========================================"; \
    echo "Building redis_exporter ${REDIS_EXPORTER_VERSION}"; \
    echo "========================================"; \
    git clone --branch ${REDIS_EXPORTER_VERSION} --depth 1 ${REDIS_EXPORTER_REPO} /tmp/redis_exporter; \
    cd /tmp/redis_exporter; \
    # Build with FIPS-enabled Go
    GOEXPERIMENT=strictfipsruntime ${GOROOT}/bin/go build \
        -ldflags="-s -w -X main.BuildVersion=${REDIS_EXPORTER_VERSION} -X main.BuildDate=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        -o /usr/local/bin/redis_exporter \
        .; \
    chmod +x /usr/local/bin/redis_exporter; \
    /usr/local/bin/redis_exporter --version; \
    cd /; \
    rm -rf /tmp/redis_exporter; \
    echo "✓ redis_exporter ${REDIS_EXPORTER_VERSION} built with golang-fips/go (strict FIPS mode)"

# Build FIPS validation utility (test-fips.c)
COPY test-fips.c /tmp/test-fips.c
RUN set -eux; \
    gcc /tmp/test-fips.c -o /usr/local/bin/fips-check \
        -lwolfssl -I${WOLFSSL_PREFIX}/include -L${WOLFSSL_PREFIX}/lib; \
    chmod +x /usr/local/bin/fips-check; \
    /usr/local/bin/fips-check; \
    rm /tmp/test-fips.c; \
    echo "✓ FIPS validation utility built and tested"

################################################################################
# Final Stage: Ubuntu FIPS Redis Exporter Runtime
################################################################################
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for security
RUN groupadd -g 1001 redis-exporter \
    && useradd -r -u 1001 -g redis-exporter -m -d /home/redis-exporter -s /bin/bash redis-exporter

# Copy OpenSSL 3.0.19 runtime libraries
COPY --from=wolfssl-builder /usr/lib/*/libssl.* /tmp/openssl-libs/
COPY --from=wolfssl-builder /usr/lib/*/libcrypto.* /tmp/openssl-libs/
COPY --from=wolfssl-builder /usr/bin/openssl /usr/bin/openssl

RUN set -eux; \
    ARCH=$(uname -m); \
    if [ "$ARCH" = "x86_64" ]; then \
        MULTIARCH="x86_64-linux-gnu"; \
    elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then \
        MULTIARCH="aarch64-linux-gnu"; \
    else \
        MULTIARCH="x86_64-linux-gnu"; \
    fi; \
    mkdir -p /usr/lib/${MULTIARCH}; \
    cp -v /tmp/openssl-libs/* /usr/lib/${MULTIARCH}/; \
    rm -rf /tmp/openssl-libs; \
    ldconfig; \
    dpkg --remove --force-depends libssl3 || true; \
    openssl version; \
    echo "✓ OpenSSL 3.0.19 runtime installed"

# Set environment variables for FIPS mode
ENV GOLANG_FIPS=1
ENV GODEBUG=fips140=only
ENV GOEXPERIMENT=strictfipsruntime
ENV CGO_ENABLED=1

# Copy wolfSSL runtime libraries
COPY --from=wolfssl-builder /usr/local/lib/libwolfssl.* /usr/local/lib/

# Copy redis_exporter binary
COPY --from=go-builder /usr/local/bin/redis_exporter /usr/local/bin/redis_exporter

# Copy FIPS validation utility (compiled in go-builder stage)
COPY --from=go-builder /usr/local/bin/fips-check /usr/local/bin/fips-check

# Register wolfSSL libraries with ldconfig
RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/wolfssl.conf && \
    ldconfig

# Copy wolfProvider
RUN set -eux; \
    ARCH=$(uname -m); \
    if [ "$ARCH" = "x86_64" ]; then \
        MULTIARCH="x86_64-linux-gnu"; \
    elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then \
        MULTIARCH="aarch64-linux-gnu"; \
    else \
        MULTIARCH="x86_64-linux-gnu"; \
    fi; \
    mkdir -p /usr/lib/${MULTIARCH}/ossl-modules

COPY --from=wolfprov-builder /usr/lib/*/ossl-modules/libwolfprov.so* /tmp/wolfprov/

RUN set -eux; \
    ARCH=$(uname -m); \
    if [ "$ARCH" = "x86_64" ]; then \
        MULTIARCH="x86_64-linux-gnu"; \
    elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then \
        MULTIARCH="aarch64-linux-gnu"; \
    else \
        MULTIARCH="x86_64-linux-gnu"; \
    fi; \
    cp -v /tmp/wolfprov/* /usr/lib/${MULTIARCH}/ossl-modules/; \
    rm -rf /tmp/wolfprov; \
    ls -la /usr/lib/${MULTIARCH}/ossl-modules/

# Configure OpenSSL to use wolfProvider
COPY openssl-wolfprov.cnf /tmp/openssl-wolfprov.cnf

RUN set -eux; \
    ARCH=$(uname -m); \
    if [ "$ARCH" = "x86_64" ]; then \
        MULTIARCH="x86_64-linux-gnu"; \
    elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then \
        MULTIARCH="aarch64-linux-gnu"; \
    else \
        MULTIARCH="x86_64-linux-gnu"; \
    fi; \
    cp /etc/ssl/openssl.cnf /etc/ssl/openssl.cnf.backup; \
    sed "s|/usr/lib/x86_64-linux-gnu/|/usr/lib/${MULTIARCH}/|g" /tmp/openssl-wolfprov.cnf > /etc/ssl/openssl.cnf; \
    rm /tmp/openssl-wolfprov.cnf; \
    echo "OpenSSL configured to use wolfProvider"

# Set OpenSSL configuration path
ENV OPENSSL_CONF=/etc/ssl/openssl.cnf
ENV LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:/usr/lib/aarch64-linux-gnu:/usr/local/lib:/usr/lib

# Copy entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Set working directory
WORKDIR /app

# Runtime verification
RUN set -eux; \
    echo "Verifying FIPS runtime configuration..."; \
    openssl version; \
    echo "OpenSSL providers:"; \
    openssl list -providers || true; \
    echo "redis_exporter version:"; \
    redis_exporter --version; \
    echo "Runtime verification complete"

# Expose Prometheus metrics port
EXPOSE 9121

# Default environment variables (can be overridden)
ENV REDIS_ADDR=redis://localhost:6379
ENV REDIS_EXPORTER_LOG_FORMAT=txt
ENV REDIS_EXPORTER_DEBUG=false
ENV REDIS_EXPORTER_WEB_LISTEN_ADDRESS=:9121
ENV REDIS_EXPORTER_WEB_TELEMETRY_PATH=/metrics

# Switch to non-root user
USER redis-exporter

# Use FIPS entrypoint that validates FIPS, then starts redis_exporter
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["redis_exporter"]
