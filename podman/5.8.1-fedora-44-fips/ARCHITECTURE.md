# Technical Architecture Documentation

Comprehensive technical architecture documentation for the Podman 5.8.1 FIPS 140-3 compliant container image.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Component Layers](#component-layers)
3. [Podman FIPS Integration](#podman-fips-integration)
4. [golang-fips/go Architecture](#golang-fipsgo-architecture)
5. [CGO Architecture](#cgo-architecture)
6. [Security Architecture](#security-architecture)
7. [Build Architecture](#build-architecture)
8. [Deployment Architecture](#deployment-architecture)
9. [Data Flow Examples](#data-flow-examples)
10. [Comparison with Standard Podman](#comparison-with-standard-podman)

---

## Architecture Overview

### High-Level System Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                       Podman Application Layer                   │
│  Podman v5.8.1 (container management platform)                  │
│  - Built from source with golang-fips/go v1.25                  │
│  - Uses standard Go crypto/* packages                           │
│  - Container operations, networking, storage                    │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ↓
┌──────────────────────────────────────────────────────────────────┐
│                   golang-fips/go Runtime v1.25                   │
│  - Modified Go compiler and runtime                              │
│  - Build-time instrumentation (GOEXPERIMENT=strictfipsruntime)  │
│  - Runtime enforcement (GODEBUG=fips140=only)                   │
│  - Panic injection for non-FIPS algorithms                      │
│  - CGO_ENABLED=1 for OpenSSL integration                        │
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
│                      OpenSSL 3.5.0 Layer                          │
│  OpenSSL 3.5.0 (system library, dynamically loaded)             │
│  - Provider management                                           │
│  - Algorithm dispatch                                            │
│  - FIPS mode configuration (fips=yes)                           │
│  - Three providers: fips, wolfssl, base                         │
└──────────────────────┬───────────────────────────────────────────┘
                       │
                       ↓
┌──────────────────────────────────────────────────────────────────┐
│                    wolfProvider v1.1.1                            │
│  OpenSSL 3.x Provider (libwolfprov.so)                          │
│  - Bridges OpenSSL 3.x to wolfSSL                               │
│  - Named "wolfssl" in openssl.cnf                               │
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
│  │ - Used for all Podman cryptographic operations             │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

### Architecture Principles

1. **Podman from Source**: Built from source using golang-fips/go for full FIPS integration
2. **Standard Go APIs**: Podman uses unmodified `crypto/*` and `crypto/tls` packages
3. **golang-fips Fork**: Modified Go runtime routes crypto operations through OpenSSL
4. **CGO Boundary**: Clean separation between Go and native C code
5. **Dynamic OpenSSL Loading**: OpenSSL loaded via dlopen at runtime
6. **FIPS Boundary**: All crypto operations within FIPS-validated wolfSSL module
7. **Runtime Enforcement**: FIPS mode activated via entrypoint.sh at container startup

### Key Differences from Standard Podman

| Aspect | Standard Podman | Podman FIPS |
|--------|-----------------|-------------|
| Build Method | Binary package (dnf/yum) | Source compilation |
| Go Compiler | Standard Go | golang-fips/go v1.25 |
| Crypto Implementation | Pure Go (crypto/*) | OpenSSL via CGO |
| FIPS Validation | None | wolfSSL FIPS #4718 |
| Algorithm Blocking | None | Runtime panics |
| Build Dependency | None | Requires OpenSSL 3.x, wolfSSL |
| Runtime Dependency | Minimal | OpenSSL, wolfProvider, wolfSSL |
| Performance | Optimized Go code | Native OpenSSL performance |
| FIPS Mode | Not available | Enforced via GODEBUG |

---

## Component Layers

### Layer 1: Podman Application Layer

**Purpose**: Container management platform

**Component**: Podman v5.8.1

**Source**: https://github.com/containers/podman (tag v5.8.1)

**Characteristics**:
- Built from source with golang-fips/go v1.25
- Uses standard `crypto/*`, `crypto/tls`, `crypto/x509` packages
- No Podman code changes required for FIPS compliance
- All cryptographic operations transparently use FIPS module

**Key Podman Components Using Crypto**:
- **Container Registry**: TLS connections for image pull/push
- **Image Verification**: Digital signatures and checksums
- **Secret Management**: Encryption of container secrets
- **Network Encryption**: Encrypted overlay networks
- **API Server**: HTTPS API endpoints

**Example**:
```go
// Podman source code (pkg/registries/pull.go)
package registries

import (
    "crypto/tls"
    "net/http"
)

func PullImage(registry string) error {
    // Standard Go TLS - no FIPS-specific modifications
    client := &http.Client{
        Transport: &http.Transport{
            TLSClientConfig: &tls.Config{
                MinVersion: tls.VersionTLS12,
            },
        },
    }
    // TLS automatically uses FIPS crypto via golang-fips/go
    resp, err := client.Get("https://" + registry + "/v2/")
    // ...
}
```

### Layer 2: Podman Runtime Dependencies

**Purpose**: Container runtime support

**Components**:
- **conmon** (v2.1.12): Container monitoring
- **crun** (v1.18.2): OCI runtime
- **slirp4netns** (v1.3.1): User-mode networking
- **fuse-overlayfs** (v1.14): FUSE overlay filesystem

**Location**:
- `/usr/sbin/conmon`
- `/usr/sbin/crun`
- `/usr/sbin/slirp4netns`
- `/usr/sbin/fuse-overlayfs`

**Characteristics**:
- Installed from Fedora 44 repositories
- Not directly involved in FIPS cryptographic operations
- Podman manages their execution
- Required for full Podman functionality

### Layer 3: golang-fips/go Runtime

**Purpose**: Modified Go runtime with FIPS support

**Source**: https://github.com/golang-fips/go (branch go1.25-fips-release)

**Version**: 1.25

**Installation**: `/usr/local/go-fips`

**Key Modifications**:
1. **OpenSSL Integration**: crypto/* packages call OpenSSL instead of pure Go implementations
2. **CGO Dependency**: All crypto operations use CGO to call native OpenSSL
3. **FIPS Provider Discovery**: Searches for "fips" provider in OpenSSL at initialization
4. **ChaCha20 Removal**: Non-FIPS ChaCha20-Poly1305 cipher suite removed
5. **Panic Instrumentation**: Injected panic points for non-FIPS algorithms

**Build-Time Configuration** (for Podman build):
- `CGO_ENABLED=1` - Required for OpenSSL integration
- `GOEXPERIMENT=strictfipsruntime` - Enables panic instrumentation
- **FIPS NOT enforced during build** - Allows Podman compilation

**Runtime Configuration** (via entrypoint.sh):
- `GOLANG_FIPS=1` - Activates FIPS mode
- `GODEBUG=fips140=only` - Triggers panics for non-FIPS operations
- `GOEXPERIMENT=strictfipsruntime` - Indicates build instrumentation
- `OPENSSL_CONF=/etc/ssl/openssl.cnf` - OpenSSL configuration path

**crypto Package Routing**:
```
Standard Go:        Podman → crypto/sha256.New() → Pure Go implementation
golang-fips/go:     Podman → crypto/sha256.New() → CGO → OpenSSL EVP_sha256() → wolfProvider → wolfSSL FIPS
```

### Layer 4: CGO Bridge Layer

**Purpose**: Go ↔ C interoperability

**Mechanism**: CGO (Go's foreign function interface)

**Responsibilities**:
- Translate Go crypto calls to C OpenSSL API calls
- Type conversion between Go and C types
- Memory management across language boundaries
- Dynamic library loading and symbol resolution

**Key Files** (in golang-fips/go):
- Located in: `src/crypto/internal/backend/openssl/*`
- Implements: `crypto/sha256`, `crypto/aes`, `crypto/rsa`, `crypto/ecdsa`, `crypto/tls`

**CGO Call Example** (SHA-256 in Podman):
```go
// When Podman uses crypto/sha256
// File: golang-fips/go/src/crypto/sha256/sha256_openssl.go

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

### Layer 5: OpenSSL 3.5.0 Layer

**Purpose**: Cryptographic provider framework

**Component**: OpenSSL 3.5.0

**Location**:
- Libraries: `/usr/local/openssl/lib64/libssl.so.3`, `libcrypto.so.3`
- Binary: `/usr/local/openssl/bin/openssl`
- Configuration: `/etc/ssl/openssl.cnf`
- FIPS Config: `/usr/local/openssl/ssl/fipsmodule.cnf`

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
fips = fips_sect
wolfssl = wolfssl_sect
base = base_sect

[fips_sect]
activate = 1
module = /usr/local/openssl/lib64/ossl-modules/fips.so
# Include the FIPS module configuration generated by openssl fipsinstall
.include /usr/local/openssl/ssl/fipsmodule.cnf

[wolfssl_sect]
activate = 1
module = /usr/local/openssl/lib64/ossl-modules/libwolfprov.so

[base_sect]
activate = 1

[algorithm_sect]
default_properties = fips=yes
```

**Three Providers**:
1. **fips**: OpenSSL's built-in FIPS provider (for golang-fips/go initialization)
2. **wolfssl**: wolfProvider (actual FIPS operations via wolfSSL)
3. **base**: Base provider (non-FIPS operations)

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
Loads module: fips.so
    ↓
Activates OpenSSL FIPS provider
    ↓
golang-fips/go satisfied, continues
    ↓
Also loads wolfssl provider from wolfssl_sect
    ↓
Operations route to wolfProvider → wolfSSL FIPS
```

### Layer 6: wolfProvider

**Purpose**: Bridge OpenSSL 3.x to wolfSSL

**Component**: wolfProvider v1.1.1

**Source**: https://github.com/wolfSSL/wolfProvider (tag v1.1.1)

**Location**: `/usr/local/openssl/lib64/ossl-modules/libwolfprov.so`

**Responsibilities**:
- Implement OpenSSL 3.x provider interface
- Translate EVP_* calls to wolfSSL API
- Manage wolfSSL context and state
- Handle provider queries and algorithm availability

**Configuration**:
- Named "wolfssl" in openssl.cnf
- Works alongside OpenSSL's "fips" provider
- Provides actual FIPS cryptographic operations

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

### Layer 7: wolfSSL FIPS Module

**Purpose**: FIPS-validated cryptographic operations

**Component**: libwolfssl.so.44

**Details**:
- Version: wolfSSL FIPS v5.8.2
- Certificate: FIPS 140-3 #4718
- Location: `/usr/local/lib/libwolfssl.so.44`
- Build Options:
  - `--enable-fips=v5` (FIPS 140-3 mode)
  - `--enable-all` (All features)
  - `--enable-keygen` (Key generation)
  - `--enable-certgen` (Certificate generation)

**FIPS Boundary**:
- All cryptographic operations occur within this module
- In-core integrity verification on load
- Power-On Self Test (POST) executed on first use
- Only FIPS-approved algorithms accessible
- Provides validated crypto for Podman operations

**Approved Algorithms** (FIPS 140-3):
- **Symmetric**: AES-128, AES-192, AES-256 (CBC, CTR, GCM, CCM)
- **Hash**: SHA-224, SHA-256, SHA-384, SHA-512, SHA3-*
- **MAC**: HMAC (SHA-*), CMAC (AES)
- **Asymmetric**: RSA (2048/3072/4096), ECDSA (P-256/384/521)
- **Key Agreement**: ECDH, DH
- **Random**: Hash_DRBG, HMAC_DRBG

**Blocked Algorithms**:
- **MD5**: Deprecated, not FIPS-approved
- **SHA-1**: Can be compiled out for strict security
- **DES/3DES**: Weak, not FIPS-approved
- **RC4**: Insecure stream cipher
- **ChaCha20**: Not FIPS-approved

---

## Podman FIPS Integration

### Podman Cryptographic Use Cases

**1. Container Registry Operations**
- **TLS Connections**: HTTPS connections to registries (docker.io, quay.io, etc.)
- **Image Signatures**: Verify signed container images
- **Registry Authentication**: OAuth tokens, basic auth over TLS

**2. Container Image Management**
- **Image Digests**: SHA-256 checksums for image layers
- **Layer Verification**: Verify integrity of downloaded layers
- **Image Signing**: Sign images with GPG keys

**3. Container Secrets**
- **Secret Encryption**: Encrypt sensitive data in containers
- **Secret Storage**: Secure storage of API keys, passwords
- **Secret Distribution**: Encrypted transfer to containers

**4. Network Security**
- **Overlay Networks**: Encrypted container-to-container communication
- **API Server**: HTTPS API endpoints
- **Remote Connections**: SSH-based remote Podman access

**5. Container Runtime**
- **Random Number Generation**: Secure container IDs, tokens
- **Certificate Generation**: Generate TLS certificates for services
- **Key Generation**: RSA/ECDSA key pairs for signing

### Build Strategy

**Build-Time** (Capability, No Enforcement):
```bash
# Building Podman with golang-fips/go
export CGO_ENABLED=1
export PATH=/usr/local/go-fips/bin:$PATH
export PKG_CONFIG_PATH=/usr/local/openssl/lib64/pkgconfig:$PKG_CONFIG_PATH

# NO FIPS enforcement during build
unset GOLANG_FIPS
unset GODEBUG
unset GOEXPERIMENT

# Build Podman
cd /usr/src/podman
make podman
```

**Why No FIPS During Build**:
- Podman build process doesn't need FIPS restrictions
- golang-fips/go provides FIPS *capability*, not enforcement
- Build system needs flexibility (non-FIPS algorithms OK for build tools)
- Runtime enforcement is where FIPS compliance matters

**Runtime** (Enforcement Activated):
```bash
# entrypoint.sh sets FIPS environment
export GOLANG_FIPS=1
export GODEBUG=fips140=only
export GOEXPERIMENT=strictfipsruntime

# Now Podman executes with FIPS enforcement
/usr/local/bin/podman "$@"
```

### Podman Commands with FIPS

**Example 1: Pull Image**
```bash
$ podman pull docker.io/library/alpine:latest

# Behind the scenes:
# 1. Podman connects to docker.io via TLS
# 2. TLS uses AES-GCM cipher (FIPS-approved)
# 3. Certificate verification uses RSA/ECDSA (FIPS-approved)
# 4. Image layers verified with SHA-256 (FIPS-approved)
# 5. All crypto operations route through wolfSSL FIPS
```

**Example 2: Run Container**
```bash
$ podman run --rm alpine echo "Hello FIPS"

# Behind the scenes:
# 1. Container ID generated with secure random (FIPS DRBG)
# 2. Network namespaces use kernel crypto (host responsibility)
# 3. If encrypted networks: AES-256 (FIPS-approved)
```

**Example 3: Build Image**
```bash
$ podman build -t myimage:latest .

# Behind the scenes:
# 1. Dockerfile processed, layers created
# 2. Layer digests calculated with SHA-256 (FIPS-approved)
# 3. If pushing to registry: TLS with FIPS crypto
```

---

## golang-fips/go Architecture

### Fork Overview

**Repository**: https://github.com/golang-fips/go

**Base**: golang/go (official Go repository)

**Branch**: go1.25-fips-release

**Modifications**:
1. Replace pure Go crypto implementations with OpenSSL calls
2. Add CGO bindings to OpenSSL EVP_* APIs
3. Inject panic points for non-FIPS algorithm detection
4. Remove ChaCha20-Poly1305 cipher suite from TLS
5. Add FIPS provider discovery on initialization

### Build-Time Instrumentation

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

### Runtime Enforcement

**GODEBUG=fips140=only**

**Purpose**: Activate injected panic points

**Example Panic** (if Podman tries MD5):
```
panic: crypto/md5: use of MD5 in FIPS mode

goroutine 1 [running]:
crypto/md5.New()
    /usr/local/go-fips/src/crypto/md5/md5.go:25
github.com/containers/podman/pkg/trust.(*Policy).verifySignature()
    /usr/src/podman/pkg/trust/policy.go:123
main.main()
    /usr/src/podman/cmd/podman/main.go:42
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

    // Verify FIPS mode (via openssl.cnf: default_properties = fips=yes)
    // Note: actual crypto operations use wolfProvider
}
```

---

## CGO Architecture

### CGO Call Lifecycle

**Example**: Podman pulling image with SHA-256 verification

```
1. Podman Application
   package podman/cmd

   func pullImage(imageName string) error {
       // Podman calls image library
       img, err := image.NewFromRemote(imageName)
       // Behind the scenes: TLS connection, SHA-256 verification
   }

2. golang-fips/go crypto/sha256
   // File: src/crypto/sha256/sha256_openssl.go
   package sha256

   // #cgo pkg-config: libcrypto
   // #include <openssl/evp.h>
   import "C"
   import "unsafe"

   func New() hash.Hash {
       d := &digest{
           ctx: C.EVP_MD_CTX_new(),
       }
       C.EVP_DigestInit_ex(d.ctx, C.EVP_sha256(), nil)
       return d
   }

3. CGO Bridge (auto-generated)
   void _cgo_EVP_DigestUpdate(EVP_MD_CTX *ctx, void *data, size_t len) {
       EVP_DigestUpdate(ctx, data, len);
   }

4. OpenSSL 3.5.0 (libcrypto.so.3)
   int EVP_DigestUpdate(EVP_MD_CTX *ctx, const void *data, size_t count) {
       // Dispatch to active provider (wolfProvider)
       return ctx->pctx->pmeth->digest_update(ctx, data, count);
   }

5. wolfProvider (libwolfprov.so)
   static int wp_sha256_update(WP_SHA256_CTX *ctx,
                               const unsigned char *data,
                               size_t len) {
       return wc_Sha256Update(&ctx->sha256, data, len);
   }

6. wolfSSL FIPS (libwolfssl.so.44)
   int wc_Sha256Update(wc_Sha256* sha256, const byte* data, word32 len) {
       // FIPS-validated SHA-256 implementation
       // Inside FIPS boundary
   }
```

### Memory Management

**Go to C** (Podman context):
```go
// Podman uses crypto/sha256 for layer verification
layer := downloadLayer(url)  // []byte data

// golang-fips/go internally:
h := sha256.New()
h.Write(layer)  // Passes to C via CGO

// CGO pointer rules:
// 1. Go pointer passed to C must not contain pointers
// 2. C cannot store Go pointers
// 3. Pointer only valid during C call

// Safe pattern in golang-fips/go:
C.EVP_DigestUpdate(ctx, unsafe.Pointer(&layer[0]), C.size_t(len(layer)))
```

---

## Security Architecture

### FIPS Boundary

```
┌─────────────────────────────────────────────────────────┐
│                  FIPS Boundary                          │
│  ┌───────────────────────────────────────────────────┐  │
│  │ libwolfssl.so.44 (wolfSSL FIPS v5.8.2)           │  │
│  │                                                   │  │
│  │  - wolfCrypt FIPS Module (validated)             │  │
│  │  - FIPS-approved algorithms only                 │  │
│  │  - In-core integrity check                       │  │
│  │  - Power-On Self Test (POST)                     │  │
│  │                                                   │  │
│  │  Input: Podman crypto operations                 │  │
│  │  Output: FIPS-validated results                  │  │
│  │                                                   │  │
│  │  ❌ No external crypto operations                 │  │
│  │  ❌ No algorithm bypass                          │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
         ↑                                    ↓
    Podman requests                      FIPS results
    (via golang-fips/go → OpenSSL → wolfProvider)
```

### Multi-Layer Enforcement

```
Layer 1: Runtime Panic (golang-fips/go + GODEBUG=fips140=only)
┌─────────────────────────────────────────┐
│ if GODEBUG=fips140=only {               │
│     panic("MD5 not allowed in FIPS")    │
│ }                                       │
└─────────────────────────────────────────┘
         ↓ (if bypassed)

Layer 2: Build-Time Instrumentation (GOEXPERIMENT=strictfipsruntime)
┌─────────────────────────────────────────┐
│ Compiler injects panic points during    │
│ Podman build for non-FIPS algorithms    │
└─────────────────────────────────────────┘
         ↓ (if bypassed)

Layer 3: OpenSSL Provider Configuration (default_properties = fips=yes)
┌─────────────────────────────────────────┐
│ OpenSSL config enforces FIPS algorithms │
│ Non-FIPS operations rejected            │
└─────────────────────────────────────────┘
         ↓ (if bypassed)

Layer 4: wolfSSL Library
┌─────────────────────────────────────────┐
│ wolfSSL FIPS v5.8.2 (Certificate #4718) │
│ Only FIPS-approved algorithms available │
│ → Validated cryptographic operations    │
└─────────────────────────────────────────┘
         ↓
     FIPS Compliant
```

### Power-On Self Test (POST)

**Execution**:
1. First Podman cryptographic operation triggers POST in wolfSSL
2. Tests all FIPS-approved algorithms
3. Verifies known-answer tests (KATs)
4. On failure, module enters error state

**POST Trigger**:
```bash
# First Podman command triggers wolfSSL POST
$ podman --version  # ← POST executes in wolfSSL

# Or explicitly via test-fips utility
$ docker run --rm cr.root.io/podman:5.8.1-fedora-44-fips test-fips

# Output:
# wolfSSL FIPS Test Utility
# =========================
# wolfSSL version: 5.8.2
# FIPS mode: ENABLED
# FIPS version: 5
# ✓ wolfSSL FIPS test PASSED
```

---

## Build Architecture

### Multi-Stage Build Process

```dockerfile
# Stage 1: wolfssl-builder (Fedora 44 base)
FROM fedora:44 AS wolfssl-builder
# - Build OpenSSL 3.5.0 from source
# - Extract wolfSSL FIPS v5.8.2 (password-protected)
# - Build with --enable-fips=v5
# - Run fips-hash.sh for integrity
# Output: libwolfssl.so.44 → /usr/local/lib/

# Stage 2: wolfprov-builder
FROM fedora:44 AS wolfprov-builder
# - Copy OpenSSL from wolfssl-builder
# - Copy libwolfssl from wolfssl-builder
# - Clone wolfProvider v1.1.1
# - Build wolfProvider linked to wolfSSL
# Output: libwolfprov.so → /usr/local/openssl/lib64/ossl-modules/

# Stage 3: go-fips-builder
FROM fedora:44 AS go-fips-builder
# - Copy OpenSSL and wolfSSL from previous stages
# - Clone golang-fips/go v1.25
# - Bootstrap with Go 1.22.6
# - Build Go toolchain with CGO_ENABLED=1
# Output: /usr/local/go-fips/ (full toolchain)

# Stage 4: podman-builder
FROM fedora:44 AS podman-builder
# - Copy golang-fips/go toolchain
# - Copy OpenSSL, wolfSSL, wolfProvider
# - Install Podman build dependencies
# - Clone Podman v5.8.1 source
# - Build Podman with golang-fips/go
# - CGO_ENABLED=1, NO FIPS enforcement during build
# Output: /usr/local/bin/podman (FIPS-capable binary)

# Stage 5: Runtime Image (Fedora 44)
FROM fedora:44
# - Copy libwolfssl.so from wolfssl-builder
# - Copy libwolfprov.so from wolfprov-builder
# - Copy OpenSSL from wolfssl-builder
# - Copy golang-fips/go toolchain from go-fips-builder
# - Copy Podman binary from podman-builder
# - Install runtime dependencies (conmon, crun, slirp4netns, fuse-overlayfs)
# - Copy openssl.cnf with provider configuration
# - Copy entrypoint.sh for FIPS enforcement
# - Generate fipsmodule.cnf via openssl fipsinstall
# - Copy test-fips utility
```

### Build Dependencies

```
OpenSSL 3.5.0 Source Build
   ↓ (libssl.so.3, libcrypto.so.3, fips.so)
wolfSSL FIPS v5.8.2 Build ← requires OpenSSL headers
   ↓ (libwolfssl.so.44)
wolfProvider v1.1.1 Build ← requires OpenSSL + wolfSSL
   ↓ (libwolfprov.so)
golang-fips/go v1.25 Build ← requires OpenSSL headers
   ↓ (/usr/local/go-fips/)
Podman v5.8.1 Build ← requires golang-fips/go toolchain + OpenSSL
   ↓ (/usr/local/bin/podman - FIPS-capable)
Runtime Image Assembly ← combines all artifacts
   ↓ (cr.root.io/podman:5.8.1-fedora-44-fips)
```

### Critical Build Flags

**wolfSSL**:
```bash
./configure \
    --enable-fips=v5 \                 # FIPS 140-3 mode
    --enable-all \                     # All features
    --enable-keygen \                  # Key generation
    --enable-certgen \                 # Certificate generation
    --prefix=/usr/local
```

**OpenSSL**:
```bash
./config \
    enable-fips \                      # FIPS provider support
    shared \                           # Shared libraries
    --prefix=/usr/local/openssl \
    --openssldir=/usr/local/openssl/ssl
```

**wolfProvider**:
```bash
./configure \
    --with-openssl=/usr/local/openssl \  # OpenSSL 3.5.0 location
    --with-wolfssl=/usr/local \          # wolfSSL FIPS location
    --prefix=/usr/local
```

**golang-fips/go**:
```bash
CGO_ENABLED=1 \
GOEXPERIMENT=strictfipsruntime \       # Inject panic instrumentation
./make.bash
```

**Podman**:
```bash
# Build WITHOUT FIPS enforcement (capability only)
export CGO_ENABLED=1
export PATH=/usr/local/go-fips/bin:$PATH
export PKG_CONFIG_PATH=/usr/local/openssl/lib64/pkgconfig
# NO GOLANG_FIPS, NO GODEBUG, NO GOEXPERIMENT during build

make podman
# Output: FIPS-capable Podman binary
```

---

## Deployment Architecture

### Container Startup Flow

```
Docker/Podman Container Start
    ↓
Execute entrypoint.sh
    ↓
┌─────────────────────────────────────────┐
│ Set FIPS Environment Variables          │
│ --------------------------------         │
│ export GOLANG_FIPS=1                    │
│ export GODEBUG=fips140=only             │
│ export GOEXPERIMENT=strictfipsruntime   │
└─────────────────────────────────────────┘
    ↓
Execute User Command
    ↓
/usr/local/bin/podman "$@"
    ↓
Podman Starts with FIPS Enforcement
    ↓
golang-fips/go Runtime Initialization
    ↓
Load OpenSSL Configuration (/etc/ssl/openssl.cnf)
    ↓
Load Providers (fips, wolfssl, base)
    ↓
Verify FIPS Provider Available
    ↓
Podman Ready with FIPS Crypto
```

### Environment Variables

| Variable | Value | Purpose |
|----------|-------|---------|
| `GOLANG_FIPS` | `1` | Activate FIPS mode in golang-fips/go |
| `GODEBUG` | `fips140=only` | Trigger panics for non-FIPS algorithms |
| `GOEXPERIMENT` | `strictfipsruntime` | Indicates binary built with instrumentation |
| `OPENSSL_CONF` | `/etc/ssl/openssl.cnf` | OpenSSL configuration file path |
| `OPENSSL_MODULES` | `/usr/local/openssl/lib64/ossl-modules` | Provider module directory |
| `LD_LIBRARY_PATH` | `/usr/local/lib:/usr/local/openssl/lib64` | Library search path |

### OpenSSL Configuration

**File**: `/etc/ssl/openssl.cnf`

```ini
# OpenSSL Configuration for Podman FIPS with wolfProvider
openssl_conf = openssl_init

[openssl_init]
providers = provider_sect
alg_section = algorithm_sect

[provider_sect]
fips = fips_sect
wolfssl = wolfssl_sect
base = base_sect

[fips_sect]
activate = 1
module = /usr/local/openssl/lib64/ossl-modules/fips.so
# Include FIPS module config generated by openssl fipsinstall
.include /usr/local/openssl/ssl/fipsmodule.cnf

[wolfssl_sect]
activate = 1
module = /usr/local/openssl/lib64/ossl-modules/libwolfprov.so

[base_sect]
activate = 1

[algorithm_sect]
default_properties = fips=yes
```

**Why Three Providers**:
1. **fips**: OpenSSL's FIPS provider (for golang-fips/go initialization check)
2. **wolfssl**: wolfProvider (actual FIPS operations via wolfSSL #4718)
3. **base**: Base provider (for non-crypto operations)

---

## Data Flow Examples

### Example 1: Podman Pull Image

```
User Command:
    $ podman pull docker.io/library/alpine:latest

↓ Podman Application Layer

Podman Registry Client:
    // Connect to registry via HTTPS
    client := &http.Client{
        Transport: &http.Transport{
            TLSClientConfig: &tls.Config{
                MinVersion: tls.VersionTLS12,
            },
        },
    }

↓ golang-fips/go TLS Stack

crypto/tls Package:
    // TLS handshake using OpenSSL
    // - ECDH key exchange
    // - AES-256-GCM cipher
    // - SHA-384 MAC

↓ CGO Bridge → OpenSSL → wolfProvider → wolfSSL FIPS

wolfSSL FIPS (libwolfssl.so.44):
    // TLS handshake
    // Certificate verification (RSA/ECDSA)
    // Symmetric encryption (AES-GCM)
    // All operations in FIPS boundary

↓ Download image manifest

↓ Verify layer digests (SHA-256)

crypto/sha256:
    // Each layer verified with SHA-256
    h := sha256.New()
    h.Write(layerData)
    digest := h.Sum(nil)

↓ CGO → OpenSSL → wolfProvider → wolfSSL FIPS

wolfSSL: wc_Sha256Update(), wc_Sha256Final()

↓ Return verified image

Podman: Image successfully pulled and verified
```

### Example 2: Podman Info Command

```
User Command:
    $ docker run --rm --privileged cr.root.io/podman:5.8.1-fedora-44-fips podman info

↓ entrypoint.sh

Set FIPS Environment:
    export GOLANG_FIPS=1
    export GODEBUG=fips140=only
    export GOEXPERIMENT=strictfipsruntime

↓ Execute Podman

/usr/local/bin/podman info

↓ golang-fips/go Initialization

runtime_openssl_init():
    - Load openssl.cnf
    - Initialize providers
    - Verify FIPS mode

↓ wolfSSL POST (first crypto operation)

wolfCrypt_Init():
    - In-core integrity check
    - Power-On Self Test
    - Verify all algorithms

↓ Podman Collects System Info

Podman gathers:
    - Version information
    - Storage configuration
    - Network configuration
    - Runtime dependencies

↓ Display Output

Podman: System information displayed
```

---

## Comparison with Standard Podman

### Build and Installation

| Aspect | Standard Podman | Podman FIPS |
|--------|-----------------|-------------|
| **Installation** | `dnf install podman` | Build from source |
| **Build Time** | N/A (pre-built) | 20-30 minutes |
| **Go Compiler** | Standard Go 1.22+ | golang-fips/go v1.25 |
| **Dependencies** | Minimal | OpenSSL, wolfSSL, wolfProvider |
| **Size** | ~40MB | ~800MB-1GB (includes toolchain) |

### Crypto Stack

| Component | Standard Podman | Podman FIPS |
|-----------|-----------------|-------------|
| **Crypto Implementation** | Pure Go | OpenSSL + wolfSSL FIPS |
| **TLS Library** | Go crypto/tls | golang-fips/go → OpenSSL |
| **Hash Functions** | Go crypto/* | OpenSSL EVP_* → wolfSSL |
| **FIPS Validation** | None | wolfSSL #4718 |
| **Algorithm Blocking** | None | Runtime panics |

### Runtime Behavior

| Operation | Standard Podman | Podman FIPS |
|-----------|-----------------|-------------|
| **`podman pull`** | TLS with any cipher | TLS with FIPS ciphers only |
| **`podman run`** | Standard crypto | FIPS crypto |
| **`podman build`** | Standard crypto | FIPS crypto |
| **Image verification** | SHA-256 (Go) | SHA-256 (wolfSSL FIPS) |
| **TLS connections** | Any TLS version/cipher | TLS 1.2+ FIPS ciphers |

### Performance

| Operation | Standard Podman | Podman FIPS | Notes |
|-----------|-----------------|-------------|-------|
| **Pull image** | Fast | Slightly slower | CGO overhead in TLS |
| **Run container** | Fast | Similar | Minimal crypto in run |
| **Build image** | Fast | Similar | Minimal crypto in build |
| **TLS handshake** | Fast | Similar | Native OpenSSL perf |
| **Hash calculation** | Fast | Slightly slower | CGO overhead |

---

## Additional Resources

- **[README.md](README.md)** - General documentation and usage
- **[CHAIN-OF-CUSTODY.md](compliance/CHAIN-OF-CUSTODY.md)** - Provenance documentation
- **[Evidence/](Evidence/)** - Test results and compliance evidence
- **Podman Documentation**: https://docs.podman.io/
- **golang-fips/go**: https://github.com/golang-fips/go
- **wolfSSL FIPS**: https://www.wolfssl.com/products/fips/
- **wolfProvider**: https://github.com/wolfSSL/wolfProvider
- **OpenSSL**: https://www.openssl.org/

---

**Last Updated**: 2026-04-17
**Version**: 1.0
**Podman Version**: 5.8.1
**golang-fips/go Version**: 1.25
**wolfSSL FIPS Version**: v5.8.2 (Certificate #4718)
**OpenSSL Version**: 3.5.0
**wolfProvider Version**: v1.1.1
**Base Image**: Fedora 44
