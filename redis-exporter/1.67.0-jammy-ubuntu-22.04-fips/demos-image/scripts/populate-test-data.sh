#!/bin/bash
################################################################################
# Redis Exporter FIPS - Test Data Population Script
#
# This script populates Redis with test data for demonstration:
# - String keys
# - Hash keys
# - List keys
# - Set keys
# - Sorted set keys
# - Various data patterns
#
# Usage:
#   ./populate-test-data.sh [OPTIONS]
#
# Options:
#   --small         Generate 1K keys (default)
#   --medium        Generate 10K keys
#   --large         Generate 100K keys
#   --load          Continuous load generation
#   --clean         Clean all data before populating
#   --redis HOST    Redis host (default: localhost)
#   --port PORT     Redis port (default: 6379)
#   --help          Show this help message
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default configuration
REDIS_HOST="${REDIS_HOST:-localhost}"
REDIS_PORT="${REDIS_PORT:-6379}"
SIZE="small"
CLEAN=false
LOAD_MODE=false

################################################################################
# Parse Arguments
################################################################################

while [[ $# -gt 0 ]]; do
    case $1 in
        --small)
            SIZE="small"
            shift
            ;;
        --medium)
            SIZE="medium"
            shift
            ;;
        --large)
            SIZE="large"
            shift
            ;;
        --load)
            LOAD_MODE=true
            shift
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --redis)
            REDIS_HOST="$2"
            shift 2
            ;;
        --port)
            REDIS_PORT="$2"
            shift 2
            ;;
        --help)
            head -n 30 "$0" | grep "^#" | sed 's/^# //; s/^#//'
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

################################################################################
# Setup
################################################################################

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Redis Test Data Population${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Redis: $REDIS_HOST:$REDIS_PORT"
echo "Size: $SIZE"
echo "Load mode: $LOAD_MODE"
echo ""

# Determine key count based on size
case $SIZE in
    small)
        KEY_COUNT=1000
        ;;
    medium)
        KEY_COUNT=10000
        ;;
    large)
        KEY_COUNT=100000
        ;;
esac

echo "Keys to generate: $KEY_COUNT"
echo ""

################################################################################
# Check Redis Connection
################################################################################

echo -e "${YELLOW}Checking Redis connection...${NC}"

if redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ping >/dev/null 2>&1; then
    echo -e "${GREEN}[OK]${NC} Redis is reachable"
else
    echo -e "${RED}[FAIL]${NC} Cannot connect to Redis"
    exit 1
fi

echo ""

################################################################################
# Clean Data (Optional)
################################################################################

if [ "$CLEAN" = "true" ]; then
    echo -e "${YELLOW}Cleaning existing data...${NC}"
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" FLUSHALL >/dev/null 2>&1 || true
    echo -e "${GREEN}[OK]${NC} Data cleaned"
    echo ""
fi

################################################################################
# Populate String Keys
################################################################################

echo -e "${YELLOW}[1/5]${NC} Populating string keys..."

START=$(date +%s)

for i in $(seq 1 $((KEY_COUNT / 5))); do
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" SET "string:$i" "value_$i" >/dev/null 2>&1

    # Progress indicator
    if [ $((i % 100)) -eq 0 ]; then
        echo -ne "\r  Progress: $i / $((KEY_COUNT / 5))"
    fi
done

END=$(date +%s)
DURATION=$((END - START))

echo -ne "\r"
echo -e "${GREEN}[OK]${NC} Generated $((KEY_COUNT / 5)) string keys in ${DURATION}s"
echo ""

################################################################################
# Populate Hash Keys
################################################################################

echo -e "${YELLOW}[2/5]${NC} Populating hash keys..."

START=$(date +%s)

for i in $(seq 1 $((KEY_COUNT / 5))); do
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" HSET "hash:$i" \
        field1 "value1_$i" \
        field2 "value2_$i" \
        field3 "value3_$i" \
        >/dev/null 2>&1

    if [ $((i % 100)) -eq 0 ]; then
        echo -ne "\r  Progress: $i / $((KEY_COUNT / 5))"
    fi
done

END=$(date +%s)
DURATION=$((END - START))

echo -ne "\r"
echo -e "${GREEN}[OK]${NC} Generated $((KEY_COUNT / 5)) hash keys in ${DURATION}s"
echo ""

################################################################################
# Populate List Keys
################################################################################

echo -e "${YELLOW}[3/5]${NC} Populating list keys..."

START=$(date +%s)

for i in $(seq 1 $((KEY_COUNT / 5))); do
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" LPUSH "list:$i" \
        "item1_$i" "item2_$i" "item3_$i" "item4_$i" "item5_$i" \
        >/dev/null 2>&1

    if [ $((i % 100)) -eq 0 ]; then
        echo -ne "\r  Progress: $i / $((KEY_COUNT / 5))"
    fi
done

END=$(date +%s)
DURATION=$((END - START))

echo -ne "\r"
echo -e "${GREEN}[OK]${NC} Generated $((KEY_COUNT / 5)) list keys in ${DURATION}s"
echo ""

################################################################################
# Populate Set Keys
################################################################################

echo -e "${YELLOW}[4/5]${NC} Populating set keys..."

START=$(date +%s)

for i in $(seq 1 $((KEY_COUNT / 5))); do
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" SADD "set:$i" \
        "member1_$i" "member2_$i" "member3_$i" \
        >/dev/null 2>&1

    if [ $((i % 100)) -eq 0 ]; then
        echo -ne "\r  Progress: $i / $((KEY_COUNT / 5))"
    fi
done

END=$(date +%s)
DURATION=$((END - START))

echo -ne "\r"
echo -e "${GREEN}[OK]${NC} Generated $((KEY_COUNT / 5)) set keys in ${DURATION}s"
echo ""

################################################################################
# Populate Sorted Set Keys
################################################################################

echo -e "${YELLOW}[5/5]${NC} Populating sorted set keys..."

START=$(date +%s)

for i in $(seq 1 $((KEY_COUNT / 5))); do
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ZADD "zset:$i" \
        1 "member1_$i" 2 "member2_$i" 3 "member3_$i" \
        >/dev/null 2>&1

    if [ $((i % 100)) -eq 0 ]; then
        echo -ne "\r  Progress: $i / $((KEY_COUNT / 5))"
    fi
done

END=$(date +%s)
DURATION=$((END - START))

echo -ne "\r"
echo -e "${GREEN}[OK]${NC} Generated $((KEY_COUNT / 5)) sorted set keys in ${DURATION}s"
echo ""

################################################################################
# Summary
################################################################################

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Population Summary${NC}"
echo -e "${BLUE}========================================${NC}"

# Get database info
DB_INFO=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" INFO keyspace | grep "^db0:")

echo "Database: $DB_INFO"
echo ""

TOTAL_KEYS=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" DBSIZE)
echo "Total keys: $TOTAL_KEYS"

MEMORY=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" INFO memory | grep "used_memory_human:" | cut -d: -f2)
echo "Memory used: $MEMORY"

echo ""
echo -e "${GREEN}Data population complete!${NC}"
echo ""

################################################################################
# Load Mode (Continuous)
################################################################################

if [ "$LOAD_MODE" = "true" ]; then
    echo -e "${YELLOW}Entering continuous load mode...${NC}"
    echo "Press Ctrl+C to stop"
    echo ""

    COUNTER=0
    while true; do
        # Random operations
        OPERATION=$((RANDOM % 5))
        KEY="load:$((RANDOM % 1000))"

        case $OPERATION in
            0)
                redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" SET "$KEY" "value_$(date +%s)" >/dev/null 2>&1
                ;;
            1)
                redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" GET "$KEY" >/dev/null 2>&1
                ;;
            2)
                redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" INCR "counter:$((RANDOM % 100))" >/dev/null 2>&1
                ;;
            3)
                redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" LPUSH "queue:$((RANDOM % 10))" "item_$(date +%s)" >/dev/null 2>&1
                ;;
            4)
                redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" LPOP "queue:$((RANDOM % 10))" >/dev/null 2>&1
                ;;
        esac

        COUNTER=$((COUNTER + 1))

        if [ $((COUNTER % 100)) -eq 0 ]; then
            echo -ne "\r  Operations: $COUNTER"
        fi

        # Small delay to avoid overwhelming
        sleep 0.01
    done
fi
