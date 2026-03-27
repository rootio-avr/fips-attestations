# Redis FIPS Deployment Examples

This directory contains production-ready deployment examples for Redis 7.2.4 Alpine FIPS image.

## Available Examples

### 1. Docker Compose (`docker-compose/`)

Basic Docker Compose deployment with:
- Production Redis configuration
- Persistent data volumes
- Health checks and resource limits
- Security best practices

**Quick Start:**
```bash
cd docker-compose/
sed -i 's/changeme_strong_password_here/YOUR_STRONG_PASSWORD/' redis.conf
docker-compose up -d
```

[Full Documentation](docker-compose/README.md)

### 2. Kubernetes (`kubernetes/`)

Production Kubernetes deployment with:
- StatefulSet for stable storage
- ConfigMap and Secret management
- Health probes (startup, liveness, readiness)
- Resource limits and security policies
- Persistent volume claims

**Quick Start:**
```bash
cd kubernetes/
kubectl create secret generic redis-fips-secret --from-literal=password='YOUR_PASSWORD'
# Edit deployment.yaml to update ConfigMap password
kubectl apply -f deployment.yaml
```

[Full Documentation](kubernetes/README.md)

### 3. TLS/SSL Setup (`tls-setup/`)

Secure TLS deployment with:
- FIPS-compliant certificate generation
- Mutual TLS (mTLS) configuration
- TLS 1.2/1.3 with approved cipher suites
- Client connection examples (Python, Node.js, Java, Go)

**Quick Start:**
```bash
cd tls-setup/
./generate-certs.sh
sed -i 's/changeme_strong_password_here/YOUR_PASSWORD/' redis-tls.conf
docker-compose -f docker-compose-tls.yml up -d
```

[Full Documentation](tls-setup/README.md)

## Choosing the Right Deployment

| Deployment Type | Use Case | Complexity | HA Support |
|----------------|----------|------------|------------|
| **Docker Compose** | Development, small production | Low | No |
| **Kubernetes** | Large-scale production | Medium | Yes* |
| **TLS Setup** | Security-critical environments | Medium | Yes* |

\* Requires additional configuration for Redis Sentinel or Cluster mode

## Common Configuration

All examples support these key features:

### FIPS Compliance
- wolfSSL FIPS v5.8.2 (CMVP Certificate #4718)
- FIPS POST validation on startup
- Only FIPS-approved cryptographic algorithms

### Security
- Strong password authentication
- Non-root container execution (UID/GID 1000)
- Read-only configuration mounts
- Security options (no-new-privileges)

### Persistence
- RDB snapshots (configurable intervals)
- AOF (Append-Only File) for durability
- Persistent volume management

### Monitoring
- Health checks (PING command)
- Redis INFO metrics
- Optional Prometheus integration

## Configuration Overview

### Password Configuration

All examples use password authentication. Update passwords in:

**Docker Compose:**
```bash
sed -i 's/changeme_strong_password_here/YOUR_PASSWORD/' redis.conf
```

**Kubernetes:**
```bash
kubectl create secret generic redis-fips-secret --from-literal=password='YOUR_PASSWORD'
# Also update ConfigMap in deployment.yaml
```

**TLS Setup:**
```bash
sed -i 's/changeme_strong_password_here/YOUR_PASSWORD/' redis-tls.conf
```

### Resource Limits

Default resource allocation:

```yaml
requests:
  cpu: 500m-1000m
  memory: 512Mi
limits:
  cpu: 2000m
  memory: 2Gi
```

Adjust based on your workload requirements.

### Persistence Settings

Default persistence strategy:

**RDB (Snapshots):**
- Save after 900s if 1+ keys changed
- Save after 300s if 10+ keys changed
- Save after 60s if 10000+ keys changed

**AOF (Append-Only File):**
- Enabled by default
- fsync every second (appendfsync everysec)
- Auto-rewrite at 100% growth, min 64MB

### Network Configuration

**Default Ports:**
- Plain Redis: 6379
- TLS Redis: 6379 (plain disabled)

**Bind Address:**
- Docker Compose: 0.0.0.0 (inside container)
- Kubernetes: 0.0.0.0 (ClusterIP restricts access)
- TLS: 0.0.0.0 with client certificate verification

## Testing Your Deployment

### Basic Connectivity Test

**Docker Compose:**
```bash
docker-compose exec redis-fips redis-cli -a YOUR_PASSWORD PING
```

**Kubernetes:**
```bash
kubectl exec redis-fips-0 -- redis-cli -a YOUR_PASSWORD PING
```

**TLS:**
```bash
docker exec redis-fips-tls redis-cli --tls \
  --cert /certs/redis-cert.pem \
  --key /certs/redis-key.pem \
  --cacert /certs/ca-cert.pem \
  -a YOUR_PASSWORD PING
```

### FIPS Validation

```bash
# Docker Compose
docker-compose exec redis-fips fips-startup-check

# Kubernetes
kubectl exec redis-fips-0 -- fips-startup-check

# TLS
docker exec redis-fips-tls fips-startup-check
```

### Performance Test

```bash
# Simple benchmark
redis-cli -a YOUR_PASSWORD --csv --latency

# redis-benchmark (1M requests)
redis-benchmark -a YOUR_PASSWORD -t set,get -n 1000000 -q

# TLS benchmark
redis-benchmark --tls \
  --cert /path/to/redis-cert.pem \
  --key /path/to/redis-key.pem \
  --cacert /path/to/ca-cert.pem \
  -a YOUR_PASSWORD \
  -t set,get -n 100000 -q
```

## Migration from Non-FIPS Redis

### Important Considerations

1. **Lua Script Compatibility**
   - Redis FIPS uses SHA-256 for script hashing (instead of SHA-1)
   - Script IDs will be different
   - Applications using `SCRIPT LOAD` must reload scripts

2. **Data Migration**
   ```bash
   # Export from source
   redis-cli -h source-redis SAVE
   scp source:/var/lib/redis/dump.rdb ./

   # Import to FIPS Redis
   docker cp dump.rdb redis-fips:/data/
   docker restart redis-fips
   ```

3. **Configuration Migration**
   - Review all `redis.conf` settings
   - Test in staging environment first
   - Plan maintenance window for production

### Migration Steps

1. **Preparation**
   - Deploy Redis FIPS in staging
   - Test application compatibility
   - Verify Lua script behavior

2. **Data Export**
   ```bash
   # Trigger save on source
   redis-cli -h source-redis BGSAVE
   redis-cli -h source-redis BGREWRITEAOF
   ```

3. **Deploy Redis FIPS**
   - Choose deployment method
   - Configure passwords and persistence
   - Validate FIPS compliance

4. **Data Import**
   - Copy RDB/AOF files
   - Start Redis FIPS
   - Verify data integrity

5. **Application Cutover**
   - Update connection strings
   - Monitor application logs
   - Verify Lua scripts work

6. **Validation**
   - Run diagnostic scripts
   - Perform load testing
   - Monitor performance metrics

## Backup and Disaster Recovery

### Backup Strategy

**RDB Snapshots:**
```bash
# Trigger background save
redis-cli -a PASSWORD BGSAVE

# Copy RDB file
docker cp redis-fips:/data/dump.rdb ./backup/dump-$(date +%Y%m%d).rdb
```

**AOF Backup:**
```bash
# Copy AOF file
docker cp redis-fips:/data/appendonly.aof ./backup/aof-$(date +%Y%m%d).aof
```

**Automated Backup (cron):**
```bash
# Add to crontab
0 2 * * * docker exec redis-fips redis-cli -a PASSWORD BGSAVE && \
          docker cp redis-fips:/data/dump.rdb /backup/redis-$(date +\%Y\%m\%d).rdb
```

### Restore Procedure

1. **Stop Redis:**
   ```bash
   docker-compose stop redis-fips
   # or
   kubectl scale statefulset redis-fips --replicas=0
   ```

2. **Restore Data:**
   ```bash
   docker cp backup/dump.rdb redis-fips:/data/
   ```

3. **Start Redis:**
   ```bash
   docker-compose start redis-fips
   # or
   kubectl scale statefulset redis-fips --replicas=1
   ```

4. **Verify:**
   ```bash
   redis-cli -a PASSWORD DBSIZE
   redis-cli -a PASSWORD INFO persistence
   ```

## Monitoring and Alerting

### Key Metrics to Monitor

1. **Memory Usage**
   ```bash
   redis-cli -a PASSWORD INFO memory | grep used_memory_human
   ```

2. **Connected Clients**
   ```bash
   redis-cli -a PASSWORD INFO clients | grep connected_clients
   ```

3. **Operations per Second**
   ```bash
   redis-cli -a PASSWORD INFO stats | grep instantaneous_ops_per_sec
   ```

4. **Persistence Status**
   ```bash
   redis-cli -a PASSWORD INFO persistence
   ```

5. **FIPS Status**
   ```bash
   docker exec redis-fips fips-startup-check
   ```

### Prometheus Integration

Add redis_exporter sidecar:

```yaml
- name: redis-exporter
  image: oliver006/redis_exporter:latest
  env:
  - name: REDIS_PASSWORD
    value: YOUR_PASSWORD
  ports:
  - name: metrics
    containerPort: 9121
```

## Troubleshooting

### Common Issues

**Connection Refused:**
- Check container is running: `docker ps` or `kubectl get pods`
- Verify port mapping: `docker port redis-fips`
- Check firewall rules

**Authentication Failed:**
- Verify password in configuration
- Check Secret/environment variables
- Test with: `redis-cli -a PASSWORD PING`

**Out of Memory:**
- Check `maxmemory` setting
- Review eviction policy
- Monitor with: `redis-cli -a PASSWORD INFO memory`

**Slow Performance:**
- Check slow log: `redis-cli -a PASSWORD SLOWLOG GET 10`
- Review resource limits
- Consider persistence settings (disable AOF fsync for testing)

**FIPS Validation Failed:**
- Check wolfProvider: `openssl list -providers`
- Verify FIPS POST: `fips-startup-check`
- Review container logs

### Diagnostic Commands

```bash
# Container logs
docker logs redis-fips
kubectl logs redis-fips-0

# Redis info
redis-cli -a PASSWORD INFO all

# Client list
redis-cli -a PASSWORD CLIENT LIST

# Configuration
redis-cli -a PASSWORD CONFIG GET '*'

# Slow queries
redis-cli -a PASSWORD SLOWLOG GET 10
```

## High Availability

For production HA deployments, consider:

### Redis Sentinel
- Automatic failover
- Monitoring and notifications
- Configuration provider for clients

### Redis Cluster
- Horizontal scaling
- Automatic sharding
- Built-in replication

See advanced deployment guides for:
- Multi-node Sentinel setup
- Redis Cluster configuration
- Cross-region replication

## Security Hardening

### Best Practices

1. **Strong Passwords**
   - Minimum 32 characters
   - Use password managers
   - Rotate regularly

2. **Network Isolation**
   - Use private networks
   - Firewall rules
   - Kubernetes NetworkPolicies

3. **TLS Encryption**
   - Enable for production
   - Use mutual TLS
   - Rotate certificates

4. **Access Control**
   - Use ACLs for multi-tenant
   - Limit dangerous commands
   - Audit access logs

5. **Updates**
   - Monitor security advisories
   - Test updates in staging
   - Plan maintenance windows

## Additional Resources

- [Main Documentation](../README.md)
- [FIPS Compliance Details](../ATTESTATION.md)
- [Architecture Overview](../ARCHITECTURE.md)
- [Development Guide](../DEVELOPER-GUIDE.md)
- [Build and Test Results](../BUILD-TEST-RESULTS.md)

## Support

For issues or questions:
1. Check troubleshooting guides in each example
2. Review main documentation
3. Check container logs
4. Verify FIPS compliance with diagnostic scripts

## License

Redis is licensed under the BSD-3-Clause license.
wolfSSL FIPS module is commercial software - ensure proper licensing.
