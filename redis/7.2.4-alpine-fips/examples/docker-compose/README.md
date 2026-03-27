# Docker Compose Deployment Example

## Quick Start

```bash
# 1. Update redis.conf with your password
sed -i 's/changeme_strong_password_here/YOUR_STRONG_PASSWORD/' redis.conf

# 2. Start Redis FIPS
docker-compose up -d

# 3. Check logs
docker-compose logs -f redis-fips

# 4. Test connection
docker-compose exec redis-fips redis-cli -a YOUR_STRONG_PASSWORD PING
```

## Configuration

Edit `redis.conf` to customize:
- **Password:** Change `requirepass`
- **Persistence:** Adjust `save` and `appendonly` settings
- **Memory:** Set `maxmemory` based on your needs
- **Network:** Configure `bind` for specific interfaces

## Persistence

Data is stored in the `redis-data` Docker volume. To backup:

```bash
# Backup RDB
docker-compose exec redis-fips redis-cli BGSAVE
docker cp redis-fips:/data/dump.rdb ./backup/

# Backup AOF
docker cp redis-fips:/data/appendonly.aof ./backup/
```

## Health Check

The health check runs every 10 seconds:

```bash
# Check status
docker-compose ps

# View health check logs
docker inspect redis-fips --format='{{.State.Health.Status}}'
```

## Scaling

For high availability, see the `examples/docker-compose-ha/` directory.
