#!/bin/sh
################################################################################
# Redis FIPS Comprehensive Test Suite
# Tests the Redis FIPS image functionality
################################################################################

set -e

# Auto-detect if running in a terminal
if [ -t 1 ]; then
    # Running in terminal - use colors
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    # Not in terminal (CI/CD, piped) - no colors
    GREEN=''
    RED=''
    YELLOW=''
    BLUE=''
    NC=''
fi

printf "${BLUE}======================================${NC}\n"
printf "${BLUE}Redis FIPS Comprehensive Test Suite${NC}\n"
printf "${BLUE}======================================${NC}\n"
printf "\n"

PASSED=0
FAILED=0
TOTAL=0

test_start() {
    TOTAL=$((TOTAL + 1))
    printf "${BLUE}[TEST %d]${NC} %s..." "$TOTAL" "$1"
}

test_pass() {
    printf " ${GREEN}PASS${NC}\n"
    PASSED=$((PASSED + 1))
}

test_fail() {
    printf " ${RED}FAIL${NC}\n"
    if [ -n "$1" ]; then
        printf "  ${RED}Error: %s${NC}\n" "$1"
    fi
    FAILED=$((FAILED + 1))
}

# Start Redis in background for testing
printf "${YELLOW}Starting Redis server in background...${NC}\n"
redis-server --daemonize yes --port 6379 --bind 127.0.0.1 2>/dev/null
sleep 2

# Test 1: FIPS POST Validation
test_start "FIPS POST validation"
if fips-startup-check >/dev/null 2>&1; then
    test_pass
else
    test_fail "FIPS POST failed"
fi

# Test 2: OpenSSL Provider
test_start "wolfProvider loaded"
if openssl list -providers 2>/dev/null | grep -qi "wolfSSL"; then
    test_pass
else
    test_fail "wolfProvider not loaded"
fi

# Test 3: FIPS Enforcement (MD5 should be blocked)
test_start "FIPS enforcement (MD5 blocked)"
if openssl dgst -md5 /etc/redis/redis.conf 2>&1 | grep -qi "error\|disabled\|unsupported"; then
    test_pass
else
    test_fail "MD5 not blocked"
fi

# Test 4: FIPS Algorithm (SHA-256 should work)
test_start "FIPS algorithm (SHA-256 working)"
if openssl dgst -sha256 /etc/redis/redis.conf >/dev/null 2>&1; then
    test_pass
else
    test_fail "SHA-256 not working"
fi

# Test 5: Redis Connectivity
test_start "Redis connectivity (PING)"
if redis-cli PING 2>/dev/null | grep -q "PONG"; then
    test_pass
else
    test_fail "Redis not responding"
fi

# Test 6: Basic SET operation
test_start "Redis SET operation"
if redis-cli SET test_key "test_value" >/dev/null 2>&1; then
    test_pass
else
    test_fail "SET operation failed"
fi

# Test 7: Basic GET operation
test_start "Redis GET operation"
if redis-cli GET test_key 2>/dev/null | grep -q "test_value"; then
    test_pass
else
    test_fail "GET operation failed"
fi

# Test 8: Multiple keys (MSET/MGET)
test_start "Multiple key operations (MSET/MGET)"
if redis-cli MSET key1 "val1" key2 "val2" key3 "val3" >/dev/null 2>&1 && \
   redis-cli MGET key1 key2 key3 2>/dev/null | grep -q "val1"; then
    test_pass
else
    test_fail "MSET/MGET failed"
fi

# Test 9: Lua Scripting (uses SHA-256 internally)
test_start "Lua scripting (SHA-256 hashing)"
if redis-cli EVAL "return redis.call('PING')" 0 2>/dev/null | grep -q "PONG"; then
    test_pass
else
    test_fail "Lua scripting failed"
fi

# Test 10: Lua redis.sha1hex() API (actually uses SHA-256)
test_start "Lua redis.sha1hex() API"
if redis-cli EVAL "return redis.sha1hex('test')" 0 >/dev/null 2>&1; then
    test_pass
else
    test_fail "redis.sha1hex() failed"
fi

# Test 11: DELETE operations
test_start "DELETE operations"
if redis-cli DEL test_key key1 key2 key3 >/dev/null 2>&1; then
    test_pass
else
    test_fail "DELETE failed"
fi

# Test 12: Key expiration (TTL)
test_start "Key expiration (SETEX/TTL)"
if redis-cli SETEX temp_key 10 "temp_value" >/dev/null 2>&1 && \
   redis-cli TTL temp_key 2>/dev/null | grep -qE "^[0-9]+$"; then
    test_pass
else
    test_fail "SETEX/TTL failed"
fi

# Test 13: Lists (LPUSH/LRANGE)
test_start "List operations (LPUSH/LRANGE)"
if redis-cli LPUSH mylist "item1" "item2" "item3" >/dev/null 2>&1 && \
   redis-cli LRANGE mylist 0 -1 2>/dev/null | grep -q "item1"; then
    test_pass
else
    test_fail "List operations failed"
fi

# Test 14: Sets (SADD/SMEMBERS)
test_start "Set operations (SADD/SMEMBERS)"
if redis-cli SADD myset "member1" "member2" "member3" >/dev/null 2>&1 && \
   redis-cli SMEMBERS myset 2>/dev/null | grep -q "member1"; then
    test_pass
else
    test_fail "Set operations failed"
fi

# Test 15: Sorted Sets (ZADD/ZRANGE)
test_start "Sorted set operations (ZADD/ZRANGE)"
if redis-cli ZADD myzset 1 "one" 2 "two" 3 "three" >/dev/null 2>&1 && \
   redis-cli ZRANGE myzset 0 -1 2>/dev/null | grep -q "one"; then
    test_pass
else
    test_fail "Sorted set operations failed"
fi

# Test 16: Hashes (HSET/HGET)
test_start "Hash operations (HSET/HGET)"
if redis-cli HSET myhash field1 "value1" field2 "value2" >/dev/null 2>&1 && \
   redis-cli HGET myhash field1 2>/dev/null | grep -q "value1"; then
    test_pass
else
    test_fail "Hash operations failed"
fi

# Test 17: Pub/Sub (basic test)
test_start "Pub/Sub functionality"
if redis-cli PUBLISH mychannel "test message" >/dev/null 2>&1; then
    test_pass
else
    test_fail "Pub/Sub failed"
fi

# Test 18: Redis INFO command
test_start "Redis INFO command"
if redis-cli INFO server >/dev/null 2>&1; then
    test_pass
else
    test_fail "INFO command failed"
fi

# Test 19: BGSAVE (background save)
test_start "Background save (BGSAVE)"
if redis-cli BGSAVE >/dev/null 2>&1; then
    test_pass
else
    test_fail "BGSAVE failed"
fi

# Test 20: Database selection
test_start "Database selection (SELECT)"
if redis-cli SELECT 1 >/dev/null 2>&1 && \
   redis-cli SELECT 0 >/dev/null 2>&1; then
    test_pass
else
    test_fail "SELECT failed"
fi

# Cleanup
redis-cli FLUSHALL >/dev/null 2>&1
redis-cli SHUTDOWN NOSAVE >/dev/null 2>&1 || true

printf "\n"
printf "${BLUE}======================================${NC}\n"
printf "${BLUE}Test Results Summary${NC}\n"
printf "${BLUE}======================================${NC}\n"
printf "Total tests: %d\n" "$TOTAL"
printf "${GREEN}Passed: %d${NC}\n" "$PASSED"
if [ $FAILED -gt 0 ]; then
    printf "${RED}Failed: %d${NC}\n" "$FAILED"
fi
printf "\n"

if [ $FAILED -eq 0 ]; then
    printf "${GREEN}======================================${NC}\n"
    printf "${GREEN}✓ ALL TESTS PASSED${NC}\n"
    printf "${GREEN}======================================${NC}\n"
    exit 0
else
    printf "${RED}======================================${NC}\n"
    printf "${RED}✗ SOME TESTS FAILED${NC}\n"
    printf "${RED}======================================${NC}\n"
    exit 1
fi
