# Kubernetes Deployment Example

This directory contains Kubernetes manifests for deploying Redis FIPS in a production environment.

## Quick Start

```bash
# 1. Update the password in the Secret
kubectl create secret generic redis-fips-secret \
  --from-literal=password='YOUR_STRONG_PASSWORD'

# 2. Update ConfigMap password (edit deployment.yaml)
# Change: requirepass REPLACE_WITH_STRONG_PASSWORD
# To:     requirepass YOUR_STRONG_PASSWORD

# 3. Deploy Redis FIPS
kubectl apply -f deployment.yaml

# 4. Check deployment status
kubectl get statefulset redis-fips
kubectl get pods -l app=redis-fips

# 5. Test connection
kubectl exec -it redis-fips-0 -- redis-cli -a YOUR_STRONG_PASSWORD PING
```

## Architecture

The deployment includes:

- **StatefulSet**: Ensures stable network identity and persistent storage
- **ConfigMap**: Redis configuration file
- **Secret**: Secure password storage
- **Service (ClusterIP)**: Internal cluster access
- **Service (Headless)**: Direct pod access for StatefulSet
- **PersistentVolumeClaim**: 10Gi persistent storage per pod

## Configuration

### Resource Limits

Default resource allocation:

```yaml
requests:
  cpu: 500m
  memory: 512Mi
limits:
  cpu: 2000m
  memory: 2Gi
```

Adjust based on your workload:

```bash
kubectl edit statefulset redis-fips
```

### Storage Class

Default uses `standard` storage class. To use a different class:

```yaml
volumeClaimTemplates:
  - metadata:
      name: redis-data
    spec:
      storageClassName: fast-ssd  # Change this
```

### Password Management

**Using kubectl to create secret:**

```bash
kubectl create secret generic redis-fips-secret \
  --from-literal=password='MyStr0ngP@ssw0rd!'
```

**Using a file:**

```bash
echo -n 'MyStr0ngP@ssw0rd!' > password.txt
kubectl create secret generic redis-fips-secret \
  --from-file=password=password.txt
rm password.txt
```

**Important:** Also update the ConfigMap to match:

```bash
kubectl edit configmap redis-fips-config
# Change: requirepass REPLACE_WITH_STRONG_PASSWORD
# To:     requirepass MyStr0ngP@ssw0rd!
```

## Health Checks

The deployment includes three types of probes:

### Startup Probe
- Checks if Redis has successfully started
- Allows up to 50 seconds for startup (10 failures × 5s)
- Prevents premature liveness/readiness checks

### Liveness Probe
- Ensures Redis is running
- Restarts pod if Redis becomes unresponsive
- Checks every 10 seconds after 30s initial delay

### Readiness Probe
- Determines if pod can receive traffic
- Removes pod from service if unhealthy
- Checks every 5 seconds after 10s initial delay

## Scaling

### Single Instance (Default)

The default configuration runs a single Redis instance:

```yaml
replicas: 1
```

### High Availability

For HA deployment with Redis Sentinel, see:
- `examples/kubernetes/redis-sentinel/` (if available)
- Redis Cluster configuration examples

**Note:** Redis FIPS image supports Redis Sentinel and Cluster modes.

## Storage

### Backup Data

```bash
# Trigger background save
kubectl exec redis-fips-0 -- redis-cli -a YOUR_PASSWORD BGSAVE

# Copy RDB file
kubectl cp redis-fips-0:/data/dump.rdb ./backup/dump.rdb

# Copy AOF file
kubectl cp redis-fips-0:/data/appendonly.aof ./backup/appendonly.aof
```

### Restore Data

```bash
# Stop Redis
kubectl scale statefulset redis-fips --replicas=0

# Copy backup to PVC (using a temporary pod)
kubectl run -i --rm --tty temp-restore \
  --image=busybox \
  --overrides='
{
  "spec": {
    "containers": [{
      "name": "temp-restore",
      "image": "busybox",
      "stdin": true,
      "tty": true,
      "volumeMounts": [{
        "name": "redis-data",
        "mountPath": "/data"
      }]
    }],
    "volumes": [{
      "name": "redis-data",
      "persistentVolumeClaim": {
        "claimName": "redis-data-redis-fips-0"
      }
    }]
  }
}' -- sh

# Inside the temporary pod:
# cp /backup/dump.rdb /data/
# exit

# Restart Redis
kubectl scale statefulset redis-fips --replicas=1
```

## Monitoring

### Prometheus Integration

The pod includes annotations for Prometheus scraping:

```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "6379"
```

### Metrics Export

Use redis_exporter for detailed metrics:

```yaml
- name: redis-exporter
  image: oliver006/redis_exporter:latest
  env:
  - name: REDIS_PASSWORD
    valueFrom:
      secretKeyRef:
        name: redis-fips-secret
        key: password
  ports:
  - name: metrics
    containerPort: 9121
```

## Security

### FIPS Validation

Verify FIPS compliance on running pod:

```bash
kubectl exec redis-fips-0 -- fips-startup-check
kubectl exec redis-fips-0 -- openssl list -providers
```

### Network Policies

Restrict access to Redis (example):

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: redis-fips-netpol
spec:
  podSelector:
    matchLabels:
      app: redis-fips
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: backend
    - podSelector:
        matchLabels:
          role: application
    ports:
    - protocol: TCP
      port: 6379
```

### Pod Security Standards

The deployment follows restricted pod security:

- `runAsNonRoot: true`
- `allowPrivilegeEscalation: false`
- Drops all capabilities
- Uses security context

## Troubleshooting

### View Logs

```bash
# Recent logs
kubectl logs redis-fips-0

# Follow logs
kubectl logs -f redis-fips-0

# Previous container logs (after crash)
kubectl logs redis-fips-0 --previous
```

### Debugging

```bash
# Get shell access
kubectl exec -it redis-fips-0 -- sh

# Check Redis status
kubectl exec redis-fips-0 -- redis-cli -a PASSWORD INFO server

# Check FIPS status
kubectl exec redis-fips-0 -- fips-startup-check

# Check disk usage
kubectl exec redis-fips-0 -- df -h /data
```

### Common Issues

**Pod stuck in Pending:**
```bash
# Check PVC status
kubectl get pvc
# Check storage class
kubectl get storageclass
```

**Probes failing:**
```bash
# Check password configuration
kubectl get secret redis-fips-secret -o jsonpath='{.data.password}' | base64 -d
kubectl get configmap redis-fips-config -o yaml | grep requirepass
```

**Out of memory:**
```bash
# Check current memory usage
kubectl exec redis-fips-0 -- redis-cli -a PASSWORD INFO memory
# Increase limits in StatefulSet
kubectl edit statefulset redis-fips
```

## Cleanup

```bash
# Delete all resources
kubectl delete -f deployment.yaml

# Delete PVC (WARNING: This deletes all data)
kubectl delete pvc redis-data-redis-fips-0

# Delete secret
kubectl delete secret redis-fips-secret
```

## Advanced Configuration

### Multiple Namespaces

Deploy to specific namespace:

```bash
# Edit deployment.yaml namespace field
# Then apply:
kubectl apply -f deployment.yaml -n production
```

### Custom Configuration

Edit the ConfigMap to customize Redis behavior:

```bash
kubectl edit configmap redis-fips-config
```

After editing, restart pods:

```bash
kubectl rollout restart statefulset redis-fips
```

## Production Checklist

- [ ] Strong password configured in Secret
- [ ] ConfigMap password matches Secret
- [ ] Resource limits appropriate for workload
- [ ] Storage class supports your performance needs
- [ ] Backup strategy implemented
- [ ] Monitoring configured (Prometheus, logs)
- [ ] Network policies applied (if required)
- [ ] FIPS validation tested
- [ ] Disaster recovery procedure documented
- [ ] Team trained on Redis FIPS operations

## References

- [Redis Configuration](../../README.md)
- [FIPS Compliance](../../ATTESTATION.md)
- [Architecture](../../ARCHITECTURE.md)
