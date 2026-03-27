#!/bin/sh
################################################################################
# Redis FIPS Pub/Sub Publisher Demo
# Publishes messages to Redis channels for demonstration
################################################################################

HOST="${REDIS_HOST:-localhost}"
PORT="${REDIS_PORT:-6379}"
CHANNEL="${CHANNEL:-demo-channel}"
MESSAGE_COUNT="${MESSAGE_COUNT:-10}"
DELAY="${DELAY:-1}"

echo "Redis Pub/Sub Publisher Demo"
echo "=============================="
echo "Host: $HOST:$PORT"
echo "Channel: $CHANNEL"
echo "Messages: $MESSAGE_COUNT"
echo "Delay: ${DELAY}s"
echo ""

count=1
while [ $count -le $MESSAGE_COUNT ]; do
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    message="Message #$count at $timestamp"

    # Publish message
    result=$(redis-cli -h "$HOST" -p "$PORT" PUBLISH "$CHANNEL" "$message" 2>&1)

    if [ $? -eq 0 ]; then
        echo "[Published] $message (subscribers: $result)"
    else
        echo "[Error] Failed to publish: $result"
    fi

    count=$((count + 1))

    if [ $count -le $MESSAGE_COUNT ]; then
        sleep "$DELAY"
    fi
done

echo ""
echo "Publishing completed: $MESSAGE_COUNT messages sent"
