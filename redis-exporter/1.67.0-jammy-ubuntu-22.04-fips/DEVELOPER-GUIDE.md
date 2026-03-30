# Redis Exporter v1.67.0 FIPS - Developer Guide

## Table of Contents

- [Getting Started](#getting-started)
- [Build Process](#build-process)
- [Testing](#testing)
- [Development Workflow](#development-workflow)
- [Updating Components](#updating-components)
- [Troubleshooting Build Issues](#troubleshooting-build-issues)
- [CI/CD Integration](#cicd-integration)
- [Contributing](#contributing)

## Getting Started

### Prerequisites

**Required:**
- Docker 20.10+ with BuildKit support
- wolfSSL commercial FIPS package access (password required)
- 10 GB free disk space
- 4 GB RAM minimum
- Internet connection (for downloading components)

**Optional:**
- `make` for automation
- `docker-compose` for testing
- `kubectl` for Kubernetes testing
- Redis server for integration testing

### Initial Setup

1. **Clone the repository:**

```bash
cd /path/to/fips-attestations
cd redis-exporter/1.67.0-jammy-ubuntu-22.04-fips
```

2. **Set up wolfSSL credentials:**

```bash
# Create password file
echo 'your-wolfssl-commercial-password' > wolfssl_password.txt
chmod 600 wolfssl_password.txt

# Verify password file exists
ls -la wolfssl_password.txt
```

**⚠️ CRITICAL:** Never commit `wolfssl_password.txt` to version control! It's already in `.gitignore`.

3. **Verify prerequisites:**

```bash
# Check Docker version (need 20.10+)
docker --version

# Check BuildKit support
docker buildx version

# Check disk space (need ~10 GB)
df -h .

# Test Docker works
docker run --rm hello-world
```

## Build Process

### Quick Build

```bash
# Run automated build script (recommended)
./build.sh

# Expected duration: 30-45 minutes (first build)
# Expected duration: 10-15 minutes (with cache)
```

**Build Output:**
```
========================================
Building Redis Exporter FIPS Image
========================================

[1/6] Validating prerequisites...
[OK] Docker is running
[OK] BuildKit is available
[OK] wolfssl_password.txt exists
[OK] Disk space: 15GB available

[2/6] Building Docker image...
Image: cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips
[Stage 1/4] Building wolfSSL FIPS v5.8.2... (15-20 min)
[Stage 2/4] Building wolfProvider v1.1.0... (5-10 min)
[Stage 3/4] Building golang-fips/go + redis_exporter... (10-15 min)
[Stage 4/4] Creating runtime image... (2-3 min)
[OK] Build completed successfully

[3/6] Checking image size...
[OK] Image size: 180 MB

[4/6] Verifying image...
[OK] Image exists in local registry

[5/6] Running quick runtime test...
[OK] FIPS validation passed
[OK] redis_exporter version check passed

========================================
✓ BUILD SUCCESSFUL
========================================

Image:       cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips
Size:        180 MB
Build Time:  1847s
```

### Manual Build

```bash
# Using BuildKit (required for secret mounting)
DOCKER_BUILDKIT=1 docker build \
    --secret id=wolfssl_password,src=wolfssl_password.txt \
    -t cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips \
    -f Dockerfile .

# Build with custom image name
DOCKER_BUILDKIT=1 docker build \
    --secret id=wolfssl_password,src=wolfssl_password.txt \
    -t my-registry/redis-exporter:1.67.0-fips \
    .

# Build without cache (clean build)
DOCKER_BUILDKIT=1 docker build \
    --secret id=wolfssl_password,src=wolfssl_password.txt \
    --no-cache \
    -t cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips \
    .

# Build with verbose output
DOCKER_BUILDKIT=1 docker build \
    --secret id=wolfssl_password,src=wolfssl_password.txt \
    --progress=plain \
    -t cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips \
    .
```

### Build Options

**build.sh supports:**
```bash
./build.sh                          # Standard build
./build.sh --no-cache               # Clean build (no cache)
./build.sh --verbose                # Verbose output
./build.sh --push                   # Build and push to registry
./build.sh --image-name NAME        # Custom image name
./build.sh --help                   # Show help
```

### Build Stages Explained

**Stage 1: wolfssl-builder** (~15-20 minutes)
- Downloads wolfSSL FIPS v5.8.2 commercial package
- Builds OpenSSL 3.0.19 from source
- Builds wolfSSL FIPS with `--enable-fips=v5 --disable-sha`
- Runs `fips-hash.sh` to generate FIPS integrity hash
- Output: `libwolfssl.so`, `libssl.so.3`, `libcrypto.so.3`

**Stage 2: wolfprov-builder** (~5-10 minutes)
- Clones wolfProvider v1.1.0 from GitHub
- Builds wolfProvider linking to wolfSSL from Stage 1
- Output: `libwolfprov.so` (OpenSSL provider module)

**Stage 3: go-builder** (~10-15 minutes)
- Downloads Go 1.22.6 bootstrap compiler
- Clones golang-fips/go v1.25-fips-release
- Removes ChaCha20-Poly1305 from TLS 1.3 (non-FIPS)
- Builds golang-fips/go from source
- Clones redis_exporter v1.67.0
- Builds redis_exporter with `GOEXPERIMENT=strictfipsruntime`
- Compiles `test-fips.c` → `fips-check` binary
- Output: `redis_exporter`, `fips-check`, `go-fips` toolchain

**Stage 4: runtime** (~2-3 minutes)
- Copies binaries and libraries from previous stages
- Configures OpenSSL to load wolfProvider
- Sets up non-root user (`redis-exporter`, UID 1001)
- Installs entrypoint script
- Final size: ~180 MB

### Build Performance Tips

**Speed up builds:**
```bash
# 1. Use BuildKit cache
export DOCKER_BUILDKIT=1

# 2. Don't use --no-cache unless necessary
./build.sh  # Uses cache

# 3. Use multi-stage caching
# BuildKit automatically caches each stage

# 4. Use CI/CD cache
# Mount /var/lib/docker between CI builds
```

**Expected build times:**
- First build: 30-45 minutes
- Rebuild (no changes): <1 minute (cached)
- Rebuild (Dockerfile change): 2-5 minutes
- Rebuild (wolfSSL upgrade): 20-30 minutes

## Testing

### Quick Validation

```bash
# 1. Build the image
./build.sh

# 2. Run quick tests
./diagnostic.sh

# Expected output:
# [TEST 1] FIPS Status Validation... ✓ PASSED
# [TEST 2] Redis Connectivity Test... ✓ PASSED (with TODO notes)
# [TEST 3] Metrics Endpoint Test... ✓ PASSED (with TODO notes)
# [TEST 4] Go FIPS Algorithms Test... ✓ PASSED
# [TEST 5] Contrast Test... ✓ PASSED (with TODO notes)
#
# ✓ ALL TESTS PASSED
```

### Manual Testing

**Test 1: FIPS Validation**
```bash
# Run FIPS validation only
docker run --rm \
  --entrypoint=/usr/local/bin/fips-check \
  cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips

# Expected:
# ===============================================
# wolfSSL FIPS 140-3 Validation
# ===============================================
# [CHECK 1/2] Running FIPS POST...
# [OK] FIPS POST passed successfully
# [CHECK 2/2] Verifying FIPS build...
# [OK] FIPS build detected
# ✓ ALL FIPS CHECKS PASSED
```

**Test 2: Start with FIPS Checks**
```bash
# Start container with full FIPS validation
docker run -d -p 9121:9121 \
  -e REDIS_ADDR=redis://redis-server:6379 \
  --name redis-exporter-test \
  cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips

# Check logs
docker logs redis-exporter-test

# Should see:
# ======================================
# Redis Exporter v1.67.0 with FIPS 140-3
# ======================================
# ... FIPS validation steps ...
# ✓ ALL FIPS CHECKS PASSED
# Starting redis_exporter...
```

**Test 3: Metrics Endpoint**
```bash
# Test metrics endpoint
curl -s http://localhost:9121/metrics | head -20

# Should see Prometheus metrics:
# # HELP redis_up Information about the Redis instance
# # TYPE redis_up gauge
# redis_up 1
# ...
```

**Test 4: Test with Redis**
```bash
# Start test Redis server
docker run -d --name test-redis redis:7.2.4

# Start exporter pointing to test Redis
docker run -d -p 9121:9121 \
  -e REDIS_ADDR=redis://test-redis:6379 \
  --link test-redis \
  --name redis-exporter-test \
  cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips

# Verify connection
curl -s http://localhost:9121/metrics | grep redis_up
# Should show: redis_up 1

# Cleanup
docker stop test-redis redis-exporter-test
docker rm test-redis redis-exporter-test
```

### Integration Testing

```bash
# Use docker-compose for full stack testing
cd examples/docker-compose/
docker-compose up -d

# Check services
docker-compose ps

# Scrape metrics
curl -s http://localhost:9121/metrics

# Check Prometheus targets
curl -s http://localhost:9090/api/v1/targets

# Cleanup
docker-compose down
```

### Diagnostic Scripts

```bash
# Run all diagnostics
./diagnostic.sh

# Run specific diagnostic
./diagnostics/test-exporter-fips-status.sh
./diagnostics/test-go-fips-algorithms.sh

# Run with Redis server
# (TODO: Implement in test-exporter-connectivity.sh)
```

## Development Workflow

### Local Development Setup

```bash
# 1. Build development image
./build.sh

# 2. Run with local Redis
docker run -d --name dev-redis redis:7.2.4

docker run -d -p 9121:9121 \
  -e REDIS_ADDR=redis://dev-redis:6379 \
  -e REDIS_EXPORTER_DEBUG=true \
  --link dev-redis \
  --name dev-exporter \
  cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips

# 3. Watch logs
docker logs -f dev-exporter

# 4. Test changes
curl http://localhost:9121/metrics

# 5. Cleanup
docker stop dev-redis dev-exporter
docker rm dev-redis dev-exporter
```

### Modifying the Build

**Change Dockerfile:**
```bash
# 1. Edit Dockerfile
vim Dockerfile

# 2. Rebuild (only changed stages rebuild)
./build.sh

# 3. Test
docker run --rm --entrypoint=/usr/local/bin/fips-check \
  cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips
```

**Change Entrypoint Script:**
```bash
# 1. Edit docker-entrypoint.sh
vim docker-entrypoint.sh

# 2. Rebuild (fast, only stage 4 rebuilds)
./build.sh

# 3. Test
docker run -d -p 9121:9121 \
  -e REDIS_ADDR=redis://localhost:6379 \
  cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips
```

### Testing FIPS Changes

```bash
# Test algorithm blocking
docker run --rm --entrypoint=bash \
  cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips \
  -c 'echo "test" | openssl dgst -md5'
# Should fail: error or "disabled" message

docker run --rm --entrypoint=bash \
  cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips \
  -c 'echo "test" | openssl dgst -sha256'
# Should work: SHA256(stdin)= ...

# Test Go FIPS mode
docker run --rm --entrypoint=bash \
  cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips \
  -c 'echo $GOLANG_FIPS $GODEBUG'
# Should show: 1 fips140=only
```

## Updating Components

### Update redis_exporter Version

```bash
# 1. Edit Dockerfile
# Change: ENV REDIS_EXPORTER_VERSION=v1.67.0
# To:     ENV REDIS_EXPORTER_VERSION=v1.68.0

# 2. Rebuild
./build.sh --no-cache  # Clean build recommended for version changes

# 3. Test
docker run --rm --entrypoint=redis_exporter \
  cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips \
  --version
```

### Update golang-fips/go Version

```bash
# 1. Edit Dockerfile
# Change: ENV GOLANG_FIPS_VERSION=go1.25-fips-release
# To:     ENV GOLANG_FIPS_VERSION=go1.26-fips-release

# 2. Rebuild stage 3 onwards
./build.sh --no-cache

# 3. Verify
docker run --rm --entrypoint=go \
  cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips \
  version
```

### Update wolfSSL FIPS Version

```bash
# 1. Edit Dockerfile
# Change: ENV WOLFSSL_URL=https://www.wolfssl.com/comm/wolfssl/wolfssl-5.8.2-commercial-fips-v5.2.3.7z
# To new version URL

# 2. Full rebuild required
./build.sh --no-cache

# 3. Verify FIPS POST still passes
docker run --rm --entrypoint=/usr/local/bin/fips-check \
  cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips
```

⚠️ **WARNING:** Updating wolfSSL FIPS may invalidate FIPS certification. Consult wolfSSL documentation.

### Update OpenSSL Version

```bash
# 1. Edit Dockerfile (Stage 1)
# Change: ENV OPENSSL_VERSION=3.0.19
# To:     ENV OPENSSL_VERSION=3.0.20

# 2. Rebuild from stage 1
./build.sh --no-cache

# 3. Verify
docker run --rm --entrypoint=openssl \
  cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips \
  version
```

## Troubleshooting Build Issues

### Build Fails: wolfSSL Download

**Error:**
```
curl: (22) The requested URL returned error: 403 Forbidden
```

**Solution:**
```bash
# Verify wolfssl_password.txt exists and is correct
cat wolfssl_password.txt

# Ensure no trailing spaces/newlines
echo -n 'your_password_here' > wolfssl_password.txt

# Test manually
curl -L -o /tmp/test.7z \
  "https://www.wolfssl.com/comm/wolfssl/wolfssl-5.8.2-commercial-fips-v5.2.3.7z"
```

### Build Fails: Out of Disk Space

**Error:**
```
Error: No space left on device
```

**Solution:**
```bash
# Clean Docker cache
docker system prune -a -f

# Remove old images
docker images | grep 'months ago' | awk '{print $3}' | xargs docker rmi

# Check space
df -h /var/lib/docker
```

### Build Fails: golang-fips/go Compilation

**Error:**
```
fatal error: openssl/evp.h: No such file or directory
```

**Solution:**
```bash
# Verify OpenSSL headers copied from stage 1
# Check Dockerfile stage 3:
# COPY --from=wolfssl-builder /usr/include/openssl /usr/include/openssl

# Rebuild from scratch
./build.sh --no-cache
```

### Build Fails: FIPS POST

**Error:**
```
ERROR: FIPS POST failed!
```

**Solution:**
```bash
# Check wolfSSL build configuration
# Ensure --enable-fips=v5 is set
grep "enable-fips" Dockerfile

# Verify fips-hash.sh was run
# Look for "./fips-hash.sh" in Dockerfile stage 1

# Check build logs
docker build --progress=plain ... 2>&1 | grep -i "fips"
```

### Runtime Fails: wolfProvider Not Loaded

**Error:**
```
[FAIL] wolfProvider not loaded
```

**Solution:**
```bash
# Check openssl.cnf configuration
docker run --rm --entrypoint=cat \
  cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips \
  /etc/ssl/openssl.cnf

# Should contain:
# [provider_sect]
# fips = fips_sect
# ...
# module = /usr/lib/x86_64-linux-gnu/ossl-modules/libwolfprov.so

# Verify module exists
docker run --rm --entrypoint=ls \
  cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips \
  -la /usr/lib/x86_64-linux-gnu/ossl-modules/
```

### Runtime Fails: redis_exporter Crashes

**Error:**
```
panic: crypto/tls: internal error
```

**Solution:**
```bash
# Check FIPS environment variables
docker run --rm --entrypoint=env \
  cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips \
  | grep -E 'GOLANG_FIPS|GODEBUG|OPENSSL'

# Should show:
# GOLANG_FIPS=1
# GODEBUG=fips140=only
# OPENSSL_CONF=/etc/ssl/openssl.cnf

# Check library dependencies
docker run --rm --entrypoint=ldd \
  cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips \
  /usr/local/bin/redis_exporter
```

### Performance Issues: Slow Build

**Symptoms:**
- Build takes >60 minutes

**Solutions:**
```bash
# 1. Use BuildKit caching
export DOCKER_BUILDKIT=1

# 2. Don't rebuild unnecessarily
./build.sh  # Uses cache by default

# 3. Use faster network for downloads
# Check download speeds:
curl -w "@-" -o /dev/null -s \
  "https://www.openssl.org/source/openssl-3.0.19.tar.gz" \
  <<'EOF'
time_total: %{time_total}s\n
speed_download: %{speed_download} bytes/sec\n
EOF

# 4. Use parallel builds (already configured)
# Dockerfile uses: make -j"$(nproc)"
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Build Redis Exporter FIPS

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2

      - name: Create wolfSSL password file
        run: echo "${{ secrets.WOLFSSL_PASSWORD }}" > wolfssl_password.txt

      - name: Build image
        run: |
          cd redis-exporter/1.67.0-jammy-ubuntu-22.04-fips/
          ./build.sh

      - name: Run diagnostics
        run: |
          cd redis-exporter/1.67.0-jammy-ubuntu-22.04-fips/
          ./diagnostic.sh

      - name: Push to registry
        if: github.ref == 'refs/heads/main'
        run: |
          cd redis-exporter/1.67.0-jammy-ubuntu-22.04-fips/
          echo "${{ secrets.REGISTRY_PASSWORD }}" | docker login -u "${{ secrets.REGISTRY_USER }}" --password-stdin
          ./build.sh --push
```

### GitLab CI Example

```yaml
build-redis-exporter-fips:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  variables:
    DOCKER_BUILDKIT: 1
  before_script:
    - echo "$WOLFSSL_PASSWORD" > wolfssl_password.txt
  script:
    - cd redis-exporter/1.67.0-jammy-ubuntu-22.04-fips/
    - ./build.sh
    - ./diagnostic.sh
  after_script:
    - rm -f wolfssl_password.txt
  cache:
    paths:
      - /var/lib/docker
```

### Jenkins Pipeline Example

```groovy
pipeline {
    agent any

    environment {
        DOCKER_BUILDKIT = '1'
    }

    stages {
        stage('Prepare') {
            steps {
                sh 'echo "$WOLFSSL_PASSWORD" > wolfssl_password.txt'
            }
        }

        stage('Build') {
            steps {
                dir('redis-exporter/1.67.0-jammy-ubuntu-22.04-fips') {
                    sh './build.sh'
                }
            }
        }

        stage('Test') {
            steps {
                dir('redis-exporter/1.67.0-jammy-ubuntu-22.04-fips') {
                    sh './diagnostic.sh'
                }
            }
        }

        stage('Push') {
            when {
                branch 'main'
            }
            steps {
                dir('redis-exporter/1.67.0-jammy-ubuntu-22.04-fips') {
                    sh './build.sh --push'
                }
            }
        }
    }

    post {
        always {
            sh 'rm -f wolfssl_password.txt'
        }
    }
}
```

## Contributing

### Code Style

- Follow existing patterns in other FIPS images (redis, golang, python, nginx)
- Use 4-space indentation in shell scripts
- Add comments for complex operations
- Keep Dockerfile stages clearly separated

### Pull Request Process

1. Create feature branch
2. Make changes
3. Test locally: `./build.sh && ./diagnostic.sh`
4. Update documentation if needed
5. Create pull request with description
6. Wait for CI/CD checks to pass

### Testing Requirements

Before submitting PR:
- ✅ Image builds successfully
- ✅ FIPS validation passes
- ✅ Diagnostic tests pass
- ✅ No security warnings
- ✅ Documentation updated

---

**Last Updated:** March 27, 2026
**Guide Version:** 1.0
**Image Version:** 1.67.0-jammy-ubuntu-22.04-fips
