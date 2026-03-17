# Ubuntu FIPS Go Image with Compiler
#
# Purpose: Go FIPS-140-3 image with strict policy and in-container compilation support
#
# Components:
#   - Ubuntu 22.04 (System OpenSSL 3.0.19)
#   - wolfSSL FIPS v5.8.2 (Certificate #4718) with --disable-sha
#   - wolfProvider v1.1.0 (OpenSSL provider)
#   - golang-fips/go v1.25 (FIPS-enabled Go compiler and runtime)
#
# FIPS Architecture:
#   Go App → golang-fips/go runtime → System OpenSSL 3.0.19 → wolfProvider → wolfSSL FIPS v5
#
# Strict Policy:
#   - MD5: Blocked at Go runtime level (GODEBUG=fips140=only)
#   - SHA-1: Blocked at wolfSSL library level (--disable-sha)
#   - SHA-256+: Allowed (FIPS approved)
#
# Capabilities:
#   - Execute pre-compiled Go binaries in FIPS mode
#
# Build: docker build -t ubuntu-fips-go:v1.0.0-ubuntu-22.04 --secret id=wolfssl_password,src=.wolfssl_password .
# Run: docker run --rm ubuntu-fips-go:v1.0.0-ubuntu-22.04

################################################################################
# Stage 1: Build wolfSSL FIPS v5
################################################################################
FROM ubuntu:22.04 AS wolfssl-builder

ENV DEBIAN_FRONTEND=noninteractive

# wolfSSL Configuration
ENV WOLFSSL_URL=https://www.wolfssl.com/comm/wolfssl/wolfssl-5.8.2-commercial-fips-v5.2.3.7z
ENV WOLFSSL_PREFIX=/usr/local

# Install build dependencies (no libssl-dev - we build OpenSSL 3.0.19 from source)
# Security: Explicitly install gzip and xz-utils to get CVE-2022-1271 fixes
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

# Build OpenSSL 3.0.19 from source (replaces Ubuntu's 3.0.2)
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
# NOTE: Requires commercial wolfSSL FIPS package (password-protected 7z file)
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

# Install build dependencies (no libssl-dev - we copy OpenSSL 3.0.19 from previous stage)
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
    # Detect architecture for multi-arch support
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
# Stage 3: Build golang-fips/go and Go Application
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

# Copy OpenSSL 3.0.19 from wolfssl-builder stage
COPY --from=wolfssl-builder /usr/lib/*/libssl.* /tmp/openssl-libs/
COPY --from=wolfssl-builder /usr/lib/*/libcrypto.* /tmp/openssl-libs/
COPY --from=wolfssl-builder /usr/include/openssl /usr/include/openssl
COPY --from=wolfssl-builder /usr/bin/openssl /usr/bin/openssl

# Copy wolfSSL from wolfssl-builder stage
COPY --from=wolfssl-builder ${WOLFSSL_PREFIX}/include/wolfssl ${WOLFSSL_PREFIX}/include/wolfssl
COPY --from=wolfssl-builder ${WOLFSSL_PREFIX}/lib/libwolfssl.* ${WOLFSSL_PREFIX}/lib/

# Copy wolfProvider (uses wildcard for architecture flexibility)
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

# Install build dependencies (no libssl-dev - we copied OpenSSL 3.0.19 from previous stage)
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

# Register wolfSSL libraries with ldconfig (MUST run before Go build)
RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/wolfssl.conf && \
    ldconfig

# Configure OpenSSL to use wolfProvider (needed for golang-fips/go FIPS mode)
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

# Set environment for building Go application
ENV OPENSSL_CONF=/etc/ssl/openssl.cnf
ENV LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:/usr/lib/aarch64-linux-gnu:/usr/local/lib:/usr/lib
ENV PATH="${GOROOT}/bin:${PATH}"
ENV CGO_ENABLED=1
ENV GOLANG_FIPS=1
ENV OPENSSL_FORCE_FIPS_MODE=1

# Copy Go source
COPY src/main.go /app/go/

# Build Go application with golang-fips/go in strict FIPS mode
# GOEXPERIMENT=strictfipsruntime blocks non-FIPS algorithms at runtime
RUN cd /app/go && \
    GOEXPERIMENT=strictfipsruntime ${GOROOT}/bin/go build -o /app/fips-go-demo main.go && \
    chmod +x /app/fips-go-demo && \
    echo "✓ Go application built with golang-fips/go (strict FIPS mode)"

################################################################################
# Final Stage: Ubuntu FIPS Go Runtime
################################################################################
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install runtime and build dependencies for in-container compilation support
# Includes gcc and build tools needed for CGO compilation
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        build-essential \
        gcc \
        libc6-dev \
        pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for security (STIG SV-238201)
# Consistent with Java base image design
RUN groupadd -g 1001 appuser \
    && useradd -r -u 1001 -g appuser -m -d /home/appuser -s /bin/bash appuser

# Copy OpenSSL 3.0.19 runtime libraries and binaries from wolfssl-builder
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
    echo "✓ OpenSSL 3.0.19 runtime installed (libssl3 3.0.2 package metadata removed)"

# Set environment variables for strict FIPS mode
ENV GOLANG_FIPS=1
ENV GODEBUG=fips140=only
ENV GOEXPERIMENT=strictfipsruntime

# Copy wolfSSL runtime libraries (no headers needed)
COPY --from=wolfssl-builder /usr/local/lib/libwolfssl.* /usr/local/lib/

# Copy golang-fips/go toolchain for in-container compilation
COPY --from=go-builder /usr/local/go-fips /usr/local/go-fips

# Set Go environment variables
ENV GOROOT=/usr/local/go-fips
ENV PATH="${GOROOT}/bin:${PATH}"
ENV CGO_ENABLED=1
ENV GOCACHE=/tmp/go-build
ENV GOMODCACHE=/tmp/go/pkg/mod

# Copy compiled Go application
COPY --from=go-builder /app/fips-go-demo /app/fips-go-demo

# Register wolfSSL libraries with ldconfig
RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/wolfssl.conf && \
    ldconfig

# Copy wolfProvider (architecture-aware using RUN to handle conditional paths)
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

# Configure OpenSSL to use wolfProvider (FIPS mode)
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

# Set OpenSSL configuration path
ENV OPENSSL_CONF=/etc/ssl/openssl.cnf
ENV LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:/usr/lib/aarch64-linux-gnu:/usr/local/lib:/usr/lib

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /app

# Create directory structure for user applications and Go cache with proper ownership
RUN mkdir -p /app \
    && mkdir -p /tmp/go-build /tmp/go/pkg/mod \
    && chown -R appuser:appuser /app /tmp/go-build /tmp/go/pkg/mod

# Switch to non-root user for runtime (STIG SV-238201)
USER appuser

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD []
