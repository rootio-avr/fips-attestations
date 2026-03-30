# Kubernetes Deployment Example

This example demonstrates deploying Redis Exporter FIPS in Kubernetes.

## Prerequisites

- Kubernetes cluster (1.24+)
- kubectl configured
- Redis service running (or deploy using provided manifests)

## Quick Deploy

```bash
# Create namespace
kubectl apply -f namespace.yaml

# Deploy redis-exporter
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml

# Verify deployment
kubectl get pods -n monitoring
kubectl get svc -n monitoring
```

## Verification

```bash
# Check pod status
kubectl get pods -n monitoring -l app=redis-exporter

# View logs
kubectl logs -n monitoring -l app=redis-exporter

# Check FIPS environment
kubectl exec -n monitoring -it \
  $(kubectl get pod -n monitoring -l app=redis-exporter -o name | head -1) \
  -- env | grep GOLANG_FIPS

# Port forward and test metrics
kubectl port-forward -n monitoring svc/redis-exporter 9121:9121
curl http://localhost:9121/metrics
```

## Configuration

### Environment Variables

Edit `deployment.yaml` to customize:

```yaml
env:
- name: REDIS_ADDR
  value: "redis://redis-service:6379"  # Your Redis service
- name: REDIS_PASSWORD  # If using authentication
  valueFrom:
    secretKeyRef:
      name: redis-secret
      key: password
```

### Resource Limits

Adjust based on your needs:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 200m
    memory: 256Mi
```

## Security

The deployment includes security best practices:

- Non-root user (UID 10001)
- Read-only root filesystem
- Dropped all capabilities
- Seccomp profile enabled
- Security context configured

## Prometheus Integration

The service includes annotations for automatic Prometheus discovery:

```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "9121"
```

For Prometheus Operator, see `../prometheus-operator/servicemonitor.yaml`
