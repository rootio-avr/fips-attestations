#!/bin/sh
################################################################################
# Redis FIPS Pub/Sub Subscriber Demo
# Subscribes to Redis channels and displays received messages
################################################################################

HOST="${REDIS_HOST:-localhost}"
PORT="${REDIS_PORT:-6379}"
CHANNEL="${CHANNEL:-demo-channel}"

echo "Redis Pub/Sub Subscriber Demo"
echo "=============================="
echo "Host: $HOST:$PORT"
echo "Channel: $CHANNEL"
echo ""
echo "Listening for messages (Ctrl+C to stop)..."
echo ""

# Subscribe to channel
redis-cli -h "$HOST" -p "$PORT" SUBSCRIBE "$CHANNEL"
