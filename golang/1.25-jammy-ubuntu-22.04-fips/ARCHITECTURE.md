# Technical Architecture Documentation

Comprehensive technical architecture documentation for the golang-fips FIPS 140-3 container.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Component Layers](#component-layers)
3. [golang-fips/go Architecture](#golang-fipsgo-architecture)
4. [CGO Architecture](#cgo-architecture)
5. [Security Architecture](#security-architecture)
6. [Build Architecture](#build-architecture)
7. [Deployment Architecture](#deployment-architecture)
8. [Data Flow Examples](#data-flow-examples)
9. [Comparison with Standard Go](#comparison-with-standard-go)

---

## Architecture Overview

### High-Level System Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                       Application Layer                          │
│  User Go Application (standard crypto/* packages)               │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ↓
┌──────────────────────────────────────────────────────────────────┐
│                   golang-fips/go Runtime                         │
│  - Modified Go compiler and runtime                              │
│  - Build-time instrumentation (GOEXPERIMENT=strictfipsruntime)  │
│  - Runtime enforcement (GODEBUG=fips140=only)                   │
│  - Panic injection for non-FIPS algorithms                      │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ↓
┌──────────────────────────────────────────────────────────────────┐
│                       CGO Bridge Layer                            │
│  - Go ↔ C interoperability (cgo)                                │
│  - Type conversion (Go types ↔ C types)                         │
│  - Memory management across boundaries                          │
│  - Dynamic library loading (dlopen/dlsym)                       │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ↓
┌──────────────────────────────────────────────────────────────────┐
│                      OpenSSL 3.x Layer                            │
│  OpenSSL 3.0.19 (system library, dynamically loaded)            │
│  - Provider management                                           │
│  - Algorithm dispatch                                            │
│  - FIPS mode configuration                                       │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ↓
┌──────────────────────────────────────────────────────────────────┐
│                    wolfProvider v1.1.0                            │
│  OpenSSL 3.x Provider (libwolfprov.so)                          │
│  - Bridges OpenSSL 3.x to wolfSSL                               │
│  - Named "fips" for golang-fips/go discovery                    │
│  - Implements EVP_* interfaces                                  │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ↓
┌──────────────────────────────────────────────────────────────────┐
│         FIPS 140-3 Validated Cryptographic Module                │
│  libwolfssl.so (wolfSSL FIPS v5.8.2, Certificate #4718)        │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │ FIPS Boundary                                              │  │
│  │ ┌──────────────┬──────────────┬──────────────────────────┐ │  │
│  │ │ wolfCrypt    │ wolfSSL TLS  │ wolfCrypt FIPS Module    │ │  │
│  │ │ Algorithms   │ Protocol     │ (validated)              │ │  │
│  │ └──────────────┴──────────────┴──────────────────────────┘ │  │
│  │ - Power-On Self Test (POST)                                │  │
│  │ - In-core integrity verification                           │  │
│  │ - FIPS-approved algorithms only                            │  │
│  │ - SHA-1 blocked at compile time (--disable-sha)            │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

### Architecture Principles

1. **Standard Go APIs**: Application code uses unmodified `crypto/*` and `crypto/tls` packages
2. **golang-fips Fork**: Modified Go runtime routes crypto operations through OpenSSL
3. **CGO Boundary**: Clean separation between Go and native C code
4. **Dynamic OpenSSL Loading**: OpenSSL loaded via dlopen at runtime
5. **FIPS Boundary**: All crypto operations within FIPS-validated wolfSSL module
6. **Multi-Layer Enforcement**: 4 independent layers enforce FIPS compliance

### Key Differences from Standard Go

| Aspect | Standard Go | golang-fips/go |
|--------|-------------|----------------|
| Crypto Implementation | Pure Go (crypto/*) | OpenSSL via CGO |
| FIPS Validation | None | wolfSSL FIPS #4718 |
| Algorithm Blocking | Warnings only | Runtime panics |
| Build Dependency | None | Requires OpenSSL 3.x |
| Runtime Dependency | None | Requires OpenSSL, wolfProvider, wolfSSL |
| Performance | Optimized Go code | Native OpenSSL performance |

---

## Component Layers

### Layer 1: Application Layer

**Purpose**: User application code

**Components**:
- Custom Go applications
- Third-party Go libraries
- Standard Go SE packages

**Characteristics**:
- No awareness of FIPS implementation
- Uses standard `crypto/*`, `crypto/tls`, `crypto/x509` packages
- No code changes required for FIPS compliance

**Example**:
```go
// Standard code - no FIPS-specific modifications
package main

import (
    "crypto/sha256"
    "fmt"
)

func main() {
    h := sha256.New()
    h.Write([]byte("test data"))
    hash := h.Sum(nil)
    fmt.Printf("SHA-256: %x\n", hash)
}
```

### Layer 2: golang-fips/go Runtime

**Purpose**: Modified Go runtime with FIPS support

**Source**: https://github.com/golang-fips/go (fork of golang/go)

**Version**: 1.25

**Key Modifications**:
1. **OpenSSL Integration**: crypto/* packages call OpenSSL instead of pure Go implementations
2. **CGO Dependency**: All crypto operations use CGO to call native OpenSSL
3. **FIPS Provider Discovery**: Searches for "fips" provider in OpenSSL at initialization
4. **ChaCha20 Removal**: Non-FIPS ChaCha20-Poly1305 cipher suite removed
5. **Panic Instrumentation**: Injected panic points for non-FIPS algorithms

**Build-Time Configuration**:
- `CGO_ENABLED=1` - Required for OpenSSL integration
- `GOEXPERIMENT=strictfipsruntime` - Enables panic instrumentation

**Runtime Configuration**:
- `GOLANG_FIPS=1` - Activates FIPS mode
- `GODEBUG=fips140=only` - Triggers panics for non-FIPS operations
- `OPENSSL_CONF=/etc/ssl/openssl.cnf` - OpenSSL configuration path

**crypto Package Routing**:
```
Standard Go:     crypto/sha256.New() → Pure Go implementation
golang-fips/go:  crypto/sha256.New() → CGO → OpenSSL EVP_sha256()
```

### Layer 3: CGO Bridge Layer

**Purpose**: Go ↔ C interoperability

**Mechanism**: CGO (Go's foreign function interface)

**Responsibilities**:
- Translate Go crypto calls to C OpenSSL API calls
- Type conversion between Go and C types
- Memory management across language boundaries
- Dynamic library loading and symbol resolution

**Key Files**:
- Located in golang-fips/go fork: `src/crypto/internal/backend/openssl/*`
- Implements: `crypto/sha256`, `crypto/aes`, `crypto/rsa`, `crypto/ecdsa`, etc.

**CGO Call Example**:
```go
// Go side (crypto/sha256/sha256.go in golang-fips/go)
package sha256

// #cgo pkg-config: libcrypto
// #include <openssl/evp.h>
import "C"
import "unsafe"

type digest struct {
    ctx *C.EVP_MD_CTX
}

func (d *digest) Write(p []byte) (int, error) {
    if len(p) > 0 {
        C.EVP_DigestUpdate(d.ctx, unsafe.Pointer(&p[0]), C.size_t(len(p)))
    }
    return len(p), nil
}

func (d *digest) Sum(in []byte) []byte {
    hash := make([]byte, Size)
    C.EVP_DigestFinal_ex(d.ctx, (*C.uchar)(unsafe.Pointer(&hash[0])), nil)
    return append(in, hash...)
}
```

### Layer 4: OpenSSL 3.x Layer

**Purpose**: Cryptographic provider framework

**Component**: OpenSSL 3.0.19

**Location**:
- Libraries: `/usr/lib/x86_64-linux-gnu/libssl.so.3`, `libcrypto.so.3`
- Binary: `/usr/bin/openssl`
- Configuration: `/etc/ssl/openssl.cnf`

**Responsibilities**:
- Provider lifecycle management (load, initialize, use)
- Algorithm dispatch to active providers
- FIPS mode enforcement (fips=yes property)
- Dynamic provider loading

**Provider Configuration** (`openssl.cnf`):
```ini
openssl_conf = openssl_init

[openssl_init]
providers = provider_sect
alg_section = algorithm_sect

[provider_sect]
# Provider named "fips" for golang-fips/go discovery
fips = fips_sect

[fips_sect]
activate = 1
module = /usr/lib/x86_64-linux-gnu/ossl-modules/libwolfprov.so

[algorithm_sect]
default_properties = fips=yes
rh-allow-sha1-signatures = no
```

**Provider Discovery Flow**:
```
golang-fips/go initialization
    ↓
OSSL_PROVIDER_try_load(NULL, "fips")  // Searches for "fips" provider
    ↓
OpenSSL reads /etc/ssl/openssl.cnf
    ↓
Finds provider_sect.fips = fips_sect
    ↓
Loads module: libwolfprov.so
    ↓
Activates wolfProvider
    ↓
All crypto operations route to wolfProvider → wolfSSL
```

### Layer 5: wolfProvider

**Purpose**: Bridge OpenSSL 3.x to wolfSSL

**Component**: wolfProvider v1.1.0

**Source**: https://github.com/wolfSSL/wolfProvider

**Location**: `/usr/lib/x86_64-linux-gnu/ossl-modules/libwolfprov.so`

**Responsibilities**:
- Implement OpenSSL 3.x provider interface
- Translate EVP_* calls to wolfSSL API
- Manage wolfSSL context and state
- Handle provider queries and algorithm availability

**Critical Configuration**:
- **Must be named "fips"** in openssl.cnf for golang-fips/go compatibility
- golang-fips/go hardcodes: `OSSL_PROVIDER_try_load(NULL, "fips")`
- Original name "libwolfprov" is incompatible - renamed via config

**Provider Interface**:
```c
// Implemented by wolfProvider (simplified)
const OSSL_DISPATCH wp_sha256_functions[] = {
    { OSSL_FUNC_DIGEST_NEWCTX,     (void (*)(void))wp_sha256_newctx },
    { OSSL_FUNC_DIGEST_UPDATE,     (void (*)(void))wp_sha256_update },
    { OSSL_FUNC_DIGEST_FINAL,      (void (*)(void))wp_sha256_final },
    { 0, NULL }
};

// Routes to wolfSSL
static int wp_sha256_update(WP_SHA256_CTX *ctx, const unsigned char *data, size_t len) {
    return wc_Sha256Update(&ctx->sha256, data, len);  // wolfSSL call
}
```

### Layer 6: wolfSSL FIPS Module

**Purpose**: FIPS-validated cryptographic operations

**Component**: libwolfssl.so

**Details**:
- Version: wolfSSL FIPS v5.8.2
- Certificate: FIPS 140-3 #4718
- Location: `/usr/local/lib/libwolfssl.so.42`
- Build Options:
  - `--enable-fips=v5` (FIPS 140-3 mode)
  - `--disable-sha` (Block SHA-1 at library level)
  - `--enable-opensslcoexist` (Coexist with system OpenSSL)

**FIPS Boundary**:
- All cryptographic operations occur within this module
- In-core integrity verification on load
- Power-On Self Test (POST) executed on first use
- Only FIPS-approved algorithms accessible
- SHA-1 physically removed from library

**Approved Algorithms** (FIPS 140-3):
- **Symmetric**: AES-128, AES-192, AES-256
- **Modes**: CBC, CTR, GCM, CCM
- **Hash**: SHA-224, SHA-256, SHA-384, SHA-512, SHA3-224/256/384/512
- **MAC**: HMAC (SHA-*), CMAC (AES)
- **Asymmetric**: RSA (2048/3072/4096), ECDSA (P-256/384/521)
- **Key Agreement**: ECDH, DH
- **Random**: Hash_DRBG, HMAC_DRBG

**Blocked Algorithms**:
- **MD5**: Deprecated, not FIPS-approved
- **SHA-1**: Compiled out with `--disable-sha`
- **DES/3DES**: Weak, not FIPS-approved
- **RC4**: Insecure stream cipher
- **ChaCha20**: Not FIPS-approved

---

## golang-fips/go Architecture

### Fork Overview

**Repository**: https://github.com/golang-fips/go

**Base**: golang/go (official Go repository)

**Modifications**:
1. Replace pure Go crypto implementations with OpenSSL calls
2. Add CGO bindings to OpenSSL EVP_* APIs
3. Inject panic points for non-FIPS algorithm detection
4. Remove ChaCha20-Poly1305 cipher suite from TLS
5. Add FIPS provider discovery on initialization

### Build-Time Enforcement

**GOEXPERIMENT=strictfipsruntime**

**Purpose**: Instrument code with panic points

**Effect**:
```go
// Without strictfipsruntime
func md5Hash(data []byte) []byte {
    h := md5.New()
    h.Write(data)
    return h.Sum(nil)
}

// With strictfipsruntime
func md5Hash(data []byte) []byte {
    if os.Getenv("GODEBUG") contains "fips140=only" {
        panic("crypto/md5: use of MD5 in FIPS mode")
    }
    h := md5.New()
    h.Write(data)
    return h.Sum(nil)
}
```

**Compiler Changes**:
- Adds runtime checks before non-FIPS operations
- Checks `GODEBUG` environment variable
- Panics with descriptive error messages

### Runtime Enforcement

**GODEBUG=fips140=only**

**Purpose**: Activate injected panic points

**Mechanism**:
1. Environment variable checked by instrumented code
2. If set, panics are triggered for non-FIPS algorithms
3. If not set, warnings printed (fallback behavior)

**Example Panic**:
```
panic: crypto/md5: use of MD5 in FIPS mode

goroutine 1 [running]:
crypto/md5.New()
    /usr/local/go-fips/src/crypto/md5/md5.go:25
main.testMD5()
    /app/main.go:67
main.main()
    /app/main.go:62
```

### FIPS Provider Discovery

**golang-fips/go Initialization**:
```c
// In golang-fips/go runtime (simplified)
void runtime_openssl_init(void) {
    // Load OpenSSL configuration
    OPENSSL_init_crypto(OPENSSL_INIT_LOAD_CONFIG, NULL);

    // Try to load "fips" provider (critical!)
    OSSL_PROVIDER *fips_prov = OSSL_PROVIDER_try_load(NULL, "fips");
    if (fips_prov == NULL) {
        fprintf(stderr, "FIPS provider not available\n");
        exit(1);
    }

    // Verify FIPS mode
    if (!EVP_default_properties_is_fips_enabled(NULL)) {
        fprintf(stderr, "FIPS mode not enabled\n");
        exit(1);
    }
}
```

**Why "fips" Name Matters**:
- golang-fips/go hardcodes: `OSSL_PROVIDER_try_load(NULL, "fips")`
- wolfProvider is named "libwolfprov" by default
- **Solution**: Rename via `openssl.cnf` provider configuration
- `fips = fips_sect` → maps "fips" name to libwolfprov.so module

### ChaCha20 Removal

**Reason**: ChaCha20-Poly1305 is not FIPS-approved

**Implementation**:
```go
// In golang-fips/go: crypto/tls/cipher_suites.go

// Standard Go includes:
// TLS_CHACHA20_POLY1305_SHA256 = 0x1303

// golang-fips/go removes ChaCha20 entirely:
var cipherSuites = []*cipherSuite{
    {TLS_AES_128_GCM_SHA256, 16, 0, 12, aeadAESGCMTLS13, nil, nil},
    {TLS_AES_256_GCM_SHA384, 32, 0, 12, aeadAESGCMTLS13, nil, nil},
    // TLS_CHACHA20_POLY1305_SHA256 removed
}
```

**Effect**: TLS connections only use AES-GCM cipher suites

---

## CGO Architecture

### CGO Call Lifecycle

**Example**: SHA-256 hashing

```
1. Go Application
   package main
   import "crypto/sha256"

   func main() {
       h := sha256.New()
       h.Write([]byte("test"))
       hash := h.Sum(nil)
   }

2. golang-fips/go crypto/sha256
   // File: src/crypto/sha256/sha256_openssl.go
   package sha256

   // #cgo pkg-config: libcrypto
   // #include <openssl/evp.h>
   import "C"
   import "unsafe"

   type digest struct {
       ctx *C.EVP_MD_CTX
   }

   func New() hash.Hash {
       d := &digest{
           ctx: C.EVP_MD_CTX_new(),
       }
       C.EVP_DigestInit_ex(d.ctx, C.EVP_sha256(), nil)
       return d
   }

   func (d *digest) Write(p []byte) (int, error) {
       if len(p) > 0 {
           C.EVP_DigestUpdate(d.ctx,
               unsafe.Pointer(&p[0]),
               C.size_t(len(p)))
       }
       return len(p), nil
   }

3. CGO Bridge (generated by Go compiler)
   // Auto-generated C wrapper
   void _cgo_EVP_DigestUpdate(EVP_MD_CTX *ctx, void *data, size_t len) {
       EVP_DigestUpdate(ctx, data, len);
   }

4. OpenSSL 3.x (libcrypto.so.3)
   int EVP_DigestUpdate(EVP_MD_CTX *ctx, const void *data, size_t count) {
       // Dispatch to active provider
       return ctx->pctx->pmeth->digest_update(ctx, data, count);
   }

5. wolfProvider (libwolfprov.so)
   static int wp_sha256_update(WP_SHA256_CTX *ctx,
                               const unsigned char *data,
                               size_t len) {
       // Call wolfSSL
       return wc_Sha256Update(&ctx->sha256, data, len);
   }

6. wolfSSL FIPS (libwolfssl.so)
   int wc_Sha256Update(wc_Sha256* sha256, const byte* data, word32 len) {
       // FIPS-validated SHA-256 implementation
       // Inside FIPS boundary
   }
```

### Memory Management

**Go to C**:
```go
// Go slice
data := []byte("hello world")

// CGO pointer rules:
// 1. Go pointer passed to C must not contain pointers
// 2. C cannot store Go pointers
// 3. C must not call back into Go (unless via callback mechanism)

// Safe pattern:
C.EVP_DigestUpdate(ctx, unsafe.Pointer(&data[0]), C.size_t(len(data)))
// Pointer is temporary, only valid during C call
```

**C to Go**:
```go
// C allocates memory
cData := C.malloc(C.size_t(256))
defer C.free(cData)

// Convert to Go slice
goData := C.GoBytes(cData, 256)  // Copies data
```

**Context Lifecycle**:
```go
type digest struct {
    ctx *C.EVP_MD_CTX  // C pointer stored in Go struct
}

func New() hash.Hash {
    d := &digest{
        ctx: C.EVP_MD_CTX_new(),  // Allocate in C
    }
    runtime.SetFinalizer(d, func(d *digest) {
        C.EVP_MD_CTX_free(d.ctx)  // Free when Go GC runs
    })
    return d
}
```

### Dynamic Library Loading

**dlopen at Runtime**:
```go
// #cgo LDFLAGS: -ldl
// #include <dlfcn.h>
import "C"

func loadOpenSSL() {
    // Load libcrypto.so at runtime
    handle := C.dlopen(C.CString("libcrypto.so.3"), C.RTLD_LAZY)
    if handle == nil {
        panic("Failed to load OpenSSL")
    }

    // Resolve symbols
    evp_sha256 := C.dlsym(handle, C.CString("EVP_sha256"))
}
```

**Library Search Path**:
```bash
# LD_LIBRARY_PATH determines search order
LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:/usr/local/lib

# Search order:
# 1. /usr/lib/x86_64-linux-gnu/libcrypto.so.3
# 2. /usr/local/lib/libwolfssl.so.42
```

### Error Handling

**OpenSSL Errors → Go Errors**:
```go
func (d *digest) Write(p []byte) (int, error) {
    if len(p) > 0 {
        ret := C.EVP_DigestUpdate(d.ctx,
            unsafe.Pointer(&p[0]),
            C.size_t(len(p)))
        if ret != 1 {
            // OpenSSL error occurred
            err := C.ERR_get_error()
            errStr := C.GoString(C.ERR_error_string(err, nil))
            return 0, errors.New("OpenSSL error: " + errStr)
        }
    }
    return len(p), nil
}
```

**wolfSSL Errors → OpenSSL Errors → Go Errors**:
```
wolfSSL: returns negative error code (e.g., -173 = BAD_FUNC_ARG)
    ↓
wolfProvider: translates to OpenSSL error code
    ↓
OpenSSL: adds to error queue (ERR_put_error)
    ↓
CGO: reads error queue (ERR_get_error)
    ↓
Go: converts to Go error
```

---

## Security Architecture

### FIPS Boundary

```
┌─────────────────────────────────────────────────────────┐
│                  FIPS Boundary                          │
│  ┌───────────────────────────────────────────────────┐  │
│  │ libwolfssl.so (wolfSSL FIPS v5.8.2)              │  │
│  │                                                   │  │
│  │  - wolfCrypt FIPS Module (validated)             │  │
│  │  - FIPS-approved algorithms only                 │  │
│  │  - SHA-1 removed at compile time                 │  │
│  │  - In-core integrity check                       │  │
│  │  - Power-On Self Test (POST)                     │  │
│  │                                                   │  │
│  │  Input: Plaintext, keys, parameters              │  │
│  │  Output: Ciphertext, hashes, signatures          │  │
│  │                                                   │  │
│  │  ❌ No external crypto operations                 │  │
│  │  ❌ No algorithm bypass                          │  │
│  │  ❌ SHA-1 not available (--disable-sha)          │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
         ↑                                    ↓
    Input data                           Output data
    (via wolfProvider)                   (via wolfProvider)
```

### Multi-Layer Enforcement

This implementation uses **4 independent layers** of FIPS enforcement:

```
Layer 1: Runtime Panic (golang-fips/go + GODEBUG)
┌─────────────────────────────────────────┐
│ if GODEBUG=fips140=only {               │
│     panic("MD5 not allowed in FIPS")    │
│ }                                       │
└─────────────────────────────────────────┘
         ↓ (if bypassed)

Layer 2: Build-Time Instrumentation (GOEXPERIMENT=strictfipsruntime)
┌─────────────────────────────────────────┐
│ Compiler injects panic points during    │
│ build for all non-FIPS algorithms       │
└─────────────────────────────────────────┘
         ↓ (if bypassed)

Layer 3: OpenSSL Provider Configuration (fips=yes)
┌─────────────────────────────────────────┐
│ default_properties = fips=yes           │
│ rh-allow-sha1-signatures = no           │
└─────────────────────────────────────────┘
         ↓ (if bypassed)

Layer 4: wolfSSL Library (--disable-sha)
┌─────────────────────────────────────────┐
│ SHA-1 code physically removed from      │
│ libwolfssl.so at compile time           │
│ → LIBRARY DOES NOT CONTAIN SHA-1        │
└─────────────────────────────────────────┘
         ↓
     BLOCKED (impossible to bypass)
```

**Defense-in-Depth**:
- Each layer is independent
- Bypassing one layer still encounters remaining layers
- Layer 4 (library removal) is absolute - cannot be bypassed

**Example: Attempting MD5**:
1. **Layer 1**: `panic: crypto/md5: use of MD5 in FIPS mode` (if GODEBUG set)
2. **Layer 2**: Panic injected at build time (if GOEXPERIMENT used)
3. **Layer 3**: OpenSSL rejects MD5 (not in FIPS provider)
4. **Layer 4**: wolfSSL doesn't provide MD5 (not FIPS-approved, but available)

**Example: Attempting SHA-1**:
1. **Layer 1**: `panic: crypto/sha1: use of SHA-1 in FIPS mode` (if GODEBUG set)
2. **Layer 2**: Panic injected at build time (if GOEXPERIMENT used)
3. **Layer 3**: OpenSSL configuration blocks SHA-1 signatures
4. **Layer 4**: `wc_InitSha` function **does not exist** in libwolfssl.so (compiled with `--disable-sha`)

### Power-On Self Test (POST)

**Execution**:
1. First cryptographic operation triggers POST in wolfSSL
2. Tests all FIPS-approved algorithms
3. Verifies known-answer tests (KATs)
4. On failure, module enters error state

**POST Trigger**:
```go
// In main.go or first crypto operation
package main
import "crypto/sha256"

func main() {
    // First call triggers wolfSSL POST
    h := sha256.New()
    h.Write([]byte("test"))
    _ = h.Sum(nil)  // ← POST executes in wolfSSL

    fmt.Println("FIPS POST completed successfully")
}
```

**POST Failure**:
```
panic: crypto/sha256: OpenSSL error: error:1C800064:Provider routines::bad decrypt

This indicates wolfSSL FIPS POST failed (known-answer test mismatch)
Possible causes:
- Library tampering
- Incorrect build flags
- Memory corruption
```

### Integrity Verification

**Build-Time** (wolfSSL):
```bash
# During wolfSSL FIPS build
cd wolfssl-5.8.2-fips
./configure --enable-fips=v5 ...
make
./fips-hash.sh  # ← Generates integrity hash
make            # ← Rebuilds with embedded hash
```

**Runtime** (wolfSSL):
```c
// In libwolfssl.so initialization
int wolfCrypt_Init(void) {
    // Verify in-core integrity
    if (DoIntegrityCheck() != 0) {
        return FIPS_INTEGRITY_E;  // Fails if library modified
    }
    // Continue initialization
}
```

**Container Verification**:
```bash
# Verify library checksums
sha256sum -c <<EOF
<expected_hash>  /usr/local/lib/libwolfssl.so.42
<expected_hash>  /usr/lib/x86_64-linux-gnu/ossl-modules/libwolfprov.so
<expected_hash>  /usr/lib/x86_64-linux-gnu/libcrypto.so.3
EOF
```

---

## Build Architecture

### Multi-Stage Build Process

```dockerfile
# Stage 1: wolfSSL FIPS Build (Ubuntu 22.04 base)
FROM ubuntu:22.04 AS wolfssl-builder
# - Download wolfssl-5.8.2-commercial-fips (7z archive)
# - Extract with password from build secret
# - Build with --enable-fips=v5 --disable-sha
# - Run fips-hash.sh for integrity
# Output: libwolfssl.so.42 → /usr/local/lib/

# Stage 2: wolfProvider Build
FROM ubuntu:22.04 AS wolfprov-builder
# - Copy OpenSSL 3.0.19 from wolfssl-builder
# - Copy libwolfssl from wolfssl-builder
# - Clone wolfProvider v1.1.0
# - Build wolfProvider linked to wolfSSL
# Output: libwolfprov.so → /usr/lib/x86_64-linux-gnu/ossl-modules/

# Stage 3: golang-fips/go Build
FROM ubuntu:22.04 AS go-builder
# - Copy OpenSSL and wolfSSL from previous stages
# - Clone golang-fips/go v1.25
# - Remove ChaCha20 cipher suite
# - Build Go toolchain with CGO_ENABLED=1
# - Set GOEXPERIMENT=strictfipsruntime
# Output: /usr/local/go-fips/ (full toolchain)

# Stage 4: Application Build
FROM go-builder AS app-builder
# - Copy application source (main.go)
# - Compile with GOEXPERIMENT=strictfipsruntime
# - Link against OpenSSL
# Output: /app/fips-go-demo (binary)

# Stage 5: Runtime Image
FROM ubuntu:22.04
# - Copy libwolfssl.so from wolfssl-builder
# - Copy libwolfprov.so from wolfprov-builder
# - Copy OpenSSL 3.0.19 from wolfssl-builder
# - Copy golang-fips/go toolchain from go-builder
# - Copy compiled binary from app-builder
# - Set environment: GOLANG_FIPS=1, GODEBUG=fips140=only
# - Configure openssl.cnf
```

### Build Dependencies

```
OpenSSL 3.0.19 Source Build
   ↓ (libssl.so.3, libcrypto.so.3)
wolfSSL FIPS v5.8.2 Build ← requires OpenSSL headers
   ↓ (libwolfssl.so.42)
wolfProvider v1.1.0 Build ← requires OpenSSL + wolfSSL
   ↓ (libwolfprov.so)
golang-fips/go v1.25 Build ← requires OpenSSL headers
   ↓ (/usr/local/go-fips/)
Application Build ← requires golang-fips/go toolchain
   ↓ (fips-go-demo binary)
Runtime Image Assembly ← combines all artifacts
```

### Critical Build Flags

**wolfSSL**:
```bash
./configure \
    --enable-fips=v5 \                 # FIPS 140-3 mode
    --disable-sha \                    # Remove SHA-1 (critical!)
    --enable-opensslcoexist \          # Coexist with system OpenSSL
    --enable-keygen \                  # Key generation support
    --enable-aesctr \                  # AES-CTR mode
    CPPFLAGS="-DHAVE_AES_ECB ..."
```

**wolfProvider**:
```bash
./configure \
    --with-openssl=/usr \              # OpenSSL 3.0.19 location
    --with-wolfssl=/usr/local \        # wolfSSL FIPS location
    --prefix=/usr/local
```

**golang-fips/go**:
```bash
CGO_ENABLED=1 \
GOEXPERIMENT=strictfipsruntime \       # Inject panic instrumentation
./make.bash
```

**Application**:
```bash
GOEXPERIMENT=strictfipsruntime \       # Match build flag
CGO_ENABLED=1 \
go build -o fips-go-demo main.go
```

---

## Deployment Architecture

### Container Startup Flow

```
Docker Container Start
    ↓
Execute docker-entrypoint.sh
    ↓
Set Environment Variables
    ↓
┌─────────────────────────────────────────┐
│ GOLANG_FIPS=1                           │
│ GODEBUG=fips140=only                   │
│ GOEXPERIMENT=strictfipsruntime         │
│ OPENSSL_CONF=/etc/ssl/openssl.cnf      │
│ LD_LIBRARY_PATH=/usr/local/lib:...     │
└─────────────────────────────────────────┘
    ↓
Run FIPS Validation (if enabled)
    ↓
Execute User Command (e.g., /app/fips-go-demo)
```

### Library Loading Sequence

```
Application Starts (/app/fips-go-demo)
    ↓
Go Runtime Initialization
    ↓
golang-fips/go calls runtime_openssl_init()
    ↓
┌─ Load OpenSSL Configuration
│   ↓
│   Read OPENSSL_CONF=/etc/ssl/openssl.cnf
│   ↓
│   Parse provider_sect: fips = fips_sect
│   ↓
│   Load module: /usr/lib/x86_64-linux-gnu/ossl-modules/libwolfprov.so
│   ↓
│   dlopen("libwolfprov.so", RTLD_LAZY)
│   ↓
│   Resolve wolfProvider dependencies
│   ↓
│   dlopen("/usr/local/lib/libwolfssl.so.42", RTLD_LAZY)
│   ↓
│   Execute wolfCrypt_Init()
│   ↓
│   Perform in-core integrity check
│   ↓
│   Register for POST on first crypto operation
│
└─ wolfProvider loaded and activated
    ↓
OSSL_PROVIDER_try_load(NULL, "fips")
    ↓
Verify provider is active and FIPS mode enabled
    ↓
┌─ If successful: Continue execution
│   ↓
│   Application ready for crypto operations
│
└─ If failed: Abort with error
    ↓
    "FIPS provider not available"
    exit(1)
```

### Environment Variables

| Variable | Value | Purpose |
|----------|-------|---------|
| `GOLANG_FIPS` | `1` | Activate FIPS mode in golang-fips/go |
| `GODEBUG` | `fips140=only` | Trigger panics for non-FIPS algorithms |
| `GOEXPERIMENT` | `strictfipsruntime` | Indicates binary built with instrumentation |
| `OPENSSL_CONF` | `/etc/ssl/openssl.cnf` | OpenSSL configuration file path |
| `LD_LIBRARY_PATH` | `/usr/local/lib:...` | Library search path |
| `CGO_ENABLED` | `1` | Required for CGO support |
| `GOROOT` | `/usr/local/go-fips` | golang-fips/go installation path |

### OpenSSL Configuration

**File**: `/etc/ssl/openssl.cnf`

```ini
openssl_conf = openssl_init

[openssl_init]
providers = provider_sect
alg_section = algorithm_sect

[provider_sect]
# CRITICAL: Named "fips" for golang-fips/go discovery
fips = fips_sect

[fips_sect]
activate = 1
module = /usr/lib/x86_64-linux-gnu/ossl-modules/libwolfprov.so

[algorithm_sect]
# Enforce FIPS mode for all operations
default_properties = fips=yes

# Block SHA-1 signatures
rh-allow-sha1-signatures = no
```

**Why This Matters**:
- `fips = fips_sect` → Maps "fips" name to wolfProvider module
- golang-fips/go hardcodes: `OSSL_PROVIDER_try_load(NULL, "fips")`
- Without this mapping, FIPS provider not found → initialization fails

---

## Data Flow Examples

### Example 1: SHA-256 Hashing

```
Application Code:
    package main
    import "crypto/sha256"

    func main() {
        h := sha256.New()
        h.Write([]byte("test data"))
        hash := h.Sum(nil)
    }

↓ golang-fips/go Runtime

crypto/sha256 Package:
    // File: src/crypto/sha256/sha256_openssl.go
    package sha256

    // #cgo pkg-config: libcrypto
    // #include <openssl/evp.h>
    import "C"

    type digest struct {
        ctx *C.EVP_MD_CTX
    }

    func New() hash.Hash {
        d := &digest{ctx: C.EVP_MD_CTX_new()}
        C.EVP_DigestInit_ex(d.ctx, C.EVP_sha256(), nil)
        return d
    }

    func (d *digest) Write(p []byte) (int, error) {
        C.EVP_DigestUpdate(d.ctx, unsafe.Pointer(&p[0]), C.size_t(len(p)))
        return len(p), nil
    }

    func (d *digest) Sum(in []byte) []byte {
        hash := make([]byte, Size)
        C.EVP_DigestFinal_ex(d.ctx, (*C.uchar)(&hash[0]), nil)
        return append(in, hash...)
    }

↓ CGO Bridge

    // Auto-generated wrapper
    _cgo_EVP_DigestUpdate(ctx, data, len)

↓ OpenSSL 3.x (libcrypto.so.3)

    int EVP_DigestUpdate(EVP_MD_CTX *ctx, const void *data, size_t len) {
        // Dispatch to active provider ("fips" = wolfProvider)
        return ctx->pctx->pmeth->digest_update(ctx, data, len);
    }

↓ wolfProvider (libwolfprov.so)

    static int wp_sha256_update(WP_SHA256_CTX *ctx,
                               const unsigned char *data,
                               size_t len) {
        // Call wolfSSL
        return wc_Sha256Update(&ctx->sha256, data, len);
    }

↓ FIPS Boundary

wolfSSL FIPS (libwolfssl.so.42):
    int wc_Sha256Update(wc_Sha256* sha256, const byte* data, word32 len) {
        // FIPS 140-3 validated SHA-256 implementation
        // All operations within FIPS boundary
        // First call triggers POST if not already run
    }

↓ Return hash

Application receives SHA-256 digest
```

### Example 2: AES-256-GCM Encryption

```
Application Code:
    package main
    import (
        "crypto/aes"
        "crypto/cipher"
    )

    func main() {
        key := make([]byte, 32)  // AES-256 key
        // ... generate key ...

        block, _ := aes.NewCipher(key)
        gcm, _ := cipher.NewGCM(block)

        nonce := make([]byte, gcm.NonceSize())
        ciphertext := gcm.Seal(nil, nonce, plaintext, nil)
    }

↓ golang-fips/go Runtime

crypto/aes Package:
    // Uses OpenSSL EVP_aes_256_gcm()
    func NewCipher(key []byte) (cipher.Block, error) {
        c := &aesCipher{
            ctx: C.EVP_CIPHER_CTX_new(),
        }
        C.EVP_EncryptInit_ex(c.ctx, C.EVP_aes_256_gcm(), nil, nil, nil)
        C.EVP_CIPHER_CTX_set_key_length(c.ctx, C.int(len(key)))
        return c, nil
    }

↓ CGO → OpenSSL → wolfProvider → wolfSSL

wolfSSL FIPS (libwolfssl.so.42):
    int wc_AesGcmEncrypt(Aes* aes, byte* out, const byte* in, word32 sz,
                        const byte* iv, word32 ivSz,
                        byte* authTag, word32 authTagSz,
                        const byte* authIn, word32 authInSz) {
        // FIPS 140-3 validated AES-GCM implementation
        // Inside FIPS boundary
    }

↓ Return encrypted data

Application receives ciphertext + authentication tag
```

### Example 3: TLS Connection

```
Application Code:
    package main
    import (
        "crypto/tls"
        "net/http"
    )

    func main() {
        client := &http.Client{
            Transport: &http.Transport{
                TLSClientConfig: &tls.Config{
                    MinVersion: tls.VersionTLS12,
                },
            },
        }
        resp, _ := client.Get("https://example.com")
    }

↓ golang-fips/go TLS Stack

crypto/tls Package:
    // TLS handshake using OpenSSL
    // - Key exchange: ECDH (via OpenSSL)
    // - Cipher: AES-256-GCM (via OpenSSL)
    // - MAC: SHA-384 (via OpenSSL)

    // Available cipher suites (ChaCha20 removed):
    - TLS_AES_128_GCM_SHA256
    - TLS_AES_256_GCM_SHA384
    - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
    - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384

↓ All crypto operations route through OpenSSL → wolfProvider → wolfSSL

wolfSSL FIPS:
    int wolfSSL_connect(WOLFSSL* ssl) {
        // TLS handshake implementation
        // - ClientHello
        // - Key exchange (ECDH - FIPS approved)
        // - Certificate verification (RSA/ECDSA)
        // - Cipher negotiation (AES-GCM only)
        // - All operations in FIPS boundary
    }

↓ Return TLS connection

Application: Secure HTTPS connection established
```

---

## Comparison with Standard Go

### Crypto Stack Comparison

| Layer | Standard Go | golang-fips/go |
|-------|-------------|----------------|
| **Application** | `crypto/sha256` | `crypto/sha256` (same) |
| **Implementation** | Pure Go code | CGO → OpenSSL |
| **Library** | `crypto/sha256/sha256block_amd64.s` | `libcrypto.so.3` (OpenSSL) |
| **Provider** | N/A | `libwolfprov.so` (wolfProvider) |
| **FIPS Module** | N/A | `libwolfssl.so.42` (wolfSSL FIPS) |
| **Validation** | None | FIPS 140-3 #4718 |

### Algorithm Availability

| Algorithm | Standard Go | golang-fips/go (GODEBUG=fips140=only) |
|-----------|-------------|----------------------------------------|
| **MD5** | ✅ Available (warning) | ❌ PANIC |
| **SHA-1** | ✅ Available (warning) | ❌ PANIC + BLOCKED at library |
| **SHA-256** | ✅ Pure Go | ✅ OpenSSL → wolfSSL FIPS |
| **SHA-384** | ✅ Pure Go | ✅ OpenSSL → wolfSSL FIPS |
| **SHA-512** | ✅ Pure Go | ✅ OpenSSL → wolfSSL FIPS |
| **AES** | ✅ Pure Go / asm | ✅ OpenSSL → wolfSSL FIPS |
| **RSA** | ✅ Pure Go | ✅ OpenSSL → wolfSSL FIPS |
| **ECDSA** | ✅ Pure Go | ✅ OpenSSL → wolfSSL FIPS |
| **ChaCha20** | ✅ Available | ❌ Removed from TLS |

### Performance Considerations

**Standard Go**:
- Pure Go implementations optimized for Go runtime
- Assembly optimizations for common architectures (amd64, arm64)
- No CGO overhead
- No external dependencies

**golang-fips/go**:
- CGO overhead for every crypto operation
- Native OpenSSL/wolfSSL performance (highly optimized C code)
- Additional function call layers (CGO → OpenSSL → wolfProvider → wolfSSL)
- External library dependencies

**Typical Overhead**:
- Small operations (single hash): 10-30% slower (CGO overhead dominates)
- Large operations (bulk encryption): 0-20% faster (native code efficiency)
- TLS handshakes: Similar performance (both use native implementations)

### Build and Runtime Requirements

| Aspect | Standard Go | golang-fips/go |
|--------|-------------|----------------|
| **Build Dependency** | None | OpenSSL 3.x headers, wolfSSL headers |
| **Runtime Dependency** | None | OpenSSL 3.x, wolfProvider, wolfSSL FIPS |
| **CGO Requirement** | Optional | **Required** (`CGO_ENABLED=1`) |
| **Cross-Compilation** | Easy | Difficult (needs target OpenSSL) |
| **Binary Size** | ~10-20 MB | ~15-25 MB (includes CGO overhead) |
| **Deployment** | Single binary | Binary + libraries (3 .so files) |

---

## Additional Resources

- **[README.md](README.md)** - General documentation and usage
- **[POC-VALIDATION-REPORT.md](POC-VALIDATION-REPORT.md)** - FIPS validation evidence
- **[SECTION-6-CHECKLIST.md](../SECTION-6-CHECKLIST.md)** - Compliance checklist
- **golang-fips/go**: https://github.com/golang-fips/go
- **wolfSSL FIPS**: https://www.wolfssl.com/products/fips/
- **wolfProvider**: https://github.com/wolfSSL/wolfProvider

---

**Last Updated**: 2026-03-16
**Version**: 1.0
**golang-fips/go Version**: 1.25
**wolfSSL FIPS Version**: v5.8.2 (Certificate #4718)
**OpenSSL Version**: 3.0.19
**wolfProvider Version**: v1.1.0
