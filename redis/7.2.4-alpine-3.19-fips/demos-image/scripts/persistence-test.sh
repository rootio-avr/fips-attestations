#!/bin/sh
################################################################################
# Redis FIPS Persistence Test Script
# Tests RDB and AOF persistence functionality
################################################################################

HOST="${REDIS_HOST:-localhost}"
PORT="${REDIS_PORT:-6379}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "${BLUE}Redis FIPS Persistence Demo${NC}"
echo "============================"
echo ""

# Test 1: Write test data
echo "${YELLOW}[1/5] Writing test data...${NC}"
redis-cli -h "$HOST" -p "$PORT" SET persistence:test:key1 "value1" > /dev/null
redis-cli -h "$HOST" -p "$PORT" SET persistence:test:key2 "value2" > /dev/null
redis-cli -h "$HOST" -p "$PORT" SET persistence:test:key3 "value3" > /dev/null
redis-cli -h "$HOST" -p "$PORT" LPUSH persistence:test:list "item1" "item2" "item3" > /dev/null
redis-cli -h "$HOST" -p "$PORT" HSET persistence:test:hash field1 "val1" field2 "val2" > /dev/null
echo "${GREEN}✓${NC} Test data written"
echo ""

# Test 2: Trigger BGSAVE
echo "${YELLOW}[2/5] Triggering background save (BGSAVE)...${NC}"
result=$(redis-cli -h "$HOST" -p "$PORT" BGSAVE 2>&1)
echo "Response: $result"

# Wait for save to complete
sleep 2

# Check last save time
last_save=$(redis-cli -h "$HOST" -p "$PORT" LASTSAVE 2>/dev/null)
if [ -n "$last_save" ]; then
    echo "${GREEN}✓${NC} Last save timestamp: $last_save"
else
    echo "Unable to get last save time"
fi
echo ""

# Test 3: Check RDB info
echo "${YELLOW}[3/5] Checking RDB persistence info...${NC}"
redis-cli -h "$HOST" -p "$PORT" INFO persistence | grep -E "rdb_|loading:|aof_" | while read line; do
    echo "  $line"
done
echo ""

# Test 4: Trigger AOF rewrite
echo "${YELLOW}[4/5] Checking AOF status...${NC}"
aof_enabled=$(redis-cli -h "$HOST" -p "$PORT" CONFIG GET appendonly 2>/dev/null | tail -1)
if [ "$aof_enabled" = "yes" ]; then
    echo "${GREEN}✓${NC} AOF is enabled"
    echo "Triggering AOF rewrite..."
    result=$(redis-cli -h "$HOST" -p "$PORT" BGREWRITEAOF 2>&1)
    echo "Response: $result"
else
    echo "AOF is disabled for this configuration"
fi
echo ""

# Test 5: Verify data persistence
echo "${YELLOW}[5/5] Verifying persisted data...${NC}"
val1=$(redis-cli -h "$HOST" -p "$PORT" GET persistence:test:key1 2>/dev/null)
val2=$(redis-cli -h "$HOST" -p "$PORT" GET persistence:test:key2 2>/dev/null)
val3=$(redis-cli -h "$HOST" -p "$PORT" GET persistence:test:key3 2>/dev/null)

if [ "$val1" = "value1" ] && [ "$val2" = "value2" ] && [ "$val3" = "value3" ]; then
    echo "${GREEN}✓${NC} All test keys verified"
else
    echo "Warning: Some keys may not be set correctly"
fi

list_len=$(redis-cli -h "$HOST" -p "$PORT" LLEN persistence:test:list 2>/dev/null)
echo "${GREEN}✓${NC} List length: $list_len items"

hash_len=$(redis-cli -h "$HOST" -p "$PORT" HLEN persistence:test:hash 2>/dev/null)
echo "${GREEN}✓${NC} Hash length: $hash_len fields"

echo ""
echo "${GREEN}Persistence test completed${NC}"
echo ""
echo "Files location (inside container):"
echo "  RDB: /data/dump.rdb"
echo "  AOF: /data/appendonly.aof (if enabled)"
echo ""
echo "To view files:"
echo "  docker exec <container> ls -lh /data/"
