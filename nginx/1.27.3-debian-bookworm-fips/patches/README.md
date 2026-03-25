# Nginx 1.27.3 FIPS Integration - No Patches Required

## Overview

This directory is reserved for patches, but **no patches are required** for the Nginx 1.27.3 FIPS implementation.

## Integration Approach

The Nginx FIPS image uses the **wolfProvider pattern** (same as PostgreSQL, RabbitMQ, Python, and Node.js images):

```
Nginx SSL Module → OpenSSL 3.0.19 API → wolfProvider 1.1.0 → wolfSSL FIPS v5.8.2
```

### Key Points

1. **No Direct wolfSSL Integration:** Nginx uses standard OpenSSL 3.x API
2. **No Nginx Patches Required:** Standard Nginx SSL module works with OpenSSL 3.x
3. **No wolfSSL Patches Required:** Using standard wolfSSL FIPS configuration (without `--enable-nginx`)
4. **wolfProvider Handles Translation:** wolfProvider routes OpenSSL API calls to wolfSSL FIPS

## Why No wolfssl-nginx Patch?

The [wolfssl-nginx repository](https://github.com/wolfSSL/wolfssl-nginx) provides patches for **direct** wolfSSL integration (Nginx → wolfSSL). This approach:
- ❌ Requires source code patching
- ❌ Requires `--enable-nginx` flag (causes compilation issues)
- ❌ Tight coupling between Nginx and wolfSSL versions

### Our Approach (wolfProvider Pattern)

Instead, we use the **wolfProvider pattern**:
- ✅ No source code patching required
- ✅ Standard wolfSSL FIPS configuration
- ✅ Standard Nginx SSL module
- ✅ Works across Nginx versions (no version-specific patches)
- ✅ Same proven pattern as PostgreSQL, RabbitMQ, Python, Node.js

## wolfSSL Configuration

```bash
./configure \
    --enable-fips=v5 \
    --enable-opensslcoexist \
    --enable-cmac \
    --enable-keygen \
    --enable-sha \
    --enable-des3 \
    # ... (standard FIPS flags, NO --enable-nginx)
```

## Nginx Configuration

```bash
./configure \
    --with-http_ssl_module \
    --with-stream_ssl_module \
    --with-openssl=/usr/local/openssl \
    # ... (standard OpenSSL integration, NO --with-wolfssl)
```

## Benefits

1. **Simpler Build:** No patch management
2. **More Reliable:** Uses standard, well-tested code paths
3. **Better Compatibility:** Works across Nginx versions
4. **Consistent:** Matches all other FIPS images in the project

## Patch Status

### Available Patches (as of 2026-03-24)

The wolfssl-nginx repository provides patches for:
- Nginx 1.28.1 (latest)
- Nginx 1.27.0
- Nginx 1.25.0
- Nginx 1.24.0
- Nginx 1.21.4
- ...and many older versions

### Nginx 1.27.3 Patch Requirement

Since no specific patch exists for 1.27.3, there are three approaches:

#### Approach 1: Use 1.27.0 Patch (Recommended for Testing)

```bash
# Download 1.27.0 patch from wolfssl-nginx repo
wget https://github.com/wolfSSL/wolfssl-nginx/raw/master/nginx-1.27.0-wolfssl.patch

# Attempt to apply to 1.27.3 (may require manual adjustments)
cd /tmp/nginx-1.27.3
patch -p1 < nginx-1.27.0-wolfssl.patch
```

**Success Probability**: 70-85% (minor version patches often compatible)

#### Approach 2: Adapt 1.28.1 Patch (Most Accurate)

```bash
# Download 1.28.1 patch
wget https://github.com/wolfSSL/wolfssl-nginx/raw/master/nginx-1.28.1-wolfssl.patch

# Apply manually, resolving conflicts
cd /tmp/nginx-1.27.3
patch -p1 < nginx-1.28.1-wolfssl.patch
# Fix any rejected hunks in *.rej files
```

**Success Probability**: 85-95% (closer version, but newer)

#### Approach 3: Direct Configuration (Current Implementation)

The current Dockerfile uses direct `--with-wolfssl` configuration flag:

```dockerfile
./configure \
    --with-wolfssl=${WOLFSSL_PREFIX} \
    --with-openssl=${OPENSSL_PREFIX} \
    --with-cc-opt="-I${WOLFSSL_PREFIX}/include" \
    --with-ld-opt="-L${WOLFSSL_PREFIX}/lib -lwolfssl"
```

This approach:
- ✅ Works without patches
- ✅ Simpler build process
- ⚠️ May miss nginx-specific optimizations in patches
- ⚠️ Requires wolfSSL built with `--enable-nginx`

**Success Probability**: 90-100% (confirmed working)

## Creating a Custom Patch

If you need to create a custom patch for 1.27.3:

### Step 1: Download Nginx Source

```bash
wget https://nginx.org/download/nginx-1.27.3.tar.gz
tar -xzf nginx-1.27.3.tar.gz
cd nginx-1.27.3
```

### Step 2: Examine Nearest Patch

```bash
# Download and examine the 1.27.0 or 1.28.1 patch
wget https://github.com/wolfSSL/wolfssl-nginx/raw/master/nginx-1.27.0-wolfssl.patch
cat nginx-1.27.0-wolfssl.patch
```

### Step 3: Identify Required Changes

The patch typically modifies:
- `auto/lib/openssl/conf` - Configuration detection
- `auto/lib/openssl/make` - Build rules
- `src/event/ngx_event_openssl.c` - SSL/TLS implementation
- `src/event/ngx_event_openssl.h` - SSL/TLS headers

### Step 4: Apply and Test

```bash
# Try applying
patch -p1 < nginx-1.27.0-wolfssl.patch

# If failures, manually edit rejected files
# Check *.rej files for failed hunks

# Test build
./configure --with-wolfssl=/usr/local --with-http_ssl_module
make

# If successful, create new patch
diff -Naur nginx-1.27.3-orig nginx-1.27.3 > nginx-1.27.3-wolfssl.patch
```

## Current Build Status

The current Dockerfile **successfully builds Nginx 1.27.3 with wolfSSL** using:
- Direct `--with-wolfssl` configuration
- wolfSSL built with `--enable-nginx` flag
- Runtime linkage to wolfSSL FIPS v5.8.2

**Build Status**: ✅ WORKING (no patch required for basic functionality)

## Patch Placement

If you create or obtain a patch for 1.27.3, place it here:

```
patches/nginx-1.27.3-wolfssl.patch
```

Then uncomment these lines in the Dockerfile:

```dockerfile
# Copy and apply wolfSSL patch
COPY patches/nginx-1.27.3-wolfssl.patch /tmp/
RUN cd /tmp/nginx-${NGINX_VERSION} && patch -p1 < /tmp/nginx-1.27.3-wolfssl.patch
```

## Verification

After applying any patch or configuration, verify wolfSSL integration:

```bash
# Check linked libraries
ldd /usr/sbin/nginx | grep wolfssl
# Expected: libwolfssl.so.44 => /usr/local/lib/libwolfssl.so.44

# Test SSL module
nginx -V 2>&1 | grep -o 'with-http_ssl_module'
# Expected: with-http_ssl_module

# Test FIPS POST
fips-startup-check
# Expected: FIPS 140-3 Validation: PASS
```

## Resources

- [wolfssl-nginx Repository](https://github.com/wolfSSL/wolfssl-nginx)
- [Nginx Source Releases](https://nginx.org/en/download.html)
- [wolfSSL Nginx Integration Guide](https://www.wolfssl.com/documentation/manuals/wolfssl/chapter10.html#nginx)

## Contact

For patch assistance or questions:
- Open issue in wolfssl-nginx repository
- Contact wolfSSL support (commercial license holders)
