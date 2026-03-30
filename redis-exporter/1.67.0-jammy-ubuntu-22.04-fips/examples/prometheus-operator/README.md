# Prometheus Operator Integration

This example demonstrates integrating Redis Exporter FIPS with Prometheus Operator.

## Prerequisites

- Kubernetes cluster with Prometheus Operator installed
- Redis Exporter deployed (see `../kubernetes/`)

## Quick Deploy

```bash
# Deploy ServiceMonitor
kubectl apply -f servicemonitor.yaml

# Deploy PrometheusRule
kubectl apply -f prometheusrule.yaml

# Verify ServiceMonitor
kubectl get servicemonitor -n monitoring redis-exporter

# Verify PrometheusRule
kubectl get prometheusrule -n monitoring redis-exporter-alerts
```

## ServiceMonitor

The ServiceMonitor automatically configures Prometheus to scrape redis-exporter:

- **Scrape Interval:** 30 seconds
- **Scrape Timeout:** 10 seconds
- **Path:** /metrics
- **Labels:** Adds `fips_enabled=true` label

## PrometheusRule

Includes alerting rules for:

1. **RedisDown** - Redis instance unreachable (critical)
2. **RedisMemoryHigh** - Memory usage >90% (warning)
3. **RedisTooManyClients** - >100 client connections (warning)
4. **RedisSlowQueries** - Slow query log growing (info)
5. **RedisReplicationLagHigh** - Replication lag >10s (warning)
6. **RedisExporterScrapeSlow** - Scrape duration >1s (warning)

## Verification

```bash
# Check if Prometheus discovered the target
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090

# Open browser to http://localhost:9090/targets
# Look for "monitoring/redis-exporter/0" target

# Check if alerts are loaded
# Open browser to http://localhost:9090/alerts
```

## Customization

### Modify Scrape Interval

Edit `servicemonitor.yaml`:

```yaml
endpoints:
- port: metrics
  interval: 15s  # Change from 30s to 15s
  scrapeTimeout: 5s
```

### Add Custom Labels

Edit `servicemonitor.yaml`:

```yaml
relabelings:
- targetLabel: environment
  replacement: production
- targetLabel: team
  replacement: platform
```

### Adjust Alert Thresholds

Edit `prometheusrule.yaml`:

```yaml
# Example: Change memory threshold from 90% to 80%
- alert: RedisMemoryHigh
  expr: (redis_memory_used_bytes / redis_memory_max_bytes) > 0.8
  for: 10m
```

## Grafana Dashboard

Import the dashboard from `../../diagnostics/demos-image/configs/grafana-dashboard.json`
