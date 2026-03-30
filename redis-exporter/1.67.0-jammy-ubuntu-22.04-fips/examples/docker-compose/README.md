# Docker Compose Example - Full Monitoring Stack

This example demonstrates a complete monitoring stack using Redis Exporter FIPS with Prometheus and Grafana.

## Components

- **Redis:** Redis 7.2 server
- **Redis Exporter:** FIPS-compliant exporter
- **Prometheus:** Metrics collection
- **Grafana:** Visualization dashboard

## Quick Start

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

## Access Points

- **Prometheus:** http://localhost:9090
- **Grafana:** http://localhost:3000 (admin/admin)
- **Redis Exporter Metrics:** http://localhost:9121/metrics
- **Redis:** localhost:6379

## Verification

```bash
# Check FIPS status
docker exec redis-exporter env | grep GOLANG_FIPS

# Test metrics endpoint
curl http://localhost:9121/metrics | grep redis_up

# Query Prometheus
curl 'http://localhost:9090/api/v1/query?query=redis_up'
```

## Configuration

Edit `prometheus.yml` to customize scrape configuration.
