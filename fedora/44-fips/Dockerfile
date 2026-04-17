################################################################################
# Fedora 44 with wolfSSL FIPS 140-3 and Podman (FIPS-enabled)
#
# This Dockerfile creates a Fedora 44 image with FIPS 140-3 compliance
# using wolfSSL FIPS v5.8.2 (Certificate #4718) and wolfProvider.
# Includes Podman for container management (configured to use FIPS OpenSSL).
#
# Build Requirements:
#   - Docker BuildKit
#   - wolfSSL FIPS package password (passed as build secret)
#
# Build Command:
#   DOCKER_BUILDKIT=1 docker buildx build \
#     --secret id=wolfssl_password,src=wolfssl_password.txt \
#     -t cr.root.io/fedora:44-fips .
#
# Architecture:
#   System/Podman → OpenSSL 3.x → wolfProvider → wolfSSL FIPS v5.8.2
#
# FIPS Enforcement:
#   - TLS 1.2 and TLS 1.3 only
#   - FIPS-approved cipher suites (AES-GCM, AES-CBC + SHA-256+)
#   - Non-FIPS algorithms blocked (RC4, DES, 3DES, MD5, SHA-1)
#
################################################################################

################################################################################
# Stage 1: Builder - Build OpenSSL 3, wolfSSL FIPS v5, and wolfProvider
################################################################################
FROM fedora:44 AS builder

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Build configuration
ENV OPENSSL_VERSION=3.5.0
ENV WOLFSSL_URL=https://www.wolfssl.com/comm/wolfssl/wolfssl-5.8.2-commercial-fips-v5.2.3.7z
ENV WOLFPROVIDER_URL=https://github.com/wolfSSL/wolfProvider/archive/refs/tags/v1.1.1.tar.gz

# Installation paths
ENV OPENSSL_PREFIX=/usr/local/openssl
ENV WOLFSSL_PREFIX=/usr/local
ENV WOLFPROV_PREFIX=/usr/local

# Install builder stage dependencies
RUN set -eux; \
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
COPY src/test-fips.c /tmp/test-fips.c

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
COPY src/test-fips.c /tmp/test-fips.c
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
# Stage 2: Runtime - Fedora 44 with FIPS libraries and Podman 5.8.2
################################################################################
FROM fedora:44 AS runtime

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Metadata labels
LABEL maintainer="root.io Inc." \
      org.opencontainers.image.title="fedora-fips-podman" \
      org.opencontainers.image.description="Fedora 44 with wolfSSL FIPS 140-3 (Certificate #4718) and Podman (FIPS-enabled)" \
      org.opencontainers.image.version="44-fips" \
      org.opencontainers.image.vendor="root.io Inc." \
      wolfssl.version="5.8.2" \
      openssl.version="3.5.0" \
      fips.enabled="true" \
      base="fedora:44"

# Installation paths
ENV OPENSSL_PREFIX=/usr/local/openssl
ENV WOLFSSL_PREFIX=/usr/local

# Copy FIPS components from builder
COPY --from=builder /usr/local/openssl /usr/local/openssl
COPY --from=builder /usr/local/lib/libwolfssl.so* /usr/local/lib/
COPY --from=builder /usr/local/include/wolfssl /usr/local/include/wolfssl
COPY --from=builder /usr/local/bin/test-fips /usr/local/bin/test-fips

# Install runtime dependencies
RUN set -eux; \
    dnf update -y; \
    dnf install -y \
        ca-certificates \
        tzdata \
        crypto-policies \
        crypto-policies-scripts \
    ; \
    dnf clean all; \
    rm -rf /var/cache/dnf

# Configure dynamic linker for FIPS libraries
RUN set -eux; \
    echo "${WOLFSSL_PREFIX}/lib" > /etc/ld.so.conf.d/fips-wolfssl.conf; \
    echo "${OPENSSL_PREFIX}/lib64" >> /etc/ld.so.conf.d/fips-wolfssl.conf; \
    ldconfig; \
    echo "✓ wolfSSL and OpenSSL libraries configured"

################################################################################
# Install Podman (BEFORE OpenSSL replacement to avoid GPG verification issues)
################################################################################
RUN set -eux; \
    echo "========================================"; \
    echo "Installing Podman"; \
    echo "========================================"; \
    # Install Podman and dependencies with standard Fedora OpenSSL
    # After system OpenSSL replacement, Podman will use FIPS OpenSSL via LD_LIBRARY_PATH
    dnf install -y \
        podman \
        containers-common \
        crun \
        conmon \
        slirp4netns \
        fuse-overlayfs \
        shadow-utils \
    ; \
    dnf clean all; \
    rm -rf /var/cache/dnf; \
    # Verify Podman installation
    podman --version; \
    echo "✓ Podman installed successfully"

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

# Verify Podman functionality
RUN set -eux; \
    echo "========================================"; \
    echo "Verifying Podman Functionality"; \
    echo "========================================"; \
    podman --version; \
    podman info || true; \
    echo "✓ Podman verification complete"; \
    echo "========================================"

################################################################################
# Replace system OpenSSL with FIPS OpenSSL
# (Done AFTER Podman installation to avoid breaking DNF/GPG)
################################################################################
# Replace system OpenSSL with FIPS OpenSSL
RUN set -eux; \
    echo "==> Replacing system OpenSSL with FIPS OpenSSL 3.5.0"; \
    # Backup original OpenSSL (optional)
    mv /usr/bin/openssl /usr/bin/openssl.backup 2>/dev/null || true; \
    # Install FIPS OpenSSL to system location
    cp -av ${OPENSSL_PREFIX}/lib64/libssl.so* /usr/lib64/; \
    cp -av ${OPENSSL_PREFIX}/lib64/libcrypto.so* /usr/lib64/; \
    cp -av ${OPENSSL_PREFIX}/bin/openssl /usr/bin/openssl; \
    # Install wolfProvider to system OpenSSL modules directory
    mkdir -p /usr/lib64/ossl-modules; \
    cp -av ${OPENSSL_PREFIX}/lib64/ossl-modules/libwolfprov.so* /usr/lib64/ossl-modules/; \
    ldconfig; \
    echo "✓ System OpenSSL replaced with FIPS OpenSSL 3.5.0"

# Set OpenSSL environment variables for FIPS mode
ENV OPENSSL_CONF="/etc/ssl/openssl.cnf" \
    OPENSSL_MODULES="/usr/lib64/ossl-modules" \
    OPENSSL_FORCE_FIPS_MODE=1 \
    LD_LIBRARY_PATH="/usr/local/lib:/usr/local/openssl/lib64" \
    PATH="/usr/local/openssl/bin:${PATH}"

# Copy OpenSSL configuration with wolfProvider
COPY openssl.cnf /etc/ssl/openssl.cnf

# Verify FIPS OpenSSL configuration
RUN set -eux; \
    echo "========================================"; \
    echo "Verifying FIPS OpenSSL Configuration"; \
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

# Set crypto-policies to FIPS mode (Fedora-specific)
RUN set -eux; \
    echo "FIPS" > /etc/crypto-policies/config; \
    update-crypto-policies --set FIPS || update-crypto-policies; \
    echo "✓ Crypto-policies set to FIPS mode"

# Copy FIPS verification and integrity check scripts
COPY src/fips_init_check.sh /opt/fips/bin/fips_init_check.sh
COPY scripts/integrity-check.sh /usr/local/bin/integrity-check.sh
COPY scripts/enable-fips.sh /usr/local/bin/enable-fips.sh
RUN chmod +x /opt/fips/bin/fips_init_check.sh \
             /usr/local/bin/integrity-check.sh \
             /usr/local/bin/enable-fips.sh

# Copy diagnostics suite
RUN mkdir -p /opt/fips/diagnostics
COPY diagnostics /opt/fips/diagnostics
RUN chmod +x /opt/fips/diagnostics/tests/*.sh /opt/fips/diagnostics/apps/*.sh 2>/dev/null || true

# Generate checksums for integrity verification
RUN mkdir -p /opt/fips/checksums && \
    sha256sum /usr/local/lib/libwolfssl.so* > /opt/fips/checksums/libwolfssl.sha256 && \
    sha256sum /usr/lib64/ossl-modules/libwolfprov.so* > /opt/fips/checksums/libwolfprov.sha256 && \
    sha256sum /usr/local/bin/test-fips > /opt/fips/checksums/test-fips.sha256 && \
    sha256sum /opt/fips/bin/* > /opt/fips/checksums/verification-scripts.sha256

# Copy docker entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod 755 /docker-entrypoint.sh

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

# Set entrypoint
ENTRYPOINT ["/docker-entrypoint.sh"]

# Default command
CMD ["/bin/bash"]

# Health check to verify FIPS mode and Podman
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD openssl list -providers | grep -i wolfssl && podman --version || exit 1
