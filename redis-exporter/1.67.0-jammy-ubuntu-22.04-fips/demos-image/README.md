# Redis Exporter FIPS - Interactive Demo

This directory contains an interactive demonstration of the redis_exporter FIPS image, showcasing its capabilities and FIPS compliance features using Docker Compose.

## Contents

```
demos-image/
├── docker-compose.yml              # Full monitoring stack orchestration
├── Dockerfile                      # Demo container image definition
├── build.sh                        # Demo image build script
├── README.md                       # This file
├── configs/                        # Configuration files
│   ├── redis.conf                  # Redis server config
│   ├── redis-sentinel.conf         # Sentinel config
│   ├── redis-cluster-*.conf        # Cluster node configs
│   ├── prometheus.yml              # Prometheus scrape config
│   └── grafana-dashboard.json      # Grafana dashboard
├── scripts/                        # Demo scripts
│   ├── setup-tls.sh                # TLS certificate generation
│   ├── populate-test-data.sh       # Redis test data
│   ├── run-demo.sh                 # Main demo runner
│   ├── test-metrics.sh             # Metrics validation
│   └── test-fips-enforcement.sh    # FIPS enforcement tests
└── html/                           # Demo web dashboard
    └── index.html                  # Interactive dashboard
```

## Quick Start

### Option 1: Docker Compose (Recommended)

Use Docker Compose for a complete monitoring stack with Redis, Exporter, Prometheus, and Grafana:

#### Start the Full Monitoring Stack

Redis, Exporter, Prometheus, and Grafana:

```bash
# Start the stack
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f redis-exporter

# Stop the stack
docker-compose down
```

#### Access Endpoints

Once the stack is running:

- **Prometheus:** http://localhost:9090
- **Grafana:** http://localhost:3000 (admin/admin)
- **Redis Exporter Metrics:** http://localhost:9121/metrics
- **Redis:** localhost:6379

#### Validate Metrics

Once the stack is running, validate the metrics:

```bash
# Run metrics validation test (from host machine)
bash scripts/test-metrics.sh

# Expected output: 23/23 tests passed
```

**Note:** The `test-metrics.sh` script requires `curl` and must be run from your host machine (not in a container). See the [test-metrics.sh](#test-metricssh) section for details.

### Option 2: Build Demo Container

Build a standalone demo container with demo files and FIPS validation:

```bash
# Build the demo image
./build.sh

# Run FIPS validation tests (default, runs standalone)
docker run --rm redis-exporter-demos:1.67.0-jammy-ubuntu-22.04-fips

# Generate TLS certificates (auto-fixes permissions)
docker run --rm -v $(pwd)/certs:/demo/certs redis-exporter-demos:1.67.0-jammy-ubuntu-22.04-fips /demo/scripts/setup-tls.sh

# Interactive shell access
docker run --rm -it redis-exporter-demos:1.67.0-jammy-ubuntu-22.04-fips /bin/bash
```

**Note:** The standalone container runs FIPS validation tests by default. For the full interactive demo with Redis, use docker-compose (Option 1 above).

**Build Options:**
```bash
# Custom image name and tag
./build.sh -n my-demos -t v1.0

# Verbose build output
./build.sh -v

# Build without cache
./build.sh -c

# Help
./build.sh -h
```

**Note:** The base redis-exporter FIPS image must be built first. See `../build.sh`.

## Demonstration Scenarios

### Scenario 1: Basic Metrics Export

Demonstrates basic redis_exporter functionality:

```bash
# Start Redis + Exporter
docker-compose up -d redis redis-exporter

# Populate test data
docker-compose exec redis-exporter /demo/scripts/populate-test-data.sh

# View metrics
curl http://localhost:9121/metrics | grep redis_
```

**Expected Metrics:**
- `redis_up` - Redis server availability
- `redis_commands_total` - Command counts
- `redis_connected_clients` - Client connections
- `redis_memory_used_bytes` - Memory usage
- `redis_db_keys` - Keys per database

### Scenario 2: FIPS Validation

Demonstrates FIPS 140-3 compliance:

```bash
# Run FIPS enforcement tests
docker-compose exec redis-exporter /demo/scripts/test-fips-enforcement.sh
```

**Tests Include:**
1. wolfSSL FIPS POST execution
2. wolfProvider registration
3. Environment variable checks (GOLANG_FIPS, GODEBUG)
4. Approved algorithm availability (SHA-256, AES-256)
5. Non-approved algorithm blocking (MD5, SHA-1)
6. TLS cipher suite restrictions

### Scenario 3: TLS/SSL Connections

Demonstrates FIPS-compliant TLS connections:

```bash
# Generate TLS certificates
docker-compose exec redis-exporter /demo/scripts/setup-tls.sh

# Restart with TLS configuration
# (Edit docker-compose.yml to enable TLS, then restart)
docker-compose restart redis redis-exporter
```

**FIPS-Approved Ciphers:**
- TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
- TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
- TLS_RSA_WITH_AES_256_GCM_SHA384
- TLS_RSA_WITH_AES_128_GCM_SHA256

### Scenario 4: Redis Sentinel Monitoring

Demonstrates Sentinel topology monitoring:

```bash
# Start Sentinel setup
docker-compose --profile sentinel up -d

# View Sentinel metrics
curl http://localhost:9122/metrics | grep sentinel
```

**Sentinel Metrics:**
- `redis_sentinel_masters` - Number of masters
- `redis_sentinel_slaves` - Replicas per master
- `redis_sentinel_sentinels` - Active sentinels
- `redis_sentinel_master_status` - Master health

### Scenario 5: Redis Cluster Monitoring

Demonstrates Cluster topology monitoring:

```bash
# Start Cluster setup
docker-compose --profile cluster up -d

# View Cluster metrics
curl http://localhost:9123/metrics | grep cluster
```

**Cluster Metrics:**
- `redis_cluster_state` - Cluster health
- `redis_cluster_slots_assigned` - Slot distribution
- `redis_cluster_known_nodes` - Node count
- `redis_cluster_size` - Number of masters

### Scenario 6: Prometheus Integration

Demonstrates Prometheus scraping and alerting:

```bash
# Start full stack
docker-compose --profile monitoring up -d

# Access Prometheus
open http://localhost:9090

# Query metrics (in Prometheus UI)
# Expression: redis_up
# Expression: rate(redis_commands_total[5m])
```

**Prometheus Queries:**
```promql
# Redis availability
redis_up == 1

# Commands per second
rate(redis_commands_total[5m])

# Memory usage percentage
redis_memory_used_bytes / redis_memory_max_bytes * 100

# Connected clients
redis_connected_clients
```

### Scenario 7: Performance Testing

Demonstrates exporter performance under load:

```bash
# Generate load
docker-compose exec redis-exporter /demo/scripts/populate-test-data.sh --load

# Monitor scrape duration
curl http://localhost:9121/metrics | grep scrape_duration
```

**Performance Metrics:**
- Scrape duration: < 1s for most setups
- Memory overhead: ~50MB baseline
- CPU usage: < 5% during scrapes

## Demo Scripts

### setup-tls.sh

Generates FIPS-compliant TLS certificates:

```bash
docker-compose exec redis-exporter /demo/scripts/setup-tls.sh

# Output:
# ✓ CA certificate generated (RSA 4096)
# ✓ Server certificate generated (RSA 2048)
# ✓ Client certificate generated (RSA 2048)
# ✓ Certificates signed with SHA-256
```

### populate-test-data.sh

Populates Redis with test data:

```bash
docker-compose exec redis-exporter /demo/scripts/populate-test-data.sh

# Options:
# --small   1K keys (default)
# --medium  10K keys
# --large   100K keys
# --load    Continuous load generation
```

### test-metrics.sh

Validates exported metrics from a running redis-exporter instance.

**Requirements:**
- docker-compose stack must be running
- `curl` must be available (run from host machine)

**Usage:**

```bash
# 1. Start the docker-compose stack
docker-compose up -d

# 2. Wait for services to start
sleep 10

# 3. Run test from HOST machine (has curl)
bash scripts/test-metrics.sh

# 4. Optional: Clean up
docker-compose down
```

**Note:** This script requires `curl` which is not available in the demo container due to FIPS libssl3 conflicts. Run the script directly from your host machine.

**Tests Performed:**
- ✓ HTTP endpoint availability (HTTP 200)
- ✓ Prometheus text format compliance
- ✓ Core metrics presence (redis_up, redis_connected_clients, etc.)
- ✓ Metric value sanity (no NaN, valid ranges)
- ✓ Label correctness

**Example Output:**
```
Total Tests:  23
Passed:       23
Failed:       0
✓ ALL TESTS PASSED
```

### test-fips-enforcement.sh

Validates FIPS enforcement:

```bash
docker-compose exec redis-exporter /demo/scripts/test-fips-enforcement.sh

# Tests:
# ✓ FIPS POST passes
# ✓ Environment variables set
# ✓ wolfProvider loaded
# ✓ SHA-256 available
# ✓ MD5 blocked
# ✓ TLS ciphers restricted
```

## Docker Compose Profiles

The docker-compose.yml supports multiple profiles:

### Default Profile
Basic Redis + Exporter:
```bash
docker-compose up
```

### Sentinel Profile
Redis Sentinel topology:
```bash
docker-compose --profile sentinel up
```

### Cluster Profile
Redis Cluster topology:
```bash
docker-compose --profile cluster up
```

### Monitoring Profile
Full stack with Prometheus + Grafana:
```bash
docker-compose --profile monitoring up
```

## Configuration Files

### redis.conf

Standard Redis configuration with FIPS considerations:

```ini
# Disable non-FIPS commands
rename-command FLUSHDB ""
rename-command FLUSHALL ""

# TLS configuration
tls-port 6380
tls-cert-file /demo/certs/redis.crt
tls-key-file /demo/certs/redis.key
tls-ca-cert-file /demo/certs/ca.crt

# Only allow FIPS ciphers
tls-ciphersuites TLS_AES_256_GCM_SHA384:TLS_AES_128_GCM_SHA256
```

### prometheus.yml

Prometheus scrape configuration:

```yaml
scrape_configs:
  - job_name: 'redis-exporter'
    static_configs:
      - targets: ['redis-exporter:9121']
    scrape_interval: 15s
    scrape_timeout: 10s
```

## Troubleshooting

### Issue: Metrics endpoint returns 404

**Cause:** Exporter not started or wrong path

**Solution:**
```bash
# Check exporter logs
docker-compose logs redis-exporter

# Verify path
curl http://localhost:9121/
```

### Issue: Redis connection refused

**Cause:** Redis not started or wrong address

**Solution:**
```bash
# Check Redis logs
docker-compose logs redis

# Test connection
docker-compose exec redis redis-cli ping
```

### Issue: FIPS POST fails

**Cause:** FIPS module not loaded or environment misconfigured

**Solution:**
```bash
# Check environment
docker-compose exec redis-exporter env | grep -E 'GOLANG_FIPS|GODEBUG'

# Run manual POST
docker-compose exec redis-exporter /usr/local/bin/fips-check
```

### Issue: TLS handshake fails

**Cause:** Non-FIPS cipher suites or invalid certificates

**Solution:**
```bash
# Regenerate certificates
docker-compose exec redis-exporter /demo/scripts/setup-tls.sh

# Test with FIPS cipher
openssl s_client -connect localhost:6380 \
  -tls1_2 -cipher 'ECDHE-RSA-AES256-GCM-SHA384'
```

## Performance Benchmarks

Typical performance metrics for the demo setup:

| Metric | Value |
|--------|-------|
| Scrape Duration | 200-500ms |
| Memory Usage | 50-80MB |
| CPU Usage | 2-5% |
| Concurrent Clients | 100+ |
| Metrics per Scrape | 150-200 |

## Security Considerations

### FIPS Compliance
- All cryptographic operations use FIPS 140-3 validated modules
- Non-approved algorithms are blocked at runtime
- TLS connections use only approved cipher suites

### Credential Management
- Default passwords are for demo only
- Use secrets management in production
- Rotate credentials regularly

### Network Security
- Bind to localhost in production
- Use TLS for all connections
- Implement firewall rules

## Next Steps

After exploring the demo:

1. **Review ARCHITECTURE.md** for technical details
2. **Read DEVELOPER-GUIDE.md** for build instructions
3. **See examples/** for production configurations
4. **Check ATTESTATION.md** for compliance documentation

## Support

For issues or questions:

- Documentation: `../README.md`
- Examples: `../examples/`
- Compliance: `../compliance/`

## License

See LICENSE file in repository root.

---

**Demo Version:** 1.67.0-jammy-ubuntu-22.04-fips
**Last Updated:** 2026-03-27
**Maintainer:** Root FIPS Team
