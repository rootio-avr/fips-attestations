# Redis 7.2.4 Alpine FIPS - Developer Guide

## Table of Contents

- [Getting Started](#getting-started)
- [Build Process](#build-process)
- [Testing](#testing)
- [Development Workflow](#development-workflow)
- [Updating Components](#updating-components)
- [Troubleshooting Build Issues](#troubleshooting-build-issues)
- [Contributing](#contributing)
- [CI/CD Integration](#cicd-integration)

## Getting Started

### Prerequisites

**Required:**
- Docker 20.10+ with BuildKit support
- wolfSSL commercial license (for FIPS v5.8.2)
- 10 GB free disk space
- 4 GB RAM minimum

**Optional:**
- `make` for automation
- `cosign` for image signing
- `syft` for SBOM generation

### Initial Setup

1. **Clone the repository:**

```bash
git clone https://github.com/your-org/fips-attestations
cd fips-attestations/redis/7.2.4-alpine-3.19-fips
```

2. **Set up wolfSSL credentials:**

```bash
# Create password file
echo 'your-wolfssl-commercial-password' > wolfssl_password.txt
chmod 600 wolfssl_password.txt

# Verify password is set
cat wolfssl_password.txt
```

**⚠️ IMPORTANT:** Never commit `wolfssl_password.txt` to version control!

3. **Verify prerequisites:**

```bash
# Check Docker version
docker --version  # Should be 20.10+

# Check BuildKit support
docker buildx version

# Check disk space
df -h .  # Need ~10 GB free
```

## Build Process

### Quick Build

```bash
# Run automated build script
./build.sh

# Expected output:
# ========================================
# Building FIPS Redis Image
# ========================================
# [1/5] Validating prerequisites...
# [OK] Docker is running
# [OK] BuildKit is available
# [OK] wolfssl_password.txt exists
# ...
# [SUCCESS] Build completed successfully!
# Image: cr.root.io/redis:7.2.4-alpine-3.19-fips
# Size: 119.49 MB
```

### Manual Build

```bash
# Using BuildKit (recommended)
DOCKER_BUILDKIT=1 docker build \
    --secret id=wolfssl_password,src=wolfssl_password.txt \
    -t cr.root.io/redis:7.2.4-alpine-3.19-fips \
    -f Dockerfile .

# Build with custom image name
DOCKER_BUILDKIT=1 docker build \
    --secret id=wolfssl_password,src=wolfssl_password.txt \
    -t my-registry/redis:7.2.4-fips \
    .

# Build with build arguments
DOCKER_BUILDKIT=1 docker build \
    --secret id=wolfssl_password,src=wolfssl_password.txt \
    --build-arg OPENSSL_VERSION=3.3.0 \
    --build-arg REDIS_VERSION=7.2.4 \
    -t cr.root.io/redis:7.2.4-alpine-3.19-fips \
    .
```

### Build Options

**Environment Variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| `DOCKER_BUILDKIT` | `1` | Enable BuildKit (required) |
| `BUILDKIT_PROGRESS` | `auto` | Progress output (`auto`, `plain`, `tty`) |

**Build Arguments:**

| Argument | Default | Description |
|----------|---------|-------------|
| `OPENSSL_VERSION` | `3.3.0` | OpenSSL version to build |
| `REDIS_VERSION` | `7.2.4` | Redis version to build |
| `WOLFSSL_URL` | (commercial) | wolfSSL FIPS download URL |
| `WOLFPROV_VERSION` | `v1.1.0` | wolfProvider version |

**Example with custom versions:**

```bash
DOCKER_BUILDKIT=1 docker build \
    --secret id=wolfssl_password,src=wolfssl_password.txt \
    --build-arg REDIS_VERSION=7.2.5 \
    --build-arg OPENSSL_VERSION=3.3.1 \
    -t cr.root.io/redis:7.2.5-alpine-fips \
    .
```

### Build Stages

The build process has multiple stages:

```
Stage 1: Builder (Alpine 3.19)
  ├─ Install build dependencies
  ├─ Build OpenSSL 3.3.0
  ├─ Build wolfSSL FIPS v5.8.2
  │   └─ Run fips-hash.sh (integrity check)
  ├─ Build wolfProvider v1.1.0
  ├─ Apply Redis FIPS patch
  └─ Build Redis 7.2.4 with TLS

Stage 2: Runtime (Alpine 3.19)
  ├─ Copy binaries from builder
  ├─ Install minimal runtime dependencies
  ├─ Configure dynamic linker (musl)
  ├─ Create redis user
  ├─ Copy configuration files
  └─ Set up entrypoint
```

**Build time:** 15-20 minutes (first build), 2-5 minutes (cached)

### Caching Strategy

Docker BuildKit caches layers aggressively. To optimize:

**Layer Order (fastest → slowest to change):**
1. Base image (`FROM alpine:3.19`)
2. Build dependencies (`apk add ...`)
3. OpenSSL build (rarely changes)
4. wolfSSL FIPS build (rarely changes)
5. wolfProvider build (rarely changes)
6. Redis source download
7. **Redis patch application** ← Change here invalidates cache
8. Redis build

**To force rebuild without cache:**

```bash
docker build --no-cache \
    --secret id=wolfssl_password,src=wolfssl_password.txt \
    -t cr.root.io/redis:7.2.4-alpine-3.19-fips \
    .
```

**To rebuild from a specific stage:**

```bash
# Rebuild only Redis (keep OpenSSL/wolfSSL cached)
docker build \
    --secret id=wolfssl_password,src=wolfssl_password.txt \
    --build-arg CACHEBUST=$(date +%s) \
    -t cr.root.io/redis:7.2.4-alpine-3.19-fips \
    .
```

## Testing

### Pre-Build Validation

```bash
# Run validation script
./test-build.sh

# Run full validation (includes patch test)
./test-build.sh --full

# Expected output:
# ========================================
# Redis FIPS Build Validation
# ========================================
# [CHECK 1] Docker prerequisites
# [PASS] Docker installed
# [CHECK 2] Required files present
# [PASS] Dockerfile exists
# ...
# Total checks: 27
# Passed: 27
# ✓ PRE-BUILD VALIDATION PASSED
```

### Post-Build Testing

**Quick validation:**

```bash
# Start container
docker run -d -p 6379:6379 --name redis-fips-test \
    cr.root.io/redis:7.2.4-alpine-3.19-fips

# Wait for startup
sleep 3

# Check FIPS validation passed
docker logs redis-fips-test | grep "ALL FIPS CHECKS PASSED"

# Test Redis connectivity
docker exec redis-fips-test redis-cli PING

# Cleanup
docker stop redis-fips-test && docker rm redis-fips-test
```

**Comprehensive test suite:**

```bash
cd diagnostics/test-images/basic-test-image

# Build test image
./build.sh

# Run all tests
docker run --rm redis-fips-test:latest

# Expected output:
# ========================================
# Redis FIPS Test Suite
# ========================================
# [TEST 1/10] FIPS POST validation...PASS
# [TEST 2/10] Redis connectivity...PASS
# [TEST 3/10] Basic operations...PASS
# [TEST 4/10] Lua scripting...PASS
# [TEST 5/10] TLS connections...PASS
# [TEST 6/10] Persistence (RDB)...PASS
# [TEST 7/10] Persistence (AOF)...PASS
# [TEST 8/10] FIPS algorithm enforcement...PASS
# [TEST 9/10] Non-FIPS algorithms blocked...PASS
# [TEST 10/10] Performance benchmark...PASS
# ========================================
# ✓ ALL TESTS PASSED (10/10)
# ========================================
```

### Manual Testing

**Test FIPS validation:**

```bash
docker run --rm cr.root.io/redis:7.2.4-alpine-3.19-fips \
    fips-startup-check
```

**Test wolfProvider:**

```bash
docker run --rm cr.root.io/redis:7.2.4-alpine-3.19-fips \
    openssl list -providers
```

**Test FIPS enforcement (MD5 should fail):**

```bash
docker run --rm cr.root.io/redis:7.2.4-alpine-3.19-fips \
    openssl dgst -md5 /etc/redis/redis.conf

# Expected: Error setting digest (FIPS blocks MD5)
```

**Test Redis with Lua scripting:**

```bash
docker run -d --name redis-test cr.root.io/redis:7.2.4-alpine-3.19-fips
docker exec redis-test redis-cli EVAL "return redis.call('PING')" 0
# Expected: PONG (uses SHA-256 hashing internally)
docker stop redis-test && docker rm redis-test
```

## Development Workflow

### Modifying the Dockerfile

1. **Make changes to Dockerfile**

```bash
vim Dockerfile
```

2. **Validate syntax**

```bash
# Use hadolint for Dockerfile linting (optional)
docker run --rm -i hadolint/hadolint < Dockerfile
```

3. **Test build**

```bash
./build.sh
```

4. **Run validation tests**

```bash
./test-build.sh --full
```

5. **Test runtime**

```bash
docker run -d -p 6379:6379 --name redis-dev \
    cr.root.io/redis:7.2.4-alpine-3.19-fips
docker logs redis-dev
docker exec redis-dev redis-cli PING
docker stop redis-dev && docker rm redis-dev
```

### Updating the FIPS Patch

**When to update the patch:**
- Redis version upgrade
- Bug fix in patch
- Additional files need patching

**Update process:**

1. **Download new Redis version:**

```bash
cd /tmp
wget http://download.redis.io/releases/redis-7.2.5.tar.gz
tar xzf redis-7.2.5.tar.gz
cp -r redis-7.2.5 redis-7.2.5-original
```

2. **Make modifications:**

```bash
cd redis-7.2.5

# Edit src/eval.c, src/debug.c, etc.
vim src/eval.c
```

3. **Generate new patch:**

```bash
cd /tmp
diff -Naur redis-7.2.5-original redis-7.2.5 > \
    redis-fips-sha256-redis7.2.5.patch
```

4. **Test patch:**

```bash
cd redis-7.2.5-original
patch -p1 --dry-run < /tmp/redis-fips-sha256-redis7.2.5.patch
# Expected: All hunks applied successfully
```

5. **Copy to project:**

```bash
cp /tmp/redis-fips-sha256-redis7.2.5.patch \
    patches/redis-fips-sha256-redis7.2.5.patch
```

6. **Update Dockerfile:**

```dockerfile
COPY patches/redis-fips-sha256-redis7.2.5.patch /tmp/redis-fips-sha256.patch
```

7. **Test build:**

```bash
./build.sh
```

### Debugging Build Failures

**Enable verbose output:**

```bash
BUILDKIT_PROGRESS=plain docker build \
    --secret id=wolfssl_password,src=wolfssl_password.txt \
    -t cr.root.io/redis:7.2.4-alpine-3.19-fips \
    . 2>&1 | tee build.log
```

**Build to specific stage:**

```bash
# Build only to builder stage
docker build --target builder \
    --secret id=wolfssl_password,src=wolfssl_password.txt \
    -t redis-builder \
    .

# Inspect builder stage
docker run --rm -it redis-builder /bin/sh
```

**Common issues:**

| Error | Cause | Solution |
|-------|-------|----------|
| `csplit: not found` | Missing coreutils | Add `coreutils` to apk install |
| `Patch does not apply` | Wrong Redis version | Update patch for correct version |
| `wolfSSL FIPS POST failed` | Corrupted build | Clean rebuild (`--no-cache`) |
| `wolfProvider not loaded` | OpenSSL config issue | Check openssl.cnf, OPENSSL_CONF |

### Local Development Environment

**Option 1: Docker development container**

```bash
# Start interactive build container
docker run --rm -it \
    -v $(pwd):/workspace \
    -w /workspace \
    alpine:3.19 /bin/sh

# Inside container
apk add build-base gcc g++ make cmake curl wget
# ... development work ...
```

**Option 2: Use builder stage**

```bash
# Build to builder stage
docker build --target builder \
    --secret id=wolfssl_password,src=wolfssl_password.txt \
    -t redis-dev-builder \
    .

# Run interactive shell
docker run --rm -it redis-dev-builder /bin/sh

# Inside container:
cd /tmp/redis-7.2.4
# ... test changes ...
make BUILD_TLS=yes
src/redis-server --version
```

## Updating Components

### Updating Redis Version

1. **Update version in Dockerfile:**

```dockerfile
ENV REDIS_VERSION=7.2.5
```

2. **Update patch (if needed):**

See "Updating the FIPS Patch" section above.

3. **Update test script:**

```bash
vim test-build.sh
# Change: REDIS_VERSION="7.2.5"
```

4. **Test build:**

```bash
./build.sh
```

5. **Update documentation:**

```bash
vim README.md ARCHITECTURE.md
# Update version references
```

### Updating OpenSSL Version

1. **Update version in Dockerfile:**

```dockerfile
ENV OPENSSL_VERSION=3.3.1
```

2. **Test compatibility with wolfProvider:**

```bash
./build.sh
docker run --rm cr.root.io/redis:7.2.4-alpine-3.19-fips \
    openssl list -providers
```

3. **Run full validation:**

```bash
./test-build.sh --full
```

### Updating wolfSSL FIPS

**⚠️ CRITICAL:** wolfSSL FIPS cannot be arbitrarily updated. Each FIPS version is tied to a specific CMVP certificate.

**To update wolfSSL FIPS:**

1. **Verify new version is FIPS 140-3 validated**
   - Check NIST CMVP website: https://csrc.nist.gov/projects/cmvp
   - Confirm certificate is active

2. **Update Dockerfile:**

```dockerfile
ENV WOLFSSL_URL=https://www.wolfssl.com/comm/wolfssl/wolfssl-X.Y.Z-commercial-fips-vN.N.N.7z
```

3. **Update configure flags if needed:**

```bash
# Check wolfSSL release notes for required flags
./configure --enable-fips=v5 ...
```

4. **Test thoroughly:**

```bash
./build.sh
docker run --rm cr.root.io/redis:7.2.4-alpine-3.19-fips fips-startup-check
```

5. **Update compliance documentation:**

```bash
vim ATTESTATION.md
# Update certificate number, validation date, etc.
```

### Updating wolfProvider

1. **Check compatibility:**
   - wolfProvider version must be compatible with wolfSSL and OpenSSL versions
   - Check https://github.com/wolfSSL/wolfProvider/releases

2. **Update Dockerfile:**

```dockerfile
ENV WOLFPROV_VERSION=v1.2.0
```

3. **Test build and runtime:**

```bash
./build.sh
docker run --rm cr.root.io/redis:7.2.4-alpine-3.19-fips \
    openssl list -providers
```

## Troubleshooting Build Issues

### Issue: Patch Fails to Apply

**Symptom:**

```
error: patch failed: src/eval.c:112
error: src/eval.c: patch does not apply
```

**Diagnosis:**

```bash
# Check Redis version
grep "ENV REDIS_VERSION" Dockerfile

# Check patch target version
head patches/redis-fips-sha256-redis7.2.4.patch

# Test patch manually
cd /tmp
wget http://download.redis.io/releases/redis-7.2.4.tar.gz
tar xzf redis-7.2.4.tar.gz
cd redis-7.2.4
patch -p1 --dry-run < /path/to/redis-fips-sha256-redis7.2.4.patch
```

**Solution:**

Create Redis version-specific patch (see "Updating the FIPS Patch" section).

### Issue: wolfSSL FIPS POST Fails

**Symptom:**

```
[CHECK 2/5] Running wolfSSL FIPS POST...
[FAIL] FIPS POST failed
```

**Diagnosis:**

```bash
# Run FIPS check utility
docker run --rm cr.root.io/redis:7.2.4-alpine-3.19-fips \
    fips-startup-check

# Check for error details
docker run --rm cr.root.io/redis:7.2.4-alpine-3.19-fips \
    fips-startup-check 2>&1 | grep -i error
```

**Common causes:**
1. Incomplete wolfSSL build (missing fips-hash.sh step)
2. Corrupted download
3. Build environment issue

**Solution:**

```bash
# Clean rebuild
docker build --no-cache \
    --secret id=wolfssl_password,src=wolfssl_password.txt \
    -t cr.root.io/redis:7.2.4-alpine-3.19-fips \
    .
```

### Issue: wolfProvider Not Loaded

**Symptom:**

```
[CHECK 4/5] Verifying wolfProvider is loaded...
[FAIL] wolfProvider not found
```

**Diagnosis:**

```bash
# Check OpenSSL configuration
docker run --rm cr.root.io/redis:7.2.4-alpine-3.19-fips \
    cat /usr/local/openssl/ssl/openssl.cnf

# Check provider module exists
docker run --rm cr.root.io/redis:7.2.4-alpine-3.19-fips \
    ls -la /usr/local/openssl/lib/ossl-modules/

# Test provider loading manually
docker run --rm cr.root.io/redis:7.2.4-alpine-3.19-fips \
    openssl list -providers -verbose
```

**Solution:**

1. Verify `openssl.cnf` has correct provider configuration
2. Ensure `libwolfprov.so` is copied to runtime stage
3. Check `OPENSSL_MODULES` environment variable

### Issue: Library Not Found

**Symptom:**

```
redis-server: error while loading shared libraries: libwolfssl.so.42: cannot open shared object file
```

**Diagnosis:**

```bash
# Check library path configuration
docker run --rm cr.root.io/redis:7.2.4-alpine-3.19-fips \
    cat /etc/ld-musl-x86_64.path

# Check if library exists
docker run --rm cr.root.io/redis:7.2.4-alpine-3.19-fips \
    ls -la /usr/local/lib/libwolfssl*

# Check library dependencies
docker run --rm cr.root.io/redis:7.2.4-alpine-3.19-fips \
    ldd /usr/local/bin/redis-server
```

**Solution:**

Update `/etc/ld-musl-*.path` in Dockerfile runtime stage:

```dockerfile
RUN set -eux; \
    ARCH=$(uname -m); \
    echo "/usr/local/openssl/lib" > /etc/ld-musl-${ARCH}.path; \
    echo "/usr/local/lib" >> /etc/ld-musl-${ARCH}.path;
```

## Contributing

### Code Style

**Dockerfile:**
- Use multi-line `RUN` commands with `set -eux`
- Add comments for complex steps
- Group related operations
- Use `--no-cache` flags for apk where appropriate

**Shell Scripts:**
- Use `#!/bin/bash` shebang
- Enable strict mode: `set -euo pipefail`
- Add usage instructions in comments
- Validate inputs

**Patches:**
- Use unified diff format (`diff -Naur`)
- Include context (3 lines before/after)
- Add comments explaining changes
- Test on clean source tree

### Commit Guidelines

**Format:**

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `refactor`: Code refactoring
- `test`: Tests
- `chore`: Build/tooling

**Examples:**

```
feat(patch): Add Redis 7.2.5 FIPS patch

- Create new patch for Redis 7.2.5
- Update line numbers for eval.c, debug.c
- Test patch application

Closes #123
```

```
fix(dockerfile): Correct musl library path configuration

Previously used /etc/ld.so.conf.d which doesn't exist on musl.
Now uses /etc/ld-musl-*.path for Alpine Linux.

Fixes #456
```

### Pull Request Process

1. **Create feature branch:**

```bash
git checkout -b feature/redis-7.2.5-support
```

2. **Make changes and test:**

```bash
./build.sh
./test-build.sh --full
```

3. **Update documentation:**

```bash
vim README.md ARCHITECTURE.md DEVELOPER-GUIDE.md
```

4. **Commit changes:**

```bash
git add .
git commit -m "feat(redis): Add Redis 7.2.5 support"
```

5. **Push and create PR:**

```bash
git push origin feature/redis-7.2.5-support
# Create pull request on GitHub
```

6. **PR checklist:**
   - [ ] Build succeeds
   - [ ] All tests pass
   - [ ] Documentation updated
   - [ ] CHANGELOG updated
   - [ ] No secrets committed

## CI/CD Integration

### GitHub Actions

**Example workflow (.github/workflows/build.yml):**

```yaml
name: Build and Test Redis FIPS Image

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2

      - name: Create wolfSSL password file
        run: echo "${{ secrets.WOLFSSL_PASSWORD }}" > wolfssl_password.txt

      - name: Run pre-build validation
        run: ./test-build.sh --full

      - name: Build image
        run: |
          DOCKER_BUILDKIT=1 docker build \
            --secret id=wolfssl_password,src=wolfssl_password.txt \
            -t cr.root.io/redis:7.2.4-alpine-3.19-fips \
            .

      - name: Test image
        run: |
          docker run -d -p 6379:6379 --name redis-test \
            cr.root.io/redis:7.2.4-alpine-3.19-fips
          sleep 5
          docker logs redis-test | grep "ALL FIPS CHECKS PASSED"
          docker exec redis-test redis-cli PING
          docker stop redis-test

      - name: Run test suite
        run: |
          cd diagnostics/test-images/basic-test-image
          ./build.sh
          docker run --rm redis-fips-test:latest

      - name: Login to registry
        if: github.ref == 'refs/heads/main'
        uses: docker/login-action@v2
        with:
          registry: cr.root.io
          username: ${{ secrets.REGISTRY_USERNAME }}
          password: ${{ secrets.REGISTRY_PASSWORD }}

      - name: Push image
        if: github.ref == 'refs/heads/main'
        run: docker push cr.root.io/redis:7.2.4-alpine-3.19-fips

      - name: Generate SBOM
        if: github.ref == 'refs/heads/main'
        run: |
          syft cr.root.io/redis:7.2.4-alpine-3.19-fips \
            -o spdx-json > compliance/SBOM-redis-7.2.4-alpine-3.19-fips.spdx.json
```

### GitLab CI

**Example .gitlab-ci.yml:**

```yaml
variables:
  DOCKER_DRIVER: overlay2
  DOCKER_BUILDKIT: 1

stages:
  - validate
  - build
  - test
  - push

validate:
  stage: validate
  script:
    - ./test-build.sh --full

build:
  stage: build
  script:
    - echo "$WOLFSSL_PASSWORD" > wolfssl_password.txt
    - docker build --secret id=wolfssl_password,src=wolfssl_password.txt
      -t cr.root.io/redis:7.2.4-alpine-3.19-fips .
  artifacts:
    expire_in: 1 hour

test:
  stage: test
  script:
    - docker run -d -p 6379:6379 --name redis-test
      cr.root.io/redis:7.2.4-alpine-3.19-fips
    - sleep 5
    - docker logs redis-test | grep "ALL FIPS CHECKS PASSED"
    - docker exec redis-test redis-cli PING

push:
  stage: push
  only:
    - main
  script:
    - docker login -u $REGISTRY_USER -p $REGISTRY_PASSWORD cr.root.io
    - docker push cr.root.io/redis:7.2.4-alpine-3.19-fips
```

---

**Document Version:** 1.0
**Last Updated:** March 26, 2026
**Maintained By:** Root FIPS Team
