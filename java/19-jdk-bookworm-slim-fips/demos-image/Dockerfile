# FIPS Demo Applications Docker Image
# Extends the base FIPS Java image to provide demonstration applications
# showing FIPS enforcement, keystore formats, and algorithm blocking
#
# Build from demos-image directory:
# Example: docker build -t fips-demos:latest .

ARG BASE_IMAGE=java:19-jdk-bookworm-slim-fips
FROM ${BASE_IMAGE}

LABEL maintainer="Root User"
LABEL description="FIPS 140-3 demonstration applications for wolfSSL Java"

# Switch to root to create directories
USER root

# Create application directory
RUN mkdir -p /app/demos

# Copy demo application source files
COPY src/*.java /app/demos/

# Compile the demo applications
WORKDIR /app/demos
RUN javac -cp "/opt/wolfssl-fips/bin:/usr/share/java/*" \
    *.java

# Set the working directory
WORKDIR /app

# Switch back to appuser
USER appuser

# Default command shows available demos
CMD echo "FIPS Demo Applications - Available Demos:" && \
    echo "" && \
    echo "1. WolfJceBlockingDemo - JCA algorithm blocking demonstration" && \
    echo "   docker run --rm <image> java -cp \"/app/demos:/opt/wolfssl-fips/bin:/usr/share/java/*\" WolfJceBlockingDemo" && \
    echo "" && \
    echo "2. WolfJsseBlockingDemo - JSSE TLS blocking demonstration" && \
    echo "   docker run --rm <image> java -cp \"/app/demos:/opt/wolfssl-fips/bin:/usr/share/java/*\" WolfJsseBlockingDemo" && \
    echo "" && \
    echo "3. MD5AvailabilityDemo - MD5 availability analysis" && \
    echo "   docker run --rm <image> java -cp \"/app/demos:/opt/wolfssl-fips/bin:/usr/share/java/*\" MD5AvailabilityDemo" && \
    echo "" && \
    echo "4. KeyStoreFormatDemo - JKS vs WKS keystore format comparison" && \
    echo "   docker run --rm <image> java -cp \"/app/demos:/opt/wolfssl-fips/bin:/usr/share/java/*\" KeyStoreFormatDemo" && \
    echo ""

# Alternative: Set a default demo to run
# CMD ["java", "-cp", "/app/demos:/opt/wolfssl-fips/bin:/usr/share/java/*", "WolfJceBlockingDemo"]
