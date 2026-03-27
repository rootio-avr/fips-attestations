# Redis FIPS Demo Image

Interactive demonstration image showcasing Redis 7.2.4 with wolfSSL FIPS 140-3 in real-world scenarios.

## Overview

This demo image extends `cr.root.io/redis:7.2.4-alpine-fips` with five production-ready configuration examples:

1. **Persistence Demo** - RDB snapshots + AOF for data durability
2. **Pub/Sub Demo** - Real-time messaging with publisher/subscriber
3. **Memory Optimization** - Memory limits and eviction policies
4. **Strict FIPS** - Maximum security enforcement with command restrictions
5. **TLS Demo** - Encrypted connections with TLS/SSL

## Building the Image

```bash
./build.sh
```

This creates the `redis-fips-demos:latest` image with all demo configurations pre-installed.

**Prerequisites:**
- Base image must exist: `cr.root.io/redis:7.2.4-alpine-fips`
- Build base image first if needed: `cd .. && ./build.sh`

## Demo Configurations

### 1. Persistence Demo (Default)

**Configuration:** `configs/persistence-demo.conf`

Demonstrates Redis data durability with both RDB snapshots and AOF persistence.

**Features:**
- RDB snapshots at multiple intervals (15min/5min/1min)
- AOF enabled with everysec fsync
- Data integrity with checksums
- FIPS-approved cryptographic operations

**Run:**
```bash
docker run -d -p 6379:6379 --name redis-persistence \
  -v $(pwd)/configs/persistence-demo.conf:/etc/redis/redis.conf:ro \
  redis-fips-demos:latest redis-server /etc/redis/redis.conf
```

**Test:**
```bash
# Write test data
docker exec redis-persistence redis-cli SET mykey "myvalue"

# Trigger background save
docker exec redis-persistence redis-cli BGSAVE

# Check persistence info
docker exec redis-persistence redis-cli INFO persistence

# Run persistence test script
docker exec redis-persistence /opt/demos/scripts/persistence-test.sh
```

### 2. Pub/Sub Demo

**Configuration:** `configs/pubsub-demo.conf`

Demonstrates Redis publish/subscribe messaging for real-time communication.

**Features:**
- High-performance pub/sub messaging
- Increased client output buffers for pub/sub
- Pattern-based subscriptions
- FIPS-compliant message transport

**Run:**
```bash
docker run -d -p 6379:6379 --name redis-pubsub \
  -v $(pwd)/configs/pubsub-demo.conf:/etc/redis/redis.conf:ro \
  redis-fips-demos:latest redis-server /etc/redis/redis.conf
```

**Test:**
```bash
# Terminal 1: Start subscriber
docker exec -it redis-pubsub /opt/demos/scripts/pubsub-subscriber.sh

# Terminal 2: Publish messages
docker exec redis-pubsub /opt/demos/scripts/pubsub-publisher.sh

# Or manually
docker exec redis-pubsub redis-cli PUBLISH demo-channel "Hello FIPS!"
```

**Customization:**
```bash
# Publish 20 messages with 2-second delay
docker exec -e MESSAGE_COUNT=20 -e DELAY=2 redis-pubsub \
  /opt/demos/scripts/pubsub-publisher.sh

# Subscribe to custom channel
docker exec -e CHANNEL=my-channel redis-pubsub \
  /opt/demos/scripts/pubsub-subscriber.sh
```

### 3. Memory Optimization Demo

**Configuration:** `configs/memory-optimization.conf`

Demonstrates Redis memory management and eviction policies.

**Features:**
- maxmemory limit (128MB for demo)
- LFU eviction policy (allkeys-lfu)
- Lazy freeing for large deletions
- Memory-efficient data structures
- Detailed memory statistics

**Run:**
```bash
docker run -d -p 6379:6379 --name redis-memory \
  -v $(pwd)/configs/memory-optimization.conf:/etc/redis/redis.conf:ro \
  redis-fips-demos:latest redis-server /etc/redis/redis.conf
```

**Test:**
```bash
# Check memory info
docker exec redis-memory redis-cli INFO memory

# Run memory test (populates with 1000 keys)
docker exec redis-memory /opt/demos/scripts/memory-test.sh

# Custom key count
docker exec -e KEY_COUNT=5000 redis-memory \
  /opt/demos/scripts/memory-test.sh

# Monitor evictions
docker exec redis-memory redis-cli INFO stats | grep evicted_keys
```

**Memory Commands:**
```bash
# Detailed memory stats
docker exec redis-memory redis-cli MEMORY STATS

# Memory usage by key
docker exec redis-memory redis-cli MEMORY USAGE mykey

# Memory doctor
docker exec redis-memory redis-cli MEMORY DOCTOR
```

### 4. Strict FIPS Demo

**Configuration:** `configs/strict-fips.conf`

Maximum FIPS security enforcement with strict settings.

**Features:**
- TLS-only connections (plain TCP disabled)*
- Password authentication required
- Dangerous commands disabled (FLUSHDB, FLUSHALL, KEYS)
- Command renaming for security
- AOF with `appendfsync always` for maximum durability
- Strict logging and audit

*Note: For demo purposes, TLS can be disabled if certificates are not available*

**Run:**
```bash
docker run -d -p 6379:6379 --name redis-strict \
  -v $(pwd)/configs/strict-fips.conf:/etc/redis/redis.conf:ro \
  redis-fips-demos:latest \
  redis-server /etc/redis/redis.conf --port 6379 --tls-port 0 \
  --requirepass your_secure_password
```

**Test:**
```bash
# Connect with password
docker exec redis-strict redis-cli -a your_secure_password PING

# Try disabled command (should fail)
docker exec redis-strict redis-cli -a your_secure_password FLUSHALL
# Response: (error) ERR unknown command

# Try renamed command
docker exec redis-strict redis-cli -a your_secure_password CONFIG_ADMIN_ONLY GET maxmemory
```

**Production Setup:**
Update password in config or use environment:
```bash
docker run -d -p 6379:6379 \
  -e REDIS_PASSWORD=YourStrongPassword123 \
  -v $(pwd)/configs/strict-fips.conf:/etc/redis/redis.conf:ro \
  redis-fips-demos:latest
```

### 5. TLS Demo

**Configuration:** `configs/tls-demo.conf`

Demonstrates encrypted Redis connections with TLS/SSL.

**Features:**
- Dual ports: 6379 (plain) + 6380 (TLS)
- TLS 1.2 and TLS 1.3 support
- FIPS-approved cipher suites
- Optional client certificate authentication
- TLS replication support

**Run:**
```bash
# Note: Requires TLS certificates mounted
docker run -d -p 6379:6379 -p 6380:6380 --name redis-tls \
  -v $(pwd)/configs/tls-demo.conf:/etc/redis/redis.conf:ro \
  -v /path/to/certs:/etc/redis/tls:ro \
  redis-fips-demos:latest redis-server /etc/redis/redis.conf
```

**Test TLS Connection:**
```bash
# Plain connection (port 6379)
docker exec redis-tls redis-cli -p 6379 PING

# TLS connection (port 6380) - requires certs
docker exec redis-tls redis-cli -p 6380 --tls \
  --cert /etc/redis/tls/redis.crt \
  --key /etc/redis/tls/redis.key \
  --cacert /etc/redis/tls/ca.crt \
  PING
```

**Generate Self-Signed Certificates:**
See `../examples/tls-setup/generate-certs.sh` for certificate generation.

## Configuration Comparison

| Feature | Persistence | Pub/Sub | Memory | Strict FIPS | TLS |
|---------|------------|---------|--------|-------------|-----|
| **RDB Snapshots** | Yes | No | Limited | Yes | Yes |
| **AOF Persistence** | Yes | No | No | Yes (always) | Yes |
| **Memory Limit** | 256MB | 256MB | 128MB | 256MB | 256MB |
| **Eviction Policy** | noeviction | noeviction | allkeys-lfu | noeviction | allkeys-lru |
| **Password** | Optional | Optional | Optional | Required | Optional |
| **TLS** | No | No | No | Yes* | Yes |
| **Command Restrictions** | No | No | No | Yes | No |
| **Use Case** | Data storage | Messaging | Limited memory | High security | Secure comms |

## Using Demo Scripts

### Pub/Sub Scripts

**Publisher:**
```bash
# Default: 10 messages, 1-second delay
docker exec redis-pubsub /opt/demos/scripts/pubsub-publisher.sh

# Custom settings
docker exec -e MESSAGE_COUNT=50 -e DELAY=0.5 -e CHANNEL=my-channel \
  redis-pubsub /opt/demos/scripts/pubsub-publisher.sh
```

**Subscriber:**
```bash
# Subscribe to demo-channel
docker exec -it redis-pubsub /opt/demos/scripts/pubsub-subscriber.sh

# Custom channel
docker exec -it -e CHANNEL=my-channel redis-pubsub \
  /opt/demos/scripts/pubsub-subscriber.sh
```

### Persistence Test

```bash
# Run full persistence test
docker exec redis-persistence /opt/demos/scripts/persistence-test.sh

# Output:
# [1/5] Writing test data...
# [2/5] Triggering background save (BGSAVE)...
# [3/5] Checking RDB persistence info...
# [4/5] Checking AOF status...
# [5/5] Verifying persisted data...
```

### Memory Test

```bash
# Default: 1000 keys
docker exec redis-memory /opt/demos/scripts/memory-test.sh

# Custom key count
docker exec -e KEY_COUNT=10000 redis-memory \
  /opt/demos/scripts/memory-test.sh

# Output includes:
# - Current memory statistics
# - Memory limit configuration
# - Population progress
# - Eviction statistics
```

## Verifying FIPS Compliance

All demos use the same FIPS-validated wolfSSL cryptographic module. Verify:

```bash
# Check wolfProvider is loaded
docker exec redis-demo openssl list -providers

# Output should include:
#   name: wolfSSL Provider FIPS
#   version: 1.1.0

# Verify FIPS POST
docker exec redis-demo fips-startup-check

# Check Redis uses SHA-256 (not SHA-1)
# Lua scripts now use SHA-256 for FIPS compliance
docker exec redis-demo redis-cli SCRIPT LOAD "return 'Hello FIPS'" | wc -c
# Should return 64 (SHA-256) not 40 (SHA-1)
```

## Interactive Testing

Run the interactive test suite:

```bash
./test-demos.sh
```

This presents a menu to test each configuration:

```
===============================================================================
Redis FIPS Demo Configuration Tester
===============================================================================

Available Demo Configurations:

  1) Persistence Demo       - RDB + AOF data durability
  2) Pub/Sub Demo           - Real-time messaging
  3) Memory Optimization    - Memory limits and eviction
  4) Strict FIPS            - Maximum security enforcement
  5) TLS Demo               - Encrypted connections

  6) Test ALL               - Run all tests sequentially
  7) Cleanup & Exit         - Stop containers and exit

Select an option (1-7):
```

**Command-Line Testing:**
```bash
# Test specific configuration
./test-demos.sh persistence-demo
./test-demos.sh pubsub-demo
./test-demos.sh memory-optimization
./test-demos.sh strict-fips
./test-demos.sh tls-demo

# Test all configurations
./test-demos.sh all
```

## Accessing Demo Logs

```bash
# View logs
docker logs redis-demo

# Follow logs
docker logs -f redis-demo

# Redis internal logs (if configured)
docker exec redis-demo cat /var/log/redis/redis.log

# Monitor commands in real-time
docker exec redis-demo redis-cli MONITOR
```

## Troubleshooting

### Port Already in Use

```bash
# Find what's using port 6379
sudo lsof -i :6379

# Use different port
docker run -d -p 6380:6379 redis-fips-demos:latest

# Connect to different port
redis-cli -p 6380 PING
```

### Configuration Test Failed

```bash
# Test config before running
docker run --rm \
  -v $(pwd)/configs/persistence-demo.conf:/etc/redis/redis.conf:ro \
  redis-fips-demos:latest \
  redis-server /etc/redis/redis.conf --test-memory
```

### Permission Denied (Data Directory)

```bash
# Create volume with correct permissions
docker volume create redis-data

# Run with volume
docker run -d -p 6379:6379 \
  -v redis-data:/data \
  redis-fips-demos:latest
```

### Memory Issues

```bash
# Check current memory usage
docker exec redis-demo redis-cli INFO memory | grep used_memory_human

# Adjust maxmemory
docker exec redis-demo redis-cli CONFIG SET maxmemory 512mb

# Check eviction policy
docker exec redis-demo redis-cli CONFIG GET maxmemory-policy
```

### FIPS Validation Errors

```bash
# Check FIPS POST
docker exec redis-demo fips-startup-check

# Verify wolfProvider
docker exec redis-demo openssl list -providers

# Test FIPS algorithm (should work)
docker exec redis-demo openssl dgst -sha256 /etc/redis/redis.conf

# Test non-FIPS algorithm (should fail)
docker exec redis-demo openssl dgst -md5 /etc/redis/redis.conf
# Should return: error or disabled
```

## Customizing Configurations

### Create Your Own Demo

1. Create custom configuration:
```bash
cp configs/persistence-demo.conf configs/my-custom.conf
# Edit my-custom.conf
```

2. Run with custom config:
```bash
docker run -d -p 6379:6379 \
  -v $(pwd)/configs/my-custom.conf:/etc/redis/redis.conf:ro \
  redis-fips-demos:latest redis-server /etc/redis/redis.conf
```

### Required FIPS Settings

All custom configurations must include FIPS-compliant settings:

```conf
# Redis is patched to use SHA-256 instead of SHA-1
# No additional configuration needed for Lua scripts

# For TLS (if using):
tls-protocols "TLSv1.2 TLSv1.3"
tls-ciphers "ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256"
tls-ciphersuites "TLS_AES_256_GCM_SHA384:TLS_AES_128_GCM_SHA256"
tls-prefer-server-ciphers yes
```

## Integration with CI/CD

### Quick Health Check

```bash
# Start demo
docker run -d -p 6379:6379 --name redis-test \
  redis-fips-demos:latest redis-server

# Wait for startup
sleep 3

# Health check
if docker exec redis-test redis-cli PING | grep -q "PONG"; then
    echo "✓ Demo healthy"
else
    echo "✗ Demo failed"
    exit 1
fi

# FIPS validation
if docker exec redis-test fips-startup-check; then
    echo "✓ FIPS validated"
else
    echo "✗ FIPS validation failed"
    exit 1
fi

# Cleanup
docker stop redis-test && docker rm redis-test
```

### FIPS Validation in Pipeline

```bash
# Verify FIPS provider is active
docker run --rm redis-fips-demos:latest openssl list -providers | grep -q "wolfSSL Provider FIPS"
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "✓ FIPS provider active"
else
    echo "✗ FIPS provider not found"
    exit 1
fi
```

## Performance Considerations

- **Persistence**: RDB is faster than AOF but less durable
- **AOF fsync**: `everysec` is balanced, `always` is slowest but safest
- **Memory Eviction**: LRU is faster than LFU but less accurate
- **Pub/Sub**: Very low latency, no persistence overhead
- **TLS**: Adds CPU overhead but provides encryption

**Benchmark Commands:**
```bash
# Basic benchmark
docker exec redis-demo redis-cli --latency

# Full benchmark
docker exec redis-demo redis-cli --intrinsic-latency 60
```

## Security Best Practices

1. **Use passwords** in production (requirepass directive)
2. **Enable TLS** for network security
3. **Disable dangerous commands** (FLUSHALL, KEYS, CONFIG)
4. **Rename sensitive commands** for additional security
5. **Bind to specific interfaces** (not 0.0.0.0 in production)
6. **Use ACLs** for multi-user environments (Redis 6+)
7. **Enable AOF** for critical data
8. **Monitor logs** for suspicious activity
9. **Keep updated** to get latest security patches
10. **Verify FIPS compliance** regularly

## See Also

- [Base Image Documentation](../README.md)
- [Diagnostic Test Suite](../diagnostics/test-images/basic-test-image/README.md)
- [Full Diagnostics](../diagnostic.sh)
- [TLS Setup Guide](../examples/tls-setup/README.md)
- [Kubernetes Deployment](../examples/kubernetes/README.md)

## Version Information

- **Redis**: 7.2.4 (patched for SHA-256)
- **wolfSSL FIPS**: 5.8.2 (Certificate #4718)
- **OpenSSL**: 3.3.0
- **wolfProvider**: 1.1.0
- **Base**: Alpine Linux 3.19
- **Image**: cr.root.io/redis:7.2.4-alpine-fips

## Support

For issues or questions:
1. Check troubleshooting section above
2. Review base image README
3. Run full diagnostics: `../diagnostic.sh`
4. Examine Redis logs: `docker logs <container>`
5. Test FIPS compliance: `docker exec <container> fips-startup-check`

## License

Redis is licensed under the BSD-3-Clause license.
wolfSSL FIPS module is commercial software - ensure proper licensing.
