# Redis Exporter v1.67.0 FIPS 140-3 Image

[![FIPS 140-3](https://img.shields.io/badge/FIPS%20140--3-Compliant-green.svg)](https://csrc.nist.gov/projects/cryptographic-module-validation-program)
[![wolfSSL](https://img.shields.io/badge/wolfSSL-5.8.2-blue.svg)](https://www.wolfssl.com/)
[![Go](https://img.shields.io/badge/Go-1.25%20FIPS-00ADD8.svg)](https://github.com/golang-fips/go)
[![Redis Exporter](https://img.shields.io/badge/redis__exporter-1.67.0-red.svg)](https://github.com/oliver006/redis_exporter)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04-orange.svg)](https://ubuntu.com/)

A FIPS 140-3 compliant Redis Exporter v1.67.0 container image for Prometheus monitoring, built with golang-fips/go on Ubuntu 22.04.

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Quick Start](#quick-start)
- [FIPS Compliance](#fips-compliance)
- [Architecture](#architecture)
- [Configuration](#configuration)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [Documentation](#documentation)
- [Examples](#examples)
- [Security](#security)
- [License](#license)

## 🎯 Overview

This image provides a production-ready, FIPS 140-3 compliant Redis metrics exporter for Prometheus, suitable for government and enterprise environments requiring validated cryptography.

**Key Components:**
- **redis_exporter v1.67.0** - Prometheus exporter for Redis metrics
- **golang-fips/go v1.25** - FIPS-enabled Go compiler and runtime
- **wolfSSL FIPS v5.8.2** - CMVP Certificate #4718
- **OpenSSL 3.0.19** - FIPS module support
- **wolfProvider v1.1.0** - OpenSSL 3.x provider for wolfSSL integration
- **Ubuntu 22.04 LTS** - Long-term support base image

**Image Size:** ~180 MB

## ✨ Features

### FIPS 140-3 Compliance
- ✅ wolfSSL FIPS v5.8.2 (CMVP Certificate #4718)
- ✅ Automatic FIPS POST (Power-On Self Test) on startup
- ✅ FIPS-approved cryptographic algorithms only
- ✅ Non-FIPS algorithms blocked (MD5, SHA-1)
- ✅ golang-fips/go v1.25 with strict FIPS runtime

### Security Features
- ✅ All crypto operations use FIPS-validated module
- ✅ TLS connections to Redis (FIPS-compliant)
- ✅ TLS metrics endpoint support
- ✅ Non-root user execution
- ✅ Minimal attack surface

### Redis Monitoring Features
- ✅ All Redis metrics exposed (memory, commands, clients, replication, etc.)
- ✅ Redis Sentinel support
- ✅ Redis Cluster support
- ✅ Multiple Redis instances monitoring
- ✅ TLS/SSL Redis connections
- ✅ Redis authentication support
- ✅ Compatible with all Redis versions (2.x - 7.x)

### Prometheus Integration
- ✅ Standard Prometheus metrics format
- ✅ Prometheus Operator ServiceMonitor support
- ✅ Customizable metrics endpoint
- ✅ High cardinality metric labels support

## 🚀 Quick Start

### Pull and Run

```bash
# Pull the image
docker pull cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips

# Run with Redis connection
docker run -d -p 9121:9121 \
  -e REDIS_ADDR=redis://my-redis-server:6379 \
  --name redis-exporter-fips \
  cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips

# Check FIPS validation logs
docker logs redis-exporter-fips

# Test metrics endpoint
curl http://localhost:9121/metrics
```

### Expected Output

The container performs automatic FIPS validation on startup:

```
======================================
Redis Exporter v1.67.0 with FIPS 140-3
======================================

Performing FIPS validation...

[CHECK 1/5] Verifying environment variables...
[OK] OPENSSL_CONF=/etc/ssl/openssl.cnf
[OK] GODEBUG=fips140=only

[CHECK 2/5] Running wolfSSL FIPS POST...
  ✓ FIPS POST completed successfully
  All Known Answer Tests (KAT) passed

[CHECK 3/5] Verifying OpenSSL version...
[OK] OpenSSL version: OpenSSL 3.0.19

[CHECK 4/5] Verifying wolfProvider is loaded...
[OK] wolfProvider (wolfSSL Provider FIPS) is loaded and active

[CHECK 5/5] Testing FIPS enforcement (MD5 should be blocked)...
[OK] MD5 is blocked (FIPS enforcement active)

======================================
✓ ALL FIPS CHECKS PASSED
======================================

FIPS Components:
  - wolfSSL FIPS: v5.8.2 (Certificate #4718)
  - wolfProvider: v1.1.0
  - OpenSSL: OpenSSL 3.0.19
  - redis_exporter: v1.67.0
  - golang-fips/go: v1.25

======================================
Starting redis_exporter...
======================================

Configuration:
  Redis Address: redis://my-redis-server:6379
  Metrics Endpoint: :9121/metrics
  Log Format: txt
  Debug Mode: false

* Ready to export Redis metrics
```

### Basic Operations

```bash
# Scrape metrics
curl http://localhost:9121/metrics

# Check specific metric
curl -s http://localhost:9121/metrics | grep redis_up

# Monitor multiple Redis instances
docker run -d -p 9121:9121 \
  -e REDIS_ADDR=redis://redis1:6379,redis://redis2:6379 \
  --name redis-exporter-fips \
  cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips

# Connect to Redis with TLS
docker run -d -p 9121:9121 \
  -e REDIS_ADDR=rediss://my-redis-server:6380 \
  -e REDIS_EXPORTER_TLS_CLIENT_KEY_FILE=/certs/client.key \
  -e REDIS_EXPORTER_TLS_CLIENT_CERT_FILE=/certs/client.crt \
  -e REDIS_EXPORTER_TLS_CA_CERT_FILE=/certs/ca.crt \
  -v $(pwd)/certs:/certs:ro \
  --name redis-exporter-fips \
  cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips

# Connect to Redis with authentication
docker run -d -p 9121:9121 \
  -e REDIS_ADDR=redis://my-redis-server:6379 \
  -e REDIS_PASSWORD=my-secret-password \
  --name redis-exporter-fips \
  cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips
```

## 🔒 FIPS Compliance

### CMVP Certificate #4718

This image uses **wolfSSL FIPS v5.8.2**, validated under FIPS 140-3:

- **Certificate:** #4718
- **Validation:** NIST CMVP FIPS 140-3
- **Module:** wolfCrypt FIPS v5.8.2
- **Algorithms:** AES, SHA-256, HMAC, RSA, ECDSA, ECDH, DRBG

**Status:** ✅ **ACTIVE** (as of March 2026)

### FIPS Mode Enforcement

The container enforces FIPS mode through multiple layers:

1. **golang-fips/go Runtime** - FIPS-enabled Go compiler with strict mode
2. **wolfSSL FIPS Module** - All crypto operations use validated module
3. **OpenSSL Provider** - wolfProvider bridges OpenSSL → wolfSSL
4. **Startup Validation** - Automatic FIPS POST and algorithm tests

### Non-FIPS Algorithms Blocked

The following non-FIPS algorithms are blocked:
- ❌ MD5 hashing
- ❌ SHA-1 (blocked at library level)
- ❌ RC4 encryption
- ❌ DES/3DES (deprecated)
- ❌ ChaCha20-Poly1305 (removed from TLS 1.3)

### FIPS-Approved Algorithms

Available FIPS-approved algorithms:
- ✅ AES-128, AES-192, AES-256 (CBC, GCM, CTR)
- ✅ SHA-224, SHA-256, SHA-384, SHA-512
- ✅ HMAC (with SHA-2)
- ✅ RSA (2048, 3072, 4096-bit)
- ✅ ECDSA, ECDH (P-256, P-384, P-521)
- ✅ DRBG (Deterministic Random Bit Generator)

## 🏗️ Architecture

### Image Layers

```
┌─────────────────────────────────────┐
│   redis_exporter v1.67.0           │
│   - Prometheus metrics export       │
│   - Redis connection & monitoring   │
├─────────────────────────────────────┤
│   golang-fips/go v1.25 Runtime     │
│   - FIPS-enabled Go runtime         │
│   - GODEBUG=fips140=only            │
├─────────────────────────────────────┤
│   OpenSSL 3.0.19 + wolfProvider    │
│   - wolfSSL Provider FIPS active    │
├─────────────────────────────────────┤
│   wolfSSL FIPS v5.8.2              │
│   - CMVP Certificate #4718          │
├─────────────────────────────────────┤
│   Ubuntu 22.04 LTS                 │
│   - Long-term support base          │
└─────────────────────────────────────┘
```

### FIPS Cryptographic Stack

```
┌─────────────────────────────────────┐
│      redis_exporter Application     │
│   (Metrics collection, TLS, HTTP)   │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│    golang-fips/go v1.25 Runtime     │
│  (FIPS-enabled with strict mode)    │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│         OpenSSL 3.0.19 API          │
│    (Application-level crypto API)   │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│      wolfProvider v1.1.0            │
│   (OpenSSL 3 → wolfSSL bridge)      │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│    wolfSSL FIPS v5.8.2              │
│  CMVP Certificate #4718             │
│  (FIPS-validated crypto module)     │
└─────────────────────────────────────┘
```

## ⚙️ Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `REDIS_ADDR` | `redis://localhost:6379` | Redis connection string (can be comma-separated list) |
| `REDIS_PASSWORD` | - | Redis authentication password |
| `REDIS_PASSWORD_FILE` | - | Path to file containing Redis password |
| `REDIS_EXPORTER_WEB_LISTEN_ADDRESS` | `:9121` | Metrics endpoint listen address |
| `REDIS_EXPORTER_WEB_TELEMETRY_PATH` | `/metrics` | Metrics endpoint path |
| `REDIS_EXPORTER_LOG_FORMAT` | `txt` | Log format (txt or json) |
| `REDIS_EXPORTER_DEBUG` | `false` | Enable debug logging |
| `FIPS_CHECK` | `true` | Enable/disable FIPS validation on startup |
| `GOLANG_FIPS` | `1` | Enable FIPS mode in Go |
| `GODEBUG` | `fips140=only` | Block non-FIPS algorithms at Go runtime |

### Redis Connection Examples

**Single Redis Instance:**
```bash
docker run -d -p 9121:9121 \
  -e REDIS_ADDR=redis://redis-server:6379 \
  cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips
```

**Multiple Redis Instances:**
```bash
docker run -d -p 9121:9121 \
  -e REDIS_ADDR=redis://redis1:6379,redis://redis2:6379,redis://redis3:6379 \
  cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips
```

**Redis with TLS:**
```bash
docker run -d -p 9121:9121 \
  -e REDIS_ADDR=rediss://redis-server:6380 \
  -e REDIS_EXPORTER_TLS_CLIENT_KEY_FILE=/certs/client.key \
  -e REDIS_EXPORTER_TLS_CLIENT_CERT_FILE=/certs/client.crt \
  -e REDIS_EXPORTER_TLS_CA_CERT_FILE=/certs/ca.crt \
  -v $(pwd)/certs:/certs:ro \
  cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips
```

**Redis Sentinel:**
```bash
docker run -d -p 9121:9121 \
  -e REDIS_ADDR=redis-sentinel://sentinel1:26379,sentinel2:26379,sentinel3:26379?master=mymaster \
  cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips
```

**Redis Cluster:**
```bash
docker run -d -p 9121:9121 \
  -e REDIS_ADDR=redis://cluster-node1:6379,cluster-node2:6379,cluster-node3:6379 \
  cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips
```

### Disable FIPS Validation (Debugging Only)

**⚠️ NOT RECOMMENDED FOR PRODUCTION**

```bash
docker run -d -p 9121:9121 \
  -e FIPS_CHECK=false \
  -e REDIS_ADDR=redis://redis-server:6379 \
  cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips
```

This bypasses FIPS validation checks but **does not disable FIPS mode** - cryptographic operations still use wolfSSL FIPS.

## 🧪 Testing

### Quick Validation Test

```bash
# Run container
docker run -d -p 9121:9121 \
  -e REDIS_ADDR=redis://redis-server:6379 \
  --name redis-exporter-fips \
  cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips

# Wait for startup
sleep 3

# Check FIPS validation passed
docker logs redis-exporter-fips | grep "ALL FIPS CHECKS PASSED"

# Test metrics endpoint
curl -s http://localhost:9121/metrics | grep redis_up

# Cleanup
docker stop redis-exporter-fips && docker rm redis-exporter-fips
```

### Comprehensive Test Suite

```bash
# Run from project root
./diagnostic.sh

# Or run specific tests
./diagnostics/test-exporter-fips-status.sh
./diagnostics/test-exporter-connectivity.sh
./diagnostics/test-exporter-metrics.sh
```

### Manual FIPS Verification

```bash
# Check wolfSSL FIPS status
docker exec redis-exporter-fips /usr/local/bin/fips-check

# Verify wolfProvider loaded
docker exec redis-exporter-fips openssl list -providers

# Test FIPS enforcement (MD5 should fail)
docker exec redis-exporter-fips bash -c 'echo "test" | openssl dgst -md5'
# Expected: Error (FIPS mode blocks MD5)

# Test FIPS-approved algorithm (SHA-256 should work)
docker exec redis-exporter-fips bash -c 'echo "test" | openssl dgst -sha256'
# Expected: SHA256(stdin)= <hash>

# Check Go FIPS environment
docker exec redis-exporter-fips bash -c 'echo $GOLANG_FIPS $GODEBUG'
# Expected: 1 fips140=only
```

## 🔧 Troubleshooting

### FIPS Validation Fails on Startup

**Symptom:** Container exits with "FIPS VALIDATION FAILED"

**Solution:**

```bash
# Check detailed logs
docker logs redis-exporter-fips

# Run FIPS diagnostic
docker run --rm --entrypoint=/usr/local/bin/fips-check \
  cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips

# Bypass validation for debugging (NOT for production)
docker run -e FIPS_CHECK=false -d -p 9121:9121 \
  -e REDIS_ADDR=redis://redis-server:6379 \
  cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips
```

### Cannot Connect to Redis

**Check Redis connectivity:**
```bash
# Test from container
docker exec redis-exporter-fips bash -c 'nc -zv redis-server 6379'

# Check exporter logs
docker logs redis-exporter-fips | grep -i "error\|fail"

# Verify REDIS_ADDR is correct
docker exec redis-exporter-fips env | grep REDIS_ADDR
```

**Common issues:**
1. Redis server not accessible from container network
2. Incorrect REDIS_ADDR format
3. Redis requires authentication (set REDIS_PASSWORD)
4. TLS configuration mismatch

### No Metrics Appear

**Verify metrics endpoint:**
```bash
# Check if exporter is running
docker ps | grep redis-exporter-fips

# Test metrics endpoint locally
docker exec redis-exporter-fips curl -s http://localhost:9121/metrics

# Check if Redis is up
docker exec redis-exporter-fips curl -s http://localhost:9121/metrics | grep redis_up
# Expected: redis_up 1
```

### TLS Connection Issues

**Verify TLS configuration:**

```bash
# Check TLS environment variables
docker exec redis-exporter-fips env | grep TLS

# Test TLS manually
docker exec redis-exporter-fips openssl s_client -connect redis-server:6380

# Check certificate paths
docker exec redis-exporter-fips ls -la /certs/
```

### High Memory Usage

**Check Redis key count:**
```bash
# Large number of keys can increase memory
curl -s http://localhost:9121/metrics | grep redis_db_keys

# Reduce scrape frequency in Prometheus
# Or filter exported metrics
```

### Diagnostic Scripts

```bash
# Run comprehensive diagnostics
./diagnostic.sh

# Run specific tests
./diagnostics/test-exporter-fips-status.sh
./diagnostics/test-exporter-connectivity.sh
./diagnostics/test-exporter-metrics.sh
./diagnostics/test-go-fips-algorithms.sh
```

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [README.md](README.md) | This file - Quick start and overview |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Technical architecture and design decisions |
| [DEVELOPER-GUIDE.md](DEVELOPER-GUIDE.md) | Build, test, and development workflows |
| [ATTESTATION.md](ATTESTATION.md) | FIPS compliance attestation and evidence |
| [POC-VALIDATION-REPORT.md](POC-VALIDATION-REPORT.md) | FIPS POC validation results |
| [examples/](examples/) | Usage examples (Docker Compose, Kubernetes, etc.) |
| [diagnostics/](diagnostics/) | Diagnostic test scripts |

## 📦 Examples

### Docker Compose Example

See [examples/docker-compose/](examples/docker-compose/) for complete monitoring stack:
- Redis server (FIPS)
- redis_exporter (FIPS)
- Prometheus
- Grafana

### Kubernetes Example

See [examples/kubernetes/](examples/kubernetes/) for Kubernetes deployment:
- Deployment manifest
- Service manifest
- ServiceMonitor (Prometheus Operator)
- TLS configuration

### Prometheus Operator Example

See [examples/prometheus-operator/](examples/prometheus-operator/) for:
- ServiceMonitor CRD
- PrometheusRule for alerts
- Grafana dashboard ConfigMap

## 🔐 Security

### Vulnerability Reporting

Report security vulnerabilities to: [security contact email]

### Security Best Practices

1. **Always use TLS** for Redis connections in production
2. **Enable authentication** on Redis (`requirepass`)
3. **Limit network exposure** (use internal networks)
4. **Run as non-root user** (default: `redis-exporter` user, UID 1001)
5. **Keep image updated** (subscribe to security advisories)
6. **Verify FIPS validation** passes on every startup
7. **Use read-only filesystem** where possible
8. **Secure metrics endpoint** (add authentication proxy if exposed)

### SBOM and Compliance

- **SBOM:** See [compliance/SBOM-redis-exporter-1.67.0-jammy-ubuntu-22.04-fips.spdx.json](compliance/SBOM-redis-exporter-1.67.0-jammy-ubuntu-22.04-fips.spdx.json)
- **SLSA Provenance:** See [compliance/slsa-provenance-redis-exporter-1.67.0-jammy-ubuntu-22.04-fips.json](compliance/slsa-provenance-redis-exporter-1.67.0-jammy-ubuntu-22.04-fips.json)
- **VEX:** See [compliance/vex-redis-exporter-1.67.0-jammy-ubuntu-22.04-fips.json](compliance/vex-redis-exporter-1.67.0-jammy-ubuntu-22.04-fips.json)

## 🎓 Additional Resources

- **redis_exporter Documentation:** https://github.com/oliver006/redis_exporter
- **Prometheus Documentation:** https://prometheus.io/docs/
- **wolfSSL FIPS:** https://www.wolfssl.com/products/wolfssl-fips/
- **NIST CMVP:** https://csrc.nist.gov/projects/cryptographic-module-validation-program
- **FIPS 140-3:** https://csrc.nist.gov/publications/detail/fips/140/3/final
- **golang-fips/go:** https://github.com/golang-fips/go

## 📄 License

- **redis_exporter:** MIT License
- **wolfSSL FIPS:** Commercial license required (included in this build)
- **OpenSSL:** Apache 2.0 License
- **golang-fips/go:** BSD-style (Go License)
- **Ubuntu:** Canonical License

## 🙏 Acknowledgments

- oliver006 for redis_exporter
- wolfSSL Inc. for wolfSSL FIPS module and wolfProvider
- golang-fips/go project for FIPS-enabled Go
- OpenSSL Project for OpenSSL
- Canonical for Ubuntu

---

**Built with ❤️ for FIPS 140-3 compliance**

*Last updated: March 27, 2026*
*Image version: 1.67.0-jammy-ubuntu-22.04-fips*
