#!/bin/bash
################################################################################
# Redis Exporter FIPS - Main Demo Runner
#
# This script orchestrates the full demo:
# 1. Starts Redis server
# 2. Validates FIPS compliance
# 3. Starts redis_exporter
# 4. Populates test data
# 5. Displays metrics
# 6. Runs interactive demo
#
# Usage:
#   ./run-demo.sh
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

################################################################################
# Banner
################################################################################

echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║         Redis Exporter FIPS - Interactive Demo               ║
║                                                               ║
║  Demonstrates FIPS 140-3 compliant Redis monitoring with:    ║
║  - wolfSSL FIPS v5.8.2 (CMVP Certificate #4718)              ║
║  - golang-fips/go v1.25                                      ║
║  - Prometheus metrics export                                  ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"
echo ""

################################################################################
# Step 1: FIPS Validation
################################################################################

echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo -e "${CYAN}Step 1/5: FIPS Validation${NC}"
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo ""

/demo/scripts/test-fips-enforcement.sh

echo ""

################################################################################
# Step 2: Start Redis Server
################################################################################

echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo -e "${CYAN}Step 2/5: Starting Redis Server${NC}"
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo ""

# Check if Redis is already running
if redis-cli -h localhost -p 6379 ping >/dev/null 2>&1; then
    echo -e "${GREEN}[OK]${NC} Redis is already running"
else
    echo -e "${YELLOW}[INFO]${NC} Starting Redis server..."
    redis-server /demo/configs/redis.conf &
    REDIS_PID=$!
    echo "Redis PID: $REDIS_PID"

    # Wait for Redis to start
    echo -n "Waiting for Redis to start..."
    for i in {1..30}; do
        if redis-cli -h localhost -p 6379 ping >/dev/null 2>&1; then
            echo ""
            echo -e "${GREEN}[OK]${NC} Redis started successfully"
            break
        fi
        echo -n "."
        sleep 1
    done
    echo ""
fi

# Verify Redis
REDIS_VERSION=$(redis-cli -h localhost -p 6379 INFO server | grep "redis_version:" | cut -d: -f2 | tr -d '\r')
echo "Redis version: $REDIS_VERSION"

echo ""

################################################################################
# Step 3: Start Redis Exporter
################################################################################

echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo -e "${CYAN}Step 3/5: Starting Redis Exporter${NC}"
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo ""

# Check if exporter is already running
if curl -s http://localhost:9121/metrics >/dev/null 2>&1; then
    echo -e "${GREEN}[OK]${NC} Redis Exporter is already running"
else
    echo -e "${YELLOW}[INFO]${NC} Starting redis_exporter..."
    redis_exporter \
        --redis.addr=redis://localhost:6379 \
        --web.listen-address=:9121 \
        --web.telemetry-path=/metrics \
        --log-format=txt \
        &> /demo/logs/exporter.log &
    EXPORTER_PID=$!
    echo "Exporter PID: $EXPORTER_PID"

    # Wait for exporter to start
    echo -n "Waiting for exporter to start..."
    for i in {1..30}; do
        if curl -s http://localhost:9121/metrics >/dev/null 2>&1; then
            echo ""
            echo -e "${GREEN}[OK]${NC} Exporter started successfully"
            break
        fi
        echo -n "."
        sleep 1
    done
    echo ""
fi

# Verify exporter
EXPORTER_VERSION=$(redis_exporter --version 2>&1 | head -1 || echo "unknown")
echo "Exporter version: $EXPORTER_VERSION"

echo ""

################################################################################
# Step 4: Populate Test Data
################################################################################

echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo -e "${CYAN}Step 4/5: Populating Test Data${NC}"
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo ""

/demo/scripts/populate-test-data.sh --small

echo ""

################################################################################
# Step 5: Display Metrics
################################################################################

echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo -e "${CYAN}Step 5/5: Metrics Overview${NC}"
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo ""

/demo/scripts/test-metrics.sh

echo ""

################################################################################
# Interactive Demo Menu
################################################################################

echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                     Demo is Ready!                            ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"
echo ""

echo "Available endpoints:"
echo -e "  ${GREEN}Metrics:${NC}  http://localhost:9121/metrics"
echo -e "  ${GREEN}Redis:${NC}    localhost:6379"
echo ""

echo "Quick commands:"
echo -e "  ${YELLOW}curl http://localhost:9121/metrics${NC}"
echo -e "  ${YELLOW}redis-cli -h localhost -p 6379 INFO${NC}"
echo -e "  ${YELLOW}redis-cli -h localhost -p 6379 DBSIZE${NC}"
echo ""

echo "Test scripts:"
echo -e "  ${CYAN}/demo/scripts/test-fips-enforcement.sh${NC}  - FIPS validation"
echo -e "  ${CYAN}/demo/scripts/test-metrics.sh${NC}           - Metrics validation"
echo -e "  ${CYAN}/demo/scripts/populate-test-data.sh${NC}     - Generate more data"
echo ""

echo "Interactive mode:"
echo -e "  Press ${YELLOW}[Enter]${NC} to see live metrics (Ctrl+C to stop)"
read -r

################################################################################
# Live Metrics Display
################################################################################

echo -e "${YELLOW}Live Metrics (updating every 5 seconds)${NC}"
echo "Press Ctrl+C to stop"
echo ""

while true; do
    clear

    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║           Redis Exporter FIPS - Live Metrics                  ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Timestamp
    echo -e "${CYAN}Updated:${NC} $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    # FIPS Status
    echo -e "${YELLOW}FIPS Status:${NC}"
    echo -e "  GOLANG_FIPS: ${GREEN}${GOLANG_FIPS:-not set}${NC}"
    echo -e "  GODEBUG: ${GREEN}${GODEBUG:-not set}${NC}"
    echo ""

    # Redis Status
    echo -e "${YELLOW}Redis Status:${NC}"
    REDIS_UP=$(curl -s http://localhost:9121/metrics | grep "^redis_up " | awk '{print $2}')
    if [ "$REDIS_UP" = "1" ]; then
        echo -e "  Status: ${GREEN}UP${NC}"
    else
        echo -e "  Status: ${RED}DOWN${NC}"
    fi

    CONNECTED_CLIENTS=$(curl -s http://localhost:9121/metrics | grep "^redis_connected_clients " | awk '{print $2}')
    echo -e "  Connected clients: ${GREEN}${CONNECTED_CLIENTS:-0}${NC}"

    TOTAL_KEYS=$(redis-cli -h localhost -p 6379 DBSIZE 2>/dev/null || echo "0")
    echo -e "  Total keys: ${GREEN}${TOTAL_KEYS}${NC}"

    MEMORY=$(redis-cli -h localhost -p 6379 INFO memory 2>/dev/null | grep "used_memory_human:" | cut -d: -f2 | tr -d '\r')
    echo -e "  Memory used: ${GREEN}${MEMORY}${NC}"

    echo ""

    # Command Stats
    echo -e "${YELLOW}Commands (last 5 sec):${NC}"
    TOTAL_COMMANDS=$(curl -s http://localhost:9121/metrics | grep "^redis_commands_total " | head -5)
    echo "$TOTAL_COMMANDS" | while read -r line; do
        CMD=$(echo "$line" | grep -o 'cmd="[^"]*"' | cut -d'"' -f2)
        COUNT=$(echo "$line" | awk '{print $2}')
        echo -e "  ${CMD}: ${GREEN}${COUNT}${NC}"
    done

    echo ""

    # Exporter Stats
    echo -e "${YELLOW}Exporter Stats:${NC}"
    SCRAPE_DURATION=$(curl -s http://localhost:9121/metrics | grep "^redis_exporter_last_scrape_duration_seconds " | awk '{print $2}')
    echo -e "  Last scrape duration: ${GREEN}${SCRAPE_DURATION}s${NC}"

    echo ""
    echo -e "${CYAN}Next update in 5 seconds...${NC}"

    sleep 5
done
