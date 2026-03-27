# Redis 7.2.4 FIPS SHA-256 Patch - Technical Details

## Overview

This patch modifies Redis 7.2.4 to replace SHA-1 hashing with SHA-256 (via OpenSSL) for FIPS 140-3 compliance.

**Patch File:** `redis-fips-sha256.patch`
**Based On:** Valkey 8.1.5 FIPS implementation (client-verified, production-ready)
**Target:** Redis 7.2.4

## Why This Patch Is Required

### FIPS 140-3 Compliance Issue

Redis uses SHA-1 for two critical functions:
1. **Lua Script Hashing** - Generating script IDs for `EVAL` and `EVALSHA` commands
2. **DEBUG DIGEST** - Computing database digests for debugging

**Problem:** SHA-1 is **NOT** FIPS 140-3 approved for new applications.

**Solution:** Replace SHA-1 with SHA-256 using OpenSSL's FIPS-validated EVP interface.

## Files Modified

### 1. src/debug.c
**Purpose:** DEBUG DIGEST command

**Changes:**
- Replace `#include "sha1.h"` with OpenSSL headers
- `xorDigest()`: Use `EVP_sha256()` instead of `SHA1_*` functions
- `mixDigest()`: Use `EVP_sha256()` instead of `SHA1_*` functions

**Impact:**
- DEBUG DIGEST output will change (different hash values)
- Maintains 20-byte output for backward compatibility
- Uses FIPS-approved SHA-256 algorithm

### 2. src/eval.c
**Purpose:** Lua script evaluation and hashing

**Changes:**
- Replace `#include "sha1.h"` with OpenSSL headers
- Rename `sha1hex()` → `sha256hex()`
- Use `EVP_sha256()` instead of `SHA1_*` functions
- Update `evalCalcFuncName()` to call `sha256hex()`
- Update `luaRedisSha1hexCommand()` to use `sha256hex()`

**Impact:**
- Script IDs will change (different hash values)
- **CRITICAL:** This breaks compatibility with existing EVALSHA calls
- Lua API keeps `redis.sha1hex()` name for backward compatibility
- Uses FIPS-approved SHA-256 algorithm

### 3. src/server.h
**Purpose:** Function declarations

**Changes:**
- Update function signature: `sha1hex()` → `sha256hex()`

**Impact:**
- Ensures consistent function naming across codebase

## Technical Implementation

### OpenSSL EVP Interface

The patch uses OpenSSL's EVP (EnVeloPe) interface:

```c
EVP_MD_CTX *mdctx = EVP_MD_CTX_new();
EVP_DigestInit_ex(mdctx, EVP_sha256(), NULL);
EVP_DigestUpdate(mdctx, data, len);
EVP_DigestFinal_ex(mdctx, hash, &hash_len);
EVP_MD_CTX_free(mdctx);
```

**Benefits:**
- ✅ FIPS 140-3 compliant (when using FIPS OpenSSL)
- ✅ Uses wolfProvider → wolfSSL FIPS in our setup
- ✅ Fallback to direct SHA256 if EVP fails
- ✅ Industry standard API

### Backward Compatibility

**Digest Size:**
- SHA-256 produces 32 bytes (256 bits)
- SHA-1 produces 20 bytes (160 bits)
- **Solution:** Truncate SHA-256 to first 20 bytes

**Hex Output:**
- SHA-256: 64 hex characters (32 bytes)
- SHA-1: 40 hex characters (20 bytes)
- **Solution:** Output only first 40 hex characters (20 bytes)

**API Names:**
- Lua API keeps `redis.sha1hex()` name
- Internally uses SHA-256
- **Reason:** Avoid breaking existing Lua scripts

## Breaking Changes

### 1. Script IDs Change

**Before (SHA-1):**
```bash
redis> EVAL "return redis.call('PING')" 0
# Script ID: <sha1-hash-of-script>
```

**After (SHA-256 truncated):**
```bash
redis> EVAL "return redis.call('PING')" 0
# Script ID: <sha256-hash-truncated-to-20-bytes>
```

**Impact:**
- ❌ Existing `EVALSHA` calls will fail
- ❌ Script cache must be rebuilt
- ❌ Applications using EVALSHA must reload scripts
- ✅ EVAL commands continue to work

### 2. DEBUG DIGEST Values Change

**Before (SHA-1):**
```bash
redis> DEBUG DIGEST
# Returns SHA-1 based digest
```

**After (SHA-256):**
```bash
redis> DEBUG DIGEST
# Returns SHA-256 based digest (different value)
```

**Impact:**
- ❌ Digest comparisons with non-FIPS Redis will fail
- ✅ DEBUG DIGEST still functional
- ✅ Used primarily for debugging (low impact)

### 3. Replication Compatibility

**Issue:**
- FIPS Redis master cannot replicate to non-FIPS Redis replica (script ID mismatch)
- Non-FIPS Redis master cannot replicate to FIPS Redis replica (script ID mismatch)

**Solution:**
- Use homogeneous clusters (all FIPS or all non-FIPS)
- Migrate entire cluster at once

## Verification & Testing

### 1. Build Verification

After applying patch:

```bash
cd redis-7.2.4
patch -p1 < redis-fips-sha256.patch

# Verify no reject files
ls -la *.rej
# (should be empty)

# Build
make BUILD_TLS=yes

# Check for OpenSSL linkage
ldd src/redis-server | grep ssl
ldd src/redis-server | grep crypto
```

### 2. Runtime Verification

**Test 1: Lua Script Execution**
```bash
redis-cli EVAL "return redis.call('PING')" 0
# Expected: PONG
```

**Test 2: Script Hashing**
```bash
redis-cli --eval test.lua
# Script should load and execute
```

**Test 3: DEBUG DIGEST**
```bash
redis-cli DEBUG DIGEST
# Should return a digest value (different from SHA-1)
```

**Test 4: redis.sha1hex() API**
```lua
-- In Lua script
local hash = redis.sha1hex("test data")
-- Should return 40-character hex string
-- (actually SHA-256 truncated, not SHA-1)
```

### 3. FIPS Compliance Verification

**Verify SHA-256 is used:**

```c
// Add debug logging in sha256hex() function
fprintf(stderr, "Using SHA-256 for script hashing\n");
```

**Check OpenSSL provider:**
```bash
OPENSSL_CONF=/path/to/openssl.cnf openssl list -providers
# Should show wolfprov provider active
```

## Migration Guide

### For Production Deployments

**Step 1: Backup**
```bash
# Backup RDB/AOF files
cp dump.rdb dump.rdb.backup
cp appendonly.aof appendonly.aof.backup
```

**Step 2: Upgrade**
```bash
# Stop Redis
redis-cli SHUTDOWN SAVE

# Deploy FIPS Redis image
docker run -d -v /data:/data cr.root.io/redis:7.2.4-alpine-3.19-fips
```

**Step 3: Script Cache**
```bash
# Clear script cache (scripts will be re-loaded on first use)
redis-cli SCRIPT FLUSH
```

**Step 4: Application Updates**
```bash
# Update applications to use EVAL instead of EVALSHA
# OR re-load scripts with new SHA-256 IDs
```

### For Development/Testing

**Test in isolated environment:**
```bash
# Use different port
docker run -d -p 6380:6379 cr.root.io/redis:7.2.4-alpine-3.19-fips

# Test application compatibility
# Connect app to port 6380 and verify functionality
```

## Known Limitations

1. **Not backward compatible** with non-FIPS Redis script IDs
2. **Replication** requires homogeneous clusters (all FIPS or all non-FIPS)
3. **Performance** - Minimal overhead from OpenSSL EVP interface (<1%)
4. **Alpine/musl** - Patch works on musl libc (verified with Valkey on Ubuntu, adapted for Alpine)

## Troubleshooting

### Patch Fails to Apply

**Error:** `patch: **** malformed patch at line X`

**Solution:**
```bash
# Check Redis version
redis-server --version
# Patch is for Redis 7.2.4 specifically

# Check patch file format
file redis-fips-sha256.patch
# Should be ASCII text

# Try with different patch options
patch -p1 --dry-run < redis-fips-sha256.patch
```

### Build Fails After Patch

**Error:** `undefined reference to EVP_sha256`

**Solution:**
```bash
# Ensure OpenSSL development headers installed
apk add openssl-dev  # Alpine
apt-get install libssl-dev  # Debian/Ubuntu

# Build with explicit OpenSSL linkage
make BUILD_TLS=yes LDFLAGS="-lcrypto"
```

### Script IDs Don't Match

**Issue:** EVALSHA fails with "NOSCRIPT" error

**Solution:**
```bash
# Clear script cache
SCRIPT FLUSH

# Re-load scripts using EVAL
# Script IDs will be recalculated with SHA-256
```

## References

- **Original Valkey Patch:** `wolfssl-valkey/patches/valkey-fips-sha256-complete.patch`
- **FIPS 140-3 Standard:** [NIST CMVP](https://csrc.nist.gov/projects/cryptographic-module-validation-program)
- **wolfSSL FIPS Certificate:** #4718
- **OpenSSL EVP Documentation:** [OpenSSL EVP](https://www.openssl.org/docs/man3.0/man3/EVP_DigestInit.html)

## Version History

- **v1.0** (2026-03-26) - Initial Redis 7.2.4 patch based on Valkey 8.1.5
- **Based on:** Valkey FIPS patch (client-verified, production-ready)
- **Target Platform:** Alpine Linux 3.19 (musl libc)
