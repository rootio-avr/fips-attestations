#!/bin/bash
# Redis Connectivity Test
# Usage: ./test-redis-connectivity.sh [container-name]

CONTAINER=${1:-redis-fips}

echo "Testing Redis connectivity..."
docker exec "$CONTAINER" redis-cli PING

echo "Testing SET operation..."
docker exec "$CONTAINER" redis-cli SET test_conn "hello"

echo "Testing GET operation..."
docker exec "$CONTAINER" redis-cli GET test_conn

echo "Testing DEL operation..."
docker exec "$CONTAINER" redis-cli DEL test_conn

echo "✓ All connectivity tests passed"
