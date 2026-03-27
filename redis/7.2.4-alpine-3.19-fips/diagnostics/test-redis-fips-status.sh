#!/bin/bash
# Redis FIPS Status Check
# Usage: ./test-redis-fips-status.sh [container-name]

CONTAINER=${1:-redis-fips}
docker exec "$CONTAINER" fips-startup-check
