#!/bin/sh
################################################################################
# Redis FIPS Memory Test Script
# Tests memory limits and eviction policies
################################################################################

HOST="${REDIS_HOST:-localhost}"
PORT="${REDIS_PORT:-6379}"
KEY_COUNT="${KEY_COUNT:-1000}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo "${BLUE}Redis FIPS Memory Demo${NC}"
echo "======================"
echo ""

# Test 1: Get current memory info
echo "${YELLOW}[1/5] Current memory statistics...${NC}"
redis-cli -h "$HOST" -p "$PORT" INFO memory | grep -E "used_memory_human|used_memory_peak_human|maxmemory_human|maxmemory_policy|mem_fragmentation_ratio" | while read line; do
    echo "  $line"
done
echo ""

# Test 2: Get maxmemory settings
echo "${YELLOW}[2/5] Memory limit configuration...${NC}"
maxmem=$(redis-cli -h "$HOST" -p "$PORT" CONFIG GET maxmemory 2>/dev/null | tail -1)
maxpolicy=$(redis-cli -h "$HOST" -p "$PORT" CONFIG GET maxmemory-policy 2>/dev/null | tail -1)
echo "  maxmemory: $maxmem bytes"
echo "  maxmemory-policy: $maxpolicy"
echo ""

# Test 3: Populate with test data
echo "${YELLOW}[3/5] Populating with test data ($KEY_COUNT keys)...${NC}"
count=0
while [ $count -lt $KEY_COUNT ]; do
    redis-cli -h "$HOST" -p "$PORT" SET "memory:test:key:$count" "value_$(printf '%0100d' $count)" EX 300 > /dev/null 2>&1
    count=$((count + 1))

    # Progress indicator
    if [ $((count % 100)) -eq 0 ]; then
        printf "."
    fi
done
echo ""
echo "${GREEN}✓${NC} $KEY_COUNT keys created"
echo ""

# Test 4: Check memory after population
echo "${YELLOW}[4/5] Memory usage after population...${NC}"
redis-cli -h "$HOST" -p "$PORT" INFO memory | grep -E "used_memory_human|used_memory_peak_human|evicted_keys" | while read line; do
    echo "  $line"
done

dbsize=$(redis-cli -h "$HOST" -p "$PORT" DBSIZE 2>/dev/null)
echo "  dbsize: $dbsize keys"
echo ""

# Test 5: Monitor eviction (if using eviction policy)
echo "${YELLOW}[5/5] Eviction statistics...${NC}"
evicted=$(redis-cli -h "$HOST" -p "$PORT" INFO stats | grep "evicted_keys" | cut -d: -f2 | tr -d '\r')
expired=$(redis-cli -h "$HOST" -p "$PORT" INFO stats | grep "expired_keys" | cut -d: -f2 | tr -d '\r')

echo "  evicted_keys: $evicted"
echo "  expired_keys: $expired"

if [ "$evicted" != "" ] && [ "$evicted" -gt 0 ]; then
    echo "${YELLOW}  Note: Keys are being evicted due to memory pressure${NC}"
else
    echo "${GREEN}  No evictions yet${NC}"
fi
echo ""

# Memory fragmentation ratio
echo "${YELLOW}Memory efficiency metrics:${NC}"
redis-cli -h "$HOST" -p "$PORT" INFO memory | grep -E "mem_fragmentation_ratio|mem_allocator" | while read line; do
    echo "  $line"
done
echo ""

echo "${GREEN}Memory test completed${NC}"
echo ""
echo "Commands to monitor memory:"
echo "  redis-cli INFO memory"
echo "  redis-cli MEMORY STATS"
echo "  redis-cli MEMORY DOCTOR"
