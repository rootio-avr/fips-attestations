# Nginx wolfSSL FIPS 140-3 - Developer Guide

**Version:** 1.0
**Image:** cr.root.io/nginx:1.29.1-debian-bookworm-fips
**Audience:** Developers, DevOps engineers, security engineers

## Table of Contents

1. [Introduction](#introduction)
2. [Development Environment Setup](#development-environment-setup)
3. [Building from Source](#building-from-source)
4. [Project Structure](#project-structure)
5. [Customizing the Image](#customizing-the-image)
6. [Extending Functionality](#extending-functionality)
7. [Debugging and Troubleshooting](#debugging-and-troubleshooting)
8. [Testing](#testing)
9. [Performance Tuning](#performance-tuning)
10. [Security Hardening](#security-hardening)
11. [CI/CD Integration](#cicd-integration)
12. [Contributing](#contributing)

---

## Introduction

This guide helps developers understand, customize, and extend the Nginx wolfSSL FIPS 140-3 image.

**What You'll Learn:**
- How to build and customize the image
- Internal architecture and file organization
- Debugging techniques and tools
- Performance optimization strategies
- Security best practices

**Prerequisites:**
- Docker (20.10+)
- Basic understanding of Nginx, OpenSSL, and TLS
- Familiarity with shell scripting and Makefiles
- Understanding of FIPS 140-3 concepts (see ARCHITECTURE.md)

---

## Development Environment Setup

### Required Tools

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y \
    docker.io \
    git \
    make \
    build-essential \
    curl \
    jq \
    openssl

# Verify installations
docker --version          # 20.10+
git --version             # 2.x+
make --version            # 4.x+
gcc --version             # 11.x+
openssl version           # 1.1.1+ or 3.x
```

### Clone Repository

```bash
# Clone the repository
git clone https://github.com/your-org/fips-attestations.git
cd fips-attestations/nginx/1.29.1-debian-bookworm-fips

# Verify structure
ls -la
# Should see: Dockerfile, build.sh, patches/, configs/, diagnostics/, etc.
```

### Docker Configuration

```bash
# Add user to docker group (to avoid sudo)
sudo usermod -aG docker $USER
newgrp docker

# Configure Docker for larger builds
# Edit /etc/docker/daemon.json
{
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}

sudo systemctl restart docker
```

---

## Building from Source

### Standard Build

```bash
# Full build (all stages)
./build.sh

# Expected output:
# ================================================================================
#   Building Nginx 1.29.1 with wolfSSL FIPS 140-3
# ================================================================================
#
# Phase 1: Downloading sources...
# ✓ nginx-1.29.1.tar.gz downloaded and verified
# ✓ wolfssl-5.8.2-stable.tar.gz downloaded and verified
# ✓ wolfProvider-1.1.0.tar.gz downloaded and verified
# ✓ openssl-3.0.19.tar.gz downloaded and verified
#
# Phase 2: Building Docker image...
# [Docker build output...]
#
# Phase 3: Running diagnostics...
# [Diagnostic output...]
#
# Build complete: cr.root.io/nginx:1.29.1-debian-bookworm-fips
```

**Build Time:** ~15-25 minutes (depends on CPU)

### Build Stages

The Dockerfile uses multi-stage builds:

```bash
# Build only the builder stage (for testing)
docker build --target builder -t nginx-fips-builder .

# Build only the runtime stage
docker build --target runtime -t nginx-fips-runtime .

# Build with custom build args
docker build \
  --build-arg NGINX_VERSION=1.29.1 \
  --build-arg WOLFSSL_VERSION=5.8.2 \
  --build-arg OPENSSL_VERSION=3.0.19 \
  -t nginx-fips-custom .
```

### Build Arguments

All build arguments with defaults:

```dockerfile
# Dockerfile build args
ARG NGINX_VERSION=1.29.1
ARG WOLFSSL_VERSION=5.8.2-stable
ARG WOLFPROVIDER_VERSION=1.1.0
ARG OPENSSL_VERSION=3.0.19
ARG DEBIAN_VERSION=bookworm-slim
```

**Change versions:**
```bash
docker build \
  --build-arg NGINX_VERSION=1.27.4 \
  -t nginx-fips-newer .
```

### Caching and Rebuilds

```bash
# Clean build (no cache)
docker build --no-cache -t nginx-fips-clean .

# Rebuild from specific stage
docker build --target builder --no-cache -t nginx-fips-builder .

# Clear Docker build cache
docker builder prune -af
```

---

## Project Structure

### Directory Layout

```
nginx/1.29.1-debian-bookworm-fips/
│
├── Dockerfile                       # Multi-stage build definition
├── build.sh                         # Main build script
├── README.md                        # User documentation
├── QUICK-START.md                   # Quick start guide
├── IMPLEMENTATION-SUMMARY.md        # Implementation details
├── CHANGES.md                       # Change log
├── ARCHITECTURE.md                  # Architecture documentation
├── DEVELOPER-GUIDE.md               # This file
├── POC-VALIDATION-REPORT.md         # Validation report
│
├── patches/                         # Source patches (if any)
│   └── README.md
│
├── configs/                         # Configuration templates
│   ├── nginx.conf.template          # Default Nginx config
│   ├── openssl.cnf                  # OpenSSL provider config
│   └── fips-startup-check           # FIPS validation script
│
├── scripts/                         # Build and utility scripts
│   ├── generate-cert.sh             # SSL certificate generator
│   ├── docker-entrypoint.sh         # Container startup script
│   └── verify-fips.sh               # FIPS verification
│
├── diagnostics/                     # Diagnostic test suites
│   ├── test-nginx-fips-status.sh    # FIPS status tests
│   ├── test-nginx-tls-handshake.sh  # TLS handshake tests
│   └── test-images/                 # Test container images
│       └── basic-test-image/        # Basic FIPS test image
│           ├── Dockerfile
│           ├── build.sh
│           ├── src/
│           │   ├── run_all_tests.sh
│           │   ├── test_tls_protocols.sh
│           │   ├── test_fips_ciphers.sh
│           │   └── test_certificate_validation.sh
│           └── README.md
│
├── demos-image/                     # Demo configurations
│   ├── Dockerfile
│   ├── build.sh
│   ├── configs/                     # Demo Nginx configs
│   │   ├── reverse-proxy.conf
│   │   ├── static-webserver.conf
│   │   ├── tls-termination.conf
│   │   └── strict-fips.conf
│   ├── html/                        # Demo HTML content
│   │   └── index.html
│   └── README.md
│
├── sbom/                            # Software Bill of Materials
│   ├── nginx-fips-sbom.spdx.json
│   └── generation-script.sh
│
├── vex/                             # Vulnerability Exchange
│   ├── nginx-fips-vex.json
│   └── update-vex.sh
│
├── slsa/                            # SLSA Provenance
│   ├── nginx-fips-provenance.json
│   └── generate-provenance.sh
│
└── compliance/                      # Compliance documentation
    ├── CHAIN-OF-CUSTODY.md
    ├── FIPS-VALIDATION.md
    └── SECURITY-POLICY.md
```

### Key Files Explained

**Dockerfile:**
- Multi-stage build (builder + runtime)
- Downloads and verifies sources
- Compiles wolfSSL, wolfProvider, OpenSSL, Nginx
- Creates minimal runtime image

**build.sh:**
- Main build orchestrator
- Verifies prerequisites
- Calls Docker build
- Runs diagnostics
- Tags image

**docker-entrypoint.sh:**
- Container startup script
- Validates FIPS provider
- Runs POST checks
- Starts Nginx

**configs/nginx.conf.template:**
- FIPS-hardened Nginx configuration
- TLS 1.2/1.3 protocols
- FIPS-approved ciphers
- Template for customization

---

## Customizing the Image

### Customizing Nginx Configuration

**Option 1: Modify Template**

```bash
# Edit the template
vi configs/nginx.conf.template

# Rebuild image
docker build -t nginx-fips-custom .
```

**Option 2: Runtime Override**

```bash
# Create custom config
cat > my-nginx.conf <<'EOF'
worker_processes 4;

http {
    server {
        listen 443 ssl;
        ssl_protocols TLSv1.3;
        # ... custom settings ...
    }
}
EOF

# Run with custom config
docker run -d -p 443:443 \
  -v $(pwd)/my-nginx.conf:/etc/nginx/nginx.conf:ro \
  cr.root.io/nginx:1.29.1-debian-bookworm-fips
```

### Adding Nginx Modules

To add additional Nginx modules, modify the Dockerfile:

```dockerfile
# In builder stage, add module to configure flags
RUN cd /tmp/nginx-${NGINX_VERSION} && \
    ./configure \
        --prefix=/usr/local/nginx \
        --with-http_ssl_module \
        --with-http_v2_module \
        --with-http_realip_module \        # ADD THIS
        --with-http_gzip_static_module \   # AND THIS
        --with-openssl=/opt/openssl \
        # ... rest of flags ...
```

**Available modules:** https://nginx.org/en/docs/configure.html

### Changing wolfSSL Version

```bash
# Update Dockerfile
ARG WOLFSSL_VERSION=5.9.0-stable  # Change this

# Update checksums in build.sh
WOLFSSL_SHA256="<new-checksum>"

# Rebuild
./build.sh
```

**Important:** New wolfSSL versions may not have FIPS certification. Verify at:
https://csrc.nist.gov/projects/cryptographic-module-validation-program

### Adding Custom Scripts

```dockerfile
# In Dockerfile, add to runtime stage:
COPY scripts/my-custom-script.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/my-custom-script.sh
```

Then call from docker-entrypoint.sh or run manually:
```bash
docker exec nginx-container my-custom-script.sh
```

---

## Extending Functionality

### Adding Health Checks

**Docker Health Check:**

```dockerfile
# Add to Dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -kf https://localhost/health || exit 1
```

**Nginx Health Endpoint:**

```nginx
# Add to nginx.conf
location /health {
    access_log off;
    return 200 "healthy\n";
    add_header Content-Type text/plain;
}
```

### Prometheus Metrics

Add Nginx metrics exporter:

```dockerfile
# In builder stage
RUN git clone https://github.com/nginxinc/nginx-prometheus-exporter.git
# ... build exporter ...

# In runtime stage
COPY --from=builder /path/to/exporter /usr/local/bin/
```

Add to nginx.conf:
```nginx
location /metrics {
    stub_status on;
    access_log off;
    allow 127.0.0.1;
    deny all;
}
```

### Log Aggregation

**Structured JSON Logging:**

```nginx
http {
    log_format json escape=json
        '{'
          '"time":"$time_iso8601",'
          '"remote_addr":"$remote_addr",'
          '"request":"$request",'
          '"status":$status,'
          '"ssl_protocol":"$ssl_protocol",'
          '"ssl_cipher":"$ssl_cipher"'
        '}';

    access_log /var/log/nginx/access.log json;
}
```

**Forward to ELK/Splunk:**

```bash
docker run -d \
  --log-driver=syslog \
  --log-opt syslog-address=tcp://logserver:514 \
  nginx-fips
```

---

## Debugging and Troubleshooting

### Debug Build

Enable debug symbols and verbose logging:

```dockerfile
# In builder stage, change Nginx configure:
./configure \
    --with-debug \          # Add this
    # ... other flags ...
```

Then run with debug logging:
```nginx
error_log /var/log/nginx/error.log debug;
```

### Interactive Debugging

```bash
# Start container with shell
docker run -it --rm --entrypoint /bin/bash nginx-fips

# Inside container:
# Check OpenSSL configuration
openssl version -a
openssl list -providers

# Check Nginx compilation
nginx -V

# Test configuration
nginx -t

# Check FIPS status
fips-startup-check

# Manual Nginx start (foreground)
nginx -g 'daemon off;'
```

### Common Issues and Solutions

#### Issue 1: wolfProvider Not Loaded

**Symptoms:**
```
openssl list -providers
# Only shows "default" provider
```

**Debug:**
```bash
# Check provider file exists
ls -la /usr/lib/x86_64-linux-gnu/ossl-modules/libwolfprov.so

# Check OpenSSL config
cat /etc/ssl/openssl.cnf | grep -A 10 provider_sect

# Check library dependencies
ldd /usr/lib/x86_64-linux-gnu/ossl-modules/libwolfprov.so

# Try loading manually
openssl list -providers -provider wolfssl
```

**Solution:**
- Verify `/etc/ssl/openssl.cnf` has correct provider path
- Check `LD_LIBRARY_PATH` includes `/usr/local/lib`
- Ensure `libwolfssl.so.39` exists and is readable

#### Issue 2: FIPS POST Failure

**Symptoms:**
```
fips-startup-check
# ERROR: wolfSSL FIPS Power-On Self Test failed
```

**Debug:**
```bash
# Check integrity file
ls -la /usr/local/lib/.libs/libwolfssl.so.39.fips

# Manual POST test
wolfssl_fips_test  # If available

# Check wolfSSL version
strings /usr/local/lib/libwolfssl.so.39 | grep wolfSSL
```

**Solution:**
- Verify integrity checksum file exists
- Ensure binary hasn't been modified (checksum failure)
- Rebuild from clean state

#### Issue 3: TLS Handshake Failures

**Symptoms:**
```
curl: (35) SSL connect error
```

**Debug:**
```bash
# Verbose OpenSSL client
openssl s_client -connect localhost:443 -debug -msg -state

# Check cipher compatibility
openssl ciphers -v 'ECDHE-RSA-AES256-GCM-SHA384'

# Check Nginx error log
docker logs nginx-container 2>&1 | grep -i ssl
```

**Solution:**
- Verify client supports TLS 1.2/1.3
- Check cipher suite compatibility
- Ensure certificates are valid

#### Issue 4: Performance Problems

**Symptoms:**
- High CPU usage
- Slow TLS handshakes

**Debug:**
```bash
# Profile Nginx workers
docker exec nginx-container top

# Check TLS session cache
openssl s_client -connect localhost:443 -sess_out /tmp/session.pem
openssl s_client -connect localhost:443 -sess_in /tmp/session.pem
# Second connection should be faster (session reuse)

# Strace Nginx worker
docker exec nginx-container strace -p $(pidof nginx | awk '{print $NF}')
```

**Solution:**
- Enable SSL session caching in nginx.conf
- Increase worker_processes
- Use TLS 1.3 (faster handshakes)

### Logging and Tracing

**Enable Verbose Logging:**

```nginx
error_log /var/log/nginx/error.log debug;

events {
    debug_connection 192.168.1.0/24;  # Debug specific IPs
}
```

**OpenSSL Debug:**

```bash
# Set environment variable
export OPENSSL_DEBUG=1

# Run with debug
docker run -e OPENSSL_DEBUG=1 nginx-fips
```

**Packet Capture:**

```bash
# Capture TLS traffic
docker exec nginx-container tcpdump -i eth0 -w /tmp/capture.pcap port 443

# Analyze with Wireshark
docker cp nginx-container:/tmp/capture.pcap .
wireshark capture.pcap
```

---

## Testing

### Unit Tests

The project includes multiple test suites:

**Run All Diagnostics:**
```bash
./diagnostic.sh

# Expected output:
# ================================================================================
#   Nginx wolfSSL FIPS 140-3 - Diagnostic Test Suite
# ================================================================================
# Found 2 test(s)
#
# [1/2] Running: test-nginx-fips-status
# ✅ test-nginx-fips-status PASSED
#
# [2/2] Running: test-nginx-tls-handshake
# ✅ test-nginx-tls-handshake PASSED
#
# ================================================================================
#   Test Summary
# ================================================================================
# Total tests: 2
# Passed: 2
# Failed: 0
```

**Run Individual Tests:**
```bash
./diagnostics/test-nginx-fips-status.sh
./diagnostics/test-nginx-tls-handshake.sh
```

### Integration Tests (Test Image)

```bash
# Build test image
cd diagnostics/test-images/basic-test-image
./build.sh

# Run all tests
docker run --rm nginx-fips-test:latest

# Expected: 14 tests, all passing
# Tests: TLS protocols, FIPS ciphers, certificate validation
```

### Manual Testing

**Test TLS 1.2:**
```bash
openssl s_client -connect localhost:443 -tls1_2
```

**Test TLS 1.3:**
```bash
openssl s_client -connect localhost:443 -tls1_3
```

**Test Specific Cipher:**
```bash
openssl s_client -connect localhost:443 -tls1_2 -cipher 'ECDHE-RSA-AES256-GCM-SHA384'
```

**Test Protocol Blocking:**
```bash
# Should fail (TLS 1.0 blocked)
openssl s_client -connect localhost:443 -tls1
```

### Load Testing

**ApacheBench:**
```bash
ab -n 1000 -c 10 -f TLS1.2 https://localhost/
```

**wrk (HTTP benchmarking):**
```bash
wrk -t 4 -c 100 -d 30s https://localhost/
```

### Security Testing

**nmap SSL Scan:**
```bash
nmap --script ssl-enum-ciphers -p 443 localhost
```

**testssl.sh:**
```bash
git clone https://github.com/drwetter/testssl.sh.git
./testssl.sh/testssl.sh localhost:443
```

**Expected results:**
- TLS 1.2, TLS 1.3 only
- FIPS-approved ciphers
- Perfect Forward Secrecy (ECDHE)

---

## Performance Tuning

### Nginx Worker Optimization

```nginx
# Auto-detect CPU cores
worker_processes auto;

# Increase connections per worker
events {
    worker_connections 4096;
    use epoll;  # Linux
}

# Enable efficient file serving
http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
}
```

### SSL/TLS Performance

**Session Caching:**
```nginx
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 10m;
ssl_session_tickets off;  # Or on, depending on security requirements
```

**Prefer TLS 1.3:**
```nginx
# TLS 1.3 has faster handshakes (1-RTT vs 2-RTT)
ssl_protocols TLSv1.3;
```

**OCSP Stapling:**
```nginx
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4 valid=300s;
```

### Kernel Tuning

```bash
# /etc/sysctl.conf
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65535

# Apply
sysctl -p
```

### Docker Resource Limits

```bash
docker run -d \
  --cpus="4.0" \
  --memory="2g" \
  --memory-swap="2g" \
  nginx-fips
```

---

## Security Hardening

### Minimal Privileges

**Non-root user:**
```dockerfile
# Already implemented in Dockerfile
RUN groupadd -r nginx && useradd -r -g nginx nginx
USER nginx
```

**Run as non-root:**
```bash
docker run --user nginx nginx-fips
```

### Read-Only Root Filesystem

```bash
docker run --read-only \
  -v /tmp \
  -v /var/run \
  -v /var/log/nginx \
  nginx-fips
```

### Security Options

```bash
docker run \
  --security-opt no-new-privileges \
  --cap-drop ALL \
  --cap-add NET_BIND_SERVICE \
  nginx-fips
```

### Secrets Management

**Never commit secrets to Git:**

```bash
# Use Docker secrets
echo "my-ssl-key" | docker secret create ssl-key -

docker service create \
  --secret ssl-key \
  nginx-fips
```

**Or mount at runtime:**
```bash
docker run -d \
  -v /secure/path/cert.pem:/etc/nginx/ssl/cert.pem:ro \
  -v /secure/path/key.pem:/etc/nginx/ssl/key.pem:ro \
  nginx-fips
```

### Network Security

**Restrict to specific networks:**
```bash
docker network create --driver bridge nginx-net

docker run --network nginx-net nginx-fips
```

**Use firewall:**
```bash
# Only allow 443
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j DROP
```

---

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Build and Test Nginx FIPS

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2

      - name: Build image
        run: |
          cd nginx/1.29.1-debian-bookworm-fips
          ./build.sh

      - name: Run diagnostics
        run: |
          cd nginx/1.29.1-debian-bookworm-fips
          ./diagnostic.sh

      - name: Run test image
        run: |
          cd nginx/1.29.1-debian-bookworm-fips/diagnostics/test-images/basic-test-image
          ./build.sh
          docker run --rm nginx-fips-test:latest

      - name: Security scan
        run: |
          # Trivy scan
          docker run --rm \
            -v /var/run/docker.sock:/var/run/docker.sock \
            aquasec/trivy image cr.root.io/nginx:1.29.1-debian-bookworm-fips

      - name: Push to registry
        if: github.ref == 'refs/heads/main'
        run: |
          echo "${{ secrets.REGISTRY_PASSWORD }}" | docker login -u "${{ secrets.REGISTRY_USER }}" --password-stdin cr.root.io
          docker push cr.root.io/nginx:1.29.1-debian-bookworm-fips
```

### GitLab CI Example

```yaml
stages:
  - build
  - test
  - scan
  - deploy

build:
  stage: build
  script:
    - cd nginx/1.29.1-debian-bookworm-fips
    - ./build.sh
  artifacts:
    paths:
      - nginx/1.29.1-debian-bookworm-fips

test:
  stage: test
  script:
    - cd nginx/1.29.1-debian-bookworm-fips
    - ./diagnostic.sh
    - cd diagnostics/test-images/basic-test-image
    - ./build.sh
    - docker run --rm nginx-fips-test:latest

security-scan:
  stage: scan
  script:
    - trivy image cr.root.io/nginx:1.29.1-debian-bookworm-fips

deploy:
  stage: deploy
  only:
    - main
  script:
    - docker push cr.root.io/nginx:1.29.1-debian-bookworm-fips
```

### Jenkins Pipeline

```groovy
pipeline {
    agent any

    stages {
        stage('Build') {
            steps {
                sh 'cd nginx/1.29.1-debian-bookworm-fips && ./build.sh'
            }
        }

        stage('Test') {
            steps {
                sh 'cd nginx/1.29.1-debian-bookworm-fips && ./diagnostic.sh'
                sh 'cd nginx/1.29.1-debian-bookworm-fips/diagnostics/test-images/basic-test-image && ./build.sh'
                sh 'docker run --rm nginx-fips-test:latest'
            }
        }

        stage('Security Scan') {
            steps {
                sh 'trivy image cr.root.io/nginx:1.29.1-debian-bookworm-fips'
            }
        }

        stage('Deploy') {
            when {
                branch 'main'
            }
            steps {
                sh 'docker push cr.root.io/nginx:1.29.1-debian-bookworm-fips'
            }
        }
    }
}
```

---

## Contributing

### Development Workflow

1. **Fork the repository**
2. **Create feature branch**
   ```bash
   git checkout -b feature/my-new-feature
   ```
3. **Make changes and test**
   ```bash
   ./build.sh
   ./diagnostic.sh
   ```
4. **Commit with descriptive message**
   ```bash
   git commit -m "Add support for Nginx module X"
   ```
5. **Push and create pull request**
   ```bash
   git push origin feature/my-new-feature
   ```

### Code Style

**Shell Scripts:**
- Use `#!/bin/bash` shebang
- Set `set -e` for error handling
- Use descriptive variable names
- Add comments for complex logic

**Dockerfiles:**
- Use multi-stage builds
- Minimize layers (combine RUN commands)
- Clean up in same layer (rm after install)
- Use specific versions (not `latest`)

**Nginx Configs:**
- Comment all non-obvious directives
- Group related settings
- Use consistent indentation (4 spaces)

### Testing Requirements

All contributions must:
- Pass existing diagnostics (`./diagnostic.sh`)
- Include new tests for new features
- Not break FIPS compliance
- Include updated documentation

### Submitting Issues

**Bug Reports:**
- Describe the issue
- Steps to reproduce
- Expected vs actual behavior
- Environment details (OS, Docker version, etc.)
- Relevant logs

**Feature Requests:**
- Describe the use case
- Proposed solution
- Alternative approaches considered

---

## Appendix A: Build Variables Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `NGINX_VERSION` | 1.29.1 | Nginx version to build |
| `WOLFSSL_VERSION` | 5.8.2-stable | wolfSSL FIPS version |
| `WOLFPROVIDER_VERSION` | 1.1.0 | wolfProvider version |
| `OPENSSL_VERSION` | 3.0.19 | OpenSSL version |
| `DEBIAN_VERSION` | bookworm-slim | Debian base image |

---

## Appendix B: Useful Commands

```bash
# View image layers
docker history cr.root.io/nginx:1.29.1-debian-bookworm-fips

# Inspect image
docker inspect cr.root.io/nginx:1.29.1-debian-bookworm-fips

# Export image
docker save cr.root.io/nginx:1.29.1-debian-bookworm-fips | gzip > nginx-fips.tar.gz

# Import image
gunzip -c nginx-fips.tar.gz | docker load

# View container logs
docker logs -f <container-id>

# Execute command in running container
docker exec -it <container-id> bash

# Copy files from container
docker cp <container-id>:/path/to/file .

# View resource usage
docker stats <container-id>
```

---

## Appendix C: References

- [Nginx Development Guide](https://nginx.org/en/docs/dev/development_guide.html)
- [OpenSSL Provider Documentation](https://www.openssl.org/docs/man3.0/man7/provider.html)
- [wolfSSL Manual](https://www.wolfssl.com/documentation/manuals/wolfssl/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [FIPS 140-3 Implementation Guidance](https://csrc.nist.gov/publications/detail/fips/140/3/final)

---

**Document Version:** 1.0
**Last Updated:** 2024-01-20
**Maintained By:** Root FIPS Team
