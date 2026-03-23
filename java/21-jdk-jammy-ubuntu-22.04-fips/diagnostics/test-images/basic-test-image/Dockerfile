# Simple FIPS Test Application Docker Image
# Extends the wolfssl-openjdk-fips-root base image to provide basic testing
# of JCA cryptographic operations and TLS functionality

ARG BASE_IMAGE=java:21-jdk-jammy-ubuntu-22.04-fips
FROM ${BASE_IMAGE}

LABEL maintainer="Root User"
LABEL description="FIPS-compliant Java test application demonstrating JCA and TLS usage"

# Compile the test application
WORKDIR /app/test

COPY src/main/*.java /app/test/

RUN javac -cp "/opt/wolfssl-fips/bin:/usr/share/java/*" \
    *.java

# Set the working directory back to /app
WORKDIR /app

# Default command runs the comprehensive FIPS test suite
# Users can override this to run individual test classes
CMD ["java", "-cp", "/app/test:/opt/wolfssl-fips/bin:/usr/share/java/*", "FipsUserApplication"]

# Alternative commands for running specific test suites:
# docker run java-21-jdk-jammy-ubuntu-22.04-fips-test-image:latest java -cp "/app/test:/opt/wolfssl-fips/bin:/usr/share/java/*" CryptoTestSuite
# docker run java-21-jdk-jammy-ubuntu-22.04-fips-test-image:latest java -cp "/app/test:/opt/wolfssl-fips/bin:/usr/share/java/*" TlsTestSuite
