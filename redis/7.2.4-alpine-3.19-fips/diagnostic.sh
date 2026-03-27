#!/bin/bash
################################################################################
# Redis FIPS Diagnostic Script
#
# Performs comprehensive diagnostics on Redis FIPS image
# Usage: ./diagnostic.sh [container-name]
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CONTAINER_NAME=${1:-redis-fips}
IMAGE_NAME="cr.root.io/redis:7.2.4-alpine-3.19-fips"

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Redis FIPS Comprehensive Diagnostics${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Check if container exists (running or stopped)
if docker ps -a | grep -q "$CONTAINER_NAME"; then
    # Container exists - check if it's running
    if docker ps | grep -q "$CONTAINER_NAME"; then
        echo -e "${GREEN}Using existing running container: $CONTAINER_NAME${NC}"
        CLEANUP=false
    else
        echo -e "${YELLOW}Starting existing container: $CONTAINER_NAME...${NC}"
        docker start "$CONTAINER_NAME" >/dev/null 2>&1
        sleep 3
        CLEANUP=false
    fi
else
    # No container exists - create new one
    echo -e "${YELLOW}Creating and starting test container...${NC}"
    if docker run -d -p 6379:6379 --name "$CONTAINER_NAME" "$IMAGE_NAME" >/dev/null 2>&1; then
        sleep 5
        CLEANUP=true
    else
        echo -e "${RED}Failed to start container. Port 6379 may be in use.${NC}"
        echo -e "${YELLOW}Trying alternative port 6380...${NC}"
        docker run -d -p 6380:6379 --name "$CONTAINER_NAME" "$IMAGE_NAME" >/dev/null 2>&1
        sleep 5
        CLEANUP=true
    fi
fi

echo ""

# Test 1: FIPS Validation
echo -e "${BLUE}[TEST 1/8]${NC} FIPS Validation Status"
if docker logs "$CONTAINER_NAME" 2>&1 | grep -q "ALL FIPS CHECKS PASSED"; then
    echo -e "${GREEN}✓ FIPS validation passed${NC}"
else
    echo -e "${RED}✗ FIPS validation failed${NC}"
fi

# Test 2: wolfSSL FIPS POST
echo -e "${BLUE}[TEST 2/8]${NC} wolfSSL FIPS POST"
docker exec "$CONTAINER_NAME" fips-startup-check >/dev/null 2>&1 && \
    echo -e "${GREEN}✓ FIPS POST successful${NC}" || \
    echo -e "${RED}✗ FIPS POST failed${NC}"

# Test 3: OpenSSL Provider
echo -e "${BLUE}[TEST 3/8]${NC} OpenSSL Provider Status"
if docker exec "$CONTAINER_NAME" openssl list -providers | grep -q "wolfSSL"; then
    echo -e "${GREEN}✓ wolfProvider loaded${NC}"
else
    echo -e "${RED}✗ wolfProvider not loaded${NC}"
fi

# Test 4: Redis Connectivity
echo -e "${BLUE}[TEST 4/8]${NC} Redis Connectivity"
if docker exec "$CONTAINER_NAME" redis-cli PING | grep -q "PONG"; then
    echo -e "${GREEN}✓ Redis responding${NC}"
else
    echo -e "${RED}✗ Redis not responding${NC}"
fi

# Test 5: Basic Operations
echo -e "${BLUE}[TEST 5/8]${NC} Basic Redis Operations"
docker exec "$CONTAINER_NAME" redis-cli SET diag_test "test_value" >/dev/null 2>&1
if docker exec "$CONTAINER_NAME" redis-cli GET diag_test | grep -q "test_value"; then
    echo -e "${GREEN}✓ SET/GET operations working${NC}"
    docker exec "$CONTAINER_NAME" redis-cli DEL diag_test >/dev/null 2>&1
else
    echo -e "${RED}✗ SET/GET operations failed${NC}"
fi

# Test 6: Lua Scripting (SHA-256)
echo -e "${BLUE}[TEST 6/8]${NC} Lua Scripting (FIPS SHA-256)"
if docker exec "$CONTAINER_NAME" redis-cli EVAL "return redis.call('PING')" 0 | grep -q "PONG"; then
    echo -e "${GREEN}✓ Lua scripting working (uses SHA-256)${NC}"
else
    echo -e "${RED}✗ Lua scripting failed${NC}"
fi

# Test 7: FIPS Enforcement
echo -e "${BLUE}[TEST 7/8]${NC} FIPS Algorithm Enforcement"
if docker exec "$CONTAINER_NAME" openssl dgst -md5 /etc/redis/redis.conf 2>&1 | grep -qi "error\|disabled\|unsupported"; then
    echo -e "${GREEN}✓ Non-FIPS algorithms blocked (MD5 rejected)${NC}"
else
    echo -e "${YELLOW}⚠ Non-FIPS algorithms may not be blocked${NC}"
fi

# Test 8: Library Dependencies
echo -e "${BLUE}[TEST 8/8]${NC} Library Dependencies"
if docker exec "$CONTAINER_NAME" ldd /usr/local/bin/redis-server | grep -q "libssl.so.3"; then
    echo -e "${GREEN}✓ OpenSSL 3.x linked correctly${NC}"
else
    echo -e "${RED}✗ OpenSSL linkage issue${NC}"
fi

echo ""
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}System Information${NC}"
echo -e "${BLUE}======================================${NC}"

echo -e "${YELLOW}Image:${NC}"
docker inspect "$CONTAINER_NAME" --format='{{.Config.Image}}'

echo -e "${YELLOW}Redis Version:${NC}"
docker exec "$CONTAINER_NAME" redis-server --version

echo -e "${YELLOW}OpenSSL Version:${NC}"
docker exec "$CONTAINER_NAME" openssl version

echo -e "${YELLOW}Container Uptime:${NC}"
docker inspect "$CONTAINER_NAME" --format='Started: {{.State.StartedAt}}'

echo -e "${YELLOW}Memory Usage:${NC}"
docker stats "$CONTAINER_NAME" --no-stream --format "{{.MemUsage}}"

echo ""
echo -e "${BLUE}======================================${NC}"
echo -e "${GREEN}Diagnostics Complete${NC}"
echo -e "${BLUE}======================================${NC}"

# Cleanup
if [ "$CLEANUP" = true ]; then
    echo -e "${YELLOW}Cleaning up test container...${NC}"
    docker stop "$CONTAINER_NAME" >/dev/null 2>&1
    docker rm "$CONTAINER_NAME" >/dev/null 2>&1
fi
