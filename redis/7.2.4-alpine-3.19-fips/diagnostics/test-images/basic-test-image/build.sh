#!/bin/bash
################################################################################
# Build Redis FIPS Test Image
################################################################################

set -e

echo "Building Redis FIPS test image..."
docker build -t redis-fips-test:latest .

echo ""
echo "✓ Test image built successfully"
echo ""
echo "To run tests:"
echo "  docker run -t --rm redis-fips-test:latest"
echo ""
echo "Or using docker-compose:"
echo "  docker-compose up"
