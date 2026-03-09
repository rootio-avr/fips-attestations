# Ubuntu FIPS Java Image
#
# Purpose: Java-only FIPS-140-3 image with strict policy (MD5 and SHA-1 blocked)
#
# Components:
#   - Ubuntu 22.04 (System OpenSSL 3.0.2)
#   - wolfSSL FIPS v5.8.2 (Certificate #4718) with --disable-sha
#   - wolfProvider v1.1.0 (OpenSSL provider)
#   - OpenJDK 17 (Java runtime)
#
# FIPS Architecture:
#   Java App → Java Crypto API → System OpenSSL 3.0.2 → wolfProvider → wolfSSL FIPS v5
#
# Strict Policy:
#   - MD5: Blocked by wolfSSL/OpenSSL
#   - SHA-1: Blocked at wolfSSL library level (--disable-sha)
#   - SHA-256+: Allowed (FIPS approved)
#
# Build: docker build -t ubuntu-fips-java:v1.0.0-ubuntu-22.04 --secret id=wolfssl_password,src=.wolfssl_password .
# Run: docker run --rm ubuntu-fips-java:v1.0.0-ubuntu-22.04

################################################################################
# Stage 1: Build wolfSSL FIPS v5
################################################################################
FROM ubuntu:22.04 AS wolfssl-builder

ENV DEBIAN_FRONTEND=noninteractive

# wolfSSL Configuration
ENV WOLFSSL_URL=https://www.wolfssl.com/comm/wolfssl/wolfssl-5.8.2-commercial-fips-v5.2.3.7z
ENV WOLFSSL_PREFIX=/usr/local

# Install build dependencies + Ubuntu System OpenSSL
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
        libssl-dev \
        pkg-config \
    ; \
    rm -rf /var/lib/apt/lists/*

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
        libssl-dev \
    ; \
    rm -rf /var/lib/apt/lists/*

# Copy wolfSSL from wolfssl-builder stage
COPY --from=wolfssl-builder ${WOLFSSL_PREFIX}/include/wolfssl ${WOLFSSL_PREFIX}/include/wolfssl
COPY --from=wolfssl-builder ${WOLFSSL_PREFIX}/lib/libwolfssl.* ${WOLFSSL_PREFIX}/lib/

# Register wolfSSL libraries
RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/wolfssl.conf && ldconfig

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
# Stage 3: Build Java Application
################################################################################
FROM ubuntu:22.04 AS java-builder

ENV DEBIAN_FRONTEND=noninteractive

# Install OpenJDK 17 for compilation
RUN apt-get update && \
    apt-get install -y openjdk-17-jdk && \
    rm -rf /var/lib/apt/lists/*

# Copy Java source
COPY src/FipsDemoApp.java /app/java/
COPY src/FipsSecurityProvider.java /app/java/
COPY src/FipsMessageDigest.java /app/java/

# Compile Java application
RUN cd /app/java && \
    javac -encoding UTF-8 FipsMessageDigest.java FipsSecurityProvider.java FipsDemoApp.java

################################################################################
# Final Stage: Ubuntu FIPS Java Runtime
################################################################################
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install OpenJDK 17 JRE and minimal dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        openjdk-17-jre-headless \
        openssl \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Set Java environment
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# Copy wolfSSL runtime libraries (no headers needed)
COPY --from=wolfssl-builder /usr/local/lib/libwolfssl.* /usr/local/lib/

# Copy compiled Java application
COPY --from=java-builder /app/java/*.class /app/java/

# Register wolfSSL libraries
RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/wolfssl.conf && ldconfig

# Copy wolfProvider (uses wildcard for architecture flexibility)
COPY --from=wolfprov-builder /usr/lib/*/ossl-modules/libwolfprov.so* /tmp/wolfprov/

RUN set -eux; \
    ARCH=$(uname -m); \
    if [ "$ARCH" = "x86_64" ]; then MULTIARCH="x86_64-linux-gnu"; \
    elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then MULTIARCH="aarch64-linux-gnu"; \
    else MULTIARCH="x86_64-linux-gnu"; fi; \
    mkdir -p /usr/lib/${MULTIARCH}/ossl-modules; \
    cp -v /tmp/wolfprov/* /usr/lib/${MULTIARCH}/ossl-modules/; \
    rm -rf /tmp/wolfprov; \
    ls -la /usr/lib/${MULTIARCH}/ossl-modules/

# Configure OpenSSL to use wolfProvider
COPY openssl-wolfprov.cnf /tmp/openssl-wolfprov.cnf

RUN set -eux; \
    ARCH=$(uname -m); \
    if [ "$ARCH" = "x86_64" ]; then MULTIARCH="x86_64-linux-gnu"; \
    elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then MULTIARCH="aarch64-linux-gnu"; \
    else MULTIARCH="x86_64-linux-gnu"; fi; \
    cp /etc/ssl/openssl.cnf /etc/ssl/openssl.cnf.backup; \
    sed "s|/usr/lib/x86_64-linux-gnu/|/usr/lib/${MULTIARCH}/|g" /tmp/openssl-wolfprov.cnf > /etc/ssl/openssl.cnf; \
    rm /tmp/openssl-wolfprov.cnf; \
    echo "OpenSSL configured to use wolfProvider from openssl-wolfprov.cnf"

# Set OpenSSL configuration
ENV OPENSSL_CONF=/etc/ssl/openssl.cnf
ENV LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:/usr/lib/aarch64-linux-gnu:/usr/local/lib:/usr/lib

# Configure Java Security Policy for FIPS Mode
COPY java.security.fips /tmp/java.security.fips

RUN set -eux; \
    JAVA_SECURITY_FILE="${JAVA_HOME}/conf/security/java.security"; \
    if [ ! -f "${JAVA_SECURITY_FILE}" ]; then \
        echo "ERROR: Java security file not found at ${JAVA_SECURITY_FILE}"; \
        exit 1; \
    fi; \
    cp "${JAVA_SECURITY_FILE}" "${JAVA_SECURITY_FILE}.backup"; \
    \
    sed -i 's/^jdk.tls.disabledAlgorithms=.*/jdk.tls.disabledAlgorithms=SSLv3, RC4, DES, MD5withRSA, DH keySize < 2048, EC keySize < 224, 3DES_EDE_CBC, anon, NULL, TLS1.0, TLS1.1, MD5, SHA1/' "${JAVA_SECURITY_FILE}"; \
    sed -i 's/^jdk.certpath.disabledAlgorithms=.*/jdk.certpath.disabledAlgorithms=MD2, MD5, SHA1, RSA keySize < 2048, DSA keySize < 2048, EC keySize < 224/' "${JAVA_SECURITY_FILE}"; \
    sed -i 's/^jdk.jar.disabledAlgorithms=.*/jdk.jar.disabledAlgorithms=MD2, MD5, SHA1, RSA keySize < 1024, DSA keySize < 1024/' "${JAVA_SECURITY_FILE}"; \
    \
    echo "" >> "${JAVA_SECURITY_FILE}"; \
    echo "# FIPS Mode Configuration" >> "${JAVA_SECURITY_FILE}"; \
    echo "crypto.policy=unlimited" >> "${JAVA_SECURITY_FILE}"; \
    echo "fips.mode=strict" >> "${JAVA_SECURITY_FILE}"; \
    \
    rm /tmp/java.security.fips; \
    echo "Java security policy configured for FIPS mode"; \
    echo "Disabled algorithms: MD5, SHA1 (strict policy)"

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /app

# Harden: remove vulnerable packages not needed at runtime, then wipe package manager
RUN dpkg --force-all --purge \
        tar passwd login gpgv \
        libpam-modules libpam-modules-bin libpam-runtime libpam0g \
        libavahi-client3 libavahi-common3 libavahi-common-data \
        libdbus-1-3 dbus libexpat1 \
        libncurses6 libncursesw6 ncurses-base ncurses-bin \
        libgcrypt20 libzstd1 \
        libsystemd0 libudev1 \
    || true \
    && rm -rf /var/lib/dpkg /var/log/dpkg.log /var/lib/apt /usr/bin/dpkg /usr/bin/apt*

USER 1001

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD []
