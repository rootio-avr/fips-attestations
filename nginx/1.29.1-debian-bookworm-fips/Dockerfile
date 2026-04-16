################################################################################
# Nginx 1.29.1 with wolfSSL FIPS 140-3 Docker Image
#
# This Dockerfile creates an Nginx 1.29.1 image with FIPS 140-3 compliance
# using wolfSSL FIPS v5.8.2 (Certificate #4718) and wolfProvider.
#
# Build Requirements:
#   - Docker BuildKit
#   - wolfSSL FIPS package password (passed as build secret)
#
# Build Command:
#   DOCKER_BUILDKIT=1 docker buildx build \
#     --secret id=wolfssl_password,src=wolfssl_password.txt \
#     -t cr.root.io/nginx:1.29.1-debian-bookworm-fips .
#
# Architecture:
#   Nginx → OpenSSL 3.x → wolfProvider → wolfSSL FIPS v5.8.2
#
# FIPS Enforcement:
#   - TLS 1.2 and TLS 1.3 only
#   - FIPS-approved cipher suites (AES-GCM, AES-CBC + SHA-256+)
#   - Non-FIPS algorithms blocked (RC4, DES, 3DES, MD5, SHA-1 in ciphersuites)
#
################################################################################

################################################################################
# Stage 1: Builder - Build OpenSSL 3, wolfSSL FIPS v5, wolfProvider, and Nginx
################################################################################
FROM debian:bookworm-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8

# Build configuration
ENV OPENSSL_VERSION=3.0.19
ENV WOLFSSL_URL=https://www.wolfssl.com/comm/wolfssl/wolfssl-5.8.2-commercial-fips-v5.2.3.7z
ENV WOLFPROV_REPO=https://github.com/wolfSSL/wolfProvider.git
ENV WOLFPROV_VERSION=v1.1.0
ENV NGINX_VERSION=1.29.1

# Installation paths
ENV OPENSSL_PREFIX=/usr/local/openssl
ENV WOLFSSL_PREFIX=/usr/local
ENV WOLFPROV_PREFIX=/usr/local
ENV NGINX_PREFIX=/usr/local/nginx

# Install builder stage dependencies via Root.io repository
COPY scripts/install-builder-packages.sh /tmp/install-packages.sh
RUN --mount=type=secret,id=rootio_api_key \
    chmod +x /tmp/install-packages.sh && \
    /tmp/install-packages.sh && \
    rm /tmp/install-packages.sh

################################################################################
# Build OpenSSL 3.0.x (for wolfProvider compatibility)
################################################################################
RUN set -eux; \
    cd /tmp; \
    curl -fsSL -o openssl-${OPENSSL_VERSION}.tar.gz https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz; \
    tar -xzf openssl-${OPENSSL_VERSION}.tar.gz; \
    cd openssl-${OPENSSL_VERSION}; \
    ./Configure \
        --prefix=${OPENSSL_PREFIX} \
        --openssldir=${OPENSSL_PREFIX}/ssl \
        --libdir=lib64 \
        shared \
        linux-x86_64 \
    ; \
    make -j"$(nproc)"; \
    make install_sw; \
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
    curl -fsSLk -o /tmp/wolfssl.7z "${WOLFSSL_URL}"; \
    PASSWORD=$(cat /run/secrets/wolfssl_password | tr -d '\n\r'); \
    7z x /tmp/wolfssl.7z -o/usr/src -p"${PASSWORD}"; \
    rm /tmp/wolfssl.7z; \
    mv /usr/src/wolfssl* /usr/src/wolfssl; \
    cd /usr/src/wolfssl; \
    # Configure wolfSSL with FIPS v5 (matching PostgreSQL/RabbitMQ configuration)
    ./configure \
        --prefix=${WOLFSSL_PREFIX} \
        --enable-fips=v5 \
        --enable-opensslcoexist \
        --enable-cmac \
        --enable-keygen \
        --enable-sha \
        --enable-des3 \
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
    echo "wolfSSL FIPS v5 installed successfully"

# Update library path for wolfSSL
ENV LD_LIBRARY_PATH="${OPENSSL_PREFIX}/lib64:${WOLFSSL_PREFIX}/lib"

# Test wolfSSL installation
RUN set -eux; \
    gcc /tmp/test-fips.c -o /tmp/test-fips -lwolfssl -I${WOLFSSL_PREFIX}/include; \
    /tmp/test-fips; \
    rm /tmp/test-fips /tmp/test-fips.c; \
    echo "wolfSSL FIPS test passed"

# Build FIPS startup check utility
COPY src/test-fips.c /tmp/fips-startup-check.c
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
    ./configure \
        --prefix=${WOLFPROV_PREFIX} \
        --with-openssl=${OPENSSL_PREFIX} \
        --with-wolfssl=${WOLFSSL_PREFIX} \
    ; \
    make -j"$(nproc)"; \
    echo "wolfProvider built, checking build artifacts..."; \
    find . -name "*.so" -type f; \
    echo "Installing wolfProvider..."; \
    make install; \
    echo "Checking installation results..."; \
    find /usr/local -name "*wolfprov*" -type f 2>/dev/null || true; \
    find ${OPENSSL_PREFIX} -name "*wolfprov*" -type f 2>/dev/null || true; \
    # Manual installation if make install didn't work
    if [ ! -f "${OPENSSL_PREFIX}/lib64/ossl-modules/libwolfprov.so" ]; then \
        echo "Manual installation required..."; \
        mkdir -p ${OPENSSL_PREFIX}/lib64/ossl-modules; \
        if [ -f ".libs/libwolfprov.so" ]; then \
            cp -v .libs/libwolfprov.so* ${OPENSSL_PREFIX}/lib64/ossl-modules/ || true; \
        fi; \
        if [ -f "src/.libs/libwolfprov.so" ]; then \
            cp -v src/.libs/libwolfprov.so* ${OPENSSL_PREFIX}/lib64/ossl-modules/ || true; \
        fi; \
    fi; \
    cd ..; \
    rm -rf wolfProvider; \
    echo "wolfProvider installation completed"

# Verify wolfProvider installation
RUN set -eux; \
    echo "Checking for wolfProvider in possible locations..."; \
    if [ -d "${OPENSSL_PREFIX}/lib64/ossl-modules" ]; then \
        ls -la ${OPENSSL_PREFIX}/lib64/ossl-modules/; \
    fi; \
    if [ -d "${OPENSSL_PREFIX}/lib/ossl-modules" ]; then \
        ls -la ${OPENSSL_PREFIX}/lib/ossl-modules/; \
    fi; \
    # Check if libwolfprov.so exists in any of the expected locations
    if [ -f "${OPENSSL_PREFIX}/lib64/ossl-modules/libwolfprov.so" ] || \
       [ -f "${OPENSSL_PREFIX}/lib/ossl-modules/libwolfprov.so" ]; then \
        echo "wolfProvider module found and verified"; \
    else \
        echo "ERROR: wolfProvider module not found in expected locations"; \
        exit 1; \
    fi

################################################################################
# Download and Build Nginx 1.29.1 with OpenSSL 3.x (wolfProvider integration)
################################################################################
# Note: Nginx uses standard OpenSSL 3.x API, which is configured to use
# wolfProvider. This follows the same pattern as PostgreSQL, RabbitMQ, etc.
#
# Architecture:
#   Nginx SSL Module → OpenSSL 3.0.19 API → wolfProvider → wolfSSL FIPS v5.8.2
################################################################################

RUN set -eux; \
    cd /tmp; \
    # Download Nginx 1.29.1 source
    curl -fsSL -o nginx-${NGINX_VERSION}.tar.gz https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz; \
    tar -xzf nginx-${NGINX_VERSION}.tar.gz; \
    cd nginx-${NGINX_VERSION}; \
    # Configure Nginx with already-installed OpenSSL 3.x
    # Note: Do NOT use --with-openssl (expects source dir). Use cc-opt/ld-opt instead.
    ./configure \
        --prefix=${NGINX_PREFIX} \
        --sbin-path=/usr/sbin/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --pid-path=/var/run/nginx.pid \
        --lock-path=/var/run/nginx.lock \
        --http-client-body-temp-path=/var/cache/nginx/client_temp \
        --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
        --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
        --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
        --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
        --user=nginx \
        --group=nginx \
        --with-http_ssl_module \
        --with-http_v2_module \
        --with-http_realip_module \
        --with-http_stub_status_module \
        --with-http_gzip_static_module \
        --with-http_secure_link_module \
        --with-threads \
        --with-stream \
        --with-stream_ssl_module \
        --with-cc-opt="-I${OPENSSL_PREFIX}/include" \
        --with-ld-opt="-L${OPENSSL_PREFIX}/lib64 -Wl,-rpath,${OPENSSL_PREFIX}/lib64" \
    ; \
    make -j"$(nproc)"; \
    make install; \
    # Create necessary directories
    mkdir -p /var/cache/nginx /var/log/nginx; \
    cd ..; \
    rm -rf nginx-${NGINX_VERSION}*; \
    echo "Nginx ${NGINX_VERSION} with OpenSSL 3.x built and installed successfully"

# Verify Nginx installation
RUN set -eux; \
    nginx -v; \
    echo "Nginx installed at: $(which nginx)"

################################################################################
# Stage 2: Runtime - Minimal Debian Bookworm with Nginx and FIPS libraries
################################################################################
FROM debian:bookworm-slim AS runtime

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8

# Metadata labels
LABEL maintainer="FIPS Nginx Team" \
      org.opencontainers.image.title="nginx-fips" \
      org.opencontainers.image.description="Nginx 1.29.1 with wolfSSL FIPS 140-3 (Certificate #4718)" \
      org.opencontainers.image.version="1.29.1-fips" \
      org.opencontainers.image.vendor="Root Security"

# Installation paths
ENV OPENSSL_PREFIX=/usr/local/openssl
ENV WOLFSSL_PREFIX=/usr/local
ENV NGINX_PREFIX=/usr/local/nginx

# Copy FIPS components from builder
COPY --from=builder /usr/local/openssl /usr/local/openssl
COPY --from=builder /usr/local/lib/libwolfssl.so* /usr/local/lib/
COPY --from=builder /usr/local/include/wolfssl /usr/local/include/wolfssl
COPY --from=builder /usr/local/openssl/lib64/ossl-modules/libwolfprov.so* /tmp/wolfprov/

# Copy Nginx installation
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /usr/local/nginx /usr/local/nginx
COPY --from=builder /etc/nginx /etc/nginx

# Copy FIPS startup check utility
COPY --from=builder /usr/local/bin/fips-startup-check /usr/local/bin/fips-startup-check

# Install runtime stage dependencies via Root.io repository
COPY scripts/install-runtime-packages.sh /tmp/install-packages.sh
RUN --mount=type=secret,id=rootio_api_key \
    chmod +x /tmp/install-packages.sh && \
    /tmp/install-packages.sh && \
    rm /tmp/install-packages.sh

# Install wolfProvider to system OpenSSL modules directory
RUN set -eux; \
    mkdir -p /usr/lib/x86_64-linux-gnu/ossl-modules; \
    cp -av /tmp/wolfprov/* /usr/lib/x86_64-linux-gnu/ossl-modules/; \
    rm -rf /tmp/wolfprov; \
    # Configure dynamic linker
    echo "${WOLFSSL_PREFIX}/lib" > /etc/ld.so.conf.d/fips-wolfssl.conf; \
    echo "${OPENSSL_PREFIX}/lib64" >> /etc/ld.so.conf.d/fips-wolfssl.conf; \
    ldconfig; \
    echo "✓ wolfSSL and wolfProvider installed to system locations"

# Set OpenSSL environment variables
ENV OPENSSL_CONF="/etc/ssl/openssl.cnf" \
    OPENSSL_MODULES="/usr/lib/x86_64-linux-gnu/ossl-modules" \
    LD_LIBRARY_PATH="/usr/local/lib:/usr/local/openssl/lib64" \
    PATH="/usr/sbin:/usr/local/openssl/bin:${PATH}"

# Copy OpenSSL configuration with wolfProvider
COPY openssl.cnf /etc/ssl/openssl.cnf
COPY fips_properties.cnf /etc/ssl/fips_properties.cnf

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
    echo "✓ FIPS OpenSSL operational"; \
    echo "✓ wolfProvider loaded"; \
    echo "========================================"

# Create nginx user and group
RUN set -eux; \
    groupadd -g 101 nginx; \
    useradd -u 101 -g nginx -s /bin/false -d /var/cache/nginx nginx; \
    # Create necessary directories
    mkdir -p /var/cache/nginx /var/log/nginx /usr/share/nginx/html /etc/nginx/ssl; \
    chown -R nginx:nginx /var/cache/nginx /var/log/nginx /usr/share/nginx/html; \
    chmod 755 /var/cache/nginx /var/log/nginx

# Copy Nginx configuration template
COPY nginx.conf.template /etc/nginx/nginx.conf

# Create default index page
RUN echo '<!DOCTYPE html><html><head><title>Nginx FIPS</title></head><body><h1>Nginx 1.29.1 with wolfSSL FIPS 140-3</h1><p>Certificate #4718</p></body></html>' > /usr/share/nginx/html/index.html

# Generate self-signed certificate for testing
# Note: Use OPENSSL_CONF=/dev/null to bypass wolfProvider during cert generation.
# wolfProvider has incomplete decoder support for reading private keys during
# generation, but can read them fine at runtime. This generates a standard
# RSA certificate that works with both standard OpenSSL and wolfProvider.
RUN set -eux; \
    OPENSSL_CONF=/dev/null openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/self-signed.key \
        -out /etc/nginx/ssl/self-signed.crt \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"; \
    chown nginx:nginx /etc/nginx/ssl/self-signed.*; \
    chmod 600 /etc/nginx/ssl/self-signed.key; \
    echo "✓ Self-signed certificate generated"

# Copy docker entrypoint
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD nginx -t || exit 1

# Expose HTTP and HTTPS ports
EXPOSE 80 443

# Set working directory
WORKDIR /etc/nginx

# Use non-root user (but entrypoint needs root to bind to port 80/443)
# USER nginx

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Default command
CMD ["nginx", "-g", "daemon off;"]
