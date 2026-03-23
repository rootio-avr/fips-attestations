# FIPS vs Non-FIPS Modes Guide

Complete guide to operating the wolfSSL FIPS Java container in FIPS mode (production) and non-FIPS mode (development/testing).

## Table of Contents

1. [Operating Modes Overview](#operating-modes-overview)
2. [FIPS Mode (Production)](#fips-mode-production)
3. [Non-FIPS Mode (Development/Testing)](#non-fips-mode-developmenttesting)
4. [Mode Comparison](#mode-comparison)
5. [Switching Between Modes](#switching-between-modes)
6. [Use Case Examples](#use-case-examples)
7. [Security Implications](#security-implications)
8. [Best Practices](#best-practices)

---

## Operating Modes Overview

The container supports two operating modes controlled by the `FIPS_CHECK` environment variable:

| Mode | FIPS_CHECK | Validation | Use Case |
|------|------------|------------|----------|
| **FIPS Mode** | `true` (default) | Full validation | Production, compliance environments |
| **Non-FIPS Mode** | `false` | Skipped | Development, testing, debugging |

**Key Point**: Both modes use the same providers (wolfJCE/wolfJSSE) and FIPS-validated crypto. The difference is whether validation checks run at startup.

---

## FIPS Mode (Production)

### What is FIPS Mode?

FIPS mode performs comprehensive validation at container startup to ensure the environment is configured correctly for FIPS compliance.

### Validation Steps Performed

1. **Library Integrity Verification**
   - Verifies SHA-256 checksums of all FIPS libraries
   - Ensures no tampering or corruption
   - Location: `/opt/wolfssl-fips/checksums/libraries.sha256`

2. **Provider Registration Verification**
   - Confirms wolfJCE is registered at priority 1
   - Confirms wolfJSSE is registered at priority 2
   - Checks for unexpected providers

3. **WKS Cacerts Format Verification**
   - Verifies system CA certificates are in WKS format
   - Loads and counts certificates
   - Ensures FIPS-compliant keystore is used

4. **FIPS POST (Power-On Self Test)**
   - Executes wolfCrypt FIPS POST
   - Tests cryptographic functionality
   - Verifies FIPS boundary integrity

5. **Algorithm Availability Checks**
   - Tests FIPS-approved algorithms (SHA-256, AES-GCM, etc.)
   - Verifies non-FIPS algorithms are unavailable (MD5, etc.)
   - Confirms correct provider routing

6. **Provider Configuration Sanity Checks**
   - Parses java.security configuration
   - Identifies unexpected or non-compliant providers
   - Validates provider priority order

### When Container Starts

```
===============================================================================
|                       Library Checksum Verification                        |
===============================================================================

Verifying library integrity...
✓ /usr/local/lib/libwolfssl.so.44
✓ /usr/lib/jni/libwolfcryptjni.so
✓ /usr/lib/jni/libwolfssljni.so
✓ /usr/share/java/wolfcrypt-jni.jar
✓ /usr/share/java/wolfssl-jsse.jar
✓ /usr/share/java/filtered-providers.jar

All library checksums verified successfully.

===============================================================================
|                        FIPS Container Verification                         |
===============================================================================

Security Manager: None
Currently loaded security providers:
	1. wolfJCE v1.0 - wolfSSL JCE Provider
	2. wolfJSSE v13.0 - wolfSSL JSSE Provider
	...

Verifying wolfSSL providers are registered...
	wolfJCE provider verified at position 1
	wolfJSSE provider verified at position 2

Verifying system CA certs are in WKS format...
	Successfully loaded 130 CA certificates from WKS format cacerts

Forcing FIPS POST via MessageDigest invocation
	FIPS POST test completed successfully

Running sanity checks on java.security
	Active security providers (from java.security file):
	 1. com.wolfssl.provider.jce.WolfCryptProvider   [Expected / FIPS]
	 2. com.wolfssl.provider.jsse.WolfSSLProvider   [Expected / FIPS]
	...

Testing wolfSSL algorithm class instantiation...
	MessageDigest: SHA-256 -> wolfJCE
	...
	Tests passed: 72/72

All FIPS validation checks completed successfully.

===============================================================================
|                         All Container Tests Passed                         |
===============================================================================
```

### Enabling FIPS Mode

```bash
# Default behavior (FIPS mode enabled)
docker run --rm java:11-jdk-jammy-ubuntu-22.04-fips

# Explicit FIPS mode
docker run --rm -e FIPS_CHECK=true java:11-jdk-jammy-ubuntu-22.04-fips

# FIPS mode with debug logging
docker run --rm \
  -e FIPS_CHECK=true \
  -e WOLFJCE_DEBUG=true \
  -e WOLFJSSE_DEBUG=true \
  java:11-jdk-jammy-ubuntu-22.04-fips
```

### Running Applications in FIPS Mode

```bash
# Run user application with FIPS validation
docker run --rm \
  -v /path/to/app:/app/user \
  -e FIPS_CHECK=true \
  java:11-jdk-jammy-ubuntu-22.04-fips \
  java -cp "/app/user:/usr/share/java/*" com.example.MyApp

# Production deployment
docker run -d \
  --name my-fips-app \
  -p 8080:8080 \
  -e FIPS_CHECK=true \
  -v /path/to/config:/app/config:ro \
  -v /path/to/truststore.wks:/app/truststore.wks:ro \
  java:11-jdk-jammy-ubuntu-22.04-fips \
  java -jar /app/myapp.jar

# Kubernetes deployment
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fips-app
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: app
        image: java:11-jdk-jammy-ubuntu-22.04-fips
        env:
        - name: FIPS_CHECK
          value: "true"
        - name: JAVA_OPTS
          value: "-Xmx1g"
        volumeMounts:
        - name: truststore
          mountPath: /app/truststore.wks
          readOnly: true
      volumes:
      - name: truststore
        secret:
          secretName: app-truststore
EOF
```

### What Happens if Validation Fails?

If any validation step fails, the container exits with an error:

```
ERROR: FIPS library integrity verification failed!
[Details of which check failed]
Container will terminate.
```

**Example Failures**:
- Library checksum mismatch → Container exits
- wolfJCE not at priority 1 → Container exits
- Cacerts not WKS format → Container exits
- FIPS POST fails → Container exits

---

## Non-FIPS Mode (Development/Testing)

### What is Non-FIPS Mode?

Non-FIPS mode skips all validation checks, allowing faster startup and more flexible configuration for development and testing.

### What is Skipped?

1. **Library Integrity Checks** - No checksum verification
2. **Provider Verification** - No priority checks
3. **WKS Format Verification** - No keystore format checks
4. **FIPS POST** - No POST execution
5. **Algorithm Checks** - No algorithm availability tests
6. **Configuration Sanity Checks** - No java.security validation

### What Still Works?

- **Same Providers**: wolfJCE and wolfJSSE are still loaded
- **Same Crypto**: FIPS-validated algorithms still used
- **Same Configuration**: java.security configuration unchanged
- **WKS Support**: WKS keystores still supported

**Important**: Non-FIPS mode doesn't change the crypto implementation, it just skips validation.

### When Container Starts

```
===============================================================================
|                        FIPS Verification Disabled                          |
===============================================================================

WARNING: FIPS_CHECK=false - Skipping FIPS verification tests
This mode is intended for development/testing only and should not be used in production

Executing command: java -version
openjdk version "11" 2022-09-20
OpenJDK Runtime Environment (build 11+36-2238)
OpenJDK 64-Bit Server VM (build 11+36-2238, mixed mode, sharing)
```

### Enabling Non-FIPS Mode

```bash
# Skip FIPS validation
docker run --rm -e FIPS_CHECK=false java:11-jdk-jammy-ubuntu-22.04-fips

# Quick container for testing
docker run --rm -e FIPS_CHECK=false java:11-jdk-jammy-ubuntu-22.04-fips java -version

# Interactive development shell
docker run --rm -it \
  -e FIPS_CHECK=false \
  -v $(pwd):/workspace \
  -w /workspace \
  java:11-jdk-jammy-ubuntu-22.04-fips \
  bash
```

### Use Cases for Non-FIPS Mode

1. **Local Development**:
   ```bash
   docker run --rm \
     -e FIPS_CHECK=false \
     -v $(pwd)/src:/app/src \
     -v $(pwd)/target:/app/target \
     -w /app \
     java:11-jdk-jammy-ubuntu-22.04-fips \
     javac -cp "/usr/share/java/*" src/*.java -d target
   ```

2. **Unit Testing**:
   ```bash
   docker run --rm \
     -e FIPS_CHECK=false \
     -v $(pwd):/tests \
     -w /tests \
     java:11-jdk-jammy-ubuntu-22.04-fips \
     java -cp "/tests:/usr/share/java/*" org.junit.runner.JUnitCore MyTests
   ```

3. **Debugging**:
   ```bash
   docker run --rm -it \
     -e FIPS_CHECK=false \
     -e WOLFJCE_DEBUG=true \
     -e WOLFJSSE_DEBUG=true \
     -v $(pwd):/app \
     java:11-jdk-jammy-ubuntu-22.04-fips \
     bash
   ```

4. **CI/CD Build Steps** (not runtime):
   ```yaml
   # GitLab CI example
   build:
     image: java:11-jdk-jammy-ubuntu-22.04-fips
     variables:
       FIPS_CHECK: "false"
     script:
       - mvn clean package
       - mvn test
   ```

5. **Custom Provider Configuration**:
   ```bash
   docker run --rm \
     -e FIPS_CHECK=false \
     -v $(pwd)/custom-java.security:$JAVA_HOME/conf/security/java.security \
     java:11-jdk-jammy-ubuntu-22.04-fips
   ```

---

## Mode Comparison

### Detailed Comparison Table

| Feature | FIPS Mode | Non-FIPS Mode |
|---------|-----------|---------------|
| **Validation** | Full (6 checks) | None |
| **Startup Time** | ~5-10 seconds | ~1 second |
| **Library Checksums** | Verified | Not checked |
| **Provider Priority** | Verified | Not checked |
| **FIPS POST** | Executed | Skipped |
| **Algorithm Tests** | Performed | Skipped |
| **Crypto Implementation** | wolfSSL FIPS | wolfSSL FIPS (same) |
| **Providers Used** | wolfJCE/wolfJSSE | wolfJCE/wolfJSSE (same) |
| **WKS Support** | Required | Supported but not required |
| **Container Exit on Failure** | Yes | No |
| **Recommended For** | Production | Development/Testing |
| **Compliance** | FIPS 140-3 compliant | Same crypto, no validation |

### Performance Comparison

```bash
# Benchmark startup time
# FIPS Mode
time docker run --rm -e FIPS_CHECK=true \
  java:11-jdk-jammy-ubuntu-22.04-fips echo "Done"
# ~8 seconds

# Non-FIPS Mode
time docker run --rm -e FIPS_CHECK=false \
  java:11-jdk-jammy-ubuntu-22.04-fips echo "Done"
# ~1 second
```

### Security Comparison

| Security Aspect | FIPS Mode | Non-FIPS Mode |
|-----------------|-----------|---------------|
| **Cryptography** | ✅ FIPS-validated | ✅ FIPS-validated (same) |
| **Library Integrity** | ✅ Verified | ⚠️ Not verified |
| **Configuration** | ✅ Validated | ⚠️ Not validated |
| **Compliance Proof** | ✅ Evidence collected | ❌ No evidence |
| **Production Ready** | ✅ Yes | ❌ No (dev only) |

---

## Switching Between Modes

### Environment Variable Control

The `FIPS_CHECK` environment variable controls the mode:

```bash
# FIPS Mode (production)
export FIPS_CHECK=true
docker run --rm -e FIPS_CHECK=$FIPS_CHECK ...

# Non-FIPS Mode (development)
export FIPS_CHECK=false
docker run --rm -e FIPS_CHECK=$FIPS_CHECK ...
```

### Docker Compose Example

```yaml
# Docker Compose v2+ (no top-level `version` key required)
services:
  app-production:
    image: java:11-jdk-jammy-ubuntu-22.04-fips
    environment:
      FIPS_CHECK: "true"
      WOLFJCE_DEBUG: "false"
      JAVA_OPTS: "-Xmx2g"
    volumes:
      - ./app.jar:/app/app.jar:ro
      - ./truststore.wks:/app/truststore.wks:ro
    command: ["java", "-jar", "/app/app.jar"]
    restart: always

  app-development:
    image: java:11-jdk-jammy-ubuntu-22.04-fips
    environment:
      FIPS_CHECK: "false"
      WOLFJCE_DEBUG: "true"
      WOLFJSSE_DEBUG: "true"
    volumes:
      - ./src:/app/src
      - ./target:/app/target
    command: ["bash"]
    stdin_open: true
    tty: true
```

### Kubernetes ConfigMap Example

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  # Production configuration
  FIPS_MODE_ENABLED: "true"

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fips-app
spec:
  template:
    spec:
      containers:
      - name: app
        image: java:11-jdk-jammy-ubuntu-22.04-fips
        envFrom:
        - configMapRef:
            name: app-config
        env:
        - name: FIPS_CHECK
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: FIPS_MODE_ENABLED
```

---

## Use Case Examples

### Use Case 1: Production Deployment

**Requirement**: FIPS-compliant production environment

**Configuration**:
```bash
docker run -d \
  --name production-app \
  --restart always \
  -p 443:8443 \
  -e FIPS_CHECK=true \
  -e JAVA_OPTS="-Xmx4g -XX:+UseG1GC" \
  -v /secure/truststore.wks:/app/truststore.wks:ro \
  -v /secure/keystore.wks:/app/keystore.wks:ro \
  -v /logs:/app/logs \
  java:11-jdk-jammy-ubuntu-22.04-fips \
  java -jar /app/production-app.jar
```

**Monitoring**:
```bash
# Check container started successfully
docker logs production-app | grep "All Container Tests Passed"

# Verify FIPS POST ran
docker logs production-app | grep "FIPS POST test completed"
```

### Use Case 2: Development Environment

**Requirement**: Fast iterations, debugging

**Configuration**:
```bash
docker run --rm -it \
  -e FIPS_CHECK=false \
  -e WOLFJCE_DEBUG=true \
  -v $(pwd):/workspace \
  -w /workspace \
  -p 8080:8080 \
  java:11-jdk-jammy-ubuntu-22.04-fips \
  bash

# Inside container
javac -cp "/usr/share/java/*" src/*.java -d target
java -cp "/workspace/target:/usr/share/java/*" com.example.Main
```

### Use Case 3: CI/CD Pipeline

**Requirement**: Build and test code

**.gitlab-ci.yml**:
```yaml
stages:
  - build
  - test
  - deploy

build:
  stage: build
  image: java:11-jdk-jammy-ubuntu-22.04-fips
  variables:
    FIPS_CHECK: "false"  # Skip validation for build speed
  script:
    - mvn clean package -DskipTests
  artifacts:
    paths:
      - target/*.jar

test:
  stage: test
  image: java:11-jdk-jammy-ubuntu-22.04-fips
  variables:
    FIPS_CHECK: "true"  # Validate FIPS mode for tests
  script:
    - mvn test
  dependencies:
    - build

deploy-prod:
  stage: deploy
  script:
    - docker build -t myapp:prod .
    - docker tag myapp:prod registry/myapp:${CI_COMMIT_TAG}
    - docker push registry/myapp:${CI_COMMIT_TAG}
  only:
    - tags
```

### Use Case 4: Integration Testing

**Requirement**: Test with FIPS validation

**docker-compose.test.yml**:
```yaml
# Docker Compose v2+ (no top-level `version` key required)
services:
  app:
    image: java:11-jdk-jammy-ubuntu-22.04-fips
    environment:
      FIPS_CHECK: "true"
    volumes:
      - ./target/app.jar:/app/app.jar:ro
    command: ["java", "-jar", "/app/app.jar"]
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 10s
      timeout: 3s
      retries: 3

  test:
    image: curlimages/curl
    depends_on:
      app:
        condition: service_healthy
    command: >
      sh -c "
        curl -f http://app:8080/api/test &&
        curl -f http://app:8080/health &&
        echo 'Integration tests passed'
      "
```

---

## Security Implications

### FIPS Mode Security Benefits

1. **Integrity Assurance**
   - Libraries haven't been tampered with
   - Checksums match expected values

2. **Configuration Validation**
   - Providers are correctly ordered
   - No unexpected providers loaded

3. **Compliance Evidence**
   - Validation output proves FIPS compliance
   - Auditable startup logs

4. **Early Failure Detection**
   - Misconfiguration detected before runtime
   - Prevents production issues

### Non-FIPS Mode Security Risks

1. **No Integrity Verification**
   - Can't detect tampered libraries
   - No checksum validation

2. **Configuration Errors Undetected**
   - Wrong provider order not caught
   - Unexpected providers not flagged

3. **No Compliance Proof**
   - Startup logs don't show validation
   - Can't prove FIPS compliance

4. **Runtime Failures Possible**
   - Misconfigurations only discovered at runtime
   - Harder to diagnose

### Risk Mitigation for Non-FIPS Mode

If you must use non-FIPS mode in production (not recommended):

1. **Manual Validation**:
   ```bash
   # Run validation script
   docker run --rm \
     -e FIPS_CHECK=true \
     java:11-jdk-jammy-ubuntu-22.04-fips \
     java -cp "/opt/wolfssl-fips/bin:/usr/share/java/*" FipsInitCheck
   ```

2. **Separate Validation Stage**:
   ```bash
   # Validate in separate container first
   docker run --rm -e FIPS_CHECK=true myapp:latest true

   # Then run without validation
   docker run -d -e FIPS_CHECK=false myapp:latest
   ```

3. **Monitoring**:
   ```bash
   # Monitor for non-FIPS algorithm usage
   docker logs app | grep -i "NoSuchAlgorithmException"
   ```

---

## Best Practices

### Production Environments

1. **Always Use FIPS Mode**:
   ```bash
   FIPS_CHECK=true  # or omit (true is default)
   ```

2. **Capture Validation Output**:
   ```bash
   docker run ... > fips-validation.log 2>&1
   ```

3. **Monitor Container Health**:
   ```yaml
   healthcheck:
     test: ["CMD", "java", "-version"]
     interval: 30s
     timeout: 3s
     start_period: 15s  # Allow time for FIPS validation
   ```

4. **Use Separate Keystore Files**:
   ```bash
   -v /secure/prod-truststore.wks:/app/truststore.wks:ro
   ```

### Development Environments

1. **Use Non-FIPS Mode for Speed**:
   ```bash
   FIPS_CHECK=false
   ```

2. **Periodic FIPS Mode Testing**:
   ```bash
   # Weekly: Test in FIPS mode
   docker run -e FIPS_CHECK=true ...
   ```

3. **Enable Debug Logging**:
   ```bash
   WOLFJCE_DEBUG=true
   WOLFJSSE_DEBUG=true
   ```

### CI/CD Pipelines

1. **Build Stage**: Non-FIPS mode (speed)
2. **Test Stage**: FIPS mode (validation)
3. **Deploy Stage**: FIPS mode (compliance)

### Documentation

1. **Document Mode Used**:
   ```markdown
   ## Deployment

   - Production: FIPS_CHECK=true
   - Staging: FIPS_CHECK=true
   - Development: FIPS_CHECK=false
   ```

2. **Include Validation Logs**:
   - Attach FIPS validation output to deployment docs
   - Store in compliance repository

---

## Summary

| Decision | Recommendation |
|----------|----------------|
| **Production** | ✅ Use FIPS mode (FIPS_CHECK=true) |
| **Staging** | ✅ Use FIPS mode |
| **Development** | ✅ Use non-FIPS mode for speed |
| **CI Build** | ⚠️ Non-FIPS OK for build speed |
| **CI Test** | ✅ Use FIPS mode |
| **CI Deploy** | ✅ Use FIPS mode |
| **Compliance** | ✅ Always FIPS mode |

---

## Additional Resources

- **[README.md](README.md)** - General container documentation
- **[DEVELOPER-GUIDE.md](DEVELOPER-GUIDE.md)** - Developer integration guide
- **[ATTESTATION.md](ATTESTATION.md)** - Compliance documentation

---

**Last Updated**: 2026-03-19
**Version**: 1.0
**wolfSSL FIPS Version**: v5.8.2 (Certificate #4718)
