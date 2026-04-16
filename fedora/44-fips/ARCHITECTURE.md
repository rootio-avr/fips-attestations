# Fedora 44 FIPS Minimal Base Image - Architecture

## Table of Contents

- [Overview](#overview)
- [System Architecture](#system-architecture)
- [Cryptographic Stack](#cryptographic-stack)
- [Build Architecture](#build-architecture)
- [Runtime Architecture](#runtime-architecture)
- [FIPS Compliance Implementation](#fips-compliance-implementation)
- [Security Architecture](#security-architecture)
- [Design Decisions](#design-decisions)
- [Limitations and Trade-offs](#limitations-and-trade-offs)

## Overview

This document describes the technical architecture of the Fedora 44 FIPS minimal base image, focusing on how FIPS 140-3 compliance is achieved using Fedora's native crypto-policies framework and the Red Hat Enterprise Linux OpenSSL FIPS Provider.

### High-Level Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│              User Applications (Built on this base)              │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐     │
│  │  Python App    │  │   Node.js App  │  │  Java App      │     │
│  │  (uses crypto) │  │  (TLS/HTTPS)   │  │  (JSSE/crypto) │     │
│  └───────┬────────┘  └───────┬────────┘  └───────┬────────┘     │
└──────────┼───────────────────┼───────────────────┼──────────────┘
           │                   │                   │
           │  All crypto operations use OpenSSL    │
           │                   │                   │
           ▼                   ▼                   ▼
┌──────────────────────────────────────────────────────────────────┐
│               OpenSSL 3.5.5 EVP API Layer                       │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  EVP_DigestInit(), EVP_CipherInit(), SSL_connect(), etc.   │  │
│  └────────────────────┬───────────────────────────────────────┘  │
└───────────────────────┼──────────────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────────────┐
│            Fedora Crypto-Policies (FIPS Mode)                    │
│         System-Wide Cryptographic Policy Framework                │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  /etc/crypto-policies/config: FIPS                         │  │
│  │  /etc/crypto-policies/back-ends/* (OpenSSL, GnuTLS, NSS)   │  │
│  └────────────────────┬───────────────────────────────────────┘  │
└───────────────────────┼──────────────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────────────┐
│         Red Hat Enterprise Linux OpenSSL FIPS Provider           │
│              FIPS 140-3 Validated Crypto Module                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  AES, SHA-256, HMAC, RSA, ECDSA, DRBG (all FIPS-approved) │  │
│  │  Loaded via OpenSSL provider architecture                 │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────────────┐
│                  Operating System / Hardware                     │
│                   Fedora 44 (Minimal)                            │
└──────────────────────────────────────────────────────────────────┘
```

## System Architecture

### Component Layers

The system is organized into distinct layers, each with specific responsibilities:

#### 1. Base Operating System (Fedora 44 Minimal)

- **Purpose:** Minimal base image for FIPS-compliant applications
- **Distribution:** Fedora 44 (released April 2025)
- **Package Manager:** DNF (Dandified YUM)
- **Base Size:** ~170 MB (minimal installation)
- **Final Size:** ~317 MB (with FIPS components)

**Key Characteristics:**
- Minimal package set (only essentials)
- No application-level software
- No compilers or development tools in final image
- No GUI or desktop components
- System libraries only (glibc, systemd-libs, etc.)

#### 2. Crypto-Policies Framework

- **Purpose:** System-wide cryptographic policy management
- **Configuration:** `/etc/crypto-policies/config`
- **Mode:** FIPS
- **Scope:** Affects all cryptographic libraries

**What It Does:**
1. Configures OpenSSL to use FIPS provider by default
2. Sets approved cipher suites for TLS
3. Enforces minimum key sizes (RSA ≥2048 bits)
4. Blocks weak algorithms (MD5, MD4, DES, RC4)
5. Updates backend configuration files:
   - `/etc/crypto-policies/back-ends/opensslcnf.config`
   - `/etc/crypto-policies/back-ends/openssl.config`
   - `/etc/crypto-policies/back-ends/gnutls.config`

**Benefits:**
- Single policy controls all crypto across system
- No application-specific configuration needed
- Consistent security posture
- Easy policy updates (via update-crypto-policies)

#### 3. Cryptographic API Layer (OpenSSL 3.5.5)

- **Purpose:** Standard cryptographic API for applications
- **Version:** 3.5.5 (from Fedora 44 repositories)
- **Role:** Abstraction layer between applications and FIPS module
- **API:** EVP (high-level crypto API)

**Provider Architecture:**
```
OpenSSL 3.x Core
    ├─ default provider (deactivated in FIPS mode)
    ├─ fips provider (ACTIVE - Red Hat OpenSSL FIPS Provider)
    └─ legacy provider (disabled in FIPS mode)
```

#### 4. FIPS Module Layer (Red Hat OpenSSL FIPS Provider)

- **Purpose:** FIPS 140-3 validated cryptographic operations
- **Version:** 3.5.5
- **Vendor:** Red Hat (adapted from OpenSSL FIPS module)
- **Standard:** FIPS 140-3
- **Integration:** Native OpenSSL 3.x provider

**Validated Algorithms:**
- Symmetric: AES-128/192/256 (CBC, GCM, CCM, CTR)
- Hashing: SHA-224, SHA-256, SHA-384, SHA-512, SHA-512/224, SHA-512/256
- MAC: HMAC-SHA-2 family
- Asymmetric: RSA (≥2048 bits), ECDSA (P-256/384/521), ECDH
- RNG: DRBG (Hash_DRBG, HMAC_DRBG)

### Data Flow Example

#### Example: Python Application Using TLS

```
Python app: ssl.create_default_context()
  │
  ▼
Python ssl module: Uses OpenSSL Python bindings
  │
  ▼
OpenSSL: SSL_connect() → TLS handshake
  │
  ▼
Crypto-policies: Enforces FIPS cipher suites only
  │
  ▼
OpenSSL FIPS Provider:
  - ECDH for key exchange
  - AES-GCM for symmetric encryption
  - SHA-256 for message authentication
  - RSA/ECDSA for certificate validation
  │
  ▼
FIPS 140-3 validated operations
  │
  ▼
Secure TLS 1.2/1.3 connection established
```

## Cryptographic Stack

### Red Hat OpenSSL FIPS Provider 3.5.5

**What is the OpenSSL FIPS Provider?**

The OpenSSL FIPS Provider is a cryptographic module that implements FIPS 140-3 validated algorithms as an OpenSSL 3.x provider. Red Hat maintains a version based on the upstream OpenSSL FIPS module.

**FIPS 140-3 Compliance:**
- **Module Name:** Red Hat Enterprise Linux OpenSSL FIPS Provider
- **Version:** 3.5.5
- **Standard:** FIPS 140-3
- **Status:** ACTIVE (validated)

**Approved Algorithms:**

```c
// AES (Advanced Encryption Standard)
- AES-128-CBC, AES-192-CBC, AES-256-CBC
- AES-128-GCM, AES-192-GCM, AES-256-GCM
- AES-128-CCM, AES-192-CCM, AES-256-CCM
- AES-128-CTR, AES-192-CTR, AES-256-CTR

// SHA (Secure Hash Algorithm)
- SHA-224, SHA-256, SHA-384, SHA-512
- SHA-512/224, SHA-512/256
- SHA-1 (legacy support - HMAC and verification only)

// HMAC (Hash-based Message Authentication Code)
- HMAC-SHA-224, HMAC-SHA-256, HMAC-SHA-384, HMAC-SHA-512

// RSA (Rivest–Shamir–Adleman)
- RSA Key Generation (2048, 3072, 4096-bit)
- RSA Signature (PKCS#1 v1.5, PSS)
- RSA Encryption (OAEP)
- Minimum key size: 2048 bits

// ECDSA (Elliptic Curve Digital Signature Algorithm)
- P-256 (secp256r1), P-384 (secp384r1), P-521 (secp521r1)
- Signature generation and verification

// ECDH (Elliptic Curve Diffie-Hellman)
- P-256, P-384, P-521 curves
- Key agreement for TLS

// DRBG (Deterministic Random Bit Generator)
- Hash_DRBG (SHA-256)
- HMAC_DRBG (SHA-256)
```

### Fedora Crypto-Policies Framework

**Architecture:**

```
┌─────────────────────────────────────────────┐
│  update-crypto-policies --set FIPS         │
│  ↓                                          │
│  Reads /usr/share/crypto-policies/FIPS.pol │
│  ↓                                          │
│  Generates backend configs:                │
│    /etc/crypto-policies/back-ends/        │
│      ├─ opensslcnf.config                 │
│      ├─ openssl.config                    │
│      ├─ gnutls.config                     │
│      ├─ nss.config                        │
│      └─ ... (other backends)              │
└─────────────────────────────────────────────┘
```

**OpenSSL Backend Configuration:**

When crypto-policies is set to FIPS mode, it generates:

`/etc/crypto-policies/back-ends/opensslcnf.config`:
```ini
[openssl_init]
.include /etc/crypto-policies/back-ends/openssl.config

[default_sect]
default_properties = fips=yes
```

This configuration:
1. Activates FIPS provider by default
2. Sets `fips=yes` as default property
3. Ensures all algorithms are FIPS-approved
4. Blocks non-FIPS algorithms

### OPENSSL_FORCE_FIPS_MODE Environment Variable

**Purpose:** Forces OpenSSL into FIPS mode in containerized environments

**Why Needed:**
- Containers don't have kernel-level FIPS support
- Host kernel FIPS mode not inherited by containers
- `OPENSSL_FORCE_FIPS_MODE=1` enables application-level FIPS enforcement

**Effect:**
```c
// Inside OpenSSL library
if (getenv("OPENSSL_FORCE_FIPS_MODE")) {
    EVP_default_properties_enable_fips(NULL, 1);
    // Forces FIPS mode regardless of kernel state
}
```

## Build Architecture

### Single-Stage Docker Build

Unlike complex application images (like Gotenberg's 8-stage build), the Fedora 44 FIPS minimal base uses a simple single-stage process:

#### Build Process Flow

```
Fedora 44 Base Image (Official)
    ↓
Install Essential Packages
  - ca-certificates
  - tzdata
  - crypto-policies
  - crypto-policies-scripts
  - openssl
  - openssl-libs
    ↓
Configure Crypto-Policies (FIPS mode)
  - echo "FIPS" > /etc/crypto-policies/config
  - update-crypto-policies --set FIPS
    ↓
Set Environment Variables
  - OPENSSL_FORCE_FIPS_MODE=1
    ↓
Copy Custom Scripts
  - FIPS verification scripts
  - Diagnostic test suite
  - Utility scripts
    ↓
Generate Integrity Checksums
  - SHA256 checksums of custom scripts
    ↓
Configure Security
  - Create non-root user (appuser:1001)
  - Set permissions
  - Create /app directory
    ↓
Set Entrypoint
  - docker-entrypoint.sh (FIPS validation)
    ↓
Final Image: cr.root.io/fedora:44-fips (~317 MB)
```

#### Dockerfile Structure

```dockerfile
FROM fedora:44

# Install packages from official Fedora repos
RUN dnf install -y \
    ca-certificates \
    tzdata \
    crypto-policies \
    crypto-policies-scripts \
    openssl \
    openssl-libs

# Configure FIPS mode via crypto-policies
RUN echo "FIPS" > /etc/crypto-policies/config && \
    update-crypto-policies --set FIPS

# Force FIPS mode in containers
ENV OPENSSL_FORCE_FIPS_MODE=1

# Copy custom scripts and diagnostics
COPY src/ /opt/fips/bin/
COPY diagnostics/ /opt/fips/diagnostics/
COPY scripts/ /usr/local/bin/

# Security configuration
RUN useradd -r -u 1001 -g appuser -m appuser
USER appuser

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/bin/bash"]
```

**Build Time:** ~5 minutes (vs 30-45 minutes for complex builds)

**Build Simplicity:**
- Single stage (no multi-stage complexity)
- All packages from official repos (no source compilation)
- No commercial FIPS modules needed (uses Fedora's native FIPS)
- Straightforward Dockerfile (easy to understand and maintain)

### Dependency Management

**All dependencies from official Fedora repositories:**

```bash
# Package verification
rpm -qa | grep -E 'openssl|crypto-policies'

# Output:
crypto-policies-20240920-1.fc44.noarch
crypto-policies-scripts-20240920-1.fc44.noarch
openssl-3.5.5-1.fc44.x86_64
openssl-libs-3.5.5-1.fc44.x86_64
```

**Supply Chain Trust:**
- Official Fedora Project repositories
- GPG-signed packages (verified by DNF)
- Reproducible from Fedora source RPMs
- No third-party dependencies

## Runtime Architecture

### Startup Sequence

```
Container Start (docker run)
    │
    ▼
docker-entrypoint.sh executes
    │
    ├─► [CHECK 1/6] Verify OPENSSL_FORCE_FIPS_MODE=1
    │
    ├─► [CHECK 2/6] Verify crypto-policies configuration
    │     - cat /etc/crypto-policies/config
    │     - Expected: FIPS
    │
    ├─► [CHECK 3/6] Verify OpenSSL version
    │     - openssl version
    │     - Expected: OpenSSL 3.5.x
    │
    ├─► [CHECK 4/6] Verify FIPS provider loaded
    │     - openssl list -providers
    │     - Expected: "fips" provider active
    │
    ├─► [CHECK 5/6] Test FIPS algorithm (SHA-256)
    │     - openssl dgst -sha256
    │     - Expected: Success
    │
    ├─► [CHECK 6/6] Verify non-FIPS blocking (MD5)
    │     - openssl dgst -md5
    │     - Expected: Error (blocked)
    │
    ▼
All checks PASSED?
    │
    ├─► YES: Display FIPS status, execute user command
    │     └─► exec "$@" (CMD from docker run)
    │
    └─► NO: Display error, exit with failure code
          └─► Container terminates
```

### FIPS Validation on Startup

Every container start performs comprehensive validation:

**Entrypoint Script (`docker-entrypoint.sh`):**

```bash
#!/bin/bash
set -e

echo "=== Fedora 44 FIPS Validation ==="

# Check 1: OPENSSL_FORCE_FIPS_MODE
if [ "$OPENSSL_FORCE_FIPS_MODE" != "1" ]; then
    echo "ERROR: OPENSSL_FORCE_FIPS_MODE not set"
    exit 1
fi

# Check 2: Crypto-policies
if ! grep -q "FIPS" /etc/crypto-policies/config; then
    echo "ERROR: Crypto-policies not set to FIPS"
    exit 1
fi

# Check 3: OpenSSL version
if ! openssl version | grep -q "3.5"; then
    echo "ERROR: OpenSSL 3.5.x not found"
    exit 1
fi

# Check 4: FIPS provider
if ! openssl list -providers | grep -q "fips"; then
    echo "ERROR: FIPS provider not loaded"
    exit 1
fi

# Check 5: SHA-256 (FIPS-approved)
if ! echo "test" | openssl dgst -sha256 > /dev/null; then
    echo "ERROR: SHA-256 not working"
    exit 1
fi

# Check 6: MD5 blocking (non-FIPS)
if echo "test" | openssl dgst -md5 > /dev/null 2>&1; then
    echo "ERROR: MD5 should be blocked in FIPS mode"
    exit 1
fi

echo "✓ All FIPS checks passed"
exec "$@"
```

### Memory Layout

```
┌───────────────────────────────────────────┐
│  Container Process (Minimal base)         │
│  ┌─────────────────────────────────────┐  │
│  │  User Application (if running)      │  │
│  │  - Python, Node.js, Java, etc.      │  │
│  ├─────────────────────────────────────┤  │
│  │  OpenSSL Libraries                  │  │
│  │  - libssl.so.3                      │  │
│  │  - libcrypto.so.3                   │  │
│  │  - FIPS provider module             │  │
│  ├─────────────────────────────────────┤  │
│  │  System Libraries                   │  │
│  │  - glibc (libc.so.6)                │  │
│  │  - pthreads                         │  │
│  ├─────────────────────────────────────┤  │
│  │  FIPS Scripts                       │  │
│  │  - /opt/fips/bin/                   │  │
│  │  - /opt/fips/diagnostics/           │  │
│  └─────────────────────────────────────┘  │
└───────────────────────────────────────────┘
```

**Minimal Footprint:**
- No application processes by default
- Only essential system libraries
- FIPS provider loaded on-demand
- Small memory overhead (~50 MB baseline)

## FIPS Compliance Implementation

### Native FIPS Integration

**Key Advantage:** Fedora provides native FIPS support through crypto-policies framework

**No Patches Required:**
- OpenSSL FIPS provider built into Fedora packages
- Crypto-policies framework handles configuration
- No source code modifications needed
- No complex build processes required

**Contrast with Commercial FIPS Solutions:**

| Approach | Fedora 44 FIPS | wolfSSL FIPS (Gotenberg) |
|----------|----------------|--------------------------|
| FIPS Module | Red Hat OpenSSL FIPS Provider | wolfSSL FIPS (commercial) |
| Integration | Native (crypto-policies) | Custom (8-stage build) |
| Source Compilation | No (from repos) | Yes (from source) |
| Build Complexity | Low (single-stage) | High (8-stage) |
| License | Free (Fedora repos) | Commercial license required |
| Maintenance | DNF updates | Manual rebuilds |

### FIPS Boundary

The **FIPS cryptographic boundary** encompasses the OpenSSL FIPS provider module:

```
┌──────────────────────────────────────────────────────┐
│              Non-FIPS Components                     │
│  Applications, OpenSSL API layer, System libraries   │
│  (Trusted but not FIPS-validated)                    │
└───────────────────┬──────────────────────────────────┘
                    │
        ┌───────────┴───────────┐
        │  FIPS Boundary Entry  │
        │  (OpenSSL EVP API)    │
        └───────────┬───────────┘
                    │
                    ▼
┌──────────────────────────────────────────────────────┐
│         FIPS Cryptographic Boundary                  │
│                                                      │
│     Red Hat OpenSSL FIPS Provider 3.5.5             │
│                                                      │
│  ┌────────────────────────────────────────────────┐ │
│  │  Validated Algorithms                          │ │
│  │  - AES-CBC, AES-GCM, AES-CCM, AES-CTR         │ │
│  │  - SHA-224, SHA-256, SHA-384, SHA-512         │ │
│  │  - HMAC-SHA-2 family                          │ │
│  │  - RSA (2048, 3072, 4096-bit)                 │ │
│  │  - ECDSA, ECDH (P-256, P-384, P-521)          │ │
│  │  - DRBG (Hash_DRBG, HMAC_DRBG)                │ │
│  └────────────────────────────────────────────────┘ │
│                                                      │
│  ┌────────────────────────────────────────────────┐ │
│  │  Configuration                                 │ │
│  │  - crypto-policies: FIPS mode                 │ │
│  │  - default_properties: fips=yes               │ │
│  │  - OPENSSL_FORCE_FIPS_MODE=1                  │ │
│  └────────────────────────────────────────────────┘ │
│                                                      │
└──────────────────────────────────────────────────────┘
```

## Security Architecture

### Defense in Depth

**Layer 1: FIPS Enforcement**
- Crypto-policies FIPS mode
- OpenSSL FIPS provider active
- `OPENSSL_FORCE_FIPS_MODE=1` environment variable
- Non-FIPS algorithms blocked at library level

**Layer 2: Minimal Attack Surface**
- Minimal package installation (only essentials)
- No compilers or development tools
- No unnecessary network services
- No application-level software

**Layer 3: Process Isolation**
- Non-root user by default (appuser:1001)
- No privileged operations required
- User namespaces supported
- Read-only root filesystem compatible

**Layer 4: Container Security**
- Minimal base image (~317 MB)
- Official packages only (GPG-verified)
- Regular security updates via DNF
- Dockerfile best practices

### Hardening Measures

**File System:**
- No setuid/setgid binaries added
- Minimal writable directories
- `/app` directory for user applications
- Integrity checksums for custom scripts

**Network:**
- No listening ports by default
- Outbound connections use FIPS crypto
- TLS 1.2/1.3 with FIPS cipher suites
- Certificate validation uses FIPS algorithms

**Runtime:**
- Non-root user execution (UID 1001)
- Minimal privileges required
- Capability dropping supported
- Seccomp profiles compatible

## Design Decisions

### Why Fedora 44?

**Pros:**
- ✅ Native FIPS support through crypto-policies
- ✅ Recent OpenSSL 3.5.5 (latest FIPS provider)
- ✅ Active development and security updates
- ✅ Free and open-source (no licensing)
- ✅ Well-documented FIPS configuration
- ✅ Regular package updates

**Cons:**
- ❌ Shorter support lifecycle (~13 months)
- ❌ Need to migrate to Fedora 45 eventually
- ❌ More frequent updates than RHEL/CentOS

**Decision:** Use Fedora 44 for cutting-edge FIPS support, plan migration to Fedora 45

### Why Crypto-Policies?

**Benefits:**
- Centralized policy management
- Affects all crypto libraries (OpenSSL, GnuTLS, NSS)
- Simple configuration (`update-crypto-policies --set FIPS`)
- No application-specific settings needed
- Fedora-native approach

**Alternative Considered:**
- Manual OpenSSL configuration
  - Con: More complex, application-specific
  - Con: Doesn't affect other libraries
  - Con: Harder to maintain

**Decision:** Use crypto-policies for system-wide FIPS enforcement

### Why Minimal Base?

**Rationale:**
- Serve as foundation for FIPS applications
- Reduce attack surface
- Faster container startup
- Smaller image size
- Easier security auditing

**Not Included:**
- No application runtimes (Python, Node.js, Java)
- No web servers (nginx, Apache)
- No databases
- No development tools

**Users add what they need:**
- Multi-stage builds on top of this base
- Install only required packages
- Keep FIPS foundation intact

### Why Single-Stage Build?

**Benefits:**
- Simple Dockerfile (easy to understand)
- Fast build time (~5 minutes)
- Easy to reproduce
- No build artifacts to discard
- Straightforward CI/CD integration

**Suitable for:**
- Minimal base images
- Using pre-built packages from repos
- No source compilation needed

## Limitations and Trade-offs

### Known Limitations

#### 1. Fedora Lifecycle

**Challenge:** Fedora has shorter support lifecycle (~13 months)

**Impact:**
- Need to migrate to Fedora 45 in ~1 year
- More frequent image rebuilds
- Continuous testing required

**Mitigation:**
- Plan migration to Fedora 45 before EOL
- Automated testing for new Fedora versions
- RHEL/CentOS alternative for long-term support

#### 2. Image Size

**Size:** ~317 MB (vs Alpine ~5 MB)

**Reason:**
- glibc vs musl (~100 MB difference)
- RPM packaging overhead
- Systemd libraries (even if not using systemd)

**Acceptable for:**
- Server deployments
- Cloud environments with adequate storage
- Multi-stage builds (base layer cached)

**Not ideal for:**
- Edge devices with limited storage
- Ultra-minimal deployments

#### 3. Container-Specific FIPS Mode

**Challenge:** Containers don't have kernel-level FIPS support

**Solution:** `OPENSSL_FORCE_FIPS_MODE=1` for application-level enforcement

**Limitation:**
- Not kernel-enforced (relies on OpenSSL behavior)
- Applications must use OpenSSL for crypto
- Direct syscalls bypass FIPS provider

**Acceptable for:**
- Most containerized applications
- Applications using standard crypto libraries
- Cloud-native deployments

**Not suitable for:**
- Applications with custom crypto implementations
- Environments requiring kernel-level FIPS

#### 4. SHA-1 Legacy Support

**Behavior:** SHA-1 allowed for legacy operations (HMAC, verification)

**Reason:** NIST SP 800-131A Rev. 2 transition guidance

**Impact:**
- SHA-1 not completely blocked
- Allowed for backwards compatibility
- Deprecated for new signing operations

**Compliance:** Aligned with NIST guidance

#### 5. 3DES Deprecation

**Behavior:** 3DES blocked for encryption, allowed for decryption

**Reason:** NIST deprecated 3DES in FIPS 140-3

**Impact:**
- Cannot encrypt new data with 3DES
- Can decrypt legacy 3DES-encrypted data

**Compliance:** Aligned with FIPS 140-3

### No Breaking Changes

**Advantage:** Drop-in base for FIPS applications

**Compatibility:**
- Standard OpenSSL API unchanged
- Python `ssl` module works without modification
- Node.js crypto module compatible
- Java JSSE works with system crypto
- No application code changes required

**Migration:** Use as base image in existing Dockerfiles with minimal changes

---

**Document Version:** 1.0
**Last Updated:** April 16, 2026
**Maintained By:** Root FIPS Team
