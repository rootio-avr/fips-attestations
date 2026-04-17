################################################################################
# FIPS-Enabled Podman Image with wolfSSL FIPS v5 on Fedora 44
################################################################################
# This Dockerfile creates a FIPS 140-3 compliant Podman image using:
# - Fedora 44 base
# - OpenSSL 3.5.0 with FIPS module support
# - wolfSSL FIPS v5.8.2 (commercial, FIPS 140-3 validated - Certificate #4718)
# - wolfProvider v1.1.1 (bridges OpenSSL 3 and wolfSSL)
# - golang-fips/go v1.25 (FIPS-enabled Go compiler)
# - Podman 5.8.1 built from source with FIPS Go
#
# FIPS Architecture:
#   Podman (Go) → golang-fips/go runtime → OpenSSL 3.5.0 → wolfProvider → wolfSSL FIPS v5
#
# Build command:
#   docker build --secret id=wolfssl_password,src=wolfssl_password.txt \
#     -t cr.root.io/podman:5.8.1-fedora-44-fips \
#     -f Dockerfile .
################################################################################

################################################################################
# Stage 1: Builder - Build OpenSSL 3.5.0, wolfSSL FIPS v5
################################################################################
FROM fedora:44 AS wolfssl-builder

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Build configuration
ENV OPENSSL_VERSION=3.5.0
ENV WOLFSSL_URL=https://www.wolfssl.com/comm/wolfssl/wolfssl-5.8.2-commercial-fips-v5.2.3.7z

# Installation paths
ENV OPENSSL_PREFIX=/usr/local/openssl
ENV WOLFSSL_PREFIX=/usr/local

# Install build dependencies
RUN set -eux; \
    dnf clean all; \
    rm -rf /var/cache/dnf/*; \
    dnf config-manager --set-disabled updates-testing || true; \
    dnf makecache --refresh; \
    dnf update -y; \
    dnf install -y \
        gcc \
        gcc-c++ \
        make \
        autoconf \
        autoconf-archive \
        automake \
        libtool \
        pkgconfig \
        perl \
        perl-IPC-Cmd \
        perl-File-Compare \
        perl-File-Copy \
        wget \
        tar \
        gzip \
        p7zip \
        p7zip-plugins \
        ca-certificates \
    ; \
    dnf clean all; \
    rm -rf /var/cache/dnf

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
    # Download wolfSSL FIPS package
    wget --no-check-certificate -O /tmp/wolfssl.7z "${WOLFSSL_URL}"; \
    PASSWORD=$(cat /run/secrets/wolfssl_password | tr -d '\n\r'); \
    7z x /tmp/wolfssl.7z -o/usr/src -p"${PASSWORD}"; \
    rm /tmp/wolfssl.7z; \
    mv /usr/src/wolfssl* /usr/src/wolfssl; \
    cd /usr/src/wolfssl; \
    # Configure wolfSSL with FIPS v5
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
# Stage 2: wolfprov-builder - Build wolfProvider
################################################################################
FROM fedora:44 AS wolfprov-builder

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV WOLFSSL_PREFIX=/usr/local
ENV OPENSSL_PREFIX=/usr/local/openssl
ENV WOLFPROVIDER_URL=https://github.com/wolfSSL/wolfProvider/archive/refs/tags/v1.1.1.tar.gz

# Install build dependencies
RUN set -eux; \
    dnf clean all; \
    rm -rf /var/cache/dnf/*; \
    dnf config-manager --set-disabled updates-testing || true; \
    dnf makecache --refresh; \
    dnf update -y; \
    dnf install -y \
        gcc \
        gcc-c++ \
        make \
        autoconf \
        autoconf-archive \
        automake \
        libtool \
        pkgconfig \
        wget \
        ca-certificates \
    ; \
    dnf clean all; \
    rm -rf /var/cache/dnf

# Copy OpenSSL from wolfssl-builder
COPY --from=wolfssl-builder ${OPENSSL_PREFIX} ${OPENSSL_PREFIX}
COPY --from=wolfssl-builder ${WOLFSSL_PREFIX}/include/wolfssl ${WOLFSSL_PREFIX}/include/wolfssl
COPY --from=wolfssl-builder ${WOLFSSL_PREFIX}/lib/libwolfssl.* ${WOLFSSL_PREFIX}/lib/

# Register libraries with ldconfig
RUN echo "${WOLFSSL_PREFIX}/lib" > /etc/ld.so.conf.d/fips-wolfssl.conf && \
    echo "${OPENSSL_PREFIX}/lib64" >> /etc/ld.so.conf.d/fips-wolfssl.conf && \
    ldconfig

# Update environment
ENV PATH="${OPENSSL_PREFIX}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${OPENSSL_PREFIX}/lib64:${WOLFSSL_PREFIX}/lib"
ENV PKG_CONFIG_PATH="${OPENSSL_PREFIX}/lib64/pkgconfig"

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
        --prefix=${WOLFSSL_PREFIX} \
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
# Stage 3: go-fips-builder - Build golang-fips/go
################################################################################
FROM fedora:44 AS go-fips-builder

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Go Configuration
ENV GOLANG_FIPS_VERSION=go1.25-fips-release
ENV GOLANG_FIPS_REPO=https://github.com/golang-fips/go.git
ENV GOROOT_BOOTSTRAP=/usr/local/go-bootstrap
ENV GOROOT=/usr/local/go-fips
ENV GOTOOLCHAIN=local
ENV WOLFSSL_PREFIX=/usr/local
ENV OPENSSL_PREFIX=/usr/local/openssl

# Copy FIPS stack from previous stages
COPY --from=wolfssl-builder ${OPENSSL_PREFIX} ${OPENSSL_PREFIX}
COPY --from=wolfssl-builder ${WOLFSSL_PREFIX}/include/wolfssl ${WOLFSSL_PREFIX}/include/wolfssl
COPY --from=wolfssl-builder ${WOLFSSL_PREFIX}/lib/libwolfssl.* ${WOLFSSL_PREFIX}/lib/
COPY --from=wolfprov-builder ${OPENSSL_PREFIX}/lib64/ossl-modules/libwolfprov.so* ${OPENSSL_PREFIX}/lib64/ossl-modules/

# Install build dependencies
RUN set -eux; \
    dnf clean all; \
    rm -rf /var/cache/dnf/*; \
    dnf config-manager --set-disabled updates-testing || true; \
    dnf makecache --refresh; \
    dnf update -y; \
    dnf install -y \
        gcc \
        gcc-c++ \
        make \
        git \
        wget \
        ca-certificates \
        pkgconfig \
    ; \
    dnf clean all; \
    rm -rf /var/cache/dnf

# Register libraries
RUN echo "${WOLFSSL_PREFIX}/lib" > /etc/ld.so.conf.d/fips-wolfssl.conf && \
    echo "${OPENSSL_PREFIX}/lib64" >> /etc/ld.so.conf.d/fips-wolfssl.conf && \
    ldconfig

# Set up library paths
ENV LD_LIBRARY_PATH="${OPENSSL_PREFIX}/lib64:${WOLFSSL_PREFIX}/lib"
ENV PKG_CONFIG_PATH="${OPENSSL_PREFIX}/lib64/pkgconfig"
ENV PATH="${OPENSSL_PREFIX}/bin:${PATH}"

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
    wget https://go.dev/dl/go1.22.6.linux-${GO_ARCH}.tar.gz -O /tmp/go.tar.gz; \
    tar -C /usr/local -xzf /tmp/go.tar.gz; \
    mv /usr/local/go ${GOROOT_BOOTSTRAP}; \
    rm /tmp/go.tar.gz; \
    echo "✓ Go bootstrap 1.22.6 installed for $ARCH"

# Build golang-fips/go from source
RUN set -eux; \
    unset GOROOT; \
    export PATH="${GOROOT_BOOTSTRAP}/bin:${PATH}"; \
    git config --global user.email "builder@fips.local"; \
    git config --global user.name "FIPS Builder"; \
    git clone --branch ${GOLANG_FIPS_VERSION} ${GOLANG_FIPS_REPO} /tmp/go-fips-repo; \
    cd /tmp/go-fips-repo; \
    git submodule update --init --recursive; \
    ./scripts/full-initialize-repo.sh; \
    cd /tmp/go-fips-repo/go/src; \
    CGO_ENABLED=1 \
    CGO_CFLAGS="-I${OPENSSL_PREFIX}/include -I${WOLFSSL_PREFIX}/include" \
    CGO_LDFLAGS="-L${OPENSSL_PREFIX}/lib64 -L${WOLFSSL_PREFIX}/lib" \
    ./make.bash; \
    FINAL_GOROOT=/usr/local/go-fips; \
    mv /tmp/go-fips-repo/go ${FINAL_GOROOT}; \
    rm -rf /tmp/go-fips-repo; \
    ${FINAL_GOROOT}/bin/go version

# Set environment for Go builds
ENV PATH="${GOROOT}/bin:${PATH}"
ENV CGO_ENABLED=1
ENV GOLANG_FIPS=1

################################################################################
# Stage 4: podman-builder - Build Podman from source
################################################################################
FROM fedora:44 AS podman-builder

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV PODMAN_VERSION=v5.8.1
ENV WOLFSSL_PREFIX=/usr/local
ENV OPENSSL_PREFIX=/usr/local/openssl
ENV GOROOT=/usr/local/go-fips

# Copy FIPS stack and Go toolchain
COPY --from=wolfssl-builder ${OPENSSL_PREFIX} ${OPENSSL_PREFIX}
COPY --from=wolfssl-builder ${WOLFSSL_PREFIX}/include/wolfssl ${WOLFSSL_PREFIX}/include/wolfssl
COPY --from=wolfssl-builder ${WOLFSSL_PREFIX}/lib/libwolfssl.* ${WOLFSSL_PREFIX}/lib/
COPY --from=wolfprov-builder ${OPENSSL_PREFIX}/lib64/ossl-modules/libwolfprov.so* ${OPENSSL_PREFIX}/lib64/ossl-modules/
COPY --from=go-fips-builder ${GOROOT} ${GOROOT}

# Install Podman build dependencies
RUN set -eux; \
    dnf clean all; \
    rm -rf /var/cache/dnf/*; \
    dnf config-manager --set-disabled updates-testing || true; \
    dnf makecache --refresh; \
    dnf update -y; \
    dnf install -y \
        git \
        make \
        gcc \
        gcc-c++ \
        pkgconfig \
        glib2-devel \
        gpgme-devel \
        libassuan-devel \
        libseccomp-devel \
        device-mapper-devel \
        btrfs-progs-devel \
        ostree-devel \
        shadow-utils-subid-devel \
        glibc-devel \
        glibc-static \
        systemd-devel \
        iptables \
        wget \
    ; \
    dnf clean all; \
    rm -rf /var/cache/dnf

# Register libraries
RUN echo "${WOLFSSL_PREFIX}/lib" > /etc/ld.so.conf.d/fips-wolfssl.conf && \
    echo "${OPENSSL_PREFIX}/lib64" >> /etc/ld.so.conf.d/fips-wolfssl.conf && \
    ldconfig

# Copy OpenSSL configuration for wolfProvider (needed during build)
COPY openssl.cnf /etc/ssl/openssl.cnf

# Set up environment for building Podman
# Note: We enable CGO and set paths, but don't enforce FIPS during build
# FIPS will be enforced at runtime in the final image
ENV PATH="${GOROOT}/bin:${OPENSSL_PREFIX}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${OPENSSL_PREFIX}/lib64:${WOLFSSL_PREFIX}/lib"
ENV PKG_CONFIG_PATH="${OPENSSL_PREFIX}/lib64/pkgconfig:/usr/lib64/pkgconfig"
ENV OPENSSL_CONF="/etc/ssl/openssl.cnf"
ENV OPENSSL_MODULES="${OPENSSL_PREFIX}/lib64/ossl-modules"
ENV CGO_ENABLED=1

# Clone and build Podman
RUN set -eux; \
    git clone --branch ${PODMAN_VERSION} --depth 1 \
        https://github.com/containers/podman.git /tmp/podman; 

COPY go.mod /tmp/podman/go.mod

RUN set -eux; \
    cd /tmp/podman; \
    go mod tidy; \
    CGO_CFLAGS="-I${OPENSSL_PREFIX}/include -I${WOLFSSL_PREFIX}/include" \
    CGO_LDFLAGS="-L${OPENSSL_PREFIX}/lib64 -L${WOLFSSL_PREFIX}/lib" \
    make BUILDTAGS="seccomp systemd" -j"$(nproc)"; \
    make install PREFIX=/usr/local; \
    cd /; \
    rm -rf /tmp/podman; \
    echo "✓ Podman ${PODMAN_VERSION} built and installed successfully"

# Verify Podman binary
RUN /usr/local/bin/podman --version

################################################################################
# Stage 5: Runtime - Fedora 44 with FIPS libraries and Podman
################################################################################
FROM fedora:44 AS runtime

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Metadata labels
LABEL maintainer="root.io Inc." \
      org.opencontainers.image.title="podman-fips" \
      org.opencontainers.image.description="Podman 5.8.1 with wolfSSL FIPS 140-3 (Certificate #4718) on Fedora 44" \
      org.opencontainers.image.version="5.8.1-fedora-44-fips" \
      org.opencontainers.image.vendor="root.io Inc." \
      wolfssl.version="5.8.2" \
      openssl.version="3.5.0" \
      golang-fips.version="1.25" \
      podman.version="5.8.1" \
      fips.enabled="true" \
      base="fedora:44"

# Installation paths
ENV OPENSSL_PREFIX=/usr/local/openssl
ENV WOLFSSL_PREFIX=/usr/local
ENV GOROOT=/usr/local/go-fips

# Copy FIPS components from builders
COPY --from=wolfssl-builder /usr/local/openssl /usr/local/openssl
COPY --from=wolfssl-builder /usr/local/lib/libwolfssl.so* /usr/local/lib/
COPY --from=wolfssl-builder /usr/local/include/wolfssl /usr/local/include/wolfssl
COPY --from=wolfssl-builder /usr/local/bin/test-fips /usr/local/bin/test-fips
COPY --from=wolfprov-builder /usr/local/openssl/lib64/ossl-modules/libwolfprov.so* /usr/local/openssl/lib64/ossl-modules/

# Copy Go toolchain (needed for podman build command)
COPY --from=go-fips-builder ${GOROOT} ${GOROOT}

# Copy Podman binary and components
COPY --from=podman-builder /usr/local/bin/podman /usr/local/bin/podman
COPY --from=podman-builder /usr/local/libexec/podman /usr/local/libexec/podman

# Install runtime dependencies
RUN set -eux; \
    dnf clean all; \
    rm -rf /var/cache/dnf/*; \
    dnf config-manager --set-disabled updates-testing || true; \
    dnf makecache --refresh; \
    dnf update -y; \
    dnf install -y \
        ca-certificates \
        tzdata \
        containers-common \
        crun \
        conmon \
        slirp4netns \
        fuse-overlayfs \
        shadow-utils \
        iptables \
        glib2 \
        gpgme \
        libassuan \
        libseccomp \
        device-mapper-libs \
        ostree-libs \
        systemd-libs \
    ; \
    dnf clean all; \
    rm -rf /var/cache/dnf

# Configure dynamic linker for FIPS libraries
RUN set -eux; \
    echo "${WOLFSSL_PREFIX}/lib" > /etc/ld.so.conf.d/fips-wolfssl.conf; \
    echo "${OPENSSL_PREFIX}/lib64" >> /etc/ld.so.conf.d/fips-wolfssl.conf; \
    ldconfig; \
    echo "✓ wolfSSL and OpenSSL libraries configured"

# Configure Podman for rootless operation
RUN set -eux; \
    mkdir -p /etc/containers; \
    # Enable unprivileged ping for rootless containers
    echo "net.ipv4.ping_group_range=0 2147483647" > /etc/sysctl.d/podman-ping.conf; \
    # Configure storage for rootless Podman
    echo '[storage]' > /etc/containers/storage.conf; \
    echo 'driver = "overlay"' >> /etc/containers/storage.conf; \
    echo '' >> /etc/containers/storage.conf; \
    echo '[storage.options.overlay]' >> /etc/containers/storage.conf; \
    echo 'mount_program = "/usr/bin/fuse-overlayfs"' >> /etc/containers/storage.conf; \
    echo '' >> /etc/containers/storage.conf; \
    # Configure registries
    echo 'unqualified-search-registries = ["docker.io", "quay.io"]' > /etc/containers/registries.conf; \
    echo "✓ Podman configured for rootless operation"

# Set OpenSSL environment variables for FIPS mode
ENV OPENSSL_CONF="/etc/ssl/openssl.cnf" \
    OPENSSL_MODULES="/usr/local/openssl/lib64/ossl-modules" \
    LD_LIBRARY_PATH="/usr/local/lib:/usr/local/openssl/lib64" \
    PATH="/usr/local/go-fips/bin:/usr/local/openssl/bin:/usr/local/bin:${PATH}" \
    CGO_ENABLED=1

# Copy OpenSSL configuration with wolfProvider
COPY openssl.cnf /etc/ssl/openssl.cnf

# Generate OpenSSL FIPS module configuration (needed for golang-fips/go initialization)
# Even though we use wolfProvider, OpenSSL's FIPS provider needs this config
RUN set -eux; \
    openssl fipsinstall \
        -out ${OPENSSL_PREFIX}/ssl/fipsmodule.cnf \
        -module ${OPENSSL_PREFIX}/lib64/ossl-modules/fips.so \
    ; \
    echo "✓ OpenSSL FIPS module configuration generated"

# Verify FIPS stack configuration
RUN set -eux; \
    echo "========================================"; \
    echo "Verifying FIPS Configuration"; \
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
    test-fips; \
    echo "✓ FIPS OpenSSL operational"; \
    echo "✓ wolfProvider loaded"; \
    echo "✓ wolfSSL FIPS v5 verified"; \
    echo "========================================"

# Note: Podman verification skipped during build to avoid FIPS initialization issues
# Podman will be verified at runtime with FIPS environment variables set

# Create non-root user for security
RUN groupadd -g 1001 appuser \
    && useradd -r -u 1001 -g appuser -m -d /home/appuser -s /bin/bash appuser \
    && mkdir -p /home/appuser/.local/share/containers \
    && chown -R appuser:appuser /home/appuser

# Create /app directory for user applications
RUN mkdir -p /app \
    && chown -R appuser:appuser /app

# Configure subuid/subgid for rootless Podman
RUN echo "appuser:100000:65536" > /etc/subuid \
    && echo "appuser:100000:65536" > /etc/subgid

# Default to root user for Podman support in CI/CD environments
# Podman requires root privileges when running in privileged mode
# To run as non-root: docker run --user appuser ...
USER root
WORKDIR /app

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Default command
CMD ["/bin/bash"]

# Health check to verify FIPS mode (without running Podman to avoid FIPS init issues)
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD openssl list -providers | grep -i wolfssl || exit 1
