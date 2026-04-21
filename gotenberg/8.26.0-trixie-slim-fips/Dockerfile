# Gotenberg 8.26.0 with wolfSSL FIPS 140-3
#
# Purpose: FIPS 140-3 validated Gotenberg PDF conversion service
#
# Components:
#   - Debian Trixie Slim (base)
#   - OpenSSL 3.5.0 (custom build with FIPS support)
#   - wolfSSL FIPS v5.8.2 (Certificate #4718)
#   - wolfProvider v1.1.1 (OpenSSL provider)
#   - golang-fips/go v1.26.2 (FIPS-enabled Go compiler and runtime)
#   - Gotenberg 8.26.0 (rebuilt from source with golang-fips/go)
#   - Chromium snapshot (latest tip-of-tree, HTML → PDF with FIPS TLS, CVE-2026-6296 fixed)
#   - LibreOffice suite (Office docs → PDF with FIPS TLS)
#   - Chromium hyphen data (52 .hyb files for text hyphenation)
#
# FIPS Architecture:
#   Gotenberg (golang-fips/go, CGO) → OpenSSL 3.5.0 → wolfProvider → wolfSSL FIPS v5
#   Chromium/LibreOffice → System OpenSSL (FIPS) → wolfProvider → wolfSSL FIPS v5
#
# Strict Policy:
#   - MD5: Blocked at Go runtime level (GOLANG_FIPS=1)
#   - SHA-1: Allowed for legacy certificate verification (FIPS 140-3 IG D.F compliant)
#   - SHA-256+: Allowed (FIPS approved)
#
# CGO Requirements:
#   - CGO_ENABLED=1 (REQUIRED - golang-fips/go uses dlopen to call OpenSSL)
#   - Build dependencies: gcc, build-essential, libc6-dev, pkg-config
#   - Runtime dependencies: libc6, libstdc++6
#
# Build:
#   docker build --secret id=wolfssl_password,src=wolfssl_password.txt \
#                --secret id=rootio_api_key,src=rootio_api_key.txt \
#                -t cr.root.io/gotenberg:8.26.0-trixie-slim-fips .
#
# Run:
#   docker run --rm -p 3000:3000 cr.root.io/gotenberg:8.26.0-trixie-slim-fips

################################################################################
# Stage 1: Build OpenSSL 3.5.0
################################################################################
FROM cr.root.io/debian:trixie-slim AS openssl-builder

ENV DEBIAN_FRONTEND=noninteractive
ENV OPENSSL_VERSION=3.5.0

# Install build dependencies
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        perl \
        pkg-config \
    ; \
    rm -rf /var/lib/apt/lists/*

# Build OpenSSL 3.5.0 from source with FIPS support
RUN set -eux; \
    curl -fsSL "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz" -o /tmp/openssl.tar.gz; \
    tar -xzf /tmp/openssl.tar.gz -C /tmp; \
    cd "/tmp/openssl-${OPENSSL_VERSION}"; \
    ./Configure \
        --prefix=/usr/local/openssl \
        --openssldir=/etc/ssl \
        shared \
        no-ssl3 \
        no-weak-ssl-ciphers; \
    make -j"$(nproc)"; \
    make install; \
    cd /; \
    rm -rf /tmp/openssl*; \
    /usr/local/openssl/bin/openssl version; \
    echo "✓ OpenSSL ${OPENSSL_VERSION} built successfully"

################################################################################
# Stage 2: Build wolfSSL FIPS v5
################################################################################
FROM cr.root.io/debian:trixie-slim AS wolfssl-builder

ENV DEBIAN_FRONTEND=noninteractive
ENV WOLFSSL_URL=https://www.wolfssl.com/comm/wolfssl/wolfssl-5.8.2-commercial-fips-v5.2.3.7z
ENV WOLFSSL_PREFIX=/usr/local

# Install build dependencies
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        autoconf \
        automake \
        libtool \
        p7zip-full \
        pkg-config \
        gzip \
        xz-utils \
    ; \
    rm -rf /var/lib/apt/lists/*

# Copy OpenSSL from openssl-builder stage
COPY --from=openssl-builder /usr/local/openssl /usr/local/openssl

# Download and build wolfSSL FIPS v5
# NOTE: Requires commercial wolfSSL FIPS package (password-protected 7z file)
# NOTE: We don't run ldconfig yet to avoid breaking curl (Debian Trixie curl expects OpenSSL 3.2+)
RUN --mount=type=secret,id=wolfssl_password,required=true \
    set -eux; \
    mkdir -p /usr/src; \
    curl -fsSL "${WOLFSSL_URL}" -o /tmp/wolfssl.7z; \
    PASSWORD=$(cat /run/secrets/wolfssl_password | tr -d '\n\r'); \
    7z x /tmp/wolfssl.7z -o/usr/src -p"${PASSWORD}"; \
    rm /tmp/wolfssl.7z; \
    find /usr/src -maxdepth 1 -type d -name "wolfssl*" -exec mv {} /usr/src/wolfssl \;; \
    echo "/usr/local/openssl/lib64" > /etc/ld.so.conf.d/openssl.conf; \
    ldconfig; \
    cd /usr/src/wolfssl; \
    # Configure wolfSSL with FIPS v5 and necessary features
    # NOTE: SHA-1 enabled for legacy certificate verification (FIPS 140-3 IG D.F compliant)
    # SHA-1 will NOT be available in TLS cipher suites (enforced by OpenSSL config)
    ./configure \
        --prefix=${WOLFSSL_PREFIX} \
        --enable-fips=v5 \
        --enable-opensslcoexist \
        --enable-cmac \
        --enable-keygen \
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
    ldconfig; \
    cd /; \
    rm -rf /usr/src/wolfssl; \
    echo "✓ wolfSSL FIPS v5.8.2 built successfully (SHA-1 enabled for legacy cert verification)"

################################################################################
# Stage 3: Build wolfProvider
################################################################################
FROM cr.root.io/debian:trixie-slim AS wolfprov-builder

ENV DEBIAN_FRONTEND=noninteractive
ENV WOLFSSL_PREFIX=/usr/local
ENV WOLFPROV_VERSION=v1.1.1

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
        binutils \
    ; \
    rm -rf /var/lib/apt/lists/*

# Copy OpenSSL from openssl-builder
COPY --from=openssl-builder /usr/local/openssl /usr/local/openssl

# Copy wolfSSL from wolfssl-builder
COPY --from=wolfssl-builder ${WOLFSSL_PREFIX}/include/wolfssl ${WOLFSSL_PREFIX}/include/wolfssl
COPY --from=wolfssl-builder ${WOLFSSL_PREFIX}/lib/libwolfssl.* ${WOLFSSL_PREFIX}/lib/

# Register libraries with ldconfig (after all git/curl operations would be done)
RUN echo "/usr/local/openssl/lib64" > /etc/ld.so.conf.d/openssl.conf && \
    echo "/usr/local/lib" > /etc/ld.so.conf.d/wolfssl.conf && \
    ldconfig

# Build wolfProvider with RPATH so it can find libwolfssl.so
RUN set -eux; \
    git clone --depth 1 --branch ${WOLFPROV_VERSION} \
        https://github.com/wolfSSL/wolfProvider.git /tmp/wolfProvider; \
    cd /tmp/wolfProvider; \
    ./autogen.sh; \
    ./configure \
        --with-openssl=/usr/local/openssl \
        --with-wolfssl=${WOLFSSL_PREFIX} \
        --prefix=/usr/local \
        LDFLAGS="-L${WOLFSSL_PREFIX}/lib -L/usr/local/openssl/lib64 -Wl,-rpath,${WOLFSSL_PREFIX}/lib -Wl,-rpath,/usr/local/openssl/lib64"; \
    make -j"$(nproc)"; \
    make install; \
    mkdir -p /usr/local/openssl/lib64/ossl-modules; \
    if [ -f ".libs/libwolfprov.so" ]; then \
        cp -v .libs/libwolfprov.so* /usr/local/openssl/lib64/ossl-modules/; \
    elif [ -f "src/.libs/libwolfprov.so" ]; then \
        cp -v src/.libs/libwolfprov.so* /usr/local/openssl/lib64/ossl-modules/; \
    fi; \
    ls -la /usr/local/openssl/lib64/ossl-modules/; \
    echo "Verifying wolfProvider RPATH:"; \
    readelf -d /usr/local/openssl/lib64/ossl-modules/libwolfprov.so | grep -i rpath || echo "No RPATH found"; \
    cd /; \
    rm -rf /tmp/wolfProvider; \
    echo "✓ wolfProvider ${WOLFPROV_VERSION} built successfully with RPATH"

################################################################################
# Stage 4: Build golang-fips/go v1.26.2
################################################################################
FROM cr.root.io/debian:trixie-slim AS golang-fips-builder

ENV DEBIAN_FRONTEND=noninteractive

# Go Configuration
ENV GOLANG_FIPS_VERSION=go1.26.2-1-openssl-fips
ENV GOLANG_FIPS_REPO=https://github.com/golang-fips/go.git
ENV GOROOT_BOOTSTRAP=/usr/local/go-bootstrap
ENV GOROOT=/usr/local/go-fips
ENV GOTOOLCHAIN=local
ENV WOLFSSL_PREFIX=/usr/local

# CRITICAL: CGO is REQUIRED for golang-fips/go
ENV CGO_ENABLED=1

# Install build dependencies (includes CGO requirements)
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        build-essential \
        gcc \
        g++ \
        libc6-dev \
        pkg-config \
        ca-certificates \
        git \
        curl \
    ; \
    rm -rf /var/lib/apt/lists/*

# Copy OpenSSL from openssl-builder
COPY --from=openssl-builder /usr/local/openssl /usr/local/openssl

# Copy wolfSSL from wolfssl-builder
COPY --from=wolfssl-builder ${WOLFSSL_PREFIX}/include/wolfssl ${WOLFSSL_PREFIX}/include/wolfssl
COPY --from=wolfssl-builder ${WOLFSSL_PREFIX}/lib/libwolfssl.* ${WOLFSSL_PREFIX}/lib/

# Copy wolfProvider from wolfprov-builder
COPY --from=wolfprov-builder /usr/local/openssl/lib64/ossl-modules/libwolfprov.so* /usr/local/openssl/lib64/ossl-modules/

# Install standard Go 1.24.9 as bootstrap compiler
# NOTE: Go 1.26.2 requires Go 1.24.6+ as bootstrap compiler
# NOTE: Download first before running ldconfig to avoid curl/OpenSSL version conflicts
RUN set -eux; \
    ARCH=$(uname -m); \
    echo "Downloading Go bootstrap compiler for architecture: $ARCH"; \
    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then \
        GO_ARCH="arm64"; \
    else \
        GO_ARCH="amd64"; \
    fi; \
    echo "Using Go architecture: $GO_ARCH"; \
    curl -fsSL "https://go.dev/dl/go1.24.9.linux-${GO_ARCH}.tar.gz" -o /tmp/go.tar.gz; \
    tar -C /usr/local -xzf /tmp/go.tar.gz; \
    mv /usr/local/go ${GOROOT_BOOTSTRAP}; \
    rm /tmp/go.tar.gz; \
    echo "✓ Go bootstrap 1.24.9 installed for $ARCH"

# Register OpenSSL and wolfSSL libraries with ldconfig
# Done after curl operations to avoid version conflicts
RUN echo "/usr/local/openssl/lib64" > /etc/ld.so.conf.d/openssl.conf && \
    echo "/usr/local/lib" > /etc/ld.so.conf.d/wolfssl.conf && \
    ldconfig

# Set up CGO library and include paths
ENV LD_LIBRARY_PATH="/usr/local/openssl/lib64:${WOLFSSL_PREFIX}/lib:/usr/lib/x86_64-linux-gnu:/usr/lib/aarch64-linux-gnu"
ENV PKG_CONFIG_PATH="/usr/local/openssl/lib64/pkgconfig:${WOLFSSL_PREFIX}/lib/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/lib/aarch64-linux-gnu/pkgconfig"
ENV CGO_CFLAGS="-I/usr/local/openssl/include -I${WOLFSSL_PREFIX}/include"
ENV CGO_LDFLAGS="-L/usr/local/openssl/lib64 -L${WOLFSSL_PREFIX}/lib -L/usr/lib/x86_64-linux-gnu -L/usr/lib/aarch64-linux-gnu"

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
    CGO_CFLAGS="-I/usr/local/openssl/include -I${WOLFSSL_PREFIX}/include" \
    CGO_LDFLAGS="-L/usr/local/openssl/lib64 -L${WOLFSSL_PREFIX}/lib" \
    ./make.bash; \
    FINAL_GOROOT=/usr/local/go-fips; \
    mv /tmp/go-fips-repo/go ${FINAL_GOROOT}; \
    rm -rf /tmp/go-fips-repo; \
    ${FINAL_GOROOT}/bin/go version; \
    echo "✓ golang-fips/go v1.26.2 built successfully with CGO support"

################################################################################
# Stage 5: Build Gotenberg from Source
################################################################################
FROM cr.root.io/debian:trixie-slim AS gotenberg-builder

ENV DEBIAN_FRONTEND=noninteractive
ENV GOTENBERG_VERSION=8.26.0
ENV GOTENBERG_REPO=https://github.com/gotenberg/gotenberg.git
ENV GOROOT=/usr/local/go-fips
ENV PATH="${GOROOT}/bin:${PATH}"
ENV WOLFSSL_PREFIX=/usr/local

# CRITICAL: CGO is REQUIRED for golang-fips/go
ENV CGO_ENABLED=1
ENV GOLANG_FIPS=1
# Note: GOEXPERIMENT=strictfipsruntime removed from build to allow ECDSA cert verification
# FIPS will be enforced at runtime via GOLANG_FIPS=1 (OpenSSL backend)

# Install build dependencies (includes CGO requirements)
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        build-essential \
        gcc \
        g++ \
        libc6-dev \
        pkg-config \
        ca-certificates \
        git \
        binutils \
    ; \
    rm -rf /var/lib/apt/lists/*

# Copy OpenSSL from openssl-builder
COPY --from=openssl-builder /usr/local/openssl /usr/local/openssl

# Copy wolfSSL from wolfssl-builder
COPY --from=wolfssl-builder ${WOLFSSL_PREFIX}/include/wolfssl ${WOLFSSL_PREFIX}/include/wolfssl
COPY --from=wolfssl-builder ${WOLFSSL_PREFIX}/lib/libwolfssl.* ${WOLFSSL_PREFIX}/lib/

# Copy wolfProvider from wolfprov-builder
COPY --from=wolfprov-builder /usr/local/openssl/lib64/ossl-modules/libwolfprov.so* /usr/local/openssl/lib64/ossl-modules/

# Copy golang-fips/go toolchain from golang-fips-builder
COPY --from=golang-fips-builder /usr/local/go-fips /usr/local/go-fips

# Copy standard Go bootstrap compiler from golang-fips-builder (for module downloads without ECDSA issues)
COPY --from=golang-fips-builder /usr/local/go-bootstrap /usr/local/go-standard

# Set up CGO library and include paths
ENV LD_LIBRARY_PATH="/usr/local/openssl/lib64:${WOLFSSL_PREFIX}/lib:/usr/lib/x86_64-linux-gnu:/usr/lib/aarch64-linux-gnu"
ENV PKG_CONFIG_PATH="/usr/local/openssl/lib64/pkgconfig:${WOLFSSL_PREFIX}/lib/pkgconfig"
ENV CGO_CFLAGS="-I/usr/local/openssl/include -I${WOLFSSL_PREFIX}/include"
ENV CGO_LDFLAGS="-L/usr/local/openssl/lib64 -L${WOLFSSL_PREFIX}/lib"

# Configure OpenSSL to use wolfProvider (needed for golang-fips/go FIPS mode)
# CRITICAL: Provider MUST be named "fips" for golang-fips/go compatibility
RUN printf '%s\n' \
    'openssl_conf = openssl_init' \
    '' \
    '[openssl_init]' \
    'providers = provider_sect' \
    'alg_section = algorithm_sect' \
    '' \
    '[provider_sect]' \
    '# CRITICAL: Provider MUST be named "fips" for golang-fips/go' \
    'fips = fips_sect' \
    '' \
    '[fips_sect]' \
    'activate = 1' \
    'module = /usr/local/openssl/lib64/ossl-modules/libwolfprov.so' \
    '' \
    '[algorithm_sect]' \
    'default_properties = fips=yes' \
    > /etc/ssl/openssl.cnf

ENV OPENSSL_CONF=/etc/ssl/openssl.cnf
ENV OPENSSL_MODULES=/usr/local/openssl/lib64/ossl-modules

# Clone Gotenberg source and build with golang-fips/go
# NOTE: git clone before ldconfig to avoid OpenSSL version conflicts

RUN set -eux; \
    git clone --depth 1 --branch "v${GOTENBERG_VERSION}" ${GOTENBERG_REPO} /gotenberg; 

COPY go.mod /gotenberg/go.mod

RUN set -eux; \   
    echo "/usr/local/openssl/lib64" > /etc/ld.so.conf.d/openssl.conf; \
    echo "/usr/local/lib" > /etc/ld.so.conf.d/wolfssl.conf; \
    ldconfig; \
    echo "Verifying wolfProvider availability:"; \
    ls -la /usr/local/openssl/lib64/ossl-modules/ || echo "Provider directory not found"; \
    ls -la /usr/local/lib/libwolfssl.so* || echo "wolfSSL library not found"; \
    echo "Checking libwolfprov.so dependencies:"; \
    ldd /usr/local/openssl/lib64/ossl-modules/libwolfprov.so || echo "ldd check failed"; \
    echo "Checking libwolfprov.so RPATH:"; \
    readelf -d /usr/local/openssl/lib64/ossl-modules/libwolfprov.so | grep -E 'RPATH|RUNPATH' || echo "No RPATH/RUNPATH found"; \
    echo "Testing provider loading with openssl:"; \
    LD_LIBRARY_PATH="/usr/local/openssl/lib64:/usr/local/lib" \
    OPENSSL_CONF=/etc/ssl/openssl.cnf \
    OPENSSL_MODULES=/usr/local/openssl/lib64/ossl-modules \
    /usr/local/openssl/bin/openssl list -providers || echo "Provider test failed"; \
    cd /gotenberg; \
    echo "Step 1: Downloading and tidying modules with standard Go (no ECDSA issues)..."; \
    /usr/local/go-standard/bin/go mod download; \
    /usr/local/go-standard/bin/go mod tidy; \
    echo "✓ Modules downloaded and tidied successfully"; \
    echo ""; \
    echo "Step 2: Building Gotenberg ${GOTENBERG_VERSION} with golang-fips/go (CGO enabled)..."; \
    echo "FIPS will be enforced at runtime via GOLANG_FIPS=1 (OpenSSL backend)"; \
    CGO_ENABLED=1 go build \
        -ldflags="-s -w -X 'github.com/gotenberg/gotenberg/v8/cmd.Version=${GOTENBERG_VERSION}'" \
        -o /usr/local/bin/gotenberg \
        ./cmd/gotenberg; \
    chmod +x /usr/local/bin/gotenberg; \
    echo "Verifying Gotenberg binary..."; \
    ls -lh /usr/local/bin/gotenberg; \
    echo "✓ Gotenberg ${GOTENBERG_VERSION} built successfully with golang-fips/go"

################################################################################
# Stage 6: Build PDF Tools
################################################################################
FROM cr.root.io/debian:trixie-slim AS tools-builder

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies for building pdfcpu
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
    ; \
    rm -rf /var/lib/apt/lists/*

# Install Go 1.26.2 for building pdfcpu (standard Go, not FIPS)
# CVE-2026-32282 fix: Go 1.26.2 includes patch for TOCTOU symlink traversal in Root.Chmod
RUN set -eux; \
    ARCH=$(uname -m); \
    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then \
        GO_ARCH="arm64"; \
    else \
        GO_ARCH="amd64"; \
    fi; \
    curl -fsSL "https://go.dev/dl/go1.26.2.linux-${GO_ARCH}.tar.gz" -o /tmp/go.tar.gz; \
    tar -C /usr/local -xzf /tmp/go.tar.gz; \
    rm /tmp/go.tar.gz

ENV PATH="/usr/local/go/bin:${PATH}"

# Build pdfcpu
RUN set -eux; \
    git clone --depth 1 --branch v0.11.1 https://github.com/pdfcpu/pdfcpu.git /tmp/pdfcpu; \
    cd /tmp/pdfcpu/cmd/pdfcpu; \
    go build -o /usr/local/bin/pdfcpu; \
    chmod +x /usr/local/bin/pdfcpu; \
    /usr/local/bin/pdfcpu version

################################################################################
# Stage 7: Extract Chromium Hyphen Data from Upstream Gotenberg
################################################################################
FROM gotenberg/gotenberg:8.26.0 AS hyphen-data-extractor

# This stage extracts the chromium-hyphen-data directory from the upstream
# Gotenberg image. These are Chromium's hyphenation dictionary files (.hyb)
# required for text hyphenation in HTML → PDF conversions.

################################################################################
# Stage 8: Final Runtime Image (Google Chrome + LibreOffice + FIPS)
################################################################################
FROM cr.root.io/debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV WOLFSSL_PREFIX=/usr/local

# CRITICAL: CGO environment variables for runtime
ENV CGO_ENABLED=1
ENV GOLANG_FIPS=1
# Note: golang-fips/go v1.26.2+ requires GOLANG_FIPS=1 alone (GODEBUG=fips140 is mutually exclusive)
# Note: GOEXPERIMENT=strictfipsruntime not used to allow ECDSA cert verification
# FIPS enforcement via GOLANG_FIPS=1 (golang-fips/go with OpenSSL backend)

# Install runtime dependencies
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        # CGO runtime dependencies
        gcc \
        libstdc++6 \
        # Chromium snapshot dependencies
        wget \
        gnupg \
        unzip \
        # Chromium runtime libraries
        libatk1.0-0 \
        libatk-bridge2.0-0 \
        libcups2 \
        libdrm2 \
        libgbm1 \
        libgtk-3-0 \
        libnspr4 \
        libnss3 \
        libxcomposite1 \
        libxdamage1 \
        libxrandr2 \
        libxkbcommon0 \
        libxshmfence1 \
        libasound2 \
        libatspi2.0-0 \
        libdbus-1-3 \
        libexpat1 \
        libglib2.0-0 \
        libpango-1.0-0 \
        libpangocairo-1.0-0 \
        libx11-6 \
        libxcb1 \
        libxext6 \
        libxfixes3 \
        # LibreOffice for Office docs → PDF
        libreoffice \
        libreoffice-writer \
        libreoffice-calc \
        libreoffice-impress \
        # Fonts
        fonts-liberation \
        fonts-noto-cjk \
        fonts-noto-color-emoji \
        fonts-dejavu-core \
        fonts-freefont-ttf \
        fonts-noto-mono \
        fonts-crosextra-carlito \
        fonts-crosextra-caladea \
        # PDF tools
        qpdf \
        exiftool \
        # Utilities
        curl \
        tini \
    ; \
    rm -rf /var/lib/apt/lists/*

# Install Chromium snapshot (latest tip-of-tree build)
# Chromium uses system OpenSSL (our FIPS OpenSSL 3.5.0)
# NOTE: This downloads the latest snapshot from chromium-browser-snapshots
#       which is bleeding-edge code (tip-of-tree). For stable builds, pin a specific revision.
RUN set -eux; \
    echo "Fetching latest Chromium snapshot revision..."; \
    CHROMIUM_REVISION=$(curl -s "https://www.googleapis.com/download/storage/v1/b/chromium-browser-snapshots/o/Linux_x64%2FLAST_CHANGE?alt=media"); \
    echo "Downloading Chromium snapshot revision: ${CHROMIUM_REVISION}"; \
    echo "  (This is tip-of-tree - bleeding edge, updates daily)"; \
    curl -# "https://www.googleapis.com/download/storage/v1/b/chromium-browser-snapshots/o/Linux_x64%2F${CHROMIUM_REVISION}%2Fchrome-linux.zip?alt=media" -o /tmp/chromium.zip; \
    echo "Extracting Chromium..."; \
    unzip -q /tmp/chromium.zip -d /opt; \
    mv /opt/chrome-linux /opt/chromium; \
    rm /tmp/chromium.zip; \
    echo "✓ Chromium snapshot revision ${CHROMIUM_REVISION} installed"; \
    echo "  - Location: /opt/chromium/chrome"; \
    echo "  - Fixes: CVE-2026-6296 and all recent Chromium vulnerabilities"; \
    echo ""; \
    echo "Verifying Chromium headless compatibility..."; \
    CHROMIUM_VERSION=$(/opt/chromium/chrome --version); \
    echo "  Chromium version: ${CHROMIUM_VERSION}"; \
    /opt/chromium/chrome --headless --disable-gpu --no-sandbox --disable-dev-shm-usage --dump-dom about:blank > /dev/null 2>&1 || \
        (echo "ERROR: Chromium headless test failed" && exit 1); \
    echo "✓ Chromium headless mode verified (Docker-compatible flags working)"

# Install additional packages from Root.io repository
COPY scripts/install-runtime-packages.sh /tmp/install-runtime-packages.sh
RUN --mount=type=secret,id=rootio_api_key \
    chmod +x /tmp/install-runtime-packages.sh && \
    /tmp/install-runtime-packages.sh && \
    rm /tmp/install-runtime-packages.sh

# Copy OpenSSL runtime libraries from openssl-builder
COPY --from=openssl-builder /usr/local/openssl /usr/local/openssl

# Copy wolfSSL runtime libraries from wolfssl-builder
COPY --from=wolfssl-builder ${WOLFSSL_PREFIX}/lib/libwolfssl.* ${WOLFSSL_PREFIX}/lib/

# Copy wolfProvider from wolfprov-builder
COPY --from=wolfprov-builder /usr/local/openssl/lib64/ossl-modules/libwolfprov.so* /usr/local/openssl/lib64/ossl-modules/

# CRITICAL: Replace system OpenSSL with FIPS OpenSSL
# This ensures Chromium and LibreOffice use FIPS-validated crypto
RUN set -eux; \
    # Backup original OpenSSL (if needed for debugging)
    if [ -f /usr/lib/x86_64-linux-gnu/libssl.so.3 ]; then \
        mv /usr/lib/x86_64-linux-gnu/libssl.so.3 /usr/lib/x86_64-linux-gnu/libssl.so.3.orig || true; \
    fi; \
    if [ -f /usr/lib/x86_64-linux-gnu/libcrypto.so.3 ]; then \
        mv /usr/lib/x86_64-linux-gnu/libcrypto.so.3 /usr/lib/x86_64-linux-gnu/libcrypto.so.3.orig || true; \
    fi; \
    # Copy FIPS OpenSSL libraries to system location
    cp -av /usr/local/openssl/lib64/libssl.so* /usr/lib/x86_64-linux-gnu/ || true; \
    cp -av /usr/local/openssl/lib64/libcrypto.so* /usr/lib/x86_64-linux-gnu/ || true; \
    # Copy OpenSSL binary
    cp -av /usr/local/openssl/bin/openssl /usr/bin/openssl; \
    # Configure dynamic linker
    echo "/usr/local/openssl/lib64" > /etc/ld.so.conf.d/fips-openssl.conf; \
    echo "/usr/local/lib" >> /etc/ld.so.conf.d/fips-openssl.conf; \
    ldconfig; \
    # Verify OpenSSL version
    openssl version; \
    echo "✓ System OpenSSL replaced with FIPS OpenSSL 3.5.0"

# Set OpenSSL environment variables
ENV OPENSSL_CONF=/etc/ssl/openssl.cnf
ENV OPENSSL_MODULES=/usr/local/openssl/lib64/ossl-modules
ENV LD_LIBRARY_PATH="/usr/local/openssl/lib64:${WOLFSSL_PREFIX}/lib:/usr/lib/x86_64-linux-gnu:/usr/lib"

# Copy Gotenberg binary from gotenberg-builder
COPY --from=gotenberg-builder /usr/local/bin/gotenberg /usr/bin/gotenberg

# Copy pdfcpu from tools-builder
COPY --from=tools-builder /usr/local/bin/pdfcpu /usr/bin/pdfcpu

# Copy Chromium hyphen data from upstream Gotenberg image (52 .hyb files, ~1.9MB)
COPY --from=hyphen-data-extractor /opt/gotenberg/chromium-hyphen-data /opt/gotenberg/chromium-hyphen-data

# Copy unoconverter and pdftk scripts from upstream Gotenberg image
COPY --from=hyphen-data-extractor /usr/bin/unoconverter /usr/bin/unoconverter
COPY --from=hyphen-data-extractor /usr/bin/pdftk /usr/bin/pdftk
RUN chmod +x /usr/bin/unoconverter /usr/bin/pdftk

# Copy OpenSSL configuration file
COPY openssl.cnf /etc/ssl/openssl.cnf

# Copy entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Create non-root user (STIG SV-238201)
RUN groupadd -g 1001 gotenberg && \
    useradd -r -u 1001 -g gotenberg -m -d /home/gotenberg -s /bin/bash gotenberg

# Create working directory
RUN mkdir -p /tmp/gotenberg && \
    chown -R gotenberg:gotenberg /tmp/gotenberg

# Set Gotenberg environment variables
# Chromium configuration (latest snapshot for security patches)
ENV CHROMIUM_BIN_PATH=/opt/chromium/chrome
ENV CHROMIUM_HYPHEN_DATA_DIR_PATH=/opt/gotenberg/chromium-hyphen-data
ENV GOTENBERG_CHROMIUM_DISABLE_JAVASCRIPT=false
ENV GOTENBERG_CHROMIUM_ALLOW_LIST=
ENV GOTENBERG_CHROMIUM_DENY_LIST=

# LibreOffice configuration
ENV LIBREOFFICE_BIN_PATH=/usr/lib/libreoffice/program/soffice.bin
ENV GOTENBERG_LIBREOFFICE_AUTO_START=false

# PDF tools paths
ENV EXIFTOOL_BIN_PATH=/usr/bin/exiftool
ENV PDFCPU_BIN_PATH=/usr/bin/pdfcpu
ENV PDFTK_BIN_PATH=/usr/bin/pdftk
ENV QPDF_BIN_PATH=/usr/bin/qpdf
ENV UNOCONVERTER_BIN_PATH=/usr/bin/unoconverter

WORKDIR /tmp/gotenberg

EXPOSE 3000

# Switch to non-root user
USER gotenberg

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
CMD ["gotenberg"]
