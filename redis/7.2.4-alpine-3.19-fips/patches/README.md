# Redis 7.2.4 FIPS Patches

This directory contains patches required for FIPS 140-3 compliance.

## Patches

### redis-fips-sha256.patch ✅

**Purpose:** Replace SHA-1 with SHA-256 for FIPS compliance

**Status:** Ready for use (adapted from Valkey 8.1.5)

**Background:**
Redis uses SHA-1 for Lua script hashing and DEBUG DIGEST commands. SHA-1 is not FIPS 140-3 approved for new applications.

**Changes:**
1. **Lua Script Hashing** (`eval.c`):
   - Replace built-in SHA-1 with OpenSSL SHA-256
   - Rename `sha1hex()` function to `sha256hex()`
   - Ensures all Lua script identifiers use FIPS-approved hashing
   - Uses OpenSSL EVP interface for FIPS compliance

2. **DEBUG DIGEST** (`debug.c`):
   - Replace SHA-1 with OpenSSL SHA-256 for digest command
   - Update `xorDigest()` and `mixDigest()` functions
   - Maintains debugging functionality with FIPS compliance

3. **Function Declarations** (`server.h`):
   - Update function signatures: `sha1hex()` → `sha256hex()`
   - Maintain API consistency

**Based On:**
- Valkey 8.1.5 FIPS patch (proven and client-verified)
- Production-ready implementation from wolfssl-valkey project

**Compatibility:**
- **Target:** Redis 7.2.4
- **Platform:** Alpine Linux 3.19 (musl libc)
- **OpenSSL:** 3.x with EVP interface
- **Breaking Change:** Script IDs will differ from non-FIPS Redis

## Documentation

See **[PATCH-DETAILS.md](PATCH-DETAILS.md)** for comprehensive documentation including:
- Technical implementation details
- Breaking changes and migration guide
- Verification and testing procedures
- Troubleshooting guide
- Known limitations

## Applying Patches

Patches are automatically applied during Docker build:

```dockerfile
# In Dockerfile
COPY patches/redis-fips-sha256.patch /tmp/
RUN cd /tmp/redis-${REDIS_VERSION} && \
    patch -p1 < /tmp/redis-fips-sha256.patch
```

## Manual Application

For development/testing:

```bash
# Extract Redis source
wget http://download.redis.io/releases/redis-7.2.4.tar.gz
tar xzf redis-7.2.4.tar.gz
cd redis-7.2.4

# Apply patch
patch -p1 < ../patches/redis-fips-sha256.patch

# Verify patch applied
git diff src/eval.c src/debug.c src/server.h
```

## Verification

After applying patches:

1. **Build succeeds** - No compilation errors
2. **Lua scripts work** - Script execution functional
3. **SHA-256 used** - Verify with OpenSSL calls
4. **DEBUG DIGEST works** - Command still functional
5. **FIPS POST passes** - No non-FIPS crypto used

## Testing

Test Lua script hashing:
```bash
# Start Redis
redis-server

# Test EVAL (uses hashing internally)
redis-cli EVAL "return redis.call('PING')" 0

# Expected: PONG
# Internally: Uses SHA-256 for script ID
```

Test DEBUG DIGEST:
```bash
redis-cli DEBUG DIGEST
# Expected: Returns digest using SHA-256
```

## Important Notes

- **Critical for FIPS:** Without this patch, Redis uses SHA-1 (non-FIPS)
- **Backward compatibility:** Script IDs change from SHA-1 to SHA-256
- **Replication:** All nodes must use same hash algorithm
- **Tested:** Based on Valkey implementation (production-ready)

## Source

Adapted from:
- `wolfssl-valkey/patches/valkey-fips-sha256-complete.patch`
- Valkey 8.1.5 FIPS implementation (client-verified)
